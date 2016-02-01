---
authors:
- david
categories:
- Containers
- Docker
- Network Traffic Monitoring
- Logging & Metrics
date: 2016-01-29T14:51:37-05:00
draft: false
short: |
  How to capture and log internet traffic from programs using Docker containers.
title: Capturing Network Traffic With Docker Containers
---


## Software and Promises

When software makes a promise, engineers need a way to verify that the promise is kept. In modern
software engineering, the process of “promise checking” is performed with a __continuous integration__ (CI) system.
Our CI system is [Concourse](https://concourse.ci/):

{{< responsive-figure src="/images/network-monitoring/concourse.png" class="text-center" title="A CI Pipeline in Concourse" >}}

Whenever a change is made to the code base, a series of automated tests attempt to ensure that the
software is working as planned.

At [Pivotal Cloud Foundry](https://pivotal.io/platform) (PCF), we guarantee that when software is deployed
on our platform, the software works in an __air-gapped__ environment (i.e., one that is either not connected
or not meant to connect to the internet). In these situations we want to maintain a “no-access”
policy with respect to the outside of a PCF deployment:

{{< responsive-figure src="/images/network-monitoring/firewall.png" class="text-center" title="Non-Connected Networks">}}

This is a common use case in enterprise deployments. When a network is air-gapped, we want to guarantee that __no__
TCP/IP requests are directed to external networks. Even if the attempts fail due to firewalling or lack of
physical connection, making requests would almost certainly cause logging headaches for an
admin trying to maintain network integrity.


## Testing for Network Traffic

Testing this is not as trivial as it sounds. PCF is a multi-component deployment platform that
has a lot of moving parts:

{{< responsive-figure src="/images/network-monitoring/diego-architecture.png" class="text-center" title="The Place of Buildpacks in Cloud Foundry" >}}

As such, there is a lot of "safe" network traffic that is internal to PCF. To complicate matters,
applications are set up and scaled on Cloud Foundry using containers within virtual machines,
adding an additional layer of complexity.

__Buildpacks__ (see figure) are what provide runtime support for apps deployed in PCF containers.
Cloud Foundry automatically detects the language and (if applicable)
framework of an app's code. Buildpacks then combine the code with necessary compilers, interpreters, and other
dependencies.

For example, if an application is written in Java using the [Spring](https://spring.io/) framework, the
[Java Buildpack](https://github.com/cloudfoundry/java-buildpack) installs a Java Virtual
Machine, Spring, and any other dependencies that are needed. It also configures the app to work with
any services that are bound to it, such as databases.

So, how can we reliably test that our buildpacks, operating inside of Linux containers inside
virtual machines, which may or may not be running on top of cloud IaaS services, never have
external network traffic?


## IPtables and You

Our original solution was to operate a miniature version of an entire Cloud Foundry deployment.
We configured custom `iptables` rules in the virtual machine running Cloud Foundry. These iptables
rules determined which network packets were “safe” (or internal to the Cloud Foundry deployment)
and which were external. Unallowed packets were logged to a file using `rsyslog`, and our tests
searched for lines of text in the log file.

{{< responsive-figure src="/images/network-monitoring/iptables.png" class="text-center" title="Monitoring Network Traffic with iptables and rsyslog">}}

The problem with this solution is that it was __complex__ and prone to __unreliability__. There were
many breakage points because of the number of configuration steps. We also observed at
times some external packet traffic that was not reported. Our promise for an air-gapped
(or __cached__) buildpack is that *zero* network connections will be attempted. If we can’t
reliably monitor our network traffic, we can’t keep our promise.


## Network Traffic Tests in Docker

Recently, we came across a simpler, more robust method for detecting network traffic
in our cached buildpacks. Enter Docker!

{{< responsive-figure src="/images/network-monitoring/docker.png" class="text-center" title="Everyone's Favorite Containerization Technology" >}}

Docker is a wrapper around Linux __containers__. Containers are userspaces that coexist
within a single kernel. Containers look and feel (mostly!) like their “own machines,”
but with a fraction of the resource cost needed to spin up entire virtual machines.

At its core, Docker (and containerization) is about resource isolation. Containers share
the same storage, memory, and network as the host kernel, but are logically separated from one another:

{{< responsive-figure src="/images/network-monitoring/containers.png" class="text-center" title="Containers in Linux">}}

This logical separation is useful for spinning up virtual servers and deploying applications. Cloud Foundry
itself uses a containerization system called
[Garden](https://blog.pivotal.io/pivotal-cloud-foundry/features/cloud-foundry-container-technology-a-garden-overview)
to create containers that run deployed apps.

So, Cloud Foundry deploys apps within containers using buildpacks, and we want to know if the buildpacks
are emitting network traffic. Instead of trying to log at the level of the physical or virtual machines,
why not execute a buildpack on a sample app inside a Docker container?

There is a common Unix utility called `tcpdump` that outputs a log of all packets transmitted
on a given machine. Could we just run tcpdump in the background to report on packets detected
in the container?

The answer is a resounding yes! We have successfully replaced all network traffic tests in our CI
with a script that generates a Dockerfile on the fly, then executes a `docker build` command to run
our buildpack inside a container alongside tcpdump. The file looks something like this:

~~~docker
FROM cloudfoundry/cflinuxfs2 # Cloud Foundry filesystem

ADD <application path> /app
ADD <buildpack path> /buildpack

RUN (sudo tcpdump -n -i eth0 not udp port 53 and ip -c 1 -t | sed -e 's/^[^$]/internet traffic: /' 2>&1 &) \
&& <buildpack execution commands>
~~~

For example, if you run `docker build .` with the Dockerfile:

~~~docker
FROM cloudfoundry/cflinuxfs2

RUN (sudo tcpdump -n -i eth0 not udp port 53 and ip -c 1 -t | sed -e 's/^[^$]/internet traffic: /' 2>&1 &) \
&& curl https://www.google.com/ \
&& sleep 5
~~~

Then you get the following output:

```
Sending build context to Docker daemon 970 kB
. . .
1 packet captured
. . .
internet traffic: P 173.194.121.49.443 > 172.17.4.44.38888 . . .
```

So there it is! Our original solution was a complex `iptables` configuration and syslogging on a virtual machine running PCF.
In our new solution, we reduced this to a *single Docker build command*. This operation is entirely modular and reproducible
on any environment, not just a PCF deployment.

In software engineering, we attempt to __minimize the complexity__ of solutions. Simpler solutions are (usually!) more robust,
and there is also a huge cost in understanding and debugging complex systems. Here we took what was originally a
complex approach to network traffic monitoring, and instead used containerization with Docker to make that monitoring
more simple and robust. If you’d like to examine the solution in detail, feel free to check out the
[full implementation](https://github.com/cloudfoundry/machete/blob/master/lib/machete/matchers/app_has_internet_traffic.rb)!
