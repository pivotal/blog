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

Here in New York City, the buildpacks team curates a heterogenous collection of official Cloud Foundry buildpacks. Some of these are soft forked code which tracks upstream buildpacks by Heroku. Others are from-scratch community implementations that were adopted by the Cloud Foundry Foundation. If you install Cloud Foundry, every buildpack except for Java is updated and maintained by this one team.

The buildpacks team has committed to the Cloud Foundry community that each our seven buildpacks are tested on two versions of Cloud Foundry, that each has been tested with a suite of representative apps for the buildpack's ecosystem, with support for two minor versions of a language in each major version line. Each buildpack has to be produced in two versions, an 'uncached' version which will download binaries on the fly, and a 'cached' version that bundles all the binaries. We also commit for all of these to ship binaries that we've built ourselves from a verified mainline source.

Most of all, we commit to do all of these within 48 hours of a serious CVE being fixed in a mainline source release, for all affected buildpacks.

Right now, this is the entire buildpacks team:

***Photo here***


## NodeJS as a case study

So we've committed to a lot of work for 2 pairs of engineers. What makes these commitments possible is automation. Our overall automation is big enough for a book, so we're going to focus on the automation of updating binaries upon upstream release.

We'll take NodeJS as our focus. It's a good case study for a few reasons. First, we support five major version lines (0.10, 0.12, 4.x, 5.x and 6.x) and provide two minor versions for each. In theory a wide-ranging, backported CVE fix may require rebuilding 10 binaries.

Secondly, the NodeJS project is highly active. Even outside of CVEs, releases happen at a brisk tempo, and our users expect to have access to the latest available versions quickly.

## The Problem With The Problem

We're humans.

Remember what we promised: tested, verified binaries for 2 versions of CF built ASAP. It is hard and slow and error prone to do this by hand. We know this because the buildpacks team used to do a lot of this work by hand.

It meant that our users relied on us to flawlessly go through a long manual process every time a source release was made. These were turned into stories in Pivotal Tracker, meaning they had to compete with other work for engineering time. Then when we *did* have to react quickly, we would have to devote a pair to pushing through all the work under stressful conditions.

Hence the famous saying: "There are masochists, and then there is Sisyphus ... and then there are Buildpack maintainers circa late-2014".

## The outline of the solution

Enter, stage right: Concourse (trumpets blaring here).

Concourse is a CI system that does all the important fundamental stuff *right*. Including all the stuff you didn't know other CI systems were doing wrong until it was built.

We can make this bold claim because of Concourse's pedigree. Concourse was born to solve a relatively simple problem: having humanly-comprehensible, declarative, flexible, fast, reliable, versionable, repeatable, distributable, shareable builds in a massive project involving dozens of self-directed agile teams in multiple offices on multiple continents for multiple companies, shipping between hundreds and thousands of commits per day in hundreds of repos in order to release a complex distributed system every few weeks.

(Hint: I'm talking about Cloud Foundry)

We still need a releases team -- Cloud Foundry is complex and not all the pipelines have been integrated -- but it's a *team*, not a department with an entire building.

Turns out that this level of capability is hard to achieve with ... any other CI system. Not out of the box, not without massive aftermarket engineering, a separate build engineering team, a tedious administrative process for getting your build account and so on and so forth. Large enterprises wind up with these. So do large tech companies. Our colleagues in Pivotal Labs have seen all of these. You don't want this. You want to use Concourse instead.

Starting in 2015, buildpacks has become one of the most adventurous users of Concourse inside the Cloud Foundry world. We have progressively transformed tedious drudge work into shiny, beautiful automation and in the process, helped to explore the boundaries of what Concourse can do.

In fact, we have *so* much automated that it's impossible to talk about all of it in a single post.

Instead, we're going to focus on one of our highest-value automations: turning a release tag from the NodeJS project into a fully-tested, fully-updated buildpack within an hour. The timing is based on build times plucked out of Concourse's records.

*tl;dr* we're going make Jack Bauer seem like a slacker.

# First Act: Wherein NodeJS Announces New Versions

Once per hour, our CI server checks fourteen upstream dependencies to see if any of them have made new releases. For NodeJS, this means checking for new version tags on Github. We turn these into a collection of YAML files representing newly available versions to be consumed by the next part of the pipeline.

***Needs more detail, snippets of code and YAML, animated gif of pipeline***

<div class="ribbon ribbon-primary">Time Elapsed</div> At the end of the First Act, 24 seconds have elapsed. Beep. Boop. Beep. Boop.

# Second Act: Wherein We Build All The NodeJSes

Of course, the NodeJS project are under no obligation to release one version at a time. CVEs often exist in multiple major versions of the Node runtime, meaning that simultaneous releases will occur. For example, [4 versions were simultaneously released on 23rd June 2016](https://nodejs.org/en/blog/vulnerability/june-2016-security-releases/) to address a group of CVEs that affected multiple versions of the Node runtime.

To ensure that every single version gets built, we take advantage of Concourse's `version: every` setting. That is, we tell Concourse to build every single Git commit made to our build management repository. Then we take the list of all dependencies waiting to be built and chop them into individual commits.

***Needs more detail, snippets of code and YAML, animated gif of pipeline***

## Intermission: How Can You Trust Us?

As a matter of professional paranoia, you shouldn't. But as a matter of professional getting-things-done-sometimes, you have to. Our job is to make it easier to trust us.

The main way we do this is to publish a locally-calculated SHA256 of the code we're building. You can then compare it with the SHAs provided by the upstream project.

Of course, that might not be good enough. For at least one company using Cloud Foundry, it's not, and that organisation builds their *own* binaries. How do they do it? Well, all the tools and Concourse configuration used by buildpacks is itself opensource. That company have stood up their own copy and now they build their own buildpacks, completely independently, so that they have more control over the process.

<div class="ribbon ribbon-primary">Time Elapsed</div> At the end of the Second Act, 6 minutes 51 seconds have elapsed. Beep etc.

# Third Act: Wherein We Release a New NodeJS Buildpack

So, within a few minutes of detecting a new release, we have candidate binaries for release. The next step is to prepare a buildpack for release. Concourse runs our buildpack-packager tools to build both cached and uncached buildpacks.

These candidate buildpacks are pushed into two Cloud Foundry environments to test compatibility with two releases. Then we run our integration suites against both versions in both environments.

Once testing is finished -- usually within 45 minutes -- we reach the first human decision point. As a matter of policy, releases must have a human in the loop. Given the Pivotal Labs DNA which was transfused into Cloud Foundry, that human is the Product Manager responsible for buildpacks. Right now, our PM is Danny Rosen.

Assuming that we're anxious to make a release as fast as possible, Danny will have prepared a story in tracker to identify the upcoming release. Once the binaries are built and the BRATS has passed, we come to the second human touch point. A pair of developers will take the story from the backlog and run through our short release workflow.

The essence of the workflow is:

* Provide a meaningful CHANGELOG entry, with descriptions of changes and links to Tracker stories
* Tag the version

Once these changes are pushed, Concourse picks the ball up and keeps running. It will re-run BRATS (juuuuust in case some unrelated changes crept into the versioning commit), then proceed to cut the release and upload it to [Github](https://github.com/cloudfoundry/nodejs-buildpack/releases) and [Pivotal Network](https://network.pivotal.io/products/buildpacks). As a favour to passers-by, it will produce nice release notes for Github users, showing the CHANGELOG entries, packaged binaries and the SHA256 of the released buildpack.

## Intermission: How Can Your App Trust Us?

So now the buildpack is available for operators to download. Cloud Foundry enables operators to update the buildpacks independently of Cloud Foundry itself, primarily so that security issues can be handled quickly.

Once a new version of the NodeJS buildpack has been uploaded, apps can restage using the latest binary.

Remember, we make a number of guarantees. One of them is that we don't unexpectedly break existing apps. This is largely what our integration testing is intended for. For each buildpack, we apply a collection of representative acceptance apps to ensure that they will stage and become responsive. For example, the NodeJS buildpack comes with 13 fixture apps, which will be applied in a variety of ways to ensure that the buildpack won't surprise you.

One surprise to avoid is dialling out to the internet, when using a cached buildpack. If you already have a NodeJS binary, you shouldn't need to download it again. While the performance gain is nice, there's a more important reason. Some Cloud Foundry users have non-negotiable requirements to work in a disconnected environment. Whether for reasons of corporate culture, regulatory compliance or government security, they simply cannot be connected to the internet. But they still want, and their operators and developers deserve, all the fruits of a modern PaaS. Part of our mission is to make that possible and we test the heck out of it.

And that's it! We've released a NodeJS buildpack. In this scenario -- remember, this is based on real figures taken from our logs -- we went through the whole process in under an hour. We needed humans to write the release notes and another to authorise the release.

Unlike Jack Bauer, we don't need ad breaks to pad us out. Your move, Jack.

<div class="ribbon ribbon-primary">Time Elapsed</div> At the end of the Third Act, 58 minutes, 39 seconds have elapsed. (Assuming 2 minutes for chatting to PM and 5 minutes for updating the CHANGELOG).

# Somewhere, a timeline of events with running total of time

# Rumours of Sequels

- More authentications
- automating more pipelines
- dealing with more simultaneous releases (traffic jam problem)
	- locks not being returned
	- concourse being overwhelmed
- being able to prioritise builds instead of being fair

# Conclusion

Pretty soon you too are going to be humblebragging about the massive systems you maintain without needing a separate build engineering team. We suggest using `#concourseproblems` and `#buildpacksrule`as your hashtags.