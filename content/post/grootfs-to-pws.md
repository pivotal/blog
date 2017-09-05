---
authors:
- marie
- glestaris
- njbennett
- gclay
categories:
- Operations
- Rollout
- Cloud Foundry
- CF
- Agile
date: 2017-09-05T17:16:22Z
short: |
  Our rollout of GrootFS to Pivotal Web Services was a gradual, iterative process that allowed us to test on a small subset of production instances, roll the changes back, make improvements, and finally release it with confidence. We talk about the process and provide takeaways for other teams deploying new features to production.
title: Deploying GrootFS to Pivotal Web Services (PWS)
image: /images/grootfs-to-pws/pws-v2-dashboard.png
---
## Change is the Only Constant on PWS
Pivotal’s Cloud Operations (CloudOps) team deploys changes to Pivotal Web Services (PWS) almost every day, sometimes multiple times a day. Most of those changes are relatively small and invisible to users. For example, we might deploy a change that encrypts communication between two components, or a change that fixes a few bugs. Often, deployments don’t impact applications running on the platform at all; at most, Diego might reshuffle application instances between cells as the cells are restarted.

### Making bigger changes
Sometimes, however, Cloud Foundry R&D wants to change something like “the underlying filesystem for all containers running on Diego, along with the system for managing those filesystems.” Like smaller changes, this change ought to be invisible to users, but it's also big, requires understanding low-level details about the kernel, and has potentially far-reaching, hard-to-predict consequences for applications running on the platform. For larger changes like this, we like to do gradual rollouts so that we can compare the behavior of existing and new code side-by-side in production.

The GrootFS and CloudOps teams recently collaborated on deploying this underlying filesystem change to Pivotal Web Services, in order to deliver feedback on how GrootFS behaved in real-world conditions. By using a progressive roll-out strategy to minimize risk and maximize information, we discovered a mysterious bug, collaborated a lot, improved GrootFS monitoring and diagnostics, and ultimately found and fixed a problem with our kernel configuration.


## What Is GrootFS?

When an application instance is started on a Diego cell, it is running inside a Garden-runC container. Containerization prevents apps from seeing processes that belong to other apps and limits the apps' access to shared CPU or memory resources. Containers also isolate apps from other apps' filesystems. The application processes has read/write access to what looks like a dedicated Linux filesystem, so no application is able to read or write changes to filesystems that belong to any other applications.

Before [GrootFS](https://github.com/cloudfoundry/grootfs), Garden-runC used a built-in component called Garden Shed to handle filesystem-level isolation, container images, and disk space management. More than a year ago, we decided that it needed to be replaced, mainly because it is based on AUFS, a layer filesystem with limited support from the Linux Kernel community. 

GrootFS is a complete rewrite, and it uses a very different underlying filesystem. While we expect this to be invisible to applications on the cluster, it is a significant change to the underlying abstraction. Before delivering it to customer sites, it was important to observe its behavior in a working production system.


## Initial Rollout

{{< responsive-figure src="/images/grootfs-to-pws/pws-v1-dashboard.png" class="center large" caption="Dashboard for initial GrootFS to PWS rollout, containing only latency information.">}}

We started by deploying GrootFS to 10% of our Diego cells. After a few days of reasonable-looking performance by the GrootFS cells on our Datadog dashboard -- where we could compare performance metrics between GrootFS-enabled cells and non-GrootFS-enabled cells -- we decided to expand the rollout to 50%.

Shortly after we rolled GrootFS out to 50% of our Diego cells, we started to catch cell failures where various processes in the cell would be stuck in [uninterruptible sleep](https://en.wikipedia.org/wiki/Sleep_(system_call)#Uninterruptible_sleep) (_D-state_) permanently. This situation would eventually cause at least some applications on the cell to block. After investigation, we realized that processes were only getting stuck in _D-state_ on GrootFS-enabled cells. This was a pretty good indication that the problem was related to GrootFS.

In order to troubleshoot the issue, we had to ‘hide’ the malfunctioning Diego cells from BOSH to prevent BOSH from recreating them before we could investigate. This blocked us from doing any deploys that affected the entire pool of Diego cells, delaying the rollout of several other features that we wanted to test on PWS.<sup>*</sup> After a few days of holding cells for investigation, we decided to roll back the deployment and see if we could reproduce the issue in a non-production scenario. The rollback resolved the _D-state_ issues on the production environment.

### What did we learn?
After the first rollout, we realized that even though our Datadog dashboard had performance metrics, we did not monitor error and health metrics for GrootFS-enabled cells. We were so focused on comparing the performance of GrootFS and Garden-Shed that we did not think about the effect the new file system stack could have on the kernel.

{{< responsive-figure src="/images/grootfs-to-pws/pws-ccd-worse-vs-avg.png" class="center medium" caption="Both lines represent image creation time. The blue line is the average, and the red line is the max. We wanted to be viewing the max, but didn't realize we needed to switch away from the default of average. This hid spikes of up to 700ms.">}}

We also learned that [statistics rollups are evil](https://lonesysadmin.net/2012/10/18/statistics-rollups-are-evil/). For instance, we knew that our container creation duration (CCD) was spiky. The average CCD was fairly satisfying but some containers took a bit longer to be created. However, we did not know how bad our spikes were, due to default statistical rollup that Datadog applies. Datadog was essentially adjusting reality without us knowing.

## Follow-Up Work
Having removed the code from production, we spent about a week trying to reproduce the issue on a test environment.  We were not able to reproduce the issue, most likely because of a unique characteristic of production such as number of cells, load on cells, or some unusual app behavior.  At that point, we opted to improve our instrumentation and monitoring, and to re-deploy to production.  In the interim, a Diego fix had shipped that reduced the impact of these _D-state_ processes, so we were confident that the issue would have less user impact if it reoccurred.

### Instrumentation and Monitoring Improvements
We created a [`grootfs-diagnostics` release](http://github.com/cloudfoundry/grootfs-diagnostics-release) that we deployed to all cells. This release contains a number of tools to help us investigate issues. The release included:

1. Long-running _D-state_ process detection. This triggers a pipeline that extracts trace logs that we identified as useful to investigating _D-state_ processes. It also alerts us via Slack.
2. _D-state_-process counter. This reports, per cell, how many _D-state_ processes are running on a given cell at a certain point. This is a secondary source of information; if the number starts to rise, it may indicate an issue.

We also drew on our experience in the first rollout to expand our Datadog dashboard to be more comprehensive. We added health metrics and error metrics, and updated the visualization for performance metrics to resolve an issue where Datadog was over-smoothing spikes.

## Second Rollout
{{< responsive-figure src="/images/grootfs-to-pws/pws-v2-dashboard.png" class="center large" caption="The second iteration of our dashboard, with metrics representing latency, traffic, errors, and saturation - Google's \"four golden signals\".">}}

Our expanded Datadog dashboard was useful right away, since we could see side-by-side performance of GrootFS cells vs. Shed cells. This immediately allowed us to identify an issue where GrootFS cells were becoming unhealthy. The issue turned out to be caused by a misconfigured property, which we fixed. Our improved performance metric visualization in Datadog made it easier to detect spikes in container creation time and made us more confident about expanding our rollout after the initial validation.

We found that our long-running _D-state_ process detection was not accurate, but since we had a secondary information source of a counter, we were able to fall back to that method. We’re currently working on v2 of our long-running _D-state_ process detection.

GrootFS is now fully deployed to PWS! 

## Takeaways for Other Production Deployers
We learned a lot from our first rollout that helped us make our second rollout more successful. The goal of this blog post is to share our experiences with you so your first rollout can go more smoothly. Here’s a list of takeaways for other folks just starting down the path to production.

### Think about health metrics _before_ rollout!
Make sure you have a dashboard that monitors your product’s health so you have an indicator if things are going south.
How things behave in your test environment isn’t necessarily representative of how things go at scale. Think about how your health metrics and monitoring may behave on a larger scale.

### Know your dependencies
Our failures were because of a kernel bug. 
Try to understand your dependencies so you have a head start if you need to troubleshoot them. Figure out how you can monitor your dependencies to see if they’re at fault for issues you find. This will allow you to quickly narrow down the scope of your investigation.

### Rollback isn't failure, it's iteration
It can be easy to spend a lot of time trying to debug an issue using the scraps of information that you happen to have available. It’s often more effective to stop the current investigation and instead improve the information the product will produce the next time the problem occurs.

### Talk to your ops team!
You’re the expert on your product, and they’re the expert on running the system, so it’s important to make sure both groups are on the same page about how the rollout will go. 

It’s also important to be clear about expectations up front. What do you need if your product has an issue - is there a script to run? Are there logs to collect? Should the ops team wait to roll back, or can they do it right away?

Establish who will be paged for what issues, and make sure everyone knows how to get in touch with the other team. Consider cross-team pairing on the deployment, if your deployment is complex.

## Where Are They Now?
Now that GrootFS is deployed to PWS and incorporated into Cloud Foundry, the GrootFS team is focusing on improving their product by finishing rootless containers support, adding support for OCI Images, and improving cache management (particularly cache cleanup). The CloudOps team continues to deploy bleeding-edge Cloud Foundry code to PWS on a daily basis.

\* Note that we have since developed a process to fully isolate Diego cells from BOSH without blocking deploys. Look out for more details on that in a later blog post.
