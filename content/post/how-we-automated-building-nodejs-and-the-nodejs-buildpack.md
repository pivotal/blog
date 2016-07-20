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

Concourse is a CI system that does all the important fundamental stuff *right*. Including all the stuff you didn't know other CI systems were doing wrong until it was built. We can make this bold claim because of Concourse's pedigree: it was born to solve for having flexible, fast, reliable, versionable, repeatable, distributable, shareable, understandable builds in a massive project involving dozens of self-directing agile teams in multiple offices on multiple continents for multiple companies, releasing a complex distributed system every few weeks.

(Hint: I'm talking about Cloud Foundry)

So, like, conceptually, it's amazing. It's proved out. 

# First Act: Wherein NodeJS Announces Four New Versions

# Second Act: Wherein We Build All The NodeJSes

# Intermission: How Can You Trust Us?

# Third Act: Wherein We Release a New NodeJS Buildpack

# Intermission: How Can Your App Trust Us?

# Conclusion