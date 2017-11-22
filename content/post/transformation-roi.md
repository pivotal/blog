---
authors:
- kstrini
- rkelapure
categories:
- App Transformation
- Replatforming
- Modernization
- Pivotal Cloud Foundry
- Cloud Native ROI Continuum
- Agile
- XP
date: 2017-10-28T17:16:22Z
draft: false
short: |
  This blog post explores how enterprises can reduce waste and continuously experiment leading to the product evolution and effective use of CAPEX to realize the true ROI Value of cloud native with Pivotal.
title: Continuous Market Disruption
image: /images/experiment.png
---

{{< responsive-figure src="/images/balloon.jpg" alt="OPEX + Experiment = Effective CAPEX" class="center" >}}

**Disruption**

> "... throughout the centuries there were men who took first steps, down new roads, armed with nothing but their own vision."
> - Ayn Rand

## Is it really faster we want? ##
What is the _value_ of going faster if we are not sure its achieving velocity ? When we set out to overhaul our customer's software delivery flow, we often find ourselves using speed and velocity interchangeably. There is a very distinct difference between the two terms - that of a vector. In software delivery it's important that the vector is in the direction of user delivered working code. However, there is more subtle understanding of speed vs. velocity in software delivery that actually resonates with a customer. This distinction is important in understanding how to quantify the real value of this cloud native movement and the opportunities a platform like Cloud Foundry facilitates in the managing of its complexity in order to discover _effective_ ways to resonate with new customer bases. It's time to stop framing the platform as just another datacenter consolidation effort to reduce our OPEX. 

The true promise in adopting a unified platform strategy is in moving the conversation forward from a reduction in OPEX to the effective use of CAPEX. We can now do this by making continuous experimentation a first class citizen in feedback loops to the CFO's internal investment decision-making process.  We can now show the decision makers in the company how we can reduce our software's technical debt sooner by sunsetting efforts that aren't producing in the market and removing them from the products code base. This has a twofold effect of freeing up resources and increasing the stickiness of our service offering. CFO's can now confidently approve continued budget for development and evolution of those features resonating in the market. The savings from pruning this technical debt early can be quickly reallocated to new experimentation allowing us the agility to respond to new market directions.

The key to this continuous disruption of both the marketplace and competitors starts with the first principal in the Agile Manifesto with a particular focus on satisfying and valuable.

> Our highest priority is to satisfy the customer through early and continuous delivery of valuable software.

In this blog post we dig deep into the Why and How of cloud native Return On Investment (ROI) with Pivotal Cloud Foundry and the Pivotal Way .

## Software as a Cost Center

Let's begin by changing our thinking of software delivery as a fixed cost investment based on the traditional cost accounting model. Currently, it is usually treated as transfer cost to the rest of the business. The fallacy here is that as organizations evolve to become software-defined enterprises this traditional approach delegates the responsibility for profit to the rest of the company, masking the true business value of continuous delivery.

Treating the DevOps team as a cost center is what leads the CFO and CTO to start thinking of cost cutting measures vs. how to penetrate and capture new markets.  This is why we see the tendency to reduce the OPEX before even exploring how to increase the overall effectiveness of CAPEX for future investment. For example, a very common initial conversation we see with our customers is how to help them reduce their OPEX. The problem with this approach is that operations has a hard floor at $0 and a real floor of some minimum investment in people and infrastructure to push an app into production, manage, maintain, and realize revenue from it. For example, if my DevOps cost is $100K, I can't save more than that, so the max ROI is $100K and in reality, even less than that. This truth clearly points out that the cost cutting path to increasing revenue is both shortsighted and an exercise in futility from a procurement strategy perspective.

{{< responsive-figure src="/images/continuum.jpeg" class="center" caption="Beyond the Buzz Words  https://youtu.be/h0g044IWtTA by  Keith Strini,  Duncan Winn,  Sean Keery">}}

Pivots [Keith Strini](https://www.linkedin.com/in/keith-strini-a3bb1a6/), [Sean Keery](https://www.linkedin.com/in/zgrinch/) and [Duncan Winn](https://www.linkedin.com/in/duncan-winn-3019506/) spoke on *Beyond the Buzzwords - Wave To Turn Trends into Profit* at the recently concluded Cloud Foundry Summit 2017 Berlin. Checkout their [video](https://www.youtube.com/watch?v=h0g044IWtTA&list=PLhuMOCWn4P9hsn9q-GRTa77gxavTOnHaa&index=50) and [slides](https://t.co/loZ7mh0bAf) here to get additional insight into this topic.

_First some definitions ..._

### Software Capitalization

#### CAPEX
Using us as the example, Pivotal is a Test Driven Development (TDD) eXtreme Programming (XP) shop. This means our unit of work is purely story driven. This means we define Capital Investment as the costs involved in creating the working set of stories. This scope is usually what it takes to implement the completely bounded context of a feature. This cost includes any upfront activity conducted by the business to generate ideas for the feature plus any validation, such as user centric discovery and framing, prototyping, UI/UX design, business reengineering, story creation, user centric feedback, and analysis.

#### OPEX
Operating expenditures are what are incurred during the development and deployment of software on a recurring basis. This is understood as simply the cost of doing business.  

For a full understanding of software capitalization, CAPEX and OPEX check out these articles

- [Why software capitalization can be  wasteful](https://www.cio.com/article/3150163/it-strategy/why-software-capitalization-can-be-wasteful.html)
- [CapEX and OpEx](http://www.scaledagileframework.com/capex-and-opex/)
- [Why Should Agilists Care About Capitalization](https://www.infoq.com/articles/agile-capitalization)
- [Agile management for software engineering: Applying the theory of constraints for business results](https://www.amazon.com/Agile-Management-Software-Engineering-Constraints/dp/0131424602)

## Reduce Release Cycle Time To Meet the Pace of Innovation  

You can speed up release cycles with a two-phased approach:

1. Maximize software delivery throughput to production by getting valuable features to your users. We look at the value chain from idea to production and create a simple value stream to baseline i.e. the time it currently takes your  teams to move changes from concept to production.  PCF optimizes for KPIs like [MTTR](https://content.pivotal.io/blog/how-pcf-metrics-helps-you-reduce-mttr-for-spring-boot-apps-and-save-money-too), MTBD, release frequency, mean number of simultaneous container updates, number of patched CVEs, number of Support Tickets, QA costs & cycle time.
2. Convert existing teams into XP cross-functional teams. Remove the last mile to delivery by pulling it into each delivery team's sphere of control. Practice continuous improvement within each delivery team until all of the constraints move out of the software delivery team into the market.

## Predictable Velocity at Reduced OPEX

Pivotal Cloud Foundry aids in an initial reduction in OPEX through automation, resource consolidation and software reduction. These savings manifest themselves in the form of

 1. Increased *Speed* of environment setup and consistent release management practices and day 2 operations  
 2. Better *Stability* of apps with Blue/Green canaries, Resilience and self-healing
 3. Increased *Scalability* with dynamic routing and on-demand auto elasticity
 4. Enhanced *Security* with the ability to rotate, repair, repave and automatically patch VMs and apps

PCF creates the fundamental building blocks for reducing your wasteful software delivery CAPEX and maximizing it for future investment. In the initial transformation phase we increase throughput - defined as the value of the delivered user stories. The value is the sales price (or budget) less any direct costs such as middleware and operating expenses involved in delivery and deployment, licensure, and hardware. This is where transforming your team into cross-functional delivery units and the use of PCF plus Continuous Delivery pipelines, gain the initial and sustained reduction in OPEX. The sum left after direct costs are subtracted is the Throughput value of the delivered Stories. Any direct costs that can be attributed to the commissioning of working software in this time period must get deducted. The remainder is the True Basis Throughput value.

Calculating the ROI after our initial Platform Phase I and II Dojos and Application Transformation engagements illustrated below looks like this:

{{< responsive-figure src="/images/cloudroi.png" class="center small" >}}

OPEX reductions can occur at the completion of the Platform phase I/II dojos and application transformation engagements. We can measure this by leveraging the PCF and Pivotal tracker instrumentation to understand the feature velocity of your new delivery teams.

The next significant step is we can help your software delivery transform. We do this via our app transformation, and managed operations phases illustrated in the picture above. We perform a [SNAP](http://cloud.rohitkelapure.com/2016/10/snap-analysis-of-applications.html) analysis of the existing portfolio with a focus on efficient CAPEX/max revenue generation for all future deliveries.

Why is this so effective ?

> “Evaluating well-designed and executed experiments that were designed to improve a key metric, only about 1/3 were successful in improving the key metric” ...	Online Experimentation at Microsoft   -Kohavi

This means that with the nature of new feature development, two thirds have zero or negative impacts on our business.

## Pivotal Cloud Foundry Enables Rapid Iterative Continuous Experiment Driven Development

We enable, through the platform, your lines of business to hypothesize, test and receive immediate feedback from users. Teams can provide decision makers effective indicators for making sound investment decisions in a continuous fashion and minimize the lost revenue from missed market opportunities. This has the additional benefit of minimizing your maintenance footprint by distilling your applications complexity (OPEX) and by helping delivery teams focus on only those features that are wanted (Efficient CAPEX) thereby allowing you greater velocity and investment budgets for future feature additions that resonate more strongly with your user base.

{{< responsive-figure src="/images/prices.jpg" class="right small" >}}

This is the value proposition of the cloud native architecture design and microservices as the fundamental building blocks. By demarcating bounded contexts and implementing subdomains as a composition of microservices, you fundamentally change the economics of software delivery. This approach simplifies the delivery and releasability aspects, which reduces the overall risk and cost of delivery. Compartmentalizing the new features released as microservices minimizes the potential ripple effect across the architecture.

Our true value proposition is what you effectively target with your CAPEX and reduced time to market necessary to acquire all future revenue generations. The initial transformation phase also provides a measurable tangential savings in OPEX that delivers a quick “prove it” win. This, however, should not be the primary focus of your procurement motivation for Pivotal especially, since you may not currently be burning through money (OPEX/CAPEX) due to wasteful processes. However, you will agree that every company, by the nature of market competition, is losing market share and potential revenue because they can’t react to customer needs fast enough.  

## Target Effective CAPEX

{{< responsive-figure src="/images/signalNoise.jpg" caption="Reducing the noise of internal budget waste" class="center" >}}

Enable your lines of businesses to narrow in on which new features resonate the most with your users through continuous experimentation via the platform and efficient delivery model. We enable developers to do this by utilizing the platform to do hypothesis testing (Blue/Green and multi-variate A/B testing) with every new feature roll out leading to an overall revenue.App Modernization helps achieve this velocity and enables teams to practice HDD with frequent feature releases.  

  {{< responsive-figure src="/images/adventure1.png" class="center" >}}
  {{< responsive-figure src="/images/adventure2.png" class="center" >}}

The above images illustrate how a new world of customer understanding can be derived by instrumenting the highest bounce rate microservices with gamification to understand motivation and intent. We can understand what is most valuable to your product through B/G deployments that help isolate the attraction and understand how to expand the attraction to other areas in the product. A number of experiments can be run with UI/UX Heat Maps combined with A/B with Navigation and Design Layout Variations to determine the threshold  that signify the conversion tipping point and measure impact through the entire funnel.

Create a team oriented understanding of how each modernization candidate affects revenue measured by removing ineffective features and adding synergistic ones. Frame the portfolio into those candidates that are revenue generating and those that are business critical. For business critical apps apply a secondary decision filter as to how its modernization yields agility to those apps that the business critical application supports.  If, by increasing this business critical application’s agility correlates to a greater yield in user retention or growth, reduction in user acquisition cost, or reduction in churn, then it is a viable candidate. We must continuously holistically evaluate how current Application Modernization investments affect the increase or decrease in your revenue generation with effective CAPEX. Each investment slice is connected to a business value that is visible.

For instance we can directly connect easily measured business value in a revenue generating service via a subscription model in which we can calculate effectiveness by how many new subscribers are attracted to the service. Correlated indicators like number of subscribers, subscriber growth, cost of acquisition, churn rate are used to determine how many features should be included in future releases by monitoring the ROI. If it is falling, less investment in future releases to maintain current ROI or if ROI is falling and churn is increasing it is an early indicator of consumer confidence and more investment may need to be spent on the quality of the requirements temporarily reducing the current ROI with hopes of stimulating higher revenues later.

## Summary - Cloud Native ROI
Progress on the the Cloud native continuum with the practices of waste reduction, automation and continuous experimentation on the Pivotal Cloud Foundry Platform will lead to  effective use of CAPEX and a meaningful reduction of OPEX in a software defined enterprise.

---

## Disclaimer:
**The authors have no formal training or accreditation in accounting. The treatment of software costs and potential for capitalization vary by country, industry, and individual company policy.** Each enterprise is responsible for the appropriate implementation of financial accounting for capitalization of development costs.

---
