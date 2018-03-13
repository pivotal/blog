---
authors:
- cunnie
categories:
- BOSH
- Logging & Metrics
date: 2018-03-16T20:00:22Z
draft: false
short: |

  It's helpful to know the performance characteristics when selecting a disk
  type for an Infrastructure as a Service (IaaS). In this blog post we describe
  the results of benchmarking various disk types of various IaaSes, including
  Amazon Web Services (AWS), Microsoft Azure, Google Compute Engine (GCE), and
  VMware vSphere. We measure Input/output operations per second (IOPS), read
  throughput, and write throughput.

title: Benchmarking the Disk Speed of IaaSes
---

## 0. Overview

_[Disclaimer: the author works for Pivotal Software, a subsididiary of Dell,
which owns VMware]_

It's helpful to know the performance characteristics of disks when selecting a
disk type. For example, the performance of a database server will be greatly
affected by the [IOPS](https://en.wikipedia.org/wiki/IOPS) of the underlying
storage. Similarly, a video-streaming server will be affected by the
underlying read throughput.

In this blog post we record three metrics:

1. IOPS
2. Write throughput
3. Read throughput

And we record them for the following IaaSes:

1. AWS
2. Microsft Azure
3. Google Compute Engine
4. VMware vSphere

The table below summarizes our findings:

| IaaS      | Disk Type       | IOPS  | Write MB/s | Read MB/s   |
| --------- | --------------  | ---:  | -----:     | ----------: |
| AWS       | standard        | 3505  | 97         | 85          |
|           | gp2             | 5441  | 102        | 92          |
|           | io1             | 1816  | 102        | 93          |
| Azure     | Standard        | 204   | 27         | 15          |
|           | Premium 20 GiB  | 207   | 27         | 15          |
|           | Premium 256 GiB | 1910  | 106        | 89          |
| Google    | pd-standard     | 455   | 86         | 61          |
|           | pd-ssd          | 10205 | 29         | 27          |
| vSphere   | FreeNAS         | 11660 | 101        | 99          |
|           | SATA SSD        | 47555 | 462        | 470         |
|           | NVMe SSD        | 50911 | 1577       | 1614        |

<div class="alert alert-warning" role="alert">

<b>These benchmarks are not gospel.</b> Even though they are recorded precisely,
they are not precise. For example, we report the GCE <i>pd-standard</i> IOPS as
455, which was the average over the course of ten runs, but the actual numbers
fluctuated wildly on any given run — as high as 712 on one, as low as 130 on
another (the standard deviation of the ten runs is a whopping 280). View these
numbers with a healthy dose of skepticism.

<p /><p />

A better use of these benchmarks would be to look for broader trends, e.g.
"GCE's SSD storage has much better IOPS than their standard storage" or
"vSphere's NVMe storage throughput can be as much as three times faster than
their SSD SATA's."

</div>

### 0.0 Take-aways:

- VMware vSphere offers the best disk performance of all the IaaSes;
  however, results should be taken with a grain of salt, for the
  measurements were taken under optimal conditions.
  <sup><a href="#optimal">[Optimal]</a></sup>
  - A VMware vSphere VM with fast Non-Volatile Memory Express (NVMe) local storage
    will dramatically outperform other IaaSes, regardless of storage type.
  - A VMware vSphere VM with SSD SATA (Serial AT Attachment) local storage
    will rival the IOPS of NVMe storage, but fall to a distant second when
    measuring throughput (read MB/s, write MB/s).
  - A VMware vSphere VM with [iSCSI-based](https://en.wikipedia.org/wiki/ISCSI)
    (Internet Small Computer Systems Interface) storage will match the
    performance of the other IaaSes, even one such as ours with a meager
    1 Gbps interface.
    <sup><a href="#freenas">[FreeNAS]</a></sup>
- Azure Premium storage offers little value for smaller disks (e.g. 32 GiB);
  in those cases, go with the less-expensive Standard storage for equivalent
  performance.
- AWS gp2 is a good overall choice; io1 storage is poor value unless one needs
  IOPS and throughput greater than what gp2 storage offers. Per AWS's
  [website](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/EBSVolumeTypes.html),
  _"[io1 should be used for] Critical business applications that require
  sustained IOPS performance, or more than 10,000 IOPS or 160 MiB/s of
  throughput per volume"_

## 1. IOPS Performance

We feel that, in general, IOPS is the most important metric when judging storage
speed: The advent of solid-state drives (SSDs) with their high IOPS
([>10k](https://en.wikipedia.org/wiki/IOPS)) exceeding by traditional hard disk
drives by an order of magnitude or more, was a game-changer.

Below is a chart of the results of the IOPS benchmark. The topmost item is the
fastest:

{{< responsive-figure src="https://user-images.githubusercontent.com/1020675/37372076-c8be8884-26ce-11e8-8bfe-65aded70e084.png" >}}

## 2. Write Performance

Write performance is important for applications which write large datasets:
e.g. disk images, BOSH stemcells, large videos, etc.

Below is a chart of the results of the write benchmark. The topmost item is the
fastest:

{{< responsive-figure src="https://user-images.githubusercontent.com/1020675/37372075-c874a714-26ce-11e8-84a5-1b65d80d3741.png" >}}

## 3. Read Performance

Read performance is important for applications which stream large amounts of
data (e.g. video servers).

We have found the read and write performance similar for a given IaaS/given disk
type-tuple. The chart of read performance below is not much different than the chart
above:

{{< responsive-figure src="https://user-images.githubusercontent.com/1020675/37372074-c808bd7e-26ce-11e8-99ab-467e07850280.png" >}}

## 4. Testing Methodology

We used [BOSH](https://bosh.io/) to deploy VMs to each of the various IaaSes.

We used the following instance types for each of the IaaSes:

| IaaS      | Instance Type   | Cores   | RAM (GiB)   | Disk Type       |
| --------- | --------------- | ------- | ----------- | --------------  |
| AWS       | c4.xlarge       | 4       | 7.5         | standard        |
|           |                 |         |             | gp2             |
|           |                 |         |             | io1             |
| Azure     | F4 v2           | 4       | 8           | Standard        |
|           |                 |         |             | Premium 20 GiB  |
|           |                 |         |             | Premium 256 GiB |
| Google    | n1-highcpu-8    | 8       | 7.2         | pd-standard     |
|           |                 |         |             | pd-ssd          |
| vSphere   | N/A             | 8       | 8           | FreeNAS         |
|           |                 |         |             | SATA SSD        |
|           |                 |         |             | NVMe SSD        |

### 4.0 Cores, Preferably 8

Our overarching goal was to have 8 cores for the vSphere NVMe SSD benchmark. The
reason we wanted so many cores was that the processor, an  [Intel Xeon Processor
D-1537](https://ark.intel.com/products/91196/Intel-Xeon-Processor-D-1537-12M-Cache-1_70-GHz),
which is clocked at a measly 1.7 GHz, became the choke point.

That's right: The Samsung NVMe was so fast that it shifted the choke point from
storage to CPU — we were no longer benchmarking the SSD; we were benchmarking
the CPU!

This problem was caused by three factors: slow clock speed, fast disk, and a
single-threaded filesystem benchmark program
([bonnie++](https://www.coker.com.au/bonnie++/)).

Curiously, we weren't the first to discover that bonnie++, in certain
configurations, may artificially cap the performance of the filesystem: in his
most-excellent blog post _[Active Benchmarking:
Bonnie++](http://www.brendangregg.com/ActiveBenchmarking/bonnie++.html)_, Brendan
Gregg concludes, in his summary:

> This test [bonnie++] is limited by: CPU speed ... and by the fact that it is single-threaded.

Our first clue that something was amiss was that the our initial benchmark gave
baffling results — the Crucial SATA, which should have been slower than the
Samsung NVMe, was instead faster.

| Metric     | Samsung NVMe<sup><a href="#samsung">[Samsung]</a></sup> | Crucial SATA<sup><a href="#crucial">[Crucial]</a></sup> |
| ----       | -----------:                                            | ---------:                                              |
| IOPS       | 981                                                     | 14570                                                   |
| Write MB/s | 180                                                     | 405                                                     |
| Read MB/s  | 395                                                     | 526                                                     |

_[Note: Although the read and write throughput numbers could be ascribed to
difference in the CPU frequency, the IOPS number are off by more than an order
of magnitude, so we suspect some other factor may be at work.]_

We were at a crossroads: our benchmarking tool, bonnie++, wasn't able to
properly benchmark our NVMe storage, but we didn't want to omit those results
from our blog post, so we decided to do what any self-respecting developer would
do: write our own filesystem benchmark tool!

We wrote [GoBonnieGo](https://github.com/cunnie/gobonniego), A Golang-based
filesystem benchmark tool which uses concurrency to run on as many CPU cores as
available. Through experimentation, we found that four cores wasn't enough to
benchmark the Samsung NVMe (all four CPUs were at 100% utilization), but that
six cores was. Six, however, is not a power of two, so we rounded up to 8 cores.

### 4.1 RAM: 4 - 8 GiB

We wanted 4-to-8 GiB RAM, dependent on what the IaaS allowed us. The amount of
data written for each benchmark was twice the size of physical RAM, so VMs with
twice the RAM should have no added advantage ([buffer
cache](https://www.tldp.org/LDP/sag/html/buffer-cache.html) notwithstanding).

### 4.2 Disk: 20 GiB

We chose to run our test on the [BOSH persistent
disk](https://bosh.io/docs/persistent-disks.html), for it was more flexible to
size than the root disk. We chose a disk size of 20 GiB, with the exception of
Azure, where we ran a second benchmark with a disk of 256 GiB.

## 5. Methodology Shortcomings

We wrote our own benchmark program; it may be grossly flawed.

Each benchmark (e.g. AWS gp2) was taken on one VM. That VM may have been on
sub-optimal hardware or suffered from the ["noisy
neighbor"](https://en.wikipedia.org/wiki/Cloud_computing_issues#Performance_interference_and_noisy_neighbors)
effect. The large standard deviation of the GCE _pd-standard_ disk may have been
the result of a noisy neighbor.

Each benchmark was only taken in one datacenter (region); there may be
differences in performance between datacenters. A more comprehensive benchmark
would collect data from many regions:

- AWS benchmark was taken in N. Virginia, _us-east-1_
- GCE benchmark was taken in Council Bluffs, Iowa, _us-central1_
- Azure benchmark was taken in Singapore
- vSphere is not a public cloud, so the location is irrelevant, but the
  benchmark was taken in San Francisco

The time that a benchmark was taken may make a difference. A benchmark taken at
3:30am on a Sunday may have better results than a benchmark taken at 10:30am on
a Monday. A more comprehensive benchmark would consist of many tests taken at
different times. Our benchmarks were done on Sunday night, but it may have
adversely affected the Azure test, which was in Singapore, and was Monday
morning there.

We only selected one instance type for each IaaS (e.g. AWS's c4.xlarge). Running
our benchmark across many instance types may show interesting results.

We didn't cover _all_ the volume types; for example, we did not benchmark AWS's
st1 (Throughput Optimized HDD) or sc1 (Cold HDD) volume types. We only tested
AWS's gp2 and io1.

## References

* [GoBonnieGo](https://github.com/cunnie/gobonniego) filesystem benchmark tool
* Benchmark configuration: BOSH Cloud Configs and manifests: <https://github.com/cunnie/deployments/tree/master/gobonniego>
* Benchmark results (raw JSON files): <https://github.com/cunnie/freenas_benchmarks/tree/master/gobonniego>
* Google Sheet containing summarized benchmark results and graphs: <https://docs.google.com/spreadsheets/d/1elngT-eHr5_RVyoPj1UKkr-7eveCw_JNXPlVFo6ECvs>

## Footnotes

<a id="optimal"><sup>[Optimal]</sup></a>
The vSphere benchmark runs suffered almost no disk contention from 40+ VMs
running on the same hardware, making the vSphere results optimal.

Below are screenshots of the disk usage on the two physical machines (ESXi
hosts) on which ran the VMs which ran the benchmarks (the benchmarks were not
running when these screenshots were taken). Note that the peak disk usage was
3.6 kBps. To put that into perspective, the slower (SATA, not NVMe) vSphere disk
throughput for write was 462 MBps: based on these charts, the disk usage from
the other, non-benchmark VMs degraded the results of the benchmark by, at most,
0.008%. In other words, rather than suffering from "noisy neighbors", the
vSphere neighbors were quiet. Dead-quiet. The benchmark VMs had the underlying
storage hardware almost completely to themselves.

{{< responsive-figure src="https://user-images.githubusercontent.com/1020675/37519840-ef6a3f54-28d7-11e8-918a-7612beee1ea4.png" >}}

{{< responsive-figure src="https://user-images.githubusercontent.com/1020675/37519846-f4e7e8be-28d7-11e8-9536-afe3ef6301a5.png" >}}

<a id="freenas"><sup>[FreeNAS]</sup></a>
Our iSCSI-based FreeNAS setup has been described in two blog posts
([here](https://content.pivotal.io/blog/a-high-performing-mid-range-nas-server)
and
[here](https://content.pivotal.io/blog/a-high-performing-mid-range-nas-server-part-2-performance-tuning-for-iscsi)),
so we will not go into details other than to mention the network interface is 1
Gbps link, not a 10 Gbps link, which caps the throughput to ~100 MB/s. In other
words, with a higher-speed Network Interface Controller (NIC) we could expect
faster throughput. Indeed, we ran our benchmark locally on the FreeNAS server,
and our throughput was ~200 MB/s, which is fast, but will never approach the
throughput of the NVMe (~1500 MB/s) or even the SATA (450 MB/s); however, what
the FreeNAS offers that the NVMe and the SATA don't is redundancy: a disk
failure on the FreeNAS is not a calamitous event.

<a id="azure_disk"><sup>[Azure Premium]</sup></a>
Azure allocates increased performance with disk size for its Premium Managed
Disks (<https://azure.microsoft.com/en-us/pricing/details/managed-disks/>) — in
other words, Azure specifies a 32 GiB disk will get you 120 IOPS and 25 MB/s
throughput, and a 256 GiB disk will get you 1,100 IOPS and 125 MB/s throughput.

We took that into account — we benchmarked the Azure Premium Managed Disk with a
sizes of both 20 GiB (the standard for our benchmark) and 256 GiB, with the
understanding the results for Azure Premium are inherently flawed — we could
have made the results better by benchmarking an even-bigger disk, or worse with
a smaller.

Why 256 GiB? It was big enough to demonstrate Azure's Premium's superiority
to Azure Standard, but not too big to be uncommon.

<a id="samsung"><sup>[Samsung]</sup></a>
The [Samsung SSD 960 2TB M.2 2280
PRO](http://www.samsung.com/semiconductor/minisite/ssd/product/consumer/ssd960/)
is installed in a [Supermicro
X10SDV-8C-TLN4F+](http://www.supermicro.com/products/motherboard/Xeon/D/X10SDV-8C-TLN4F_.cfm)
motherboard with a soldered-on 1.7 GHz 8-core [Intel Xeon Processor
D-1537](https://ark.intel.com/products/91196/Intel-Xeon-Processor-D-1537-12M-Cache-1_70-GHz),
and 128 GiB RAM.


The results of the _CPU-constrained_ bonnie++ v1.97 benchmarks of the Samsung
960 PRO are viewable
[here](https://github.com/cunnie/freenas_benchmarks/blob/9ecd5736db87902ee955f096012c39527f778ef5/bonnie%2B%2B_1.97/vsphere_nvme.txt#L4).

Below is a photo of the Samsung NVMe mounted in the Supermicro motherboard:

{{< responsive-figure src="https://lh3.googleusercontent.com/CD6DLntvhwM6T8toGYVJ3spQKrdofD14_pOZ10xyAxrFuRJx_SbMJj1pB9cnV_KQLXRM_w0HVU3JCKwHEaDjKOUILyMbQz7RlPYJosxTJeWJYb4hA7bmIdCBhVs41erlgIC6-DeK_dh4ln6aPzOebhxIwCDOTGVPE_tSJNS17ozPg1a70uBZqA9zpTUXQ6YN3u6LoQ0mWyq4a1uOTSuAd9RiVSVsyRB-ZInN8gESgWLQGyEID2yjQ8shqCHSruf8JOocGqOcq78d-4UYpp0NWvlpnoCuY0aQISttWiV2dxYkEVEyW7Feq_ovfhBSUft7qCO9EpQTRW2gBQnrUDslFb-JUbtG4tP7--tRPyafeHxW8dW5irVL7SA8aAWRtWreaGoTf9QxsHae9chTf29nc1e8RGzXmIUG6tLn9iliFYPblUGpevN-tNc2YuskA6fporufbu4oa5F1V0ISoe29YoR68s0dlN2SDSMG28EREgFaZWXiDIi_GNZ_VSGi5rof6XAyHWuASnyyoJuFLNlqth7Cpx_MlqIG9_9o2v4jfoMgKuWNvnfhsj7bdK3GegRd7FYJw7VBGJ-x7j3f2IEO7_bdT3t3TO6esThMM2gL=w2290-h1134-no" >}}

<a id="crucial"><sup>[Crucial]</sup></a>
The [Crucial MX300 1TB M.2 Type 2280 SSD](http://www.crucial.com/usa/en/storage-ssd-mx300) is installed in an [Intel Skull Canyon](https://www.intel.com/content/www/us/en/nuc/nuc-kit-nuc6i7kyk-features-configurations.html) which features a 2.6 GHz 4-core [Intel Core i7-6770HQ](https://ark.intel.com/products/93341/Intel-Core-i7-6770HQ-Processor-6M-Cache-up-to-3_50-GHz) and 32 GiB RAM.

The results of the bonnie++ v1.97 benchmarks of the Crucial MX 300 are viewable
[here](https://github.com/cunnie/freenas_benchmarks/blob/9ecd5736db87902ee955f096012c39527f778ef5/bonnie%2B%2B_1.97/vsphere_sata.txt#L4).

The photograph below shows the Crucial SSD, but astute observers will note that
it's not the Skull Canyon motherboard (it isn't) — it's the Supermicro
motherboard.

{{< responsive-figure src="https://lh3.googleusercontent.com/ePgrw43fR6l_Q48GohVVDA44S3SX9VdB1iraiDjdlNRW9lGKhp3zJbpyNmYSOX54wPc3SL370ClEIplGqDFeIil7NOnHq96CQfRtdMALC3onYmjTBGxTTX36G3uMujOBEApI_n_qX1qDq3VVyA6tnXUTTa3e4bcHlGpL1y_EZp98zQ33Hv6dI2KrqEtrhb4Cz8u3gBQ_g5EjM-T4hOP6x4PDn3mEhFe996MB8sMSBfkfpC3b4R0ulyUFuJ3HgQUcpkBUM3xLX46Y2J6_NA-2kkh1CfLFVholSvxU9Ux6NafgnJ-Y3Dw_G6Nd38u8N45plV9NXpkTxL-3gO7UDUPrA5q9HJERpFwyvPUO18ex0mr8IcAuvnGHHMkBWGkPUTndAF5d47KQrHouB1mxv2uu7g7rnTTevpkAM9iqr0KrtjODFaszxpQ_KFnL4KzzZTbCYOt995pkAv0VR0aHXCiyL1oSX1O85bATIXlkJ50Mz3y16xFO9mBZdqdJZmSg8U2AWCaKSMyz3-WcfBCzvELA1CxuyjnRCiEbAu7QVKrDQ-_b-txQsiH4RPvonRNTcodfyttQORBYU4BebWmDzu0Az3r9VcrmJAuz0cdhOOmO=w2290-h1016-no" >}}
