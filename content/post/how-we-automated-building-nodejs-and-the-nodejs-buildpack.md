---
authors:
- geramirez
- jchester
categories:
- Concourse
- Buildpacks
- Automation
- Cloud Foundry
- NodeJS
date: 2016-07-20T16:47:39-04:00
draft: true
short: |
  Recently, the buildpacks team completed a fully-automated, security-checking, end-to-end pipeline for turning NodeJS release announcements into new NodeJS buildpacks. Here's how we did it.
title: How we automated building NodeJS and the NodeJS buildpack
---

# The Problem
	- we maintain 7 buildpacks, including NodeJS
	- by itself, NodeJS has ten (10! the number of fingers you have!) binaries included.
	- our users expect 
		- to have the latest versions within hours of a release from upstream.
		- that the binary we ship is not based on some baddie's replacement source code
		- that we won't break their apps

# The Problem With The Problem

We're humans.

It is hard and slow and error prone to do this by hand. 

The NodeJS project releases at a brisk tempo and often drops multiple versions simultaneously. 

It is fairly exhausting to keep up with all this by hand and increases the likelihood of our fatfingering messing up your app deploy a few days later.

Hence the famous saying: "There are masochists, and then there is Sisyphus ... and then there are Buildpack maintainers circa late-2014".

# The outline of the solution

Enter, stage right: Concourse (trumpets blaring here).

Concourse is a CI system that does all the important fundamental stuff *right*. Including all the stuff you didn't know other CI systems were doing wrong until it was built. 

We can make this bold claim because of Concourse's pedigree: it was born to solve a relatively simple problem  -- having humanly-comprehensible, declarative, flexible, fast, reliable, versionable, repeatable, distributable, shareable builds in a massive project involving dozens of self-directed agile teams in multiple offices on multiple continents for multiple companies, shipping between hundreds and thousands of commits per day in hundreds of repos in order to release a complex distributed system every few weeks. We still need a release engineering team -- it's massive -- but it's a *team*, not a department with an entire building.

(Hint: I'm talking about Cloud Foundry)

Turns out that this level of capability is hard to achieve with ... anything other CI system. Not without massive aftermarket engineering, a separate build engineering team, a tedious administrative process for getting your build account and so on and so forth. Our colleagues in Pivotal Labs have seen all of these. You don't want this.

Since 2015, buildpacks has become one of the most aggressive users of Concourse inside the Cloud Foundry world. We have progressively transformed tedious drudge work into shiny, beautiful automation.

In fact, we have *so* much automated that it's impossible to talk about all of it in a single post. 

Instead, we're going to focus on one of our highest-value automations: turning a release tag from the NodeJS project into a fully-tested, fully-updated buildpack in a few hours without a single human having to get involved.

While we're doing it, we're going make Jack Bauer seem like a slacker.

# First Act: Wherein NodeJS Announces Four New Versions

At the end of the First Act, 24 seconds have elapsed. Beep. Boop. Beep. Boop.

# Second Act: Wherein We Build All The NodeJSes

# Intermission: How Can You Trust Us?

At the end of the Second Act, 6 minutes 51 seconds have elapsed. Beep etc.

# Third Act: Wherein We Release a New NodeJS Buildpack

# Intermission: How Can Your App Trust Us?

Assume 5 minutes for change logs

Assume 2 minutes for chatting to PM.

At the end of the Third Act, 58 minutes, 39 seconds have elapsed.

In this scenario -- remember, this is based on real figures taken from our logs -- we went through the whole process in under an hour. We needed humans to write the release notes and another to authorise the release.

Unlike Jack Bauer, we don't need ad breaks to pad us out. Your move, Jack.

# Somewhere, a timeline of events with running total of time

# Rumours Of Sequels

- automating more pipelines
- dealing with more simultaneous releases (traffic jam problem)
	- locks not being returned
	- concourse being overwhelmed
- being able to prioritise builds instead of being fair

# Conclusion

Pretty soon you too are going to be humblebragging about the massive systems you maintain without needing a separate build engineering team. We suggest using `#concourseproblems` as your hashtag.