+++
authors = ["dgustafsson", "hlinnakangas"]
categories = ["Greenplum Database", "PostgreSQL", "Greenplum", "Development"]
date = 2018-03-21T15:16:22Z
draft = true
short = "Summary of Pivotal Contributions to PostgreSQL 11"
title = "How Pivotal supports the Development of PostgreSQL 11"
+++

Ever since Pivotal announced to make [Greenplum Database](https://greenplum.org/) Open Source, and we started merging newer [PostgreSQL](https://www.postgresql.org/) versions, we also decided to support the upstream project. This happens in various ways: by developing and contributing new features, reviewing patches from other contributors, or sending bugfixes to upstream.


## Our Motivation

Not only is the PostgreSQL Project an awesome project with a thriving community, and it is fun to work with, in the long run this strategy has several advantages for us.

Eventually the Greenplum Database merge process might catch up with PostgreSQL releases, and every feature which is not only in our product but also available in upstream makes the merge process easier for us.

This strategy further closes the gap between the original project and the fork, and makes it easier for users to use both projects in parallel.

Last but not least, bringing features into upstream PostgreSQL "exposes" these features to a broader range of reviewing developers, and the feature is tested on a wider range of platforms, compared to what is supported by Greenplum Database.


## Our Contributions

With PostgreSQL entering the home stretch, it is time to look back and see what we contributed, and where we might be able to improve in the future.

This chapter breaks into three (FIXME: four, if there are other kinds of contributions) different sections:

* Features we contributed
* Features we reviewed
* Bugfixes we provided

That said, this list is not complete, because we do not count all the small fixes and patches we provided. Let's just focus on the major items here.

### Features we contributed

#### Fix shm_toc.c to always return buffer-aligned memory

This fixes a problem with alignment of memory chunks, which failed on several 32-bit systems.
