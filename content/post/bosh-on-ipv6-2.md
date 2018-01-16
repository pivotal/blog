---
authors:
- cunnie
- dkalinin
categories:
- BOSH
- IPv6
date: 2018-01-15T21:16:22Z
draft: true
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
and IPv6 addresses and which is running an nginx web server.

We expect this blog post to be of interest to those who plan to deploy BOSH in
IPv6-enabled environments on vSphere.

## 1. Prerequisites

Use _at least_ the following versions:

- Stemcell [3468.13](https://bosh.io/stemcells/bosh-vsphere-esxi-ubuntu-trusty-go_agent) Ubuntu/Trusty
<sup><a href="#ubuntu" class="alert-link">[Ubuntu]</a></sup>
- BOSH Director [264.5.0](https://bosh.io/releases/github.com/cloudfoundry/bosh?all=1)
- BOSH CLI [2.0.45](https://bosh.io/docs/cli-v2.html#install)
- `bosh-deployment` commit [218e6d50](https://github.com/cloudfoundry/bosh-deployment/tree/218e6d5030d89ca9f31c50b8b308e2a78d2a0997)

## 2. Deployment Overview

In this example, we deploy a
[multihomed](https://en.wikipedia.org/wiki/Multihoming) VM
<sup><a href="#dual_stack" class="alert-link">[why not dual-stack?]</a></sup>
running an nginx web server.

{{< responsive-figure src="https://docs.google.com/drawings/d/e/2PACX-1vQ13VLsT0OY9ngx7U2ul1Auxv19mVUx3q1NId9xXw9hb2QnwqbGdzxjj2Q5W8XWSTOb6H2Z3xiGDS9i/pub?w=1037&amp;h=936" >}}

## 3. Deploying the BOSH Director

We use [bosh-deployment](https://github.com/cloudfoundry/bosh-deployment) to
deploy our BOSH director. Our script can be viewed
[GitHub](https://github.com/cunnie/deployments/blob/f4fffca86ecf4fd662713ab4c8a30c9d63ec26d5/bin/vsphere-ipv4.sh).

Our script has several customizations (e.g.
[here](https://github.com/cunnie/deployments/blob/f4fffca86ecf4fd662713ab4c8a30c9d63ec26d5/bin/vsphere-ipv4.sh#L30-L32)).
These customizations are unrelated to IPv6, and rest assured that using a
vanilla deploy script will result in a BOSH Director that is able to deploy VMs
with IPv6 addresses.

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

We upload our [Cloud Config](https://bosh.io/docs/cloud-config.html) to our BOSH
Director. Our Cloud Config contains the networks settings for our IPv4 and IPv6
subnets.

```bash
bosh -e ipv4 ucc cloud-config-vsphere-ipv4.yml
```

Our Cloud Config can be viewed on
[GitHub](https://github.com/cunnie/deployments/blob/73349cf7ff19afdd8e4bfc0345368171d837545a/cloud-config-vsphere-ipv4.yml).
The networking section is shown below. Note that we do not [abbreviate](https://en.wikipedia.org/wiki/IPv6_address#Representation)
<sup><a href="#dont_abbreviate" class="alert-link">[why no abbreviations?]</a></sup>
our IPv6 addresses:

```yaml
networks:
- name: IPv4
  type: manual
  subnets:
  - range: 10.0.9.0/24
    gateway: 10.0.9.1
    static: [ 10.0.9.161-10.0.9.165 ]
    cloud_properties:
      name: VM Network
- name: IPv6
  type: manual
  subnets:
  - range: "2601:0646:0100:69f1:0000:0000:0000:0000/64"
    gateway: "2601:0646:0100:69f1:020d:b9ff:fe48:9249"
    dns:
    - 2001:4860:4860:0000:0000:0000:0000:8888
    - 2001:4860:4860:0000:0000:0000:0000:8844
    static: [  "2601:0646:0100:69f1:0000:0000:0000:0161-2601:0646:0100:69f1:0000:0000:0000:0170" ]
    cloud_properties:
      name: IPv6
```

<div class="alert alert-warning" role="alert">

<b>Don't  abbreviate IPv6 addresses in BOSH manifests or Cloud Configs</b>.
Don't use double colons (<code>::</code>), don't strip leading zeroes. As an
extreme example, the loopback address (<code>::1</code>) should be represented
as <code>0000:0000:0000:0000:0000:0000:0000:0001</code>.

</div>

## 4. Upload the Stemcell and the nginx Release

```bash
bosh -e ipv4 us https://s3.amazonaws.com/bosh-core-stemcells/vsphere/bosh-stemcell-3468.17-vsphere-esxi-ubuntu-trusty-go_agent.tgz
bosh -e ipv4 ur https://github.com/cloudfoundry-community/nginx-release/releases/download/v1.12.2/nginx-1.12.2.tgz
```

## 5. Deploy the Web server

We create a manifest for our deployment; it can be viewed on
[Github](https://github.com/cunnie/deployments/blob/73349cf7ff19afdd8e4bfc0345368171d837545a/nginx-ipv46.yml).

We assign our IP addresses within our manifest as follows:

```yaml
instance_groups:
  networks:
  - name: IPv4
    static_ips:
    - 10.0.9.165
  - name: IPv6
    static_ips:
    - 2601:0646:0100:69f1:0000:0000:0000:0165
    - default:
      - dns
      - gateway
```

Note that we assign our default gateway to the _IPv6_ interface. This has the
implication that our IPv4 interface can only communicate on its local subnet
(i.e. 10.0.9.0/24), which means that it must be deployed on the same subnet as
the BOSH Director (otherwise the VM would be unable to communicate with the
Director, hence would be unable to receive its configuration).

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
  nginx/821894df-9441-4325-92aa-2f4ded0e2bd9  running        -   10.0.9.165
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

Don't abbreviate IPv6 addresses in BOSH manifests or Cloud Configs.

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

Applications (e.g. nginx) must be designed to bind to the IPv6 address as well
as the IPv4. Specifically, the underlying system call (kernel interface) to
create a socket [socket(2)](http://man7.org/linux/man-pages/man2/socket.2.html),
requires the specification of the address family, which can either be IPv4
(`AF_INET`) or IPv6 (`AF_INET6`). Certain applications bind to both IPv4 and
IPv6 addresses seamlessly (e.g. `sshd`); however, that's not the case for the
majority of applications. Even nginx, a popular webserver, requires a fairly
cryptic directive to bind to both IPv4 & IPv6: `listen [::]:80 ipv6only=off;`
(the directive to listen to IPv4 is a simple `listen 80;`).

BOSH releases must be designed to either seamlessly bind to IPv6 interfaces or
to expose a manifest property to allow binding to an IPv6 address (e.g. the
nginx BOSH release).

IPv6's [Neighbor Discovery
Protocol](https://en.wikipedia.org/wiki/Neighbor_Discovery_Protocol) (NPD)
distorts the BOSH networking model. For example, on a multi-homed VM with both
IPv4 interface and IPv6 interfaces, with IPv4 interface being set as the
[default gateway](https://bosh.io/docs/networks.html#multi-homed) via BOSH, and
a gateway assigned to the IPv6 via Router Advertisement, may result in non-local
traffic going out _both_ the IPv4 _and_ IPv6 interfaces instead of solely the
IPv4 interface. This may be viewed as a feature.

Once IPv6 is enabled on a VM, it is enabled on _all_ interfaces. In other words,
the IPv4 interface may pick up an IPv6 address as well, one that was not
assigned by BOSH but rather acquired via Neighbor Discovery Protocol (NPD). For
example, the web server we deployed acquired an additional IPv6 addresses on its
"IPv4" interface: `2601:646:100:69f0:250:56ff:fe8c:86a9`

Having an IPv6 address on both interfaces of the deployed VM can sometimes cause
odd networking behavior. For example, when using `bosh ssh` to connect to the
IPv6 interface (i.e. the VM's "far" interface) of the web server VM from a
workstation on the same subnet (same VLAN) as the VM's IPv4 interface, _and_ if
the VM has acquired an IPv6 address on its IPv4 interface (i.e. the VM's "near"
interface), then the `bosh ssh` sessions will disconnect (TCP RESET) within 60
seconds. A workaround would be to ssh to the IPv4 interface or the "near"
IPv6 interface.

BOSH doesn't have a concept of "dual-stack". In other words, when it deploys a
VM, BOSH assigns the VM's network interface either an IPv4 or an IPv6 address,
but not both (though, as mentioned above, an IPv4 interface may acquire an IPv6
address via NPD).

BOSH requires the IPv6 default route to reside in the same subnet as the gateway
(which is not an IPv6 requirement (often the default route is an `fe80::...`
address), though it is an IPv4 requirement).

BOSH won't allocate certain addresses, e.g. "[subnet
zero](https://en.wikipedia.org/wiki/Subnetwork#Subnet_zero_and_the_all-ones_subnet)".

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

There was also much help from groups within Pivotal, e.g. BOSH Core for merging
the pull requests and fleshing-out the testing structure, Toolsmiths for
creating the necessary environments, and IOPS for enabling IPv6 as needed.

## Footnotes

<a name="ubuntu"><sup>[Ubuntu]</sup></a> IPv6 only works on Ubuntu stemcells; we
haven't yet made changes to the `bosh-agent` to accommodate IPv6 on the
CentOS-flavored stemcells. Pull requests are welcome.

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
network interface. To accommodate dual stack we would have had to make
fundamental changes to BOSH's networking paradigm and BOSH's codebase — changes
that would have required time we did not have. The multihomed single-stack
approach was an expedient and technically valid choice.

<a name="dont_abbreviate"><sup>[why no abbreviations?]</sup></a> The BOSH
Director codebase represents IPv6 addresses (in most cases, such as the internal
database) as strings, and many manipulations will fail if abbreviated IPv6
addresses were used (e.g. "does this IPv6 address fall in this range?").

Although we'd like to have the capability to use abbreviated IPv6 addresses, and
that may be a direction we take longer term, in the short term we must use
fully-expanded IPv6 addresses. They are but a minor inconvenience to manifest
writers.
