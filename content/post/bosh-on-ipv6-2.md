---
authors:
- cunnie
- dkalinin
categories:
- BOSH
- IPv6
date: 2018-01-16T19:12:22Z
draft: false
short: |
  Recent changes to the BOSH software suite enable the assignment of IPv6
  addresses to VMs deployed by the BOSH Director in a vSphere environment.
  In this blog post we describe how we deployed a BOSH Director and
  subsequently used the Director to deploy a web server with a private
  IPv4 address and a public IPv6 address.
title: Deploying BOSH VMs with IPv6 Addresses on vSphere
---

## 0. Abstract

BOSH is a VM orchestrator; a BOSH Director creates, configures, monitors, and
deletes VMs. The BOSH Director interoperates with a number of IaaSes
(Infrastructure as a Service), one of which is VMware vSphere, a virtualization
platform. BOSH traditionally operates exclusively within the IPv4 networking
space (i.e. the BOSH Director has an IPv4 address (e.g. 10.0.0.6), and the VMs
which it deploys also have IPv4 addresses); however, recent changes have
enabled IPv6 networking within the BOSH Framework.

In this blog post we show how we deployed a BOSH Director with an IPv4 address
(no IPv6), and, in turn, used the BOSH Director to deploy a VM with both IPv4
and IPv6 addresses and which is running an nginx web server. Future blog posts
will describe installing a BOSH Director in a pure IPv6 network.

We expect this blog post to be of interest to those who plan to deploy BOSH in
IPv6-enabled environments on vSphere.

<div class="alert alert-warning" role="alert">

<b>BOSH with IPv6 is in beta!</b>  We urge caution when deploying BOSH with IPv6 –
limiting your deployments to test environments is a good idea. We welcome
feedback.

</div>

## 1. Prerequisites

Use _at least_ the following versions:

- Stemcell [3468.13](https://bosh.io/stemcells/bosh-vsphere-esxi-ubuntu-trusty-go_agent) Ubuntu/Trusty
<sup><a href="#ubuntu" class="alert-link">[Ubuntu]</a></sup>
- BOSH Director [264.5.0](https://bosh.io/releases/github.com/cloudfoundry/bosh?all=1)
- BOSH CLI [2.0.45](https://bosh.io/docs/cli-v2.html#install)
- `bosh-deployment` commit [be379d8](https://github.com/cloudfoundry/bosh-deployment/commit/be379d8bd9701c5f08d469a8cd8e1d531eecf259)

## 2. Deployment Overview

In this example, we deploy a
[multihomed](https://en.wikipedia.org/wiki/Multihoming) VM
<sup><a href="#dual_stack" class="alert-link">[why not dual-stack?]</a></sup>
running an nginx web server.

{{< responsive-figure src="https://docs.google.com/drawings/d/e/2PACX-1vQ13VLsT0OY9ngx7U2ul1Auxv19mVUx3q1NId9xXw9hb2QnwqbGdzxjj2Q5W8XWSTOb6H2Z3xiGDS9i/pub?w=1037&amp;h=936" >}}

## 3. Deploying the BOSH Director

We use [bosh-deployment](https://github.com/cloudfoundry/bosh-deployment) to
deploy our BOSH director. You can use your existing Director. If you need to
deploy one, follow the instructions on
[bosh.io](https://bosh.io/docs/init-vsphere).

We set our BOSH Director's alias to "ipv4" and log in:

```bash
 # set the alias for our BOSH Director to "ipv4"
bosh -e 10.0.9.151 alias-env ipv4
 # use something along these lines to find the admin password:
 # `bosh int --path /admin_password creds.yml`

 # log in
bosh -e ipv4 log-in
  Email (): admin
  Password ():
```

## 4. Upload the Cloud Config

Assuming that you already have a Cloud Config with an IPv4 network, let's add an
additional Cloud Config that defines the IPv6 network.

```bash
bosh -e ipv4 update-config cloud cloud-config-vsphere-ipv6.yml --name ipv6
```

The IPv6 Cloud Config is shown below, and can also be seen on
[GitHub](https://github.com/cunnie/deployments/blob/528e354d017e16a120bb505b14a3ba444e136c1a/cloud-config-vsphere-ipv6.yml).

```yaml
networks:
- name: ipv6
  type: manual
  subnets:
  - range: "2601:0646:0100:69f1:0000:0000:0000:0000/64"
    gateway: "2601:0646:0100:69f1:020d:b9ff:fe48:9249"
    dns:
    - 2001:4860:4860:0000:0000:0000:0000:8888
    - 2001:4860:4860:0000:0000:0000:0000:8844
    azs: [z1]
    cloud_properties:
      name: IPv6
```

<div class="alert alert-warning" role="alert">

<b>Don't <a
href="https://en.wikipedia.org/wiki/IPv6_address#Representation">abbreviate</a>
IPv6 addresses in BOSH manifests or Cloud Configs</b> <sup><a
href="#dont_abbreviate" class="alert-link">[why no abbreviations?]</a></sup> .
Don't use double colons (<code>::</code>), don't strip leading zeroes. As an
extreme example, the loopback address (<code>::1</code>) should be represented
as <code>0000:0000:0000:0000:0000:0000:0000:0001</code>.

</div>

## 4. Upload the Stemcell and the nginx Release

```bash
bosh -e ipv4 us https://bosh.io/d/stemcells/bosh-vsphere-esxi-ubuntu-trusty-go_agent?v=3468.17 \
  --sha1 1691f18b9141ac59aec893a1e8437a7d68a88038

bosh -e ipv4 ur https://bosh.io/d/github.com/cloudfoundry-community/nginx-release?v=1.12.2 \
  --sha1 70a21f53d1f89d25847280d5c4fad25293cb0af9
```

## 5. Deploy the Web server

We create a manifest for our deployment; it can be viewed on
[Github](https://github.com/cunnie/deployments/blob/f5c5d939c574ca86a0c2c6ce2e26fc21d9d73a44/nginx-ipv46.yml).

We assign our instance group to have two networks within our manifest as
follows:

```yaml
instance_groups:
- name: nginx
  networks:
  - name: default
  - name: ipv6
    default: [dns, gateway]
```

Note that we assign our default gateway to the _IPv6_ interface. This has the
implication that our IPv4 interface can only communicate on its local subnet
(i.e. 10.0.9.0/24), which means that it must be deployed on the same subnet as
the BOSH Director (otherwise the VM would be unable to communicate with the
Director, hence would be unable to receive its configuration).
<sup><a href="#routing" class="alert-link">[Routing]</a></sup>

Deployment is straightforward:

```bash
bosh -e ipv4 -d nginx deploy nginx-ipv46.yml
```

## 6. Check It's Working

We check to make sure our nginx VM is running and that it has configured its IP
addresses properly:

```bash
bosh -e ipv4 -d nginx instances
  Using environment 'bosh-vsphere-ipv4.nono.io' as user 'admin' (openid, bosh.admin)
  ...
  Instance                                    Process State  AZ  IPs
  nginx/821894df-9441-4325-92aa-2f4ded0e2bd9  running        z1  10.0.9.165
                                                                 2601:0646:0100:69f1:0000:0000:0000:0165
```

Next we browse to our newly-deployed web server (note this must be done from a
workstation with an IPv6 address), <http://[2601:646:100:69f1::165]/> or
<http://nginx-ipv6.nono.io/>

{{< responsive-figure src="https://user-images.githubusercontent.com/1020675/34973631-a56045e8-fa3d-11e7-8553-fefe1807c43e.png" >}}

## 7. Conclusion

We have seen how, using a standard BOSH director with a standard stemcell, we
were able to deploy an IPv6-enabled VM running a service (nginx) that was
reachable from the internet.

## Gotchas

**Don't abbreviate IPv6 addresses** in BOSH manifests or Cloud Configs.

**Don't use large [`reserved`](https://bosh.io/docs/networks.html#manual) IP
ranges** (> 1k IP addresses); they will cause `bosh deploy` to hang.

**Make sure your application binds to the IPv6 address** of your VM if you plan on
using the IPv6 endpoint (e.g. <http://[2601:646\:100:69f1::165]/>). You may
need to make additional configuration changes, possibly code changes.

Tech notes: the underlying system call (kernel interface) to create a socket,
[socket(2)](http://man7.org/linux/man-pages/man2/socket.2.html), requires the
specification of the address family, which can either be IPv4 (`AF_INET`) or
IPv6 (`AF_INET6`), which means that applications need to "opt-in" to binding to
the IPv6 address (it's not automatic). Certain applications are coded to bind to
both IPv4 and IPv6 addresses seamlessly (e.g. `sshd`); however, that's not the
case for the majority of applications. Even nginx, a popular webserver, requires
a fairly cryptic directive to bind to both IPv4 & IPv6: `listen [::]:80
ipv6only=off;` (the directive to listen to IPv4 is a simple `listen 80;`).

Be aware of the **security implications of IPv6 Router Advertisements** BOSH
stemcells are _currently_ configured to accept IPv6 router advertisements
which expose the VM to man-in-the-middle attacks.
<sup><a href="#router_ads" class="alert-link">[Router Advertisements]</a></sup>

IPv6 is **enabled on _all_ the VM's interfaces**. Once BOSH
assigns an IPv6 address to an interface on a VM, the other interfaces may pick up
an IPv6 address as well, one that was not assigned by BOSH but rather acquired
via IPv6's Neighbor Discovery Protocol's (NP's) [stateless address
autoconfiguration](https://en.wikipedia.org/wiki/IPv6_address#Stateless_address_autoconfiguration)
(SLAAC). For example, the web server we deployed acquired an additional IPv6
addresses on its "IPv4" interface: `2601:646:100:69f0:250:56ff:fe8c:86a9`.

Currently **BOSH doesn't have a concept of "dual-stack"**. In other words, when
it deploys a VM, BOSH assigns the VM's network interface either an IPv4 or an
IPv6 address, but not both (though an IPv4 interface may acquire an IPv6 address
via SLAAC).

Currently BOSH requires the **IPv6 default route to reside in the same subnet**
as the gateway (often the IPv6 default route is an
`fe80::...` address).

BOSH won't allocate certain addresses, e.g. "[subnet
zero](https://en.wikipedia.org/wiki/Subnetwork#Subnet_zero_and_the_all-ones_subnet)".

## History

We began work in January 2017. Each week we picked one day to work in the late
evening for three hours. The changes spanned several BOSH components: the BOSH
Director (e.g commit
[4a35c4b8](https://github.com/cloudfoundry/bosh/commit/4a35c4b8daac86522f07884274dc6fa2c870fecb)),
the BOSH agent (e.g. commit
[0962dce7](https://github.com/cloudfoundry/bosh-agent/commit/0962dce7801616f89ba2cd559e97b532379ba594)),
the BOSH CLI (e.g. commit
[0316b3a5](https://github.com/cloudfoundry/bosh-cli/commit/0316b3a5b58241ca78a75057fb64e6dfc6741f7b)),
and BOSH deployment (e.g. commit
[214ebac4](https://github.com/cloudfoundry/bosh-deployment/commit/214ebac44cdd30a892feafc8c4a62662ab36665b)).

## Acknowledgements

We'd like to thank the many people who made IPv6-on-BOSH possible: the BOSH
Development Team (Danny Berger, Chris De Oliveira, Tom Viehman, Eve Quintana,
Difan Zhao, Joshua Aresty) for merging the pull requests and fleshing-out the
testing structure, Toolsmiths (Mark Stokan, Ken Lakin, and Der Wei Chan) for
creating the necessary environments, and IOPS (Sachin Prasad, Quintin Donnelly,
and Pablo Lopez) for enabling IPv6.

## Footnotes

<a name="ubuntu"><sup>[Ubuntu]</sup></a> IPv6 only works on Ubuntu Trusty stemcells; we
haven't yet made changes to the `bosh-agent` to accommodate IPv6 on the
CentOS-flavored or Ubuntu Xenial stemcells. Pull requests are welcome.

<a name="dual_stack"><sup>[why not dual stack?]</sup></a> Our deployed webserver
VM is multihomed — it has two network interfaces: one which has the IPv4 address
(10.0.9.165), and the other which has the IPv6 address
(2601:646\:100:69f1::165). But a more common approach is to use a single,
[dual
stack](https://www.juniper.net/documentation/en_US/junos/topics/concept/ipv6-dual-stack-understanding.html),
network interface:

> A dual-stack device is a device with network interfaces that can originate and
understand both IPv4 and IPv6 packets.

So why did we opt for the dual-homed single-stack approach instead of the
single-homed, dual stack approach? The answer is that BOSH's networking model
assumes one and only one IP address (be it IPv4 or IPv6) is assigned to a given
network interface. To accommodate dual stack we would have had to make changes
to BOSH vSphere CPI and BOSH Agent - changes that would have required time
we did not have. The multihomed single-stack approach was an expedient and
technically valid choice.

<a name="routing"><sup>[Routing]</sup></a> Most non-BOSH-deployed machines with
both IPv4 and IPv6 addresses have two default routes: one for IPv4, and one for
IPv6 (we discount the
[link-local](https://en.wikipedia.org/wiki/Link-local_address) addresses (i.e.
`fe80::/10`) which, by definition, don't have a route). The BOSH networking
model, as it currently stands, only allows one default route.

This restriction constrains the placement of the deployed VM: if the IPv6
interface has the default route, then the IPv4 doesn't, which means that the VM
must be deployed on the same subnet as the BOSH Director in order to communicate
with it (the BOSH Director only communicates via IPv4, although we are actively
working to change that).

On the other hand, if the IPv4 interface of the deployed VM has the default
route, then the IPv6 interface doesn't, which limits the usefulness of having a
VM with an IPv6 address (the impetus to use IPv6 is driven by [IPv4 address
exhaustion](https://en.wikipedia.org/wiki/IPv4_address_exhaustion),
specifically routable addresses, and an IPv6 interface with no IPv6 route is not
routable, and offers little value over an IPv4 address).

However, all is not lost: the IPv6 interface of the deployed VM may acquire an
IPv6 route via router advertisements.
<sup><a href="#router_ads" class="alert-link">[Router Advertisements]</a></sup>
That means it's possible to deploy a VM with _both_ IPv4 and IPv6 default
routes.

<a name="dont_abbreviate"><sup>[why no abbreviations?]</sup></a> The BOSH
Director codebase represents IPv6 addresses (in most cases, such as the internal
database) as strings, and many manipulations will fail if abbreviated IPv6
addresses were used (e.g. "does this IPv6 address fall in this range?").

Although we'd like to have the capability to use abbreviated IPv6 addresses, and
that may be a direction we take longer term, in the short term we must use
fully-expanded IPv6 addresses. They are but a minor inconvenience to manifest
writers.

<a name="router_ads"><sup>[Router Advertisements]</sup></a>
IPv6's [Neighbor Discovery
Protocol](https://en.wikipedia.org/wiki/Neighbor_Discovery_Protocol)'s (NP's)
Router Advertisements allow for the discovery of IPv6 routes within an IPv6
subnet. Unfortunately, they may also be used to enable man-in-the-middle attacks
(Infoblox has a [blog
post](https://community.infoblox.com/t5/IPv6-CoE-Blog/Why-You-Must-Use-ICMPv6-Router-Advertisements-RAs/ba-p/3416)
describing the security issues).

The BOSH agent will enable the acceptance of router advertisements if an IPv6 is
assigned to the VM (source code: the kernel
[settings](https://github.com/cloudfoundry/bosh-agent/blob/bbee23c0e055b66477a0bae7fc657f9b525a0a99/platform/net/kernel_ipv6.go#L58-L61)
and
[`/etc/network/interfaces`](https://github.com/cloudfoundry/bosh-agent/blob/ec9f5b2f5a09aae9f213bbd917af0ae010d50fbe/platform/net/ubuntu_net_manager.go#L372)),
which undoes the default settings of the
[stemcell](https://github.com/cloudfoundry/bosh-linux-stemcell-builder/blob/7eaa5facbfb53676d9c0de2a5866439ebe4f40c6/stemcell_builder/stages/bosh_sysctl/assets/60-bosh-sysctl.conf#L21-L25) (which disable router advertisements).

We plan to disable the acceptance of IPv6's NP's router advertisements and
to replace it with another mechanism to allow _both_ the IPv4 and IPv6 to have
default routes (one idea we have been considering is a new property,
`ipv6_gateway`).

Similarly, we plan to disable [ICMPv6 Redirects](https://en.wikipedia.org/wiki/Internet_Control_Message_Protocol#Redirect)
on IPv6-enabled VMs in the future.

Use caution when connecting to a VM that has acquired an IPv6 address on its
IPv4 interface via SLAAC: having an IPv6 address on both interfaces of the
deployed VM may cause odd networking behavior. For example, when using `bosh
ssh` to connect to the IPv6 interface (i.e. the VM's "far" interface) of the web
server VM from a workstation on the same subnet (same VLAN) as the VM's IPv4
interface, _and_ if the VM has acquired an IPv6 address on its IPv4 interface
(i.e. the VM's "near" interface), then the `bosh ssh` sessions will disconnect
(TCP RESET) within 60 seconds. A workaround would be to ssh to the IPv4
interface or the "near" IPv6 interface.

## Corrections & Updates

*2018-01-27*

Trimmed Gotchas section; moved excessive detail into Footnotes section

Created an Acknowledgements section
