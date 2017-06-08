---
authors:
- bsnchan

categories:
- BOSH
- Turbulence
- Cloud Cache

date: 2017-06-07T17:16:57-04:00
draft: false
short: |
  Testing for data consistency on the Cloud Cache team using BOSH and Turbulence

title: Testing for Data Consistency on Cloud Cache using BOSH and Turbulence
image: /images/testing-data-consistency-in-cloud-cache/turbulence-kill-az.png
---

## What is Cloud Cache

The Cloud Cache for Pivotal Cloud Foundry product provides on-demand in-memory data clusters that can be used by app developers in CF. App developers are able to store any kind of data objects in the Cloud Cache cluster provided they are Java-serializable. Cloud Cache uses Pivotal GemFire, the Pivotal distribution of [Apache Geode](http://geode.apache.org).

## CAP Theorem

[CAP theorem](https://en.wikipedia.org/wiki/CAP_theorem) states that it is impossible for a distributed data store to provide more than two our of the three guarantees:

* Consistency
* Availability
* Partition tolerance

Let's take a look at where Cloud Cache for PCF stands with the CAP theorem.

### Cloud Cache and CAP theorem

#### Partition Tolerance

This is accomplished by GemFire's ability to handle network partitioning (by setting the GemFire property `enable-network-partition-detection=true`).

Network partitioning in GemFire is detected by a weighting system - when a GemFire node is spun up, it is given a weight. By default, cache servers have a weight of 10, locators have a weight of 3, and lead members have a weight of 15.

When the membership coordinator calculates the membership weight and notices the quorum of the cluster is no longer sufficient to run as a distributed system, the "losing" side will declare a network partition has occurred and disconnect itself from the higher weighted side. Network partitions can occur if Cloud Cache is deployed to only two AZs and one AZ loses connectivity to the second AZ.

You can go to the official GemFire docs for more information on how GemFire handles networking partitioning [here](http://gemfire.docs.pivotal.io/geode/managing/network_partitioning/network_partitioning_scenarios.html).

#### Consistency

Consistency in GemFire uses different consistency checks depending on the region type that is configured.

For partitioned regions, GemFire maintains consistency by updating keys only on the primary copy of the key. The member holds a lock on the key while distributing updates to the other redundant copies so there is strong consistency.

For replicated regions (meaning a copy on every cache sever), GemFire updates keys on all the nodes without holding a lock on the key. Although it is possible for keys to be updated at the same time, conflict checking will ensure that all the members will be updated with the most recently updated key. This means the data will eventually be consistent as the keys sync across all the cache servers.

You can go to the official GemFire docs for more information on how GemFire handles consistency [here](http://gemfire.docs.pivotal.io/geode/developing/distributed_regions/how_region_versioning_works.html).

#### Availability

Cloud Cache for PCF will attempt to be as highly available as possible by using BOSH's resurrection features. BOSH resurrection monitors all the locator and cache server processes running on the Cloud Cache nodes and will apply the solutions listed below if any of the scenarios mentioned below occurs:

* Restart the locator cache server process if the locator or cache server process is not running.
* Recreate the VM if the VM has dissapeared from the cloud.
* Replace the VM if the VM has become unresponsive.

## What does testing all this look like?

Being an in-memory data service makes testing challenging as you cannot simply update the cluster multiple VMs at a time as this will cause data loss. This can easily happen if more than one node goes offline at a time (this really depends on the number of redundant copies set up and what the eviction algorithm is for a given region). However, even common scenarios such as stemcell upgrades with BOSH's `max_in_flight` property being greater than one can cause data loss. So how do we test this?

As part of our development workflow we run our stress tests against every development build in our Concourse pipeline. Our stress tests consists of the following steps:

1. Create a GemFire partioned region with 2 redundant copies (that means 3 copies total)
2. Create a Cloud Cache service instance that is deployed between at least 3 AZs
3. Push a CF app that is constantly writing keys and values to the created region from step 1.
4. Use [Turbulence](https://github.com/cppforlife/turbulence-release) to do the following:
 * terminate VMs one at a time
 * take down an entire AZ
5. Wait for BOSH's resurrector to resurrect terminated VMs
6. Read all the keys and values written in step 3 and ensure **no data was lost**

### Demo!

The load testing app in this demo has three endpoints: `start`, `stop`, and `generate_report`.

When the `start` endpoint is called, the app will continuously and write data to the bound Cloud Cache service instance.

When the `stop` and `generate_report` endpoints are called, the app will stop the writing and generate a report that reports the number of successful writes and reads. In addition it will ensure **every** key has the expected value that was written.

This looks something like:

```java
while (counter < totalWrites) {
    String key = report.getGuid() + "K" + counter;
    String value = "V" + counter;

    Data data = this.data.findOne(key);

    if (data != null && data.getValue().equals(value)) {
        log.debug("Read. [" + report.getGuid() + "] successfulRead: " + successfulReportTimeReads++);
    } else {
        log.warn("Read. [" + report.getGuid() + "] failedRead: " + failedReportTimeReads++);
    }
    counter++;
}
```

In this demo, after the `start` endpoint is called, we will use turbulence to shutdown all VMs in an entire AZ. You'll be able to see BOSH resurrect the VMs that were destroyed and that there was no data loss.

Below is a video of all this in action!

{{< youtube 7S1GHs4h1rg >}}


Below is a screenshot of what the event looked like in Turbulence. You can see that BOSH found all the VMs in `z2`, the specified AZ, and call `delete_vm` on the those VMs.

{{< figure src="/images/testing-data-consistency-in-cloud-cache/turbulence-kill-az.png" class="center" >}}
