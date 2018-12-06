---
authors:
- lhamel

categories:
- Kubernetes
- Greenplum
- Databases
- Stateful Apps
- Stateless Apps
- Pivotal Container Service (PKS)

date: 2018-12-06T17:16:22Z

draft: true

title: Provisioning Stateful Kubernetes Containers that Work Hard and Stay Alive

short: |
  How to configure and create Kubernetes containers that resist getting evicted, part 2 of a 4-part series on Stateless Kubernetes Apps

---

## Provisioning Stateful Kubernetes Containers that Work Hard and Stay Alive

### By default, all containers are free from limits but subject to eviction

By default, Kubernetes places very few limits on a container. A default, "best effort" container can take as many resources as it needs until the Kubernetes system decides that the container should be evicted, typically because memory or storage have become scarce.

Each container runs within a virtual machine (VM) which is called a "node". By sharing all the resources of a node, best-effort containers have several advantages:

*   Containers can sustain a burst of service, expanding their resource usage as needed, particularly for short-term spikes
*   Resources on the node are not reserved for idle containers
*   Containers that have gotten into trouble with unexpected resource problems, such as infinite loops or memory leaks, will be automatically evicted
*   Containers that have been evicted may be automatically restarted (if they have a  restartable specification and resources permit)

This default configuration for resource contention implies that the eviction of a given container is no big deal. This assumption that is generally true for a stateless app, in which many containers may share the service load. However, for stateful apps, container eviction could cause some disruption in service.


### How containers are monitored, and where to find evidence of evictions

There are at least two concurrent systems for monitoring the resource usage of containers in Kubernetes. One is the [Kubernetes kubelet monitor](https://kubernetes.io/docs/tasks/administer-cluster/out-of-resource/#eviction-monitoring-interval) which observes whether containers are exceeding their stated limits. Another is the Linux [Out-of-memory (OOM) killer](https://kubernetes.io/docs/tasks/administer-cluster/out-of-resource/#node-oom-behavior) which runs on each node, watching the RAM available on that node. Fundamentally, these monitors are protecting the liveliness of the node and its Kubernetes system functions.

After evicting a container, the **Kubelet** monitor generally provides info about the eviction within the status of a cluster, such as when queried with _kubectl get pods_. For example, restartable containers will restart after eviction and will have a non-zero number in the column "Restarts". Containers that cannot be restarted after eviction by kubelet are left in an error state in the column "Status". 

To see eviction in action, see [a sample](https://kubernetes.io/docs/tasks/configure-pod-container/assign-memory-resource/#exceed-a-container-s-memory-limit) from Kubernetes documentation that demonstrates a simple container that gets evicted. This eviction by the kubelet monitor results from the sample container exceeding its stated memory limits. Importantly, this sample overage does not threaten the system containers on the node--there is still plenty of memory on the node to run Kubernetes. Thus, in this sample, the kubelet monitor has sufficient memory and CPU to do its job; the node itself is not under pressure.

The **Linux OOM Killer**, on the other hand, gets invoked when the node itself is starved for memory. In that situation, Kubernetes system containers, which control Kubernetes system logging, may be threatened and may not function as designed. Thus, there may not be much evidence of the Linux OOM killer in Kubernetes status reports. Evictions by the OOM tool may only show up in the syslog of a given node. To access that information, use the platform tools (_gcloud_ on GKE, _bosh_ on PKS) to obtain a shell on the node.


### Setting limits on containers helps increase their priority, but does not prevent eviction

Kubernetes literature emphasizes how a developer can set a container's [requested resources and its limits](https://github.com/kubernetes/community/blob/master/contributors/design-proposals/node/resource-qos.md#qos-classes) inside the pod definition. These limits are not maintained in a benevolent way. Resource limits help the optimistic scheduling of containers onto nodes, but the limits also serve as explicit thresholds for eviction:

"[A Container can exceed its memory request if the Node has memory available. But a Container is not allowed to use more than its memory limit. If a Container allocates more memory than its limit, the Container becomes a candidate for termination.](https://kubernetes.io/docs/tasks/configure-pod-container/assign-memory-resource/#specify-a-memory-request-and-a-memory-limit)"

Kubernetes has [an algorithm](https://kubernetes.io/docs/tasks/administer-cluster/out-of-resource/#evicting-end-user-pods) for deciding the order in which containers will be evicted when the node becomes threatened with CPU/RAM/disk starvation. This algorithm favors a "guaranteed" container, which means **all** resources have a stated "limit" amount that equals the "request" amount, versus a "burstable" container with a request that is lower than its limit. The order of eviction is: 

*   best-effort
*   burstable
*   guaranteed

In order to be the last to be evicted, a container must state limits for CPU and memory, and either state requests equal to those limits, or no request (so that implicitly, the requests are set to the limits). These requirements then qualify the container as a "guaranteed" container, the last to be evicted for resource issues (assuming that the container itself is well-behaved, staying inside those limits).


### Noisy neighbors, controlling the neighborhood

How can stateful containers be protected against eviction when neighbors are using lots of resources?

First, consider the neighborhood, consisting of all the containers that can be scheduled on a worker node. The Kubernetes _kubelet_ bases its decisions about eviction based on the metrics at the node level. Thus, containers on a node are at the mercy of "noisy" neighbors. If a stateful container must stay alive, it is best to deploy it into a predictably quiet neighborhood. One simple way to do this is to have no or few neighbors, to run a stateful app on a dedicated cluster.

The idea of a dedicated cluster seems to go against one of the design goals of Kubernetes, which is to optimize resource usage. Kubernetes was designed to share node resources optimally. A typical Kubernetes system stretches to handle spikes in a particular app while, given sufficient container redundancy on multiple nodes, other apps are not harmed in terms of service availability.

Stateful apps need different priorities. When operating a stateful app, resources may need to be allocated more statically in order to preserve the stateful app's service availability.

In addition to considering a heterogeneous neighborhood, consider the stateful app's containers as neighbors themselves. How can one of the app's containers be protected against the others within the same app, that might take up its resources? One way is to dedicate a node per container, or at least carefully determine a topology where multiple containers can run within the same node. The topology of one node per container is simple to describe and may help with provisioning for high availability. 


**In summary, for the easiest configuration to assure a stateful app's performance and protection, dedicate the cluster to single-tenant, and dedicate a node per single stateful container. That way, each node can be tuned for the single purpose of running the stateful app. More complex topologies are possible. Start as simply as possible.**


### Node capacity

To determine the largest amount of resources available to any pod on a node, two key metrics are available: a node's "capacity" and its "allocatable" attribute, as shown in the following sample output, querying a Minikube instance that was given 4Gb to start with:

**kubectl get nodes -o json**

```yaml
...

"allocatable": {
    "cpu": "4",
    "ephemeral-storage": "15564179840",
    "hugepages-2Mi": "0",
    "memory": "3934296Ki",
    "pods": "110"
},
"capacity": {
    "cpu": "4",
    "ephemeral-storage": "16888216Ki",
    "hugepages-2Mi": "0",
    "memory": "4036696Ki",
    "pods": "110"
},

...
```

In this output, "capacity" reflects the entire allotment given to Minikube, while "allocatable" is a [calculation after system pods are running](https://kubernetes.io/docs/tasks/administer-cluster/reserve-compute-resources/#node-allocatable). In Kubernetes 1.12, the pod scheduler protects the system's resources (i.e., the non-allocatable portion). 

A sample bash script can parse this memory capacity on a node: 

```bash
mem_cap_string=$(kubectl get nodes -o jsonpath='{.items[0].status.capacity.memory}')
mem_cap_int=$(echo ${mem_cap_string} | sed 's/[^0-9]*//g')
mem_units=$(echo ${mem_cap_string} | sed 's/[^A-z]*//g')
```

This "mem_cap_int" value can be used as an upper bound for total container resources within the node.


### Limits managed within the app itself

Even with the recommendations above, including a dedicated cluster, dedicated nodes, and LimitRanges that guarantee eviction last, a container can be evicted because of resource usage beyond stated limits. How can a stateful app assure that its containers are "well behaved" and stay within their limits?

**An app must manage its own resource usage internally, particularly with regard to the measure that commonly causes eviction: memory.**


### _cgroups_ to enforce limits: best choice for CPU

One tool for an app to self-limit its resource usage is to enforce limits using Linux _cgroups_. [cgroups](https://en.wikipedia.org/wiki/Cgroups) are part of the Linux kernel. A cgroup setting can kill processes that go over, for example, memory limits, or can throttle processes to a maximum CPU usage. If an app manages _cgroups_ for all the child processes it creates, the app has a chance to successfully stay within the limits of the app's declared resource usage. 

However, _cgroups_ are not gentle for memory or disk space. Any child process that goes over a memory or disk space quota will be terminated by the cgroup without graceful notification. So cgroups for memory management require the app to forgive traumatic termination of child processes.

_cgroups_ are extremely useful for CPU throttling of child processes because this involves a simple manipulation of CPU allocation, not a traumatic termination of the process. According to dynamic business conditions, an app could use CPU cgroups to dial up and down the CPU usage of existing child processes.

Getting access to _cgroups_ is a challenge for containers, one that includes, in Kubernetes 1.10, a remapping of the node's /sys/fs/cgroup file system and various configurations. 


### Additional strategies for managing resources within an app

Having established the overall picture of resources, in particular how to maximize an app's usage of the capacity available within a node, the responsibility of resource management falls upon the app itself, to be well-behaved within its guaranteed limits. Assuming the app has an architecture wherein a parent process spawns child processes for each request, that app's responsibilities include:



*   determining the percentage of memory and disk resources that are allocated to the parent process
*   ensuring that the parent process does not exceed these limits
*   determining the number of child processes that can run in parallel, within the resources remaining after the parent process
*   ensuring that each child process stays within some limit
*   denying or pending requests for new child processes when the maximum number of parallel child processes are already running

That list of responsibilities starts to sound like a resource management framework, of which Kubernetes itself is one. This points up the obvious: if any stateful app can be re-architected to become stateless, resource management can be outsourced to Kubernetes. Otherwise, a stateful app must devote a significant amount of logic to managing resource allocation.

[Stateful Apps, a 4-part series](stateful-apps-toc.md)
