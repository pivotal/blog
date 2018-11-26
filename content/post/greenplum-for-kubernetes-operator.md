 ---
authors:
- gtadi
categories:
- Greenplum
- Kubernetes
- Agile
date: 2018-11-26T00:00:00Z
draft: false
short: |
  Enabling Declarative Style Greenplum Deployment in Kubernetes
title: Greenplum for Kubernetes Operator
---

# Greenplum for Kubernetes

Greenplum is an MPP (Massively Parallel Postgres) Database coordinating multiple postgres instances to support distributed transactions and data storage. Greenplum is well known as Online Analytics Platform (OLAP) database. This blog discusses provisioning, deploying, managing and tearing down Greenplum cluster at a large scale.

# Design Rationale

The greatest leaps Greenplum for Kubernetes team taken since its inception are:
- containerizing the Greenplum, and
- leveraging Kubernetes to manage these containers in any cloud

Leveraging Kubernetes to deploy Greenplum has taken few revisions to make it more cloud native and tolerant to real time errors.
Greenplum for Kubernetes initially leveraged bare pods (one pod per segment) with anti affinity rules to deploy each pod individually on each node with the help of bash scripts. However, this setup is not robust enough to handle container terminations.

When the team decided to move with statefulsets to handle some of those issues; then team created a design to use at least 3 statefulsets: master, primary segments and mirror segments. Also, Statefulsets are able to maintain compute and storage relationship. More about statefulsets: https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/

From users’ point of view:

- Why should user care about creating 3 statefulsets and managing them by themselves?
- Also, this is not a pure declarative style deployment of Greenplum

That provoked our thoughts and use “Operator pattern” which was initially from CoreOS. This can take away significant manual work and makes it easy to manage Greenplum cluster that users create. That’s how Operator for Greenplum for Kubernetes evolved.

# Greenplum for Kubernetes Operator
{{< responsive-figure src="/images/greenplum-for-kubernetes-operator/operator-blog.png" class="center" height="42" width="42">}}

## Workflow
Steps: 2-4 and 6-9 are behind the scenes steps

1. **Kubernetes Admin** requests a greenplum-operator deployment. This is a one-time deployment for a given Kubernetes cluster with appropriate permissions to be able to create Greenplum cluster in any namespace.
2. Greenplum operator pod is created after the request is processed
3. Operator pod registers Custom Resource Definition for Greenplum to Kubernetes Key Value store etcd
4. Operator starts the controller to handle requests that are requesting custom Resource kind `GreenplumCluster`
5. **Greenplum User** creates a manifest file fulfilling requirements and submit to kubernetes
6. Kubernetes verifies the definition with etcd. Returns error if Custom Resource definition is not found.
7. The informers in Kubernetes will save this request to a queue in custom controller created by operator
8. Controller processes queue one by one and requests scheduler to either `create` , `update` or `delete` a given Greenplum deployment.
9. Scheduler will process the request and creates statefulsets and oversees the whole pod creation process and their placement depending on the resource requirements specified in manifest file.

## Operator Advantages

- Operators perform CRUD operations on the apps deployed in Kubernetes. The following benefits help us using Kubernetes app with an operator.
- User only require to convert requirements to manifest file and submit to Kubernetes with `kubectl` command
- Operator can validate user input and notifies with proper error message. This enables users to experience declarative style deployment.
- Operators can update the status of the app during & after its deployment
- Operator is one time creation for a given cluster
- Updates are handled appropriately when user request an update for the existing deployment
- Operators can check for duplicate deployments
- Operators enable respective apps to be treated as Kubernetes native resources.

# References
1. https://coreos.com/operators/
2. http://greenplum-kubernetes.docs.pivotal.io
