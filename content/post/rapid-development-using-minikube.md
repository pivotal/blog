 ---
authors:
- xzhang
- gtadi
- dsharp
categories:
- Greenplum
- Kubernetes
- Agile
date: 2018-10-02T16:01:25Z
draft: false
short: |
  Speed up agile developing process using a minikube
title: Development of Greenplum for Kubernetes using Minikube
---

# TL;DR

Minikube is a single node Kubernetes environment designed for local development
with local Kubernetes (K8s) and Docker support. Because of its portable nature,
the development feedback cycle is faster with very minimum overhead.

# Greenplum for Kubernetes

Greenplum is a MPP (massively parallel processing) data warehousing database
management system based on PostgreSQL. An opinionated production-grade Greenplum
cluster can be deployed in Kubernetes faster than on bare metal.

The following resources are created when Greenplum cluster is deployed in K8s:

- **LoadBalancer** to expose Greenplum service
- **Pod** to host Greenplum segments
- **StatefulSet** to automatically restart failed segments
- **Helm** to package Greenplum deployment
- **New Custom Resource** to support declarative Greenplum cluster configuration
- **Operator Pattern** to create, delete, and maintain Greenplum clusters
- **Headless Service** to enable custom service discovery
- **Secrets** to store SSH and docker-registry secrets where the Greenplum image is hosted
- **Config Map** to record the current Greenplum cluster configuration
- **Persistent Volume** and  **Persistent Volume Claim** to store Greenplum database data
- **Storage Class** to provide different storage for best performance, cost, and available infrastructure
- **Resource Limits** to fine-tune Greenplum performance and manage resource consumption

# Agile practices

- TDD (test driven development)
- Full-time Pair Programming

Our development process encourages us to validate the Greenplum service at
various levels: e.g. unit testing, integration, multi-node deployment, and
performance benchmark.

With the increase in team size, docker image size (e.g. ~400MB), feature-set and
testing criteria, it started getting harder to create and manage Google
Kubernetes Engine (GKE) clusters. Also, it is expensive to use public cloud
infrastructure for our daily development tests.

So, we searched and found minikube, which works perfectly for minimal
functionality testing without any compromises. And it's Open Source!

# GKE Setup Requirements

We need following checklist in place to start developing any Kubernetes application on GKE:

- **Google Account** Each developer should have their own GCP account (their Google or G Suite account).
- **Google Project** A shared Google Project is required.
- **Turn on APIs** By default, required APIs are turned off. Make sure these APIs are turned ON before using `gcloud` cli to manage GKE clusters
- **Roles & Permissions** Certain IAM roles need to be assigned to the developer so that they can manage their own GKE clusters.
- **Wait...** After all this administration overhead, it takes ~5 min to set up a new cluster with 4 nodes.
- **Remote access K8s VMs** For debugging, use `gcloud ssh` or the web ssh to login to any K8s VMs.
- **Google Container Registry permission** Make sure each developer has proper permissions to push and pull images to and from Google Container Registry.

Given this overhead to setup environment, ramping up a new developer in the team
would take few days to understand different aspects for this configuration and
start up their first GKE cluster.

# Minikube Setup Requirements

Now, let's take a look at the minikube requirements. https://kubernetes.io/docs/tasks/tools/install-minikube/

- Virtualbox
- Minikube binary
- `kubectl` CLI tool

Usually, in 10min or so, a single-node K8s cluster should be ready.

# Minikube Benefits

These are few benefits we observed using minikube comparing to GKE.

## Save Money

A GKE cluster costs money to run. Usually, to save time on bring a cluster up
and down, we just leave the cluster running. Furthermore, to support multiple
developers with different stories, we keep multiple clusters for the whole day.
However, most time a cluster is idling doing nothing, but we are charged by the
VM backing the K8s cluster. If you forget to tear the cluster down before end of
the day, you will be charged overnight for zero usage. It requires good
stewardship to always clean after your use, and try to share clusters as much as
we can, but still avoid stepping on each other toes.

A minikube cluster is completely local. There is no extra cost aside from the
electricity to keep your workstation up and running. There is no worry of being
charged to just leave the cluster up. Also, there is no over-stepping among
multiple developers.

## Better Docker Support

To use a container image in a GKE cluster, first the image must be pushed to the
Google Container Registry (gcr.io). Our image is unfortunately around 400MB.
Pushing a huge container every time with image changes is a pain, especially for
remote workers on a slower home Internet connection. Docker's caching of lower
layers is not always sufficient to reduce this pain, since sometime we have to
change a lower layer.

One attempt to alleviate that pain was to use an ssh tunnel to access the Docker
daemon socket into the GKE cluster and build our Docker images from there.
However, GKE VMs are using an older version of Docker (17.03), which doesn't
support multi-stage Dockerfiles (17.05+).

Minikube can easily expose its Docker environment (`eval $(minikube
docker-env)`) and it got a modern Docker version (17.12). All the image building
is local, and there is no need to workaround the missing feature of multi-stage
Dockerfiles.

## Easier Reproduction

From time to time, we need to provide a reproduction environment to another team
to investigate issues we faced with that team's components. We tried to share a
GKE cluster with our reproduction. Not surprisingly, if the other team member
doesn't have GCP account, the sharing a `kubeconfig` is not enough for them to
connect to the cluster.

Instead, we created reproduction steps to use on minikube. They can easily bring
up a minikube cluster on their side and rerun the reproduction steps to quickly
get a ready-to-investigate cluster.

# Minikube Challenges

Since minikube is a single-node K8s cluster and disjoint from an IaaS backend,
the minikube environment presents challenges in a few corner scenarios.

## Local Persistent Volumes

As a distributed database management system, certain components like
fault-tolerance-service need to ensure the data is actually written to the
disk, rather than the cache. `O_DIRECT` flag is used in those scenarios.

However, minikube  [uses `tmpfs` to support local persistent volume]
(https://github.com/kubernetes/minikube/blob/master/docs/persistent_volumes.md).
This caused failures when using `O_DIRECT` to access to the underlying storage
system, since [`tmpfs` does not permit using `O_DIRECT`]
(https://lists.gt.net/linux/kernel/720702).

Because of this, unnecessary fail-overs will be triggered if we deploy Greenplum
with local persistent volumes on Minikube.

On the GKE cluster, since it's using a real file system rather than `tmpfs`,
they have no issue supporting `O_DIRECT`.

## Multiple Subnets

In a real multi-node environment, every K8s node gets its own subnet, hence
different pods might have different subnets. However, in a single-node
environment like minikube, all the pods share the same subnet.

This configuration hid a replication bug where the test passed on minikube
but failed on GKE.

In Postgres databases like Greenplum, Host Based Authentication is used to
permit access to the database. In Greenplum, this is configured on the master
node in a file named `pg_hba.conf`. A bug caused the system to put an incorrect
hostname value in `pg_hba.conf`. However, on minikube we didn't catch this bug,
because another line item in `pg_hba.conf` said to trust all replication
connections from the same subnet.

Please be cautious to use minikube to test your network related features. You
might be confused on why minikube and GKE exhibit different behaviors.

## Load Balancer with External IP

External IP addresses are an IaaS resource. A real load balancer will map an
external IP address to a pool of internal IP addresses, so that the traffic can
be redirected to online pods to give user a highly available service.

Greenplum requires a load balancer to direct client traffic to the active master
pod. However, we cannot test this feature locally on minikube, because [minikube
cannot get an external IP] (https://github.com/kubernetes/minikube/issues/2834).
It can only expose the `nodePort`. In this case, during master to standby
fail-over, the `nodePort` will be changed, hence the test will fail.

If a functional load balancer is a requirement, please consider using an
IaaS-backed K8s provider like GKE.

# A Typical Developing Process

This is a typical development process based on different environments.

## Minikube development process

```bash
# create/start cluster
minikube start
# expose docker environment
eval $(minikube docker-env)

# BEGIN iterations
  # build container image
  docker build
  # test it out
  helm install
  ...
# END iterations

# stop cluster
minikube stop
```

## GKE development process

```bash
# login to gcloud
gcloud auth login
# create a GKE cluster
gcloud container clusters create
# wait for few minutes for the cluster to create and start
# login to the GKE cluster
gcloud container clusters get-credentials

# BEGIN iterations
  # build container images locally
  docker build
  # push new container images to repo docker registry
  docker push
  # test it out
  # NOTE: the container images have to be downloaded to the GKE cluster nodes
  helm install
  ...
# END iterations

# delete cluster to save money
gcloud container clusters delete
```

# Conclusion
For local development, minikube is a rich enough environment to test a K8s
applications, even for a complicated stateful application like Greenplum, a
massively parallel processing data warehouse service.

However to verify the end-to-end experience with real storage and network
setups, GKE would be a better choice.
