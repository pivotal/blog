 ---
authors:
- gtadi
- xzhang
categories:
- Greenplum
- Kubernetes
- Agile
date: 2018-10-02T16:01:25Z
draft: true
short: |
  Speed up agile developing process using a minikube
title: Development of Greenplum for Kubernetes using Minikube
---

# TL;DR
Minikube is a single node kubernetes environment designed for local development with local K8s and docker support. Because of its portable nature, development feedback cycle is faster with very minimum overhead.

~~Minikube environment is with less up-front cost to start a k8s cluster to get faster feedback
for developing new Greenplum data services on top of K8s (Kubernetes).~~

# Greenplum for Kubernetes

Greenplum is a MPP (massive parallel processing) data warehousing database management system based on PostgreSQL. An opinionated production grade Greenplum cluster can be deployed in Kubernetes faster.

~~We use K8s to make an opinionated Greenplum deployment faster.~~
~~The following K8s resources are used to work together to bring Greenplum to K8s:~~

The following resources are created when Greenplum cluster is deployed in K8s:
- **LoadBalancer** to expose Greenplum service
- **Pod** to host Greenplum segments
- **StatefulSet** to automatically restart failed segments
- **Helm** to package Greenplum deployment
- **New Custom Resource** to support declarative Greenplum cluster configuration
- **Operator Pattern** to create, delete, and maintain Greenplum clusters
- **Headless Service** to enable custom service discovery
- **Secrets** to store SSH and docker-registry secrets where the Greenplum image hosted
- **Config Map** to record current Greenplum cluster configuration
- **Persistent Volume** and  **Persistent Volume Claim** to store Greenplum database data
- **Storage Class** to provide different storage for best performance and cost
- **Resource Limits** to fine tune Greenplum performance and manage resource consumption

# Agile practices

~~We follow strict TDD (test driven development) and full-time pair programming, which requires a running K8s cluster to~~

- TDD
- Full time Pair Programming

Development process requires validating Greenplum service at various levels.
e.g. unit testing, integration, multi-node deployment, and performance benchmark.

With the increase in team size, docker image size, feature-set and testing criteria; it started getting harder to spin and manage GKE clusters. Also, it is expensive to use infrastructure for our daily development tests.

So, we searched and found minikube, which works perfectly for minimal functionality testing without any compromises. And it's FREE!!

~~For local development, we need an environment to enable faster iteration. We started with GKE (Google Kubernetes Engine),
since it doesn't require any local setup, and we can just pay as we go. However, as we start to adding more and more
features to Greenplum, the number of clusters increased, and managing those clusters became a pain. Also, Greenplum
container images are around 400MB and just uploading those images became a bottleneck for rapid iterations. With that context, we are looking for a local developing environment, and we found minikube.~~

# GKE Setup Requirements
~~# What's GKE Requirements~~
~~Before we go into how minikube helped us to speed-up the development, let's see what are the extra steps a developer has to do in order to use a GKE cluster.~~

We need following checklist in place to start developing any Kubernetes application in GKE:

- **Google Account** Every developer should own a GCP account associated with an email.
 ~~Each developer has to apply a separate GCP (Google Cloud Platform) account from our admin.~~
- **Google Project** A shared Google Project is required.
- **Turn on APIs** By default, requied APIs are turned off. Make sure these APIs are turned ON before using `gcloud` cli to manage GKE clusters
~~Bunch of APIs need to turned on to enable `gcloud` CLI to manage GKE clusters from commandline.~~
- **Roles & Permissions** Certain IAM roles need to be assigned to the developer so that they can manage their own GKE clusters.
- **Wait...** After all this administration overhead, it takes ~5 min to set up a new cluster with 4 nodes.
- **Remote access K8s VMs** For debugging, use `gcloud ssh` to login to any K8s VMs ~~purpose, since it's on the cloud, the devs need to use gcloud supported `ssh` method.~~
- **Google Container Registry permission** Make sure each developer has proper permissions to push  and pull images to and from Google Container Registry.
~~since all the new code developer created will be baked into a container image, the K8s cluster has to have proper permission to access it.~~

Given this overhead to setup environment, ramping up a new developer in the team would take few days to understand different aspects for this configuration.

~~As you can see, if we want to ramp up a new developer, it will take days to just get first cluster ready.~~

# Minikube Setup Requirements
~~# What's Minikube Requirements~~
Now, let's take a look at the minikube requirement. https://kubernetes.io/docs/tasks/tools/install-minikube/

- Virtualbox
- Minikube binary
- `kubectl` CLI tool
Usually, in 10min or so, a K8s cluster should be ready.

# Minikube Benefits
~~# What's benefit of using minikube~~

These are few benefits we observed using minikube comparing to GKE.

## Save Money

A GKE cluster cost money to start. Usually, to save time on bring a cluster up and down, we just always leave the cluster there. Also, to support
multiple developers with different stories, we keep multiple clusters for the whole day. However, usually most time the cluster is pretty idling
doing nothing, but we charged by the VM backing the K8s cluster. Furthermore, if you forgot to tear the cluster down before end of the day, it charged
overnight for zero usage. It requires good stewardship to always clean after your use, and try to share clusters as much as we can, but still avoid
stepping on each other toes.

A minikube cluster is all local. There is no extra cost other than the electricity to keep your current workstation up and running. There is no worry of
being charged to just leave the cluster up. Also, there is no over-stepping among multiple developers.

## Better Docker Support

A GKE cluster is harder to expose its docker environment, and to update any container image, we need to push it to a remote registry. Our image is
unfortunately around 400MB. Pushing a huge container every time with image changes is a pain. Even the cached layered cannot help much, since sometime
we have to change a lower layer.

Also to build the container, GKE is using an older version of docker (17.03), which doesn't even support multi-stage Dockerfile (17.05+).

Minikube can easily expose its docker environment (`eval $(minikube docker-env)`) and it got a much newer docker version (17.12). All the image building
is local, and there is no workaround of lacking of support of multi-stage Dockerfile.

## Easier Repro

From time to time, we need to provide a repro environment to other team to investigate issues we faced. We tried to share a GKE cluster with our repro.
Not surprisingly, if the other team member doesn't have GPC account, the `kubeconfig` shared won't allow them to connect to the cluster with the repro.

Later on, we just create a repro steps using minikube, and just give them a repro based on minikube. They can easily bring up a minikube cluster on their
side and rerun the repro steps to quickly get a ready to investigate cluster.

# What's challenge of using minikube  

Since minikube is a single-node K8s cluster and also it's disjoint from an IaaS backend, the minikube environment facing challenges in few corner scenarios.

## Real Local Persistent Volume

The first challenge we are facing is minikube using tempfs to support local persistent volume. This caused failure in program need `O_DIRECT` access to
the underlying storage system. Please see https://github.com/kubernetes/minikube/blob/master/docs/persistent_volumes.md and https://lists.gt.net/linux/kernel/720702.

As a distributed database management system, certain components like fault-tolerance-service needs to ensure the data is actually written to the disk, other than
the cache. `O_DIRECT` flag is used in those scenarios.

Minikube gave us this challenge, and unnecessary failover will be triggered if we deploy Greenplum with local persistent volumes on Minikube.

However, on the GKE cluster, since it's using a real file system other than `tmpfs`, they have no issue support `O_DIRECT`.

## Multiple Subnets

In a real multi-node environment, every K8s node got its own subnet, hence different pods might have different subnet.
However, in a single-node environment like minikube, all the pods shared same subnet.

Such configuration hidden a replication bug where the test passed on minikube but failed on GKE.

On Greenplum master node, there is `pg_hba.conf` to specify what process from which host can access the master. The bug sets the `pg_hba.conf` with a wrong
hostname value. However, on minikube we didn't catch this bug, because another line item in `pg_hba.conf` said to trust all replication connections from the
same subset.

Please be cautious to use minikube to test your network related features. You might be confused on why minikube and GKE got different behaviors.

## Load Balancer with External IP

External IP is an IaaS resource. A real load balancer will map an external IP to a pool of internal IPs, so that the traffic can be redirected to online pods
to give user a highly available service.

Greenplum got same feature by providing master and standby nodes to clients through a load balancer. However, we cannot test this feature locally on minikube,
because minikube cannot get an external IP (https://github.com/kubernetes/minikube/issues/2834). It can only expose the nodePort. In this case, during master
to standby failover, the nodePort will be changed, hence the test will fail.

If a functional load balancer is a requirement, please consider to use a IaaS backed K8s provider like GKE.

# What's a typical developing process

This is a recap of the typical developing process based on different environment.

## Minikube development process

```
# create/start cluster
minikube start
# expose docker environment
eval $(minikube docker-env)

# BEGIN iterations
  # build container image
  docker build
  # test it out
  ...
# END iterations

# stop cluster
minikube stop
```

## GKE development process

```
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
  # NOTE: the container images have to be downloaded to the GKE cluser nodes
  ...
# END iterations

# delete cluster to save money
gcloud container clusters delete
```

# Summary
For local development, minikube is a rich enough environment to support your K8s applications, even for the complicated
stateful application like Greenplum, a massive parallel processing data warehouse service.

Again, to verify the end-to-end experience, GKE would be a good choice.   
