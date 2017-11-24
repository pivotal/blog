---
authors:
- kstrini
- rkelapure
categories:
- App Transformation
- Org Transformation
- Greenfield Development
- Modernizing Legacy Workloads
- Mission Critical Development
- Continuous Fielding
- Pivotal Cloud Foundry
- User Centric Development
date: 2017-11-21T17:16:22Z
draft: true
short: User Centric Design in the DOD
title: ⌒ ‿ Watching the Vapor Trail
image:
---

{{< responsive-figure src="/images/watching-the-vapor-trail/kpi.png" alt="Scout Sniper Synchronization" class="center small" >}}

**Effective Operational Agility**

> “… speeding up the delivery of innovation while maintaining technological superiority in order to maximize the warfighter’s advantage.”
> - RADM Lewis

### Problem Space

Our DOD customers are now facing barrage of asymmetric threats in completely different domains (Cyber, EW, A2/AD, Space). These threats are originating from all over the world and are all evolving at different speeds. In the DOD acquisition field, they are charged with delivering the capabilities necessary to counter these threats. However, they are stymied by their organization around the assembly line designed to counter the force-on-force symmetrical threat of the past. 

This organizational constraint is so pervasive hyper normalization has created a culture in which this is accepted as “the way”. We found that their enterprise architectures, team structures, contract requirements and competing priorities constrained us from being as flexible as what they articulated as mission desires. The standard design, acquisition and implementation and accreditation processes always seemed to get in the way of our ability to move as quickly as wanted when delivering foundational services and mission applications. When engaging with the existing contracted workforce, contracts were scoped to deliver to an agile methodology but not over the entire lifecycle of the fielding delivery process.

At Pivotal, we were asked by one of our DOD customers to focus on delivery methods that instead focused on mission driven value. In other words, streamlining their traditional delivery process to the field. This is in order to help them maintain the velocity of effective operational agility to outpace the speed of these evolving threats. We immediately saw it as doing our part in protecting our national security and providing our soldiers, sailors, airmen/women and marines a continuous advantage over our country’s adversaries.

This continuous fielding alignment included helping the organization shift from older acquisition methodologies to approaches that evolved along with the changing needs of the warfighter. In our first delivery to a forward theater, increasing the velocity to the edge brought new interesting challenges and exposed hidden technical debt that was accruing with existing programs of record. We were forced to innovate in multiple areas to deal with these hidden complexities. The resultant outcomes helped promote tangential benefits in fiscal responsibility across multiple programs by reducing redundant process, personnel, and technology. It also simplified the overall complexity required in delivering a system of systems enterprise (SOSe). 


### Continuous Fielding

{{< responsive-figure src="/images/watching-the-vapor-trail/velocity_to_the_edge.jpg" alt="The last mile is the hardest" class="right small" >}}

At Pivotal, we hoped this overhauling of how we established continuous fielding deliveries would culminate in a new social development model. In this model, the idea was to increase commercial market forces within the national security space by lowering the barrier to entry. The thinking is that this market would then produce the best value and migrate the greatest innovations to the field with security integrity built into the core of their DNA.

The reason we discuss user-centric software design and development in the context of continuous fielding is due to the fielding of software being the most restrictive and critical constraint. Fielding is what has traditionally sat between developers eliciting user feedback, the idea that software needs to be complete before it can be delivered, and general fear that every release will trigger a new and laborious accreditation cycle.

In the past, this was primarily because fielding required an entire stack scan, security posture assessment, and CVE maintenance program per application or system of record. Usually, the application density per hardware kit was extremely low even with virtualization because of the heavy weight nature of the OS necessary to run VMs. These hardware/virtualization capabilities would still require several supporting personnel to maintain them and then this was multiplied across the warfighter portfolio producing the need for large contractor forces to support them either in theater or in the rear support function. Improving this whole process was the necessary first step in moving to a lighter weight delivery model which would allow us to better handle direct access to our users (warfighter in theater).

{{< responsive-figure src="/images/watching-the-vapor-trail/total_tco.jpg" alt="The Real ROI of the Platform" class="center small" >}}

As you can imagine, we found significant efficiencies in reducing the training, maintenance and sustainment costs by offloading full stack responsibilities to the cloud native platform. This moved us towards our goal of restoring control of IT operations to the warfighter, which would eventually result in a reduction of the deployed contractor force in theater. This in part was due to the offloaded complexity but also equally important, as we will explore in part 2 of this series, was the design approach.

### Warfighter Personas and User Centric Design

We approached the design fundamentally different from the traditional development process of today. We used a focused user-centric process to drive more operator intuitive interfaces and minimize the technical debt of unwanted or obsolescent features from the very beginning of the effort. 

First we began with our Design team conducting a discovery and framing phase despite existing requirements that had been gathered and vetted through some organizational process. This is due to the freshness of the mission needs, the frequency at which they change, and spinning up in the problem space for the team. We found that this disconnect is probably the primary nexus of the current problem of technical obsolescence in the DOD today. From here, we integrate the warfighter needs from our Design team with the business and feasibility needs we vet them against in our Product Management and Engineering teams. These 3 groups create a balanced software delivery team, in which our DOD pairs are each a part. These are usually horizontally scaled, collocated, flat management structures. Each team remains small and focused on specific user-centric capabilities through a shared context and team ownership of the implementation decisions being made.

{{< responsive-figure src="/images/watching-the-vapor-trail/warfighter_centric_design.jpg" alt="Eliciting Feedback and Adapting" class="right small" >}}

These small teams give us a strong basis from which to prioritize the work we did via warfighter-persona driven stories. To give you an idea on the difference in approaches, functionally our tool was responsible for the exact same mission as another recently modernized fielded system. However, we were able to identify issues at the operator level, like their inability to fully control the data behind the calculations, that later became major feature sets in the product we helped our DOD customer deliver to them. By approaching it from a warfighter-centric viewpoint we can develop hypotheses based on user research and then validate these solutions in theater based on user testing. This research is done through a lot of user interviews in which there are initial problems recorded and then validated in follow up interviews with other users. These validated user problems the serve as the basis for the ongoing implementation iterations.

We also spent a lot of time preparing and working off of datasets that were representative of reality rather than a generalized model that would be exercised by mocked data.  This affected everything from the basic design of the visualization down to how many pixels we had to shave off to make sure the representative data set fit on screen.

This attention to detail and level of collaboration had an additional effect on the end users. For the first time warfighters chose how the UI/UX would work. This led to a shift in their training focus from the tools to mission functions (C2/ISR). This also fostered immediate adoption of the tools and the design methodology because their feedback showed up the future software releases.

{{< responsive-figure src="/images/watching-the-vapor-trail/xp_tdd.jpg" alt="Pairing in Everything To Be Successful" class="right small" >}}

Another area that was a break from the DOD norm was the fact that we used no “testers” or “test organization”. This was due to the fact from an operational perspective we were receiving direct feedback from the warfighter and we approached all development from a Test Driven Design (TDD) approach. What this meant was that there were no testers only developers. All testing was automated, from unit and integration to journeys and acceptance.  

Traditionally, alongside Information Assurance, testing is usually the next biggest constraint to continuous fielding. We elevated this constraint by going beyond the normal unit testing and coverage metrics necessary to meet the minimum requirements. To do this properly, we constructed a whole suite of integration tests based on real user tasks. These are called journeys and simulated full user interactions end-to-end through out the application. By approaching it in this way, it offloaded tasks that normally created a heavy burden on the manual testing done in the acceptance phase. This, combined with the code quality from pair programming, was probably the single biggest global improvement to the fielding timeline. This had secondary benefit in that testers were trained as developers contributing to the code base. This instantly increased feature development capacity or reduced the required budget since no test group needed to be brought onboard. In addition, test goals were completely aligned to the software delivery, which doesn’t regularly happen when it’s outsourced to a test organization.

{{< responsive-figure src="/images/watching-the-vapor-trail/test_automation_pyramid.jpg" alt="Automated Test Harness For Deployment Success" class="right small" >}}

Returning to the code quality aspect of the effort, within the development-testing phase rework is the biggest budget consumer. In our effort, all developers worked in pairs. We discovered that pairing minimized the time that developers spent on blockers that prevented progress. This, in turn, had a team wide effect on overall productivity. This is in part due to the fact that over time with two sets eyes fewer defects were found. At first, the idea that we halved our workforce was met with resistance. However, after observing the effect over a few weeks, what emerged was that a new continuous inspection process was happening. This process was reducing the rework due to missed errors somewhere between 25-50%. When you combine this idea that, in reality, individual developers are productive for about 5.5 hours in an 8-hour day, pair programming essentially was a no cost improvement. So if this was a wash, why the importance in switching to it? It was pair programming’s ability to form a resilient team. 

Resiliency, in this case, has multiple points. The first point was substitution, the ability to rotate new team members in and old team members out. We currently are operating in pairs with service men/women; they aren’t dedicated full-time software development, platform architects, or devops military occupational specialties (MOS) billets. As a result there are no formal schooling opportunities to develop the career fields or billets focused on how to do quality software deliveries at scale and compliant with Federal Acquisition Rules (FAR).  This mean our team was losing members on average of once a month as they returned to their “day jobs”. On the positive side we were gaining about 2, which leads to the second point, a minimum floor. Our team’s ability to spin up new members into productive contributors to code baseline was about 2 weeks. This was due to exceptionally efficient skills and context transfer that occurs during pairing. 

The result was a consistent velocity of learning to be productive within the team no matter the rotation tempo or skill level of the new individual. This combined with user-centric approach and continuous fielding goal led our team to an initial fielded delivery release of less than 5 months. This included the inception of the original idea, user interviews, development/test, Information Assurance, and fielding to the group in the active CENTCOM theater. This delivery had an immediate impact on operations, including reducing the number of personnel required to support that mission function. Now the goal with every delivery going forward is to develop the type of synergy found between sniper and spotter. Where the needs of our warfighter are understood intuitively through repeated practice and direct communication. Ultimately, with the result being efficient shots on target every time.

_Next in our Challenges in National Security Delivery series we will discuss a few related topics in more detail. In part 3, [**Securing the Perimeter**](), we cover how we are working to ensure chain of custody in the Continuous Integration/Continuous Delivery application pipelines. Finally in part 4, [**We the Few**](http://pivotal-cf-blog-staging.cfapps.io/post/we-the-few/), we talk about critical team compositions for Day 2 platform operations. If you missed part 1, [**Eyes on Target**](http://engineering.pivotal.io/post/eyes-on-target/), it describes the overview of the entire effort_
