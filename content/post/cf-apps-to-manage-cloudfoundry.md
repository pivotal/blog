---
authors:
- tdadlani
categories:
- BOSH
- CF Runtime
- Operations

date: 2015-11-24T13:23:20-08:00
draft: true
short: |
  Why should you write CF apps to manage a CF installation?
title: How to manage CF with CF apps?
---
## Operating Cloudfoundry using Cloudfoundry applications


#### Need for custom metrics
Being on a team that operates and manages a cloudfoundry installation makes you think about metrics and alerting. You realize the need to collect information from the system as a whole and potentially build new systems that can correlate different pieces of information and present it to the operator in a simple actionable way.

Virtual machines that run CloudFoundry emit BOSH and component specific metrics. These metrics together cover a large portion of metrics needed to run Cloudfoundry independent of the IaaS. How does an operator collect relevant metrics for their CF installation.

#### The gaps
There are no direct ways to get the following metrics from a cloudfoundry installation:

* Capacity planning
* IaaS metrics
* Correlating logs to metrics
* Custom analytics like traffic classification
* ..... and many more

#### Filling the gaps

The most obvious solution to fill these gaps is to write custom monitoring and metrics collection tools that can communicate with your CF installation. The big question for an operator is, where do I run this tool?

We investigate the various options an operator has and what are the pros and cons of each approach independently. The following three options will be discussed below.

* “Operator VM” on the IaaS.
* Custom Bosh release that manages all the “operator” applications
* Cloudfoundry applications


##### Operator VM on the IaaS.

_Pros:_

* Managed by your IaaS.
* Independent from your cf installation.


_Cons:_

* Expensive to maintain: As a operator you will need to implement custom IaaS specific VM monitoring and orchestration.
* Custom dependency management: Any dependencies of the code that you are running will need to be managed by the user.
* Hard to recreate in a new environment on a different IaaS. If the tool works on an AWS instance or AMI, the user would need to configure or recreate a similar machine image for Openstack or vSphere.
* Need to manually manage access control and security groups on the IaaS to communicate to CF components.


##### Custom Bosh release that manages all the “operator” applications

_Pros:_

* BOSH manages the VM lifecycle for you.
* BOSH provides resurrection.
* BOSH release will provided packaged dependencies.


_Cons:_

* Inovles writing a custom BOSH release.
* Maintaining different components of a BOSH release.
* Managing a deployment manifest to deploy the custom "operator" release.
* To deploy every new feature or change to the applicaiton, you need to cut a new final release.
* Need to manually manage access control and security groups on the IaaS to communicate to CF components.


##### Cloudfoundry applications

_Pros:_

* Linearly scalable.
* Health management of application managed by CF.
* Dependencies managed within source code (Gemfile, Godeps, npm)
* Application can leverage cloudfoundry services.
* As an operator the application(s) provide a good litmus test about the state of the CF environment.

_Cons:_

* Need to manually manage access control and security groups on the IaaS to communicate to CF components.

The most relevant solution that emerges from this is that of cloudfoundry applications. The first two approaches need the user to configure security groups for the custom VM through BOSH or otherwise. The CF app approach only needs you to configure CF level security groups. These security groups for the "operator" spaces and orgs can get higher privileges to query a variety of endpoints to get relevant operator specific information.

In conclusion, once you have a working cloudfoundry installation and are responsible for running it, you should be able to trust running an application on it. The application built on the platform makes managing and updating it as simple as a ‘cf push’ with all the benefits of scaling out, load balancing and health management built into the platform.
