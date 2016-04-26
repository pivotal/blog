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
title: Distributed Pair Programming: What Works!
---

For the past two years, the Cloud Foundry Toolsmiths team here at Pivotal has been distributed, spanning the Eastern and Pacific time zones. Two years makes 522 weekdays. For me personally, that means that for 522 days I have been remote pairing with my team members. In those days, we have iterated on a lot of potential solutions for addressing the needs of our team!

As an agile engineering teams, our core values include:

* Pairing
* Brainstorming as a team
* Allowing easy collaboration and open discussions with other teams
* Having weekly retrospectives and iterating

We can't deny it: an engineering team that is colocated can accomplish these tasks much more easily. Colocated team members only need to sit next to each other at a shared workstation to pair. Colocated team members can easily huddle in a group to discuss technical implementations or tackle any problems at hand. Other engineering teams can easily approach another team's desk to ask any questions. The real question is: how can a distributed team accomplish all this? In this post I'll be sharing some of the tooling my team has found to work well, and what we would still like to improve.

## Pairing

### Screensharing

All Pivotal workstations are connected on an internal network, so screensharing can be easily accomplished using Mac OSX's Screen Sharing app which uses [VNC](https://en.wikipedia.org/wiki/Virtual_Network_Computing). We have found that the Screen Sharing app provides better image quality and does not require the remote guest machine to approve the connection. This allows us to access remote team members' workstations before they arrive in the office to access any code that made have been stashed locally, which is particularly important when you work across time zones!

{{< figure src="/images/distributed_pairing/macvnc.png" class="center" >}}

If the team doesn't have the luxury of a shared network, the second best option we have found for screensharing is [Screenhero](https://screenhero.com/). Screenhero allows both members to control the screen. Unlike OSX's Screen Sharing, it does require the remote guest machine to approve the connection. One really nice feature of Screenhero is that it shows each user's cursor so you can see where on the screen your team member is pointing to.

If the screen sharing quality is subpar, our pairs will rotate working off each other's workstations to avoid having one team member constantly driving while pairing.

### Audio

Good audio quality is essential while pairing, so we have invested in good headsets. We use the [Sennheiser PC Gaming headsets](http://en-us.sennheiser.com/pc-gaming-headset), selected because they are lightweight and they have great sound quality. One of my favorite features of the headsets is that lifting the microphone arm automatically mutes the mic. It may sound like a simple feature, but is the much appreciated. Listening to your pair coughing or munching on snacks can become an annoyance (and being able to mute if you want to is actually an advantage over in-person pairing). These headsets are slightly expensive but worth it if you plan to remote pair often.

As to which audio application we use, the options are numerous. Google Hangouts, Skype, appear.in...and the list goes on. These communication platforms are great, but one thing that they do not allow easily is what we will talk about next - having team discussions remotely.

## Brainstorming and team discussion

Team discussions can take place on the communication platforms mentioned above, but the coordination required for creating and getting everyone into the same chat room can be cumbersome and time-consuming. What we have found to work well for us is [TeamSpeak](https://www.teamspeak.com/). TeamSpeak has the concept of "channels", where users can join and leave the channels as they please. As we have it set up, each pair will work together on one channel. If one pair needs to interrupt another pair, or the team wants to quickly discuss something, TeamSpeak users can easily join another pair's channel by dragging a username into the appropriate channel.

{{< figure src="/images/distributed_pairing/teamspeak.png" class="center" >}}


We use the [TeamSpeak BOSH release](https://github.com/pivotal-cf-experimental/teamspeak-bosh-release) to deploy a teamspeak server. Using[BOSH](http://bosh.io/) to deploy software allows us to not worry about services failing or the vm dissapearing as BOSH will monitor your vm's health for you, and fix it or recreate it when needed. If you're interested in learning more about BOSH and its capabilities, I strongly recommend you read the document ["What Problems does BOSH solve?"](http://bosh.io/docs/problems.html).

## Working with other teams

Working with other teams can be difficult when the team is distributed. The fact is that **nothing** trumps in-person conversations. We use [Slack](https://slack.com/) so other teams can reach out to us, and if conversations take longer than 2-3 minutes, we ask the other team to join an [appear.in](https://appear.in) room. Our appear.in caht is open, and anyone with the link can join.

Collaborating and working with other teams is the area I personally feel needs the most improvement. Slack messages can be slow, and having multiple team members join a video call requires a lot of effort (finding a conference room, getting on the call, setting up mic/speaker settings). I'd love to hear what other tooling you have used to help with this scenario.

## Retros

Colocated retros are typically done on a whiteboard. We use [Trello](https://trello.com/) for our retros. In Trello, you are able to create teams and, within the team, create boards. Team members can then use the web client or the mobile app to write on the retro board. Trello also allows us to easily keep a history of all our retros, which is good for reference.

{{< figure src="/images/distributed_pairing/sample-retro.png" class="center" >}}

## Summary

Here's an incomplete list of tools our team uses right now to make sure we're remote pairing effectively:
* Screen sharing: OSX Screen Sharing
* Screen sharing: [Screenhero](https://screenhero.com/)
* Audio: [Sennheiser PC Gaming headsets](http://en-us.sennheiser.com/pc-gaming-headset)
* Audio: [TeamSpeak](https://www.teamspeak.com/) (specifically the [TeamSpeak BOSH release](https://github.com/pivotal-cf-experimental/teamspeak-bosh-release))
* Chat: [Slack](https://slack.com/)
* Videoconference: [appear.in](https://appear.in)
* Retros: [Trello](https://trello.com/)

All of the tooling and software mentioned we used is based on our personal preferences. We are constantly iterating to make working in a distributed easier and more awesome. We'd love to hear feedback, or learn about other tooling that you have had success with while working in a distributed team!
