---
authors:
- jimpark
categories:
- BOSH
- CF Runtime
date: 2016-12-20T14:53:27-08:00
draft: false
short: |
  On September 29th, 2016, Pivotal Web Services (PWS) enabled a feature available in BOSH to auto-assign public IPs to Diego cells.
title: Public IPs for diego cells
---

## What we did
On September 29th, 2016, Pivotal Web Services (PWS) enabled a feature available in BOSH to [auto-assign public IPs to Diego cells](https://bosh.io/docs/aws-cpi.html#networks, resource_pools[].cloud_properties.auto_assign_public_ip). By setting this value to true for our Diego cell instances, BOSH automatically assigned public IPs to each of our Diego cells.


## Why we did what we did
Any app in PWS that relied on external resources like a database, blobstore, or API communicated to that external resource via an active/passive HA pair of Network Address Translation (NAT) boxes. While this worked for PWS in smaller scales, PWS has continued to grow over the years.

The first issue was that we found the network burden of supporting a growing number of apps was becoming too great for the number of NAT boxes we were running. The way this manifested was steadily increasing network latency for our running apps. Our NAT boxes were already at the highest tier of AWS instance that had a 1Gbps uplink. This required addressing. Increasing the size of the NAT boxes to an instance size with a 10 Gbps uplink would have addressed this issue, but would have been problematic because of the second and third issues.

The second issue is that the failover procedure disrupts established connections. The failover is implemented by changing the [AWS route table](https://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/VPC_Route_Tables.html) to point to the new instance. The disruption happens because NAT boxes do not share NAT session table data, so the new NAT box will drop or refuse packets inbound to established clients. So every time a NAT box needed to be retired or upgraded, a fraction of apps in PWS suffered from broken outbound network sessions.

Thirdly, we assigned a NAT box pair per availability zone. This meant that for a growing number of Diego cells, we had a relatively fixed number of NAT boxes. That meant that as the number of consumers grew, the demand on the service grew, alongside the potential impact from a failure.

The NAT boxes were a bottleneck and a collective point of failure. Simply upgrading the NAT boxes indefinitely would have produced larger failure pools, and would only have served to punt the can down the road.


## How assigning public IPs to cells changed the situation
Assigning public IPs to Diego cells resolves this issue by allowing each Diego cell to communicate to the Internet “directly.”

In PWS we have an app (https://github.com/pivotal-cloudops/ping2datadog)  that pings out to a nearby target. We have enough app instances deployed of these that we can assume a somewhat uniform distribution across PWS. By reporting on the average time for a ping to return, we are able to collect heat maps of outbound network latency. After implementing direct public IPs, the bottleneck was immediately relieved, and we saw a dramatic decrease in outbound network latency.

![Improved latency when we enabled public IPs. The red and orange lines are bandwidth graphs from the active NAT boxes.](https://i.imgur.com/Oob8L7K.png)

Even if traffic were to collectively grow beyond the capacity for the network hardware on which it sits, dedicated network hardware can gracefully failover links without interrupting flow significantly. Technically, AWS public IPs are [still NAT’d](https://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/vpc-ip-addressing.html ), but this is done at a layer that is transparent to the instance, presumably by machines that maintain stateful NAT or 1-to-1 DNAT. In either case, the issue of the session table is handled.



## How you can implement
Set `resource_pools.<my diego cell subnet>.cloud_properties.auto_assign_public_ip` = true for diego cells in your CF deployment manifest.


## A note on security
I recommend configuring ACLs to allow traffic from 0.0.0.0/0 to your externally accessible assets, and using robust authentication and encryption measures instead.

One reason is simplicity and the guarantee that it provides. There is value to being able to say that “the source IP of the app is definitively not the problem. There are no ACLs in place to limit it, were it coming from AWS, or GCP, or from the corporate network.” Given a complex and growing infrastructure, ACLs introduce a variable to validate when troubleshooting why a connection is failing. Furthermore, ACLs are often constructed starting with least privilege, and growth later often requires revisiting these ACLs. Allowing access from anywhere prevents the potential problem statement of “we just scaled out to another AZ and half the app instances don’t work now.”

A second reason is that it is an ineffective security measure. The ACL reduces the field of potential attackers, but the vulnerability to various means of exploitation is not reduced once the hurdle of source IP is bypassed. Where the boundaries of source IP aligns with that of a publicly available PaaS or IaaS, this anti-pattern compounds the complexity of troubleshooting. All a savvy attacker would need to do is launch an attack from that PaaS or IaaS while the ACL assumes that the traffic is legitimate. This lends the malicious traffic undue credence. This credence can confuse responders. “The phone call is coming from inside the house.”

It’s not a house. It’s a public property. Assume that bad actors exist in the public property.

*Source-IP based ACLs provide inadequate protection from attack and complicate operations.*


Instead, it is recommended to use strong authentication that valid clients can present in order to gain access to Internet-available resources. An example for this is client certificates for authentication. A password cannot be guessed if no valid password exists. Client certificates are sufficiently complex to keep a brute force attack at [bay](https://blog.digicert.com/cost-crack-256-bit-ssl-encryption/)

If certificate-only authentication is not possible (as is the case for AWS RDS), use a password that is as long as possible alongside a second factor, such as rate limiting. The second factor increases the cost of successful attack dramatically. Some useful second factors can be found at https://lwn.net/Articles/255651/. The article is for protecting SSH, but the same principles apply.


### If you still must use source-IP based ACLs, the rest of this post applies.
AWS publishes IP ranges [here](https://ip-ranges.amazonaws.com/ip-ranges.json).
PWS currently is currently hosted on us-east-1. We do not guarantee that this will remain true indefinitely, but it is true for now. We also do not promise to provide notification if we expand PWS to multiple regions, but we probably will.

The effective list of possible IPs is as follows:

```bash
curl https://ip-ranges.amazonaws.com/ip-ranges.json |   ruby -rjson -e 'puts JSON.pretty_generate( JSON.parse(STDIN.read)["prefixes"].select {|v| v["region"] == "us-east-1" && v["service"] == "EC2"}.map{|v| v["ip_prefix"]} )'
```

One can subscribe to IP address range notifications following the documentation found [here](https://docs.aws.amazon.com/general/latest/gr/aws-ip-ranges.html#subscribe-notifications).
