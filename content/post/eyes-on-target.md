---
authors:
- kstrini
- rkelapure
categories:
- App Transformation
- Modernization
- Pivotal Cloud Foundry
- Agile
- Continuous Fielding
- Mission Value
date: 2017-11-18T17:16:22Z
draft: false
short: Continuously Fielding Mission Driven Value
title: (-0-0-) Eyes on Target  
image:
---

{{< responsive-figure src="/images/eyes-on-target/Eyes_on_Target.jpg" alt="The mean time between fielding" class="center small" >}}

**Sisu**  

> strength, perseverance and resilience to commit oneself fully to a task and to bring that task to an end.

At Pivotal, when we entered the national security space we made a conscious effort to translate the shared values of our company into those that were culturally aligned with this community. We did this with the stubborn intent to not sacrifice the speed at which we enable our customers to deliver innovation. 

{{< responsive-figure src="/images/eyes-on-target/Effective_vs_Efficient.jpg" alt="Translating The Difference" class="right small" >}}

It required us to extensively collaborate with national security customers to define a new goal to align value and distill the non-value added work. This new primary goal was the development and implementation of a continuous fielding model. With a unified fielding platform strategy we are collectively working to overcome the delivery challenges of fielding to the last mile, out to the edge.

In the national security space its not how fast can you get an idea into production but how fast can you deliver a compliant solution to a mission need. This requires all of the pieces to be accounted for including compliancy. It drives a single KPI, the mean time between fielding. This KPI measures our  ability to deliver the velocity needed to maintain the Effective Operational Agility for a continuous advantage over our adversaries.

## Factors impeding Goals

There were several challenges impeding our ability to deliver on the promise of velocity. In order to reach the field, every application must pass through various organizations corresponding to delivery phases. Each delivery phase had their own lead, review, and report generation time. There was no cross-functional platform or capability development teams. There was a general lack of transparency of an application’s progress across these silos.

{{< responsive-figure src="/images/eyes-on-target/Factors_Impeding_Goals.jpg" alt="No Smooth Parallel Flow" class="center small" >}}

These resulted in complex high risk deployments per vertical that required high touch specialized skill sets. These high touch processes were due to a lack of a consistent governance model limiting the acquisition community’s ability to respond to changes in the threat without accepting significant security risks and potential system impacts.

The fluctuating budgets of the delivery teams from code development through the fielding process had led to disparate code bases, development teams, and environments for each vertical, delaying fielding time and making it cost prohibitive to  field a single capability and limited protection from failures in production.

It is important to understand that failure due to inadequately addressing non-functional aspects has severe impacts in this environment. Requirements don’t sufficiently address non-functional needs. Budget drops result in even less interest in addressing non-functional requirements. So there are two basic approaches in addressing this impediment. We could have continued to respond to failures reactively or offload these concerns to a platform technology that has built in non-functional aspects as a first class citizen. We needed to combine the technical enablement with the cultural enablement necessary to move from reactive to proactive operations.

## How Operators deploy and run software

We began diligently working on the organizational transformation process but ran into several factors working against us. First, the federal acquisition process incentivizes schedule over performance. Couple this with the testing processes that often result in meeting minimum requirements and this leads to little incentive to deliver exceptional products. We decided to start with changing the engineering culture. We needed to convince engineering that functionally acceptable is not enough. We wanted to remind them that the the warfighter/analyst/operator demands an individual personal drive to excellence in addition to an exceptional synergy within a team.

Finding empathy with the delivery teams, meant understanding how difficult safe software deployments are in the national security arena. Separate teams/organizations responsible for the different phases in a delivery meant less shared understanding. Low deployment frequency is more prone to errors. You take this complexity and exponentially expand it when you approach the scale necessary to support national security. We recognized that the two major factors contributing this complexity.

**1**. There was no unified common platform strategy for the delivery teams to rally around and build a consistent knowledge base and governance control point. To address the first factor we needed repeatable deliveries with validated results that were defensible. This included using version control for all components in the platform inventory. Through automation this would significantly lower the traditional System Operational Verification Test (SOVT) and eliminate the far more System of System Enterprise (SOSE) tests.

**2**. There was a perpendicular communication flow being exercised to the parallel delivery flow. To address the second factor we started organizing around operational mission driven value streams. This meant recruiting direct warfighter involvement to drive product development. This meant that the delivery team would have a better understanding of operational relevancy. They could better understand the decisions while maintaining a high level of application knowledge. The result of this change was a higher level of accountability and ownership throughout the lifecycle of the application. This was true for the delivery team as well as the end user who was taking delivery of the application. We now had a solution for the perpendicular communication flow problem that mirrored our parallel delivery flow.

## Security and Compliance in Secure Continuous Fielding

One of the  necessary impedances to continuous fielding is  security and accreditation compliancy. From an operations perspective, this breaks down into a number of different smaller challenges to consider and improve upon. For instance, maintaining patched systems and the latest capabilities at the scale of the entire enterprise. Doing this without scheduling downtime or even having to notify the end users at all is fundamentally necessary when supporting mission critical workloads.

{{< responsive-figure src="/images/eyes-on-target/Last_Mile.jpg" alt="Continuous Fielding Is Tough" class="right small" >}}

In the past, this was an intricate dance between the developers and the operators. Operators needed to schedule and coordinate patch changes, developers needed to test those changes. There was a lot of back and forth between the groups needed to execute the timing of these patches into operations. By moving the demarcation line to the platform it allows the developers to offload the implementation responsibilities. It allows the operators to standup and test patches uniformly across the application portfolio and then report findings ahead of moving them into operations. Once the team agrees on the confidence of the CVE patch, Operators could move this patch across the entire operations enterprise in a canary style deployment maintaining 24/7 uptime in support of mission critical workloads. The platform enforces an unified governance model through api-level promises to each application within the foundation.

Authentication is offloaded to the Enterprise Identity Provider like ADFS and the platform is authenticated using Single Sign On via SAML. Applications receive an OAuth token back and can secure their protected resources to whatever granularity makes sense within their subject matter domain. This allows developers to test both inside the platform and in isolation prior to pushing. It also offloads the heavy weight portions of security to an already approved solution by security. In the past, the security and IA teams had to do extensive reviews to understand how each delivery would affect the overall security posture of the enterprise slowing down the fielding process. This often required an entire infrastructure support team just to deliver application code.

Understanding the implementation of runtime security cleared several challenges for continuous fielding. However we still had to address platform components and their updates and the new application feature developments. We approached these requirements by focusing on the application bits as the currency throughout the whole delivery process. We separated concerns via clearly defined API level coordination between distributed components. Our underlying release engineering and deployment lifecycle tool chain was defined via statically typed version controlled artifacts. These artifacts were executable and a microservice that is hashed and verifiable by the security team. This gave them transparency into exactly what was running in operations. It has the secondary benefit of environment parity by minimizing configuration drift across platforms. This transparency combined with the necessary security controls implemented and verified all the way to the container left just the changing application bits to continuously accredit.

This was a fundamental change in how accreditation could be done. In order to take advantage of this opportunity, several threat vectors in the application delivery process had to be addressed.

First, we needed a way to verify that only approved developers were able to commit to the official source code repositories. There needed to be secure transport between the source code repository and the build servers. Credentials in the build process that required access to environment resources needed to be restricted to test authority scope only. Before any build executed the commit signatures in the source code repositories needed to be validated.

Next, once in the build process, a minimum set of security scans needed to be a part of every build session. These security scans needed to all be able to execute before failure findings are sent back to developers to minimize build sessions. A security chain of trust needed to be initiated starting with source code through build and release by auditing and signing the resulting binary artifact. From here, an automated, independent reproducible build would be initiated and the resulting hash would be verified against the signed binary. This resulted in a successful push through a secure transport to release repository in which metadata and the appropriate egress rules could be defined and applied later during the push into operations.

Finally, the operations pipeline would pick up the binary, egress rules, and metadata, provision an ephemeral key promise, push the binary to a space within Cloud Foundry and apply the appropriate egress rules. The runtime instance would ask for the authorization token and run time keys. This would guarantee only authorized instances in operations and eliminate configuration drift. This is where the biggest reduction on an order of magnitude in fielding time occurs. This is due to the smaller scope of application accreditation vs. stack/type accreditation, automated security scanning pipeline, runtime authorization and verification of the binary artifact in an independent build process.

So now that we are in operations, how do we improve the run time experience for the warfighter?  Several factors aid in this goal. One, by being on Cloud Foundry all logging and metrics are treated the same. This allows the operators to build enterprise-wide monitoring of several different aspects of the environment. All metrics and logs are event streams and can be drained to a number of different 3rd party tools that allow them to watch aggregates of app/component health across the platform. They also can monitor for any security events, container events, and resource access. Since all the distributed components and application containers adhere to the API contracts enterprise alerting can be activated for relatively minimal effort. This also ensures that future workloads won’t require any understanding of how the event streams work in order to be added to the watch list. These features combined with the built in resiliency and fault tolerance provide a comprehensive self-healing element to the platform. This removes most recovery burdens from the operator. These recovery capabilities include restarting failed system processes, recreating missing or unresponsive VMs, the deployment of new application instances if they crash or become unresponsive, application striping across availability zone and dynamic routing and load balancing all out of the box.

## How Developers Design Mission Critical Apps

The key opportunity for developers is in designing mission critical resiliency into the application architecture by leveraging the distributed nature of the platform. By being able to field to the edge, you get performance improvements in end-user latency and transfer speed. This is due to a reduction in lag by eliminating the long haul physics. This will be especially evident in the increase in transfer speeds from imagery and command-and-control applications due to proximity of the provisioned resources.

The distributed platform has several components built-in that are designed to work across geographic boundaries. Applications deployed to the platform can now be evolved to take advantage of the platform level high availability and resiliency. This combined with the wan level caching technology can support the end user operating in both a connected and disconnected manner.

Additional capabilities in the platform include smart routing, service discovery, circuit breaker, data integration and real time processing at scale. These capabilities support multiple approaches to addressing the different mission functions. These include aspects such as the application’s data synchronization strategy, availability and consistency tolerance. These are all important element in designing how the applications will behave during a reduction in capability due to operations within Anti-Access/Area Denial like conditions.

Partial datacenter outages can be mitigated with service discovery and circuit breaker technologies that are native to the platform. Developers calculate latency penalties switching between instances and build this intelligence into the applications combined with Layer 2/Layer 3 Quality of Service optimizations for data prioritization in degraded environments. Finally we're beginning to explore the expected behavior in fail-over scenarios in the case of a full data center outage. The ability to exercise the application resiliency on a monthly, weekly, daily basis is important especially once the application is fielded. Application switch over to an available data center and all the elements within the application will need to account for this change such as routing, storage for recovery of state, and data.

_Next in our Challenges in National Security Delivery series we will discuss a few related topics in more detail. In part 2, [**Watching the Vapor Trail**](http://pivotal-cf-blog-staging.cfapps.io/post/watching-the-vapor-trail/), we cover how we fit our user-centric software design model into the DOD paradigm. In part 3, [**Securing the Perimeter**](), we cover how we are working to ensure chain of custody in the Continuous Integration/Continuous Delivery application pipelines. Finally in part 4, [**We the Few**](http://pivotal-cf-blog-staging.cfapps.io/post/we-the-few/), we talk about critical team compositions for Day 2 platform operations._
