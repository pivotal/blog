---
authors:
- cunnie
- cdutra
- zak
- beebz
categories:
- BOSH
- BOSH CPI
- vSphere
- NSX-T
date: 2017-04-17T11:43:14-07:00
draft: false
short: |
  BOSH now allows attaching vSphere deployed VMs to NSX-T's Opaque Networks
title: Deploy To vSphere NSX-T Opaque Networks Using BOSH
---

[VMware's vSphere](http://www.vmware.com/products/vsphere.html) is an
Infrastructure as a Service (IaaS) which runs Virtual Machines (VMs).
[BOSH](http://bosh.io/docs/about.html) is a VM orchestrator which automates the
creation of VMs.  [NSX-T](https://www.vmware.com/support/pubs/nsxt_pubs.html)
is a pluggable Network backend for vSphere (and other hypervisors). NSX-T
allows the creation of opaque networks in vSphere, networks whose detail and
configuration of the network is unknown to vSphere and which is managed outside
vSphere.

With the release of [BOSH vSphere CPI
v40](http://bosh.io/releases/github.com/cloudfoundry-incubator/bosh-vsphere-cpi-release?all=1),
users can attach their BOSH-deployed VMs to an NSX-T opaque network.

<div class="alert alert-success" role="alert">

Opaque networks are treated as ordinary BOSH networks; in other words,
<i>writers of BOSH manifests need not concern themselves with the underlying
type of network</i> whether it be opaque, distributed switch port group or
standard switch port group. The manifest need only contain the name of the
network; it can be blissfully ignorant of the underlying implementation.

</div>

<br />

This blog post describes how to attach a deployed VM to an opaque network. We
first deploy a BOSH director attached to an opaque network via the BOSH CLI,
then we use the BOSH director to deploy two VMs to the opaque network.

## 0. Quick Start

Like other vSphere networks, the name of the opaque network *as it appears in
vSphere* should match the name of the network as it appears under the
`cloud_properties` section of the manifest.

In the following screenshot from the vSphere web interface, we can see the
opaque network, *opaque*. The unique icon (a network interface sprouting from a
cloud) identifies it as an opaque network.

{{< responsive-figure
src="https://cloud.githubusercontent.com/assets/1020675/25021562/7aa472be-2047-11e7-989a-d12e624c19f2.png"
>}}

In our corresponding BOSH Cloud Config we specify that VMs placed in the BOSH
*western_us* [network](https://bosh.io/docs/vsphere-cpi.html#networks)  should
be attached to the vSphere *opaque* network. Note that under `cloud_properties`
we make sure to use the opaque network name as it appears in vSphere, *opaque*:

```yaml
networks:
- name: western_us
  type: manual
  subnets:
  - range: 192.168.0.0/24
    cloud_properties:
      name: opaque # must match name of network in vSphere
```

At this point, the seasoned BOSH manifest writer will have enough information
to deploy to NSX-T networks, and may find the remainder of this post
uninteresting.  The remainder of the blog post is directed towards those
interested in detailed examples.

## 1. Double Deployment: BOSH Director First, VMs Second

We will deploy twice to demonstrate BOSH's opaque network feature: first to
demonstrate its effectiveness with the BOSH CLI, second to demonstrate its
effectiveness with the BOSH director:

* Our first deployment is the BOSH Director itself, using the new [BOSH Command
Line Interface](https://bosh.io/docs/cli-v2.html) (CLI) (`bosh2`). Due to an
artifact of our environment <sup><a href="#multi_homed"
class="alert-link">[artifact]</a></sup> , The BOSH director cannot attach
solely to the opaque network; to work around this restriction, we will attach
it to _two_ networks: a distributed virtual port group, _scarlet_, and the
NSX-T opaque network, _opaque_.
* Our second deployment is two VMs which reside exclusively on the _opaque_
network. A successful BOSH deploy indicates that the _opaque_ network is
functioning properly &mdash; a BOSH deploy won't succeed unless the director is
able to communicate with the VMs over the network.

{{< responsive-figure src="https://docs.google.com/drawings/d/1cEoJOv9O9gl0mns5_whe7epUcY9QpTHok_PsqF3m2Wk/pub?w=1320&amp;h=979" >}}

### 1.0 Deploy BOSH Director

We use the this
[manifest](https://github.com/cunnie/deployments/blob/f591e80c7846754c6045e3ce3c8d097503c1a1ce/bosh-vsphere.yml)
to deploy our BOSH director.

We type the following commands (note the `vcenter_ip` and `vcenter_password`
have been obscured) to deploy our BOSH director, log into it, and upload a
stemcell:

```bash
bosh2 create-env bosh-vsphere.yml -v vcenter_ip=vcenter.XXXX -v vcenter_password=XXXX -l vsphere-creds.yml
bosh2 -e 10.85.46.6 --ca-cert <(bosh2 int vsphere-creds.yml --path /director_ssl/ca) alias-env nsx-t
```

We check our vSphere Web Client to make sure our BOSH director is attached
to both networks:

{{< responsive-figure src="https://cloud.githubusercontent.com/assets/1020675/25098614/18fcad50-235e-11e7-9146-c092a7a48ef0.png" >}}

We authenticate against our BOSH director and upload a stemcell:

```bash
export BOSH_CLIENT=admin
export BOSH_CLIENT_SECRET=`bosh2 int ./vsphere-creds.yml --path /admin_password`
bosh2 -e nsx-t upload-stemcell https://s3.amazonaws.com/bosh-core-stemcells/vsphere/bosh-stemcell-3363.15-vsphere-esxi-centos-7-go_agent.tgz
```

Our director is up and running; we are now ready to use our director to deploy
two VMs.

### 1.1. Use BOSH Director to Deploy Two VMs

We upload our [Cloud Config](https://github.com/cunnie/deployments/blob/f591e80c7846754c6045e3ce3c8d097503c1a1ce/cloud-config-vsphere.yml):

```bash
bosh2 -e nsx-t -n update-cloud-config cloud-config-vsphere.yml
```

Now we create a minimal deployment consisting of two VMs ([BOSH manifest](https://github.com/cunnie/deployments/blob/f591e80c7846754c6045e3ce3c8d097503c1a1ce/minimal.yml)).

```bash
bosh2 -e nsx-t -n deploy -d minimal minimal.yml
```

We make sure the deploy succeeds &mdash; a successful deploy indicates the BOSH
director and its two VMs are able to communicate over the opaque network:

```bash
...
Task 56 done

Succeeded
```

## Addendum: Technical Requirements

* [BOSH vSphere CPI](http://bosh.io/releases/github.com/cloudfoundry-incubator/bosh-vsphere-cpi-release?all=1) v40+ (v40 tested)
* [vSphere 5.5](https://pubs.vmware.com/vsphere-55/index.jsp#com.vmware.wssdk.apiref.doc/new-mo-types-landing.html) (VMware vCenter Server Appliance 6.0.0.20000 tested)
* NSX-T 1.0+ (1.0.1.0.0.4191070 tested)

## Notes

We use [bosh-deployment](https://github.com/cloudfoundry/bosh-deployment) to
generate our BOSH director's manifest. We use this [custom
script](https://github.com/cunnie/deployments/blob/f591e80c7846754c6045e3ce3c8d097503c1a1ce/bin/vsphere.sh)
which uses this [custom
configuration](https://github.com/cunnie/deployments/blob/f591e80c7846754c6045e3ce3c8d097503c1a1ce/etc/vsphere.yml).
Much of the complexity derives from the need to create a dual-homed director.

All hosts in a cluster should have at least one physical interface allocated to
NSX-T. If not, VMs deployed to hosts with no physical cards allocated to NSX-T
will not be able to communicate.

If the operators of a vSphere environment have made the unfortunate decision to
identically name multiple networks (e.g. `VM Network`), the distributed virtual
port group will be selected first, followed by the opaque network, followed by
the standard switch port group.

Technical details: The BOSH vSphere CPI introduces a [new code
path](https://github.com/cloudfoundry-incubator/bosh-vsphere-cpi-release/blob/7185b00637a352adb7add09b136c78ec7ef171f3/src/vsphere_cpi/lib/cloud/vsphere/resources/nic.rb#L23-L28)
which examines the type of network to which the VM is being attached, and, if
it's an opaque network, uses the vSphere API to apply an opaque-specific
backing to the VM's network interface card.

## Footnotes

<a name="multi_homed"><sup>[artifact]</sup></a>

The astute reader may ask, "Multi-homed? Is there something about NSX-T's
opaque networks that require a multi-homed BOSH director?"

[A computer which is attached to more than one network is referred to as a
"multi-homed" computer. Routers and gateways are the canonical multi-homed
computers.]

The short answer is no, opaque networks do not require a multi-homed BOSH
director.  The reason we're deploying a multi-homed director is a side-effect
of the manner in which the opaque network was created for our environment: it
was created without routable IP addressess and without a router. Had it been
created with routable IP addresses and had a default gateway attached, a
multi-homed director would not have been necessary.
