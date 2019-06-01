---
authors:
- cunnie
categories:
- Logging & Metrics
- FreeNAS
date: 2019-05-25T17:16:22Z
draft: false
short: |
  Upgrading our iSCSI (Internet Small Computer System Interface) NAS
  (network-attached storage) server from 1 GbE (gigabit ethernet) to 10 GbE
  increased our vSphere VM's (Virtual Machine's) sequential read throughput 43%,
  sequential write throughput 940% (!), and IOPS (Input/Output Operations Per
  Second) 60%.
title: "A High-performing Mid-range NAS Server, Part 3: 10 GbE"
---

### Abstract

"How much faster will my VM's disks be if I upgrade my
[ZFS](https://en.wikipedia.org/wiki/ZFS)-based (Z File System) NAS to 10 GbE?"
The disks will be faster, in some cases, much faster. Our experience is that
sequential read throughput will be 1.4✕ faster, write throughput, 10✕ faster,
and IOPS, 1.6✕ faster.

We ran a three-hour benchmark on our NAS server before and after upgrading to 10
GbE. We ran the benchmark again after upgrading. The benchmark looped through
write-read-iops tests continuously.

#### The Sequential Read Results:

{{< responsive-figure src="https://docs.google.com/spreadsheets/d/e/2PACX-1vTddYLAn6UFpesWIPH5S6ptr9sm3ECcHxf5aYobpfKqT1pdp8IyTZu4D9yV7SOmwQEVkhgwpy5xnlUW/pubchart?oid=955621268&format=image" >}}

We were underwhelmed with the 10 GbE read performance — we felt it should have
been better, and surprised that it wasn't. The 1 GbE results were close to the
theoretical network maximum, and we thought the upgrade would have unleashed its
full potential. Little did we know that its full potential was barely above 1
GbE.

The lackluster performance wasn't due to RAM pressure: there was enough RAM on
the FreeNAS server (128 GiB) to cache the contents of the sequential read test
(16 GiB) several times over, and this was borne out by running `zpool iostat 5`,
which showed the disks were barely touched during the read test.

We also noticed dips in 10 GbE performance at regular intervals (where the read
throughput dropped to less than 120 MB/sec); we are not sure what caused these
dips, but they seemed to occur _almost exactly 35 minutes apart_ (although
timestamps aren't included in the graph above, they are included in the raw
benchmark results, which can be viewed in the [References](#references) section
below).

As an aside, there are fewer 1 GbE tests than 10 GbE tests in the above chart.
That is, there are fewer blue dots than red dots, for the 1 GbE tests took
longer to run, hence there were fewer results reported within the three-hour
test window.

#### The Sequential Write Results:

{{< responsive-figure src="https://docs.google.com/spreadsheets/d/e/2PACX-1vTddYLAn6UFpesWIPH5S6ptr9sm3ECcHxf5aYobpfKqT1pdp8IyTZu4D9yV7SOmwQEVkhgwpy5xnlUW/pubchart?oid=321002413&format=image" >}}

The sequential write performance, shown in the above graph, was the star of the
show: a 10✕ increase, linear with the network bandwidth increase.

There are some caveats. Most importantly, we sacrificed safety for speed.
Specifically, we did not override the default ZFS setting, `sync=standard`. As
pointed out in the article, "[Sync writes, or: Why is my ESXi NFS so slow, and
why is iSCSI
faster?](https://www.ixsystems.com/community/resources/sync-writes-or-why-is-my-esxi-nfs-so-slow-and-why-is-iscsi-faster.40/)":

> iSCSI by default does not implement sync writes. As such, it often appears to
> users to be much faster.... However, your VM data is being written async,
> which is hazardous to your VM

You may ask, "What are these sync writes to which you refer?" Robert Milkowski,
the author of the ZFS `sync` feature, describes it succinctly in his [blog
post](http://milek.blogspot.com/2010/05/zfs-synchronous-vs-asynchronous-io.html):

> Synchronous file system transactions (fsync, O_DSYNC, O_SYNC, etc) are written
> out [to disk before returning from the system call]

In other words, these are system calls
([`fsync(2)`](http://man7.org/linux/man-pages/man2/fsync.2.html)) or flags to
system calls ( [`open(2)`](http://man7.org/linux/man-pages/man2/open.2.html)'s
'`O_DSYNC` and `O_SYNC`) to make sure that the data has really, truly been
written out to disk before returning from a
[`write(2)`](http://man7.org/linux/man-pages/man2/write.2.html). When the system
call returns, you know that the data's on the disk, not in some buffer
somewhere.

_[Editor's note: this is not always true. Linux *usually* writes the data to
disk, but sometimes it doesn't. For the dirty details, see [this
post](http://milek.blogspot.com/2010/12/linux-osync-and-write-barriers.html).]_

`sync` is a great feature when ZFS is used as a fileserver (technically a
[distributed file
system](https://en.wikipedia.org/wiki/Clustered_file_system#Distributed_file_systems)),
via protocols such as [NFS](https://en.wikipedia.org/wiki/Network_File_System)
(Network File System), [SMB](https://en.wikipedia.org/wiki/Server_Message_Block)
(Server Message Block), or even the deprecated
[AFP](https://en.wikipedia.org/wiki/Apple_Filing_Protocol) (Apple Filing
Protocol, formerly AppleTalk Filing Protocol):

- The applications that depend on synchronous behavior (that have opted-in via
  system call or flag) are guaranteed that their data has been written to disk
- The majority of applications who don't need synchronous behavior
  can take advantage of the high write speeds (often ten times as fast)

But here's the rub: iSCSI is **not** a distributed file system. It's a
distributed block device. Which means it's at a lower layer than NFS, SMB, and
AFP. There are no system calls, no directories, no file permissions, no files;
there are only reads and writes.

The upshot is that if power is cut to the NAS server while the VM is active, the
and the NAS hasn't yet flushed the outstanding writes to disk, then the VM's
file system may be corrupted beyond the ability of file system repair tools to
fix. We witnessed this problem firsthand by cutting the power to the NAS server
while actively exercising a Linux VM's iSCSI disk by running the `gobonniego`
file system benchmark. Our Linux system's `btrfs` filesystem was corrupted
beyond the ability of `btrfsck` to fix, emitting cryptic errors such as "`child
eb corrupted`" and "`parent transid verify failed`" before finally giving up. We
lost our VM, and had to reinstall Linux from scratch.

#### The IOPS Results:

{{< responsive-figure src="https://docs.google.com/spreadsheets/d/e/2PACX-1vTddYLAn6UFpesWIPH5S6ptr9sm3ECcHxf5aYobpfKqT1pdp8IyTZu4D9yV7SOmwQEVkhgwpy5xnlUW/pubchart?oid=1489787822&format=image" >}}

The IOPS results were good, averaging 21k. As a comparison, they were much
better than a [mechanical hard
drive's](https://en.wikipedia.org/wiki/IOPS#Mechanical_hard_drives) (44 -203),
and better than even [SATA 3
Gbit/s](https://en.wikipedia.org/wiki/IOPS#Solid-state_devices)'s 5k-20k, but
nowhere near as performant as the higher end NVMe drives (e.g. Samsung
SSD 960 PRO's 360k).

### Configuration

{{< responsive-figure src="https://docs.google.com/drawings/d/e/2PACX-1vTBv3cUiVxCkfjKnN0iV1tjG-wo3GfnXF14zPSlSM4sDnU508y0GE6rsyR3ADNG6iRV7qVtKjyeByTM/pub?w=1128&h=858" >}}

#### Storage

| Component  | 10 GbE<br />(new, 2019) | 1 GbE<br />(old, 2104) |
|---|---|---|
| Motherboard | $820 1 × [Supermicro X10SDV-8C-TLN4F+ Mini-ITX 1.7GHz 35W 8-Core Intel Xeon D-1537](https://www.supermicro.com/products/motherboard/Xeon/D/X10SDV-8C-TLN4F_.cfm) | $375 1 × [Supermicro A1SAi-2750F Mini-ITX 2.4GHz 20W 8-Core Intel C2750](https://www.supermicro.com/products/motherboard/Atom/X10/A1SAi-2750F.cfm) |
| Ethernet controller | (built-in) | (built-in) |
| RAM | $1,336 4 × D760R Samsung DDR4-2666 32GB ECC Registered | $372 4 × Kingston KVR13LSE9/8 8GB ECC SODIMM |
| HBA | (same HBA) | $238 1 × [LSI SAS 9211-8i 6Gb/s SAS Host Bus Adapter](https://docs.broadcom.com/docs/12352062) |
| Disk | (same Disk) | $1,190 7 × Seagate 4TB NAS HDD ST4000VN000 |
| Power Supply | (same Power Supply) | $110 1 × [Corsair HX650 650 watt power supply](https://www.corsair.com/us/en/Categories/Products/Power-Supply-Units/hx-series-config/p/CP-9020030-NA) |
| Ethernet Switch | $589 1 × [QNAP QSW-1208-8C 12-port 10GbE unmanaged switch](https://www.qnap.com/en-us/product/qsw-1208-8c) | $18 1 × [TP-Link 8-Port Gigabit Desktop Switch TLSG1008D](https://www.tp-link.com/us/home-networking/8-port-switch/tl-sg1008d/) |
| SFP+ Modules | $79 2 × [Ubiquiti UF-MM-10G U Fiber SFP+ Module 2-pack](https://store.ui.com/collections/all/products/uf-mm-10g-20-20-pack) | N/A |
| Software | (same Software) | FreeNAS-11.2-U4.1 |

#### Virtual Machine:

- Hypervisor: **VMware ESXi, 6.7.0, 13644319**
- Underlying hardware: (same as file server's): [Supermicro X10SDV-8C-TLN4F+ Mini-ITX 1.7GHz 35W 8-Core Intel Xeon D-1537](https://www.supermicro.com/products/motherboard/Xeon/D/X10SDV-8C-TLN4F_.cfm)
- vCPUs: **8**
- RAM: **8 GiB**
- OS: **Fedora 30 (Server Edition)**
- Linux kernel: **5.0.16-300.fc30.x86_64**
- Filesystem: **[tmpfs](https://en.wikipedia.org/wiki/Tmpfs#Linux)** (not ext4 nor btrfs)
- Benchmarking Software: **[GoBonnieGo v1.0.9](https://github.com/cunnie/gobonniego)**
- Benchmarking invocation: `./gobonniego -dir /tmp/ -json -seconds 14400 -v -iops-duration 60`

### Shortcomings

We didn't control solely for the 1 GbE → 10 GbE differences: the ethernet
controllers were built into the motherboards, hence the ethernet controller
upgrade entailed a motherboard upgrade in turn entailing CPU & RAM upgrades.

In other words, the performance increases can't be attributed solely to the
change in network controllers; faster CPUs and larger (32 GiB → 128 GiB) and
faster (DDR3 → DDR4) RAM may also have been a factor.

We have seen at least one dramatic speed-up that we could _not_ attribute to the
ethernet upgrade: when browsing an AFP (Apple Filing Protocol) share from our
WiFi-based laptop, we noticed that one large directory (4.5k entries), which
previously took ~30 seconds to display in Apple's Finder, now displayed in
sub-second time. We know the WiFi's throughput (200 Mb/s) was minuscule compared
to the file server's (1 Gb/s, 10 Gb/s), so the reason for the speed-up lay
elsewhere.

Other VMs had disks that were placed on the iSCSI datastore; they may have
contended with benchmark VM for disk access. We feel the contention was minor at
most.

## <a name="references">References</a>

- Raw benchmark results:
  - [1 GbE](https://raw.githubusercontent.com/cunnie/cloud_storage_benchmarks/5e0d329f1b386de5ee7cf43e0619d0d61076ea4e/10g_upgrade/1g.json)
  - [10 GbE](https://raw.githubusercontent.com/cunnie/cloud_storage_benchmarks/5e0d329f1b386de5ee7cf43e0619d0d61076ea4e/10g_upgrade/10g.json)
- ZFS configuration:
  - [`zdb -eC tank`](https://github.com/cunnie/cloud_storage_benchmarks/blob/master/10g_upgrade/zdb_-eC_tank.txt)
  - [`zfs get all tank/vSphere`](https://github.com/cunnie/cloud_storage_benchmarks/blob/master/10g_upgrade/zfs_get_all_tank_slash_vSphere.txt)
  - [`zpool status tank`](https://github.com/cunnie/cloud_storage_benchmarks/blob/master/10g_upgrade/zpool_status_tank.txt)
- [A High-performing Mid-range NAS Server, Part 1: Initial Set-up and Testing](https://content.pivotal.io/blog/a-high-performing-mid-range-nas-server)
- [A High-performing Mid-range NAS Server, Part 2: Performance Tuning for iSCSI](https://content.pivotal.io/blog/a-high-performing-mid-range-nas-server-part-2-performance-tuning-for-iscsi)
