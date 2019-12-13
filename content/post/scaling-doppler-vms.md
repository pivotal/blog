---
authors:
- tochen
- msuliteanu
categories:
- CF
- Cloud Foundry
- PAS
- Pivotal Application Service
- Loggregator
- Logging & Metrics
date: 2019-12-13T16:00:00Z
short: |
  When your Cloud Foundry logging system is not working optimally, one of the reasons could be improperly scaled Doppler VMs. Read this learn if this is the case and get general guidelines for how to properly scale your Doppler VMs.
title: Scaling Doppler VMs in Cloud Foundry
image: /images/loggregator/diagram.gif
---
## Why care about Dopplers

You might be wondering what a Doppler is (and why you care about it). Doppler VMs are a core component of log and metrics transport;
one that you probably won’t care about until it stops working. Insufficiently scaled Doppler VMs are a frequent source of log
loss in Cloud Foundry. This post aims to be a resource to an operator whose platform is dropping logs and is trying to determine
if Doppler is the reason.

Anyone that has worked with the logging pipeline in Cloud Foundry has probably heard of Dopplers, but how many actually know what they do?
Dopplers are an intermediary point on a log’s journey through Cloud Foundry. A log or metric begins its journey when it is emitted by a
Cloud Foundry application or component. The emitted logs and metrics are sent to a logging agent on the same VM that then sends them to the
Dopplers. Dopplers receive logs and metrics and make them available to consumers. Common consumers include the various nozzles that pull
from the Firehose, like Splunk and Datadog, and Pivotal products, like Healthwatch and Metrics.

{{< responsive-figure src="/images/loggregator/diagram.gif" class="center" alt="Figure 1: Loggregator Architecture" caption="Figure 1 - Loggregator Architecture" >}}

## Is Doppler Under-Scaled?
There are some key scaling indicators that can help determine whether Doppler is the problem, and if it is, what to do about it.

### First take a look at your logging system metrics.
The most universally accessible method for users of Cloud Foundry to get at these metrics is to query the Log Cache.
The section below gives a list of a few metrics to look at. For each metric, a PromQL query is given that
can be issued against the Log Cache to get the relevant information on that metric.

There are two methods to execute a PromQL query against Log Cache,
using the `cf query` command from the [`log-cache-cli` plugin](https://plugins.cloudfoundry.org/#log-cache) or curling the Log Cache directly:

#### CF Query (requires CLI plugin)
```shell
$ cf query "<PromQL>"
```

#### Curling Log Cache
```shell
$ curl -v https://log-cache.<cf system domain>/api/v1/query --data-urlencode "query=<PromQL>" -H "Authorization: $(cf oauth-token)"
```

#### Metrics to Inspect
Check the following metrics for the conditions noted. If any of those conditions are true, then Doppler is probably under-scaled.

1. Check if the `doppler.ingress` metric is higher than 16,000 per second per Doppler.
   - PromQL: `rate(ingress{source_id='doppler'}[5m])`
2. Check if CPU usage on the Doppler VMs is consistenly above 75% **OR**
   - The `doppler.dropped` with tag {direction=ingress} metrics is greater than zero.
     - PromQL: `sum(max_over_time(dropped{source_id='doppler', direction='ingress'}[<some time>])) by (index) > 0`

If none of these things are out of expected ranges, it is very likely that the problem is somewhere else in the logging pipeline.

## Scaling Up
Now that we know the ‘what’, we can handle the ‘what to do’.
In general, adding more Dopplers is recommended. This is because, regardless of the amount of CPU allocated, Dopplers have a i
hard limit of 16,000 logs per second per Doppler. The amount to scale varies by foundation. A good strategy is to look at the
`rate of ingress` metric and figure out the minimum Dopplers by dividing by 16,000, then adding another 20% on top of those.
Once Dopplers have been scaled check for dropped logs and scale further if necessary.

The exception to this horizontal scaling rule is that a foundation can have at most 40 Dopplers before overall logging function
degrades and horizontal scaling has no effect. When a foundation is at 40 Dopplers and dropping logs it is possible to try
scaling CPU as a buffering measure, but ultimately it is likely that the foundation will need to be sharded into smaller foundations.

## Other Problems
It is worth mentioning that there is another metric, `doppler.dropped` with tag `{direction=egress}`, that indicates slow
consumers of Dopplers. This can be an indication that logs are dropping because of a slow consumer. Slow consumers are another
big topic that be covered by their own future post.
