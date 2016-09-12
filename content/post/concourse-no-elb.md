---
authors:
- cunnie
- sill
categories:
- BOSH
- Concourse
date: 2016-08-26T06:58:07-07:00
draft: false
short: |
  nginx is a less-expensive alternative to a load balancer for a BOSH-deployed Concourse server's SSL termination.
title: Concourse without a Load Balancer
---

## Abstract

[Concourse](http://concourse.ci/) is a continuous integration (CI) server. It
can be deployed manually or via
[BOSH](http://concourse.ci/clusters-with-bosh.html).

In this blog post, we describe the BOSH deployment of a Concourse CI server to
natively accept Secure Sockets Layer (SSL) connections without using a load
balancer. This may reduce the complexity and cost
<sup>[[ELB-pricing]](#ELB-pricing)</sup> of a Concourse deployment.

<div class="alert alert-danger" role="alert"> 2016-09-12: This blog post is
obsolete. Newer (v2.0.0+) versions of Concourse allow binding to the privileged
ports 80 and 443, eliminating the need for an nginx proxy. Here is an example
of a BOSH-deployed Concourse server that binds natively to ports 80 & 443: <a
href="https://github.com/cunnie/deployments/blob/62d0ed813879440f656b6e0bd6f984d708c4bff2/concourse-ntp-pdns-gce.yml#L48-L51">BOSH
manifest</a>.  </div>

### 0. Pre-requisites

Deploy Concourse with BOSH. Follow the instructions
[here](http://concourse.ci/clusters-with-bosh.html).

### 1. Upload nginx BOSH Release

Next, upload the nginx BOSH release to your director (note that we're using an
experimental CLI whose syntax is slightly different <sup>[[Golang
CLI]](#golangcli)</sup> ):

```
bosh upload-release https://github.com/cloudfoundry-community/nginx-release/releases/download/v4/nginx-4.tgz
```

### 2. Add nginx to your BOSH manifest

Add the release:

```yaml
releases:
- name: nginx
  version: latest
```

Add the nginx job properties.

The following example shows the manifest properties for
[https://ci.nono.io](https://ci.nono.io). Be sure to replace all occurrences of
"ci.nono.io" with the fully qualified domain name (FQDN) of your Concourse
server. Also, substitute the appropriate SSL certificate(s) and key.

```yaml
- name: nginx
  release: nginx
  properties:
    nginx_conf: |
      worker_processes  1;
      error_log /var/vcap/sys/log/nginx/error.log   info;
      events {
        worker_connections  1024;
      }
      http {
        include /var/vcap/packages/nginx/conf/mime.types;
        default_type  application/octet-stream;
        sendfile        on;
        keepalive_timeout  65;
        server_names_hash_bucket_size 64;
        # redirect HTTP to HTTPS
        server {
          server_name _; # invalid value which will never trigger on a real hostname.
          listen 80;
          rewrite ^ https://ci.nono.io$request_uri?;
          access_log /var/vcap/sys/log/nginx/ci.nono.io-access.log;
          error_log /var/vcap/sys/log/nginx/ci.nono.io-error.log;
        }
        server {
          server_name ci.nono.io;
          # weak DH https://weakdh.org/sysadmin.html
          ssl_ciphers 'ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:AES:CAMELLIA:DES-CBC3-SHA:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5:!PSK:!aECDH:!EDH-DSS-DES-CBC3-SHA:!EDH-RSA-DES-CBC3-SHA:!KRB5-DES-CBC3-SHA';
          ssl_prefer_server_ciphers on;
          # poodle https://scotthelme.co.uk/sslv3-goes-to-the-dogs-poodle-kills-off-protocol/
          ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
          listen              443 ssl;
          ssl_certificate     /var/vcap/jobs/nginx/etc/ssl_chained.crt.pem;
          ssl_certificate_key /var/vcap/jobs/nginx/etc/ssl.key.pem;
          access_log /var/vcap/sys/log/nginx/ci.nono.io-access.log;
          error_log /var/vcap/sys/log/nginx/ci.nono.io-error.log;
          root /var/vcap/jobs/nginx/www/document_root;
          index index.shtml index.html index.htm;
          # https://www.digitalocean.com/community/tutorials/how-to-configure-nginx-with-ssl-as-a-reverse-proxy-for-jenkins
          location / {
              proxy_set_header  Host $host;
              proxy_set_header  X-Real-IP $remote_addr;
              proxy_set_header  X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header  X-Forwarded-Proto $scheme;
              # Fix `websocket: bad handshake` when using `fly intercept`
              proxy_set_header  Upgrade $http_upgrade;
              proxy_set_header  Connection "upgrade";

              # Fix the “It appears that your reverse proxy set up is broken" error.
              proxy_pass          http://localhost:8080;
              proxy_read_timeout  90;
              proxy_redirect      http://localhost:8080 https://ci.nono.io;
          }
        }
      }
    # FIXME: replace with your HTTPS SSL key
    ssl_key: ((nono_io_key))
    # FIXME: replace with your HTTPS SSL chained certificate
    ssl_chained_cert: |
      -----BEGIN CERTIFICATE-----
      MIIFXDCCBESgAwIBAgIQOvRHkhKyb/k9O4xvIi9zZTANBgkqhkiG9w0BAQsFADCB
      ...
      NaaNSyS8pHUJhaq+ZiC7zM2YsuLBICPQfsunHGrho4k=
      -----END CERTIFICATE-----
      -----BEGIN CERTIFICATE-----
      MIIGCDCCA/CgAwIBAgIQKy5u6tl1NmwUim7bo3yMBzANBgkqhkiG9w0BAQwFADCB
      ...
      +AZxAeKCINT+b72x
      -----END CERTIFICATE-----
      -----BEGIN CERTIFICATE-----
      MIIFdDCCBFygAwIBAgIQJ2buVutJ846r13Ci/ITeIjANBgkqhkiG9w0BAQwFADBv
      ...
      pu/xO28QOG8=
      -----END CERTIFICATE-----
```

### 3. BOSH Deploy

We deploy (note that we are using an experimental BOSH CLI whose syntax
differs slightly from the canonical Ruby CLI's):

```sh
bosh deploy -d concourse concourse.yml -l <(lpass show --note deployments)
```

We browse to our newly-deployed Concourse server to verify an SSL connection:
[https://ci.nono.io](https://ci.nono.io)

{{< responsive-figure src="https://cloud.githubusercontent.com/assets/1020675/18006701/ac76b628-6b55-11e6-9ac2-afc69dc96b51.png" >}}

### 4. Manifests

* Concourse server + nginx front-end [BOSH
manifest](https://github.com/cunnie/deployments/blob/84900b6067b8d935e86991f428c4f246914082b7/concourse.yml)
* BOSH Director Cloud Config
[manifest](https://github.com/cunnie/deployments/blob/84900b6067b8d935e86991f428c4f246914082b7/cloud-config-gce.yml)
* BOSH Director
[manifest](https://github.com/cunnie/deployments/blob/84900b6067b8d935e86991f428c4f246914082b7/bosh-gce.yml)
<sup>[[Google Cloud]](#google_cloud)</sup>

### Addendum: Using Concourse's Built-in TLS instead of nginx

Concourse has BOSH job properties that allow you to set the TLS key and
certificate, bypassing the need for a colocated nginx job:

```yaml
instance_groups:
  jobs:
    atc:
      properties:
        tls_cert: |
          -----BEGIN CERTIFICATE-----
          MIIFXDCCBESgAwIBAgIQOvRHkhKyb/k9O4xvIi9zZTANBgkqhkiG9w0BAQsFADCB
          ...
          NaaNSyS8pHUJhaq+ZiC7zM2YsuLBICPQfsunHGrho4k=
          -----END CERTIFICATE-----
          -----BEGIN CERTIFICATE-----
          MIIGCDCCA/CgAwIBAgIQKy5u6tl1NmwUim7bo3yMBzANBgkqhkiG9w0BAQwFADCB
          ....
          pu/xO28QOG8=
          -----END CERTIFICATE-----
        tls_key: |
          -----BEGIN RSA PRIVATE KEY-----
```

This simple solution has a downside: the Concourse URI's requires a port number
at the end (e.g. the URI would be https://ci.nono.io:4443 instead of
https://ci.nono.io). <sup>[[privileged]](#privileged)</sup>

[Here](https://github.com/cunnie/deployments/blob/1e9a96203acfd806822834f4d6932225771c834b/concourse.yml)
is a sample BOSH manifest which uses Concourse's built-in TLS.

## Footnotes

<a name="ELB-pricing"><sup>[ELB-pricing]</sup></a> ELB pricing, as of this
writing, is
[$0.025/hour](https://aws.amazon.com/elasticloadbalancing/pricing/), $0.60/day,
**$219.15** / year (assuming 365.24 days / year).

Load balancers (specifically ELBs) offer the ability to direct traffic to a pool
of backend servers and to automatically remove a server from the pool if it
becomes unresponsive; however, this feature is often unneeded &mdash; we are
unaware of any Concourse server deployments which have multiple backends. A load
balancer in front of a Concourse server is an unnecessary expense in our opinion.

<a name="golangcli"><sup>[Golang CLI]</sup></a>
We are using an experimental Golang-based BOSH command line interface (CLI), and
the arguments are slightly different than those of canonical Ruby-based [BOSH
CLI](https://github.com/cloudfoundry/bosh/tree/master/bosh_cli); however, the
arguments are similar enough to be readily adapted to the Ruby CLI (e.g. the
Golang CLI's `bosh upload-stemcell` equivalent to the Ruby CLI's `bosh upload
stemcell` (no dash)).

The new CLI also allows variable interpolation, with the value of the variables
to interpolate passed in via YAML file on the command line. This feature allows
the redaction of sensitive values (e.g. SSL keys) from the manifest. The format
is similar to Concourse's interpolation, except that interpolated values are
bracketed by double parentheses "((key))", whereas Concourse uses double curly
braces "{{key}}".

Similar to Concourse, the experimental BOSH CLI allows the YAML file containing
the secrets to be passed via the command line, e.g. `-l ~/secrets.yml` or
`-l <(lpass show --note secrets)`

The Golang CLI is in alpha and should not be used on production systems.

<a name="google_cloud"><sup>[Google Cloud]</sup></a>
We are deploying to [Google Cloud Platform](https://cloud.google.com/)'s [Google
Compute Engine](https://cloud.google.com/compute/) (GCE), and thus the
`cloud_properties` sections of the BOSH Director's manifest may appear
unfamiliar to those who deploy on AWS or vSphere.

<a name="privileged"><sup>[privileged]</sup></a> Concourse will not bind to a
[privileged
port](http://unix.stackexchange.com/questions/16564/why-are-the-first-1024-ports-restricted-to-the-root-user-only).

You may attempt to force `atc` to bind to port 443 by setting its
[tls_bind_port](https://github.com/concourse/concourse/blob/b0d0c99edb7a1f379c350426d0e71ab16b74da56/jobs/atc/spec#L42-L45)
job property, but it will not work,  `atc` will not start, and you will see the
following message in `/var/vcap/sys/log/atc/atc.stderr.log`:

```
web-tls  exited with error: listen tcp 0.0.0.0:443: bind: permission denied
```
