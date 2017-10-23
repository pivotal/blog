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
date: 2017-09-14T17:16:22Z
draft: true
short: |
  This blog post explores how enterprises can reduce waste and continuously experiment leading to the product evolution and effective use of CAPEX to realize the true ROI Value of cloud native with Pivotal.
title: Continuous Market Disruption
image:
---

The key to Continuous Disruption of both the marketplace and your competitors starts with the first principal in the Agile Manifesto.

> Our highest priority is to satisfy the customer through early and continuous delivery of valuable software.

What is the _value_ of overhauling the software delivery culture, replatforming and modernizing application workloads, greenfield etc. Or better yet _WHY_ are we doing this? As you work in life, you need to understand this. If you can't answer that question, then should evaluate why you are spending time on that activity. How does one quantify the real value of Cloud Native and the value-add that a Platform like Cloud Foundry brings to your organization's strategic objectives. In this blog post we dig deep into the Why and How of cloud native ROI with Pivotal Cloud Foundry and the Pivotal Way .

What if OPEX reduction isn’t the true promise of the conversation. What if we move the conversation forward from the reduction in software capitalization to the effective use of CAPEX. What if we make hypothesis market testing a first class citizen in feedback loops to CFO decision making. What if we validate our hypothesis with the granularity of cloud native microservices architecture. What if we let platform like PCF offload the technical complexity of managing microservices. What if features that don't work get sunset quicker, reducing technical debt sooner simultaneously increasing stickiness by continued budget for development and evolution. What if the savings from pruning technical debt early are quickly reallocated to new hypotheses. What if this is the agility we need to respond to innovate in a martket.

## Software as a Cost Center

Lets not think of software delivery as a fixed cost investment based on traditional cost accounting model, where it is treated as transfer cost to the rest of the business. The fallacy here is that as organizations evolve to become software defined enterprises this cost model approach delegates the responsibility for profit to the rest of the company, masking the true business value of continuous delivery in a subscription based revenue-generating model.

Treating software as a cost center leads to the CFO and CTO to start thinking of cost cutting measures i.e. the tendency to reduce the overall OPEX before exploring how to increase effective uses of CAPEX for future investment. OPEX has a hard floor at $0 and a real floor of some minimum investment in people and infrastructure to push an app into production, manage, maintain, and realize revenue from it. For example, if my IT cost is $100K, I can’t save more than that, so the max ROI is $100K and in reality, even less than that. This truth clearly points out that the cost cutting path to increasing revenue is both shortsighted and an exercise in futility from a procurement strategy perspective.

[{{< responsive-figure src="/images/continuum.jpeg" class="center" caption="Beyond the Buzz Words https://youtu.be/h0g044IWtTA by Keith Strini, Duncan Winn, Sean Keery">}}

## Software Capitalization

#### CAPEX
Capital Investment is defined as the costs involved in creating the working set of stories for the microservices used to implement the bounded context of the feature. Any upfront activity conducted by the business to generate ideas for the bounded context plus any validation, such as market research, focus groups, prototyping, usability studies, UI/UX design, business re-engineering, requirements engineering, and analyst

#### OPEX
Operating expenditures incurred during the development and deployment of software incurred on an recurring basis. Simply the cost of doing business.  

For a full understanding of software capitalization, CAPEX and OPEX check out these articles

- [Why software capitalization can be wasteful](https://www.cio.com/article/3150163/it-strategy/why-software-capitalization-can-be-wasteful.html)
- [CapEX and OpEx](http://www.scaledagileframework.com/capex-and-opex/)
- [Why Should Agilists Care About Capitalization](https://www.infoq.com/articles/agile-capitalization)


## Reduce Release Cycle Time To Meet the Pace of Innovation  

You can speed up release cycles with a two-phased approach:

 1. Maximize software delivery throughput by busting lead times to production getting new features to your users. We look at the value chain from idea to production as a backlog prioritized delivery flow from sprint to production. We thus create a simple value stream to baseline, the time it currently takes your  teams to move changes from concept to production.  PCF optimizes KPIs like [MTTR](https://content.pivotal.io/blog/how-pcf-metrics-helps-you-reduce-mttr-for-spring-boot-apps-and-save-money-too),  MTBD, release frequency, mean number of hosts simultaneously receiving updates, number of patched CVEs, number of Support Tickets, QA costs & cycle time.

 2. Convert existing teams into XP cross-functional teams. Remove the “last mile” to delivery by injecting it into each delivery team’s responsibility sphere of control. Practice continuous improvement within each delivery team until all of the constraints move out of the software delivery team and move into the market i.e. Sales and Market Segmentation Analysis.

## Predictable Velocity at Reduced OPEX

Pivotal Cloud Foundry aids in an initial reduction in OPEX through automation, resource consolidation and software reduction. These savings manifest themselves in the form of
 1. Increased *Speed* of environment setup and consistent release management practices and day 2 operations  
 2. Better *Stability* of apps with Blue/Green canaries, Resilience and self-healing
 3. Increased *Scalability* with dynamic routing and on-demand auto elasticity
 4. Enhanced *Security* with the ability to rotate, repair, repave and automatically patch VMs and apps

PCF creates the fundamental building blocks for reducing your wasteful software delivery CAPEX and maximizing it for future investment.In the initial transformation phase we increase throughput - defined as the value of the delivered user stories. The value is the sales price (or budget) less any direct costs such as middleware and operating expenses involved in delivery and deployment, licensure, and hardware. This is where transforming your team into cross-functional delivery units and use of PCF plus Continuous Delivery pipelines, gain the initial and sustained reduction in OPEX.

The sum left after direct costs are subtracted is the Throughput value of the delivered Stories. Any direct costs that can be attributed to the commissioning of working software in this time period must get deducted. The remainder is the True Basis Throughput value.

Calculating the ROI after our initial Platform Phase I and II Dojos and Application Transformation engagements  looks like this:

```
ROI (iteration) = ( T(iteration) – OE(iteration) ) / I (iteration)
ROI (release) = ( T(release) – OE(release)) / I (release)
ROI (quarter) = ( T(quarter) – OE(quarter)) /I (quarter)
```

{{< responsive-figure src="/images/cloudroi.png" class="center" >}}

OPEX reductions can occur at the completion of the Platform phase I/II dojos and application transformation engagements. We can measure this by leveraging the PCF and Pivotal tracker instrumentation to understand the feature velocity of your new delivery teams.

The next significant step is how effectively agile we can help you transform. We do this via our app transformation, and managed operations phases. We perform a [SNAP](http://cloud.rohitkelapure.com/2016/10/snap-analysis-of-applications.html) analysis of the existing portfolio with a focus on efficient CAPEX/max revenue generation for all future deliveries.

Why is this so effective?

> “Evaluating well-designed and executed experiments that were designed to improve a key metric, only about 1/3 were successful in improving the key metric” ...	Online Experimentation at Microsoft   -Kohavi

This means that with the nature of new feature development, two thirds have zero or negative impacts on our business.

## Pivotal Cloud Foundry Enables Rapid Iterative Hypothesis Driven Development

We enable, through the platform, your lines of business to hypothesize, test and receive immediate feedback from users. Teams can provide decision makers effective indicators for making sound investment decisions in a continuous fashion and minimize the lost revenue from missed market opportunities. This has the additional benefit of minimizing your maintenance footprint by distilling your applications complexity (OPEX) and by helping delivery teams focus on only those features that are wanted (Efficient CAPEX) thereby allowing you greater velocity and investment budgets for future feature additions that resonate more strongly with your user base.

This is the value proposition of the cloud native architecture design and microservices as the fundamental building blocks. By demarcating bounded contexts and implementing subdomains as a composition of microservices, you fundamentally change the economics of software delivery. This approach simplifies the delivery and releasability aspects, which reduces the overall risk and cost of delivery. Compartmentalizing the new features released as microservices minimizes the potential ripple effect across the architecture.

Our true value proposition is what you effectively target with your CAPEX and reduced time to market necessary to acquire all future revenue generations. The initial transformation phase also provides a measurable tangential savings in OPEX that delivers a quick “prove it” win. This, however, should not be the primary focus of your procurement motivation for Pivotal especially, since you may not currently be burning through money (OPEX/CAPEX) due to wasteful processes. You will appreciate that every company, by the nature of market competition, is losing market share and potential revenue because they are not able to react to customer needs fast enough.

## Target Effective CAPEX

 1. Enable your lines of businesses to narrow in on which new features resonate the most with your users through continuous experimentation via the platform and efficient delivery model. We enable developers to do this by utilizing the platform to do hypothesis testing (Blue/Green and multi-variate A/B testing) with every new feature roll out leading to an overall revenue.App Modernization helps achieve this velocity and enables teams to practice HDD with frequent feature releases.  

  {{< responsive-figure src="/images/adventure1.png" class="left" >}}
  {{< responsive-figure src="/images/adventure2.png" class="right" >}}

  The above images illustrate how a new world of customer understanding can be derived by instrumenting the highest bounce rate microservices with gamification to understand motivation and intent. We can understand what is most valuable to your product through B/G deployments that help isolate the attraction and understand how to expand the attraction to other areas in the product. A number of experiments can be run with UI/UX Heat Maps combined with A/B with Navigation and Design Layout Variations to determine the threshold  that signify the conversion tipping point and measure impact through the entire funnel.

 2. Create a team oriented understanding of how each modernization candidate affects revenue measured by removing ineffective features and adding synergistic ones. Frame the portfolio into those candidates that are revenue generating and those that are business critical. For business critical apps a secondary decision filter is applied as to how its modernization yields agility to those apps that the business critical application supports.  If, by increasing this business critical application’s agility, we correlate a greater yield in user retention or growth, reduction in user acquisition cost, or reduction in churn, then it is a viable candidate, if not, then not. We must continuously holistically evaluate how current Application Modernization investments affect the increase or decrease in your revenue generation with effective CAPEX. Each investment slice is connected to a business value that is visible.

For instance we can directly connect easily measured business value in a revenue generating service via a subscription model in which we can calculate effectiveness by how many new subscribers are attracted to the service. Correlated indicators like number of subscribers, subscriber growth, cost of acquisition, churn rate are used to determine how many features should be included in future releases by monitoring the ROI. If it is falling, less investment in future releases to maintain current ROI or if ROI is falling and Churn is increasing it is an early indicator of consumer confidence and more investment may need to be spent on the quality of the requirements temporarily reducing the current ROI with hopes of stimulating higher revenues later.

## Summary - Cloud Native ROI
Progress on the the Cloud native continuum with the practices of waste reduction and continuous experimentation on the Pivotal Cloud Foundry Platform will lead to  effective use of CAPEX and a meaningful reduction of OPEX in a software defined enterprise.

---

## Disclaimer:
**The authors have no formal training or accreditation in accounting. The treatment of software costs and potential for capitalization vary by country, industry, and individual company policy.** Each enterprise is responsible for the appropriate implementation of financial accounting for capitalization of development costs.

---
