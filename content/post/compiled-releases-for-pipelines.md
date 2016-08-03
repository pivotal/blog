---
authors:
- mfine
- jpalermo
categories:
- BOSH
- Concourse
- Testing
date: 2016-08-02T15:37:43-07:00
draft: true
short: |
  Using BOSH compiled releases in our pipelines speeds up a single run through CI by over a factor of 2.
title: Faster Pipelines With Compiled BOSH Releases
---

## The Problem

The Pivotal Core Services team is responsible for the [cf-mysql release](https://github.com/cloudfoundry/cf-mysql-release). Deploying this BOSH release requires compiling MariaDB, Galera, and XtraBackup. These packages depend on each other and must be compiled serially. Compilation of the release often takes longer than 40 minutes.

After committing and pushing a change to the release it would take 2.5 to 3 hours before it passed CI and could be considered deliverable code. By taking advantage of BOSH compiled releases, we were able to speed up our pipeline by a factor of 2.

We have a pool of test environments that we clean after each run through CI. Because of this, each environment would end up compiling the same unchanged packages every time our pipelines ran.
The packages that take the most time to compile are rarely changed, but we would always perform the compilation from scratch every time.

## How Compiled Releases Can Help

We knew that compiled releases would make deployments faster, but we had trouble utilizing them in our test pipeline.
Creating the compiled release as part of the pipeline does not make the pipeline faster since the compilation still has to take place;
it only becomes valuable if you can use it later to avoid recompiling.

We would save time if we could find a way to compile the release up front and only compile the packages that had changed.

### Solution

We created a shared BOSH director where compiled releases are created before deployments in our pipelines.
Because the BOSH director is never cleaned up, it's able to reuse compiled packages that have not changed.

There is now a job at the beginning of our pipeline that compiles the release and downloads that release as a Concourse resource
before immediately passing it along and uploading it to another director. This step means that the second bosh director,
the one that is always cleaned up, no longer needs to compile anything.

### Caveats

When BOSH is exporting a compiled release, it creates a lock on the release name.
This means that you can not have multiple jobs uploading and exporting releases for the same BOSH release simultaneously.
To solve this problem we created a [concourse pool resource](https://github.com/concourse/pool-resource) that acts as a mutex for our BOSH director doing the compilation.

Exporting a release does take a bit of time, so depending on the compilation time of your BOSH release this may not be a win.

### Resources

[Creating BOSH compiled releases.](https://bosh.io/docs/compiled-releases.html)
[Our script used for compiling a release.](https://github.com/cloudfoundry-incubator/cf-mysql-ci/blob/a12f8a25bd84413e4651350ea97491cf5fc84a1a/scripts/compile_release)
[Concourse pipeline configuration that compiles releases.](https://github.com/cloudfoundry-incubator/cf-mysql-ci/blob/dbc2ba48390c0250c8ce201974230f1ba5aa82ae/ci/pipelines/cf-mysql-acceptance.yml#L154)
