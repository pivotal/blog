---
authors: 
- cunnie
- dimsdale
categories:
- BOSH
- Concourse
date: 2015-10-24T13:52:48-07:00
short: |
  How to deploy a publicly-accessible, extremely lean Concourse CI server.
title: The World's Smallest Concourse CI Server
---

### *[2016-04-06: This Blog Post is out-of-date; Please refer to the official [Concourse documentation](http://concourse.ci/installing.html) for instructions how to install a Concourse server]*

[Continuous Integration](https://en.wikipedia.org/wiki/Continuous_integration)
(CI) is often used in conjunction with test-driven development (TDD);
however, CI servers often
bring their own set of challenges: they are usually "snowflakes",
uniquely configured machines that are difficult to upgrade, re-configure, or
re-install. <sup>[[snowflakes]](#snowflakes)</sup>

In this blog post, we describe deploying a publicly-accessible, lean
(1GB RAM, 1 vCPU, 15GB disk)
[Concourse](http://concourse.ci/) CI server using a 350-line manifest.
Upgrades/re-configurations/re-installs are as simple as editing a file
and typing one command (*bosh-init*).

We must confess to sleight-of-hand: although we describe deploying a CI
server, the worker is too lean to run any but the smallest tests.
**The deployed CI Server we describe can't run large tests**.

We will address that shortcoming in a future blog post where we describe
the manual provisioning of local workers. The process isn't difficult, but
including it would have made the blog post undesirably long.

## 0. Set Up the Concourse Server

In the following steps, we demonstrate creating a Concourse
CI server, [ci.blabbertabber.com](https://ci.blabbertabber.com/)
for our open source Android project,
[BlabberTabber](https://github.com/blabbertabber/blabbertabber).

### 0.0 Prepare an AWS Account

We follow the bosh.io [instructions](http://bosh.io/docs/init-aws.html#prepare-aws)
<sup>[[AWS tooling]](#aws_tooling)</sup>
to prepare our AWS account.

After we have completed this step, we have the information
we need to populate our BOSH deployment's manifest:

* Access Key ID, e.g. AKIAxxxxxxxxxxxxxxxx
* Secret Access Key, e.g. 0+B1XW6VVxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
* Availability Zone, e.g. us-east-1a
* Region, e.g. us-east-1
* Elastic IP, e.g. 52.23.10.10
* Subnet ID, e.g. subnet-1c90ef6b
* Key Pair Name, e.g. bosh, aws_nono
* Key Pair Path, e.g. ~/my-bosh/bosh.pem, ~/.ssh/aws_nono.pem

### 0.1 Create the *concourse* Security Group

Although we created an AWS Security Group in the previous step, it doesn't
suit our purposes&mdash;we need to open the ports for HTTP (80) and HTTPS (443).
We create a *concourse* Security Group via the Amazon AWS Console:

* **VPC &rarr; Security Groups**
* click **Create Security Group**
  * Name tag: **concourse**
  * Description: **Rules for accessing Concourse CI server**
  * VPC: *select the VPC in which you created in the previous step*
  * click **Yes, Create**
* click **Inbound Rules** tab
* click **Edit**
* add the following rules:

    | Type of Traffic | Protocol  | Port Range | Source IP CIDR   | Notes |
    | :-------------  | :-------- | ---------: | --------: | :---- |
    | SSH (22)        | TCP (6)   | 22         | 0.0.0.0/0 | debugging, agents |
    | HTTP (80)       | TCP (6)   | 80         | 0.0.0.0/0 | redirect |
    | HTTPS (443)     | TCP (6)   | 443        | 0.0.0.0/0 | web |
    | Custom TCP Rule | TCP (6)   | 2222       | 0.0.0.0/0 | agents |
    | Custom TCP Rule | TCP (6)   | 6868       | 0.0.0.0/0 | bosh-init |

* click **Save**

### 0.2 Obtain SSL Certificates

We decide to use HTTPS to communicate with our Concourse server, for we will
need to authenticate against the webserver when we configure our CI
(when we transmit our credentials over the Internet we want them to be encrypted).

We purchase valid SSL certificates for our server <sup>[[Let's Encrypt]](#lets_encrypt)</sup> .
Using a self-signed certificate is also an option.

We use the following command to create our key and CSR. Note that you
should substitute your information where appropriate, especially for the
CN (Common Name), i.e. don't use *ci.blabbertabber.com*.

```bash
openssl req -new \
  -keyout ci.blabbertabber.com.key \
  -out ci.blabbertabber.com.csr \
  -newkey rsa:4096 -sha256 -nodes \
  -subj '/C=US/ST=California/L=San Francisco/O=blabbertabber.com/OU=/CN=ci.blabbertabber.com/emailAddress=brian.cunnie@gmail.com'
```

We submit the CSR to our vendor, authorize the issuance of the certificate,
and receive our certificate, which we will place in our manifest (along with
the key and the CA certificate chain).

We configure a DNS A record for our concourse server to point to our AWS Elastic IP.
We have the following line in our blabbertabber.com zone file:

```
ci.blabbertabber.com. A 52.23.10.10
```

### 0.3 Create Private SSH Key for Remote workers

We create a private ssh key for our remote worker:

```
ssh-keygen -P ''  -f ~/.ssh/worker_key
```

We will use the public key in the next step, when we create our BOSH manifest.

### 0.4 Create BOSH Manifest

We create the BOSH manifest for our Concourse server by doing the following:

* download the redacted (passwords & keys removed) BOSH [manifest](https://github.com/blabbertabber/blabbertabber/blob/develop/ci/concourse-aws.yml)
* open it in an editor
* search for every occurrence of *FIXME*
* update the field described by the *FIXME*, e.g. update the IP address,
  set the password, set the Subnet ID, etc....

For those interested, our sample Concourse manifest was derived from
Concourse's official sample *bosh-init*
[manifest](https://github.com/concourse/concourse/blob/master/manifests/bosh-init-aws.yml) and modified as follows:

* added an nginx release to provide SSL termination (i.e. HTTPS)
while bypassing the need for an ELB ($219.14/year <sup>[[ELB-pricing]](#ELB-pricing)</sup> ).
This was also why we enabled ports 80 and 443 in our AWS Security Group.
* added a postgres job and configured our Concourse server to use that instead of Amazon RDS in order
to eliminate RDS charges, but we suspect the savings to be insignificant.
* configured the web interface to be publicly-viewable but require authorization to make changes
* added our remote worker's public key to *jobs.properties.tsa.authorized_keys*

### 0.5 Deploy the Concourse Server

We install *bosh-init* by following these [instructions](https://bosh.io/docs/install-bosh-init.html).

We use *bosh-init* to deploy Concourse using the manifest
we created in the previous step. In the following example, our manifest is
named *concourse-aws.yml*:

```
bosh-init deploy concourse-aws.yml
  ...
  Finished deploying (00:12:15)

  Stopping registry... Finished (00:00:00)
  Cleaning up rendered CPI jobs... Finished (00:00:00)
```

A deployment takes ~12 minutes.This [gist](https://gist.github.com/cunnie/088794c9566a707aed71) contains
the complete output of the *bosh-init* deployment.

### 0.6 Verify Deployment and Download Concourse CLI

We browse to [https://ci.blabbertabber.com](https://ci.blabbertabber.com).

{{< responsive-figure src="/images/concourse-000/no_pipelines.png" >}}

We download the `fly` CLI by clicking on the Apple icon (assuming that your workstation is an OS X machine) and move it into place:

```bash
install ~/Downloads/fly /usr/local/bin
```
### 0.7 Create *Hello World* Concourse job

We follow Concourse's [Getting Started](http://concourse.ci/getting-started.html)
instructions to create our first pipeline. We
add `tags [ "micro" ]` to the sample Concourse pipeline
so that the job is run on our "micro" worker (in
our BOSH manifest, we tag the worker that
is colocated on our _t2.micro_ Concourse
server "micro" so that we can steer small jobs
to it).

```bash
cat > hello-world.yml <<EOF
jobs:
- name: hello-world
  plan:
  - task: say-hello
    config:
      platform: linux
      image: "docker:///ubuntu"
      tags: [ "micro" ]
      run:
        path: echo
        args: ["Hello, world!"]
EOF
```

We configure the pipeline (remember to substitute the username and password in the manifest,
*jobs.properties.atc.basic_auth_username* and *jobs.properties.atc.basic_auth_password*,
for "user:password" below):


```
fly -t "https://user:password@ci.blabbertabber.com" set-pipeline -p really-cool-pipeline -c hello-world.yml
```

You can see the gist of the output [here](https://gist.github.com/cunnie/a3a125e9069e493ef8ca).

Type **y** when prompted to apply the configuration.

### 0.8 Browse to Concourse and Kick off Job

Refresh [https://ci.blabbertabber.com](https://ci.blabbertabber.com) to
see our newly-created pipeline:

{{< responsive-figure src="/images/concourse-000/new_pipeline.png" >}}

Next we unpause the job

* click the "&equiv;" (hamburger) in the upper left hand corner
* click the "&#x25b6;" (play button) that appears below the hamburger.
  This will un-pause our pipeline and allow builds to run.
* click **Log in with Basic Auth**
* authenticate with the *atc*'s account and password (these can be found in the manifest,
*jobs.properties.atc.basic_auth_username* and *jobs.properties.atc.basic_auth_password*)
* click the "&equiv;" (hamburger) in the upper left hand corner (yes, again)
* click the "&#x25b6;" (play button) that appears below the hamburger.
The banner at the top of the screen will switch from light-blue to black.
The page should look like this:

{{< responsive-figure src="/images/concourse-000/unpaused_pipeline.png" >}}

### 0.9 Our First Integration Test: Hello World

We kick off our job:

* click the *hello-world* rectangle in the middle of the screen.
* click the "**&oplus;**" button in the upper right hand side of the screen

We see that the  job completes successfully by the
pea-green color. We click "**>_ say-hello**" to see the output:

{{< responsive-figure src="/images/concourse-000/success.png" >}}

## 1.0 Conclusion

We have demonstrated with the ease with which one can deploy a CI server
using a combination of *Concourse* and *bosh-init*, a deployment which takes
less than a quarter hour from start (no disk, no OS) to finish (a publicly-accessible,
up-and-running CI server) and which is easily re-deployed.

We recognize that our deployment is incomplete, that it lacks the workers
necessary to run jobs of any consequence.  We will describe how to manually
provision workers in our next blog post.

One of the benefits of the *Concourse/bosh-init* combination is that *Concourse*
stores its state on a [persistent disk](https://bosh.io/docs/persistent-disks.html),
so that re-deploying the CI server (e.g. new OS, new Concourse) won't cause the loss
of the pipeline configuration or build history.

## Appendix A. Concourse Yearly Costs: $80.34

The yearly cost of running a Concourse server is $80.34. Note that this
does not include the cost of the worker.
Had we chosen to implement the recommended m3.large EC2 instance for a worker, it
would have increased our yearly cost by $713.54 <sup>[[m3.large]](#m3.large)</sup> .

Here are our costs:

|Expense|Vendor|Cost|Cost / year
|-------|------|----|----------
|*ci.blabbertabber.com* cert|cheapsslshop.com|$14.85 3-year  <sup>[[inexpensive-SSL]](#inexpensive-SSL)</sup>|$4.95
|EC2 t2.micro instance|Amazon AWS|$0.0086 / hour <sup>[[t2.micro]](#t2.micro)</sup>|$75.39

## Footnotes

<a name="snowflakes"><sup>[snowflakes]</sup></a>
Even the most innocuous changes to a CI server can be fraught with anxiety: two years
ago when we were migrating one of our development team's Jenkins CI server VM
from one datastore to another (a very low-risk operation),
we needed to have several meetings with the Team's
product manager and the anchor before they were willing to allow us to proceed
with the migration.

<a name="aws_tooling"><sup>[AWS Tooling]</sup></a>
We appreciate that creating the AWS infrastructure (VPC, Elastic IP, Key Pair)
is tedious and a bit of a clickfest. We're working to make this much easier, soon.
Per Rob Dimsdale, "the MEGA team is actively working on tooling to improve the
user-experience of creating the AWS stack for Concourse, but we're not ready
for public consumption of that tooling just yet." Stay tuned.

<a name="lets_encrypt"><sup>[Let's Encrypt]</sup></a>
[Let's Encrypt](https://letsencrypt.org/) is a "free, automated, and open"
Certificate Authority which issues valid SSL certificates free of charge.
We are eagerly awaiting its launch, which hopefully will happen within the
next few weeks.

<a name="ELB-pricing"><sup>[ELB-pricing]</sup></a> ELB pricing, as of this writing, is [$0.025/hour](https://aws.amazon.com/elasticloadbalancing/pricing/), $0.60/day, $219.1455 / year (assuming 365.2425 days / year).

<a name="m3.large"><sup>[m3.large]</sup></a> Amazon effectively charges [$0.0814/hour](https://aws.amazon.com/ec2/pricing/) for a 1 year term all-upfront m3.large reserved instance.

<a name="inexpensive-SSL"><sup>[inexpensive-SSL]</sup></a> One shouldn't pay more than
$25 for a 3-year certificate. We used [SSLSHOP](https://www.cheapsslshop.com/comodo-positive-ssl) to purchase our *Comodo Positive SSL*, but there are many good SSL vendors, and we don't endorse one over
the other.

<a name="t2.micro"><sup>[t2.micro]</sup></a> Amazon effectively charges [$0.0086/hour](https://aws.amazon.com/ec2/pricing/) for a 1 year term all-upfront t2.micro reserved instance.
