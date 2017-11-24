---
authors:
- kstrini
- rkelapure
categories:
- Day 2 Operations
- Org Transformation
- Mission Critical Development
- Continuous Fielding
- Pivotal Cloud Foundry
date: 2017-11-23T17:16:22Z
draft: true
short: Critical Team Composition For Day 2 Operations
title: ✭ ✭ ✭ We The Few
image:
---

{{< responsive-figure src="/images/we-the-few/one-team-delivery.png" alt="Scout Sniper Synchronization" class="center small" >}}

**Team Unity Through Goal Aligment**

> "...a desire presupposes the possibility of action to achieve it; action presupposes a goal which is worth achieving"
> - Ayn Rand

### Problem Space

Mission critical systems are fundamentally different than your average commercial platforms. While it's true that most aspects share commonality with the key tenets desirable in all enterprise environments, workload survivability, in whatever manner that takes, is the number one priority.

In defining our ideal environment within the Department of Defense (DOD) and Intelligence Communities (IC), we must focus on the end game… meeting the mission objectives. To achieve this, we must start from the mission objectives and work from the field back towards development examining all aspects of the delivery process, instrumenting the key constraints, and continuously learning and improving these constraints until we can reach ideal flow along with high survivability. 

Why this is particularly difficult in this vertical is two-fold; no one company or organization owns the delivery and the physical constraints of operating within the environment are particularly difficult. You overlay this with the fact that release engineering is a complex task in itself and the fact that each organization has different interpretation on how to achieve a predictable schedule. In the federal government, programs are incentivized to drive this schedule over performance. This results in little in the way of alignment to the goal of delivering exceptional products.

Coupling these challenges to the speed of the evolving threat and you can intuit how quickly national security deliveries can go off the rails. In part 4 of this series we are going to explore the critical team composition necessary for Day 2 Operations in this vertical. The scope will include how continuous fielding roles can be stratified across the delivery flow to align with the concerns and needs of the development teams responsible for capability development.


### Starting From The End

In order to run in operations you must have full time dedicated resources committed to both run the platform and actively work to improve its resiliency. This is absolutely fundamental in moving the operations from a reactive to a proactive culture. This role is known as a platform reliability engineer (PRE). 

{{< responsive-figure src="/images/we-the-few/pre-mindset.png" alt="Culture Shift To Proactive" class="center small" >}}

PREs are trained to think about all events within operations as existing in one of two phases past or future. When operating under normal conditions, i.e. no current fires to put out, they conduct post mortems on corrective actions used to remove past causes and distill the necessary preventative actions to mitigate future causes. In addition to known cause and effects, there are going to be edge cases, technology limitations, budget constraints that cannot overcome certain situations that will occur in operations. Nevertheless, the PRE will still have to deal with them. So they will also work to put in place adaptive actions in order to help evolve during times of contingency. PREs primarily look at what effects in the past happened from successful adaptations and use this knowledge base to predict future effects from additional contingent actions. This shifts the mindset from waiting for the next fire to what can I do for my environment to prevent fires altogether.

This is accomplished by implementing critical instrumentation starting from the release process into production throughout each application’s lifecycle and finally sunsetting of the capability. From here the PRE balances continuous monitoring of critical service level indicators (SLIs) with active improvement of the platform. This process begins either with the initial canary style or blue/green style of deployment of a release. 

In a canary style, the release is relegated to an isolated org and space, this provides the PRE with an early look at the metrics around the release before it moves into the general resource population of the production org and space limiting the exposure of the enterprise resources. The goal is to uncover resource consumption defects that weren’t discovered early in the delivery cycle that may exhaust valuable production resources. The release runs in the canary state for some arbitrary length of time (usually an hour), basically whatever gives our customer enough confidence to roll it out. In the first part of the canary, we look at infrastructure events and log management monitoring. PREs are particularly sensitive to new errors and increases in error rate changes. We can then do an analysis of the canary metrics and logs as a sample size to compare to the metrics in operations. 

With a blue/green style of deployment the focus is on confirming new feature sets or entire capabilities are appropriate for production release before exposing the entire potential user base to them. It functions as an early feedback loop in production normally used for MVP working with production data but not approved for general release. Again, like canary, the goal is to act upon the continuous monitoring prior to either scaling or exposure to the full user base. We usually default to 10% user exposure but of course it is specific to each customer. This is focused on application performance such as bottlenecks  and potentially any security monitoring that may uncovered vulnerabilities exposed from the new features or compliance gaps. During a blue/green, we are primarily looking at Time to Interactive (TTI). This metric is especially important if it's significantly higher on the new feature set vs the original (blue vs green). Of course we also pay attention to any crash rates that are different from blue to green. Tracing the latency, crashes, increased error rates, or new errors to their root cause helps a PRE understand if additional improvement needs to account for new error cases or if it is necessary to provide feedback on issues to the development teams.
When working in environments with different security classification levels, it is necessary to have at least one pair of PREs per environment. Cross environment responsibility is strongly discouraged due to the constraints being different between each one. 

This works due to another tenet, environmental parity. We will discuss this later in the blog but the synopsis is this, dealing with infrastructure as code, controlling all changes from version control, externalizing environment specific configuration and credentials and executing all of it from automated pipelines.

In addition to these runtime responsibilities, the PRE also functions as the coordination point for all platform status, upgrades, and outages for the environment in which they are responsible. They create and coordinate the platform cadence meeting on either a monthly or quarterly rhythm. They also communicate the capability onboarding cadence for the environment in which they are responsible. These would be topics like developer capability requests, capability updates, and platform roadmap upgrades. They also enforce strict versioning control over the root infrastructure pipelines, their specific environment configuration including sending notifications of outages, new service deployments, and creating and coordinating quarterly resiliency exercises to test application, service, hardware, and PCF stateful/stateless component level failure states.


### Working The Middle

In order to release into operations you must have full time dedicated resources committed to the receipt and execution of each initial release. This is critical in aiding the PRE with proactive capacity planning, shaping of the platform roadmap, and ensuring a consistency in releases that reduces the amount of release failure rates. This role has the all important task of innovating on ways to reduce the cycle time. Cycle time in the national security space includes the delivery through the last mile and into the field. This role is known as a release engineer (RelE). 

{{< responsive-figure src="/images/we-the-few/cycle-time.png" alt="Cycle Time" class="center small" >}}

RelEs function as part developer and part PRE in order to operate the release process which is heavily immersed in automated testing. They oversee all events in moving a release in and out of staging and into operations. This includes the attendance of final initial pre-release demonstration for all release candidate applications to begin a shared understanding of the applications characteristics. This also includes coordinating an initial release date with the rest of the platform team.

Their instrumentation is focused on understanding three main Service Level Objectives (SLOs), Testing Pipeline and Release Health, and Code Maturity. These SLOs are driven by several SLIs but the key ones are Number of Open Bugs when released, Number/Percentage of Successful historical release in the continuous delivery phase (not deployment), and the greenness of the testing pipeline as a whole. That is the downstream view of the monitoring that takes place. The upstream is the pulling of conclusions PREs have made from the canaries and blue/green deployments into production and coordinating feedback access to this operations data to the developers.

RelEs are the safeguard against rushed or incomplete deliveries because their role is to ensure everything necessary to run in production is in the release repository. They confirm complete test harnesses are available and they understand how to execute them. This means ensuring that there is sufficient unit, api, gui, and journey test coverage to vett the mechanics of the application itself. They confirm integration tests work in staging if the system is to reach externally to the platform. In the near future, we are working towards shared and standalone IA control tests that prove compliance has also been met. If custom buildpacks are required, then associated pipelines must be provided to ensure the application continues to operate as expected. 

RelEs also verify the application manifests contains all of the necessary bindings, environment variables, and confirm that targeted services are available in the targeted environment. This is especially critical when dealing with constraints due to different classification levels. RelEs must clearly understand what the current security posture looks like and what assumptions drive that posture. This is primarily due to the fact that they are the pushing entity for the initial release. The RelE has a second area of focus, the knowledge transfer of how to execute an initial release to the platform in a specific environment. 

The reason we are making the initial release distinction is that the RelE actually does all of the above duties while pairing with the developer. The sets of pipelines that form the test harness and continuous fielding process must fundamentally be an enablement experience between the RelE and development teams, as the number of products the RelE is responsible for initially moving will continue to expand. This is the ideal right sizing the delivery team scales. After the initial release, the developers hold the responsibility to operate their capability in operations from that point forward. 

The reason this is a critical difference to understand in the Pivotal/NatSec delivery world is because it implies that the organizations who want to transform their deliveries this way must become a learning organization whose actions are driven by the feedback loops established in the continuous fielding process. PREs and RelEs are constantly assessing what is working and what is not in operations. This drive their decisions that traditionally don’t disseminate into a shared understanding with all of the development teams leading to errors in the future. Since each environment, (especially in this space) is different, transparency and constant improvement is critical in the continuous fielding process. 

### Ending With The Beginning

In order for the platform team to proactively operate, they need comprehensive input on the types of workloads they will eventually be dealing with. These include aspects like types of resource consumption, rough access volume, types of managed service, types of user provided services, external integrations to the platform, etc. In order for developers to embrace this new style of delivery and to truly understand the value in offloading all non-application concerns (IA, delivery, binding, operations) to the platform they need a platform ambassador of sorts. This role is known as an Onboarding Engineer (ObE).

This is typically where the newest members of the platform team begin their experiences. This is the most efficient way to understand what a delivery looks like from end-to-end and gain empathy for the developer’s plight. It also is fundamentally important because they are a member of the platform team which creates an alignment from start to finish with the goals of continuous fielding. The ObE serves as a coordination point for all new development projects. They are responsible for creating and coordinating the initial platform onboarding meeting. 

In this meeting, the elicit information from the developers about the characteristics of the capability they are delivering, the source code repository location they will be delivering from, which operations environment they will be targeting, which platform services they will need, rough capacity aspects (number of projected users, volume of data, etc), current Information Assurance (IA) maturity, need for custom buildpacks, and any third party (non-platform) integration that needs to be supported.

Additionally, the ObE provides information about available environments and their intent, where to look for services differences available between environments and why, how to request new capabilities be added, timelines for these new services to be available, the latest PCF roadmap by environment, responsibility expectations for the developer (test harness, IA, lead times, custom bps, etc), and finally how to triage and where to access feedback for troubleshooting applications in the different environments.

ObEs inform all new efforts of the platform upgrade cadence and serve as the initial knowledge source for all things continuous fielding for each specific customer’s environment. This quickly spins up newer members before affecting operations allowing them more of an initial research role and focused knowledge gap areas to experiment with in sandboxes during bench time between new onboarding efforts.

### In Conclusion

The interaction between these three roles is critical in establishing a stable continuous fielding process. The role scopes are very specific to aide in the scaling of different capability delivery velocities. In a small to medium size volume, one pair per classification environment should be able to support workloads with an established application pipeline promotion process and an experienced ObE and RelE. Obviously, this will not happen in the first week but as the team learns to trust each role to do their job the deliveries will get smoother. With the use of the platform to handle the mundane high availability and healthiness of the platform, we have seen teams with an average size of seven run two different classification single foundation environments. This setup supported quite a large workload in operations with relatively low overhead allowing a large section of the portfolio to be deployed. As the number of environments grow, this team composition can scale with each role independently based on whichever becomes the bottleneck. For instance, adding a new environment may only increase another pair of PREs or a large volume of new efforts may just require an additional ObE if the targeted environments remain the same.

{{< responsive-figure src="/images/we-the-few/team-composition.png" alt="Culture Shift To Proactive" class="center small" >}}

The critical part to getting to stability is to reward a culture of learning by not penalizing experimenting with high probability of failures. This means scheduling regular resiliency exercises in which Developers, PREs, RelEs, ObEs all participate in random destruction across all levels of operations. This in order to solidify that continuous fielding is a “One Team” goal. It helps the team better understand their current fielding gaps, foster better communication by the delivery team as a whole, and grow in a shared fielding context so that there is better knowledge resiliency when pushing capabilities to the warfighter.


_This wraps our Challenges in National Security Delivery initial topics list, if you enjoyed these and wanted to understand the details of how we accomplished a specific area please let us know. We will happily expound upon additional areas of interest. If you missed any of the other parts in the series they are here [**Eyes on Target**](http://engineering.pivotal.io/post/eyes-on-target/), [**Watching the Vapor Trail**](http://pivotal-cf-blog-staging.cfapps.io/post/watching-the-vapor-trail/)_
