---
authors:
- cunnie
categories:
- BOSH
- CF
- IPv6
- vSphere
date: 2020-02-01T01:16:22Z
draft: false
short: |
  This blog post describes how to assign both an IPv4 and an IPv6 address to the
  HAProxy VM (an optional load balancer) on a Cloud Foundry deployment
  (foundation). This may be of particular interest to homelab enthusiasts who
  have an abundance of public IPv6 addresses but only one public IPv4.
title: How To Enable IPv6 on Your Cloud Foundry's HAProxy
---

### 0. Abstract

[HAProxy](http://www.haproxy.org/) is an optional load balancer included in
the canonical open source [Cloud Foundry
deployment](https://github.com/cloudfoundry/cf-deployment). Its intended use is
on IaaSes (Infrastructures as a Service) that do not offer built-in load
balancers [0]. On vSphere, this means without the optional network
virtualization solutions, NSX-T and NSX-V. This blog post describes how to
assign an IPv6 address to an HAProxy load balancer in a Cloud Foundry
deployment.

### 1. Pre-requisites

Users following this blog post should be familiar with BOSH, BOSH's manifest
operations files, IPv6, and deploying Cloud Foundry using _cf-deployment_.

### 2. Set Up DNS Records

We set up our DNS (Domain Name System) records as shown in the table below
(we're using the same domain, `cf.nono.io`, for both system and app domains, and
this is probably [not a good
idea](https://github.com/cloudfoundry/cloud_controller_ng/issues/568)):

| Hostname     |  IPv4 Address |          IPv6 Address |
|--------------|---------------|----------------------:|
| cf.nono.io   |  10.0.250.10  | 2601:646:100:69f5::10 |
| *.cf.nono.io |  10.0.250.10  | 2601:646:100:69f5::10 |

 Our DNS server uses a BIND-format (Berkeley Internet Name Domain) [1] file, and
 [here](https://github.com/cunnie/shay.nono.io-usr-local-etc/blob/9f56b3a271a7b869706bd6676e0110377a053486/named_chroot/usr/local/etc/namedb/dynamic/nono.io#L36-L40)
 are the raw entries (tweaked for readability):

```bind
cf.nono.io.     A     10.0.250.10
                AAAA  2601:646:100:69f5::10
*.cf.nono.io.   A     10.0.250.10
                AAAA  2601:646:100:69f5::10
```

{{< responsive-figure src="https://docs.google.com/drawings/d/e/2PACX-1vTu14kV9z2Uv9HP36PNzkJ7QbewEnhABG2BFvpO4ET67YCkYV9R7Rdg8RSZ7zmLTOMjXhtj2disPNDf/pub?w=1209&amp;h=1234" >}}

Note that the IPv4 address (10.0.250.10) is in a [private
network](https://en.wikipedia.org/wiki/Private_network) and not reachable from
the internet, but the IPv6 address (2601:646:100\:69f5::10) is in a public one.
Indeed, the IPv6 address is in a `/64` subnet, one of 8 subnets that Comcast has
allocated.

<div class="alert alert-info" role="alert">

Only IPv6-enabled clients can reach our Cloud Foundry; IPv4-only clients can't.

</div>

### 3. Prepare the Cloud Foundry Deployment

Let's download what we need and log in to our BOSH Director:

```shell
mkdir -p ~/workspace
cd ~/workspace
git clone https://github.com/cloudfoundry/cf-deployment
git clone https://github.com/cunnie/deployments
git clone https://github.com/cloudfoundry/cf-acceptance-tests.git
export BOSH_ENVIRONMENT=vsphere # our vSphere BOSH Director's environment alias
bosh login
cd deployments
```

- the GitHub repo `cf-deployment` contains the BOSH manifest and manifest
  operations files to deploy Cloud Foundry.
- the GitHub repo `deployments` contains additional scripts and manifest
  operations files to deploy Cloud Foundry with an IPv6 HAProxy.
- the GitHub repo `cf-acceptance-tests` contains a sample CF app that we can
  push to test IPv6 connectivity.

#### 3.0 Prepare the BOSH Cloud Config

Normally we'd add our IPv6 Network to our Cloud Config's YAML file and then type
in `bosh update-cloud-config`, but that's not what we're going to do in this
case. Instead, we're going to use the Cloud Config included _cf-deployment_ and
use a custom manifest operations files to add our IPv6 network to it.

[Here](https://github.com/cunnie/deployments/blob/f43a24cd150c87c2bf7974863dd157686024c181/bin/cf.sh#L25-L32)
are the relevant lines from our script:

```shell
# We don't use the primary cloud config (we already have one); instead,
#   we set up a secondary config
bosh update-config \
  --non-interactive \
  --type cloud \
  --name cf \
  <(bosh int \
    -o $DEPLOYMENTS_DIR/cf/cloud-config-operations.yml \
    -l $DEPLOYMENTS_DIR/cf/cloud-config-vars.yml \
    $DEPLOYMENTS_DIR/../cf-deployment/iaas-support/vsphere/cloud-config.yml)
```

The environment variable `$DEPLOYMENTS_DIR` refers to the directory which
contains our customizations (`~/workspace/deployments`).

Let's talk about our customizations; We customize as follows:

- We set up our variables in
  [`cf/cloud-config-vars.yml`](https://github.com/cunnie/deployments/blob/f43a24cd150c87c2bf7974863dd157686024c181/cf/cloud-config-vars.yml).
  The file is uninteresting—it sets up the IPv4 subnets for the three AZs, two
  of which (`az2` and `az3`) will be immediately removed as part of our
  manifest operations.

- We apply our manifest operations ([`cf/cloud-config-operations.yml`](https://github.com/cunnie/deployments/blob/f43a24cd150c87c2bf7974863dd157686024c181/cf/cloud-config-operations.yml)).

  - We remove two of the AZs, leaving one, `az1`. We don't want a sprawling
    deployment; Our vSphere cluster is too small. We can only fit one AZ.

  - We modify `az1`'s' subnet to include a static IP address, 10.0.250.10, which
    will be assigned to the HAproxy, and which is the DNS `A` record for
    `*.cf.nono.io`.

  - We introduce the IPv6 subnet, 2601:646\:100:69f5::/64, including a static
    IPv6 address, 2601:646\:100:69f5::10, which will be assigned to the HAproxy,
    and which is the DNS `AAAA` record for `*.cf.nono.io`.

#### 3.1 Prepare the BOSH Runtime Config

As long as BOSH DNS is colocated on all deployed VMs (which is the default BOSH
Runtime Config), you shouldn't need to make changes.

#### 3.2 Deploy Cloud Foundry with BOSH

Deploying the VMs requires one command, `bosh deploy`, but with many options.
Here are the relevant lines from our deploy [shell
script](https://github.com/cunnie/deployments/blob/3e2366d7ceebf7e2cf6107592dc6d28a7c56daf4/bin/cf.sh).

```shell
bosh \
  -e vsphere \
  -d cf \
  deploy \
  --no-redact \
  $DEPLOYMENTS_DIR/../cf-deployment/cf-deployment.yml \
  -l <(lpass show --note cf.yml) \
  -v system_domain=cf.nono.io \
  -o $DEPLOYMENTS_DIR/../cf-deployment/operations/scale-to-one-az.yml \
  -o $DEPLOYMENTS_DIR/../cf-deployment/operations/use-haproxy.yml \
  -o $DEPLOYMENTS_DIR/../cf-deployment/operations/use-latest-stemcell.yml \
  -o $DEPLOYMENTS_DIR/cf/letsencrypt.yml \
  -o $DEPLOYMENTS_DIR/cf/haproxy-on-ipv6.yml \
  -v haproxy_private_ip=10.0.250.10 \
  --var-file=star_cf_nono_io_crt=$HOME/.acme.sh/\*.cf.nono.io/fullchain.cer \
  --var-file=star_cf_nono_io_key=$HOME/.acme.sh/\*.cf.nono.io/\*.cf.nono.io.key \
```

Notes:

-  `-o $DEPLOYMENTS_DIR/cf/haproxy-on-ipv6.yml` is the most important line for
   deploying HAProxy with IPv6. It's a [BOSH manifest operations
   file](https://bosh.io/docs/cli-ops-files/), and will be covered in the
   following section.

- `-v haproxy_private_ip=10.0.250.10` sets the HAProxy to the IPv4 address
  pointed to by `*.cf.nono.io`.

- `-v system_domain=cf.nono.io` sets the system domain, which should point to
  the IPv4 address above.

- `<(lpass show --note cf.yml)` is a YAML file that sets only one property,
  `cf_admin_password`. The author prefers to have a easy-to-remember admin
  password rather than needing to extract the password from a BOSH-generated
  CredHub secret. This line, this YAML file, is unnecessary; you may safely skip
  it.

- Any parameter beginning with `$DEPLOYMENTS_DIR/../cf-deployment` refers to a
  file in [cf-deployment](https://github.com/cloudfoundry/cf-deployment) GitHub
  repo, which means it's a canonical manifest or manifest operations file.

- `-o $DEPLOYMENTS_DIR/../cf-deployment/operations/use-haproxy.yml`. Enable
  HAProxy, otherwise there's no VM to which we can assign an IPv6 address.

- `-o $DEPLOYMENTS_DIR/cf/letsencrypt.yml` is a custom manifest operations file
  the deploys HAProxy with a valid, commercial TLS certificate issued by [Let's
  Encrypt](https://letsencrypt.org/). Its usage outside the scope of this
  document, but if enough are interested the author may write a blog post to
  describe how to deploy Cloud Foundry with a free Let's Encrypt wildcard
  certificate. You may safely skip this file.

- `--var-file=star_cf_nono_io_crt` and `--var-file=star_cf_nono_io_key` are also
  related to the Let's Encrypt TLS certificate. You may skip them.

### 4. Prepare the Manifest Operations File to Enable IPv6 on HAProxy

The [23-line manifest operations
file](https://github.com/cunnie/deployments/blob/f43a24cd150c87c2bf7974863dd157686024c181/cf/haproxy-on-ipv6.yml)
is too long to inline in this blog post, but let's review key points:

- Assign HAProxy VM an IPv6 address. BOSH requires IPv6 to have leading zeros,
  no double-colons. In other words, don't abbreviate the IPv6 address. This
  IPv6 address should be the AAAA DNS record of the app & system domains (e.g.
  `cf.nono.io`, `*.cf.nono.io`):
  ```YML
  # haproxy has an IPv6 address
  - type: replace
    path: /instance_groups/name=haproxy/networks/name=PAS-IPv6?
    value:
      name: PAS-IPv6
      static_ips:
      - 2601:0646:0100:69f5:0000:0000:0000:0010
  ```
- Configure HAProxy job (process) to bind to both IPv4 and IPv6 addresses:
  ```YML
  # configure haproxy to bind to the IPv6 in6addr_any address "::"
  - type: replace
    path: /instance_groups/name=haproxy/jobs/name=haproxy/properties/ha_proxy/binding_ip?
    value: "::"

  # configure haproxy to bind to both IPv4 & IPv6 interfaces
  - type: replace
    path: /instance_groups/name=haproxy/jobs/name=haproxy/properties/ha_proxy/v4v6?
    value: true
  ```

### 5. Test

We push an application, then `curl` the application over IPv6.

```shell
cf api api.cf.nono.io --skip-ssl-validation # replace your CF API endpoint here
cf login
cf target -o system -s system # or whichever org & space you want to use
cf push dora -p ../cf-acceptance-tests/assets/dora
curl -6 -k https://dora.cf.nono.io # replace your application domain here
 # "Hi, I'm Dora!"
```

### Gotchas

A reasonable question is, "do browsers have trouble consistently navigating to
HAProxy's IPv6 address given that `*.cf.nono.io` resolve to both IPv4 and IPv6
addresses?"

We haven't experienced trouble with either the Google Chrome or Firefox
browsers. Similarly, we haven't experienced problems with the [Cloud Foundry
CLI](https://docs.cloudfoundry.org/cf-cli/install-go-cli.html) (Command Line
Interface); however, we suspect that if we had a machine on our internal network
whose IPv4 addressed matched the IPv4 address of our HAProxy (i.e.
10.0.250.10), then connectivity would be erratic.

Assigning the HAProxy VM's [default
gateway](https://bosh.io/docs/networks/#multi-homed) to the IPv4 or IPv6
interface is a nuanced decision. If the BOSH Director is in a different IPv4
subnet, you _must_ assign the default gateway to the IPv4 interface so that the
VM can reach the BOSH director and retrieve its configuration and releases (as
is the case in our setup).

If you have IPv6 [router
advertisements](https://en.wikipedia.org/wiki/Neighbor_Discovery_Protocol) on
your IPv6 subnet, your IPv6 interface will pick up its default gateway for free.
If you do not have router advertisements, you will need a more complex manifest
operations file; check
[here](https://github.com/cunnie/deployments/blob/4129d8ee5546f0a658eaacfa624da619b02a7335/cf/haproxy-on-ipv6.yml#L25-L81)
for inspiration.

For best results, use Ubuntu Xenial stemcells 621.51 or greater; IPv6 router
advertisement are [enabled by
default](https://github.com/cloudfoundry/bosh-agent/commit/7864a5947b3c0b3cc3d21911d93728b8a9ee760e).


### Footnotes

[0]

Most IaaSes (Amazon Web Services (AWS), Google Cloud, and Microsoft Azure) offer
load balancers, and they typically charge $200+/yr for the service.

The author is of the opinion is that load balancers are often an unnecessary
expense, and many users are better off with a carefully-monitored single
webserver rather than a fleet of webservers fronted by a load balancer. To quote
[Andrew Carnegie](https://quoteinvestigator.com/2017/02/16/eggs/):

> put all your eggs in one basket, and then watch that basket

[1]

[BIND](https://en.wikipedia.org/wiki/BIND) is an old-school DNS server. Nowadays
most users are better off using DNS-as-a-service (e.g. Amazon's [Route
53](https://aws.amazon.com/route53/), Google Cloud
[DNS](https://cloud.google.com/dns/)), but for the hardcore, deploying your own
DNS servers is a wonderfully addictive option. The author, for example, has been
running his own DNS servers since 1996, and currently maintains 4 DNS servers on
4 different IaaSes (Azure, AWS, Google, Hetzner) on 3 different continents
(America, Asia, Europe).

The author is an unapologetic DNS fanboy, and had [Paul
Mockapetris](https://en.wikipedia.org/wiki/Paul_Mockapetris), the author of the
original DNS RFC, autograph his laptop with a permanent marker.
