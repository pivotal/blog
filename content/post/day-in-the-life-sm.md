---
authors:
- genevieve
categories:
- BBL
- Cloud Foundry
date: 2017-09-06T08:30:00Z
short: |
  A day in the life of a Pivotal Cloud Foundry software engineer in Santa Monica, California.
title: Day in the Life - Santa Monica Style
image: /images/day-in-the-life-sm/pairing.jpg
---

<p align="center"  style="font-weight:bold">

Did you ever imagine yourself at work, drinking coffee, working
on an acceptance test for a CLI that paves an IaaS environment for your users to
do their work on? That between sips you’d work to automate deployment of a
heavily distributed PaaS software system in a fraction of the time it would take
to deploy by hand?

</p>

<p align="center">

Surprisingly, this is not what I dreamt of as a young girl, but I could not be
more pleased with my unforeseen new morning routine.

</p>

<p align="center"  style="font-weight:bold">

I’m Genevieve, anchor of the Pivotal Cloud Foundry Infrastructure team.

</p>

<p align="center">

This is a day in my life!

</p>


## 6 AM - 9 AM

{{< responsive-figure src="/images/day-in-the-life-sm/santa-monica.jpg" class="center small" caption="Early morning Santa Monica.">}}

I like to start early.

As such, this is what happens before breakfast: I (sometimes) wake up before my
alarm, jump out of bed, grab my spin clothes,
and head out the door to a cycling studio nearby. Angela, another software
engineer with Pivotal Cloud Foundry, meets me there and we strap in. After
class, I race home, get ready for work, and pick up a latte on my way.

Everyone gets to the office before 9 AM because we have **catered breakfast**!
You don’t want to miss out on the
[omlette or juice bar](https://hbr.org/2017/05/why-my-company-serves-free-breakfast-to-all-employees?mkt_tok=eyJpIjoiTXpZNE0yUmtOamMyTm1OaiIsInQiOiJ6TWtWSENrRncwNVZtZUM3dmdWdFVvTjQ1NVRUa3I3SlY4NlZOd1Z1OU1yQTlkSFBHV0xrVE9pWlFqZ0pQMyswN2NiNEM1eG9ZR1VjSnllSG1YSklTZ1JvR3p4WGZxeFBTbWpXdjd0cUJWRFQrRVgyMHcyejZramtRS1FUWU54QSJ9).



## 9:06 AM

At 9:06 AM, we ring a cowbell and stand in a circle around the event space for
the office-wide standup. This standup is a chance to introduce new folks to the
office, share interestings, and highlight upcoming events in and out of the
office. This helps us start the day off together!



## 9:15 AM - 9:20 AM

After office standup, every team has their own standup.

Our team is composed of four engineers and one product manager. We pair program
at Pivotal, so each pair will give a status update on their work from the day
before. After that, we decide pairs for today.

Our standups are pretty quick because we don’t have any remote team members
right now. Our team sits next to each other and we inevitably talk throughout
the day, sharing context on our respective stories.

If you want to know how **remote pair programming** works, check out
[Brenda’s post!](http://engineering.pivotal.io/post/pair-programming-in-a-distributed-team/ )



## 9:20 AM - 11:00 AM

This is where the fun begins, it’s time to start programming/debugging/exploring.

{{< responsive-figure src="/images/day-in-the-life-sm/pairing.jpg" class="center small" caption="Angela and I pairing.">}}

Cloud Foundry is an open source Platform-as-a-Service with contributions from a number of
organizations and individual developers. My team works entirely in the
open-source.

Working with the **open-source community** is exciting because you get more brain
power on a problem. I’ll often find issues or pull requests in my
[backlog](https://www.pivotaltracker.com/n/projects/1488988)
from individual developers looking to add support for some new feature
or they are simply interested in contributing a refactor.

I like that I can talk about what I do in great detail with anyone...
*unfortunately for those I'm talking to.*

### Infrastructure

My team maintains 3 very different projects - cue the Charlie’s
Angels theme song. They are:

- [bosh-bootloader](https://github.com/cloudfoundry/bosh-bootloader)
- [consul-release](https://github.com/cloudfoundry-incubator/consul-release)
- [etcd-release](https://github.com/cloudfoundry-incubator/etcd-release)

`etcd` and `consul` are 3rd-party software components that we packaged to run on
[BOSH](https://bosh.io).
We maintain those packages for the numerous teams working on CF. You can learn
more about these components with
[Onsi’s talk](https://www.youtube.com/watch?v=1OkmVTFhfLY).

### bosh-bootloader, or bbl for short

Now, on to the new kid on the block.

`bbl` is a CLI written in [Go](https://golang.org/), for paving an IaaS of
your choosing for a
[Cloud Foundry](https://www.cloudfoundry.org/) or
[concourse](http://concourse.ci/) installation.

Currently, `bbl` supports Amazon Web Services, Google Cloud
Platform, and Microsoft Azure.

#### How do you use it?


To get a BOSH director and load balancers for CF, run:

```
export $BBL_IAAS=iaas-of-your-choosing
export $BBL_ENV_NAME=santa-monica
# export the necessary credentials for your IaaS

bbl up

bbl create-lbs --type cf --cert $BBL_LB_CERT --key $BBL_LB_KEY
```

To tear it all down, run:

```
bbl down
# yup, really
```

`bbl` is opinionated in terms of networks and security groups.

We are currently completing a security feature where `bbl` deploys a **jumpbox** in
front of your BOSH director. You can think of a jumpbox as a bastion: a single
point of entry to the system. A jumpbox has fewer ports open than the BOSH
director (only an ssh port) and the ingress rules for the BOSH director can be
reduced to only the jumpbox instead of accepting traffic from anywhere on a
handful of ports.

This is important because it drastically reduces the surface area with which
your CF or concourse installation can be compromised.

You can experiment with it on GCP:

```
bbl up --iaas gcp --jumpbox --name super-duper-secure-environment
```

#### Why is bbl interesting to me?

Creating, configuring, securing, migrating, and destroying **"things in the cloud"**
is tricky and fun. Different IaaSes have different rules and different `bbl` users can
have very different needs.

We use [terraform](https://www.terraform.io) to create these resources as it supports the IaaSes we
currently pave and the ones we want to support in the (near) future.

At Pivotal, we **<3** test-driving and automation. Being able to do that with
infrastructure management is made easier with terraform.

*Side Note:* In terms of **test-driving**, Cloud Foundry is a really interesting case.
Nima and Amit have a
[great explanation here!](https://www.cloudfoundry.org/challenges-testing-highly-distributed-highly-scalable-cloud-platform-case-cloud-foundry/)

To learn more about `bbl`, check out Angela and Christian's talk
on [deploying Cloud Foundry with bbl, BOSH 2.0, and cf-deployment](https://www.youtube.com/watch?v=lIhx69WfRcE).

Alright, where were we?



## 11:00 AM - 11:15 AM

In the middle of the morning, we take a break. You can sit on the balcony to get
some sun, go for a walk, or chat others up.



## 11:15 AM - 12:30 PM

After a break, we work till lunch.



## 12:30 PM - 1:30 PM

Speaking of lunch, it's a really popular time of day for events and clubs.

Angela and I run the Diversity & Inclusion initiatives in the Santa Monica office. She led
an incredible **book club** for *Citizen: An American Lyric*.

Lunches for D&I are sometimes a support forum and sometimes action-oriented
where we plan for upcoming internal or external events, like with [Project
Scientist](http://www.projectscientist.org/).

{{< responsive-figure src="/images/day-in-the-life-sm/project-scientist.jpg" class="center small" caption="Myself, Tiffany, Angela, and Bronwyn during Project Scientist. #ilooklikeanengineer" >}}

On days without lunch events, I like to walk one block over and down the
California Incline to the beach. I’m from Montreal so I find time during the day
to call my family back home. Or I listen to **Kaytranada’s 99.9%** because it’s
phenomenal and will never get old.



## 1:30 PM - 2:00 PM

As anchor, once a week I have a pre-IPM with Evan, our product manager.

An **iteration planning meeting** is where the team meets to talk about stories in
the backlog and point them based on their anticipated complexity.

In the pre-IPM, Evan and I work to flesh out stories with acceptance criteria.
We are considerate of writing stories that deliver real user value in
incremental units of work for the engineers. Sometimes as anchor, I represent
the engineering team by negotiating the prioritization of certain chores that
the engineers feel are important to improving their workflow.


## 2:00 PM - 3:00 PM

After pre-IPM, I return to my pair and we continue any stories in flight.


## 3:00 PM - 3:15 PM

We take a break in the middle of the afternoon too because, hello, our office is
in Santa Monica by the beach and sunshine is addictive!



## 3:15 PM - 5:00 PM

Our day ends at 5PM and we disperse.


#### Flex hours

At this point you might be thinking: *“This schedule feels a little rigid.”*

Pivotal has a set **9 AM - 12:30 PM / 1:30 PM - 5 PM** schedule.

That’s 35 hours with your team. The other 5 hours can be moved anywhere. These
five hours a week don’t need to be spent in your team’s backlog or in the
office. You can explore new technical domains or work on diversity and inclusion
efforts. It’s flexible in time, topic, and location.

We believe in **sustainable pace** - you hear it a lot in the industry and we
*really* practice it.

When you take vacation, even to somewhere with cell service, you don’t have to
worry about being contacted. We respect each other’s mornings, evenings, and
weekends.

Depending on the week, I’ll spend flex hours at a coffee shop on Saturday morning.
I can pick up an interesting story in the icebox or
work on an iOS/Go application just to change it up!



## SUPER IMPORTANT NOTE

We have a yoga class in the office on Monday nights!


