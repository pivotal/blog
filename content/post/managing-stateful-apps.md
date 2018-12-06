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

title: Managing Stateful Apps with the Operator Pattern; Orchestration Considerations

short: |
  Managing stateful apps with the Operator Pattern, and other orchestration considerations, part 4 of a 4-part series on Stateless Kubernetes Apps


---
## Managing stateful apps with the Operator Pattern; Orchestration Considerations

### The Operator Pattern

The [Operator Pattern](https://coreos.com/blog/introducing-operators.html) stipulates a process that is registered with the Kubernetes system layer, listening to Kubernetes system events with the responsibility to manage a particular set of resources. All the logic that initializes and maintains a service is thereby encapsulated into a Kubernetes deployment, which we'll call the "Operator" hereafter. 

This pattern aligns with many of the requirements for stateful apps, so the Operator Pattern is a popular implementation choice. An Operator is one way to orchestrate all the constituent pieces of a stateful app into a holistic service. An Operator can more generally be called an orchestrator. 


### Recreating failed containers

When a container fails or is otherwise determined to be missing, Kubernetes may automatically attempt to recreate the container, depending on several factors. For example, the [StatefulSet resource](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/) typically requires that Kubernetes recreates any missing member of such a set. Alternatively, an orchestrator can monitor a deployment of pods to maintain the required set of containers. 


### Options for automation and self-healing

Given a container has failed and been recreated, consider its effect on a stateful app. The service may also have failed, or not. To the extent that the app guarantees [High Availability](https://en.wikipedia.org/wiki/High_availability) for the failure case, automated recovery of the service is expected. However, the wide range of potential error cases presents a challenge to cover entirely without manual intervention.


### Liveness and readiness probes offer orchestration options; DNS entries contingent on readiness

Kubernetes offers both "liveness" and "readiness" health probes, which offer an excellent mechanism for orchestrating a service, but with important caveats. 

First, basic Kubernetes definitions: a failed liveness probe will cause the container to be killed. A failed readiness probe will cause a container to stop handling requests for a given service. 

Given the need for a stateful app to orchestrate its components into a holistic service, a typical design for a stateful app involves containers bringing themselves up into a "live-but-not-ready" state. When all the containers that will constitute a service become available in this wait state, an orchestrator can manage initialization of the service.

However, failing the readiness criteria means the Kubernetes will remove the DNS entry for the container, and vice-versa. An unready container is still part of the network, but not addressable via DNS. 

Thus, an orchestrator that is based on network communication can interact with unready containers, but they must address those containers with IP addresses, not with DNS addresses. To facilitate this, a container could, for example, add its IP address to a config map or other shared discovery location. The orchestrator would communicate with constituent containers to move them into the ready state.


### Starting with fewer features

Many stateful apps require complex orchestration to assemble various pieces into a single service. On "Day 1", this orchestration must stand up and integrate all the pieces that constitute a service. On "Day 2", this orchestration must upgrade, repair, and resize all the pieces that constitute the (already-started) service.

When developing a stateless app from scratch, consider putting off day-2 tasks in favor of starting small. Given manual intervention by administrators to help manage day-2 operations, a development team can postpone building those features to focus on making Day 1 work smoothly. For example, consider a typical day-2 task of upgrading, wherein an app release is upgraded. For a stateful app, an upgrade could easily mean a service outage. When users are given a choice between automated upgrades at unscheduled times, and manual upgrades with scheduling, users may choose to schedule. In that case, building out automated upgrading may be deprioritized.

[Stateful Apps, a 4-part series](stateful-apps-toc.md)
