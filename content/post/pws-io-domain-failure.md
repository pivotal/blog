---
authors:
- tdadlani
- dreeve
categories:
- CF Runtime
- DNS
- Cloud Foundry
- Pivotal Web Services
date: 2016-12-20T11:42:41-08:00
draft: true
short: |
  An article about the `.io` TLD failure, how it affected Cloud Foundry, as well as how we could potentially mitigate TLD failures in the future.
title: Understanding and Mitigating the .io Top-Level-Domain failure in Cloud Foundry and Pivotal Web Services
---

# Introduction

On October 28th, 2016, five out of seven nameservers for the `.io` top-level domain (TLD) stopped working.<sup><a href="#io-failure-ycombinator" class="alert-link">[1]</a></sup> In this article, we’ll talk briefly about the `.io` TLD failure, then talk about how it affected Cloud Foundry as well as how we could potentially mitigate these failures in the future.


# What Happened?

Five of the seven nameservers for the `.io` TLD stopped responding. This made many `.io` domains inaccessible for a few hours.


### What Affects Did This Downtime Have?

Pivotal Web Services (PWS) relies on the `.io` Top-Level Domain for a few things and the PWS CloudOps team noticed a few ways that users of PWS could have been affected.


### How Did This Affect Internal Cloud Foundry Components?

1. Traffic internal to Cloud Foundry relies on NATS<sup><a href="#nats" class="alert-link">[2]</a></sup> to register routes to Cloud Foundry’s router. All registered routes that leveraged the system domain (`run.pivotal.io`) were potentially affected.
1. The Cloud Foundry CLI goes through the cloud controller, which registers its route at `api.run.pivotal.io`. This meant that the CF CLI was partially unusable while the `.io` TLD was having issues.


### How Did This Issue Manifest Itself to Application Developers?

1. Users who had Cloud Foundry applications running on PWS with a PWS-generated subdomain were potentially inaccessible as long as the TLD was down. That is, many requests to apps with `*.cfapps.io` domain names received "Cannot resolve host"-type errors.
1. If an application was bound to an internal service that uses an `.io` domain in its connection string &mdash; p-mysql, for example &mdash; app owners would see connection errors.


# TLD Failure Mitigation Strategies

### Mitigation Strategy

Register applications to multiple domains with different TLDs. For example, register your application with both `example.io` and `example.com`. For TLS to work with this strategy, you will need to buy a certificate for each domain.

Application name: myapp
Apps Domain: example.io

Default: When you run `cf push` you get `myapp` running on myapp.example.io

To mitigate against TLD failures:

~~~bash
# Application name: myapp
# Apps Domain: example.io
# Private Domain: example.com

cf create-route my-space example.com --hostname myapp
cf push
cf map-route my-app example.com --hostname myapp
~~~


At the platform level, configure the platform to use multiple TLDs with an [extra shared domain](https://docs.cloudfoundry.org/devguide/deploy-apps/routes-domains.html#shared-domains) and follow the steps above.


### How can we respond to partial TLD nameserver failures in a Cloud Foundry installation?

Assuming your CF installation uses wildcard DNS entries for your system and application domains, there are different ways to mitigate customer impact of a partial TLD nameserver failure on different IaaSes.


#### Google Cloud Platform and Microsoft Azure

Increase the TTL value for your DNS entries that have an A record with the public IP address for the CF domain. Increasing the TTL increases the time until cache invalidation on your [DNS caching servers] (https://www.digitalocean.com/community/tutorials/a-comparison-of-dns-server-types-how-to-choose-the-right-dns-configuration#caching-dns-server). A time of four to six hours should work. The risk of this approach is that if you decide to change your load balancer, a new IP address will be assigned to your load balancer and it will approximately take the same four to six hours to propagate worldwide. In the case of a production system, this even rarely happens.

#### Amazon Web Services

Since Amazon ELBs don’t provide an IP address for your DNS entry, you need to [create an ALIAS record] (http://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resource-record-sets-choosing-alias-non-alias.html) for the DNS entry of your system and app domains. AWS doesn’t guarantee that the IP address of a load balancer will remain the same over that load balancer’s lifetime.<sup><a href="#aws-load-balancer" class="alert-link">[3]</a></sup>

 A load balancer internally points to one or more A records with a TTL of 60 seconds. You cannot mitigate against the partial TLD NS downtime in a safe manner.

 Here is an **unsafe** way to do this: Replace your `ALIAS` record with `A` records that resolve from the load balancer’s `CNAME` with higher TTLs as in step 1. (example: my-custom-load-balancer.amazonaws-312312.com -> 52.44.113.14). If AWS changes the IP addresses your application will experience longer downtime rather than intermittent failures. The safest option is to not do anything and wait for the issue to resolve itself.

**Note**: Some DNS caching servers do not honor TTLs.<sup><a href="#dns-ttl-1" class="alert-link">[4]</a></sup><sup><a href="#dns-ttl-2" class="alert-link">[5]</a></sup>


# Conclusion

DNS is a highly-available and a highly-cached system. In most cases of DNS server failure, not every request is affected. In addition, the failure rate of web servers is much higher than DNS servers. For more information about the Domain Name System, refer to [RFC 1034](https://www.ietf.org/rfc/rfc1034.txt) and [RFC 1035](https://www.ietf.org/rfc/rfc1035.txt).

-------

### Footnotes

[1] <a name="io-failure-ycombinator"></a> [Hackernews post about `.io` domain failure](https://news.ycombinator.com/item?id=12813065)

[2] <a name="nats"></a> [NATS](https://nats.io/)

[3] <a name="aws-load-balancer"></a> [How Elastic Load Balancing Works](http://docs.aws.amazon.com/elasticloadbalancing/latest/userguide/how-elastic-load-balancing-works.html)

[4] <a name="dns-ttl-1"></a> [Providers Ignoring DNS TTL](https://ask.slashdot.org/story/05/04/18/198259/providers-ignoring-dns-ttl)

[5] <a name="dns-ttl-2"></a> [What Percentage of Nameservers Honor TTL These Days?](http://serverfault.com/questions/72363/what-percentage-of-nameservers-honor-ttl-these-days)
