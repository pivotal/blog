---
authors:
- tpatterson
- msuliteanu
categories:
- CF
- Cloud Foundry
- PAS
- Pivotal Application Service
- Loggregator
- Logging & Metrics
date: 2020-01-14T16:00:00Z
short: |
  If you're still losing logs even though you've correctly scaled Dopplers, you probably need to scale your Firehose API and consumers.
title: Scaling the Firehose API and Consumers
image: /images/loggregator/firehose-api.png
---
## Scaling the Loggregator API
So you’ve used [this article](https://engineering.pivotal.io/post/scaling-doppler-vms/) to correctly scale Dopplers 
in your Loggregator system. Even so, you notice that you're still experiencing log loss. It could be that your log consumers need to be tuned for the log and metric volume coming 
from the Dopplers. In this post, we’ll talk about scaling the API and consumer VMs in the Loggregator pipeline. 

Here are some terms we’ll use throughout the article:
- `loggregator_trafficcontroller` (TC) is the instance group hosting the streaming log API.
- `consumer` is any generic client of the TC that wants to stream logs.

### Notes on the Loggregator Streaming API
- There are two versions of the streaming API provided by Loggregator. For the purposes of this article, we’ll be chatting mostly about the v1 API but the scaling principles introduced are valid for both API versions.
   
### API Flow
{{< responsive-figure src="/images/loggregator/firehose-api.png" class="center" alt="Figure 1: Loggregator API Flow" caption="Figure 1 - Loggregator API Flow" >}}

## How to tell if your consumers are struggling?
Loggregator emits a variety of metrics about itself to assist operators with scaling issues like we’re discussing in this article. If your consumers are unable to keep up with the load from your foundation, Loggregator will give you clues about what is happening:
Metrics
`doppler_proxy.slow_consumer` This metric is emitted by the TC when a consumer fails to keep up with the Log Volume. It represents a consumer whose connection to the API has been forcibly terminated.
`doppler.dropped{direction=egress}` This is a metric emitted in PAS version >= 2.6.9 by the Doppler VMs that indicates log-loss due to slow downstream consumers. You’ll see this metric *in addition* to the above slow_consumer metric.

### To view these metrics, you can request them from Log Cache using PromQL. This can be done one of two ways:

#### CF Query (requires the [log-cache-cli](https://plugins.cloudfoundry.org/#log-cache) CLI plugin)
`$ cf query "<PromQL>"`

#### Directly (using `curl`)
`$ curl -v https://log-cache.<cf system domain>/api/v1/query --data-urlencode "query=<PromQL>" -H "Authorization: $(cf oauth-token)"`

For example, to see the latest value of `doppler_proxy.slow_consumer` using the `cf query` command, you would run:

      $ cf query doppler_proxy.slow_consumer

## Logs
The TC emits logs about slow consumers when it emits a `doppler_proxy.slow_consumer` metric. This log contains the IP of the slow consumer along with its shard ID.
NOTE: The IP address in this log was intended to help identify the slow consumer by IP. Because all consumers connect via the Gorouter, in practice, this is always the IP address of a Gorouter instance.
The `Dropped (egress) 1000 envelopes` is emitted by Dopplers when downstream consumers are having trouble keeping us.
NOTE: Even through these logs appear in the Doppler Logs they do indicate a slow consumer!

### Logs to Ignore
TC VMs record the connection status between the Streaming API and the backing Doppler VMs. As a result, the logs can be quite noisy. Logs describing gRPC connections or Doppler connections can be safely ignored.

## Identifying a Slow Consumer
Now that you’ve determined that you have a slow consumer, how do you fix the issue? 
To find your slow consumer, there are a couple of strategies:
1. Look for a `slow consumer` log message from the TC and pay attention to the identified subscription ID. This often identifies the offending consumer.
1. Alternatively, turn all your consumers off and then start turning them on one by one. When you start seeing the indicators listed above, you’ve found a slow consumer.

## Scaling  
Loggregator is designed to facilitate consumers to scale horizontally until they can meet the load from the system. Scaling consumers can be a balancing act, so you’ll likely need to try a few times before your system is correctly provisioned.

Before you scale, there are a couple of things to keep in mind. 
1. Loggregator the entire log stream to each consumer with a unique subscription ID, so be sure this is the same across all instances of your consumer.
1. Log consumers consume via the API. Scaling consumers without regard for the API risks overloading the TC VMs. As a result, we recommend that you scale TC VMs alongside consumers in a 1:1 ratio. This isn’t a hard rule, but it ensures optimum load distribution. If you scale beyond 1:1 TC:Consumer, closely watch the TC VM vitals to ensure they’re not being overloaded.

Now scale your slow consumer and TC VMs. For simplicity, we recommend a scaling factor of 2x. This should allow you to quickly determine if scaling your consumer helped your situation. Check your logs and metrics. If they improved, scale again. If they did not improve, you’ll need to look further downstream for the source of the log bottleneck.

Once you have achieved the right scaling to service the load coming from your foundation, you should see few dropped log messages or slow consumers. Keep in mind that bursts of load may cause these metrics and logs to briefly spike.


## Notes on Total Loggregator Size
   
TC VMs create streams back to every Doppler VM for every consumer present in your system. As a result, the total size of a Loggregator pipeline is limited by the connection overhead between the TCs and the Dopplers. The maximum size for which the Loggregator scaling recommendations are valid is 40 Dopplers to 20 TC VMs. Much like the ratio of TC VMs to Consumers, this isn’t a hard rule so keep an eye on your VM vitals.   
