---
authors:
- jamil
categories:
- BOSH
- Apache JMeter
- Distributed Load Testing
- Distributed Stress Testing
date: 2017-03-11T09:42:46-05:00
short: |
  Tornado for Apache JMeter&trade;, is a BOSH release for Apache JMeter&trade;. It simplifies the usage of JMeter&trade; in distributed mode, making it easier to perform load or stress testing.
title: "BOSH + Apache JMeter(TM) = Tornado for Apache JMeter(TM)"
---

[BOSH](http://bosh.io/) is an open source tool for release engineering, deployment, lifecycle management, and monitoring of distributed systems.
BOSH can provision and deploy software over hundreds of VMs. It also performs failure recovery and software updates with zero-to-minimal downtime.

[Apache JMeter&trade;](http://jmeter.apache.org/) is open source software, a 100% pure Java application designed to load test functional behavior and measure performance. It was originally designed for testing Web Applications but has since expanded to other test functions. JMeter may be used to test performance both on static and dynamic resources, Web dynamic applications. It can be used to simulate a heavy load on a server, group of servers, network or object to test its strength or to analyze overall performance under different load types.

[Tornado for Apache JMeter&trade;](https://github.com/jamlo/jmeter-bosh-release), is a [BOSH](https://bosh.io/) release for [Apache JMeter &trade;](http://jmeter.apache.org/). It simplifies the usage of JMeter&trade; in distributed mode, making it easier to perform distributed load/stress testing on multiple IAAS offerings.

**Note: Apache&trade;, Apache JMeter&trade; and JMeter&trade; are trademarks of the Apache Software Foundation (ASF).**

**Note: This software is NOT associated with Apache JMeter&trade; software or the ASF.**

## Release Features

* Horizontally scale your JMeter&trade; load/stress tests with the power of BOSH.
* Deploy onto multiple IaaS offerings (wherever BOSH can be deployed: AWS, Microsoft Azure, Google Compute Engine, OpenStack, etc).
* Distribute the source traffic of your load tests across multiple regions and IaaS.
* Tune the JVM options for JMeter&trade; from your BOSH deployment manifest (no VM SSHing is needed).
* The load/stress tests results will be automatically downloaded to your local machine (optional dashboard can be generated).
* Offered in 2 modes: `Storm` and `Tornado` modes.

## How It Works

### 1) Storm Mode
This mode is used when the collection of the results for a JMeter&trade; plan execution is necessary. It works by spinning `n` number of VMs that will act as JMeter&trade; workers. Those VMs will run JMeter&trade; in server mode, and patiently wait for an execution plan to be delivered to them.

When all the workers are up, a BOSH [errand](https://bosh.io/docs/terminology.html#errand) can be manually triggered where it will send the execution plan to the workers, waits for them to finish execution, collect the results, and download these results to the users local machine.

**Detailed Steps :**

* When first deploying, an `n` number of VMs will be created, each running a jmeter&trade; worker. Each worker will wait and listen for commands to be sent.
* When the workers have been started, a [BOSH errand](https://bosh.io/docs/terminology.html#errand) should be manually run. This results in the creation of another VM.
* When the Errand VM has been started, a bash script will be automatically executed on that VM. In our case, the script will run a JMeter&trade; client that connects to all the JMeter&trade; workers running on the worker VMS. This client will distribute the test plan to the workers. Behind the scenes, BOSH will detect all the IP addresses of the workers VMs without the user's intervention (This is accomplished through [BOSH links](https://bosh.io/docs/links.html)).
* When all the JMeter&trade; workers are done executing the test plan (each worker will execute the plan separately, knowing nothing about the other workers), each worker will report back the tests results to the JMeter&trade; client running on the errand VM.
* The Jmeter&trade; client, will aggregate the test result (an optional dashboard can be generated).
* The aggregated test results will then be downloaded to the user's local machine.

{{< responsive-figure src="/images/jmeter-bosh-release/jmeter_storm_mode.png" >}}

### 2) Tornado Mode - Unleash the Dragons
This mode is more suitable in the scenario where the simulation of large number of active users is more important than collecting the results logs; for example, detecting the behaviour of an application under continuous heavy traffic.

How it works is by spinning `n` number of VMs, each provided the same JMeter&trade; execution plan. Then each JMeter&trade; instance will loop indefinitely (the JMeter&trade; plan should be set to loop indefinitely when created) targeting the requested URL. You can tune the number of working VMs on the fly through BOSH; by utilizing `bosh stop` and `bosh start` commands, or by changing the number of instances and deploying again.

**Detailed Steps :**

* Create a deployment with `n` number of instances
* On each VM, a JMeter&trade; instance will be started, executing the provided plan.
* JMeter&trade; (on each VM) will loop indefinitely, hammering the target(s) specified.
* Through BOSH CLI, the user can `bosh stop`, `bosh start` to tune the number of JMeter&trade; plans working.

This mode is useful in the scenario where the operator already has monitoring software for the target application and want to see the behaviour of it under huge loads.

{{< responsive-figure src="/images/jmeter-bosh-release/jmeter_tornado_mode.png" >}}

## A Sample Deployment

Check the repo [README](https://github.com/jamlo/jmeter-bosh-release#getting-started---aws-example) for steps how to create your own test plan. Also check the [docs](https://github.com/jamlo/jmeter-bosh-release/tree/master/docs) folder for sample manifests.
