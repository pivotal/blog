---
authors:
- cunnie
categories:
- Concourse
date: 2016-09-01T17:29:49-07:00
draft: false
short: |
  Use Concourse's badges to display the health of your project
title: Concourse has Badges
---

The [Concourse](http://concourse.ci/) Continuous Integration (CI) server has an
API endpoint that displays a badge which shows health of your project:

<code>http(s)://<span style="color: green; font-style: italic">concourse-server</span>/api/v1/pipelines/<span style="color: green; font-style: italic">pipeline-name</span>/jobs/<span style="color: green; font-style: italic">job-name</span>/badge</code>

## 0. Abstract

{{< responsive-figure src="/images/passing.svg" >}}

Open Source projects that have CI (e.g.
[Bootstrap](https://github.com/twbs/bootstrap),
[Node.js](https://github.com/nodejs/node)) often feature status badges (also
known as images or icons) to display the health of their projects.  CI servers
such as [Travis CI](https://travis-ci.org/) offer status badges. Concourse CI
also offers status badges.

The status badge is a [Scalable Vector
Graphics](https://en.wikipedia.org/wiki/Scalable_Vector_Graphics) (SVG) image
available from the Concourse API. <sup>[[Concourse
versions]](#concourse_versions)</sup>

## 1. Real World Example

The [sslip.io](https://github.com/cunnie/sslip.io) project has a [Concourse
CI pipeline](https://ci.nono.io/pipelines/sslip.io) consisting of one job.

The pipeline is *sslip.io* (same name as the project, a simple naming scheme),
and the job's name is *check-dns*.

In the project's [README.md]
(https://github.com/cunnie/sslip.io/blob/276311f219882c2d7228d271109f21c6e7b0698a/README.md),
the following line displays the status badge and links to the Concourse server's
pipeline:

```md
[![ci.nono.io](https://ci.nono.io/api/v1/pipelines/sslip.io/jobs/check-dns/badge)](https://ci.nono.io/?groups=sslip.io)
```

## 2. It's at the Job Level, ***not*** the Pipeline Level

The badges display at the job level, which leads to a conundrum: which
job best represents the health of the project?

Let's assume a simple pipeline with two jobs: unit and integration.
The *integration* job is only run if the *unit* job has succeeded.

A reasonable choice to represent the health of the project would be the
*integration* job, but there is a problem: The *integration* job's badge might
show "passing" (that the code is good) when the unit tests have failed (see
figure below). *The badge would show the build as passing when in reality the build has failed*:

{{< responsive-figure src="/images/unit-integration-conundrum.png" >}}

Similarly with choosing the *unit* job to represent the health of the project:
the *unit* job may have passed but the *integration* job may have failed.
Again, the *badge would show the build as passing when the build has failed*.

One way to address this would be to display several badges, one for each job —
Bootstrap has demonstrated that it's reasonable to have more than one badge on
a project's page. <sup>[[Bootstrap badges]](#bootstrap_badges)</sup>

For example:

<table style="max-width: 0;">
<tr>
<th>Job</th><th>Status</th>
</tr><tr>
<td>unit</td><td><img src="/images/passing.svg" /></td>
</tr><tr>
<td>integration</td><td><img src="/images/passing.svg" /></td>
</tr>
</table>

This begs the question: why not have badges at the pipeline level and not at the
job level? The short answer is this: Concourse's jobs have a status, but the
pipelines don't. The pipelines weren't designed to have a status, and thus
implementing a badge at the pipeline level is not a trivial task.

## 3. The Five Types of Badges

| Badge | Significance |
|---|---|
| [![ci.nono.io](/images/passing.svg)](https://ci.nono.io/?groups=sslip.io) | The most recent run of the job passed &mdash; you want this. |
| [![ci.nono.io](/images/failing.svg)](https://ci.nono.io/?groups=sslip.io) | The most recent run of the job failed. There is probably a bug in your code. |
| [![ci.nono.io](/images/aborted.svg)](https://ci.nono.io/?groups=sslip.io) | You aborted the most recent run of the job; maybe it was stuck.  |
| [![ci.nono.io](/images/unknown.svg)](https://ci.nono.io/?groups=sslip.io) | The job has never been run. |
| [![ci.nono.io](/images/errored.svg)](https://ci.nono.io/?groups=sslip.io) | Concourse ran into an error and couldn't complete the job. |

## Acknowledgements

[Chris Brown](https://github.com/xoebus) wrote much of the code during his lunch
hour. [Kris Hicks](https://github.com/krishicks) shepherded the [pull
request](https://github.com/concourse/atc/pull/77) through the acceptance
process, refashioning the code along the way. He also reviewed this post. Any
excellence is theirs, gnarliness, mine.

[shields.io](http://shields.io/) was used to generate the initial badges.

---

## Assets

A [pipeline](https://ci.nono.io/pipelines/badges) that displays all five types
of badges, and its
[YAML](https://github.com/cunnie/sslip.io/blob/e89d79cb7c6c77fa6160756d08ad8383f0f23340/ci/pipeline-badges.yml).

A [pipeline](https://ci.nono.io/pipelines/simple) that has two jobs (unit and
integration), and its
[YAML](https://github.com/cunnie/sslip.io/blob/276311f219882c2d7228d271109f21c6e7b0698a/ci/pipeline-simple.yml).

## Footnotes

<a name="concourse_versions"><sup>[Concourse versions]</sup></a>The badge API
endpoint was added in Concourse v1.3.0.

The badge API endpoint was changed briefly in v2.0.0 and then reverted in
v2.0.1.

If your server is v2.0.0, this is the API endpoint:

<code>http(s)://<span style="color: green; font-style: italic">concourse-server</span>/api/v1/teams/main/pipelines/<span style="color: green; font-style: italic">pipeline-name</span>/jobs/<span style="color: green; font-style: italic">job-name</span>/badge</code>

<a name="bootstrap_badges"><sup>[Bootstrap badges]</sup></a>An open source
developer once remarked, "Bootstrap's [project
page](https://github.com/twbs/bootstrap) has more badges than a Third World
General!"

We'd like to commend the Bootstrap developers for their commitment to CI,
cross-platform compatibility, and just about everything that makes an open
source project successful — they've set a high bar to which all of us aspire.
