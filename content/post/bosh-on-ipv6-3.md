---
authors:
- cunnie
- dkalinin
categories:
- BOSH
- IPv6
date: 2017-12-17T17:16:22Z
draft: true
short: |
  Recent changes to the BOSH software suite enable the assignment of IPv6
  addresses to both the BOSH Director and to the VMs deployed by the BOSH
  director. In this blog post we describe how we deployed a BOSH Director and
  subsequently used the Director to deploy a web server, both VMs with only IPv6
  addresses, no IPv4.
title: BOSH deployed to an IPv6 environment on vSphere
---

## 0. Abstract

BOSH is a VM orchestrator; a BOSH Director creates, configures, monitors, and
deletes VMs. The BOSH Director interoperates with a number of IaaSes
(Infrastructure as a Service), one of which is VMware vSphere, a virtualization
platform. BOSH traditionally operates exclusively within the IPv4 networking
space (i.e. the BOSH Director has an IPv4 address (e.g. 10.0.0.6), and the VMs
which it deploys also have IPv4 addresses); however, recent changes have
enabled IPv6 within the BOSH Framework.

In this blog post we show how we deployed a BOSH Director with an IPv6
address (no IPv4), and, in turn, used the BOSH Director to deploy several VMs
with IPv6 addresses.

We expect this blog post to be of interest to those who plan to deploy BOSH in
IPv6-enabled environments.

## 1. Prerequisites

Use _at least_ the following versions:

- Stemcell [3468.13](https://bosh.io/stemcells/bosh-vsphere-esxi-ubuntu-trusty-go_agent) Ubuntu/Trusty
<sup><a href="#ubuntu" class="alert-link">[Ubuntu]</a></sup>
- BOSH Director [264.5.0](https://bosh.io/releases/github.com/cloudfoundry/bosh?all=1)
- BOSH CLI [2.0.45](https://bosh.io/docs/cli-v2.html#install)
- `bosh-deployment` commit [218e6d50](https://github.com/cloudfoundry/bosh-deployment/tree/218e6d5030d89ca9f31c50b8b308e2a78d2a0997)

The following must have IPv6 addresses
<sup><a href="#hybrid" class="alert-link">[Hybrid]</a></sup>

- the workstation from which the BOSH Director is redeployed
- the VMware vCenter
- the VMware ESXi host

## 2. Deployment Overview

<a name="ubuntu"><sup>[Ubuntu]</sup></a> We haven't yet made changes to the
`bosh-agent` to accommodate IPv6 on the CentOS-flavored stemcells; pull requests
are welcome.

{{< responsive-figure src="https://docs.google.com/drawings/d/e/2PACX-1vTeIfjAzxLxLNFW32pRwxg7Uf7xV9391f5DT3kujrB83p4KHwTDVmg98JhOavw7MdX2nCz4NRnRngb9/pub?w=1427&amp;h=1550" >}}

## History

Enabling IPv6 on BOSH was a side project we started a year ago, grossly
underestimating the amount of time required — we thought it would take a couple
of weeks at most; it took over a year. The changes spanned several BOSH
components: the BOSH Director (e.g commit
[4a35c4b8](https://github.com/cloudfoundry/bosh/commit/4a35c4b8daac86522f07884274dc6fa2c870fecb)),
the BOSH agent (e.g. commit
[0962dce7](https://github.com/cloudfoundry/bosh-agent/commit/0962dce7801616f89ba2cd559e97b532379ba594)),
the BOSH CLI (e.g. commit
[0316b3a5](https://github.com/cloudfoundry/bosh-cli/commit/0316b3a5b58241ca78a75057fb64e6dfc6741f7b)),
and BOSH deployment (e.g. commit
[214ebac4](https://github.com/cloudfoundry/bosh-deployment/commit/214ebac44cdd30a892feafc8c4a62662ab36665b)).

Although both our names appeared on the commits, Dmitriy did much of the heavy
lifting. The code is his. Brian contributed the IPv6-enabled vSphere
infrastructure and network & kernel configuration requirements.

## Gotchas

Don't [abbreviate](https://en.wikipedia.org/wiki/IPv6_address#Representation)
IPv6 addresses in BOSH manifests or Cloud Configs. Don't use double `::`, don't
strip leading zeroes. As an extreme example, the loopback address (`::1`) should be
represented as `0000:0000:0000:0000:0000:0000:0000:0001`.

Don't use large [`reserved`](https://bosh.io/docs/networks.html#manual) IP
ranges (> 1k IP addresses); they will cause `bosh deploy` to hang.  We have
cheerfully named the following Cloud Config "the fifth horseman of the BOSH
apocalypse", for no deployment to that network will ever complete.

```yaml
networks:
- name: IPv6
  type: manual

  subnets:
  - range:    2601:0646:0100:69f1:0000:0000:0000:0000/64
    gateway:  2601:0646:0100:69f1:020d:b9ff:fe48:9249
    dns:
    -         2001:4860:4860:0000:0000:0000:0000:8888
    -         2001:4860:4860:0000:0000:0000:0000:8844
    # This large range will cause `bosh deploy` to hang; don't do it
    reserved: [ 2601:0646:0100:69f1:0000:0000:0000:0000-2601:0646:0100:69f1:ffff:ffff:ffff:ffff ]
```

Don't upload stemcells using the [bosh.io](https://bosh.io/) URLs (`bosh
upload-stemcell
https://s3.amazonaws.com/bosh-core-stemcells/vsphere/bosh-stemcell-...`); they
won't work (`Network is unreachable`); Amazon S3 doesn't have IPv6 addresses for
s3.amazonaws.com. Instead, download the stemcell locally to your workstation,
then upload the stemcell from your workstation to your Director (e.g. `bosh
upload-stemcell stemcell.tgz`).

BOSH requires the IPv6 default route to reside in the same subnet as the gateway
(which is not an IPv6 requirement (often the default route is an `fe80::...`
address), though it is an IPv4 requirement).

IPv6's [Neighbor Discovery
Protocol](https://en.wikipedia.org/wiki/Neighbor_Discovery_Protocol) may subvert
the BOSH networking model. For example, on a multi-homed VM with both IPv4
interface and IPv6 interfaces, with IPv4 interface being set as the [default
gateway](https://bosh.io/docs/networks.html#multi-homed) via BOSH, and a gateway
assigned to the IPv6 via Router Advertisement, may result in non-local traffic
going out _both_ the IPv4 _and_ IPv6 interfaces instead of solely the IPv4
interface. Some may view this as a feature.

Certain versions of the vCenter Appliance require [modifying
`/etc/sysctl.conf`](https://communities.vmware.com/thread/552934) to enable IPv6.

BOSH doesn't have a concept of "dual-stack". In other words, when it deploys a
VM, the VM's network interface can have one IP address, either IPv4 or IPv6 but
not both.

BOSH won't allocate certain addresses, e.g. "[subnet zero](https://en.wikipedia.org/wiki/Subnetwork#Subnet_zero_and_the_all-ones_subnet)".

## Footnotes

<a name="ubuntu"><sup>[Ubuntu]</sup></a> IPv6 only works on Ubuntu stemcells; we
haven't yet made changes to the `bosh-agent` to accommodate IPv6 on the
CentOS-flavored stemcells. Pull requests are welcome.

<a name="hybrid"><sup>[Hybrid]</sup></a> The BOSH director and its VMs can be
deployed in a hybrid manner, with both IPv4 _and_ IPv6 addresses. Such
deployments do not always require the workstation, vCenter, and ESXi host to
have IPv6 addresses. Discussions of such deployments are outside the scope of
this blog post.
