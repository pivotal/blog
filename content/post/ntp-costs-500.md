---
authors:
- cunnie
categories:
- NTP
date: 2017-01-28T12:38:13-08:00
draft: false
short: |
  Running a Network Time Protocol (NTP) server in the pool.ntp.org project can
  incur $500/year in data transfer (bandwidth) costs. Those costs can be reduced
  or even eliminated by choosing alternative Infrastructure as a Service (IaaS)
  providers, modifying the server's pool.ntp.org connection speed setting,
  choosing an alternative continent upon which to place the server, and
  modifying the NTP daemon's configuration file to rate-limit the clients.
title: Why Is My NTP Server Costing $500/Year? Part 3
---

When [Hacker News picked up Part
1](https://news.ycombinator.com/item?id=13249562) of our series of blog posts on
running public NTP servers, a contributor said, "I wish he'd explained ... what
they ultimately did (since there's no part 3 that I can find)."

We had dropped the ball — we had never concluded the series, had never written
part 3, had never described the strategies to mitigate the data transfer costs.

This blog post remedies that oversight; it consists of two parts: the first part
addresses strategies to reduce the cost of running an NTP server, and the second
part discusses side topics (aspects of running an NTP server).

Perhaps the most dismaying discovery of writing this blog post was the
realization that the title is no longer accurate — rather than costing us
$500/year, our most expensive NTP server was costing us more than $750/year in
data transfer charges. <sup><a href="#cost_doubling">[Traffic increase]</a></sup>

## Table of Contents

* [0. Previous Posts (Parts 1 & 2)](#previous_posts)
* [1. Reducing the Cost of Running an NTP Server](#reducing_costs)
  * [1.0 Statistics (traffic)](#statistics)
  * [1.1 The Right Infrastructure Can Drop the Data Transfer Costs to $0](#infrastructure)
  * [1.2 Connection Speed Setting](#speed)
  * [1.3 Geographical Placement](#geography)
  * [1.4 Rate Limiting](#rate_limiting)
  * [1.5 Join the Pool](#join)
* [2. Side Topics](#side_topics)
  * [2.0 The Cavalry is Coming: Google's Public NTP Servers](#google_ntp)
  * [2.1 The Snapchat Excessive NTP Query Event Cost $13 - $18 (Per Server)](#how_much)
  * [2.2 Are Virtual Machines Adequate NTP Servers? Yes.](#adequate)
  * [2.3 Sometimes It's the Network, not the VM](#network)
* [Footnotes](#footnotes)
* [Corrections & Updates](#corrections)

## <a name="previous_posts">0. Previous Posts</a>

These posts provide background, but reading them isn't necessary:

* [Why Is My NTP Server Costing $500/Year? Part
1](https://content.pivotal.io/blog/why-is-my-ntp-server-costing-500-year-part-1).
We analyze our sudden increase in AWS data transfer charges and conclude that
adding our server into the NTP pool is the sole reason for the data transfer
increase.

* [Why Is My NTP Server Costing Me $500/Year? Part 2: Characterizing the NTP
Clients](https://content.pivotal.io/blog/why-is-my-ntp-server-costing-me-500-year-part-2-characterizing-the-ntp-clients).
We characterize the demand that each NTP client places on an NTP server, by
operating system. To our surprise, FreeBSD and Ubuntu place the greatest demand
on the NTP servers, and Windows and macOS the least.

## <a name="reducing_costs">1. Reducing the Cost of Running an NTP Server</a>

We maintain several servers in the pool.ntp.org project. These servers are
personal, not corporate, so we're quite sensitive to cost: we don't want to
spend a bundle if we don't have to. Also, these servers have roles other than
NTP servers (in fact, their primary purpose is to provide Domain Name System
(DNS) service and one is also a [Concourse](https://concourse.ci/) continuous
integration (CI) server).

Which begs the question: given the expense, why do it? We have several motives:

* We have benefited greatly from the open source community, and providing this
service is a modest way of giving back.

* Our day job is a developer on
[BOSH](https://en.wikipedia.org/wiki/BOSH_(bosh_outer_shell), a tool which, at
its simplest, creates VMs in the cloud based on specifications passed to it in a
file. We use BOSH to deploy our NTP servers, and on at least two occasions we
have uncovered obscure bugs as a result.

* On the rare occasions when our systems fail, often our first warning is an email
from the pool with the subject, "NTP Pool: Problems with your NTP service". In
other words, being in the pool is a great monitoring system, or, at the very
least, better than nothing.

### <a name="statistics">1.0 Statistics (traffic)</a>

We have two NTP servers in the [pool.ntp.org
project](http://www.pool.ntp.org/en/) whose country is set to "United States"
and whose connection speed is set to "1000 Mbit". We have gathered the following
statistics <sup><a href="#ntp_statistics">[NTP statistics]</a></sup> over a
seven-day period (2017-01-21 15:00 UTC - 2017-01-28 15:00 UTC). Note that other
than data transfer pricing, the choice of underlying IaaS is unimportant
(assuming proper functioning of VM/disk/network). In other words, although the
Google Compute Engine (GCE) server carries more traffic than the Amazon Web
Services (AWS) server, the roles could have easily been reversed. The mechanism
underlying pool.ntp.org project (a multi-stage mechanism which "targets the
users to servers in/near their country and does a weighted
[round-robin](https://en.wikipedia.org/wiki/Round-robin_DNS) just on those
servers"), is not a perfectly precise balancing mechanism (e.g. some clients
will "stick" to a server long after the pool.ntp.org record has updated).

| Metric            | Amazon Web Services | Google Compute Engine |
|-------------------|--------------------:|----------------------:|
| packets recvd/sec |             3033.89 |               3115.38 |
| packets sent/sec  |             2794.60 |               2909.26 |
| GiB recvd/month   |             564.71  |                579.88 |
| GiB sent/month    |             520.17  |                541.51 |
| $ / GiB sent      |              $0.09  |                 $0.12 |
| $ / month         |             $46.82  |                $64.98 |

<div class="alert alert-success" role="alert">

Although we present statistics for both inbound (NTP queries to our server) and
outbound traffic (NTP responses from our server), it is the outbound traffic
which is of particular interest to us, for the inbound traffic is usually free,
and the outbound traffic is usually metered (both AWS and GCE charge for
outbound traffic but not inbound).  We have attempted to maintain a consistent
coloring scheme for our charts, using blue for inbound (free) and green for
outbound (metered). The mnemonic is that green, the color of US currency, is the
metric for which we pay.

</div>

### <a name="infrastructure">1.1 The Right Infrastructure Can Drop the Data Transfer Costs to $0</a>

We believe that the choice of IaaS is the most important factor in determining
costs. For example, running an NTP server on GCE would have an annual cost of
$945.36, and running a similar server on DigitalOcean would cost $120 — that
represents an **87% reduction in total cost and an annual savings of $825.36**.

Our GCE configuration assumes a _g1-small_ instance (1 shared CPU, 1.7 GiB) RAM
($0.019 per hour) running 24x7 (30% Sustained Use Discount) for a monthly cost
of $13.80. We then add the monthly data transfer costs of $64.98 for a monthly
total of $78.78, annual total of $945.36.

DigitalOcean offers [2TB/month](https://www.digitalocean.com/pricing/) free on
their $10/month server; which should be adequate for the highest-trafficked NTP
servers in the pool (i.e. US-based, 1000 Mbit connection speed), which typically
have 1.1 - 1.4 TiB aggregate inbound and outbound traffic. <sup><a
href="#digital_ocean_bandwidth_metering">[DigitalOcean bandwidth
metering]</a></sup>

The NTP server need not reside in an IaaS; it is equally effective in a
residence. In fact,  savvy home users who have a static IP, have set up an NTP
server, and who are comfortable sharing their NTP service with the community at
large are encouraged to join the pool.

It is particularly important when setting up an NTP server in a residence to
set an appropriate connection speed (see next section).

### <a name="speed">1.2 Connection Speed Setting</a>

The most important tool to control the amount of traffic your NTP server
receives is to use the "Net speed/connection speed" setting in the [Manage
Servers](https://manage.ntppool.org/manage) page. Its thirteen settings cover
more than three orders of magnitude.

Using our GCE NTP server as an example, at the highest setting (1000 Mbit), we
incur $64.98/month, and at the lowest setting (384 Kbit), $0.02/month.

The tool isn't precise: as previously mentioned, round-robin DNS is a blunt
instrument. We have two NTP servers based in the US whose connection speed is
set to 1000Mbit, and yet their outbound traffic differs by 4% (our AWS server
carries 4% less traffic than our GCE server). Using the connection speed will
get you in the ballpark, but don't expect precision.

According to pool.ntp.org:

> The net speed is used to balance the load between the pool servers. If your
connection is asymmetric (like most DSL connections) you should use the lower
speed.

In our residence, our cable download speed is 150Mbps, but our upload speed is a
mere 10Mbps, so we set our pool.ntp.org's server setting to "10Mbit"

> The pool will only use a fraction of the "netspeed setting"

The million-dollar question: what is the fraction, exactly? **about 2%**
worst-case scenario (i.e. server is placed in the United States). Assuming 90
bytes per NTP packet, 1,000,000,000 bits per Gbit, aggregating inbound and
outbound (2Gbps total aggregate bandwidth per server), we calculate the
bandwidth to be, on our 4 servers, 2.10%, 2.16%, 0.67%, and 0.35%.

Our home connection is not metered, so we don't incur bandwidth charges (i.e.
it's free).

{{< responsive-figure src="https://cloud.githubusercontent.com/assets/1020675/22177615/4e8c1940-dfd6-11e6-9a2f-a33e0bc07c8d.png" caption="The pool.ntp.org project's menu option on the server management page allows you to throttle the traffic on your server. The lower your connection speed, the less traffic your server will receive, and the lower the bandwidth costs." >}}

The aggregate "netspeed" for the US zone is [86798173
kbps](https://community.ntppool.org/t/feedback-why-is-my-ntp-server-costing-me-500-per-year/146/5?u=cunnie). This implies the following:

* Our GCE server (and also our AWS server) accounts for 1.15% of the US NTP pool traffic
* The entire US NTP pool is queried 270,376&times; every second
* The entire US NTP pool responds (assuming rate-limiting) 252,495&times; every second
* The entire US NTP pool transfers 45.9TiB in NTP responses monthly
* Using GCE, the entire US NTP pool would cost $4,078 in monthly data transfer costs (GCE's pricing tiers for $/GiB-month are $0.12 for TiB 0-1, $0.11 for TiB 1-10, $0.08 for TiB 10+)

### <a name="geography">1.3 Geographical Placement</a>

The placement of the NTP server has dramatic effect on the bandwidth and cost.
For example, our German NTP server's typical outbound monthly traffic is 82.63
GiB, which is **85% less bandwidth** than our US/Google server's monthly 541.51
GiB.

{{< responsive-figure src="https://docs.google.com/spreadsheets/d/1yvHpDjaD3pOV2C0-Zb9ljdvdWxDc9V8oZnF5IvfLZew/pubchart?oid=1739925391&format=image" >}}

A note about placement: The pool.ntp.org project allows participants to place
servers in various zones. A "zone" consists of a country and that country's
continent (there are non-geographic vendor zones as well, e.g. Ubuntu has a zone
"ubuntu.pool.ntp.org", but those zones fall outside the scope of this
discussion). The pool will "[will try finding the closest available
servers](http://www.pool.ntp.org/zone)" for NTP clients, which may or may not be
in the same zone.

We don't have NTP servers on all continents (we're missing Antarctica, Oceania,
and South America), so we don't have insight on the bandwidth requirements for
NTP servers placed there; however, we do know that our server in Asia is not as
stressed as our US/Google server (166.00 GiB vs. 541.51 Gib).

We were curious why the load on our German server was so light, and we
believe that part of the reason is that there is much greater participation
in the pool.ntp.org project in Europe. Europe, with 2,686 servers, has almost
exactly 3&times; North America's meager 895 servers.

{{< responsive-figure src="https://cloud.githubusercontent.com/assets/1020675/22177616/4e8c8772-dfd6-11e6-8ac1-e789b5ca457a.png" caption="The ntp.pool.org's servers, broken out by continent." >}}

### <a name="rate_limiting">1.4 Rate Limiting</a>

We have found that by enabling NTP's [rate
limiting](http://doc.ntp.org/4.2.4/accopt.html) feature can reduce the outbound
traffic by 9.56% on average (as high as 16.60% for our German server and as low
as 6.57% for our GCE server).

But don't be fooled into thinking that rate limiting's sole purpose is to reduce
traffic a measly 9%. Rate limiting has an unintended side benefit: it throttles
traffic during excessive NTP query events. For example, Snapchat released a
broken iOS client which placed excessive load on NTP servers (see
[below](#how_much) for more information) in mid-December. Traffic to our AWS
server, normally a steady 600 MiB / hour, spiked viciously. In one particular
hour (12/18/2016 04:00 - 0500 UTC), the inbound traffic climbed almost ninefold
to 4.97 GiB! Fortunately, rate limiting kicked in, and rejected 69.30% of the
traffic, which reduced our cost for that hour by 69.30%, for we are charged only
for outbound traffic.

Rate limiting is enabled by adding the `kod` and `limited` directives in the NTP
servers configuration file. In our servers' configuration, we use the
[suggested](http://support.ntp.org/bin/view/Support/AccessRestrictions#Section_6.5.1.1.3.)
restrictions for servers "who allow others to get the time" and "to see your
server status information". Links to our `ntp.conf` files can be found
[here](#ntp_charts).

```
restrict    default limited kod nomodify notrap nopeer
restrict -6 default limited kod nomodify notrap nopeer
```

Disclaimer: we're not 100% sure it was rate-limiting that clamped down on our
outbound traffic. There is a small chance that it was another factor, e.g. ntpd
was overwhelmed and dropped packets, AWS (or GCE) stepped in and limited
outbound NTP traffic. We haven't run the numbers.

## <a name="join">1.5 Join the Pool</a>

We encourage those with NTP servers with static IPs to join the pool; the
experience has been personally rewarding and professionally enriching (how many
can claim to operate a service with thousands of requests per second?).

We also lay out a cautionary tale: when joining, keep an eye to costs,
especially bandwidth. Opting for a lower connection speed initially (e.g.
10Mbps), and ratcheting it up over time is a prudent course of action.

## <a name="side_topics">2. Side Topics</a>

### <a name="google_ntp">2.0 The Cavalry is Coming: Google's Public NTP Servers</a>

[Google has announced public NTP
servers](https://cloudplatform.googleblog.com/2016/11/making-every-leap-second-count-with-our-new-public-NTP-servers.html).
Over time, we suspect that this will reduce the load on the pool.ntp.org
project's servers.

<div class="alert alert-warning" role="alert">

Servers in the NTP Pool should <strong>not</strong> use Google's NTP servers as
upstream time providers, nor should they use any upstream provider which
"smears" the leap second.

</div>

&nbsp;

There is a schism in the community regarding [leap
seconds](https://en.wikipedia.org/wiki/Leap_second):

* The NTP pool supports the leap second, which is the UTC standard. The advantage
of the leap second is that every second is always the same length, i.e.
"9,192,631,770 periods of the radiation emitted by a caesium-133 atom in the
transition between the two hyperfine levels of its ground state".

* Google, on the other hand, [smears the leap
second](https://developers.google.com/time/smear), which lengthens the second by
13.9µs during the ten hours leading up to and following the leap seconds. Their
reasoning is, "No commonly used operating system is able to handle a minute with
61 seconds".

For readers interested in using Google's NTP service, the server is
*time.google.com*.

### <a name="how_much">2.1 The Snapchat Excessive NTP Query Event Cost $13 - $18 (Per Server)</a>

In December Snapchat released a [version of its iOS app that placed undue
stress](http://www.theregister.co.uk/2016/12/21/snapchat_coding_error_nearly_destroys_all_of_time_for_the_internet/)
on the pool.ntp.org servers.

This event caused [great
consternation](https://community.ntppool.org/t/recent-ntp-pool-traffic-increase/18)
among the NTP server operators, and words such as "decimated", "server loss",
and "sad" were used.

The effect on two of our servers can be readily seen by our bandwidth graph.
First, our AWS server:

{{< responsive-figure src="https://docs.google.com/spreadsheets/d/1yvHpDjaD3pOV2C0-Zb9ljdvdWxDc9V8oZnF5IvfLZew/pubchart?oid=355797491&format=image" >}}

Our AWS chart presents hourly inbound and outbound traffic, measured in MiB.
Times are in UTC.

Note the following leading up to the event:

- Inbound traffic is fairly steady, averaging 611 MiB/hour, and so is outbound traffic, averaging 562 MiB/hr.
- There's little difference between inbound and outbound traffic (i.e. ntpd's
rate-limiting is kicking in at a modest ~8%).

Note the following about the event and its aftermath:

- The onset of the event was sudden: on 12/13/2016, inbound traffic jumped from
12.7 GiB the previous day to 18.2 GiB.
- There were unexplained dips in traffic during the event. For example, on
12/16/2016 0:00 - 3:00 UTC, the inbound traffic fell below 300 MiB/hr. Not
only was this extremely low in the midst of an NTP excessive query-event, but
it would have been abnormally low during regular service.
- The event had a long tail. Even though Snapchat released a fix, traffic hadn't
normalized by the end of December. Things had improved, but they hadn't gotten
gotten back to normal.

Next, we present our GCE bandwidth chart:

{{< responsive-figure src="https://cloud.githubusercontent.com/assets/1020675/21468123/ac026274-c9d2-11e6-8334-2f56e9c9d20f.png" >}}

Our GCE chart presents per second inbound and outbound traffic, measured in
packets. Times are in EST.

Note the following:

- Unlike AWS, there were no unexplained dips in traffic.
- Google smoothed the graph — it's not as jagged as AWS's.
- Similar to AWS, the traffic is steady leading up to the event.
- The traffic during the event can clearly be seen to follow a daily rhythm.
- The peak-to-baseline ratio matches that of the AWS graph (baseline of 3.1 kpackets/sec, peak of 25kpackets/sec, shows an 8.3&times; increase; AWS's was 9&times;).
- Rate-limiting clamped down on the most egregious traffic, containing costs.

For our last chart, we took our AWS statistics and did the following:

- We stretched the timescale: we went as far back as 2016-11-01 and as far forward
as mid-January, 2017.
- We examined traffic daily, not hourly, to reduce the spikiness.
- It was easy to mark the beginning of the event (2016-12-13): it came in with a bang.
- It was difficult to mark the ending of the event: it went out with a whimper. There
was no sudden cliff as traffic fell, rather, it was a slow dwindling of traffic. We chose,
for better or worse, to delineate the end of the event by marking a local minimum of
traffic (2017-01-12). Note that traffic remained significantly above the baseline after that point.

{{< responsive-figure src="https://cloud.githubusercontent.com/assets/1020675/22092441/6cacc986-ddb2-11e6-80d8-52f61d3d8364.png" caption="overly-annotated chart of NTP data transfer">}}

How much did the NTP event cost us? By our reckoning, the event lasted 30 days,
and the average amount of daily traffic above the baseline was 4.97 GiB, for a
total of 149.1 GiB. Given that AWS charges $0.09 per GiB, the total cost of the
Snapchat event for our AWS server was **$13.42**. We can extrapolate for our GCE
server: the amount of traffic would be similar, but Google's bandwidth is 33%
more expensive ($0.12 vs. AWS's $0.09), giving us an estimate of **$17.90**.

There were no additional costs for our German server (we did not exceed the
bundled bandwidth).

### <a name="adequate">2.2 Are Virtual Machines Adequate NTP Servers? Yes.</a>

Are Virtual Machines adequate NTP servers? The short answer is, "yes", but the
long answer is more complex.

First, timekeeping within a VM is complicated (see the excellent [VMware
Paper](http://www.vmware.com/pdf/vmware_timekeeping.pdf) for a thorough
analysis): there are two ways that a computer (VM) measures the passage of time
(tick counting & tickless timekeeping). Tick counting can result in "lost
ticks", which means the clock loses time (it slows down compared to true time),
and tickless timekeeping, which, although eliminates the "lost ticks" problem,
brings its own set of baggage with it (e.g. the hypervisor must know or be
notified that the VM is using tickless timekeeping).

The result is that a VM's clock can drift quite a bit. In one
[serverfault.com](http://serverfault.com/questions/106501/what-are-the-limits-of-running-ntp-servers-in-virtual-machines)
post, a contributor stated,

> in the pure-VM environment would probably be within, oh, 30 to 100ms of true

And another contributor added:

> Running NTP in a virtualised [sic] environment, you'll be luck to achieve 20ms accuracy (that's what we've done using VMware).... NTP servers should always be on physical hosts

But that flies in the face of our experience. Our VM NTP server on Google's cloud
has excellent timekeeping: **99% of its time is within +2ms/-2ms of true**.
Don't take our word for it, look at the chart
<sup><a href="#ntp_charts">[NTP charts]</a></sup> :

{{< responsive-figure src="https://cloud.githubusercontent.com/assets/1020675/21662851/2a6a1622-d291-11e6-9ace-dd12baf6929c.png" >}}

Disclaimer: we cherry-picked our best NTP server; our other servers aren't as
accurate. Our Hetzner server, via IPv6, is typically
[+4ms/-4ms](http://www.pool.ntp.org/scores/2a01:4f8:c17:b8f::2), and via IPv4 is
typically [+10ms/-10ms](http://www.pool.ntp.org/scores/78.46.204.247), our AWS
server [+20ms/-20ms](http://www.pool.ntp.org/scores/52.0.56.137), and so is our
[Microsoft Azure server](http://www.pool.ntp.org/scores/52.187.42.158).

Our numbers are surprisingly good especially given that the [monitoring
system](https://github.com/abh/ntppool/blob/b7d86c1a069e463748c2e54e9545af1183c293c0/docs/ntppool/en/tpl/server/graph_explanation.html#L3-L19)
used to collect the numbers is susceptible to random network latencies:

>  The monitoring system works roughly like an SNTP (RFC 2030) client, so it is
more susceptible by random network latencies between the server and the
monitoring system than a regular ntpd server would be.

> The monitoring system can be inaccurate as much as 10ms or more.

We caution the reader not to extrapolate the efficacy of various IaaSes based on
the timekeeping of a VM on that IaaS. For example, it would be unwise to assume
that Google Cloud is 5 times better than AWS because our Google VM's NTP server
is 5 times more accurate. In the Google vs. AWS case, our AWS NTP server is a
lower-tier [t2.micro](https://aws.amazon.com/ec2/instance-types/), A [Burstable
Performance Instance](https://aws.amazon.com/ec2/instance-types/#burst) which
Amazon recommends against using for applications which consistently require CPU:

> If you need consistently high CPU performance for applications such as video
encoding, high volume websites or HPC applications, we recommend you [don't use
Burstable Performance Instance].

We also find that the network plays a role in the accuracy of the NTP servers.
We suspect that is one of the reasons that our Microsoft Azure VM, which is
located across the globe (from the Los Angeles-based monitoring station) in
Singapore, has among the least accurate metrics. Which leads into our next
topic.

### <a name="network">2.3 Sometimes It's the Network, not the VM</a>

We were convinced that the network was often a bigger factor than virtualization
in NTP latency, but how to prove it? If only we were able to have two exactly
identical NTP servers on different networks and measure differences in latency.
But how to accomplish that?

Dual-stack.

That's right: one of our NTP servers (shay.nono.io) was dual-stack: it had both
IPv4 and IPv6 addresses on its single ethernet interface, which eliminated
differences in IaaSes, operating systems, RAM, cores, etc... as factors in
latency.

And the difference between the IPv4 and IPv6 was striking:

* The IPv6 stack never dropped a packet; The IPv4 stack dropped a 4 packets over
  the course of three days.
* The IPv6 stack is tightly concentrated in the +3/-4ms range; the IPv4 stack,
  on the other hand, sprawls across the +20/-20ms range.

The upshot is that the network can affect the latency as much as threefold. In
the charts below, you can see differences between the IPv6 (top chart) and
IPv4 (bottom chart). Note that the latency (offset) is measured on the _left_
axis:

{{< responsive-figure src="https://cloud.githubusercontent.com/assets/1020675/22265983/207b73e8-e233-11e6-9ee6-1a05f9d79998.png" >}}

{{< responsive-figure src="https://cloud.githubusercontent.com/assets/1020675/22265984/207f3834-e233-11e6-9557-de568939901f.png" >}}

There are those who might say, "But the comparison is unfair — IPv6 has builtin QOS
(Quality Of Service). Of course IPv6 would have better performance!"

Rather than argue the relative merits of IPv6 vs. IPv4, we would prefer to
present a counter-example: we have a _second_ timeserver (time-home.nono.io)
that is dual stack, and it exhibits the opposite behavior (the IPv4 latency is
better):

* The IPv4 stack is concentrated on the -2/-10ms range (8 millisecond spread); the
  IPv6 traffic has spread that's twice as wide, +10/-5ms (15 millisecond spread).

Although this server is not as an extreme example of latency differences as the
previous one, it supports our contention that the network can have a powerful
effect on latency.

For your consumption, we present the charts below, you can see differences
between the IPv6 (top chart) and IPv4 (bottom chart). Note that the latency
(offset) is measured on the _left_ axis:

{{< responsive-figure src="https://cloud.githubusercontent.com/assets/1020675/22265981/20673a68-e233-11e6-8ad9-4d0683b2edfd.png" >}}

{{< responsive-figure src="https://cloud.githubusercontent.com/assets/1020675/22265982/2068c888-e233-11e6-9d3b-ed109947e499.png" >}}

## <a name="footnotes">Footnotes</a>

<sup><a name="cost_doubling">[Traffic increase]</a></sup>

Our costs increased 50% for a simple reason: the amount of NTP traffic
increased. When we wrote the original blog post in two and a half years ago in
June 2014, our monthly outbound traffic was 332 GiB; in January 2017 it had
climbed to 542 GiB (for our GCE NTP server, 520 GiB for our AWS NTP server).

We are not sure the reason behind the increase, but it tracks closely with the
growth of the public cloud infrastructure. [According to
IDC](https://www.idc.com/getdoc.jsp?containerId=prUS41599716):

> The public cloud IaaS market grew 51% in 2015. IDC expects this high growth to
continue through 2016 and 2017 with a CAGR of more than 41%.

<sup><a name="aws_network_data">[AWS Network Data]</a></sup>

We needed more data.  We turned to Amazon's [Usage Reports](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/usage-reports.html).

**AWS Console &rarr; My Account &rarr; Reports &rarr; AWS Usage Report &rarr; Amazon Elastic Compute Cloud**

  We ran a report requesting the following information:

* Usage Types: **DataTransfer-Out-Bytes**
* Operation:  **All Operations**
* Time Period:  **Custom date range**
  * from: **Dec 1 2016**
  * to: **Jan 18 2017**
* Report Granularity: **Hours**
* click **Download report (CSV)**

We downloaded the report and imported it into a spreadsheet ([Google
Sheets](https://docs.google.com/spreadsheets/d/1yvHpDjaD3pOV2C0-Zb9ljdvdWxDc9V8oZnF5IvfLZew/edit?usp=sharing)).

<sup><a name="ntp_statistics">[NTP statistics]</a></sup>

NTP statistics are derived from two servers in the NTP pool (ns-aws.nono.io and
ns-gce.nono.io) by using the `ntpq` command after they had been running for a
week. Here is the output of the command when run on the ns-gce.nono.io NTP
server:

```text
$ ntpq -c sysstats
uptime:                601851
sysstats reset:        601851
packets received:      1874993118
current version:       1455746472
older version:         418760288
bad length or format:  534317
authentication failed: 361395
declined:              393
restricted:            15845
rate limited:          123140728
KoD responses:         15874848
processed for time:    2554
```

These numbers are necessary but not sufficient: we want to know, "how much will
my data transfer cost each month?" <sup><a href="#aws_data_transfer_cost">[AWS
data transfer cost]</a></sup> To determine that, we'll need to know Amazon
data transfer pricing, our inbound and especially outbound
traffic, and the size of NTP packets in bytes.

We derive additional statistics using the above numbers. In the above example
(which was the output from our Google NTP server on Thu Jan  5 04:02:45 UTC 2017)
we were able to calculate the traffic in GiB per month as follows:

- **packets sent** = packets received - bad length or format - authentication failed - declined - restricted - rate limited = **1750940440** <sup><a href="#ntp_packets_sent">[NTP packets sent]</a></sup><br />
- **packets received per second** = packets received / uptime = **3115.38**
- **packets sent per second** = packets sent / uptime = **2909.26**
- **packets received per month** = packets received / uptime × 60 secs/min × 60 mins/hr × 24 hr/day × 30.436875 day/month = **8192651756**
- **packets sent per month** = packets sent / uptime × 60 secs/min × 60 mins/hr × 24 hr/day × 30.436875 day/month = **7650612225**
- **gigabytes received per month** = packets received per month × bytes per packet <sup><a href="#ntp_packet_size">[NTP packet size]</a></sup> × gigabytes per byte = **579.88**
- **gigabytes sent per month** = packets sent per month × bytes per packet  × gigabytes per byte = **541.51**

[The average number of days per
month](https://www.quora.com/What-is-the-average-number-of-days-in-a-month) in
the Gregorian calendar is 365.2425 / 12 = **30.436875**. It would be
irresponsible for a post about NTP to casually peg the number of days in a month
to 30. Respect time.

The raw data from which the numbers in this blog post are derived can be found
in a
[spreadsheet](https://docs.google.com/spreadsheets/d/1yvHpDjaD3pOV2C0-Zb9ljdvdWxDc9V8oZnF5IvfLZew/edit?usp=sharing).
The organization is haphazard. The data contained therein is released into the
public domain.

<sup><a name="aws_data_transfer_cost">[AWS data transfer]</a></sup>

AWS charges [**$0.09 per
GiB**](https://aws.amazon.com/ec2/pricing/on-demand/#Data_Transfer) for Data
Transfer (bandwidth) OUT from Amazon EC2 us-east-1 (Virginia) region to
Internet. Inbound data transfer is free.

As with much of Amazon pricing, this is a rule-of-thumb and subject to qualifiers:

* Amazon has volume discounts; e.g. traffic above 10TB/month is charged at
$0.085/GiB, above 50TB/month is charged at $0.07/GiB, etc...
* Amazon charges much less for traffic to other Amazon datacenters (e.g. outbound
traffic to another AWS Region is $0.02/GiB)
* Inbound traffic is not always free; Amazon charges, for example, $0.01/GiB
for traffic originating from the same Availability Zone using a public or Elastic IPv4 address

In spite of these qualifiers, we feel the $0.09/GiB is an appropriate value to
use in our calculations.

AWS [measures](https://forums.aws.amazon.com/thread.jspa?threadID=151161) their
data transfer pricing in terms of [GiB](https://wikipedia.org/wiki/Gibibyte)
(2<sup>30</sup>) instead of [GB](https://en.wikipedia.org/wiki/Gigabyte)
(10<sup>9</sup>) (although their documentation refer to the units as "GB").

<sup><a name="google_data_transfer_cost">[Google data transfer]</a></sup>

Google charges [**$0.12 per
GiB**](https://cloud.google.com/compute/pricing) for Data
Transfer (bandwidth) OUT from Google Cloud Platform.

Similar to AWS's data transfer pricing, there are qualifiers:

* Google has volume discounts (e.g. with tiers at 1TB ($0.11) and 10TB ($0.08))
* Egress to China (but not Hong Kong) is almost double (e.g. $0.23). Network Egress
to Australia is also more expensive ($0.19)
* Prices do not apply to Google's Content Deliver Network (CDN) service

We find Google's pricing to be simpler than Amazon's — Google's pricing is
uniform across Google's datacenters, whereas Amazon's data transfer costs can
vary by region (datacenter).

Google [explicitly defines](https://cloud.google.com/compute/pricing) their data
transfer pricing in terms of [GiB](https://wikipedia.org/wiki/Gibibyte)
(2<sup>30</sup>) instead of [GB](https://en.wikipedia.org/wiki/Gigabyte) (10<sup>9</sup>). A GB is 0.931 the size of a GiB (the GiB is bigger, and handsomer too, I might add):

> Disk size, machine type memory, and network usage are calculated in gigabytes (GB), where 1 GB is 2<sup>30</sup> bytes

<sup><a name="digital_ocean_bandwidth_metering">[DigitalOcean bandwidth metering]</a></sup>

DigitalOcean's bandwidth pricing is more aspirational than actual: They have not
yet implemented bandwidth metering, though they plan to do so in the future. Per
their response to our ticket opened on 2017-01-17 (boldface ours):

> We do not have a pricing scheme set up yet for bandwidth. As such, we do not
actually charge for it. Our engineering team is working on a solution for this,
but it has not been given an ETA. We often suggest customers who are heavy BW
utilizes to just **be kind** to our platform & **be mindful** when we reach out
with requests to slow down just a bit, as times, it can become disruptive to
customers downstream.

Some may be tempted, knowing that the bandwidth is not measured, to opt
for the lower-tier $5/month server (with 1TB bandwidth) to provide an NTP server
to the community. We find such a decision to be on ethically shaky ground, for
we know that our bandwidth would most likely exceed that amount (we estimate 1.1 -
1.4 TiB aggregate inbound and outbound), and we'd be taking advantage of
DigitalOcean's momentary bandwidth blind spot. As such, any benefits we would
provide to the community would be, in a sense, fruit of a poisonous tree.

<sup><a name="ntp_packets_sent">[NTP packets sent]</a></sup>

Although `ntpq -c sysstats` does not display the number of packets sent (only
the number of packets received), the number can be calculated from the remaining
fields, i.e. the number of packets sent minus the number of packets dropped.
According to [opsenswitch.net](http://www.openswitch.net/documents/user/ntp_user_guide#generic-tips-for-troubleshooting), these are the categories of packets that are dropped:

* bad length or format
* authentication failed
* declined
* restricted
* rate limited

<sup><a name="ntp_packet_size">[NTP packet size]</a></sup>

IPv4 NTP packets are **76 octets** (bytes) (IPv6 NTP packets are 96 octets, but
we ignore the IPv6 packet size for the purposes of our calculations — the two
servers (AWS & Google) from which we gather statistics are IPv4-only).

We calculate the size as follows: we know the size of an NTP packet is almost
always 48 bytes (it can be longer; the [NTP
RFC](https://tools.ietf.org/html/rfc5905#section-7.3) allows for for extension
fields, key identifiers, and digests in the packet, but in practice we rarely
see those fields populated).

The NTP packet is encapsulated in a User Datagram Protocol (UDP) packet, which
adds [8 octets](https://en.wikipedia.org/wiki/User_Datagram_Protocol#Packet_structure)
to the length of the packet, bringing the total length to 56.

The UDP packet in turn is encapsulated in an IP (IPv4 or IPv6) packet. IPv4 adds
[20 octets](https://en.wikipedia.org/wiki/IPv4#Header) to the length of the
packet, bringing the total to 76. IPv6 adds [40
octets](https://en.wikipedia.org/wiki/IPv6_packet#Fixed_header) to the length,
for a total of 96.

The IP packet in turn is encapsulated in an Ethernet II packet. The Ethernet II
header does not include the 7-octet Preamble, the 1-octet Start of frame
delimiter, the optional 802.1Q tag (we're not using VLAN-tagging), nor the
4-octet Frame check sequence. It *does* include the 6-octet MAC destination and
the 6-octet source, as well as the 2-octet ethertype field, which adds [14
octets](https://en.wikipedia.org/wiki/Ethernet_frame#Structure) to the length,
for a grand total packet size of **90 bytes for IPv4** and **110 bytes for
IPv6**.

To confirm our calculations, we turn to `tcpdump`, a popular network sniffer (a
tools which listens, filters, and decodes network traffic). We use it to expose the
lengths of an IPv4 NTP packet.

* The Ethernet II packet has a length of 90 octets ("length 90")
* The IPv4 portion has a length of 76 octets ("length 76")
* The NTP packet has a length of 48 octets ("NTPv4, length 48")

```
$ sudo tcpdump -ennv -i vtnet0 -c 1 port ntp
tcpdump: listening on vtnet0, link-type EN10MB (Ethernet), capture size 262144 bytes
07:42:13.181157 d2:74:7f:6e:37:e3 > 52:54:a2:01:66:7d, ethertype IPv4 (0x0800), length 90: (tos 0x0, ttl 44, id 0, offset 0, flags [DF], proto UDP (17), length 76)
    107.137.130.39.123 > 172.31.1.100.123: NTPv4, length 48
  Client, Leap indicator: clock unsynchronized (192), Stratum 0 (unspecified), poll 4 (16s), precision -6
  Root Delay: 1.000000, Root dispersion: 1.000000, Reference-ID: (unspec)
    Reference Timestamp:  0.000000000
    Originator Timestamp: 0.000000000
    Receive Timestamp:    0.000000000
    Transmit Timestamp:   3692878933.085937805 (2017/01/08 07:42:13)
      Originator - Receive Timestamp:  0.000000000
      Originator - Transmit Timestamp: 3692878933.085937805 (2017/01/08 07:42:13)
1 packet captured
2 packets received by filter
0 packets dropped by kernel
```

Note the flags passed to `tcpdump`:

* `-e` capture the Ethernet frame, needed for Ethernet II length.
* `-nn` don't lookup hosts, don't lookup ports
* `-v` breaks out the size of the UDP packet (56 octets)
* `-i vtnet0` specifies a particular Ethernet interface (typically `eth0` on Linux)
* `-c 1` capture one packet then exit
* `port ntp` listen for IPv4 packets whose source or destination port is NTP's (123)

To capture an IPv6 packet, use this variation:

```
sudo tcpdump -ennv -i vtnet0 -c 1 ip6 and port ntp
```

AWS does not bill for the layer 2 (data link layer, Ethernet II) of traffic,
only for the IP portion. In other words, NTP packets have a length of 76 octets
(as far as billing measurement is concerned). <sup><a
href="#aws_net_metrics">[AWS Network Metrics]</a></sup>

Google, too, does not bill for layer 2 traffic, only for IP traffic.
<sup><a href="#gce_net_metrics">[Google Network Metrics]</a></sup>


<sup><a name="aws_net_metrics">[AWS Network Metrics]</a></sup>

We are confident that AWS charges only for the IP-portion of network packets
and not the Ethernet portion, but we were unable to find this explicitly in
writing. We deduced it by running the following test.

First, we measured the amount of NTP traffic over a one-hour period using the
following command on our AWS NTP server. We kicked off the command on Wed Jan
25 05:00:00 UTC 2017:

```
ntpq -c sysstat; sleep 3600; ntpq -c sysstat; date
...
Wed Jan 25 06:00:00 UTC 2017
```

The number of inbound packets received during the hour was 9,961,945. Now that
we know the number of packets, we need to find out the number of bytes. And then
it's simple math: we divide the number of bytes by the number of packets. If the
number is close to 90, then AWS is measuring the Ethernet frame, 76, the IP
frame. We expect the number of inbound bytes to be approximately 757,107,820
(76 &times; 9,961,945).

We generate an AWS Usage report of inbound bytes:

AWS Console → My Account → Reports → AWS Usage Report → Amazon Elastic Compute Cloud

Calamity has struck! The number of inbound bytes from 05:00-06:00 is 657,882,293
is much too small. Not even close. Not even possible. The absolute minimum
number of bytes is 757,107,820 (that's the number of NTP packets &times; the
minimum NTP packet size, 76 bytes). It's possible to have _more_ traffic (e.g.
larger NTP packets, non-NTP traffic (ssh, DNS)), but not less.

Here's a snippet of the CSV downloaded from AWS:

```
Service, Operation, UsageType, Resource, StartTime, EndTime, UsageValue
...
AmazonEC2,RunInstances,DataTransfer-In-Bytes,,01/25/17 05:00:00,01/25/17 06:00:00,657882293
...
```

With the numbers we have, there are ~66 bytes per packet, and we need to get to
76 bytes per packet.

Maybe the report is in a different time zone? No, we know that "[All usage
reports for AWS services are in
GMT](https://forums.aws.amazon.com/thread.jspa?threadID=88004)".

Aha! We forgot the Usage Type _DataTransfer-Regional-Bytes_. We run that report
and see the following data:

```
Service, Operation, UsageType, Resource, StartTime, EndTime, UsageValue
...
AmazonEC2,InterZone-In,DataTransfer-Regional-Bytes,,01/25/17 05:00:00,01/25/17 06:00:00,2052
AmazonEC2,PublicIP-In,DataTransfer-Regional-Bytes,,01/25/17 05:00:00,01/25/17 06:00:00,76761576
```

Here is an interesting tidbit: **10% of the inbound NTP traffic
originates from within the Amazon cloud**.

We decide to create a chart to visually express how closely our NTP server's
statistics matches AWS's data transfer metrics assuming that NTP packets are 76
bytes:

{{< responsive-figure src="https://docs.google.com/spreadsheets/d/1yvHpDjaD3pOV2C0-Zb9ljdvdWxDc9V8oZnF5IvfLZew/pubchart?oid=1439682529&format=image" >}}

The NTP server's statistics are collected every five minutes, and are thus a line.
The AWS data transfer statistics are coarser, only by the hour, and show up as purple dots.
It's evident that the two correlate, within a few percentage points.

We expected the AWS's numbers to exceed ours by a slight amount, for our numbers
collected via `ntpq` only report the NTP traffic, and we know that our server
carries other traffic as well (it's a DNS server, too); however, we found the
opposite to be true: the traffic reported by AWS was consistently smaller than
our NTP traffic, albeit by a small amount. We are not sure why, and are
presenting this as a mystery.

To collect our statistics, we ran the following on our NTP server:

```
while :; do
  /var/vcap/packages/ntp/bin/ntpq -c sysstat > /tmp/ntp.$(date +%s)
  sleep 300
done
```

We waited several hours, then collated everything:

```
cd /tmp/
grep -h received ntp.* | awk '{print $3}' > five_minute_intervals.ntp
```

We uploaded the file into Google Sheets, calculate the delta between the five
minute intervals, created a rolling hourly sum, and compared it with the output
of the AWS usage report.

<sup><a name="gce_net_metrics">[Google Network Metrics]</a></sup>

We are confident that Google charges only for the IP-portion of network packets
and not the Ethernet portion, but we were unable to find this explicitly in
writing. Instead, we inferred this via the manner in which Google measures
packet size, and were so pleased with our methodology that we would like to
share it.

First, we brought up in our browser the Google Compute Engine Dashboard, twice.
Then we selected our NTP server VM, twice. On one, we selected, "Network
Packets", and the other we selected "Network Bytes". The following is a mash-up
of the two charts:

{{< responsive-figure src="gce_bytes_packets_annotated" src="https://cloud.githubusercontent.com/assets/1020675/21968913/b43f69b8-db4e-11e6-8718-cc35bea3de02.png" >}}

Having both numbers allowed us to calculate the number of bytes per packet.
If the number was close to 90 bytes per packet, then Google was including the
Ethernet/data link layer. If the number was close to 76 bytes per packet, then
Google was only counting the IPv4 portion of the packet.

Our numbers? 76.19 and 76.06, within 0.25% of 76 bytes. Our conclusion? Google
is only counting the IPv4 portion of the packet. (You may ask why we are not
concerned that the average number of bytes per packet is not _exactly_ 76 bytes.
The answer? The servers carry traffic other than NTP (e.g. the Google server is
both a DNS server and a [Concourse](http://concourse.ci/) continuous
integration (CI) server, which often have packet sizes other than 76 bytes.
Also, a small portion of NTP packets are greater than 76 bytes).

<iframe style="width: 100%" src="https://docs.google.com/spreadsheets/d/1yvHpDjaD3pOV2C0-Zb9ljdvdWxDc9V8oZnF5IvfLZew/pubhtml?gid=421145593&widget=true&headers=false&range=A46:E48"></iframe>

<sup><a name="ntp_charts">[NTP charts]</a></sup>

The NTP Pool project provides publicly-accessible charts for the servers within
the pool. Here are links to the charts of the servers that we maintain and to
their ntpd (and, in one case, their [chronyd](https://chrony.tuxfamily.org/))
configuration files:

* [Google server, US (ns-gce.nono.io)](http://www.pool.ntp.org/scores/104.155.144.4) [(ntp.conf)](https://github.com/cunnie/deployments/blob/4578625694140ccdb9303997d39686e11cd6ffe6/concourse-ntp-pdns-gce.yml#L178-L192)
* [AWS server, US (ns-aws.nono.io)](http://www.pool.ntp.org/scores/52.0.56.137) [(ntp.conf)](https://github.com/cunnie/deployments/blob/4578625694140ccdb9303997d39686e11cd6ffe6/nginx-ntp-pdns-aws.yml#L167-L181)
* [Azure server, Singapore (ns-azure.nono.io)](http://www.pool.ntp.org/scores/52.187.42.158) [(ntp.conf)](https://github.com/cunnie/deployments/blob/4578625694140ccdb9303997d39686e11cd6ffe6/nginx-ntp-pdns-azure.yml#L212-L225)
* Hetzner server, Germany (shay.nono.io) [(ntp.conf)](https://github.com/cunnie/shay.nono.io-etc/blob/86a5548d2f89ee7c0d5fd7cf20b94ea0aea2fb0c/ntp.conf):
  * [IPv4](http://www.pool.ntp.org/scores/78.46.204.247)
  * [IPv6](http://www.pool.ntp.org/scores/2a01:4f8:c17:b8f::2)
* Comcast server, US (time-home.nono.io) [(chrony.conf)](https://github.com/cunnie/fedora.nono.io-etc/blob/14ce418bdd1e9d57fe145d0f7d44ce39f479019a/chrony.conf):
  * [IPv4](http://www.pool.ntp.org/scores/73.15.134.22)
  * [IPv6](http://www.pool.ntp.org/scores/2601:646:100:e8e8::101)

## <a name="corrections">Corrections & Updates</a>

*2017-02-04*

A quote on the mechanism that pool.ntp.org uses to select servers was missing
the phrase, "just on those". The quote has been corrected.

The calculation for cost of aggregate data transfer for the entire US
pool.ntp.org did not take into account tiered pricing. Pricing was adjusted:
original cost was $5,640, adjusted cost is $4,078.

Phrasing was changed to improved readability.

We removed a comment that pointed out we had not gathered statistics for our
Azure NTP server; it seemed pointless.

*2017-02-01*

The post mis-characterized the mechanism behind the NTP pool as "round-robin
DNS"; the mechanism is more sophisticated: It targets the users to servers
in/near their country and does a weighted round-robin just on those servers.

[Ask Bjørn Hansen](https://www.askask.com/) said:

> The system is a little more sophisticated than just round-robin DNS. It
targets the users to servers in/near their country and does a weighted
round-robin just on those servers.

We have added sections describing our motives for operating NTP servers and
encouraging others to join the pool. Thanks Leo Bodnar.

We wrongly encouraged NTP pool servers to use Google's NTP servers as upstream
providers. We now warn _against_ using Google's NTP servers, and provide reasons
why (leap seconds). Thanks [Joseph
B](https://community.ntppool.org/t/feedback-why-is-my-ntp-server-costing-me-500-per-year/146/9),
Ask.

We added statistics regarding the aggregate netspeed for the US zone.

[NTP Pool
operators](https://community.ntppool.org/t/feedback-why-is-my-ntp-server-costing-me-500-per-year/146)
suggested the following IaaSes:

* Amazon Lightsail
* Linode (we've had positive experience with Linode)
* Vultr
* BuyVM
* Ramnode
* LunaNode
* Atlantic
* ARP Networks (we've had positive experience with ARP Networks)
* Scaleway
