---
authors:
- cfurman
- ablease
categories:
- BOSH
- Cloud Foundry
- Concourse
- AWS
- GCP
date: 2016-10-20T16:37:02+01:00
draft: true
short: |
  Migrating development environments from AWS to GCP
title: Dev/CI BOSH on GCP
---

Today many teams at Pivotal use either vSphere or AWS to host development and CI environments while working on Cloud Foundry related projects. This means we have multiple BOSH directors, Cloud Foundries, and Concourse deployments to manage.

We, the PCF Services Enablement team in London, recently moved our development and CI infrastructure from Amazon Web Services to Google Cloud Platform (GCP). Why did we do this?

- Opportunity for cost savings: [Preemptible](https://cloud.google.com/compute/docs/instances/preemptible) VMs allow for [substantial cost savings](https://media.tenor.co/images/6e53dd259c94213d290655f37470e627/raw) in development / CI environments.
- Using [BOSH](http://bosh.io/) to deploy Cloud Foundry, Concourse and BOSH-lite lowers the barrier means the cost of change is low.
- The GCP tooling ecosystem offers sensible abstractions over a great set of core APIs.
- From working with the Google team we have seen how responsive they are to feedback, and how quickly they iterate on the platform.

This post is intended to help others thinking of making a similar move.

---

# Before deploying BOSH

We used the [GCP Terraform resources](https://www.terraform.io/docs/providers/google/#) to provision IaaS components before deploying the BOSH director itself. We followed the [Google CPI documentation](https://github.com/cloudfoundry-incubator/bosh-google-cpi-release/tree/master/docs/bosh), but deviated from it in certain ways.

The docs recommend setting up an SSH bastion instance, from which you can run `bosh-init` and `bosh ssh` commands. Setting up a bastion instance has security advantages:

1. You can SSH into it with `gcloud compute ssh`, which uses a temporary private key. Access is tied to your Google account. No individual developer or operator has a private key that can access instances.
1. The BOSH director API port (25555) and the BOSH agent port (6868) do not need to be reachable from any public IP, only the bastion instance.

We didn't deploy the bastion instance, and instead opened the necessary ports for public access to the BOSH director VM. This allows us to `bosh ssh` (using the director as a gateway host) and `bosh-init` from our workstations. For development / CI environments, we felt that the convenience of a jumpbox-free setup outweighed the security benefits.

We don't recommend ignoring the bastion instructions for production!

A generalized version of our Terraform scripts, which are mostly taken from the [Google CPI docs](https://github.com/cloudfoundry-incubator/bosh-google-cpi-release/blob/master/docs/bosh/main.tf):

```javascript
// Preamble
variable "projectid" {
    type = "string"
    default = "cf-services-enablement"
}

variable "region" {
    type = "string"
    default = "europe-west1"
}

variable "zone" {
    type = "string"
    default = "europe-west1-d"
}

provider "google" {
    project = "${var.projectid}"
    region = "${var.region}"
}

// Network where director, and every VM it deploys, will reside in
resource "google_compute_network" "cf" {
  name       = "cf"
}

// Subnet for the director itself
// Add more subnets for deployments, as needed
resource "google_compute_subnetwork" "bosh-director-subnet" {
  name          = "bosh-director-subnet-${var.region}"
  ip_cidr_range = "10.0.0.0/24"
  network       = "${google_compute_network.cf.self_link}"
}

resource "google_compute_address" "bosh-director-ip" {
  name = "bosh-director-ip"
}

// Allow all communication between bosh-deployed VMs
resource "google_compute_firewall" "bosh-internal" {
  name    = "bosh-internal"
  network = "${google_compute_network.cf.name}"

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }

  target_tags = ["bosh-internal"]
  source_tags = ["bosh-internal"]
}

// Open director and bosh-agent ports for certain instances.
// This allows API access, and bosh-init.
resource "google_compute_firewall" "bosh-director" {
  name    = "bosh-director"
  network = "${google_compute_network.cf.name}"

  allow {
    protocol = "tcp"
    ports    = ["25555", "6868"]
  }

  target_tags = ["bosh-director"]
  source_ranges = ["0.0.0.0/0"]
}

// Allow SSH to certain instances
resource "google_compute_firewall" "ssh" {
  name    = "ssh"
  network = "${google_compute_network.cf.name}"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  target_tags = ["ssh"]
  source_ranges = ["0.0.0.0/0"]
}

// Open UAA port on certain instances
resource "google_compute_firewall" "uaa" {
  name    = "uaa"
  network = "${google_compute_network.cf.name}"

  allow {
    protocol = "tcp"
    ports    = ["8443"]
  }

  target_tags = ["uaa"]
  source_ranges = ["0.0.0.0/0"]
}
```

The firewall rules are fine-grained so that they can be reused for things such as Cloud Foundry and BOSH lite.

# Deploying BOSH

We deployed the BOSH director with `bosh-init` using a modified version of [the init manifest in the Google CPI docs](https://github.com/cloudfoundry-incubator/bosh-google-cpi-release/tree/master/docs/bosh#deploy-bosh).

We won't duplicate our whole manifest here, but some highlights are:

1. The director VM is tagged with `bosh-director`, `bosh-internal`, `ssh`, and `uaa`. This applies all of the firewall rules above.
1. We used [UAA instead of basic auth](http://bosh.io/docs/director-users-uaa.html) to secure access to our director. We needed to do this, as one of our products interacts with the BOSH API and supports both UAA and basic auth. This might not be necessary for every team.
1. We have an extra property: `google.json_key`, containing a JSON literal representing a service account access key. This allows us to use `bosh-init` to bootstrap the director from outside GCE.
1. In `cloud_provider.ssh_tunnel.private_key`, we keep a local path to a private key that corresponds to a GCE public key that will be in `authorized_keys` on all the VMs. You can template this out of Lastpass (or similar) as necessary.
1. We enable the resurrector, see note about "preemptible VMs" further down.

Some of these differences are consequences of not using a bastion instance.

## Cloud Config

A generalized version of our [cloud config](http://bosh.io/docs/cloud-config.html):

```yaml
azs:
- name: europe-west1-d
  cloud_properties: {zone: europe-west1-d}

networks:
- name: a-network
  type: manual
  subnets:
  - range: 10.0.2.0/24
    gateway: 10.0.2.1
    az: europe-west1-d
    cloud_properties:
      network_name: cf
      subnetwork_name: some-network
      ephemeral_external_ip: false
      tags: [bosh-internal]

# For assigning static IPs
- name: static
  type: vip
  cloud_properties: {}

vm_types:
- name: some-vm
  cloud_properties:
    machine_type: n1-standard-1
    root_disk_type: pd-ssd
    root_disk_size_gb: 60
    preemptible: true
    tags: [web, cf-secure-websockets, uaa, ping]

disk_types:
- name: 10GB
  disk_size: 10240
  cloud_properties: {type: pd-ssd}

compilation:
  workers: 3
  reuse_compilation_vms: true
  network: a-network
  az: europe-west1-d
  vm_type: some-vm
```

Interesting points:

1. We control whether instances in a network have outbound internet access by whether or not it has a public ip, rather than using NAT.
1. In `vm_types`, the [`preemptible`](https://cloud.google.com/compute/docs/instances/preemptible) setting will flag an instance to be shutdown at any time for an 80% cost saving. This, in conjunction with the bosh resurrector is handy for saving money in development environments, but perhaps not in production.
1. `tags` are used to assign firewall rules to instances, in a composable fashion.

# Deploying Cloud Foundry

We had to create some more terraform resources for this:

```javascript
// In production, we would recommend using IaaS-native load balancing.
// In development, we just deployed the haproxy job from cf-release.
resource "google_compute_address" "cf-haproxy" {
  name = "cf-haproxy"
}

// Open standard HTTP(S) ports to certain instances
resource "google_compute_firewall" "web" {
  name    = "web"
  network = "${google_compute_network.cf.name}"

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  target_tags = ["web"]
  source_ranges = ["0.0.0.0/0"]
}

// Open port 4443 to certain instances
resource "google_compute_firewall" "cf-secure-websockets" {
  name    = "cf-secure-websockets"
  network = "${google_compute_network.cf.name}"

  allow {
    protocol = "tcp"
    ports    = ["4443"]
  }

  target_tags = ["cf-secure-websockets"]
  source_ranges = ["0.0.0.0/0"]
}
```

We apply firewall rules to the haproxy job's `vm_type` to open ports 80, 443, and 4443, to allow HTTP(S) and log streaming from the outside world.

You can optionally apply the UAA rule above to the haproxy, allowing direct UAA access. Again, this is useful for development but unnecessarily dangerous in production.

There is not much special about our manifest, which is a modified version of the [minimal AWS manifest](https://github.com/cloudfoundry/cf-release/blob/master/example_manifests/minimal-aws.yml). Alternatively, you could use the one from the [Google CPI docs](https://github.com/cloudfoundry-incubator/bosh-google-cpi-release/blob/master/docs/cloudfoundry/cloudfoundry.yml). If you've been following our terraform snippets, you'll need to use particular `vm_type`s for VMs that have open ports, such as haproxy.

# Deploying Concourse

To enable access to concourse containers via `fly hijack` an additional firewall rule is
required. We also provision a static IP address for our single-instance concourse web VM to reduce the number of times we have to modify our DNS record.

```javascript
// Allocate an IP address for concourse.
resource "google_compute_address" "concourse" {
  name = "concourse"
}

// Open port 2222 to allow ssh access to concourse.
resource "google_compute_firewall" "concourse-hijack" {
  name    = "concourse-hijack"
  network = "${google_compute_network.cf.name}"

  allow {
    protocol = "tcp"
    ports    = ["2222"]
  }

  target_tags = ["concourse-hijack"]
  source_ranges = ["0.0.0.0/0"]
}
```

Our manifest doesn't differ much from the example in [the Concourse docs](http://concourse.ci/clusters-with-bosh.html). The biggest difference is how we serve HTTPS. Rather than using Google's load balancers, we configure the Concourse ATC job to serve HTTPS directly, using a valid certificate for our domain. This is a cost-saving and simplifying step for us, as we are a small team and have no need for multiple web VM instances.

At the time of writing, the [Google CPI docs](https://github.com/cloudfoundry-incubator/bosh-google-cpi-release/tree/master/docs/concourse) contain instructions for setting up an HTTP load balancer on GCP. This leaves you without `fly hijack` or HTTPS support.

To support HTTPS, `fly hijack`, and have multiple web VMs, you could use a [network load balancer setup](https://cloud.google.com/compute/docs/load-balancing/network/) to proxy (without TLS termination) ports 80, 443, and 2222 to the web instances, which themselves handle TLS on port 443.

# Deploying BOSH Lite

We deploy BOSH lite using our GCP director, and use it for most dev and CI deployments. Our workflow is inspired by [Starke and Wayne's blog post](http://www.starkandwayne.com/blog/deploy-many-bosh-lites-using-normal-bosh-to-any-infrastructure/) about this.

We provision a static IP for the lite director using terraform, and point a wildcard DNS entry at it. This allows the director to be used as an entry point for Cloud Foundry. The port forwarding release, colocated on the lite director VM, exposes the CF haproxy job container on host ports, as in the [Starke and Wayne manifest](http://www.starkandwayne.com/blog/deploy-many-bosh-lites-using-normal-bosh-to-any-infrastructure/).

# Differences between GCP and AWS

Overall we found the move to GCP very pleasant. Some differences are summarized here:

1. VM names are based on UUIDs. To find the VM for a bosh job using the web console, you must grep for the IP or click into each one to view its metadata.
1. VM startup time is a little faster than AWS, but shutdown time is a lot longer (about 2 minutes). This could be because the CPI issues a soft shutdown signal, but we haven't investigated this.
1. The load balancing setup is more complex than AWS ELBs.
