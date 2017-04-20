---
authors:
- stev
categories:
- Cloud Foundry
- CF
- BOSH
- Weave Scope
- Visualization
- Distributed Systems
date: 2017-04-12T10:51:52+01:00
short: This is the first of two blog posts showing you how Weave Scope, a visualization and troubleshooting tool originally aimed at Docker and Kubernetes, can be used to reveal the hosts and network topologies for arbitrary BOSH deployments. As such, Scope is able to visualize the many components that make up Cloud Foundry and the interplay between them. This gives everyone, from newcomers to seasoned experts, new ways to learn about Cloud Foundry and troubleshoot a running system if necessary.
title: Visualizing Cloud Foundry with Weave Scope - Part 1
---
<style>
.twitter-tweet-rendered {
  padding: 20px;
  display:block;
  margin-left:auto;
  margin-right:auto;
}

pre {
  margin:20px;
}

figure {
  margin:20px;
}

figcaption {
  font-size:14px;
}

.post-summary {
  line-height:30px;
}
</style>

Using Cloud Foundry to deploy an application to the cloud is a really simple affair: `cf push my-app` and you are done.

{{< tweet 598235841635360768 >}}

But what happens behind the curtain? Cloud Foundry is actually a pretty complex distributed system. Trying to understand the many components and how they work together presents a steep learning curve. Operators and anyone with an interest that goes beyond deploying an application have to build their mental model of the platform by looking at docs, logs, metrics, configuration files, or actual source code. Until now, there was nothing that would allow them to visualize and explore Cloud Foundry in a more interactive and graphical way. Weave Scope provides exactly that: a novel tool that can be used to reveal Cloud Foundry’s topology and the interplay between the different components of the platform. This gives everyone, from newcomers to seasoned experts, new ways to learn about Cloud Foundry and to troubleshoot a running system if necessary.

In this first of two blog posts, we will show you how we made Weave Scope, a tool originally aimed at Docker and Kubernetes, work happily alongside BOSH and Cloud Foundry. The second post will then introduce you to two plugins we wrote for  Weave Scope in order to visualize some Cloud Foundry-specific aspects. Before we dive in, though, you might want to check out [this demo](https://demo.scope.cf-app.com) to get a better idea of what Cloud Foundry looks like when visualized through Weave Scope.

---

## Cloud Foundry and BOSH
[Cloud Foundry](https://www.cloudfoundry.org) is a distributed system that consists of around 25 distinct services, each of which can be scaled to an arbitrary number of instances. A typical production deployment of Cloud Foundry might employ up to a few hundred instances in total, each running as a separate Virtual Machine (VM).

Most typically, Cloud Foundry is packaged, deployed, and monitored using [BOSH](https://www.bosh.io).

> BOSH is a project that unifies release engineering, deployment, and lifecycle management of small and large-scale cloud software. BOSH can provision and deploy software over hundreds of VMs. It also performs monitoring, failure recovery, and software updates with zero-to-minimal downtime. [[source](https://bosh.io/docs/about.html)]

In terms of monitoring, the BOSH CLI provides [several commands](https://bosh.io/docs/sysadmin-commands.html#health) to check the health of individual VMs and the state of the jobs they run.

{{< responsive-figure src="/images/visualizing-cloud-foundry-part-1/bosh-instances.png" caption="BOSH instances and their jobs" class="center" >}}

In case of problems with a particular VM or job, operators can use BOSH to [download logs](https://bosh.io/docs/sysadmin-commands.html#logs) from the affected host or [SSH into the VM](https://bosh.io/docs/sysadmin-commands.html#ssh) to debug further.

In addition to the tooling BOSH provides, Cloud Foundry itself gives operators access to a firehose of [near real-time metrics](https://docs.pivotal.io/pivotalcf/F1-10/loggregator/all_metrics.html) emitted by the different components of the system. Those metrics can be used to [populate dashboards](https://github.com/cloudfoundry-community/prometheus-boshrelease) and [trigger alerts](https://docs.pivotal.io/pivotalcf/1-10/monitoring/metrics.html) when certain thresholds are reached.

{{< responsive-figure src="/images/visualizing-cloud-foundry-part-1/grafana-dashboard.png" caption="Grafana dashboard displaying Cloud Foundry metrics" class="center" >}}

Arguably, BOSH and real-time metrics represent sufficient means of monitoring and debugging Cloud Foundry deployments. However, using these tools effectively requires a high level of pre-existing knowledge about the system. Operators have to be aware of the different components, how they work together, and the relevant metrics and potential issues.

As part of a recent hack day at Pivotal we looked at alternative approaches to monitor and troubleshoot Cloud Foundry. We were especially interested in ways of visualizing the topology of the overall system and allowing operators to explore the different components in a more graphical and interactive form.

Just after we started our investigation into different approaches and existing tools, it became clear that [Weave Scope](https://www.weave.works/products/weave-scope/) would offer most of what we were hoping for out-of-the-box. The only problem was that Scope is primarily aimed at applications running on top of [Kubernetes](https://kubernetes.io/), [Apache Mesos](https://mesos.apache.org/), or [Amazon ECS](https://aws.amazon.com/ecs/). At the time we looked at it, there was no easy way to use it with Cloud Foundry or any other BOSH-deployed system.

## Weave Scope BOSH Release

Fortunately, Scope’s architecture proved to be modular and easily extensible. There were no fundamental incompatibilities that would have prevented us from using this tool to visualize and monitor Cloud Foundry or other arbitrary BOSH deployments. All we had to do was create a [BOSH release](https://bosh.io/docs/release.html) for operators to deploy Scope alongside Cloud Foundry and have it work without requiring much configuration.

At its core, Scope consists of two components — the Scope App and the Scope Probe.

> The probe is responsible for gathering information about the host on which it is running. This information is sent to the app in the form of a report. The app processes reports from the probe into usable topologies, serving the UI, as well as pushing these topologies to the UI. [[source](https://www.weave.works/docs/scope/latest/how-it-works/)]

### Scope App Job

As a first step, we wanted to give operators a way to run the Scope App. We decided to do this by packaging the Scope binary inside a new BOSH release called [weave-scope-release](https://github.com/st3v/weave-scope-release) and creating a corresponding job named [scope_app](https://github.com/st3v/weave-scope-release/tree/master/jobs/scope_app). The sole purpose of this job is to start the App as follows:

~~~bash
./scope --mode=app --weave=false
~~~

Using weave-scope-release to deploy the Scope App is relatively straightforward. All it takes is a [BOSH manifest](https://bosh.io/docs/deployment-manifest.html) that defines a corresponding job, similar to the following.

~~~yaml
jobs:
- name: weave-scope-app
  instances: 1
  networks:
  - name: weave_scope_1
  resource_pool: weave_scope_z1
  persistent_disk: 1024
  templates:
  - release: weave-scope
    name: scope_app
    provides:
      weave_scope_app:
        as: weave_scope_app
        shared: true
~~~

Note that the example above defines a single instance of the Scope App job and declares that the instance should provide a so-called [BOSH link](https://bosh.io/docs/links.html) which exposes the instance’s IP and other connection details including a port.

A [sample manifest](https://github.com/st3v/weave-scope-release/blob/a165544bd3d6ac933fd0c08380222dcf8c48d7b8/manifests/bosh-lite/scope-app.yml) that can be used to deploy the Scope App to [BOSH Lite](https://bosh.io/docs/bosh-lite.html) can be found inside the weave-scope-release repo.

{{< responsive-figure src="/images/visualizing-cloud-foundry-part-1/deploy-scope-app.png" caption="Deploying the Scope App" class="center" >}}

Once the Scope App has been deployed, you can get its IP by issuing `bosh vms weave-scope`. When you point your web browser to this IP address and port 4040 (given you have not changed the default port in your manifest), you should see the Scope UI, but no actual content.

{{< responsive-figure src="/images/visualizing-cloud-foundry-part-1/scope-empty.png" class="center" >}}

### Scope Probe Add-on

As a next step, in order to visualize BOSH deployments inside the Scope App we had to get the Scope Probe running on all BOSH-deployed hosts. To do that we decided to create a second job inside weave-scope-release that starts the Probe as follows:

~~~bash
./scope --mode=probe \
        --probe.docker=false \
        --probe.kubernetes=false \
        --weave=false \
        --no-app \
        --probe.conntrack=false \
        --probe.plugins.root=${SCOPE_PLUGINS_ROOT} \
        ${SCOPE_APP_ADDRESS}
~~~

Called [scope_probe](https://github.com/st3v/weave-scope-release/tree/master/jobs/scope_probe), this job uses the same binary as the Scope App job. The binary supports a wide range of command line options. This makes both the App and the Probe highly customizable which helped us tremendously in coming up with a working prototype of our release within a single day. Using a subset of the available command-line options, the scope_probe job starts Scope in Probe mode, tells it not to collect Docker- and Kubernetes-related metrics, disables integrations with [conntrack](http://conntrack-tools.netfilter.org/) and [Weave Net](https://www.weave.works/products/weave-net/), and instructs the Probe to look for available plugins in a particular directory, something we will cover in more detail in the second blog post in this series. Once started, the Probe gathers reports about the host it is running on and sends them to the previously deployed Scope App.

After creating a BOSH job for the Scope Probe we had to ensure it would be colocated and executed on all hosts within any deployment that should be monitored. We achieved this by using add-ons, a BOSH feature that is configured through the so-called [runtime config](https://bosh.io/docs/runtime-config.html).

> The Director has a way to specify global configuration for all VMs in all deployments. The runtime config is a YAML file that defines IaaS agnostic configuration that applies to all deployments. …
> 
> An addon is a release job that is colocated on all VMs managed by the Director. [[source](https://bosh.io/docs/runtime-config.html#addons)]

The runtime config we ended up using defines a single add-on consisting of the previously created scope_probe job. As you can see in the example below, the add-on consumes the BOSH link provided by the Scope App to determine the IP to which to send reports.

~~~yaml
releases:
- name: weave-scope
  version: 0.0.10
addons:
- name: scope-probe
  jobs:
  - name: scope_probe
    release: weave-scope
    consumes:
      weave_scope_app:
        from: weave_scope_app
        deployment: weave-scope
~~~

The weave-scope-release repository contains a [sample runtime config](https://github.com/st3v/weave-scope-release/blob/cd5ddc5826c0db17b43d7b150a58fb6ab604f485/manifests/bosh-lite/runtime-config.yml) manifest that places the probe on all VMs across all deployments. To update the runtime config for a given BOSH Director one can use the [CLI command](https://bosh.io/docs/sysadmin-commands.html#cloud-config) `bosh update runtime-config`.

Once the runtime config has been updated, BOSH makes sure the Probe job is colocated as part of any subsequent deploy operation. That way, any new deployment will automatically show up in the Scope App. Deployments that already existed prior to this point will have to be re-deployed in order to place the Probe on the corresponding hosts.

After updating the runtime config and (re-)deploying Cloud Foundry the Scope App will show a graph representing the platform’s topology. The nodes in this graph represent hosts. Edges equate to active network connections between hosts.

{{< responsive-figure src="/images/visualizing-cloud-foundry-part-1/scope-cf-nodes.png" class="center" >}}

Clicking on any node in the graph will reveal more detailed information about a particular host. Amongst other details, this includes basic health stats like CPU and memory usage, a list of active in- and outbound connections, as well as a list of running processes. In addition, one can get easy remote access to the corresponding host.

{{< responsive-figure src="/images/visualizing-cloud-foundry-part-1/scope-host-remote-access.png" class="center" >}}

## What's next?

As shown in this blog post, it was relatively simple to come up with a BOSH release for Weave Scope that can be used to reveal the hosts and network topology of arbitrary BOSH deployments. This release demonstrates that Weave Scope, out-of-the-box, is super useful in visualizing and troubleshooting Cloud Foundry. But it could be even better. What if were able not only to show the hosts that make up Cloud Foundry but also the containers that represent the applications that have been deployed to the platform? This is what we will look at in the second blog post of this series. Stay tuned.

## Experimental Status

As mentioned before, weave-scope-release was implemented as part of a one-day hackathon event. As such, some of the implementation is rather naive and lacks both testing and proper documentation. The work presented here should be seen as a proof of concept, which depending on feedback and interest, might turn into a more robust and officially supported product at some point. **Until then, we do not recommend using this experimental release in a production environment.**
