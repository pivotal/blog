---
authors:
- mthomas
categories:
- Tomcat
- Troubleshooting
- Migrated Content
date: 2013-03-13T10:46:45Z
short: |
  It is late on a Friday afternoon, and your web application has stopped responding to requests. The server is still
  reachable, and the Apache Tomcat process is still running–there are no errors in the logs. You want to go home but
  you can’t until it is fixed. What do you do?
title: Hanging by a Thread
---

If your answer is “restart Tomcat and hope it stays up until Monday,” then this article is for you.

Rather than keeping your fingers crossed and hoping you don’t get an angry call from your boss over the weekend, this
article will provide you with some simple steps you can take to diagnose the problem. 

## Step 1: What is Tomcat Doing? Thread Dumps Begin to Answer the Question

If the Tomcat process is running, then it must be doing something. The question is what is it doing when it should be
responding to requests? The way to answer that question is with a thread dump–actually, a series of thread dumps. You
need to take three thread dumps roughly 10 seconds apart and then compare them. I always compare them with a diff tool
rather than by eye - it is far too easy to miss subtle but important differences between the dumps.

How you generate a thread dump depends on your operating system and how you are running Tomcat. On Linux, FreeBSD,
Solaris etc. use `kill -3` to trigger a thread dump. On Windows use `CTRL-BREAK` if Tomcat is running in a console
window. If Tomcat is running as a service, then the service wrapper should provide a way to trigger a thread dump.
Commons Daemon (the service wrapper that ships with Tomcat) provides an option to trigger a thread dump via the system
tray icon.

Thread dumps are written to standard out. One of the many reasons for not writing standard out to application logs is
because the thread dumps can be much harder to extract. For the same reason, it is a really bad idea to redirect
standard out to /dev/null. Extract your thread dumps into separate files, and you are ready to start examining them.

## Step 2: Examining the Thread Dumps

First of all, look at dump1 and search for the word deadlock. If you have a deadlock, the thread dump will tell you.
It will also point out which threads are involved in the deadlock. Deadlocks are caused when multiple threads try and
obtain the same set of locks in different orders. Deadlocks are usually an application issue, sometimes a [library
issue](http://markmail.org/message/j4c3mro4qxlykv7z) and rarely a Tomcat bug. If you find a deadlock then the only
option to resolve it is to restart Tomcat. There
is usually nothing you can do to prevent a deadlock from reoccurring. A fix will require code changes.

If you don’t have any deadlocks, then the next step is to compare the first and second thread dumps. The thread dump
shows all the threads within the JVM including those created by the JVM. The threads you are most likely to be
interested in are those related to handling HTTP or AJP requests and will be named `<protocol>-<type>-<port>-exec-<id>`.
`<protocol>` will be “ajp” for AJP connectors and “http” for HTTP connectors. `<type>` will be one of “bio”, “nio”,
"nio2" or “apr” and `<port>` will be the port the connector is listening on. `<id>` is a unique ID allocated to each
thread that starts at one and increments for each new thread created for the connector. You may see a large number
of threads that look similar to this:

```none
"http-nio-8080-exec-9" daemon prio=6 tid=0x00000000151fc800 nid=0xc68 waiting on condition [0x00000000199af000]
java.lang.Thread.State: WAITING (parking)
at sun.misc.Unsafe.park(Native Method)
- parking to wait for <0x00000007ad6e1ea0> (a java.util.concurrent.locks.AbstractQueuedSynchronizer$ConditionObject) 
at java.util.concurrent.locks.LockSupport.park(LockSupport.java:186)
at java.util.concurrent.locks.AbstractQueuedSynchronizer$ConditionObject.await (AbstractQueuedSynchronizer.java:2043)
at java.util.concurrent.LinkedBlockingQueue.take(LinkedBlockingQueue.java:442)
at org.apache.tomcat.util.threads.TaskQueue.take(TaskQueue.java:104)
at org.apache.tomcat.util.threads.TaskQueue.take(TaskQueue.java:32)
at java.util.concurrent.ThreadPoolExecutor.getTask(ThreadPoolExecutor.java:1068)
at java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1130)
at java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:615)
```

This is an idle thread waiting for a request to process. It is normal to see a number of these in the stack trace.
The one case where they can indicate a problem is if you see the same number of AJP threads as you have maxThreads
configured for your AJP connector. That may be an indication of thread starvation as AJP uses persistent connections.
You typically need to have at least as many threads available to your AJP connector as you have maximum concurrent
requests configured in your reverse proxy.

## Step 3: Identifying Root Cause

Normally, you need to focus on threads that include application calls. What you are looking for is a thread that is
processing a request, and it hasn’t changed from one thread dump to the next. Once you have found such a thread,
you’ll need to look at the source code for your application to figure out what might be causing that thread to hang.
There was a [nice example](http://markmail.org/message/yedaxbmtd2zqrdg4) on the Tomcat users mailing list recently.i
In this thread dump, there is only one thread in application code - `http-bio-8080-exec-10`. That thread is in a call
to `org.apache.commons.pool.impl.GenericObjectPool#borrowObject()` which is very suggestive. It looks like the
application is hanging — it is waiting to borrow a database connection from the pool - but the pool is empty. This
scenario suggests root cause — a connection leak somewhere in the application. If you enable logging for abandoned
connections, you should identify the source of the leak fairly quickly.

Of course, issues vary from application to application, but the general troubleshooting process is the same. When an
application hangs, take three thread dumps roughly 10 seconds apart. Then, check for deadlocks following by
application threads that haven’t moved on from one thread dump to the next. If you need help interpreting the thread
dump, the Tomcat user mailing list is always willing to help.
