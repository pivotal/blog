---
authors:
- cunnie
- lfranklin
- cdutra
categories:
- BOSH
- NSX
- vSphere
date: 2016-11-01T09:15:02-07:00
draft: false
short: |
  BOSH, a VM (Virtual Machine) orchestrator, includes the ability to
  interoperate with NSX, a network virtualization platform, when deploying to a
  vSphere IaaS (Infrastructure as a Service). This blog post describes deploying
  VMs as the backend of an NSX Load Balancer.
title: Leveraging NSX's Features with BOSH's vSphere CPI
---

[VMWare NSX](http://www.vmware.com/products/nsx.html) is a network
virtualization platform (frequently paired with the vSphere IaaS (Infrastructure
as a Service)). It includes features such as Load Balancers (LBs) and firewall
rules, features often found in public-facing IaaSes (e.g. AWS (Amazon Web
Services), GCE (Google Compute Engine), and Microsoft Azure) but not native to
vSphere.

[BOSH](https://bosh.io/), a VM orchestrator, includes hooks to interoperate with
NSX's LB and Distributed Firewall features. These hooks enable BOSH to attach
created VMs to existing NSX Load Balancer Pools and NSX Distributed Firewall
rulesets. BOSH uses NSX's Security Groups <sup><a href="#nsx_security_groups"
class="alert-link">[NSX Security Groups]</a></sup> as the underlying mechanism.

<div class="alert alert-success" role="alert">

<b>NSX's Security Groups are <i>not</i> AWS's Security Groups.</b> NSX's
Security Groups are rich grouping objects (in BOSH's case, a collection of VMs)
which can be associated with Load Balancer pools and firewall rulesets (Google
Compute Engine's analog would be "Tags"). AWS's Security Groups, on the other
hand, are firewall rules (e.g. "block inbound TCP port 25").

</div>
<p />

This blog posts describes how to use BOSH to deploy a set of VMs as the backend
of an NSX LB and to apply NSX firewall rules to those VMs.  We expect this blog
post to be of interest to BOSH users who deploy to vSphere environments paired
with NSX with LB or security requirements (e.g. a public-facing vSphere
environment).

## 0.0 Plan

We will deploy three VMs as a backend to an LB with a properly configured
Application Profile, Virtual Server, and Pool. See the [NSX Setup
documentation](https://pubs.vmware.com/NSX-6/index.jsp#com.vmware.nsx.admin.doc/GUID-412635AE-1F2C-4CEC-979F-CC5B5D866F53.html)
for additional instructions.

We will also assign a firewall rule which disallows ssh to the three deployed
VMs.

A network diagram of our resulting deployment is shown below:

{{< responsive-figure src="https://docs.google.com/drawings/d/11GBu_UgjJ_q6qPUF4zkDIJ5cBgbDxjv8gLengLTwhBE/pub?w=960&h=720">}}

## <a name="prerequisites"></a> 1.0 NSX Prerequisites

### 1.1 Ensure the NSX Edge is enabled for Load Balancing

{{< responsive-figure src="https://cloud.githubusercontent.com/assets/1923644/19787469/c8cbaf3a-9c57-11e6-9da4-5b06016dfa3f.png" class="right large">}}

The NSX Edge must be enabled for load balancing.

The name of the NSX Edge ("load-balancer") is important — we will use this to
set our BOSH Director's [Cloud Config](http://bosh.io/docs/cloud-config.html)'s
`vm_extensions`'s `nsx.lbs`'s property, `edge_name`, in a subsequent step.

NSX menu navigation: Edge &rarr; Manage &rarr; Load
Balancer &rarr; Global Configuration &rarr; Load Balancer Status

### 1.2 Configure NSX Application Profile

{{< responsive-figure src="https://cloud.githubusercontent.com/assets/1923644/19787709/18ca64b2-9c59-11e6-9cb9-c2c3660eae9c.png" class="right large">}}

We configure an Application Profile. We use an HTTP-type Profile
with default settings.

NSX menu navigation: Edge &rarr; Manage &rarr; Load
Balancer &rarr; Application Profiles

### 1.3 Configure NSX Pool (leave Members empty)

{{< responsive-figure src="https://cloud.githubusercontent.com/assets/1923644/19788122/7da964c6-9c5b-11e6-8fd8-cd14d63a9876.png" class="right large">}}

We configure a backend pool for the load balancer. We use the defaults.
We do not add any members to the Pool — the BOSH Director will add the members
when it deploys the nginx VMs (specifically it will add the Security Group with
which it has tagged the VMs it has deployed).

The name of the Pool ("http-pool") is important — we will use this to set our
BOSH Director's Cloud Config's `vm_extensions`'s `nsx.lbs`'s property,
`pool_name`, in a subsequent step.

NSX menu navigation: Edge &rarr; Manage &rarr; Load
Balancer &rarr; Pools

### 1.4 Configure NSX Virtual Server

{{< responsive-figure src="https://cloud.githubusercontent.com/assets/1923644/19788285/3efaa0b8-9c5c-11e6-95c9-94a9b9f6ce6c.png" class="right large">}}

We configure the virtual server (the VM which acts as a load balancer and which
has the load balancer's IP address). The IP address of the load balancer belongs
to one of the interfaces of the NSX Edge (vNIC,  NSX menu navigation: Edge
&rarr; Manage &rarr; Settings &rarr; Interfaces).

The IP address (10.85.5.84) _is_ the load balancer, and it is the address to
which we'll point our browser during testing.

NSX menu navigation: Edge &rarr; Manage &rarr; Load
Balancer &rarr; Virtual Servers

### 1.5 Create Firewall Rule and Security Group to Restrict ssh

{{< responsive-figure src="https://cloud.githubusercontent.com/assets/1020675/19895148/db0e53ba-a00c-11e6-80c4-71dde83caeb2.png" class="right large">}}

We create a firewall rule to reject ssh traffic. We specify the following:

* Name (click pencil icon to modify): **deny-ssh-rule**
* Destination:
  * Object Type: **Security Group**
  * click **New Security Group...**
  * Name: **deny-ssh**
  * click **Finish**, click **OK**
* Service: **ssh**
* Action: **Reject**
* click **Publish Changes**

The name of the Security Group ("deny-ssh") is important — we will use this to
set our BOSH Director's Cloud Config's `vm_extensions`'s `nsx`'s property,
`security_groups`, in a subsequent step.

NSX menu navigation: Networking & Security &rarr; Firewall &rarr;
Configuration &rarr; General &rarr; _click the first rule_ &rarr; _click
green "plus" (+) icon_ &rarr; _make changes_ &rarr; _click "Publish Changes"_

<div class="alert alert-danger" role="alert">

NSX Edges have their own, separate firewall configuration. Those are outside
the scope of this blog post.

</div>
<p />

## 2.0 Create BOSH Director with NSX Features

### 2.1 Create SSL Keys and Certificates for BOSH Director

Follow [these instructions](https://bosh.io/docs/director-certs.html) to
generate the certificate, CA (Certificate Authority) certificate, and key for
the BOSH director. You may skip this step if you have a key and a valid,
CA-issued certificate for your BOSH director. For example, if your BOSH
director's hostname is "bosh.example.com", and you have a key and certificate
for "bosh.example.com", then you may skip this step.

### 2.2 Create BOSH Director Manifest

We create our BOSH director's manifest with the properties needed to communicate
with the NSX manager:

```yaml
jobs:
  - name: bosh
    ...
    properties:
      ...
      vcenter: # <--- Replace values below
        nsx:
          address:  nsx.example.com
          user:     administrator@vsphere.local
          password: ((nsx_password))
          # CA Certificate for your NSX Manager
          ca_cert: |
            -----BEGIN CERTIFICATE-----
            ...
```

Here is the complete [BOSH Director manifest](https://github.com/cunnie/deployments/blob/77559c00bccd41fa377cea0289ef960342039b3d/bosh-vsphere.yml).

### 2.3 Create BOSH Director using BOSH Director's Manifest

We deploy our BOSH Director. We use the BOSH [Golang
CLI](https://github.com/cloudfoundry/bosh-cli) client which allows variable
interpolation (denoted by "((" and "))" in the manifest). We interpolate
variables from our JSON-formatted LastPass secure note, "vsphere cpi concourse
secrets"). Note that variable interpolation is not strictly necessary, and you
may choose to place sensitive information such as the vCenter user's password in
plaintext in the manifest. *Caveat utor*.

```bash
bosh create-env bosh-vsphere.yml -l <(lpass show --note "vsphere cpi concourse secrets")
```

## 3.0 Create Cloud Config

### 3.1 Log into the BOSH Director

We log into our BOSH Director. Note that we use the IP address and pass the CA
Certificate of our self-generated certificate. If you have a valid cert,
you should pass the hostname, not the IP address, of your BOSH director, and
you do not need to specify the `--ca-cert` parameter.

In our sample manifest, the login user is **admin** and the password is **admin**.

```bash
bosh env 10.85.57.6 --ca-cert ~/scratch/vsphere/certs/rootCA.pem
bosh log-in
```

### 3.2 Create and Update Cloud Config

We create a [BOSH Cloud Config](http://bosh.io/docs/cloud-config.html) with NSX
properties for our deployment:

```yaml
vm_extensions:
- name: lb
  cloud_properties:
    nsx:
      security_groups:
      - deny-ssh                      # TODO: create in advance & assign firewall rules
      lbs:
      - edge_name: load-balancer
        pool_name: http-pool
        security_group: http-backend  # does not need to be created in advance
        port: 80
```

The name of the VM Extension ("lb") is important — we will use this subsequently
in our deployment manifest to assign our VM to the load balancer backend and
to reject ssh traffic.

The Edge and Pool must exist prior to the deployment; see [1.0 NSX
Prerequisites](#prerequisites) for instructions. The NSX Security Group
`deny-ssh` should be created in advance. The other Security Group,
`http-backend`, does not need to be created in advance (BOSH will create it).

<div class="alert alert-warning" role="alert">

Although BOSH auto-creates Security Groups (e.g. `deny-ssh`), it will not
create corresponding firewall rules (e.g. "reject all inbound traffic to port
22") nor attach Security Groups to the firewall rule.

When to create a Security Group in advance? A good rule of thumb is this: <b>If
in doubt, create the Security Group in advance</b>. The Security Group _must_ be
created in advance if it is used in a firewall rule, but it is  not necessary
when it is used as a load balancer backend. In other words, create the Security
Group in advance if it is referenced under the
`vm_extensions.cloud_properties.nsx.security_groups` property.

</div>
<p />

We upload our
Cloud Config to the Director:

```bash
bosh update-cloud-config cloud-config-vsphere.yml
```

Here is the complete [Cloud
Config](https://github.com/cunnie/deployments/blob/c1f529c154960eed0382ebca79dc2b765826886b/cloud-config-vsphere.yml).

## 4.0 Deploy VMs with NSX Configured

We deploy our VMs that will function as the backend of our load balancer.

### 4.1 Upload Stemcell & ngninx Release

Our deployment requires a BOSH stemcell and the BOSH nginx release; we upload
them to our BOSH Director:

```bash
bosh upload-stemcell https://bosh.io/d/stemcells/bosh-vsphere-esxi-centos-7-go_agent?v=3263.8
bosh upload-release https://github.com/cloudfoundry-community/nginx-release/releases/download/v4/nginx-4.tgz
```

### 4.2 Create a deployment manifest

We deploy three nginx VMs. In order to associate these VMs with the Security
Groups and LBs listed in the Cloud Config, we add the `lb` VM extension (which
we defined in our Cloud Config, above) to each Instance Group

`vm_extensions` requires an array value, thus `lb` must be enclosed in brackets.

```yaml
instance_groups:
- name: nginx
  instances: 1
  vm_type: default
  vm_extensions: [lb]
  ...
```

Here is the [deployment manifest](https://github.com/cunnie/deployments/blob/a21607715c8456e2c93f2d99f58690e8e5c9896f/nginx-vsphere.yml).

We deploy our VMs with our manifest:

```bash
bosh deploy -d nginx nginx-vsphere.yml
```

## 5.0 Test

### 5.1 Test Load Balancer

{{< responsive-figure src="https://cloud.githubusercontent.com/assets/1020675/19872716/7b129532-9f78-11e6-8f8e-5241ae718a3b.png" class="right small">}}

{{< responsive-figure src="https://cloud.githubusercontent.com/assets/1020675/19872715/7b106960-9f78-11e6-9066-c37e692107db.png" class="right small">}}

{{< responsive-figure src="https://cloud.githubusercontent.com/assets/1020675/19872714/7afd600e-9f78-11e6-881a-097915c38bb5.png" class="right small">}}

We browse to our virtual server (10.85.5.84). We hit refresh three times to
ensure the load balancer cycles through each of the backend VMs.

Each backend's home page declares its IP address (e.g. 10.85.57.21) in a unique
color (e.g. red). We can determine immediately which backend we're hitting.

We see that all 3 backends are functioning properly.

### 5.1 Test Firewall's ssh Filter

We ssh into one of our VMs to make sure our firewall rule is properly
rejecting ssh traffic:

```bash
for LAST_OCTET in 21 22 23; do
  ssh vcap@10.85.57.${LAST_OCTET}
done
ssh: connect to host 10.85.57.21 port 22: Connection refused
ssh: connect to host 10.85.57.22 port 22: Connection refused
ssh: connect to host 10.85.57.23 port 22: Connection refused
```

## Addendum: Technical Requirements

* [BOSH vSphere CPI](http://bosh.io/releases/github.com/cloudfoundry-incubator/bosh-vsphere-cpi-release?all=1) v30+ (v31 tested)
* VMWare NSX-V 6.1+ (6.2.2 Build 3604087 tested)
* vSphere 6.0+ (6.0.0.20000 tested)

## Addendum: BOSH Documentation

* [BOSH vSphere CPI] (http://bosh.io/docs/vsphere-cpi.html)

## Addendum: NSX Documentation
* [NSX for vSphere Official Documentation] (https://www.vmware.com/support/pubs/nsx_pubs.html)
* RAML Spec Describing NSX for vSphere API (https://github.com/vmware/nsxraml)

## Addendum: PowerNSX Windows CLI

Windows users may prefer to configure the NSX Manager via the
[PowerNSX CLI](https://github.com/vmware/powernsx), a "a PowerShell module that abstracts the VMware NSX API to a set of easily used PowerShell functions".
We have not tested this ourselves (we have but few Windows machines at Pivotal).

## History/Corrections

2016-11-2: NSX Manager's password is interpolated in the BOSH Director's
manifest; previously it was in plaintext.

2016-11-2: A comment showed a command to extract the NSX Manager's
self-signed certificate. The command lent itself to a man-in-the-middle
attack, so the comment has been removed.

2016-11-3: An addendum refers to the PowerNSX CLI. Thanks [Anthony
Burke](https://twitter.com/pandom_).

2016-11-3: A misplaced comment in the Cloud Config indicated that the pool did
not need to be created in advance; that was incorrect. The pool must be created
in advance, but the Security Group does not. The comment now correctly indicates
that the Security Group does not need to be created in advance.

2016-11-4: The definition of an NSX Security Group was clarified. Also, a
reference to NSX Transformers was removed. Links to the NSX documentation were
added. Thanks [Pooja Patel](https://twitter.com/poozza).

---

## Footnotes

<a name="nsx_security_groups"><sup>[NSX Security Groups]</sup></a> NSX's
Security Groups are rich grouping objects. A Security Group typically consists
of a name (e.g. "deny-ssh") and a collection of zero or more objects. In BOSH's
case, these objects are VMs (e.g. LB backend VMs). During deployment, BOSH
attaches VMs to Security Groups as defined in the Cloud Config's
`vm_extensions.cloud_properties.nsx` section. If the Security Group is
defined in a firewall rule, that firewall rule is applied to those VMs.
If that Security Group is a member of a Load Balancer pool, then that VM
becomes (by association) a member of the Load Balancer pool.
