---
authors:
- dmikusa
categories:
- Tomcat
- Performance
- Migrated Content
date: 2011-11-22T09:13:00+00:00
short: |
  Performance Tuning the JVM for Running Apache Tomcat
title: JVM Tuning for Apache Tomcat
---

This article is the second in a series discussing how to performance tune the JVM to better run Apache Tomcat. In the first article, we discussed the basic basic goals and [how to monitor the performance of your JVM](../tomcat-gc-measurement).

If you have not read the [first article](../tomcat-gc-measurement), I would strongly suggest reading that before continuing with this article. It is important to understand and follow the processes outlined in that article when performance tuning. They will both save you time and prevent you getting into trouble. With that, let's continue.

# Tuning the JVM

At this point we've covered the basics and are ready to begin examining the JVM options that are available to us. Please note that while these options can be used for any application running on the JVM, this article will focus sole only how they can be applied to Tomcat. The usage of these options for other applications may or may not be appropriate.

*Note: For simplicity, it is assumed that you are running an Oracle Hotspot JVM.*

## General Options

### `-Xms` and `-Xmx`

These settings are used to define the size of the heap used by the JVM. `-Xms` defines the initial size of the heap and `-Xmx` defines the maximum size of the heap. Specific values for these options will depend on the number of applications and the requirements of each application deployed to a Tomcat instance.

With regard to Tomcat, it is recommended that the initial and maximum values for heap size be set to the same value. This is often referred to as a fully committed heap and this will instruct the JVM to create a heap that is initially at its maximum size and prevent several full garbage collections from occurring as the heap expands to its maximum size.

### `-XX:PermSize` and `-XX:MaxPermSize`

These settings are used to define the size of the permanent generation space. `-XX:PermSize` defines the initial value and `-XX:MaxPermSize` defines the maximum value.

With regard to Tomcat, it is recommended that the initial and maximum values for the size of the permanent generation be set to the same value. This will instruct the JVM to create the permanent generation so that it is initially at its maximum size and prevent possible full garbage collections from occurring as the permanent generation expands to its maximum size.

At this point, you might be thinking that this seems awful similar to the `-Xms` and `-Xmx` options, and while the concept is the same, “PermGen” or permanent generation, refers to the location in memory where the JVM stores the class files that have been loaded into memory. This is different and distinct from the heap (specified by `-Xms` and `-Xmx`) which is where the JVM stores the object instances used by an application.

One final note, if the PermGen space becomes full (regardless of the availability of memory in the heap) then the JVM will attempt a full garbage collection to reclaim space. This can often be a source of problems for applications which dynamically create or load a large number of classes. Proper sizing of `-XX:PermSize` and `-XX:MaxPermSize` for your applications will allow you to work around this issue.

### `-Xss`

This setting determines the size of the stack for each thread in the JVM. The specific value that you should use will vary depending on the requirements of the applications deployed to Tomcat, however in most cases the default value used by the JVM is too large.

For a typical installation, this value can be lowered, saving memory and increasing the number of threads that can be run on a system. The easiest way to determine a value for your system is to start out with a very low value, for example 128k. Then run Tomcat and look for a StackOverFlow exception in the logs. If you see the exception, then gradually increase the value and restart Tomcat. When the exceptions disappear, you have found the minimal value which works for your deployment.

### `-server`

This setting will select the Java HotSpot Server VM. This will instruct the VM that it is running in a server environment and the default configurations will be changed accordingly.

Note, this option is really only needed when running 32-bit Windows, as 32-bit Solaris and 32-bit Linux installations with two or more CPU's and 2GB or more of RAM will enable this option by default. In addition, all 64-bit OS's have this option enabled by default as there is no 64-bit client VM.

For a comprehensive list of JVM options, please see the article Java HotSpot VM Options.

## Selecting a Collector

For many users, tuning the basic options I mentioned in the previous section will be sufficient for their applications. However, for larger applications or applications which just require larger heap sizes these options may not be sufficient. If your Tomcat installation fits this profile then you'll want to take one further step and tune the collector.

To begin tuning the collector, you need to pick the right collector for your application. The JVM ships with three commonly used collectors: the serial collector, the parallel collector and the concurrent collector. In most cases when running Tomcat, you'll be using either the parallel collector or the concurrent collector. The difference between the two being that the parallel collector typically offers the better throughput, while the concurrent collector often offers lower pause times.

The parallel collector can be enabled by adding `-XX:+UseParallelGC` to `CATALINA_OPTS` or the concurrent collector can be enabled by adding `-XX:+UseConcMarkSweepGC` to `CATALINA_OPTS` (you would never want to have both options enabled). As to which of the collectors you should be using, it is difficult to give a blanket recommendation. I would suggest that you give both a try, measure the results and use that to make your decision.

Once you have selected a collector, it is possible to take one further step and apply some configuration settings which are specific to the collector. That being said, most of the time the JVM will detect and set excellent values for these options. You should not attempt to manually configure these unless you have a good understanding of how the specific garbage collector is working, you are applying rule number one from above and you really know what you are doing. That said, I'm going to talk about two options, one for the parallel collector and one for the concurrent collector.

When you specify the option to run the parallel collector, it will only run on the young generation. This means that multiple threads will be used to process the young generation, but the old generation will continue to be processed by a single thread. To enable parallel compaction of the old generation space you can enable the option `-XX:+UseParallelOldGC`. Note that this option will help the most when enabled on a system with many processors.

When you specify the option to run the concurrent collector, it is important to realize that garbage collection will happen concurrently with the application. This means that garbage collection will consume some of the processor resources that would have otherwise been available to the application. On systems with a large number of processors, this is typically not a problem. However, if your system has only one or two processors then you will likely want to enable the `-XX:+CMSIncrementalMode` option. This option enables incremental mode for the collector, which instructs the collector to periodically yield the processor back to the application and essentially prevents the collector from running for too long.

# Conclusion

Congratulations! If you're reading this then you made it all the way through the article. If you're still a little confused at this point, that is OK and I would say normal. Tuning the JVM and the inner workings of the garbage collectors is not an easy subject.

If you'd like to get some additional information on the subject, I would strongly suggest continuing on with this article from Oracle, [Java SE 6 HotSpot[tm] Virtual Machine Garbage Collection Tuning](http://www.oracle.com/technetwork/java/javase/gc-tuning-6-140523.html). It is very technical and should be able to fill in any of the gaps left from this article.
