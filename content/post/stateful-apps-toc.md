---
authors:
- lhamel

categories:

date: 2018-12-06T17:16:22Z

draft: false

title: Stateful Apps in Kubernetes

short: |
  Defining stateful versus stateless applications in terms of Kubernetes service resiliency. The first blog post of a series of four about Stateful Kubernetes Apps.

---

Kubernetes is available across all public clouds nowadays, including Pivotal's own [PKS](https://pivotal.io/platform/pivotal-container-service), which runs in the cloud and can also be run "on prem", on the premises of an enterprise. Kubernetes promises to run any workload, including stateless and stateful applications.

A typical distinction between two types of Kubernetes apps–between stateless and stateful apps–is based on the manner in which data within the app is saved. However, for this discussion of Kubernetes apps, let's adopt a definition of stateless/stateful that classifies apps by the resilience of their service. Services provided by **stateless** apps can be easily managed with a pool of containers that, together, deliver a redundant, resilient service. Removing a portion of the containers will not interrupt the ongoing delivery of the stateless app's service.

{{< responsive-figure src="/images/stateless-cluster-resilient.png" class="center" caption="Defining a Stateless App by Its Resilience" >}}

Within this discussion, **stateful** apps are those apps that require context such that the service provided by the stateful app cannot be continuously sustained when an arbitrary container is removed. Redundancy of certain key containers is not possible.

{{< responsive-figure src="/images/stateful-cluster-breaks.png" class="center" caption="Defining a Stateful App by Its Susceptibility to Failure" >}}

One example of a stateful app is a database that stores its data on a particular volume, where that volume cannot be shared for some reason. Another example might be a legacy app that, while capable of being refactored to be stateless in the future, is undergoing a "lift and shift" port into Kubernetes before it is refactored to be stateless.

The vast majority of Kubernetes literature is written for stateless apps. Stateless apps are in the "sweet spot" for Kubernetes operational expectations and its optimizations. Meanwhile, designing and building an app that keeps state can be a challenge, with many fewer examples in the literature.

What are some of the most important considerations for developing and running stateful apps in Kubernetes? What expectations of Kubernetes operational patterns must be modified?

Subsequent posts in this series of blogs about Stateful Apps in Kubernetes focus on topics that may require special attention for stateful apps:

*   [Provisioning Stateful Kubernetes Containers that Work Hard and Stay Alive](/post/provisioning-stateful-kube-containers)
*   [Storing Stateful Data that Outlives a Container or a Cluster; Optimizing for Local Volumes](/post/storing-stateful-data)
*   [Managing Stateful Apps with the Operator Pattern; Orchestration Considerations](/post/managing-stateful-apps)
