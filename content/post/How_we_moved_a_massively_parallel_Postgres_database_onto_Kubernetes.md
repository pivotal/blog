---
authors:
- obasarir
categories:
- Greenplum
- Kubernetes
- PostgreSQL
- Databases


date: 2019-03-14T12:30:00Z
draft: false
short: |
  Distributed applications that scale out, such as Greenplum, fit well with Kubernetes.
title: How we moved a massively parallel Postgres database onto Kubernetes

---
If you’ve ever wondered what type of applications are the best candidates to run on Kubernetes, distributed applications 
that scale out, such as Greenplum, are certainly at the top of the list, as we’ve discovered.

Our project started in late 2017 as an investigation of how Greenplum can best benefit from containers and a container management platform such as Kubernetes. At that point, Greenplum already had containers (see [PL/Container](https://gpdb.docs.pivotal.io/latest/ref_guide/extensions/pl_container.html)) triggered by SQL queries with UDFs (user defined functions). These containers were, and still are, useful in isolating the functions and managing resources in a more granular and precise manner. Our next step was to move all of Greenplum into containers. Would this be an unnatural act, an okay solution that could be considered “lifting and shifting” of a legacy application, or a joining of two technologies that fit like hand in glove?

In our exploration, first, we packaged Greenplum in a container to run it in that single container. It was certainly not a workable solution, but a step in the right direction to test out and learn about how isolation, resource management, and storage work in this environment. One important point to note here is that containers are not a new technology that introduces another layer between the executing code and the hardware. Rather, containers simply use basic Linux kernel constructs such as [cgroups](https://en.wikipedia.org/wiki/Cgroups), namespaces, and chroot that have been added to the kernel over the last four decades. 


{{< responsive-figure src="/images/gp4k/k8s_intro.png" class="center" caption="Kubernetes Intro" >}}


At runtime, your application code that is running in a container is as close to the hardware as any piece of code that is not inside a container. This should not be confused with the abstraction created by the layers of images used to package containers to make them portable, because that’s not a runtime concern. Therefore, you still get bare-metal performance from code that executes inside a container. And, if you want to layer in VMs for the benefits that VMs provide, that also is possible and your code runs as efficiently on VMs inside a container as it does on VMs directly. 

After we tinkered with running Greenplum in a single container, we realized that this was not the ideal mapping for Greenplum in containers. Since Greenplum is an MPP (Massively Parallel Processing/Postgres) system, we needed to, at the very least, spread the cluster across many containers and somehow get these containers to know about each other and work together. That’s when Kubernetes came into focus.  

Kubernetes is the open source container management platform that allowed us to break Greenplum out of a single container and run it as a truly distributed scale-out database. Kubernetes orchestrates groups of containers called pods. A pod can have one or more containers that can share storage. In our case, the storage was set up as PVs (persistent volumes) and these PVs can be either local or remote depending on the storage class chosen by the user. 

Again, the containers that make up a pod are just runtime constructs created by using the Linux kernel. Kubernetes orchestrates the pods via its scheduler by choosing a worker node for each pod to run on. A Kubernetes cluster also has master nodes where the scheduler and other administrative functions live. We assisted Kubernetes in making the scheduling decision by specifying (anti)affinity rules and node selectors, which are a simplified form of such rules. If in the future we need more complex logic, Kubernetes also allows us to define our own custom scheduler.  

For our containers, we also defined CPU & memory bounds, called requests and limits in Kubernetes. The available resources on the worker nodes are then handled by the Linux kernel feature cgroups under the hood.

Kubernetes provided a great platform for Greenplum by allowing us to create clear boundaries between compute and storage, by letting us distribute the compute across a cluster with precise controls, and by giving us the knobs for management of resources.

Greenplum, in turn, turned out to be a great tenant for Kubernetes because it distributed user data across its cluster and processed SQL and PL queries on these data in parallel. Let’s take a quick look at Greenplum’s architecture. It has a master, a standby master, a number of primary segments and their mirror segments. Each of these is a Postgres database instance along with a number of libraries and tools for AI/Machine Learning, Graph, Text analytics, etc. 


{{< responsive-figure src="/images/gp4k/gpdb.png" class="center" caption="Greenplum" >}}


When a query is received, the master creates a plan that distributes the execution across the primary segments, allowing Greenplum to return results in a fraction of the time. The more primary segments and the more parallelized your data, the faster your analysis. 

With this distributed, scale-out architecture of Greenplum, when compute and/or storage resources need to be increased, we can do so by simply adding more segments. Similarly, on Kubernetes, an application can increase capacity by increasing the number of pods. This was an obvious one-to-one mapping between the atomic units of Greenplum and Kubernetes: a Greenplum segment mapped to a Kubernetes pod. 


{{< responsive-figure src="/images/gp4k/map_pod_to_segment.png" class="center" caption="Map pod to segment" >}}


It was primarily this relationship in the distributed nature of Greenplum and Kubernetes which made for a strong architectural fit. So, seeing this, we were able to move Greenplum out of a single container and onto a highly available, Linux-kernel-based container orchestrator and run the same exact Greenplum database to provide the same exact user experience. The overall solution, as it turned out, had a number of additional benefits. 

One such benefit was the Operator Pattern, which was the way Kubernetes allowed for adding custom logic to control an application. This meant that we could build a Greenplum operator, a first-class citizen of Kubernetes, and use this operator to automate day-1 and day-2 operations such as deployment, failover, expansion, and upgrades and patching of not just Greenplum but a whole set of related tools and components altogether. 

We should note though that automated upgrades and patching doesn’t mean 0-downtime rolling upgrades; rather, it means that during a scheduled maintenance window, the human operator can perform an upgrade by simply triggering the Greenplum operator to take all the necessary steps, preserving state and data of the database in the process.

Another big benefit was that we could handle application and library dependency management in our CI pipelines so that the customers didn’t have to. Greenplum and its rich ecosystem could now be tested for security, configuration, integration, networking as well as dependencies and then released in one package ready to create a new Greenplum workbench or upgrade from an existing one. Of course, the user could still customize which components to enable and how.



There was one caveat though. The performance was only as good as the underlying hardware. Just as with bare-metal deployments, our hardware needed to provide adequate CPU, memory, disk IO, network IO for the pods. Kubernetes couldn’t magically make Greenplum fly. And building the right infrastructure for Kubernetes, especially if we were going to run a database on it, was not straightforward. This area remains a challenge for us and for the larger Kubernetes community. We have seen deployments of stateless applications in production environments, but databases are relatively new to this scene. 

Nevertheless, our investigation brought us to a place where we see tremendous opportunity and benefits from running an MPP database such as Greenplum on Kubernetes. We evaluated whether this would be an unnatural act, an okay solution that could be considered “lifting and shifting” of a legacy application, or bring together two technologies that fit like hand in glove. And, we strongly believe that massively parallel Postgres databases and Kubernetes fit like hand in glove.


For more on this topic, see Pivotal Engineering Journal articles by our team:

- [Managing Stateful Apps with the Operator Pattern; Orchestration Considerations](http://pivotal-cf-blog-staging.cfapps.io/post/managing-stateful-apps/)
- [Storing Stateful Data that Outlives a Container or a Cluster; Optimizing for Local Volumes](http://pivotal-cf-blog-staging.cfapps.io/post/storing-stateful-data/)
- [Provisioning Stateful Kubernetes Containers that Work Hard and Stay Alive](http://pivotal-cf-blog-staging.cfapps.io/post/provisioning-stateful-kube-containers/)
- [Stateful Apps in Kubernetes](http://pivotal-cf-blog-staging.cfapps.io/post/stateful-apps-toc/)
- [Greenplum for Kubernetes Operator](http://pivotal-cf-blog-staging.cfapps.io/post/greenplum-for-kubernetes-operator/)
- [Development of Greenplum for Kubernetes using Minikube](http://pivotal-cf-blog-staging.cfapps.io/post/rapid-development-using-minikube/)
