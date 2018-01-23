---
authors:
- rkelapure
- mgunter
categories:
- Profiling
- Java
- VisualVM
- Performance
- CPU Sampling
date: 2018-01-16T14:55:31+02:00
draft: false
short: |
  How to profile apps on Pivotal Cloud Foundry. VisualVM to the rescue!
title: Diagnosing performance issues with Java legacy apps on Pivotal Cloud Foundry
---

# The murder mystery - of the slow process

We were in the process of migrating a legacy java app to PCF. We were replatforming it to Spring Boot from a TIBCO AMX base. The issue we were seeing is that XML service calls ran `2x` slower when running in PCF as compared to when the service calls were made from a standalone java jar. The exact same app displayed different performance characteristics when running in different scenarios:

{{< responsive-figure src="/images/profiling/scenario-table.png" caption="Table listing options" class="center" >}}

ok! so given this situation how do you go about resolving it?
First, It wasn't an obvious situation for doing method-level profiling. So, we had to rule-out a few things that came to mind first:

## Dead-ends
Network-related differences including Latency, bandwidth and route differences. We found out that network performance was faster from PCF than from the Laptop.

JDBC differences including driver versions, pooling configuration, and caching config. We looked at Database call latency in the different environments and found that JDBC performance was not changing enough between scenarios to cause the difference we were seeing.

Class-loading differences especially around the XML parsing libraries used. The major portion of latency was coming from XML processing of the Database resultsets. Were different classes being used in the different scenarios? We did some detailed Class-Loading analysis of the different scenarios and did find a few differences, but `no smoking gun here either`!

_What else could we do to understand the differences across these scenarios. We turned to Profiling._

# Tools Considered
What are the options that come to mind when a service is performing poorly and not satisfying the latency service level indicators ?

**1**.  Poor man's profiler. Take three or four javacores spread 20 seconds apart to see if threads are hanging in particular java operation or code paths. Javacores are the poor man's profiler to debug performance issues. Take a whole bunch of thread dumps spaced 30s apart to determine which threads are stuck and the exact processing that takes place. There are some tools that automatically trigger a JVM thread dump. [thread-dump-grapher](https://github.com/davidminor/java-thread-dump-grapher). On PCF to trigger a threaddump you can either ssh into the container and issue `kill -3 <PID>` or Use Spring Boot `/dump` actuator [endpoint](https://docs.spring.io/spring-boot/docs/current/reference/html/production-ready-endpoints.html) use VisualVM. More on this later....Back to the actual problem. In our case the service call execution was in the 50-200s range therefore there simply was not enough time to trigger multiple thread-dumps aka java cores.

**2**. The second option that came to mind was to instrument the application with metrics and benchmark it using a microprofiler like JMH. We considered getting inspired by David Syer's work with spring boot like the [spring-boot-startup-bench](https://github.com/dsyer/spring-boot-startup-bench). naah ... we are lazy and impatient developers - this would be too much work.

**3**.  We briefly considered JVM garbage collection was a likely culprit. We suspected that the app may be getting pressured due to low memory and GC stop the world activity may be causing the slowdown. Since we could change the size of the JVM and not affect performance, we moved on.

**4**.  However, if we wanted to validate this hypothesis in more detail we would have needed to compare the verbose GC logs from the jvm inside the container and the app running standalone outside. We would need to push the app with `java_opts: -Xloggc:$PWD/beacon_gc.log -verbose:gc` and the pull the log out from the container or Splunk etc.,. Again this felt too much of a chore with not enough immediate ROI. If you are suspecting issues with the native memory then you will need to do more invasive surgery with ```JAVA_OPTS: -Djava.security.egd=file:///dev/urandom -XX:NativeMemoryTracking=summary -XX:+PrintHeapAtGC -XX:+PrintGCDetails -XX:+PrintGCTimeStamps```

**5**. _The hunt was now on for a light weight CPU sampling profiler that could be invoked without much setup or prep within the app._ oh wait ... there is this thing called the `hprof` JVMTI profiler baked within the JVM. Unfortunately [HROF](https://docs.oracle.com/javase/8/docs/technotes/guides/troubleshoot/tooldescr008.html) is not reliable and has [problems](http://www.brendangregg.com/blog/2014-06-09/java-cpu-sampling-using-hprof.html). Moreover the hprof tool was sunset in JDK8 further adding to our misgiving to our tool.

---
 Finally through the process of elimination we landed on [VisualVM](https://visualvm.github.io/index.html) for profiling our app. VisualVM on your laptop can connect remotely to the app running in PCF. See this excellent KnowledgeBase [article](https://discuss.pivotal.io/hc/en-us/articles/221330108-How-to-remotely-monitor-Java-applications-deployed-on-PCF-via-JMX) on _How to remotely monitor Java applications deployed on PCF® via JMX_. Please note that *The instructions are only useful in Diego-based containers with SSH access enabled.*

# Where the Bodies Lie ... 

We decided to use VisualVM to profile several of the scenarios to see if the profile results were consistent and could help explain the performance differences.
{{< responsive-figure src="/images/profiling/Slide2.jpg" caption="Scenarios profiled" class="center" >}}

The three scenarios were tested with VisualVM's Sampling option.

> "VisualVM’s profiler works by “instrumenting” all of the methods of your code. This adds extra bytecode to your methods for recording when they’re called, and how long they take to execute each time they are.
VisualVM’s sampler, however, takes a dump of all of the threads of execution on a fairly regular basis, and uses this to work out how roughly how much CPU time each method spends" (reference from : https://blog.idrsolutions.com/2014/04/profiling-vs-sampling-java-visualvm/ ).

To get relevant profile information we had to configure the VisualVM sampling configuration
{{< responsive-figure src="/images/profiling/Slide1.jpg" caption="Scenarios profiled" class="center" >}}

We ran each test with the same load test using SOAPUI. The results are below:

{{< responsive-figure src="/images/profiling/Slide3.jpg" caption="Builpack on PCF Results" class="center" >}}

{{< responsive-figure src="/images/profiling/Slide4.jpg" caption="mvn spring-boot run Results" class="center" >}}

{{< responsive-figure src="/images/profiling/Slide5.jpg" caption="java -jar Results" class="center" >}}

# Smoking Gun

We still aren't 100% sure why the Buildpack execution was slower than `mvn spring-boot:run`. Our best guess is that the method in question is loading classes and the classpath order can be very different between execution methods. Even if the same class is found, the position on the classpath can delay the loading of the class.

To summarize our finding, here is the method that caused the slowdown we were seeing in PolicyNoteBoot:

The performance penalty of `DatatypeFactory.newInstance().newXMLGregorianCalendar(c);` was confirmed from the data above with a workaround of caching the Factory outside the loop. [Java Performance Pitfalls - DatatypeFactory](http://dimovelev.blogspot.com/2013/10/java-performance-pitfalls.html)

Moving the factory object out of the loop made performance better and consistent.

The final SoapUI results were:

{{< responsive-figure src="/images/profiling/Slide6.jpg" caption="mvn spring-boot run Results" class="center" >}}

# KnowledgeBase Articles
- Java application memory not being garbage collected https://discuss.pivotal.io/hc/en-us/articles/115009516387-Java-application-memory-not-being-garbage-collected
- Remote Triggers for Applications on Cloud Foundry https://content.pivotal.io/blog/remote-triggers-for-applications-on-cloud-foundry
- Dump Native Memory https://github.com/dmikusa-pivotal/cf-debug-tools#use-profiled-to-dump-the-jvm-native-memory
- Java Buildpack Framework java opts https://github.com/cloudfoundry/java-buildpack/blob/master/docs/framework-java_opts.md
