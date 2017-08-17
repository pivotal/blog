---
authors:
- cunnie
categories:
- BOSH
date: 2017-08-16T17:16:22Z
draft: false
short: |
  A BOSH director is typically deployed with self-signed SSL (Secure Sockets
  Layer) certificates; however, the director can be deployed with certificates
  issued by a trusted CA (Certificate Authority). Here's how.
title: Deploying a BOSH Director With Valid SSL Certificates
---

## 0. Abstract

A BOSH director is a virtual machine (VM) orchestrator which deploys VMs to
various Infrastructures as a Service (IaaS) such as Amazon Web Services (AWS)
and Google Cloud Platform (GCP). The BOSH Command Line (CLI) communicates with
the director over Secure Sockets Layer (SSL). While most BOSH directors are
deployed with self-signed certificates, it is possible to configure a BOSH
director with certificates issued by a recognized certificate authority (CA)
(e.g. Comodo, Symantec, Let's Encrypt). This blog post describes a technique to
deploy a BOSH director with a CA-issued SSL certificate.

Additionally, this blog posts describes a mechanism to override the
automatically-generated passwords (e.g. for logging into the director from the
CLI).

This blog post may be of use to organizations who desire the following:

- use CA-issued SSL certificates on their BOSH director
- set specific passwords on the BOSH director's services (e.g. login, PostgreSQL)
- dispense with the `--var-store` file (which stores the auto-generated passwords
and the self-signed SSL certificate authority's certificate), a file created by
the BOSH CLI during deployment and which normally must be stored in a safe
&amp; secure manner

This blog posts assumes familiarity with [BOSH CLI
v2](https://bosh.io/docs/cli-v2.html) and with the procedure to deploy a BOSH
director.

The blog post describes deploying (i.e. creating) a BOSH director
([bosh-gce.nono.io](https://bosh-gce.nono.io:25555/info)) to the Google Cloud
Platform.

<div class="alert alert-warning" role="alert">

The BOSH Development Team has put much engineering into the CA/certificate
generation & workflow and also in generating secure (i.e. high entropy)
passwords. By following the instructions in this blog post, you're deliberately
tossing that work aside, and may open your BOSH director to subtle (or perhaps
not-so-subtle) attacks. At the very least you void your warranty.

You have been warned.

</div>

## 1. Overview of the Procedure To Deploy a BOSH Director

The procedure to deploy a BOSH director with valid SSL certificate is a superset
of the [normal procedure](https://bosh.io/docs/init-google.html) to deploy a
BOSH director, with an additional step: using `bosh interpolate` to create an
intermediate manifest.

Below is a visual diagram of the process:

{{<responsive-figure src="https://docs.google.com/drawings/d/1cpwqxuoAcGJbVfQxFXrYA9ZXf6XqEA4jZEVMozczfLk/pub?w=1224&amp;h=1584">}}

## 2. Deploying the BOSH Director to GCP

### 2.1 Pre-requisites: IP addresses, DNS Records, and SSL Certificates

We are deploying our BOSH director to Google Cloud Platform (GCP), so we
acquire an external IP address via the GCP console.

* **104.154.39.128** — the external IP address acquired from GCP. Note that
the IP address need not be a public address — in fact, most BOSH directors have
private ([RFC 1918](https://tools.ietf.org/html/rfc1918)) addresses. Having
one's BOSH directors reachable solely via a jumpbox adds a layer of security.
* **bosh-gce.nono.io** — the DNS record must point to the director's IP address
(i.e. 104.154.39.128)
(`dig +short bosh-gce.nono.io` returns the expected IP address).
* **SSL Certificate** — we use a wildcard certificate (i.e. **\*.nono.io**), but
a wildcard certificate is not necessary, and a regular SSL certificate
(e.g. bosh-gce.nono.io) is much less expensive.

### 2.2 Create a Manifest Operations (`gce.yml`) File to Insert the SSL Certificate

We create a manifest operations YAML file (`gce.yml`) to insert our SSL
certificate. Note that although we populate the SSL certificate, we do _not_
populate the SSL key; instead, we use a variable, `((nono_io_key))`, which will
be interpolated in the second stage (double parentheses, "`(())`", are an
indicator to the BOSH CLI parser to perform variable substitution).

Below is a shortened version of our manifest operations file; the full one can be
viewed on
[GitHub](https://github.com/cunnie/deployments/blob/d769ca78cb733491493defea7729859a57422c58/etc/gce.yml):

```YAML
- type: replace
  path: /instance_groups/name=bosh/properties/director/ssl/key?
  value: ((nono_io_key))
- type: replace
  path: /instance_groups/name=bosh/properties/director/ssl/cert?
  value: |
    -----BEGIN CERTIFICATE-----
    MIIFXDCCBESgAwIBAgIQOvRHkhKyb/k9O4xvIi9zZTANBgkqhkiG9w0BAQsFADCB
    <snip>
    NaaNSyS8pHUJhaq+ZiC7zM2YsuLBICPQfsunHGrho4k=
    -----END CERTIFICATE-----
    -----BEGIN CERTIFICATE-----
    MIIGCDCCA/CgAwIBAgIQKy5u6tl1NmwUim7bo3yMBzANBgkqhkiG9w0BAQwFADCB
    <snip>
    pu/xO28QOG8=
    -----END CERTIFICATE-----
```

### 2.3 Create the Message Bus Bootstrap SSL and Certificates (`mbus_bootstrap_ssl.yml`) File

We create a YAML file that contains the SSL Certificate and the
substitution-directive, `((nono_io_key))`, for the private key used
during the message bus bootstrap process.

Typically we would set a variable via the CLI when using to create our
intermediate manifest (e.g. to set the external IP via the CLI: `bosh
interpolate ~/workspace/bosh-deployment/bosh.yml -v external_ip="104.154.39.128" ...`);
however, we cannot set the variable because it's too complex (it's not a simple
value; instead it's YAML), so we use the BOSH CLI's `--var-file` option (e.g.
`--var-file mbus_bootstrap_ssl=etc/mbus_bootstrap_ssl.yml`), which has been
created to accommodate situations like these.

Below is a shortened version of our `mbus_bootstrap_ssl.yml` operations file;
the full one can be viewed on
[GitHub](https://github.com/cunnie/deployments/blob/5382d1f2f0b007232db353b936514844346a7249/etc/mbus_bootstrap_ssl.yml):

```YAML
certificate: |
  -----BEGIN CERTIFICATE-----
  MIIFXDCCBESgAwIBAgIQOvRHkhKyb/k9O4xvIi9zZTANBgkqhkiG9w0BAQsFADCB
  NaaNSyS8pHUJhaq+ZiC7zM2YsuLBICPQfsunHGrho4k=
  -----END CERTIFICATE-----
  -----BEGIN CERTIFICATE-----
  MIIGCDCCA/CgAwIBAgIQKy5u6tl1NmwUim7bo3yMBzANBgkqhkiG9w0BAQwFADCB
  +AZxAeKCINT+b72x
  -----END CERTIFICATE-----
private_key: ((nono_io_key))
```

### 2.4  Run `bosh interpolate` to Create Intermediate Manifest

We run the `bosh interpolate` to create our intermediate manifest,
`bosh-gce.yml`.

```bash
bosh interpolate ~/workspace/bosh-deployment/bosh.yml \
  -o ~/workspace/bosh-deployment/misc/powerdns.yml \
  -o ~/workspace/bosh-deployment/gcp/cpi.yml \
  -o ~/workspace/bosh-deployment/external-ip-not-recommended.yml \
  -o ~/workspace/bosh-deployment/jumpbox-user.yml \
  -o etc/gce.yml \
  --var-file mbus_bootstrap_ssl=etc/mbus_bootstrap_ssl.yml \
  -v dns_recursor_ip="169.254.169.254" \
  -v internal_gw="10.128.0.1" \
  -v internal_cidr="10.128.0.0/20" \
  -v internal_ip="10.128.0.2" \
  -v external_ip="104.154.39.128" \
  -v network="cf" \
  -v subnetwork="cf-e6ecf3fd8a498fbe" \
  -v tags="[ cf-internal, cf-bosh ]" \
  -v zone="us-central1-b" \
  -v project_id="blabbertabber" \
  -v director_name="gce" \
  > bosh-gce.yml
```

The first argument to `bosh interpolate` is the BOSH director manifest template
file, `~/workspace/bosh-deployment/bosh.yml`. This has the generic defaults for
a BOSH director (e.g. persistent disk size of 32,768MB, the five jobs of the
director, etc...). The source of this file is the
[bosh-deployment](#bosh_deployment) git repo, which has been cloned to
`~/workspace/bosh-deployment/` on our workstation.

The `-o` (`--ops-file`) ("manifest operations from a YAML file") are a set of
files which configure the BOSH director with specific attributes. With the
exception of our custom (`gce.yml`), the manifest operations files reside in the
`bosh-deployment` repository.

Here is the list of manifest operations files and their purpose:

* `misc/powerdns.ym`: this is only needed for
[dynamic networks](https://bosh.io/docs/networks.html#dynamic), where the IaaS,
rather than the director, assigns IP addresses to the VMs deployed by the
director. The BOSH development team is doing [interesting
work](https://bosh.io/docs/dns.html) with hostname resolution (DNS), and this particular manifest
operations file will likely be deprecated soon.
* `gcp/cpi.yml`: this is needed for deploying a BOSH director to GCP, it sets
properties such as `machine_type` (`n1-standard-1`).
* `external-ip-not-recommended.yml`: this is not recommended for general use;
it's for deploying a BOSH director with a publicly-accessible IP address.  <sup><a href="#security" class="alert-link">[Security]</a></sup>
* `jumpbox-user.yml`: this creates an account, _jumpbox_, on the director. This
account has `sudo` privileges and can be ssh'ed into using an ssh key. In our
example, the interpolated variable `gce_jumpbox_user_public_key`, contains the
public key which will be inserted into the file `~jumpbox/.ssh/authorized_keys`
on the BOSH director. The private key is kept in `~/.ssh/google` on our
workstation. The command to ssh into our director is the following:
`ssh -i ~/.ssh/google jumpbox@bosh-gce.nono.io`

We use a script to create our intermediate manifest; our script can be viewed
on [GitHub](https://github.com/cunnie/deployments/blob/5382d1f2f0b007232db353b936514844346a7249/bin/gce.sh).

Our intermediate manifest (without secrets) can also be seen on
[GitHub](https://github.com/cunnie/deployments/blob/5382d1f2f0b007232db353b936514844346a7249/bosh-gce.yml).

### 2.5 Create a Secrets File

We create a YAML file with our secrets (passwords and keys). These will
be substituted during the second stage (`bosh create-env`). Below is a redacted
version of our file (the passwords aren't the real passwords; don't even bother
trying to use them) (the public ssh key, however, is the real deal) (the GCP
credentials JSON values are mostly real, too):

```yaml
admin_password: IReturnedAndSawUnderTheSun
blobstore_agent_password: ThatTheRaceIsNotToTheSwift
blobstore_director_password: NorTheBattleToTheStrong
hm_password: NeitherYetBreadToTheWise
mbus_bootstrap_password: NorYetRichesToMenOfUnderstanding
nats_password: NorYetFavourToMenOfSkill
postgres_password: ButTimeAndChanceHappenethToThemAll

gce_jumpbox_user_public_key: "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC9An3FOF/vUnEA2VkaYHoACjbmk3G4yAHE3lXnGpIhz3EV5k4B5RzEFKZnAIFcX18eBjYQIN9xQO0L9xkhlCyrQHrnXBjCDwt/BuQSiRvp3tlx9g0tGyuuJRI5n656Shc7w/g4UbrQWUBdLKjxTT4kTgAdK+1pgDbhAXdPtMwt4D/sz5OEFdf5O5Cp+0spxC+Ctdb94taZhScqB4xt6dRl7bwI28vZdq6Sjg/hbMBbTXzSJ17+ql8LJtXiUHO5W7MwNtKdZmlglOUy3CEIwDz3FdI9zKEfnfpfosp/hu+07/8Y02+U/fsjQyJy8ZCSsGY2e2XpvNNVj/3mnj8fP5cX cunnie@nono.io"

gcp_credentials_json: |
  {
    "type": "service_account",
    "project_id": "blabbertabber",
    "private_key_id": "642493xxxxxxx",
    "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvAIBADANBgkqhkiG9w0BYwoIBAQCtNvKlIorU1xlP\nlXOxMTS8lT2djHXXN2od0l1mR/\nX4tDHQ2DPvAuKXSLYfgQRuNlydxMQcN7Ln7aDtECgYAgTNO/7a9QjyVyov2tzZMT\nPG19XeHbuu/SZHcQqa+oEGWwTM02+TUCfaCQVOesxcRHjeGjCJbBC1jaWL7\nFRSsSpYEPdcaDO9p56CbebgGvrp790EgM1YvacjbW3CoUA\nG2B88HgJ5MmxAZRCuPaVjg==\n-----END PRIVATE KEY-----\n",
    "client_email": "bosh-user@blabbertabber.iam.gserviceaccount.com",
    "client_id": "11221xxxx",
    "auth_uri": "https://accounts.google.com/o/oauth2/auth",
    "token_uri": "https://accounts.google.com/o/oauth2/token",
    "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
    "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/bosh-user%40blabbertabber.iam.gserviceaccount.com"
  }

nono_io_key: |
  -----BEGIN RSA PRIVATE KEY-----
  MIIEpQIBAAKCAQEAty5zouKiJfdQQ45DUR1AvhArzgwMAxf/c+2QEKueRSqCfm6l
  <snip>
  K+6Y18ijXoJimhW32UhmjnsmeAlq0/0HUvLBCe9mXlA8cWg533V3v30=
  -----END RSA PRIVATE KEY-----
```

### 2.6 Deploying the director

Deploying the director is a bit anticlimactic. In this example, we assume
the name of the file which contains our secrets which we created in the
previous step is named `secrets.yml`:

```bash
bosh create-env bosh-gce.yml -l secrets.yml
```

In a more complex example (we use LastPass&trade; to store our secrets in a note
named `deployments.yml`), we take advantage of bash's [process
substitution](https://www.gnu.org/software/bash/manual/html_node/Process-Substitution.html)
to take the output of the LastPass CLI's command and make it appear as a file
argument to the BOSH CLI:

```bash
bosh create-env bosh-gce.yml -l <(lpass show --note deployments.yml)
```

Remember to save the `bosh-gce-state.json` file — it contains the location of
the persistent disk, which is important if you ever decide to re-deploy your
BOSH director, for the director's state (including deployments, releases,
stemcells) is stored on the persistent disk.

## 3. Optimizations: Collapse Two Stages into One

The two stages can be collapsed into one by dispensing with the `bosh interpolate`
section and merging its options with the `bosh create-env` step. Indeed, the
only advantage of using a two-stage process is the creation of the intermediate
BOSH director manifest file, `bosh-gce.yml`.

## Acknowledgements

[Dmitriy Kalinin](https://github.com/cppforlife/) offered frank & candid
feedback on this post.

## Footnotes

<a name="security"><sup>[Security]</sup></a> The author has mixed feelings
for many of the best-practices in the security space; for example, the author
feels that firewalls are no substitute for knowing which services should
(and should not) be running on one's server and that tools such as
[AppArmor](https://en.wikipedia.org/wiki/AppArmor),
[SELinux](https://en.wikipedia.org/wiki/Security-Enhanced_Linux), and
[auditd](https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/6/html/Security_Guide/chap-system_auditing.html) often introduce subtle and hard-to-debug failures at the
expense of arguably modest security improvements.

## Bibliography

<a name="bosh_deployment">
[bosh-deployment](https://github.com/cloudfoundry/bosh-deployment)</a> is a
GitHub repository containing a collection of manifest templates and manifest
operations files. Manifest operations files use the
[go-patch](#go_patch) syntax.

<a
name="go_patch">[go-patch](https://github.com/cppforlife/go-patch/blob/master/docs/examples.md)</a>
is a tool which modifies a target YAML file based on directives, the directives
which in turn are are also YAML files. *go-patch* is the mechanism which the
BOSH CLI uses to apply changes to the BOSH template (e.g.
`external-ip-not-recommended.yml` is a *go-patch*-format file in the
[bosh-deployment](https://github.com/cloudfoundry/bosh-deployment) GitHub repo,
which, when applied to the `bosh.yml` manifest file, creates the necessary
properties for a BOSH director with an external IP address.

## Corrections & Updates

*2017-08-17*

Clarified the author's statement with regard to the pros and cons of current
security practices. The original statement was controversial and could reflect
poorly on the author and the journal. The present statement is more neutral in
tone.

Removed an incomplete sentence, described the provenance of the `--var-store`
file.
