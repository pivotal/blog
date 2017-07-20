---
authors:
- jamil
categories:
- BOSH
- Apache JMeter
- Distributed Load Testing
- Distributed Stress Testing
date: 2017-07-11T09:44:46-05:00
draft: false
short: |
  This post details the steps of utilizing BOSH to setup half a million (potentially much more) concurrent and distributed Apache JMeter threads for load testing.
title: "Half a Million Concurrent/Distributed JMeter Users with BOSH ... in 10 Minutes"
image: /images/jmeter-bosh-usecase/jmeter-bosh-usecase-1.png
---

[BOSH](http://bosh.io/) is an open source tool for release engineering, deployment, lifecycle management, and monitoring of distributed systems.
BOSH can provision and deploy software over hundreds of VMs. It also performs failure recovery and software updates with zero-to-minimal downtime.

[Apache JMeter&trade;](http://jmeter.apache.org/) is open source software, a 100% pure Java application designed to load test functional behavior and measure performance. It was originally designed for testing web applications but has since expanded to other test functions. JMeter may be used to test performance both on static and dynamic resources, web dynamic applications. It can be used to simulate a heavy load on a server, group of servers, network or object to test its strength or to analyze overall performance under different load types.

[Tornado for Apache JMeter&trade;](https://github.com/jamlo/jmeter-bosh-release), is a [BOSH](https://bosh.io/) release for [Apache JMeter &trade;](http://jmeter.apache.org/). It simplifies the usage of JMeter&trade; in distributed mode, making it easier to perform distributed load/stress testing on multiple IAAS offerings.

---
## Prerequisites

* Check this previous [blog post](http://engineering.pivotal.io/post/jmeter-bosh-release/) for more details about [Tornado for Apache&trade; JMeter&trade;](https://github.com/jamlo/jmeter-bosh-release) bosh release.
* A Bosh director deployed on AWS. See [Docs for details](https://bosh.io/docs/init-aws.html).
* Your AWS account quota limits should allow the creation of a minimum 100 `m4.large` instances.
* **Note: AWS is used here as an example. This experiment can be repeated on multiple IAAS offerings [(GCP, Azure, OpenStack, Softlayer)](http://bosh.io/docs/init.html)**

---
## Steps

### 1- Choose a Load Testing Target
<div class="alert alert-error" role="alert">
You'll need to choose a target for the load test. **MAKE SURE** you have the **PERMISSION** to load test the target. **DO NOT** direct this test for example at Google; as it will be considered a DDoS attack. It is your responsibility to make sure you have the permission to load test the target.

In this internal test, we used a service with the necessary permission (that can also handle this load). I repeat, **DO NOT** choose a target before getting the corresponding approval.
</div>

---
### 2- Add an Additional VM Type to the Cloud Config
We will be using `m4.large` instances for the JMeter Worker VMs. Add this snippet under the `vm_types` section in the cloud-config, and update it.

```yaml
- name: default
  cloud_properties:
    instance_type: m4.large
```
---
### 3- Modify the Public IPv4 Addressing Attribute for Your Subnet
The Subnet where all the VMs will come up need to enable the `Enable auto-assign public IPv4 address`. This will allow your VM to have access to the internet when load testing an external target. You'll also need to configure the route table and internet gateway accordingly in your AWS account settings.

---
### 4- Deploy
Deploy the following manifest (Change the target URL in the `jmeter_storm` job). It deploys Tornado for Apache&trade; JMeter&trade; in [STORM mode](https://github.com/jamlo/jmeter-bosh-release#1--storm). It creates 100 worker VMs, each with a JMeter instance that starts and waits for an execution plan to be delivered to it. Each JMeter instance will start 5000 threads. This number is usually a large one for an individual JMeter instance, but we'll stick with it for this test. See the note at the end of this post.

A quick look at the jobs properties, each thread will make a GET HTTP call each 5 seconds, for 3 minutes , with a rampup time of 2 minutes. The deploy will take few minutes; it is creating 100 VMs.

```yaml
---
name: jmeter

releases:
- name: jmeter-tornado
  version: "2.1.1"
  url: https://bosh.io/d/github.com/jamlo/jmeter-bosh-release?v=2.1.1
  sha1: c47ae7cd0094c5d9275ec083a8cdeef894f0064a

stemcells:
- alias: default
  os: ubuntu-trusty
  version: latest

update:
  canaries: 50
  max_in_flight: 50
  canary_watch_time: 5000-60000
  update_watch_time: 5000-60000

instance_groups:
- name: storm-workers
  azs: [z1]
  instances: 100
  jobs:
  - name: jmeter_storm_worker
    release: jmeter-tornado
    properties:
      jvm:
        xms: 1024m
        xmx: 6144m
  vm_type: default
  stemcell: default
  networks:
  - name: default

- name: storm
  lifecycle: errand
  azs: [z1]
  instances: 1
  jobs:
  - name: jmeter_storm
    release: jmeter-tornado
    properties:
      wizard:
        configuration:
          users: 5000
          ramp_time: 120
          duration: 180
          gaussian_random_timer:
            constant_delay_offset: 5000
            deviation: 5000
        targets:
        - name: An Example Test
          url: "http://<a target that you have permission to load test>"
          http_method: GET
  vm_type: small
  stemcell: default
  networks:
  - name: default
```

At the end of the deploy run `bosh instances`, you should get something similar to this:

```
[jamil@ra3id: bosh-1 ]$ bosh instances
Using environment 'X.X.X.X' as client 'admin'

Task 216. Done

Deployment 'jmeter'

Instance                                            Process State  AZ  IPs
storm-workers/012c4e52-ef5a-4f7b-805c-4294206f49f1  running        z1  10.0.1.55
storm-workers/01dbdf14-545a-4d66-8998-7971f5dd6a25  running        z1  10.0.1.7
storm-workers/03be756f-e259-42ae-9f53-b897655cdeeb  running        z1  10.0.1.8
storm-workers/097af91e-9af3-4cdb-b46e-eb76ccefb3b1  running        z1  10.0.1.9
storm-workers/10741b24-40bc-4b47-b851-e25b76a0a56a  running        z1  10.0.1.56
storm-workers/1220f5b1-23d6-48a1-be89-756dc5840a4d  running        z1  10.0.1.10
storm-workers/17b8b1ad-a155-459f-ae44-74c09582bd6a  running        z1  10.0.1.57
storm-workers/1880b213-dc82-4fda-80b2-6f9ed34f9014  running        z1  10.0.1.58
storm-workers/1b4bd5ae-7bed-468b-b20c-5d59882bf249  running        z1  10.0.1.59
storm-workers/1b92e5e5-5d14-44b1-9f12-ffc604ba6177  running        z1  10.0.1.11
storm-workers/1b962c14-6f91-4729-b3ce-4e444e9395f9  running        z1  10.0.1.100
storm-workers/1dbcc612-63d6-4bcd-a0aa-910f11718f46  running        z1  10.0.1.60
storm-workers/1dc6cff0-783a-40d4-97ab-b1db78d0965a  running        z1  10.0.1.61
storm-workers/1f7c4c0e-8c31-4d21-9722-2f9030b9cd40  running        z1  10.0.1.12
storm-workers/26de8fa7-470e-436d-b2a2-dd7648f0be12  running        z1  10.0.1.62
storm-workers/2ae361a4-9a72-42f2-8ad7-9f0c064f6e8a  running        z1  10.0.1.63
storm-workers/2ae98c98-f5d5-4f37-9525-aebb1874ca57  running        z1  10.0.1.6
storm-workers/2de84ea4-c5ed-44ee-91b2-3f0eafcc3976  running        z1  10.0.1.13
storm-workers/2ee299c5-1071-4840-8f5e-2f82e1e29e5c  running        z1  10.0.1.64
storm-workers/2fc857b8-1aeb-4d69-8400-e42eed41c9ae  running        z1  10.0.1.14
storm-workers/30bbc8a0-fb0e-4c99-9f89-54049292d413  running        z1  10.0.1.15
storm-workers/342eaa4e-ea4c-43b5-88e9-88bf9b689015  running        z1  10.0.1.16
storm-workers/3580e767-55f4-467c-9ff0-db7f355341d6  running        z1  10.0.1.65
storm-workers/3852d3b9-7021-4c13-b2dd-9d2f32f90a92  running        z1  10.0.1.17
storm-workers/3924d891-3b87-4c55-ad4d-df7f376568ed  running        z1  10.0.1.18
storm-workers/3d8cdf2e-c781-4059-bba0-b14ad3a12f12  running        z1  10.0.1.66
storm-workers/3fc86cf9-4475-44e7-a0a5-851c26280096  running        z1  10.0.1.19
storm-workers/43bd0db6-82d6-40f2-b5a2-5d87686ca4b7  running        z1  10.0.1.20
storm-workers/460a2a16-28f3-4c8f-9cec-6259470f52d8  running        z1  10.0.1.21
storm-workers/47ce2858-0cf2-472a-abf4-c62dd7da4332  running        z1  10.0.1.22
storm-workers/508d80f6-79fc-4270-8075-a3f12bb769f2  running        z1  10.0.1.67
storm-workers/54be2d45-0c0c-4b96-89e9-76159b99eb43  running        z1  10.0.1.23
storm-workers/5a2b34b9-0e73-4c17-816a-9cd93b0fdddb  running        z1  10.0.1.24
storm-workers/5c35db4d-effb-4086-86eb-b276f659afbe  running        z1  10.0.1.68
storm-workers/5c824ca8-0eb2-40c8-a601-ee8925301f67  running        z1  10.0.1.69
storm-workers/5f551106-2147-4936-88cb-fd77fca74774  running        z1  10.0.1.70
storm-workers/5fa68c1b-23c0-4fad-8413-4a9bc183facf  running        z1  10.0.1.25
storm-workers/60365918-0f0f-4108-8113-636d3bb24be7  running        z1  10.0.1.101
storm-workers/60feda1f-1aff-4053-9d0c-a300afd5c450  running        z1  10.0.1.71
storm-workers/61f98b1e-2dd4-4a7b-8db5-906dc7f91fbd  running        z1  10.0.1.26
storm-workers/63504bca-4946-4a73-ae94-c796590b0c0d  running        z1  10.0.1.72
storm-workers/6388be98-be90-4888-88b3-64cf8114dd98  running        z1  10.0.1.27
storm-workers/6605ed80-ea0f-48c3-b373-d1c6cef10437  running        z1  10.0.1.28
storm-workers/6980dd56-68a9-4ccc-9ce7-599b73dd401a  running        z1  10.0.1.29
storm-workers/6b705cff-5f41-432d-8685-7130faa92a92  running        z1  10.0.1.30
storm-workers/6f445301-a145-4677-91f8-430952029458  running        z1  10.0.1.73
storm-workers/6f74b098-1f05-4095-9875-9fc072202bbc  running        z1  10.0.1.31
storm-workers/76f5b4c0-22ce-458b-99ca-4db70726d04f  running        z1  10.0.1.32
storm-workers/7f1a788f-c686-4293-b9db-f975b11987a1  running        z1  10.0.1.74
storm-workers/84fa5894-f438-4608-ac0b-a3b9f2d6c03f  running        z1  10.0.1.33
storm-workers/890b879a-1bf0-4dbb-9e55-b5f360f09567  running        z1  10.0.1.34
storm-workers/8e39ca72-4668-4689-87fb-020149fee2ae  running        z1  10.0.1.75
storm-workers/9611dabd-84c4-473e-8fc5-909b309c7a3d  running        z1  10.0.1.76
storm-workers/97dec8fb-e075-451f-b4b9-3cc6a7ba50f1  running        z1  10.0.1.35
storm-workers/9984a17e-633a-49fc-b49e-7930118212e1  running        z1  10.0.1.36
storm-workers/9b6c5661-0b2b-4c92-84af-9b0804880d8b  running        z1  10.0.1.77
storm-workers/9bbcf7f1-c3fd-4508-ba52-e7fa5c666961  running        z1  10.0.1.78
storm-workers/a005cbfc-4558-4353-8d61-a181755cd21b  running        z1  10.0.1.37
storm-workers/a680d32f-251f-43b1-bce8-ce14f4aa6875  running        z1  10.0.1.79
storm-workers/a932e157-f9da-4757-bd22-449bac79beae  running        z1  10.0.1.80
storm-workers/a9457e0b-1d46-43f4-a5f8-5e5e0f6fe73b  running        z1  10.0.1.81
storm-workers/a9ffcfa6-d3a9-4155-99b0-c57cba2bdad8  running        z1  10.0.1.82
storm-workers/aa777614-b306-40df-ba95-8262fc9278cb  running        z1  10.0.1.83
storm-workers/aaee289c-bb4f-4f3d-82cf-909a95116ae7  running        z1  10.0.1.38
storm-workers/ab4a5729-c1f6-471a-8a67-d61167f34ae7  running        z1  10.0.1.84
storm-workers/aefff130-1205-4e50-86de-b652722eb645  running        z1  10.0.1.4
storm-workers/b144772c-0702-40e6-8070-dfbac47adca1  running        z1  10.0.1.39
storm-workers/b66ea281-6705-4ec6-b5eb-d1667c943d2d  running        z1  10.0.1.40
storm-workers/b6d81f58-3d3f-481a-ab1a-2a369f973207  running        z1  10.0.1.41
storm-workers/b86f4d93-d7d8-42b3-b6ed-430a7f3de4a6  running        z1  10.0.1.85
storm-workers/bb83b13b-2bfa-4ca7-b4ac-30451246a493  running        z1  10.0.1.86
storm-workers/c0fe0a7b-22e2-4b0c-9a6b-a2ca14b89545  running        z1  10.0.1.87
storm-workers/c3791e89-544e-48c5-9955-5f538dd532f9  running        z1  10.0.1.88
storm-workers/c3e4ef40-66c4-4dd4-9808-1ef4cee451e2  running        z1  10.0.1.42
storm-workers/c6246836-56f3-46e1-afd4-985b421cde85  running        z1  10.0.1.43
storm-workers/c9634d5f-1503-45af-bb7f-14a4c2d7ce05  running        z1  10.0.1.89
storm-workers/cb7b6c75-c581-43d0-96a6-4ff241ac196e  running        z1  10.0.1.44
storm-workers/cc205ae0-b11a-4f6e-80c9-254eab2e4a56  running        z1  10.0.1.45
storm-workers/cdc96956-57e8-4a1a-ba7c-87a2fca4de16  running        z1  10.0.1.102
storm-workers/ce2f5d05-e989-44e1-b599-116e621cce10  running        z1  10.0.1.90
storm-workers/ceb33e8f-8a87-4d8e-b25f-b967711c8489  running        z1  10.0.1.91
storm-workers/d0cebb00-74c7-45df-affa-399330295de7  running        z1  10.0.1.46
storm-workers/d7853cda-5161-451a-af26-cd9757fd80c8  running        z1  10.0.1.47
storm-workers/d7b492ee-7657-4f65-8434-e17f7cbe1035  running        z1  10.0.1.92
storm-workers/de87cab5-fab8-497e-9b29-7359b3246792  running        z1  10.0.1.93
storm-workers/e497884c-e57d-420d-a7d6-5202f1611e8f  running        z1  10.0.1.94
storm-workers/e506a559-c03a-4d6a-91c4-a1c9bc46e2b8  running        z1  10.0.1.95
storm-workers/e61c5bd3-d37d-4fed-8d0b-c1f577bdbb19  running        z1  10.0.1.48
storm-workers/e6302b6d-22b5-4b1e-a541-b93211e7a79e  running        z1  10.0.1.49
storm-workers/e69121ae-0a15-45d6-9b77-3fa23a5e03ee  running        z1  10.0.1.96
storm-workers/e823047c-1c9c-4c25-b693-8b7cb52db3d5  running        z1  10.0.1.97
storm-workers/ea9211b6-2f13-4a96-bca1-2c2e02be1662  running        z1  10.0.1.98
storm-workers/eaa1f261-6e95-4d1b-a26d-09185208aa0c  running        z1  10.0.1.50
storm-workers/ec4aa7fb-d950-4ba1-94bd-5cf4be148a20  running        z1  10.0.1.99
storm-workers/ed194209-e517-41c8-b357-24a170a1b734  running        z1  10.0.1.51
storm-workers/ef9b1acd-2547-4c70-ab22-639eba25da7d  running        z1  10.0.1.52
storm-workers/f0199888-3d9f-4643-89a8-cb6ecb603aba  running        z1  10.0.1.53
storm-workers/f04f19f6-b141-4f79-b3e4-cd2ebfd9a051  running        z1  10.0.1.54
storm/2d73d1d5-84f4-49eb-b123-03d1dbe3667e          -              z1  10.0.1.5

99 instances

Succeeded
```

---
### 5- Open the Flood Gates
Since we are using [STORM mode](https://github.com/jamlo/jmeter-bosh-release#1--storm), we'll need to run a BOSH errand that will trigger all the JMeter&trade; workers. Run :
```
bosh run-errand -d jmeter storm --download-logs
```
in your terminal. This will create the errand VM that runs JMeter&trade; in client mode, distributes the JMX plan to all workers, waits for them to finish, aggregates the logs, and then download the tests result (including a statically generated dashboard) to your local machine.

---
### 6- Check the Results
After the errand has finished and downloaded the results onto your local machine, extract the tarball. You'll find all the test run logs, including the JTL file. This can be used to generate the corresponding metrics.

In-addition to the log files, a dashboard has also been generated. In the extracted directory, navigate to dashboard folder and double click `index.html`. You'll find detailed graphs for the test run result. An example is shown below.

{{< responsive-figure src="/images/jmeter-bosh-usecase/jmeter-bosh-usecase-1.png" >}}

---
### 7- Congrats
Congrats! You have just simulated 0.5 million users. Make sure to delete the deployment after the test run if you are not using it, or else the IAAS bill will be interesting.

## Notes
In our test, each thread will make an HTTP call every 5 seconds. If you want to lower that number, the number of threads per every JMeter instance needs to be lowered down, too.

**Note: Apache&trade;, Apache JMeter&trade;, and JMeter&trade; are trademarks of the Apache Software Foundation (ASF).**
