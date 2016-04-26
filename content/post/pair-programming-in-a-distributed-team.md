---
authors:
- bsnchan
categories:
- Agile
- Pair Programming
date: 2016-04-20T17:25:05-04:00
draft: true
short: |
  Tales of pair programming on a distributed team.
title: Tales of Pair Programming on a Distributed Team
---

Before we get started, you may wonder what I know about working on a distributed agile team. I'm on the Cloud Foundry Toolsmiths team here at Pivotal, and we have been a distributed team for the past 2 years across the Eastern and Pacific timezones. That is 522 total weekdays of remote pairing to be exact! For 522 days, I have been remote pairing with my team members and in those days I have learned what works, what doesn't work, and what problems still need to be solved.

As with most agile engineering teams, some of the core values we hold onto are:

* pairing
* brainstorming as a team
* allowing easy collaboration and open discussions with other teams
* having weekly retros and iterating

For obvious reasons, an engineering team that is collocated can accomplish these tasks much easier. Collocated team members only need to sit next to each other at a shared workstation to pair. Collocated team members can easily huddle in a group to discuss technical implementations or tackle any problems at hand. Other engineering teams can easily approach another team's desk to ask any questions. The real question is ... how can a distributed team accomplish all this? In this post I'll be sharing some of the tooling my team has found to really work and what we would still like to improve.

## Pairing

### Screensharing

All Pivotal workstations are connected on an internal network, so screensharing can be easily accomplished using Mac OSX's Screen Sharing app which uses [VNC](https://en.wikipedia.org/wiki/Virtual_Network_Computing). We have found that the Screen Sharing app provides better image quality and does not require the remote guest machine to approve the connection. This allows me to access my remote team members' workstations before they arrive in the office to access any code that made have been stashed locally.

{{< figure src="/images/distributed_pairing/macvnc.png" class="center" >}}

If the team doesn't have the luxury of having a shared network, the second best option we have found for screensharing is [Screenhero](https://screenhero.com/). Screenhero allows both members to control the screen but does require the remote guest machine to approve the connection. A great feature of Screenhero is that it shows each user's cursor so you can see where on the screen your team member is pointing to.

If the screen sharing quality is subpar, our pairs will rotate working off each other's workstations to avoid having one team member constantly driving while pairing.

### Audio

Good audio quality is essential while pairing so we invest in good headsets. We choose to use the [Sennheiser PC Gaming headsets](http://en-us.sennheiser.com/pc-gaming-headset) as they are lightweight. One of the best features of the headsets is the microphone arm. Lifting the microphone arm will automatically allow you to mute yourself. It may sound like a simple feature but is the most appreciated as listening to your pair coughing or munching on snacks can become an annoyance. These headsets are slightly expensive but is worth the slight expense if you plan to be remote pairing often.

There are plenty of ways to have an audio call with another team member online. Google Hangouts, Skype, Appearin and the list goes on. These communication platforms are great but one thing that they do not allow easily is what we will talk about next - having team discussions remotely.

## Brainstorming and team discussion

Team discussions can take place on the communication platforms mentioned above, but creating and getting everyone into the same chat room can be cumbersome and time-consuming. What we have found to work great for us is [TeamSpeak](https://www.teamspeak.com/). TeamSpeak has the concept of "channels", where users can join and leave the channels as they please. Each pair will typically work together on one channel. If one pair needs to interrupt another pair, or the team wants to quickly discuss something, TeamSpeak users can easily join another pair's channel by dragging the user's username into the appropriate channel.

{{< figure src="/images/distributed_pairing/teamspeak.png" class="center" >}}


If you are familiar with using [BOSH](http://bosh.io/), you can use the [TeamSpeak BOSH release](https://github.com/pivotal-cf-experimental/teamspeak-bosh-release) to deploy a teamspeak server. Using BOSH to deploy software allows us to not worry about services failing or the vm dissapearing as BOSH will monitor your vm's health for you, and fix it or recreate it when needed. If you're interested in learning more about BOSH and its capabilities, I strongly recommend you read the document ["What Problems does BOSH solve?"](http://bosh.io/docs/problems.html).

## Working with other teams

Working with other teams is a bit difficult when the team is distributed. The underlying fact is that **nothing** trumps in-person conversations. We use [Slack](https://slack.com/) so other teams can reach out to us. If conversations take longer than 2-3 minutes, we would ask the other team to join an [Appearin](https://appear.in) room, which video chat room that anyone with the link can join.

Collaborating and working with other teams is the area I personally feel needs the most improvement. Slack messages can be slow and having multiple team members join a video call requires a lot of effort (finding a conference room, getting on the call, setting up mic/speaker settings). I'd love to hear what other tooling you have used to help with this scenario.

## Retros

Collocated retros are typically done on a whiteboard. We choose to use [Trello](https://trello.com/) for retros. In Trello, you are able to create teams and within the team, create boards. Team members can then use the web client or the mobile app to write on the Retro board. Trello also allows for us to easily keep a history of all our retros.

{{< figure src="/images/distributed_pairing/sample-retro.png" class="center" >}}

## Summary

All of the tooling and software mentioned in this post are based on the team member's preference. We are constantly iterating to make working in a distributed easier and more awesome. We'd love to hear feedback or new tooling that you may have used while working in a distributed team!
