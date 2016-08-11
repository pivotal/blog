---
authors:
- dmikusa
categories:
- Tomcat
- Performance
- Migrated Content
date: 2011-11-16T00:08:15+00:00
short: |
  Setting Up Measurement of Garbage Collection in Apache Tomcat
title: Apache Tomcat GC Measurement
---

Have you ever seen this scenario before? A user has deployed an application to a Tomcat server. The application works great during testing and QA; however, when the user moves the application into production, the load increases and Tomcat stops handling requests. At first this happens occasionally and for only 5 or 10 seconds per occurrence. It's such a small issue, the user might not even notice or, if noticed, may choose to just ignore the problem. After all, it's only 5 or 10 seconds and it's not happening very often. Unfortunately for the user, as the application continues to run the problem continues to occur and with a greater frequency; possibly until the Tomcat server just stops responding to requests all together.

There is a good chance that at some point in your career, you or someone you know has faced this issue. While there are multiple possible causes to this problem like blocked threads, too much load on the server, or even application specific problems, the one cause of this problem that I see over and over is excessive garbage collection.

As an application runs it creates objects. As it continues to run, many of these objects are no longer needed. In Java, the unused objects remain in memory until a garbage collection occurs and frees up the memory used by the objects. In most cases, these garbage collections run very quickly, but occasionally the garbage collector will need to run a “full” collection. When a full collection is run, not only does it take a considerable amount of time, but the entire JVM has to be paused while the collector runs. It is this “stop-the-world” behavior that causes Tomcat to fail to respond to a request.

Fortunately, there are some strategies which can be employed to mitigate the affects of garbage collections; but first, a quick discussion about performance tuning.

# Performance Tuning Basics

The first rule that you need to know: measure, adjust, and measure again. Simply put, measure the performance of your Tomcat instance before you make a change, make one change and then measure the performance of Tomcat after you have made the change. If you follow this pattern, you will always know exactly how the change you made affects the performance of your Tomcat instance.

One tip, which will help to make your measurements more accurate, is to run a load generating tool like JMeter or Selenium on the web applications deployed to your Tomcat instance. Because many garbage collection issues only occur under load, it's important generate some load on your system while you are taking measurements. Not only will this help you to more accurately replicate and test garbage collection issues, but it will also help you to minimize potential problems when you migrate your new garbage collection settings into production.

Now for the second rule: do not blindly apply configuration settings to your Tomcat instance. Just because a setting is mentioned in this or any other article does not mean that you can apply it to your configuration without first applying rule number one. It is very important to realize that your Tomcat instance is likely hosting a unique set of applications which in turn have a unique set of memory usage patterns. Because of this, the configuration settings that make one Tomcat instance run blazingly fast could easily cause crippling performance issues for another. What's worse, in practice you won't see such a dramatic change in performance. Instead, what will likely happen is that the performance will change by a smaller, less noticeable amount. So unless you've measured the performance before and after, you may not even know that you've just hurt the performance of your Tomcat instance. Remember: measure, adjust and measure again. Always. No exceptions.

# Measuring Performance

Now that we all know that we need to measure the performance of our Tomcat instances prior to making any changes, that brings up the question, how do we measure the performance? It depends on what is important to your application. For some applications, individual response time may be important, while others will value throughput (i.e. how many requests Tomcat can process over some interval). For the purposes of this article, we are going to to look at something more specific to the JVM, garbage collection performance.

Garbage collection performance is a good metric to use both because it can heavily impact things like response time and response throughput and because it's easy to measure, even in a production system. To measure the performance of garbage collection we simply enable garbage collection logging.

This is done by adding the following JVM options to the CATALINA_OPTS variable in the bin/ setenv.sh|bat file for your Tomcat instance.

  *  `-Xloggc:$CATALINA_HOME/logs/gc.log` or   `Xloggc:%CATALINA_HOME%/logs/gc.log`
  *  `-XX:+PrintHeapAtGC`
  *  `-XX:+PrintGCDetails`
  *  `-XX:+PrintGCTimeStamps`
  *  `-XX:-HeapDumpOnOutOfMemoryError`

Once these options are added and Tomcat is restarted, you should see a file `logs/gc.log` which will contain logging statements from the garbage collector. In that log file, you should see lines like the following:

`1.612: [GC [PSYoungGen: 12998K->1568K(18496K)] 12998K->1568K(60864K), 0.0054130 secs] [Times: user=0.01 sys=0.00, real=0.00 secs]`

These indicate at what point in time the garbage collection occurred, the memory statistics for the heap at the point in time when garbage collection ran, and how much time it took for the garbage collection to run. Alternatively, you could see a line like this:

`1.617: [Full GC (System) [PSYoungGen: 1568K->0K(18496K)] [PSOldGen: 0K->1483K(42368K)] 1568K->1483K(60864K) [PSPermGen: 9458K->9458K(21248K)],0.0294590 secs] [Times: user=0.02 sys=0.00, real=0.03 secs]`

This line has essentially the same information, however it is indicating that a full garbage collection has taken place (i.e. “Full GC” rather than just “GC”) and because of this it is showing memory statistics for the old generation and the permanent generation, in addition to the young generation which is normally displayed.

From this log we can now track how often garbage collections are occurring, how often full garbage collections are occurring and the execution time of a garbage collection. It is with these metrics in mind that we try to tune our Tomcat instance. Continue to modify your configuration and remeasure your performance over and over again until you have reached the goal of having both a minimal number of garbage collections and a minimal amount of time spent on garbage collections.

In the [next post](../tomcat-tuning), we'll talk further about performance tuning the JVM, including a discussion on some of the JVM options that are commonly used and a discussion on the different collectors which are available.
