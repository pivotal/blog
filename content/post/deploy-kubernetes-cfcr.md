---
authors:
- twong
categories:
- CFCR
- BOSH
- Tutorial
- Kubernetes
date: 2018-01-15T23:25:24-05:00
draft: true
short: |
  Cloud Foundry Container Runtime makes deploying Kubernetes easy with the power of BOSH.
title: Deploying Kubernetes with Cloud Foundry Container Runtime
image: /images/cfcr-full.png
---

{{< youtube U14EA0KVQU0 >}}

# Kubernetes + BOSH = CFCR

The goal of Cloud Foundry Container Runtime is to simplify deploying and maintaining a Kubernetes cluster. It does a lot to alleviate the day-to-day burdens.

This is a walkthrough of how to install CFCR and deploy Kubernetes with it. CFCR used to be called Kubo, so you'll see lots of references to Kubo in this tutorial.

> *CFCR aims to delight the Kubernetes operator*

It features:

* enable self-healing when there're VM failures or retirement
* generating, installing, and managing certificates
* monitoring the health of Kubernetes processes such as proxy and API server
* support different infrastructure providers so you're not locked down (right now we support GCP, AWS, vSphere, and OpenStack)
* make the deployment and scaling up process repeatable and easier to automate
* support rolling system upgrades

That's a long list of stuff that operators have to worry about and CFCR is our solution that problem. How does it do that? Well it accomplishes many of these goals with the help of BOSH.

## How does BOSH work?

Like I mentioned before, BOSH is a toolchain that helps people operate complex software. By deploying software with BOSH, your services will have multi-IaaS support, it'll be highly availble, self healing in the face of infrastructure failures, and be easy to scale.

BOSH was designed with these features so it can deploy complex platforms like Cloud Foundry and now Kubernetes. Like Kubernetes, BOSH is made up of several components. In fact, if you understand the components of Kubernetes, you can often find direct analogues in BOSH.

[architecture diagram]

Here're the key [components of BOSH](https://bosh.io/docs/bosh-components.html):

* Director (similiar the Kubernetes API server) - receives commands from the user and creates tasks to be run. It reconciles the current state of the system and the expected state.
* VMs - where BOSH will install software.
* Agent (a process running on each VM) - think of it like a kubelet, agents take orders from the director, checks with Monit to make sure processes on the VM are alive, and communicates with the health monitor.
* Health Monitor - monitors the health of VMs and notifies the director if a VM dies
* Cloud Provider Interface (CPI) - Similar to Kubernetes cloud providers. This is a Cloud Foundry developers have already implemented this interface for all the popular IaaS (including AWS, GCP, vSphere, and OpenStack) and it allows BOSH to talks to each infrastructure  provider to procure resources.
* CLI
* BOSH release

### BOSH Release

While BOSH has many similarities with Kubernetes, the way they package software is different. You can think of packaged software in the BOSH world as tarballs called *releases*. Releases contain the libraries, source code, binaries, scripts, and configuration templates needed to deploy a system of software. 

In case the case of the CFCR BOSH release, the packages in the tarball include Golang, CNI, flanneld, among others. The binaries include api-server, kubeproxy, kubelet, among others. The release also include configuration templates to configure these components. The whole thing is packaged together into a tarball, and the software vendor can then distribute this tarball however they like.

When the user deploys this release, the resulting instance is called a deployment. The way a deployment is created goes like this:

1. Extract the contents of a release, compiling packages and source code
1. Spin up the configured number of VMs
1. Start the BOSH agent on each VM
1. Snstall the of the compiled software on the VMs
1. Set up the configuration for those software
1. Start the software, also start monitoring for crashes

When a new version of a release is published, the user goes through the same deployment process, except now a rolling upgrade is possible.

Deploying a director takes around 30 minutes. Ideally, the user rarely has to upgrade BOSH itself, but an upgrade can be faster than an initial deployment depending on how much has changed. The good thing is it doesn't involve any downtime for the deployments, meaning services are not disrupted.

## GCP Prerequisites

For this guide we're going to be using GCP. (However, the official CFCR docs also describe how to get it working in AWS, vSphere, and OpenStack.) Before we get started, here are some prerequestites you'll need from

* A GCP project, in my case this is `cf-sandbox-twong`.
* APIs enabled:
  * Google Identity and Access Management (IAM)
  * Google Cloud Resource Manager APIs
* A service account that can deploy BOSH, it has to have the `Owner` role. In this guide we'll call this service account `k1-bosh@cf-sandbox-twong.iam.gserviceaccount.com`
* A VPC Network. We'll call it `cfcr-net` in this example.

The official docs have a terrform plan that will create the next set of prerequisites for you. However, if you don't want to use terraform, I've listed out the individual elements you need below.

* Another service account which will be used by the k8s nodes. In our case we'll call it `k1-node@cf-sandbox-twong.iam.gserviceaccount.com` and it needs these roles:
  * `roles/compute.storageAdmin`
  * `roles/compute.networkAdmin`
  * `roles/compute.securityAdmin`
  * `roles/compute.instanceAdmin`
  * `roles/iam.serviceAccountActor`
* A subnet under `cfcr-net` with at least /24 CIDR range. In our case we'll call the subnet `k1-us-west1-subnet`.
* A [bastion VM](https://cloud.google.com/solutions/connecting-securely#bastion) so that the scripts we're going to run will have access to the subnet. We'll name this VM `k1-bosh-bastion`.
* A firewall rule so that we'll have SSH access into the bastion.
* A NAT VM so that internal VMs can send requests out to the internet. We'll name this VM `k1-nat-instance-primary`.
* A route to our NAT VM. We'll call this route `k1-nat-primary`. Furthermore, we'll configure it so that all VMs with a tag called `no-ip` will use this route.
* A firewall rule so that VMs inside the subnet can talk to each other. If you use the terraform plan, all VMs with the tag `internal` shares this firewall rule.

With all the prequisites out of the way, we're now ready to install BOSH.

## Deploy BOSH

### Download `kubo-deployment`

For most of this guide, we'll be working from within the bastion. Before you get started, copy the key for `k1-bosh@cf-sandbox-twong.iam.gserviceaccount.com` in this VM. We'll need it for later.

```sh
$ gcloud compute ssh k1-bosh-bastion
$ ls
k1-admin-service-account.key.json
```

Then, download the [latest version of `kubo-deployment`](https://github.com/cloudfoundry-incubator/kubo-deployment/releases). This tarball contains the scripts necessary to deploy BOSH and then CFCR, it also contains the CFCR BOSH release itself. In this example we're going to download version 0.12.0 but you should download the latest version available.

```sh
$ wget https://github.com/cloudfoundry-incubator/kubo-deployment/releases/download/v0.12.0/kubo-deployment-0.12.0.tgz
$ tar -xvf kubo-deployment-latest.tgz
```

### Set up your configuration

After that, we'll generate a configuration template for deploying BOSH:

```sh
$ kubo-deployment/bin/generate_env_config ~/ cfcr-config gcp
```

This will create the `cfcr-config` folder, inside of which is the configuration file `director.yml` which contains the properties for deploying BOSH and later for deploying CFCR.

Our next step is to update `director.yml` with machine specific configuration, such as the network name, zone, and gateway.

Conveniently, if you followed the docs and used the project's terraform plan to create the bastion, there's script that does all of this for you located at `/usr/bin/update_gcp_env`.

If you didn't use the terraform plan, here's a list of the properties you need to update in `director.yml`:

```yaml
project_id: cf-sandbox-twong # your GCP project id
network: cfcr-net
subnetwork: k1-us-west1-subnet
zone: us-west1-a # the zone where you subnet is located
service_account: k1-node@cf-sandbox-twong.iam.gserviceaccount.com # the service account created in the earlier terraform script. It'll be used by the CPI

internal_ip: 10.0.1.252 # decide the future IP address of your director, must be in your subnet
deployments_network: my-cfcr-deployments-network # the internal name that BOSH will use place deployments. Can be whatever you want
internal_cidr: 10.0.1.0/24 # your subnet's CIDR, or at least a subset of it that you want BOSH to use to deploy machines
internal_gw: 10.0.1.1 # your subnet's gateway
director_name: k1-bosh # decide the future name of your BOSH director, can be user friendly and can be whatever you want
dns_recursor_ip: 10.0.1.1 # DNS IP for resolving non-BOSH hostnames
```

### Kick off the deployment

Use the `deploy_bosh` step to deploy BOSH, and pass into it the directory containing our configuration files, and the key for our `k1-admin` service account.

```sh
$ kubo-deployment/bin/deploy_bosh \
    ~/cfcr-config ~/k1-admin-service-account.key.json
```

Deploying BOSH takes about thirty minutes with GCP.

### After deploying

If you take a look at the GCP console again, you'll see that there's a new VM with a name like `vm-123abc` (yours will have a unique ID). This is the BOSH director that I described at the beginning of the guide.

Your SSH connection might have time out, so make sure you SSH into the bastion again.

Inside the `cfcr-config` director you'll notice two new files:

* `creds.yml` - which containers the passwords, CAs, and certs used by BOSH, and generated by our scripts. It'll also be used later to store all the CFCR related credentials.
* `state.json` - a state file which keeps track of which VMs BOSH is install into. It'll only be used when you update BOSH or when you have to destroy BOSH.


### (Optional) Try out some BOSH CLI commands

Getting familiar with BOSH is not a necessary part of this guide. However, it'll come in handy for troubleshooting or if you want to deploy and operate other software releases BOSH supports besides CFCR.

```sh
# make sure we have the right version
$ bosh-cli -v

# each environment is like a kubeconfig
$ bosh envs

# you'll get an error saying you're unauthorized
$ bosh-cli -e cfcr-config deployments

$ cd cfcr-config
$ ls

# copy admin_password
$ head creds.yml

# user name admin
bosh-cli -e cfcr-config login

bosh-cli -e cfcr-config deployments
bosh-cli -e cfcr-config vms
```

## Deploy CFCR

### Set up k8s networking infrastructure

Execute the terraform plan that will set up the networking infrastructure for our kubernetes cluster.

```sh
$ cd ~
$ cp kubo-deployment/docs/user-guide/routing/gcp/kubo-lbs.tf ./

# specify where the terraform state will be created
$ export cfcr_terraform_state=~/cfcr-config/terraform.tfstate
```

Next, you'll need to apply the IaaS terraform script. It takes as input some existing settings such as your network name and project ID. If you used the the terraform plan from the docs to set up the bastion, these properties will already be available to you as environment variables on the machine.

```sh
$ terraform apply \
    -var network=${network} \
    -var projectid=${project_id} \
    -var region=${region} \
    -var prefix=${prefix} \
    -var ip_cidr_range="${subnet_ip_prefix}.0/24" \
    -state=${cfcr_terraform_state}
```

This plan creates a target pool for the k8s master, a load balancer and firewall rule for ingress into the master. You can find them in the GCP cloud console.


### Update `director.yml`

`director.yml` will be reused when we deploy our k8s cluster. First we need to use terraform to recall the target pool name and load balancer address.

```sh
# terraform has created a GCP instances pool to put our master
$ export master_target_pool=$(terraform output -state=${cfcr_terraform_state} kubo_master_target_pool)

# it has also created a LB in front of that pool
$ export kubernetes_master_host=$(terraform output -state=${cfcr_terraform_state} master_lb_ip_address)
```

Then, open up `director.yml` and fill in the related properties.

```yaml
routing_mode: iaas
kubernetes_master_host: <replace with $kubernetes_master_host>
master_target_pool: <replace with $master_target_pool>
```

### Deploy our k8s cluster

Finally, it's time to deploy k8s. We have the handy script `deploy_k8s` which will uses the CFCR BOSH release to configure and launch our cluster. It'll create VMs for our k8s master and workers, set up the CAs and certs correctly, and well as launch all the k8s processes.

```sh
$ kubo-deployment/bin/deploy_k8s ~/cfcr-config my-k8s-cluster
```

The deployment process takes about twenty minutes on GCP. When it's complete, BOSH will begin monitoring VMs, maintaining logs, and restart any crashed components.

If you look at the GCP cloud console, you'll see four new VMs. If you look at the their tags, you'll be able to tell that one of them is a k8s master, and the others are k8s nodes.

### Set Up kubeconfig

To communicate to the cluster, you'll see to set up a kubeconfig. We have script `set_kubeconfig` that does it for you.

```sh
$ kubo-deployment/bin/set_kubeconfig
$ kubo-deployment/bin/set_kubeconfig \
    ~/cfcr-config my-k8s-cluster
$ kubectl get svc --all-namespaces
$ less .kube/config
```

You can now access the k8s cluster from anywhere by exporting the kubeconfig to the machine you want to use. Exit the bastion and use the `gcloud compute scp` command to copy the kubeconfig.

```sh
$ gcloud compute scp k1-bosh-bastion:~/.kube/config ./kubeconfig
$ kubectl --kubeconfig=./kubeconfig cluster-info
$ kubectl --kubeconfig=./kubeconfig get componentstatuses
$ kubectl --kubeconfig=./kubeconfig get nodes
$ kubectl --kubeconfig=./kubeconfig get svc --all-namespaces
```
