---
authors:
- twong
categories:
- Legal Compliance
- Concourse
- License Finder
- Agile Transformation
- Oslo
- osl-ci
date: 2017-07-26T14:31:04-04:00
short: |
  Must license auditing always be a burden to a product’s release process? Pivotal tackles this hairy issue at competing ends of the spectrum: implementing more thorough license inspections while also speeding up the time to delivery for our software.
title: Open Source License Compliance at the Speed of Your Code
image: /images/the-village-lawyers-office.jpg
draft: true
---

{{< responsive-figure src="/images/the-village-lawyers-office.jpg" caption="Depiction of conventional open source license review process" alt="painting of a lawyer's office from a previous age" class="center" >}}

When people discuss agile development, the usual topics come to mind: CI/CD, microservices, and devops. However, many enterprises also have to take into account another facet of creating software: license compliance. While it might sound straightforward, open source license (OSL) compliance requires collaboration between multiple internal teams and involves several important steps. Each step presents challenges that could potentially slow down the release cycle. I’ll explain what they are, the problems Pivotal encountered with our old workflow, and what our new strategy is.

OSL compliance involves:

1. Finding out what dependencies (and nested dependencies) are in our software
2. Discovering the licenses and copyrights adopted by those dependencies
3. Performing a legal review to make sure the terms of those licenses are acceptable to use
4. Making available that list of licenses along with the software release

So far so good, but with the old workflow, several pain points became apparent.

## The Old Way
License compliance used to require close involvement by the product managers (PM) of the individual product teams. Before releasing their software, the PM would have to coordinate with the engineering team to organize a spreadsheet containing all of the project’s dependencies and their respective licenses and copyrights. It was a huge hassle and larger code bases needed a higher level of participation. 

The spreadsheet of license data was then passed to the OSL team, who cleaned up the information and checked for gaps in the audit. Afterwards, the list was exported to a legal review application as support tickets that the legal review team has to examine. If the legal review team found a blacklisted license, a lengthy conversation would take place between them and the product team about how to remove the related dependency.

The process had built-in bottlenecks and certainly wasn’t agile. Product teams had to waste time regularly generating reliable dependency reports, taking focus away from feature work. PMs had to schedule their dependency audits after a code freeze, which means close to the end of the release cycle — generally a busy time for a PM. At such a late stage, if the legal review team discovered an issue, it was very likely to cause a delay.

{{< responsive-figure src="/images/osl_old_process.jpg" alt="a timeline of the old process, showing that legal review happens after development, holding up the product release" class="center" >}}

Dealing with unexpected license problems had product delays in the past. It was nobody’s fault, but the issue required a group effort to come up with a solution.

## A Vision of Agility
When tasked with creating a new workflow, the OSL team knew we had to create a system that could reliably discover licenses for the majority of our software. Then, as much as we could, we had to remove the human aspect of running this system so that it was always up to date with our many changing code bases. Pivotal had to optimize our license review process in the same way we optimized our release engineering process: 

1. Create common tooling useful for the majority of projects
2. Invest in automation
3. Recognize bottlenecks, unblock with agile reorganization

### Build tooling around available Open Source Software

When we relied on each product team to deliver their own software dependency audits, a couple challenges surfaced:

* Each individual team had to learn how to thoroughly identify dependencies, or the OSL team would have to provide guides
* Compiling an exhaustive list of dependencies became tedious work when a team doesn’t have a robust audit workflow already set up
 
To tackle these issues, the OSL team decided to build a utility called `osl-ci` that could be used to scan any software project and generate a reliable list of dependencies and licenses.

To create `osl-ci`, we incorporated some useful OSS tools including [License Finder](https://github.com/pivotal/LicenseFinder) and the [FOSSology toolset](https://github.com/fossology/fossology). Originating from Pivotal Labs, License Finder is a tool that utilized all manners of package managers to output a project’s declared licenses. FOSSology contained programs that matched individual project files against a database of known licenses and copyrights. Adding to these tools, we created logic to support the layout of Cloud Foundry specific release artifacts such as BOSH releases, blobs, and stemcells.

With `osl-ci`, anyone in the organization could run a reliable audit of their software without much guidance. Whether the code base used Golang, Node.js, Java, or any other number of languages, we could generate a list of dependencies and license in a standard format, comprehensive enough for our legal review process.

### Continuous License Compliance

Even though we created a great utility to scan for licenses, there were still problems around the /release process/ that created foreseen delays at the tail end of a team’s release schedule:

* When teams were busy building and releasing software, dependency reviews were often pushed until the last minute, jeopardizing the release date
* Coordinating license scanning efforts of every product team would require a lot of overhead effort for the OSL team

To solve this problem, we began treating license scanning the same way we treated integration tests — codifying them in continuous integration. Using [Concourse](https://concourse.ci), the OSL team set up pipelines that observed changes in the code repos of every Pivotal product. Every time there was a code change, it would automatically initiate a license scan and the resulting list of dependencies and licenses were sent for later processing. This early-and-often style of automated scanning reduced the burden for products teams and the OSL team.

{{< responsive-figure src="/images/osl_pipelines.png" caption="The dashboard for the many OSL scanning pipelines — there's one for each product. Sometimes, pipelines go red when there's a problem determining dependencies." alt="a dashboard with many open source license scanning Concourse pipelines, one for each Pivotal product" class="center" >}}

As an added benefit, we were also able to take advantage of Concourse’s strengths:

* Side effects of project compilation and package management were kept isolated in containers
* Easy to create dozens of pipelines (one for each product) and use git to manage the configurations and collaborate with other teams
* Predictable behaviour when scaling to large scanning workloads

In the future, we also plan to use Concourse’s [credential management](https://concourse.ci/downloads.html#v330) features to securely share our pipelines and be more flexible when working  closely with other teams.

### Agile Legal Review

Even after setting up automation, there were still the real /human/ bottleneck of legal review. In order for the OSL file to be generated, a legal representative still has to go through each dependency and its corresponding license and officially sign off on their use. There were numerous challenges with this step:

* The legal review process couldn’t be automated (and couldn’t really be sped up except by adding more legal reps)
* Legal review is a necessary part of a product’s release, but it was always one of the very last steps, raising the risk of last minute delays
* Communication between the product manager and the legal review team happened during a very busy time in a product’s schedule
* Review team’s own backlog was often “bursty” where a lot of review work came in at once followed by a quiet period

Of all the stages in our workflow, the legal review process was the most challenging the evolve but could potentially yield the most time savings. We recognized that the this was not just a technology problem, but instead stemmed from stiff requirements relating to legal compliance. Solving the problem would require the type of agile transformation that we help our customers go through.

Without reducing the thoroughness of our legal review, we took some steps to make the process more agile. To start, we created an app called Oslo which presented a view of every Pivotal product and all the licenses and copyrights within these products. The app continuously received new information from the automation pipelines discussed in the previous section. If a blacklisted license ever came into the system, it would be automatically flagged, and a notification was sent to the OSL team. This shortened the time before a dialog could be initiated with the product team and reduced the back-loading of potential delays caused by these conversations.

{{< responsive-figure src="/images/oslo.png" caption="A recent beta build of Oslo" alt="a screenshot of Oslo" class="center" >}}

Oslo is still a work in progress and we’re continually experimenting with it to find inefficiencies in our workflow. With it, the legal review team will be able to preview the licenses of an upcoming product even before a code freeze. They can then more flexibly schedule reviews to be done in advance according to product priority and legal resource availability.  This more agile style of legal review will help reduce the risk of unexpected delays and put less stress across the organization.

{{< responsive-figure src="/images/osl_new_process.jpg" alt="a timeline of the new process, showing that legal review occurs concurrently with development, no longer blocking release" class="center" >}}

## Conclusion
Legal review is an important concern for many enterprises but unfortunately it’s easy to forget its effects on the release schedule. Furthermore, a rigorous legal compliance process will never be the first target of an agile transformation. However, successfully modernizing this rigid workflow allows an organization to release software more regularly, preserve valuable R&D time, reduce liability, and build confidence with their customers.
