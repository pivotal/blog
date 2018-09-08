---
authors:
- tyacovone
- loakley
- jvigil
- kmacoskey
categories:
- BOSH
- Agile
date: 2018-09-07T14:30:22Z
draft: true
short: |
  Leveraging a singular BOSH director to manage Concourse for multiple teams
title: Concourse as a Service and Multi-CPI
image: /images/multi-cpi.jpg
---
### **Background**
As the Toolsmiths Team for Greenplum, we are tasked with doing everything in our power to enable other developers within the org.  When this mission statement is actualized, it often leads to infrastructure management – from IaaS configuration to deploying and maintaining Concourse.

### **Prior Patterns**
One of our central responsibilities is the maintenance of two Concourse deployments: one for compiling and testing production code, and one for development. All teams within the GP org are free to use these shared Concourse deployments to create and iterate on custom pipelines. However, Greenplum teams often need additional customizations in network configurations or compute regions that a shared deployment cannot provide. Additionally, the ability to track individual teams’ cloud spend at a granular project level improves the organization’s ability to predict costs and allocate resources. In any of these cases, team-specific Concourse deployments and corresponding GCP projects are required. 

Historically, this problem was addressed at the team level. When a team found that shared deployments no longer suited their needs, they would have to create a self-titled GCP project, spawn a BOSH director within this project, then leverage this BOSH director to deploy a custom Concourse instance.

### **Pain Points**
Unfortunately, team-managed BOSH deployments led to a number of issues across the organization, the first of which revolved around inefficiencies in the development process. When a team is tasked with standing up their own Concourse deployment, there is an implicit assumption that at least one member of that team is familiar enough with BOSH, Terraform, Concourse, and GCP to successfully launch a Concourse instance. Even if this assumption is correct (which is often not the case), the engineering effort required to accomplish this task could be better spent developing features more closely aligned with their team’s core competency.

Additionally, expecting teams to handle the creation of their own Concourse deployments naturally leads to significant divergence in implementation. In this state, Concourse/BOSH version updates become rare occurrences, as they require both time and sufficient context to execute. 

### **The Solution**
To reconcile these difficulties, we chose to draw a line between the Concourse deployments themselves and their supporting infrastructure. Offering ‘Concourse as a Service’ (CONCaaS) means that our team claims responsibility for the creation and maintenance of any custom Concourse deployment. The expectation of the team requesting the deployment is then limited to solely Concourse knowledge. By removing familiarity with BOSH, Terraform, and GCP from the scopes of other dev teams, they are able to go about creating and managing their own Concourse pipelines without being burdened with the overhead costs of supporting the deployment.

This shift towards CONCaaS leveraged a new pattern of BOSH infrastructure management, called Multi-CPI. In essence, this pattern utilizes a singular BOSH director to create and manage multiple Concourse deployments within different GCP projects (see image below). The complexity of managing shared infrastructure and one-off deployments is greatly reduced by using this centralized point of contact with a global view of GCP projects. _[Technical blog post coming soon]_ 

{{< responsive-figure src="/images/multi-cpi.jpg" class="center" >}}

### **Multi-CPI: A ‘Wings’ Comparison**
For those familiar with the Concourse development team’s usage of one large, shared Concourse deployment (called Wings), we’d like to highlight a few key distinctions. Unlike Multi-CPI, Wings utilizes one Concourse deployment, existing within one GCP project, and then extends this deployment to accommodate the needs of various teams. This “one size fits all” approach is quite the opposite of Muli-CPI, where we employ our global director to create a unique Concourse deployment within a corresponding GCP project on a team-by-team basis.

Both solutions draw a similar line in terms of which components are managed by the ‘providing team’ and the ‘customer team’, however by virtue of Wings placing all their ‘customers’ in the same Concourse bucket, there are limitations that are inherently placed on the customization of infrastructure that exists at the GCP project or BOSH level. The team-oriented division of infrastructure that is fundamental to the Multi-CPI solution makes it easier to monitor cloud spend across the org, while also providing greater flexibility in terms of network customization (VPC peering, connecting external workers, etc).

### **Current Status & Beyond**
We’re currently in the process of migrating existing GCP projects and their associated deployments to the ‘singular BOSH director’ pattern, since this consolidation of management furthers our ability to offer CONCaaS. Thus far, there are 11 BOSH deployments being managed under the global director, with 9 of the 11 representing Concourse instances that previously fit the 1:1:1 pattern of ‘director-project-deployment’. This includes the shared Prod and Dev deployments, 7 team-specific deployments, and two instances for monitoring and reporting.

All deployments managed by our global BOSH director are reporting VM and Concourse metrics to an InfluxDB instance. We deployed this database instance alongside a Grafana instance using the global director, such that we can monitor all managed infrastructure from a centralized location. 
Moving forward, we hope to strengthen the Multi-CPI pattern by storing all relevant credentials and secrets in a secure external location, such as CredHub or Vault. In addition, we intend to extend support to AWS in order to give our global director the ability to deploy and manage necessary infrastructure within both cloud platforms.

