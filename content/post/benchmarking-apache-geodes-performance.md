---
authors:
- helena
categories:
- Performance
- Apache Geode
- AWS
- Java
- Testing
date: 2019-12-03T17:16:22Z
draft: false
short: |
  Measuring and Improving Performance for a Faster Geode 1.10
title: Benchmarking Apache Geode's Performance
---

## Measuring Geode's Performance
[Apache Geode&trade;](https://geode.apache.org/) is an in-memory data grid that provides real-time, consistent access to data-intensive applications throughout widely distributed cloud architectures. Data is distributed throughout the cluster, consisting of servers, locators, and clients. Servers are responsible for hosting data, while locators are responsible for directing the requests from the clients. Due to the distributed and real-time nature of Geode deployments, performance is important - so what is Geode’s performance?
 
Geode’s performance is shown in figure 1, with average throughput in operations per second on the vertical axis and four different performance tests on the horizontal axis. The graph shows that PartitionedGetBenchmark, when testing Geode 1.9.0, had an average throughput of 200,000 operations per second.

{{< responsive-figure src="/images/GeodeBenchmarkFigure1.png" class="center" alt="Figure 1: Geode 1.9.0 Average Throughput by Test (in average operations per second) - PartitionedGetBenchmark 203,855; ReplicatedGetBenchmark 244,463; PartitionedPutBenchmark 181,655; ReplicatedPutBenchmark 207,697" caption="Figure 1 - Geode 1.9.0 Throughput" >}}

But what does that mean? Is 200,000 a good throughput for this test deployment? Is the performance consistent and accurate? Has it improved or regressed since the previous version? And perhaps most importantly, can it be better?


## How is Performance Measured?
To answer those questions, we must first ask: how is Geode benchmarked? When we started replacing the previous bare-metal performance testing of Geode, we had several goals for the project, many of which have already been accomplished. You can run performance tests on demand against any revision of Geode (released or in development), on an AWS cluster, or on any development machine. You can also run benchmarks from Concourse CI pipelines. We enabled running with a profiler attached for use in debugging performance bottlenecks. And finally, you can compare any two runs of benchmarks for changes in performance.

While the benchmarks currently enable users to understand the performance of a cluster, there are still a few goals in progress. The first goal is to increase community engagement with benchmarks. Community members like you can run benchmarks to understand the performance impact of your configurations (as an operator) or code changes (as a developer). Community members can also create your own benchmark tests, helping to increase coverage over Geode. Increasing this test coverage is another ongoing effort. Finally, data visualization of benchmark data is still in progress.

Our current [portfolio of tests](https://github.com/apache/geode-benchmarks/blob/develop/README.md), paired with various configuration options in Geode, cover many of the common workloads that are used in deployments. This post focuses on the results of four of the benchmarks that cover the simplest and most common operations in Geode:
* ReplicatedGetBenchmark
* ReplicatedPutBenchmark
* PartitionedGetBenchmark
* PartitionedPutBenchmark

Current configuration options are:
* With/without SSL
* With JDKs: 8, 9, 10, 11, 12, 13
* With/without SecurityManager enabled
* With Garbage Collectors: CMS, G1, Z, Shenandoah

The benchmarks are driven from the client side, performing operations against the cluster as fast as possible. Latency and throughput are measured throughout the test and then analyzed to calculate the average, standard deviation, and 99th percentile. The tests, by default, are run for five minutes, with a one-minute warm-up period. The cluster is comprised of one locator, two servers, and the client. The servers have a region (either partitioned or replicated depending on the test), which is pre-populated with data before starting the test phase.

## How Can Performance Be Improved?
The first step towards fixing performance issues is finding them. Using a profiler, we can look for several different kinds of hotspots. Monitor locks, thread park/unpark reentrant locks, and excessive allocations/garbage collection (GC) are all good places to start looking for bottlenecks. Other things to look for include:
* Overuse of synchronization
* Getting a system property in a hot path
* Lazy initialization of objects in a hot path
* Synchronization on a container, such as a hash map. 
Examples of some of these are covered later in this post.

Let’s focus on a specific example of a performance refactor, starting with the reason that we were even looking for a bottleneck. When the benchmarks were run, the stats showed us that none of the hardware was being saturated, but when running with a profiler, no hot spots were showing up. This seemed immediately suspect, since an absence of bottlenecks meant we should be using all of our CPU to do operations. Eventually, we found the secret profiler option that shows the zero-time reentrant locks. This exposed Thread.park() as a hotspot, with callers of reentrant lock and the connection pool. Further investigations showed that the connection pool was holding a reentrant lock in a hot path while using a deque.

{{< responsive-figure src="/images/GeodeBenchmarkFigure2.png" class="center" alt="Figure 2: Geode 1.9.0 Throughput Scaling by number of threads - a bar graph showing that the throughput with 2 threads is approximately 2000. The throughput scales evenly to 32 threads (throughput of approximately 20000). With 72 and 144 threads the throughput decreases." caption="Figure 2 - Geode 1.9.0 Throughput Scaling by Number of Threads" >}}

Through further benchmarking of Geode 1.9.0 with different numbers of client threads performing get operations on the cluster, we found that the throughput only scaled to 32 threads before decreasing for higher thread counts (figure 2). Since this was run on a 36 vCPU AWS instance, we did not expect to see decreasing performance at such low thread counts. This issue is caused by the connection pool’s lack of support for a sufficient number of concurrent operations.

{{< responsive-figure src="/images/GeodeBenchmarkFigure3.png" class="center" alt="Figure 3: Profile of Geode 1.9.0's executeOnServer callstack - Profiler output shows that ConnectionManagerImpl.borrowConnection() and ConnectionManagerImpl.returnConnection() both call ReentrantLock.lock(), which is responsible for 48% and 47% respectively of the time spent in the executeOnServer method." caption="Figure 3 - Profile of Geode 1.9.0's executeOnServer" >}}

The profiler shows where in the code the bottleneck was occurring (figure 3). Every operation that is executed on the server results in one call to ConnectionManagerImpl.borrowConnection and one call to ConnectionManagerImpl.returnConnection (highlighted in green), both of which get a reentrant lock (highlighted in blue). This lock is responsible for almost half of the time spent in these two methods. This is the cause of the taper in performance shown in figure 2. As the thread count increases, contention for the lock increases as operations borrow and return connections concurrently, resulting in a bottleneck.

{{< responsive-figure src="/images/GeodeBenchmarkFigure4.png" class="center" alt="Figure 4: ConnectionManagerImpl - Code snippet of the variable definitions at the top of the ConnectionManagerImpl class. Two arrows highlight the definition of an ArrayDeque of PooledConnection to hold the available connections, and a ReentrantLock." caption="Figure 4 - ConnectionManagerImpl" >}}

The profiler points us to a specific location in the code, shown in figure 4. This is a pared-down version of the ConnectionManagerImpl, which implements the ConnectionManager. In this class, available connections are being stored in a deque (the first arrow in figure 4). Because the deque is not a thread safe structure, a reentrant lock (the second arrow in figure 4) is used when accessing the deque. The places where this lock is used, in borrowConnection and returnConnection, are the bottlenecks we were seeing in the profiler. 

{{< responsive-figure src="/images/GeodeBenchmarkFigure5.png" class="center" alt="Figure 5: borrowConnection implementation locking - Long code snippet with 6 collapsed sections of code. An arrow spanning the majority of the snippet highlights that all that code is between locking and unlocking. A second arrow points to an await while holding the lock." caption="Figure 5 - borrowConnection implementation with locking" >}}

Figure 5 shows one of the two implementations of borrowConnection. One of these implementations returns an available connection to any server, and the other returns an available connection to a specific server. Both implementations of borrowConnection, as well as the implementation of returnConnection have the same issue with locking, so this post will focus on the server-specific implementation of borrowConnection. 

In this implementation, the reentrant lock is held for a significant portion of the method, while the deque is being traversed. The arrows on the left of the image show that the lock is held for a long time. In the middle of holding that lock, there is an await (the arrow on the right of the image). The await causes the thread to be paused until the condition has been met and a signal is received. During this time, the lock is returned. This means that it must reacquire the lock before the thread can continue, further delaying the return of a connection to the caller. In the worst case, this delay is the duration of the timeout provided to the await, plus the time it takes to reacquire the lock, with contention.
 
Between the profiler and the code, we can be very confident that this area of the code is a significant bottleneck, but how can we fix it? The first part of the solution is to replace the deque in the connection manager with a more appropriate structure. Since we also want to test this code, let’s introduce some modularity into the code and extract all of the behavior related to the available connections to be moved into another class called the AvailableConnectionManager. The implementation of this class also allows us to get rid of the lock in the connection manager, resulting in the implementation of ConnectionManagerImpl shown in figure 6.

{{< responsive-figure src="/images/GeodeBenchmarkFigure6.png" class="center" alt="Figure 6: Refactored ConnectionManagerImpl - Code snippet of ConnectionManagerImpl, with a line highlighted showing that a new class has been introduced, called AvailableConnectionManager." caption="Figure 6 - Refactored ConnectionManagerImpl" >}}

{{< responsive-figure src="/images/GeodeBenchmarkFigure7.png" class="center" alt="Figure 7: AvailabeConnectionManager, extracted from ConnectionManagerImpl - Code snippet showing the method signatures in the AvailableConnectionManager. These are: public PooledConnection useFirst(); public boolean remove(PooledConnection); public PooledConnection useFirst(Predicate<PooledConnection>); public void addFirst(PooledConnection, boolean); public void addLast(PooledConnection, boolean); private void passivate(PooledConnection, boolean). The class also defines a Deque<PooledConnection> to store the connections." caption="Figure 7 - AvailableConnectionManager, extracted from ConnectionManagerImpl" >}}

Figure 7 shows the implementation of the AvailableConnectionManager, extracted from the ConnectionManagerImpl. In this implementation, the deque has been replaced with a concurrent linked deque. The linked nature of the deque does cause some performance hits due to the need to allocate and garbage collect the nodes. However, this structure relies on compare and swap for a lock-free implementation, making the ConcurrentLinkedDeque the ideal choice for this implementation. The benefit gained from being lock-free far outweighs the slowdown from allocations and GC.

{{< responsive-figure src="/images/GeodeBenchmarkFigure8.png" class="center" alt="Figure 8: Refactored borrowConnection without locks - Code snippet showing that borrowConnection uses no locks, instead calling useFirst() on the AvailableConnectionManager." caption="Figure 8 - Refactored borrowConnection without locks" >}}

With those changes in mind, we can now take a look at the refactored implementation of borrowConnection. Figure 8 shows that borrowConnection is now lock-free, instead calling the useFirst method on the AvailableConnectionManager. This keeps all of the logic for manipulating the list of available connections in the AvailableConnectionManager.
 
{{< responsive-figure src="/images/GeodeBenchmarkFigure9.png" class="center" alt="Figure 9: AvailableConnectionManager.useFirst() - code snippet that shows the useFirst method. The method no longer uses any locks, instead using ConcurrentLinkedDeque.removeFirstOccurence()." caption="Figure 9 - AvailableConnectionManager.useFirst()" >}}

If we look at the logic in useFirst, shown in figure 9, we can see that there are still no reentrant locks used. Instead, ConcurrentLinkedDeque.removeFirstOccurence() is called. Since this method is thread-safe and lock-free, a sufficiently large pool of connections should result in continued scaling of throughput well past 32 threads on the client.

{{< responsive-figure src="/images/GeodeBenchmarkFigure10.png" class="center" alt="Figure 10: Profiler results for refactor - Profiler callstack shows that the borrowConnection and returnConnection methods only account for 1% and 0% respectively of the time spent in the execution on the server." caption="Figure 10 - Profiler Results for Refactor" >}}

The new implementations of ConnectionManagerImpl and AvailableConnectionManagerImpl have been thoroughly tested at every level – beyond the familiar unit and integration testing. The use of a profiler is instrumental for finding hotspots. Using the same process as used in finding the bottleneck, a profiler can be attached while running benchmarks to see if any of the old hot spots are still there, or if any new ones have appeared. Figure 10 shows that the borrowConnection and returnConnection methods are no longer hot spots and no longer call ReentrantLock methods. This gives us good confidence that no new hot spots have been introduced by this refactor.

The next type of test run against this refactor is distributed testing. Distributed tests show how the connection manager behaves in a real Geode cluster. A cluster is spun up in several VMs and operations are run, causing connections to be created and destroyed, borrowed and returned. The results of these operations are compared against the expected results. This ensures that this refactor behaves as expected when running with the rest of the system.
 
In addition to testing the system as a whole, we wanted to ensure that there were no concurrency issues within the refactored ConnectionManagerImpl, as well as with the extracted AvailableConnectionManager. To that end, concurrency tests were added for these classes. In concurrency testing, an executor is given multiple threads to run in parallel, applying pressure to the connection manager to test that certain timings do not result in concurrency issues. This also allows us to test how the code behaves with contention for connections.

{{< responsive-figure src="/images/GeodeBenchmarkFigure11.png" class="center" alt="Figure 11: Geode Average Throughput Before and After Connection Pool Refactor (in average operations per second) - before refactor 197,686; After refactor 659,980" caption="Figure 11 - Average Throughput Before and After Refactor" >}}

{{< responsive-figure src="/images/GeodeBenchmarkFigure12.png" class="center" alt="Figure 12: Geode 1.10.0 Throughput Scaling by Number of Threads - bar graph of throughput by number of threads doubling from 2 to 512. At 2 threads the throughput is very low, then doubles with each doubling of threads, up to 32 threads. After that, the throughput increases slightly more slowly, before tapering at 512 threads." caption="Figure 12 - Throughput by Number of Threads for Refactored Connection Pool" >}}

The final type of testing that was done on this refactor is performance testing. The results of the performance tests are shown in figure 11. This graph compares the throughput of the commit prior to the refactor, with the committed refactored code. It shows a 239% increase in performance due to this single commit. Additionally, we could see by looking at the Geode stats that the CPU of the client was saturated when running with the refactored connection manager. Finally, figure 12 shows that the scaling of throughput now continues well past the 32 threads at which it tapered off using the old connection pool. With the new connection pool, it takes until 512 threads for scaling to slow at all. This shows that the new implementation not only provides better throughput than the original at moderate thread counts, but also behaves much better under high contention.

## Measuring the Performance Improvement From Geode v1.9 to v1.10

{{< responsive-figure src="/images/GeodeBenchmarkFigure13.png" class="center" alt="Figure 13: Geode 1.9.0 versus 1.10.0 Average Throughput by Test (in average operations per second) - PartitionedGetBenchmark 203,855/692,725; ReplicatedGetBenchmark 244,463/736.022; PartitionedPutBenchmark 181,655/357,507; ReplicatedPutBenchmark 207,697/372,430" caption="Figure 13 - Apache Geode 1.9.0 versus 1.10.0 Throughput" >}}

{{< responsive-figure src="/images/GeodeBenchmarkFigure14.png" class="center" alt="Figure 14: Apache Geode 1.9.0 versus 1.10.0 Latency (in nsec) - PartitionedGetBenchmark 1,764,765/518,534; ReplicatedGetBenchmark 1,471,434/488,051; PartitionedPutBenchmark 1,980,392/1,005,730; ReplicatedPutBenchmark 1,731,946/965,404" caption="Figure 14 - Geode 1.9.0 versus 1.10.0 Latency (in nsec)" >}}

Figure 13 shows a comparison of throughputs for the two versions, with 1.9.0 in dark purple and 1.10.0 in light purple. There is a significant improvement in throughput in Geode 1.10.0.
 
Additionally, figure 14 shows that there was also a significant reduction in latency between 1.9.0 and 1.10.0. These improvements are largely due to the change in connection pool, but version 1.10.0 includes several other small performance refactors that, together, make a big difference in the performance of Geode.

## Relevant Links and Notes
* Recording of SpringOne presentation on Geode’s Performance: [https://youtu.be/awQ4byzC2LM]
* Apache Geode repo: [https://github.com/apache/geode]
* Benchmark repo: [https://github.com/apache/geode-benchmarks]
* JIRA query for Performance Issues: [https://issues.apache.org/jira/browse/GEODE-7134?jql=project%20%3D%20GEODE%20AND%20labels%20%3D%20performance]
* AWS Machine Info: type - c5.9xlarge; vCPU - 36; Memory - 72GiB; Network – 10 Gbps; EBS bandwidth – 7,000 Mbps
