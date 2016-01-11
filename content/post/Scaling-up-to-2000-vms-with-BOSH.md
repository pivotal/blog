---
authors: 
- kai
categories:
- BOSH
date: 2015-10-16T15:43:00-07:00
short: |
  In order to know if we can deploy 2000 vms with BOSH, we did a scaling test and this blog post list how we did it and the caveats we found.
title: Scaling up to 2000 vms with BOSH
---

Pivotal's Cloud Ops team provide production operation support for [Pivotal Web Services](https://run.pivotal.io/), which is a public facing PaaS service based on [cloudfoundry](https://github.com/cloudfoundry).

Managing such a big cluster (hundreds of vms) is not easy, and here are some of the challenges we are facing from day to day:

* Continuous integration: Deploy the latest code to production every few days.
* Scale entire cluster if the capacity is not enough.
* Upgrade the OS images for the whole cluster with no downtime.
* Deploy the whole cluster to some new environment with some version of code.

and one tool we heavily rely on for managing our deploy is [BOSH](http://bosh.io/).

BOSH provides software release which packages up all related source code, binary assets, configuration etc, In addition to releases BOSH provides a way to capture all Operating System dependencies as one image which is called Stemcell.

BOSH tool chain provides a centralized server that manages software releases, Operating System images, persistent data, and system configuration. It provides a clear and simple way of operating deployed system.

(note: If you are not familiar with BOSH, one suggestion is to go through the [BOSH tutorial](http://mariash.github.io/learn-bosh/#introduction) )

it works great for us, yet we would like to know how far we can go, we did a scaling test for BOSH. and it turns out we can scale to up to 2000 vms and we still didn't see the limit of BOSH yet!

Here is how we roll it:

### Steps:

* Setup an AWS account and increase the EC2 instance limit to 2000
* Set up a BOSH with [bosh-init](https://bosh.io/docs/using-bosh-init.html)
* Deploy a second BOSH cluster with the first BOSH.

Note: We put the nats job into another vm, in order to be able to scale it separately,
This is not recommended, we assume we will see the CPU contention but it doesn't happend,
it bring extra complexity without significant benefit, more points of failure in the control plane.

A deployment manifest snippet as below:
```yaml
jobs:
- name: nats
  templates:
  - name: nats
    release: bosh
  instances: 1
  resource_pool: default
  networks:
  - name: default
    default:
    - dns
    - gateway
    static_ips:
    - 10.0.0.8
  properties:
   nats:
    user: <REPLACE WITH NATS USER>
    password: <REPLACE WITH NATS PASSWORD>
    address: 10.0.0.8
    port: 4222
 
- name: bosh
  templates:
  - name: redis
    release: bosh
  - name: powerdns
    release: bosh
  - name: director
    release: bosh
  - name: registry
    release: bosh
  - name: health_monitor
    release: bosh
  instances: 1
  resource_pool: default
  persistent_disk: 20480
  networks:
  - name: default
    default:
    - dns
    - gateway
    static_ips:
    - 10.0.0.7
  - name: vip_network
    static_ips:
    - <REPLACE WITH IPs>
```

* Create a deployment manifest for [dummy BOSH release](https://github.com/pivotal-cf-experimental/dummy-boshrelease), create a dummy BOSH release and upload to the second BOSH director. 
* BOSH deploy, 2000 vms get created and deployed.
* Make some changes to dummy release, create a new version of dummy release and do BOSH deploy again, 2000 vms get updated with the new code.

   We do managed to finish the creation of 2000 vms cluster from 0, update and delete it in one day, yet we found a couple of caveats.

### Caveats:

First issue we found is AWS doesn't offer us 2000 instances in one AZ(availability zone). we have more than 1000 instances available in one AZ and less instances available in another AZ.

This one is easily overcome by creating 2 resource pools in BOSH manifest, each resource pool utilize one AZ. Then BOSH will automatically figure out how to place the vms into 2 AZ separately.

Another difficulty we found in the deploy is it will takes a lot of time if we can only update one vm at a time. Luckily, BOSH has a max_in_flight option which can specify how many vms to update concurrently. 

But we would like to push it higher see how fast we can go, we found another hard limitation in BOSH which most people don't know, which is the max_threads in [BOSH director configuration](https://github.com/cloudfoundry/bosh/blob/master/release/jobs/director/spec#L73).

Before we change the max_threads, even if we set max_in_flight to 256, we found only 32 vms was updating at the same time.

So we try increasing that max_threads to 256, (you need target the first BOSH and change the BOSH manifest and redeploy to make it effect), and we start seeing some error like below:

Error 100: Request limit exceeded.
AWS::EC2::Errors::RequestLimitExceeded Request limit exceeded
 
After talking to Amazon about it, this is a general limitation in AWS EC2 and we can't easily increase it in AWS side.
 
So we step back a bit to find out what the biggest parameter we can use on AWS, and 50 seems to be what we can do in Max in our account.

(BTW: We also submit some feature request to BOSH so it will retry when the limit exceeded, 
and the story is now in the [backlog](https://www.pivotaltracker.com/n/projects/956238/stories/103449734)

This is not an ideal speed but still something acceptable, after this tuning, we managed to deploy 2000 vms in 2 hours, update 2000 vms in next 2 hours and delete the whole deployment in next 1.5 hour.

During the whole deploy process, we observed the CPU, Network, Disk utilization in the director VM (we use c3.xlarge) are still pretty moderate, which indicate we still have headrooms, but we don't go further due to time constraints.
