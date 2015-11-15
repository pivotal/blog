---
authors: 
- gregg
categories:
- jasmine
- javascript
date: 2015-10-15T09:54:52-07:00
draft: true
short: |
  Let's talk a bit about the current state of Jasmine and how we look at maintaining it.
title: State of Jasmine
---

Hi, I'm Gregg and I'll be your primary maintainer/product manager for Jasmine for the near future.  You may have seen me active in github as @slackersoft. I wanted to take some time to talk about the 2.0 release and what has happened with support for older versions.

When we released Jasmine 2.0, we somewhat unceremoniously dropped support for development against older versions. This was done out of a desire to have time to support the community with new features for the new version. Jasmine 1.3 had a number of issues that made maintenance of the code difficult and time-consuming, that we feel we’ve addressed with the 2.0 release.

However, we have heard from the community that there is a desire to get some particular bugs in 1.3 fixed without needing to upgrade to 2.0. Going forward, the plan is that we will merge Pull Requests into a 1.3 branch on github. For now, there won’t be a release (new standalone distribution and ruby gem), but if we hear enough feedback that either is desired, we can revisit this decision in the future.
