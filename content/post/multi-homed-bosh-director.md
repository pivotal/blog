---
authors:
- dberger
- cunnie
- aminjam
- rupa
- salvi
categories:
- BOSH
date: 2016-05-13T13:37:44-07:00
short: |
  We explore deploying a multi-homed BOSH Director to a vSphere environment to segregate networks
  in a secure manner.
title: How to Deploy a Multi-homed BOSH Director to a vSphere Environment
---

vSphere users ask, "How do I configure my BOSH director so that it can
communicate with my vCenter but the director's deployed VMs can't?"

One technique is to use a multi-homed BOSH director combined with the BOSH [Networking
Release](https://github.com/cloudfoundry/networking-release) (a BOSH release
which enables customization of the VM's routing table, allowing more routes
than the default gateway).

## Network Diagram

The following is a network diagram of our deployment. We want to protect the
assets at the top (in blue): the vCenter server and its associated ESXi servers.
These machines are particularly sensitive as they control hundreds of VMs.

The BOSH Director needs access to the vCenter, but its deployed VMs must *not*
have access to the vCenter.

We provision BOSH as a multi-homed VM attached to both the vCenter management
network and the BOSH Routing Network. This allows the director to communicate
with the deployed VMs, but prevents the VMs from communicating with the
sensitive networks.

{{< responsive-figure src="https://docs.google.com/drawings/d/1OReIbjwBHGX19HHgSQThdZenTS03ITtp8gOxwetLNcI/pub?w=894&amp;h=907" class="full" >}}

## BOSH Deployment Manifest

We use a BOSH [v2 deployment manifest](http://bosh.io/docs/manifest-v2.html) and a [cloud config](http://bosh.io/docs/cloud-config.html)
to deploy our BOSH director. Here is our BOSH director's manifest:

```yaml
director_uuid: __DIRECTOR_UUID__
name: bosh

releases:
- name: bosh
  version: latest
- name: bosh-vsphere-cpi
  version: latest
- name: networking
  version: latest

stemcells:
- alias: default
  os: ubuntu-trusty
  version: latest

update:
  canaries: 1
  max_in_flight: 10
  canary_watch_time: 1000-30000
  update_watch_time: 1000-30000

jobs:
- name: bosh
  instances: 1
  stemcell: default
  templates:
  - {name: nats, release: bosh}
  - {name: postgres, release: bosh}
  - {name: blobstore, release: bosh}
  - {name: director, release: bosh}
  - {name: health_monitor, release: bosh}
  - {name: vsphere_cpi, release: bosh-vsphere-cpi}
  - name: routes
    release: networking
    properties:                 # This customizes the BOSH Director's
      networking.routes:        # routing table so it can reach
      - net: 172.16.1.0         # the two networks to which it deploys
        netmask: 255.255.255.0  # VMs:
        interface: eth1         # - CF Public Network  (172.16.1.0/24)
        gateway: 172.16.0.1     # - CF Private Network (172.16.2.0/24)
      - net: 172.16.2.0
        netmask: 255.255.255.0
        interface: eth1
        gateway: 172.16.0.1

  vm_type: medium
  persistent_disk: 40_960

  networks:
  - {name: bosh-management-network, static_ips: [10.0.1.6], default: [dns,gateway]}
  - {name: bosh-routing-network, static_ips: [172.16.0.6]}

  properties:
    nats:
      address: 127.0.0.1
      user: nats
      password: nats-password

    postgres: &db
      listen_address: 127.0.0.1
      host: 127.0.0.1
      user: postgres
      password: postgres-password
      database: bosh
      adapter: postgres

    blobstore:
      address: 172.16.0.6
      port: 25250
      provider: dav
      director: {user: director, password: director-password}
      agent: {user: agent, password: agent-password}

    director:
      address: 127.0.0.1
      name: my-bosh
      db: *db
      cpi_job: vsphere_cpi
      user_management:
        provider: local
        local:
          users:
          - {name: admin, password: admin}
          - {name: hm, password: hm-password}

    hm:
      director_account: {user: hm, password: hm-password}
      resurrector_enabled: true

    vcenter: &vcenter # <--- Replace values below
      address: 10.0.0.5
      user: root
      password: vmware
      datacenters:
      - name: datacenter
        vm_folder: vms
        template_folder: templates
        datastore_pattern: vnx5400-ds
        persistent_datastore_pattern: vnx5400-ds
        disk_path: disk
        clusters: [pizza-boxes]

    agent: {mbus: "nats://nats:nats-password@172.16.0.6:4222"}

    ntp: &ntp [0.pool.ntp.org, 1.pool.ntp.org]
```

Note that `properties.blobstore.address` and `properties.agent.mbus` use the
BOSH director's interface that is *closest to its deployed VMs* (i.e.
172.16.0.6); if you use the other interface (i.e. 10.0.1.6), the VMs will not
be able to contact the director and the deployment will fail.

Here is our cloud-config manifest:

```yaml
networks:
- name: bosh-management-network
  subnets:
  - range: 10.0.1.0/24
    gateway: 10.0.1.1
    static:
    - 10.0.1.6
    cloud_properties: { name: bosh-management-network }

- name: bosh-routing-network
  subnets:
  - range: 172.16.0.0/24
    gateway: 172.16.0.1
    static:
    - 172.16.0.6
    cloud_properties: { name: bosh-routing-network }

- name: cf-public-network
  subnets:
  - range: 172.16.1.0/24
    gateway: 172.16.1.1
    cloud_properties: { name: cf-public-network }

vm_types:
- name: tiny
  cloud_properties: { cpu: 1, ram: 1024, disk: 1024 }
- name: medium
  cloud_properties: { cpu: 2, ram: 2048, disk: 81_920 }

compilation:
  workers: 6
  network: bosh-management-network
  reuse_compilation_vms: true
  cloud_properties: { cpu: 2, ram: 2048, disk: 1024 }
```

Here is our deployment manifest (a very simple deployment):

```yaml
name: simple

director_uuid: __BOSH_DIRECTOR_UUID__

releases: []

stemcells:
- alias: default
  os: ubuntu-trusty
  version: latest

update:
  canaries: 1
  max_in_flight: 1
  canary_watch_time: 5000-300000
  update_watch_time: 5000-300000

instance_groups:
- name: simple-vm
  instances: 1
  jobs: []
  vm_type: tiny
  stemcell: default
  networks:
  - name: cf-public-network
```

## Notes

If one were to dispense with the BOSH Routing Network and deploy VMs on the
same subnet to which the BOSH director is attached, then one would not need to
include the [BOSH Networking
Release](https://github.com/cloudfoundry/networking-release) in the BOSH
manifest (the BOSH will not need to traverse a router to reach its deployed
VMs, for the VMs will be deployed to the same subnet on which the director has
an interface).

More complex BOSH deployments, e.g. [Cloud Foundry Elastic
Runtime](https://github.com/cloudfoundry/cf-release/), typically assume
multiple subnets, requiring the use of the networking-release.

We use BOSH v2 deployment manifest and cloud config to deploy our BOSH
director; however, BOSH directors are most often deployed with *bosh-init*,
which uses a slightly different manifest format. It should be a fairly trivial
exercise to convert our manifests to a *bosh-init*-flavored manifest.

## Gotchas

BOSH stemcells have been hardened, and this may cause unexpected connectivity
issues. Specifically, asymmetric routing may cause pings (or other attempts to
connect) to one of the Director's interfaces to fail (pings to the other
interface should succeed).

This problem is caused by [reverse packet
filtering](https://access.redhat.com/solutions/53031).  To fix, one can enable
the Director's kernel to accept asymmetrically routed packets (the following
commands must be run as root):

```bash
echo 2 > /proc/sys/net/ipv4/conf/default/rp_filter
echo 2 > /proc/sys/net/ipv4/conf/all/rp_filter
echo 2 > /proc/sys/net/ipv4/conf/eth0/rp_filter
echo 2 > /proc/sys/net/ipv4/conf/eth1/rp_filter
```

To make the changes permanent (to persist on reboot), the following should
be added to `/etc/sysctl.conf`:

```bash
net.ipv4.conf.all.rp_filter=2
net.ipv4.conf.default.rp_filter=2
net.ipv4.conf.eth0.rp_filter=2
net.ipv4.conf.eth1.rp_filter=2
```
