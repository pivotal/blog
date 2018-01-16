---
authors:
- rkelapure
- mgunther
categories:
- Profiling
- Java
- VisualVM
- Performance
- CPU Sampling
date: 2018-01-16T14:55:31+02:00
draft: true
short: |
  How to profile apps on Pivotal Cloud Foundry. VisualVM to the rescue!
title: Diagnosing performance issues with Java legacy apps on Pivotal Cloud Foundry
---

# The murder mystery - of the slow process

We were in the process of migrating a legacy java app to PCF. We were replatforming it to Spring Boot from a TIBCO AMX base. The issue we were seeing is that XML service calls ran 2x slower when running in PCF as compared to when the service calls were made from a standalone java jar. The exact same app displayed different performance characteristics when running in the cloud vs when it ran on a local laptop. ok! so given this situation how do you go about diagnosing a latency problem in the cloud ??

# Tools Used - Optionality  
What are the options that come to mind when a service is performing poorly and not satisfying the latency service level indicators ?

1. Poor man's profiler. Take three or four javacores spread 20 seconds apart to see if threads are hanging in particular java operation or code paths. Javacores are the poor man's profiler to debug performance issues. Take a whole bunch of thread dumps spaced 30s apart to determine which threads are stuck and the exact processing that takes place. There are some tools that automatically trigger a JVM thread dump. [thread-dump-grapher](https://github.com/davidminor/java-thread-dump-grapher). On PCF to trigger a threaddump you can either ssh into the container and issue `kill -3 <PID>` or Use Spring Boot `/dump` actuator [endpoint](https://docs.spring.io/spring-boot/docs/current/reference/html/production-ready-endpoints.html) use VisualVM. More on this later....Back to the actual problem. In our case the service call execution was in the 50-200s range therefore there simply was not enough time to trigger multiple threaddumps aka java cores.

2. The second option that came to mind was to instrument the application with metrics and benchmark it using a microprofiler like JMH. We considered getting inspired by David Syer's work with spring boot like the [spring-boot-startup-bench](https://github.com/dsyer/spring-boot-startup-bench). naah ... we are lazy and impatient developers - this would be too much work.

3. To our dismay since we could not blame the network or the DNS, JVM garbage collection was the next likely culprit. We suspected that the app may be getting pressured due to low memory and GC stop the world activity may be causing the slowdown. In order to validate this hypothesis we would have needed to compare the verbose GC logs from the jvm inside the container and the app running standalone outside. We would need to push the app with `java_opts: -Xloggc:$PWD/beacon_gc.log -verbose:gc` and the pull the log out from the container or Splunk etc.,. Again this felt too much of a chore with not enough immediate ROI. If you are suspecting issues with the native memory then you will need to do more invasive surgery with ```JAVA_OPTS: -Djava.security.egd=file:///dev/urandom -XX:NativeMemoryTracking=summary -XX:+PrintHeapAtGC -XX:+PrintGCDetails -XX:+PrintGCTimeStamps```

4. The hunt was now on for a light weight CPU sampling profiler that could be invoked without much setup or prep within the app. oh wait ... there is this thing called the `hprof` JVMTI profiler baked within the JVM. Unfortunately [HROF](https://docs.oracle.com/javase/8/docs/technotes/guides/troubleshoot/tooldescr008.html) is not reliable and has [problems](http://www.brendangregg.com/blog/2014-06-09/java-cpu-sampling-using-hprof.html). Moreover the hprof tool was sunset in JDK8 further adding to our misgiving to our tool.

5. Finally through the process of elimination we landed on [VisualVM](https://visualvm.github.io/index.html) for profiling our app. VisualVM on your laptop can connect remotely to the app running in PCF. See this excellent KnowledgeBase [article](https://discuss.pivotal.io/hc/en-us/articles/221330108-How-to-remotely-monitor-Java-applications-deployed-on-PCF-via-JMX) on _How to remotely monitor Java applications deployed on PCF® via JMX_. Please note that *The instructions are only useful in Diego-based containers with SSH access enabled.*

# Where the Bodies Lie ... Evidence

{{< responsive-figure src="/images/profiling/cloud-profile.png" caption="Cloud profile showing slowdown" class="center" >}}

{{< responsive-figure src="/images/profiling/standlone-profile.png" caption="standalone profile with no impact" class="center" >}}

# Smoking Gun

We still aren't sure why the Buildpack execution was slower than `mvn spring-boot:run`. Moving the factory object out of the loop made performance better and consistent. The performance penalty of `DatatypeFactory.newInstance().newXMLGregorianCalendar(c);` was confirmed from the data above with a workaround of caching the Factory outside the loop. [Java Performance Pitfalls - DatatypeFactory](http://dimovelev.blogspot.com/2013/10/java-performance-pitfalls.html)

# KnowledgeBase Articles
- Java application memory not being garbage collected https://discuss.pivotal.io/hc/en-us/articles/115009516387-Java-application-memory-not-being-garbage-collected
- Remote Triggers for Applications on Cloud Foundry https://content.pivotal.io/blog/remote-triggers-for-applications-on-cloud-foundry
