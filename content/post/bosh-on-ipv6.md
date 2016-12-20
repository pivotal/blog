---
authors:
  - cunnie
categories:
  - BOSH
  - IPv6
date: 2016-12-20T20:49:50.000Z
draft: true
short: |
  Amazon Web Services (AWS) has recently announced Internet Protocol version 6
  (IPv6) Support for their Elastic Compute Cloud (EC2) Instances in Virtual
  Private Clouds (VPCs). In this blog post, we describe using the beta BOSH
  command line interface (CLI) to deploy a virtual machine (VM) running nginx (a
  popular webserver) to EC2 with a native IPv6 address.
title: Using the beta BOSH CLI to Deploy an IPv6-enabled nginx Server to AWS
---

This blog post describes the procedure we followed to use the [beta BOSH command
line interface (CLI)](https://bosh.io/docs/cli-v2.html) to deploy an nginx
webserver with a native IPv6 address (i.e. 2600:1f16:0a62:5c00::4) to AWS in
addition  to its IPv4 Elastic IP address (i.e. 52.15.73.90).  We were then able
to browse the webserver _via the IPv6 protocol._

<div class="alert alert-error" role="alert">

BOSH does not support IPv6. This is a proof-of-concept. Do not apply IPv6 to
your production BOSH Directors or to BOSH CLI-deployed systems.

</div>

## 0. Network Diagram

The following is a network diagram of our final configuration:

{{< responsive-figure src="https://docs.google.com/drawings/d/1WemXsPIQ2KxWRT6lh0nYprDnE-LvsVzYJkGHKZ5WmWc/pub?w=781&amp;h=1087" >}}

## 1. Disclaimers

We do not use a BOSH Director (an orchestrator VM) to deploy an nginx webserver;
instead, we use the beta BOSH Golang CLI to deploy the webserver.

We do _not_ use the [BOSH Ruby command line
interface](https://rubygems.org/gems/bosh_cli/versions/1.3262.4.0) (CLI) to
deploy the webserver; instead, we deploy with the beta BOSH Golang CLI. Golang
has extensive support for IPv6 <sup><a href="#golang_ipv6">[Golang
IPv6]</a></sup> .

The procedure we follow is _not_ entirely automated. Specifically, we use the
AWS management console to manage the webserver's instance's IP addresses in
order to auto-assign an IPv6 address to our deployed webserver.

The webserver requires an IPv4 address and an IPv4 Elastic IP. The webserver is
not exclusively IPv6.

We use the [BOSH os-conf
release](https://github.com/cloudfoundry/os-conf-release) to enable IPv6 <sup><a
href="#ipv4_only_stemcells">[IPv4-only Stemcells]</a></sup> with the
`enable_ipv6` job.

We use the [BOSH Dynamic Host Configuration Protocol (DHCP)
release](https://github.com/pivotal-cf-experimental/dhcp-server-release) to
manually start the IPv6 DHCP client daemon which acquires an IPv6 address from
Amazon <sup><a href="#dhcpv6">[DHCPv6]</a></sup> .

## 2. Create AWS Environment

We create an IPv6-enabled environment.

The [BOSH Documentation](http://bosh.io/docs/init-aws.html#create-vpc) to create
a VPC is quite thorough, and the instructions below are meant to complement the
official instructions, not to replace them (for example, we do not describe
creating a key pair nor allocating an Elastic IPv4 address). _The instructions
below describe the additional configuration required for an IPv6 deployment_.

### 2.0 Create VPC

Create an IPv6 VPC. Currently the VPC must be created in the _us-east-2_ [AWS
Region](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html#concepts-available-regions)
(Ohio). Select **IPv6 CIDR block &rarr; Amazon provided IPv6 CIDR**.

{{< responsive-figure src="https://cloud.githubusercontent.com/assets/1020675/21070083/2c93f73a-be35-11e6-812c-cc973df0dfa9.png" >}}

### 2.1 Create Subnet

Create the Subnet in the IPv6 VPC. Select **IPv6 CIDR block &rarr;
Specify a custom IPv6 CIDR**

{{< responsive-figure src="https://cloud.githubusercontent.com/assets/1020675/21070194/87db9b2e-be36-11e6-93c1-76cfec9169b8.png" >}}

We choose the IPv6 `2600:1f16:0a62:5c00::/64` Classless Inter-Domain Routing
(CIDR) for our subnet
<sup><a href="#ipv6_cidr">[IPv6 CIDR]</a></sup> .

We were excited to discover that we could select **Subnet Actions &rarr; Modify
auto-assign IP settings &rarr; Enable auto-assign IPv6 address**, but
disappointed to learn that it had no effect on our BOSH-deployed VM (it had no
routable IPv6 addresses when deployed).

### 2.2 Create Internet Gateway

Create an Internet Gateway.

Attach it to the IPv6 VPC.

### 2.3 Create Route Table

Create route table. Add default routes for outbound IPv4 traffic (0.0.0.0/0)
and for outbound IPv6 traffic (::/0)

{{< responsive-figure src="https://cloud.githubusercontent.com/assets/1020675/21197499/8a8fc4c2-c1f0-11e6-8083-289e89c0b951.png" >}}

::/0 is IPv6 shorthand for all IP addresses. A routing table entry whose
destination is ::/0 is the default IPv6 route.

### 2.4 Associate Route Table with Subnet

{{< responsive-figure src="https://cloud.githubusercontent.com/assets/1020675/21315699/46ac2668-c5b2-11e6-80bb-e2b34f1f239e.png" >}}

### 2.5 Create Security Group

Create the Security Group in the IPv6 VPC

We enable all traffic, but we are aware that the security-minded should be much
more prudent.

Note that we enable traffic from all IPv4 sources (**0.0.0.0/0**) and all IPv6
sources (**::/0**).

{{< responsive-figure src="https://cloud.githubusercontent.com/assets/1020675/21070453/fa703cf0-be39-11e6-8b2c-1b74ecab796c.png" >}}

## 3. Deploy IPv6-enabled nginx webserver

We deploy the nginx webserver.

### 3.0 Create BOSH Manifest

Here is our [BOSH
Manifest](https://github.com/cunnie/deployments/blob/a86ac4f499dffdf2d0bb62b4ab031cff78f021a0/nginx-aws-ipv6.yml).

We use LastPass to store our secrets (e.g. our AWS Access Key ID and Secret
Access Key). The new BOSH CLI allows us to inject our secrets into our manifest
(all properties enclosed in a double parentheses are templatized). In this
snippet of the manifest, we templatize our Amazon credentials:

```
aws:
  access_key_id: ((aws_access_key_id_ipv6)) # <--- Replace with AWS Access Key ID
  secret_access_key: ((aws_secret_access_key_ipv6)) # <--- Replace with AWS Secret Key
```

### 3.1 Deploy with BOSH

We deploy our webserver, using the LastPass CLI to read in our secrets from
a YAML file which is stored as a secure note:

```bash
bosh create-env bosh-aws-ipv6.yml -l <(lpass show --note deployments)
```

### 3.2 Check Instance Networking

This step is optional. We ssh to the instance to check IPv6 connectivity, first removing the history of the ssh key of the previous deploy using `ssh-keygen -R`. We use
the IP command `ip addr` to show the status of our `eth0` interface:

```
$ ssh-keygen -R 52.15.73.90; ssh -i ~/.ssh/aws_nono.pem vcap@52.15.73.90
...
/:~$ ip addr show dev eth0
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9001 qdisc mq state UP group default qlen 1000
    link/ether 02:30:8c:56:50:e9 brd ff:ff:ff:ff:ff:ff
    inet 10.0.0.7/24 brd 10.0.0.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::30:8cff:fe56:50e9/64 scope link
       valid_lft forever preferred_lft forever
```

We note the following:

* IPv4 connectivity is as expected: The local address is set to 10.0.0.7, as
  specified in our manifest.
* IPv6 is enabled (as determined by the `inet6` line); however, the address,
  fe80::30:8cff:fe56:50e9/64, is a [Link-local address](https://en.wikipedia.org/wiki/Link-local_address)
  and not routable.

### 3.3 Manually Add IPv6 address

Select our instance and choose **Actions &rarr; Networking &rarr; Manage IP
Addresses**

We assign the address 2600:1f16:0a62:5c00::4
<sup><a href="#ipv6_notation">[IPv6 notation]</a></sup> .
to our webserver.

{{< responsive-figure src="https://cloud.githubusercontent.com/assets/1020675/21315710/4f92fb1c-c5b2-11e6-8114-f182ab32e9fd.png" >}}

Note: we chose the address ::4 within our subnet for our instance. Addresses
:: (i.e. ::0), ::1, ::2, and ::3 are reserved by Amazon and cannot be assigned to instances.

## 4. Test IPv6

### 4.1 Browse to Webserver

We browse to our newly-deployed webserver's IPv6 address. Note that we must
[bracket the IPv6 address](https://en.wikipedia.org/wiki/IPv6_address#Literal_IPv6_addresses_in_network_resource_identifiers).

Our deployed webserver's home page displays our workstation's IPv6 address.

{{< responsive-figure src="https://cloud.githubusercontent.com/assets/1020675/21353219/e4818ee2-c679-11e6-9a5a-d10d835e9b46.png" >}}

### 4.2 Confirm IPv6 Assignment via AWS Console

[Optional] The Amazon console displays the instance's IPv6 address next to the **IPv6 IPs**
header.

{{< responsive-figure src="https://cloud.githubusercontent.com/assets/1020675/21353225/ec7544d6-c679-11e6-8937-4dbe3f299b97.png" >}}

### 4.3 Confirm IPv6 Assignment via ssh

[Optional] The `ip addr show dev eth0` command displays our 2600:1f16:a62:5c00::4 /128
AWS-assigned routable IPv6 address:

```bash
/:~$ ip addr show dev eth0
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9001 qdisc mq state UP group default qlen 1000
    link/ether 02:30:8c:56:50:e9 brd ff:ff:ff:ff:ff:ff
    inet 10.0.0.7/24 brd 10.0.0.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 2600:1f16:a62:5c00::4/128 scope global
       valid_lft forever preferred_lft forever
    inet6 fe80::30:8cff:fe56:50e9/64 scope link
       valid_lft forever preferred_lft forever
```

## 5. Troubleshooting

Do not use an `m3` instance type <sup><a href="#supported_instance_types"
class="alert-link">[Instance Types]</a></sup> ; it triggers the following error:

```bash
Deploying:
  Creating instance 'bosh/0':
    Creating VM:
      Creating vm with stemcell cid 'ami-5081db35 light':
        CPI 'create_vm' method responded with error: CmdError{"type":"Unknown","message":"The requested configuration is currently not supported. Please check the documentation for supported configurations.","ok_to_retry":false}
```

The IPv6 address may take up to 3 minutes to acquire after modifying the
instance's IP addresses to auto-assign an IPv6 address.

## 6. Footnotes

<a name="golang_ipv6"><sup>[Golang IPv6]</sup></a> Golang has been designed with
IPv6 in mind, at times at the expense of IPv4 users ("[ParseIP always returns an
IP in ipv6 ipv4-mapped address
format](https://github.com/golang/go/issues/8985)", "[netstat only list ipv6
port](https://groups.google.com/forum/#!msg/golang-nuts/F5HE7Eqb6iM/q_um2VqT5vAJ)").

<a name="ipv4_only_stemcells"><sup>[IPv4-only Stemcells]</sup></a> BOSH
stemcells, as a side-effect of the hardening initiative, disable IPv6 by default
through judicious use of kernel (system) variable settings.

- Security Technical Implementation Guide (STIG) [V-38546](https://www.stigviewer.com/stig/red_hat_enterprise_linux_6/2013-06-03/finding/V-38546)
- Pivotal Tracker [story](https://www.pivotaltracker.com/n/projects/956238/stories/119692507)
- GitHub [commit](https://github.com/cloudfoundry/bosh/commit/44607ae50110ca0c723f7509073d28542a7d7a4d)

We did not need to un-blacklist the IPv6 kernel module in `/etc/modprobe.d/blacklist.conf`:
IPv6 is built into the kernel; it's not a module.

<a name="dhcpv6"><sup>[DHCPv6]</sup></a> AWS uses DHCPv6 to allocate IPv6
addresses in lieu of the more common [stateless address autoconfiguration
(SLAAC)](https://en.wikipedia.org/wiki/IPv6#Stateless_address_autoconfiguration_.28SLAAC.29),
a component of the [Neighbor Discovery
Protocol](https://en.wikipedia.org/wiki/Neighbor_Discovery_Protocol) (NDP).

<a name="ipv6_cidr"><sup>[IPv6 CIDR]</sup></a> Although IPv6 networks can be
[subnetted](https://en.wikipedia.org/wiki/IPv6_subnetting_reference) in a manner
similar to IPv4 networks, the primary method of allocating IP addresses, SLAAC,
requires a /64 subnet. Hence almost all IPv6 subnets are /64.

For example, although AWS allocates a /56 IPv6 range for each VPC, AWS
requires all IPv6 subnets within the VPC to have a /64 CIDR.

AWS is more flexible with IPv4 subnetting: A VPC's IPv4 allocation [can range from](http://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/VPC_Subnets.html#VPC_Sizing) /16 to /28. The subnets also range from /16 to /28.

<a name="ipv6_notation"><sup>[IPv6 notation]</sup></a>
[IPv6 address representation](https://en.wikipedia.org/wiki/IPv6_address#Recommended_representation_as_text) recommends separating each 16-bit group with colons (":"), suppressing leading zeros ("0"), and using the double-colon ("::") to represent one or more all-zero groups. Thus, our webserver's address is represented as 2600:1f16:a62:5c00::4 although the unsimplified address would be represented as 2600:1f16:0a62:5c00:0000:0000:0000:0004.

Amazon reserves the addresses ::1, ::2, ::3 in each IPv6 subnet.

<a name="supported_instance_types"><sup>[Instance Types]</sup></a>
AWS notes in [their
announcement](https://aws.amazon.com/blogs/aws/new-ipv6-support-for-ec2-instances-in-virtual-private-clouds/):

> It works with all current-generation EC2 instance types with the exception of M3 and G2
