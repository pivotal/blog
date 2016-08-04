---
authors:
- mfine
- jpalermo
- chendrix
- njbennett
categories:
- BOSH
- Concourse
- Testing
date: 2016-08-04T13:37:43-07:00
short: |
  Compile once, deploy many times.
title: Faster Pipelines With Compiled BOSH Releases
---

## The Problem

The Pivotal Core Services team is responsible for the [cf-mysql release](https://github.com/cloudfoundry/cf-mysql-release). Deploying this BOSH release requires compiling MariaDB, Galera, and XtraBackup. These packages depend on each other and must be compiled serially, making overall compilation take longer than 40 minutes.

In our Continuous Integration (CI) pipeline, we have a traditional fan-out/fan-in structure where we deploy our release to many environments before running a test against each one.

We treat these environments as disposable clones of one another; we pull them from a pool and clean them before and after each test to make builds reproducible and reduce test pollution.
The problem with this strategy is that deploying to a clean environment requires recompilation of all packages, meaning our CI pipeline would often take between 2.5 to 3 hours from start to finish, even when none of our packages were changed.

{{< responsive-figure src="/images/compiled-releases-for-pipelines/ci-pipeline-before.png" class="center">}}

## How Compiled Releases Can Help

BOSH's [compiled releases](https://bosh.io/docs/compiled-releases.html) allow you to compile all of your packages once,
export a compressed archive of your release, and then deploy that release to other environments.


We knew that compiled releases would make deployments faster, but we had trouble utilizing them in our test pipeline.
Creating the compiled release as part of the pipeline does not make the pipeline faster since the compilation still has to take place. It only becomes valuable if you can use it later to avoid recompiling.

{{< responsive-figure src="/images/compiled-releases-for-pipelines/ci-pipeline-naive-compiled.png" class="center">}}

We would save time if we could find a way to compile the release up front and only compile the packages that had changed.

## Solution

We created a shared BOSH director where compiled releases are created before deployments in our pipelines.
Because the BOSH director is never cleaned up, it's able to reuse compiled packages that have not changed.

{{< responsive-figure src="/images/compiled-releases-for-pipelines/ci-pipeline-long-lived-compiled.png" class="center">}}

There is now a job at the beginning of our pipeline that compiles the release and downloads that release as a Concourse resource
before immediately passing it along and uploading it to another director. This step means that the second bosh director,
the one that is always cleaned up, no longer needs to compile anything.

When a package does change, now only that package needs to be recompiled. This means that in the average case,
compilation takes around 5 minutes, and only in the worst case will compilation take up to 40 minutes, e.g. when we change the version of MariaDB, which is rare.

## Caveats

When BOSH is exporting a compiled release, it creates a lock on the release name.
This means that you can not have multiple jobs uploading and exporting releases for the same BOSH release simultaneously.
To solve this problem we created a [concourse pool resource](https://github.com/concourse/pool-resource) that acts as a mutex for our BOSH director doing the compilation.

Exporting a release does take a bit of time, so depending on the compilation time of your BOSH release this may not be a win.

## Resources

- [Creating BOSH compiled releases.](https://bosh.io/docs/compiled-releases.html)
- [Our script used for compiling a release.](https://github.com/cloudfoundry-incubator/cf-mysql-ci/blob/a12f8a25bd84413e4651350ea97491cf5fc84a1a/scripts/compile_release)
- [Concourse pipeline configuration that compiles releases.](https://github.com/cloudfoundry-incubator/cf-mysql-ci/blob/dbc2ba48390c0250c8ce201974230f1ba5aa82ae/ci/pipelines/cf-mysql-acceptance.yml#L154)
