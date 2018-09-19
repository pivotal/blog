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

_[Disclaimer: the author works for Pivotal Software, of which Dell is an
investor. Dell is also an owner of VMware]_

It's helpful to know the performance characteristics of disks when selecting a
disk type. For example, the performance of a database server will be greatly
affected by the [IOPS](https://en.wikipedia.org/wiki/IOPS) of the underlying
storage. Similarly, a video-streaming server will be affected by the
underlying read throughput.

### 0.0 Highlights:

- If you need a fast disk, nothing beats a local vSphere NVMe drive. Nothing.
  Whether its IOPS, read throughput, or write throughput, NVMe is the
  winner hands down.
- Google's SSD (Solid State Drive) storage has 22× the IOPS of its standard
  storage. For general purpose use, always go with the SSD; however, if you're
  doing streaming (long reads or writes), the standard storage may be the better
  (and cheaper) choice.
- AWS's io1 disk is a waste of money unless you need an IOPS > 4k (the
  gp2 disk has an IOPS of ~4k). AWS's now-deprecated standard storage
  has a decent IOPS of ~2k.
- The key to getting IOPS out of Azure is to enable [Host Disk
  Caching](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/premium-storage-performance#disk-caching),
  which can catapult an anemic 120 IOPS to a competitive 8k IOPS.

### 0.1 Metrics, IaaSes, and Results

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

| IaaS      | Disk Type             | IOPS  | Read MB/s   | Write MB/s |
| --------- | --------------        | ---:  | ----------: | -----:     |
| AWS       | standard              | 1913  | 87          | 99         |
|           | gp2                   | 3634  | 92          | 103        |
|           | io1 (1000 IOPS)       | 1210  | 94          | 102        |
| Azure     | Standard 20 GiB       | 121   | 15          | 28         |
|           | Premium 256 GiB       | 1106  | 90          | 106        |
| Google    | pd-standard 20 GiB    |  162  | 43          | 74         |
|           | pd-standard 256 GiB   |  239  | 65          | 78         |
|           | pd-ssd 20 GiB         |  6150 | 27          | 29         |
|           | pd-ssd 256 GiB        | 11728 | 138         | 149        |
| vSphere   | FreeNAS               | 7776  | 104         |  91        |
|           | SATA SSD              | 26075 | 470         | 462        |
|           | NVMe SSD              | 28484 | 1614        | 1577       |


<div class="alert alert-warning" role="alert">

<b>These benchmarks are not gospel.</b> Even though they are recorded precisely,
they are not precise. For example, we report the GCE <i>pd-standard</i> Read
MB/s as 43, which was the average over the course of ten runs, but the metric is
more nuanced — the first four runs averaged 98 MB/s, and then, once Google
throttled the performance, dropped precipitously to 6 MB/s. Your mileage may
vary.

</div>


## 1. IOPS Performance

We feel that, in general, IOPS is the most important metric when judging storage
speed: The advent of solid-state drives (SSDs) with their high IOPS
([>10k](https://en.wikipedia.org/wiki/IOPS#Solid-state_devices)) exceeding by traditional hard disk
drives by an order of magnitude or more, was a game-changer.

*[Authors' note: in this blog post we use the term "standard" to refer to storage
back by magnetic media (i.e. "[rapidly rotating disks (platters) coated with
magnetic material](https://en.wikipedia.org/wiki/Hard_disk_drive)". This is also
the term that the IaaSes use. For example, Google refers to its magnetic storage
as ["standard hard disk drives
(HDD)"](https://cloud.google.com/compute/docs/disks/#pdspecs).]*

Below is a chart of the results of the IOPS benchmark. Note that the 256 GiB
Google SSD drive appears to be the winner, but only because we have excluded the
results of the vSphere local SSD disks (SATA & NVMe) from these charts (don't
worry, we'll include them in a chart [further down](#vsphere_local)). Also note that
Google [scales the performance of the disk with the size of the
disk](https://cloud.google.com/compute/docs/disks/#introduction): all else being
equal, the bigger disk will have better performance, and we see that reflected
in the scoring: the 256 GiB Google SSD disk leads the pack, but the 20 GiB disk
lands squarely in the middle.

While we're on the topic of Google, its standard drive takes two of three worst
slots of IOPS performance. The 256 GiB standard drive has an IOPS of 239, the 20
GiB, 162. Note that these numbers aren't bad for magnetic disk storage (a
typical magnetic hard drive will have
[75-150](https://en.wikipedia.org/wiki/IOPS#Mechanical_hard_drives) IOPS), it's
just that they seem lackluster when compared to the other IaaSes' storage
offerings.

AWS's io1 storage is a "tunable" storage offering — you specify the number of
IOPS you require. In our benchmarks we specified 1,000 IOPS, and we were pleased
that AWS exceeded that by 20%. Interestingly, the io1 numbers were precisely
clustered: across all ten runs the IOPS were within ±2 of each other (standard
deviation of 1.8).

{{< responsive-figure src="https://docs.google.com/spreadsheets/d/e/2PACX-1vTddYLAn6UFpesWIPH5S6ptr9sm3ECcHxf5aYobpfKqT1pdp8IyTZu4D9yV7SOmwQEVkhgwpy5xnlUW/pubchart?oid=1346974855&format=image" >}}

## 2. Read Performance

Read performance is important for applications which stream large amounts of
data (e.g. video servers). It's also useful for applications which fling disk
images around (e.g. BOSH Directors).

Once again we see Google's 256 GiB SSD leading the pack, and vSphere's iSCSI
FreeNAS server not far behind (never underestimate the throughput of seven
magnetic drives reading in parallel).

Interestingly the read performance of AWS is fairly consistent across all three
of its offerings (standard, gp2, io1), which leads to the conclusion that if
you're on AWS, and you use the storage for streaming reads, then AWS standard is
the cost-effective answer (be careful: we did not benchmark AWS's "Throughput
Optimized HDD" storage type, st1, which may be a better solution).

Although Google's SSD storage turns in great performance numbers, their standard
storage doesn't, landing second-to-last in terms of read throughput.

{{< responsive-figure src="https://docs.google.com/spreadsheets/d/e/2PACX-1vTddYLAn6UFpesWIPH5S6ptr9sm3ECcHxf5aYobpfKqT1pdp8IyTZu4D9yV7SOmwQEVkhgwpy5xnlUW/pubchart?oid=710877827&format=image" >}}

## 3. Write Performance

Write performance is important for applications which write large files: e.g.
disk images, BOSH stemcells, large videos, etc.

Once again, the Google SSD 256 GiB is the leader, and by a decent margin, too.

Second place is the Azure Premium 256 GiB, which is a surprise because until
this point Azure has had a difficult time cracking the top half of these charts.

The next three are the AWS storage types, which have been clustered together for
the two previous benchmarks as well, leading one to conclude that AWS storage
types are more similar than they are different.

Google, besides taking the lead, also corners three of the bottom four slots:
Google storage can be fast, but can also be slow. Also, the Google standard
offering again is surpringly faster than the 20 GiB SSD, so, for small disks on
Google where throughput is important, choose standard storage over SSD.

Below is a chart of the results of the write benchmark. The topmost item is the
fastest:

{{< responsive-figure
src="https://docs.google.com/spreadsheets/d/e/2PACX-1vTddYLAn6UFpesWIPH5S6ptr9sm3ECcHxf5aYobpfKqT1pdp8IyTZu4D9yV7SOmwQEVkhgwpy5xnlUW/pubchart?oid=1214783557&format=image" >}}

## 4. IaaS-specific Commentary

### 4.0 AWS

AWS storage options are noted more for their similarity than for their differences.

A note about the chart below: The storage type (e.g. "io1 20 GiB") is denoted on
the horizontal axis at the bottom. IOPS, represented in blue, are recorded on
the axis on the _left_ (e.g. "io1 20 GiB" has an IOPS of 1210). Throughput, both
read and write, are recorded on the axis on the _right_ (e.g. "io1 20 GiB" has a
read throughput of 94 MB/s).

{{< responsive-figure
src="https://docs.google.com/spreadsheets/d/e/2PACX-1vTddYLAn6UFpesWIPH5S6ptr9sm3ECcHxf5aYobpfKqT1pdp8IyTZu4D9yV7SOmwQEVkhgwpy5xnlUW/pubchart?oid=1774206212&format=image" >}}

Amazon differs from Azure and Google in that it doesn't scale performance to the
size of the drive. Looking at the chart above, it would be difficult to
distinguish the 20 GiB standard drive from the 256 GiB standard drive from the
performance numbers alone. Indeed, one might be surprised to discover that the
bigger drive has slightly _worse_ performance than the smaller one (which  we
discount as being statistically insignificant).

IOPS seems to be the real differentiator, not throughput (the throughput numbers
are very similar across storage types, though gp2's throughput is marginally
faster than standard's).

AWS gp2 is a good overall choice; io1 storage is poor value unless one needs
more than 4k IOPS and throughput greater than what gp2 storage offers. Per
AWS's
[website](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/EBSVolumeTypes.html),
_"[io1 should be used for] Critical business applications that require sustained
IOPS performance, or more than 10,000 IOPS or 160 MiB/s of throughput per
volume"_

And io1 is certainly expensive; of our AWS charges for the month during which
these benchmarks were run, the io1 storage accounted for over half the cost
(which included the cost of the EC2 instances, network bandwidth, etc.). And
when one considers that the io1 was configured with a very modest 1k IOPS, it
becomes apparent how expensive io1 is (we suspect that io1 storage with 10k IOPS
may radically eclipse other AWS costs for many customers).

The difference between Amazon's "[Previous
Generation](https://aws.amazon.com/ebs/previous-generation/)" standard storage
and its gp2 storage is mostly IOPS, for half the price ($0.05/GB-month vs.
$0.10/GB-month at the time of this writing) standard offers half the IOPS (1913
vs. 3634), with almost identical throughput numbers. Save your money if you need
the storage but not the IOPS.

AWS's write throughput consistently outperforms its read throughput, which may
indicate their storage backend uses write-caching.

Never one to be intimidated by complexity, AWS has a
[baroque](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/EBSVolumeTypes.html#IOcredit)
credit system for its gp2's performance which tilts the field in favor of VMs
that are spun up briefly to run benchmarks such as GoBonnieGo — a long-running
VM with heavy disk usage may not see the performance reflected in our results.
We ran a special benchmark to determine if we could exhaust our credits, and the
answer was yes, we could, but it took three hours. See [below](#aws_throttle)
for details.

### 4.1 Azure

<div class="alert alert-success" role="alert">

If you want IOPS on your Azure VMs, we strongly encourage you to set your
<b>Premium Storage disk caching</b> to <i>ReadOnly</i> at a minimum,
<i>ReadWrite</i> if your application can stomach the loss of writes (but don't
do this for databases).

</div>

<p />

To get the most out of your Azure storage, we recommend the following:

- enable [Disk
Caching](
https://docs.microsoft.com/en-us/azure/virtual-machines/windows/premium-storage-performance#disk-caching)
unless your disk is big and your activity is mostly
streaming (not IOPS)
- use Standard Storage if your disk use is light, Premium if heavy

The biggest single factor for boosting IOPS for Azure disks is Disk Caching
But don't take our word for it — look at our results below:

{{< responsive-figure
src="https://docs.google.com/spreadsheets/d/e/2PACX-1vTddYLAn6UFpesWIPH5S6ptr9sm3ECcHxf5aYobpfKqT1pdp8IyTZu4D9yV7SOmwQEVkhgwpy5xnlUW/pubchart?oid=651613620&format=image" >}}

How to read the chart: The horizontal axis denotes the storage type. The first
two letters of the storage type are either "st" or "pr", denoting Azure Standard
storage and Azure Premium storage, respectively. The second part is a number,
either 20 or 256 representing the size of the disk in GiB. Finally, the optional
suffix "rw" means that _ReadWrite_ caching was enabled on that disk. To tie it
all together with an example, "pr 256 rw" means that the benchmark was performed on a 256 GiB drive of Azure Premium storage with caching set to _ReadWrite_.

IOPS, represented in blue, are recorded on the axis on the _left_ (e.g. "st 20
rw" has an IOPS of 8219). Throughput, both read and write, are recorded on the
axis on the _right_ (e.g. "pr 256" has a read throughput of 90 MB/s).

We could find **no significant difference in performance between Azure Standard
Managed Disks and Azure Premium Managed Disks** — the results for "st 20" match
the results for "pr 20", the results for "st 256" match the results for "pr
256". We assumed an error in our configurations, but in spite of checking
several times we could find no mistake. This flies in the face of the [Microsoft
Documentation](https://azure.microsoft.com/en-us/pricing/details/managed-disks/),
which indicates that the backend for the Standard Storage is different than
Premium's, and slower, too:

> Premium Managed Disks are high performance Solid State Drive (SSD) based

> Standard Managed Disks use Hard Disk Drive (HDD) based Storage

On Azure, the bigger disk will outperform the smaller disk; however this changes
once you enable caching: **disks of different size will perform identically when
caching is enabled**. As you can see in the chart above, the performance of the
Standard 20 GiB disk ("st 20 rw") is almost identical to the Premium 256 GiB
disk ("pr 256 rw") — if you placed your hand over the legend, you'd be
hard-pressed to distinguish the two disks based on their performance.

#### 4.1.0 Azure Pricing

Azure's pricing for Standard storage is approximately
[$0.048](https://azure.microsoft.com/en-us/pricing/details/managed-disks/) per
GiB/month for 32 GiB, which is a hair under AWS's pricing for its deprecated
standard disk ($0.05 per GiB month) but slightly over AWS's st1 Throughput
Optimized offering ([$0.045 per
GiB/month](https://aws.amazon.com/ebs/pricing/)). Azure's Premium storage comes
in at $0.165 for 32 GiB, which is a hair under Google's pricing for its SSD
offering
([$0.17](https://cloud.google.com/persistent-disk/#persistent-disk-pricing) per
GiB month).

But Azure has a rider in small print at the [bottom of the
page](https://azure.microsoft.com/en-us/pricing/details/managed-disks/) which
could make Standard disks *much* more expensive than Premium:

> We charge $0.0005 per 10,000 transactions for Standard Managed Disks

As a worst-case scenario, we could spend close to $65 in a month if we push our
256 GiB Standard disk to its limit ([500
IOPS](https://azure.microsoft.com/en-us/pricing/details/managed-disks/)):

( $0.0005 / 10000 IO operations )
× ( 500 IO operations / 1 second )
× ( 3600 seconds / 1 hour )
× ( 24 hours / 1 day )
× ( 30 days / 1 month )
= $64.80

#### 4.1.1 Azure IOPS

Azure deserves recognition for delivering within 0.5% the amount of the expected
IOPS. On the Premium 256 GiB drive, Azure said to expect 1100 IOPS, and our
benchmark came in at 1106:

{{< responsive-figure
src="https://user-images.githubusercontent.com/1020675/38069255-39a844de-32ca-11e8-9972-e39edfa573d9.jpg" class="left small" >}}

### 4.2 Google Cloud Platform

Google takes the crown for both the best and the worst. There's a 22× increase
in their performance between their Standard offering and their SSD offering (for
comparison, AWS's is 2× and Azure's is 1×), and Google also scales performance
by disk size, which means that the 256 GiB SSD leads the pack, and the 20 GiB
Standard — well, let's just say it tries its best.

And it's not the disks' fault — it appears that Google throttles the performance
of its small-size Standard drive: After four runs of our benchmark, the
performance plummeted. IOPS dropped ~75% (from ~300 to ~80), read throughput
~95% (98 MB/s to 6 MB/s), and write throughput ~90% (135 MB/s to 13 MB/s).
Perhaps a visualization would help to grasp this steep decline:

{{< responsive-figure
src="https://docs.google.com/spreadsheets/d/e/2PACX-1vTddYLAn6UFpesWIPH5S6ptr9sm3ECcHxf5aYobpfKqT1pdp8IyTZu4D9yV7SOmwQEVkhgwpy5xnlUW/pubchart?oid=504090737&format=image" >}}

The thing to understand is that the performance numbers for Google's standard
drive are worse than they appear — the storage is able to put up a good front
for the first twenty minutes (each benchmark takes approximately 4-5 minutes to
run on the Google Standard), and then the performance collapses.

#### <a id="aws_throttle">4.2.0 Google's vs. AWS's Throttling</a>

Google isn't unique among the IaaSes for this performance cliff — AWS
experiences the same drop-off for its gp2 20 GiB drive. We can see in the
illustration below that the drop-off is similar to Google's; however, the
drop-off occurs much later in AWS — rather than occurring on the fifth run as
had happened in Google's case, Amazon's performance collapsed on the
thirty-fourth run. Google collapsed after 20 minutes; Amazon collapsed after 3
hours.

{{< responsive-figure
src="https://docs.google.com/spreadsheets/d/e/2PACX-1vTddYLAn6UFpesWIPH5S6ptr9sm3ECcHxf5aYobpfKqT1pdp8IyTZu4D9yV7SOmwQEVkhgwpy5xnlUW/pubchart?oid=48993031&format=image" >}}

### 4.3 vSphere

Our vSphere benchmarks were carried out under near-optimal <sup><a
href="#optimal">[Optimal]</a></sup> conditions; there were no noisy neighbors.

Before we discuss the performance of [vSphere local disks](#vsphere_local), we'd
like to point out that the vSphere non-local storage (the FreeNAS-based iSCSI
storage) carried itself quite admirably in the benchmarks, placing 2nd in IOPS,
2nd in read throughput (and the middle of the pack in write throughput — nothing
is perfect). This is doubly impressive when one takes into account that the
vSphere storage setup that we benchmarked is not a professional setup — the
networking backend is 1 Gbps, not 10 Gbps, the disks are magnetic, not SSDs
(though with an SSD cache). It would not be unreasonable to assume that a
professional grade storage backend, e.g. a [Dell EMC
VNX5600](https://store.emc.com/en-ph/Solve-For/STORAGE-PRODUCTS/Dell-EMC-VNX5600-Storage/p/VNX-VNX5600-storage-platform)
would turn in better results, possibly toppling the reigning champion, Google.

#### <a id="vsphere_local">4.3.0 The Unbelievable Performance of [vSphere] Local Disks</a>

Now let's discuss the vSphere local disks. In the chart below, we compare the
results of our vSphere local disk benchmarks with our reigning champion, Google
256 GiB SSD:

{{< responsive-figure
src="https://docs.google.com/spreadsheets/d/e/2PACX-1vTddYLAn6UFpesWIPH5S6ptr9sm3ECcHxf5aYobpfKqT1pdp8IyTZu4D9yV7SOmwQEVkhgwpy5xnlUW/pubchart?oid=1704161126&format=image" >}}

We can see that in every measure, the performance of local disks dwarf the
performance of Google's flagship offering.

But local disks are not a perfect solution, for they offer speed at the expense
of reliability (a true [Faustian
bargain](https://en.wikipedia.org/wiki/Deal_with_the_Devil)) — one disk crash
and the data's all gone.

Also, local SSD disks are available on
[AWS](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ssd-instance-store.html),
[Azure](https://azure.microsoft.com/en-us/pricing/details/virtual-machines/series/),
and [Google](https://cloud.google.com/compute/docs/disks/local-ssd), and,
although we have not benchmarked their performance, it's something we'd be very
interested in (we haven't benchmarked those because the ability to use local
disks would require a significant change to BOSH, the cloud orchestrator we use
to deploy the VMs on which we run our benchmarks).

## 5. Testing Methodology

We used [BOSH](https://bosh.io/) to deploy VMs to each of the various IaaSes.

We used the following instance types for each of the IaaSes:

| IaaS      | Instance Type   | Cores   | RAM (GiB)   | Disk Type       |
| --------- | --------------- | ------- | ----------- | --------------  |
| AWS       | c4.xlarge       | 4       | 7.5         | standard        |
|           |                 |         |             | gp2             |
|           |                 |         |             | io1             |
| Azure     | F4s v2          | 4       | 8           | Standard 20 GiB |
|           |                 |         |             | Premium 256 GiB |
| Google    | n1-highcpu-8    | 8       | 7.2         | pd-standard     |
|           |                 |         |             | pd-ssd          |
| vSphere   | N/A             | 8       | 8           | FreeNAS         |
|           |                 |         |             | SATA SSD        |
|           |                 |         |             | NVMe SSD        |

For those interested in replicating our tests or reproducing our results, our
BOSH manifests and Cloud Configs can be found
[here](https://github.com/cunnie/deployments/tree/7434abd0eaf12699482a2af24c95b8bef4d89ac6/gobonniego).

We spun up a VM, and ran the benchmark ten times in succession, storing the
[results](https://github.com/cunnie/freenas_benchmarks/tree/9c0cecdb7de3d8a5fe7347f6fbec718786d4400f/gobonniego-1.0.7)
in JSON format (i.e. we passed the arguments `-runs 10 -json` to GoBonnieGo).
The numbers displayed in the charts and tables are the _averages_ of the ten
runs.

Each VM was configured with a [BOSH persistent
disk](https://bosh.io/docs/persistent-disks.html) of a certain type (e.g. Google
SSD 256 GiB). We instructed GoBonnieGo to exercise the persistent disk (not the
root nor the ephemeral disks) (i.e. we passed the argument `-dir
/var/vcap/store/gobonniego` to GoBonnieGo).

Each GoBonnieGo run consists of the following steps:

- A write test, which creates a set of files consisting of random data whose
aggregate size equals twice the physical RAM of the VM (e.g. for the AWS test,
which used a c4.xlarge instance type with 7.5 GiB, GoBonnieGo created a set of
files whose footprint was 15 GiB). The throughput (write MB/s) is calculated by
taking the total amount written (e.g. 15 GiB) and dividing by the time it takes
to write that amount. The test writes 64 kiB blocks of random data.
- At that point, GoBonnieGo clears the buffer cache to avoid skewing the upcoming
read benchmark.
- A read test, which reads the files created by the write test. Again, the
throughput (read MB/s) is calculated by taking the total amount read (e.g. 15
GiB) and dividing by the time it takes to read that amount. The read blocksize
is 64 kiB.
- GoBonnieGo clears the buffer cache again, to avoid skewing the upcoming IOPS
benchmark.
- Finally, GoBonnieGo runs an IOPS test, where it randomly seeks to locations in
the test files, and then either reads or writes a 512-byte block (with a 9:1
ratio of reads to writes). It runs the test for approximately 5 seconds, and at
the end tallies up the total number of reads & writes and divides by the
duration.
- GoBonnieGo then deletes its test files and records its results.

### 5.0 Cores, Preferably 8

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

### 5.1 RAM: 4 - 8 GiB

We wanted 4-to-8 GiB RAM, dependent on what the IaaS allowed us. The amount of
data written for each benchmark was twice the size of physical RAM, so VMs with
twice the RAM should have no added advantage ([buffer
cache](https://www.tldp.org/LDP/sag/html/buffer-cache.html) notwithstanding).

### 5.2 Disk: 20 GiB

We chose to run our test on the [BOSH persistent
disk](https://bosh.io/docs/persistent-disks.html), for it was more flexible to
size than the root disk. We chose a disk size of 20 GiB, with the exception of
Azure, where we ran a second benchmark with a disk of 256 GiB.

## 6. Methodology Shortcomings

We wrote our own benchmark program; it may be grossly flawed.

Each benchmark (e.g. AWS gp2) was taken on one VM. That VM may have been on
sub-optimal hardware or suffered from the ["noisy
neighbor"](https://en.wikipedia.org/wiki/Cloud_computing_issues#Performance_interference_and_noisy_neighbors)
effect.

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
* Benchmark results (raw JSON files): <https://github.com/cunnie/freenas_benchmarks/tree/master/gobonniego-1.0.7>
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

{{< responsive-figure
src="https://user-images.githubusercontent.com/1020675/37519840-ef6a3f54-28d7-11e8-918a-7612beee1ea4.png"
class="left small" >}}

{{< responsive-figure
src="https://user-images.githubusercontent.com/1020675/37519846-f4e7e8be-28d7-11e8-9536-afe3ef6301a5.png"
class="left small" >}}

<!-- Gratuitous title to avoid text below flowing to the right of above images -->
###### Above is the chart of the disk usage on the two vSphere ESXi hosts before benchmarking

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

{{< responsive-figure
src="https://user-images.githubusercontent.com/1020675/38319873-cde69b1a-37e7-11e8-8204-692ac250a934.jpg"
class="left small" >}}

###### Above is a photo of the Samsung NVMe mounted in the Supermicro motherboard:

<a id="crucial"><sup>[Crucial]</sup></a>
The [Crucial MX300 1TB M.2 Type 2280 SSD](http://www.crucial.com/usa/en/storage-ssd-mx300) is installed in an [Intel Skull Canyon](https://www.intel.com/content/www/us/en/nuc/nuc-kit-nuc6i7kyk-features-configurations.html) which features a 2.6 GHz 4-core [Intel Core i7-6770HQ](https://ark.intel.com/products/93341/Intel-Core-i7-6770HQ-Processor-6M-Cache-up-to-3_50-GHz) and 32 GiB RAM.

The results of the bonnie++ v1.97 benchmarks of the Crucial MX 300 are viewable
[here](https://github.com/cunnie/freenas_benchmarks/blob/9ecd5736db87902ee955f096012c39527f778ef5/bonnie%2B%2B_1.97/vsphere_sata.txt#L4).

The photograph below shows the Crucial SSD, but astute observers will note that
it's not the Skull Canyon motherboard (it isn't) — it's the Supermicro
motherboard.

{{< responsive-figure
src="https://user-images.githubusercontent.com/1020675/38319872-cdcbe9f0-37e7-11e8-80c9-10d60c21fef8.jpg"
class="left small" >}}

## Corrections & Updates

*2018-09-18*

The worst-case scenario for the cost of a 256 GiB Standard disk on Azure was
~22× too high: it is $64.80, not $1,425.60. Thanks [Mike
Taber](https://twitter.com/SingleFounder/status/1040787595775684609)!

*2018-03-19*

Clarified Dell's relationship to Pivotal Software: Dell is an _investor_ in
Pivotal; Dell is not the _owner_ of Pivotal.

*2018-04-01*

IaaS Disk Performance: Use more-accurate GoBonnieGo 1.0.7

Used the more-accurate numbers generated by a second run using the newer
GoBonnieGo 1.0.7 which clears the buffer cache before the IOPS and read tests.
The IOPS number is both lower and more accurate. Updated tables and charts.

Removed the vSphere local disk benchmarks from the charts; the numbers were too
good and dwarfed the results of the other IaaSes and made them hard to read.

Created a _highlights_ section which has important take-aways for each IaaS.
Removed the _Take-aways_ section; it was no longer needed.

Expanded the metrics (IOPS, read, and write) commentary.

Added a section specific to each IaaS.

On Azure, called out the importance of enabling host disk caching. If not
enabled, Azure's IOPS are abysmal.

Added new test results for Azure disks with host disk caching enabled.

Included a more in-depth description of the benchmarks (10 runs, IOPS, read,
write, clearing of the buffer cache).

Added a measurement of AWS's and Google's performance-throttling.

Shrunk the presented size of several images — they took up almost the entire
page!

Fixed the Azure VM type (included the "s").

*2018-04-02*

Switched the order of the columns of the chart at the top (IOPS, write, read →
IOPS, read, write) to match the remainder of the post.

Removed the _Azure_ footnote — nothing was referring to it, and it had no
information that wasn't already mentioned elsewhere in the post.

*2018-04-04*

Modified the URL of the images to point to their location on GitHub, not Google
Photos. Google Photos has the [unfortunate habit of expiring
URLs](https://productforums.google.com/forum/#!msg/picasa/08ba8idWrW8/ZuIwpin9DAAJ)
after a few days, and we are disappointed with them.

Added anecdotal evidence of the expense of AWS's io1 storage type (it's quite
expensive).
