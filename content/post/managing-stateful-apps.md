---
authors:
- lhamel

categories:

date: 2018-12-06T17:16:22Z

draft: true

title: Managing Stateful Apps with the Operator Pattern; Orchestration Considerations

short: |
  Stateful Kubernetes apps can be managed with the Operator Pattern, and have other considerations regarding their orchestration; the forth blog of a series of 4 on Stateless Kubernetes Apps


---
(This blog is the fourth installment of a [four-part series](/post/stateful-apps-toc))

## The Operator Pattern

The [Operator Pattern](https://coreos.com/blog/introducing-operators.html) stipulates a process that is registered with the Kubernetes system layer, listening to Kubernetes system events with the responsibility to manage a particular set of resources. All the logic that initializes and maintains a service is thereby encapsulated into a Kubernetes deployment, which we'll call the "Operator" hereafter. 

This pattern aligns with many of the requirements for stateful apps, so the Operator Pattern is a popular implementation choice. 
An Operator is one way to orchestrate all the constituent pieces of a stateful app into a holistic service. 
An Operator can be called an orchestrator. 


## Recreating failed containers

When a constituent container is missing, Kubernetes may automatically attempt to 
recreate the container, depending on several factors. For example, the 
[StatefulSet resource](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/) typically 
specifies that Kubernetes will recreate any missing member of such a set. 
Alternatively, an orchestrator can monitor a deployment of pods to maintain the required set of containers. 

## Options for automation and self-healing

Given a constituent container has failed and been recreated automatically by Kubernetes, 
consider its effect on a stateful app. The service may also have failed as a result of the failed constituent. 
To the extent that the app guarantees [High Availability](https://en.wikipedia.org/wiki/High_availability) for 
the given failure case, automated recovery of the service is expected. The orchestrator must recognize the need to 
reintegrate the recreated container(s) into the overall service. (The very wide range of potential error cases presents 
a challenge to flawlessly recover without manual intervention.)

## Liveness and readiness probes offer orchestration options; DNS entries contingent on readiness

Given the need for a stateful app to orchestrate its components into a holistic service, 
a typical design for an orchestrator involves signalling to and from constituent containers to 
help move them into desired states. 

Kubernetes offers health probes that can be used for decentralized signalling, 
including "liveness" and "readiness" health probes.

First, basic Kubernetes definitions: a failed liveness probe will cause the container to be killed. 
A failed readiness probe will cause a container to stop handling requests for its declared service. 

Passing the readiness probe means the Kubernetes adds a DNS entry for the passing container, 
and vice-versa: failing the probe will omit or remove the DNS entry. Importantly, a "live-but-not-ready" container 
is still part of the network, but not addressable via DNS. 

One mechanism for decentralized discovery of constituent containers is for these containers to bring themselves up into 
a live-but-not-ready state, and announce themselves via some discovery mechanism. For example, upon creation, a container could 
add its IP address to a config map or other shared discovery location. Meanwhile, an orchestrator can monitor
changes to a config map with standard file-status monitoring tools. When all the containers 
that will constitute a service become available in a wait state, an orchestrator can 
manage initialization of the service.

{{< responsive-figure src="/images/operator-discovery.png" class="center" caption="Operator Discovery Cycle" >}}

## Starting with fewer features

Many stateful apps require complex orchestration to assemble various pieces into a single service. 
On "Day 1", this orchestration must stand up and integrate all the pieces that constitute a service. 
On "Day 2", this orchestration must upgrade, repair, and resize all the pieces that constitute the 
(already-started) service.

When developing a stateless app from scratch, consider putting off day-2 tasks in favor of starting small. 
Given manual intervention by administrators to help manage day-2 operations, 
a development team can postpone building those features to focus on making Day 1 work smoothly. 
For example, consider a typical day-2 task of upgrading, wherein an app release is upgraded. 
For a stateful app, an upgrade could easily mean a service outage. When users are given a choice 
between automated upgrades at unscheduled times, and manual upgrades with scheduling, 
users may choose to schedule. In that case, building out automated upgrading may be deprioritized.

[Stateful Apps, a 4-part series](/post/stateful-apps-toc)
