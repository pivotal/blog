---
authors:
- dgustafsson
categories:
- PostgreSQL
- Greenplum Database
- Databases
date: 2016-08-12T22:11:44+02:00
draft: false
short: |
  Greenplum merge with PostgreSQL 8.3
title: GPDB merge with PostgreSQL 8.3
---


# Greenplum merge with PostgreSQL 8.3

A long time ago, Greenplum was forked from PostgreSQL, and became a separate product.

When Greenplum was started, PostgreSQL 7.4 was the latest and greatest available release. During the releases from 7.4 to 8.2, every major version of PostgreSQL was merged into Greenplum. Then the decision was made to fork the product, and no longer merge newer releases. Up to today, Greenplum shows the 8.2 in its version string:

```
SELECT version();
                      version
--------------------------------------------------------
 PostgreSQL 8.2.15 (Greenplum Database 4.3.8.2 build 1)
```
 
Over time, a substantial amount of the new features from PostgreSQL were merged into Greenplum. However it turned out that this process became more and more complicated. And customers kept asking for features they know from PostgreSQL.

Then, a while ago the decision was made to merge Greenplum with PostgreSQL again. This will bring in more features into the product, improve the driver situation, and hopefully attract developers to write code for both products - or make merging code from one product to another more easy.


## About the merge

One of the goals of the merge was - and is - to keep the code and commit history intact. Therefore everything can’t just be merged in one huge commit, but changes, conflicts and commit messages must be sorted out. As a first step, the merge with PostgreSQL 8.3 was approached.

In the beginning, git showed roughly 6600 conflicts.

In our first approach, we picked a number commits (usually 10 - 25), fixed bugs and conflicts, and tried it out. Then the changes were committed to the Greenplum master branch.

Turns out, that this approach is slow, and brings many problems and other conflicts. One major problem is that this keeps changing the master code base with major changes on an almost daily basis. Many other teams have to be involved to fix failing regression tests after the commits. And it needs to happen quickly in order to keep the tests green. After having merged about 25% of the changes, it became crystal clear that this approach is not working well ..

During a team meeting we discussed the pros and contras of this approach, and decided to try a different strategy. The remaining ~75% of the changes were merged into a dirty branch, and we kept working on making this branch usable and pass the regression tests. In addition, 2 or 3 rebases were required in order to keep our working branch in sync with the master branch.

After about two months, our branch was in a state which passed the regular regression tests, had only a small number of conflicts when running with Orca, no more source code conflicts, and an updated list of commit messages. At this point we decided to merge this back into the master branch, in order to not keep the work sitting around and accumulate more changes. The Orca team kept working on their regression failures after the merge. Also we cherry-picked a few independent features and bugfixes and merged them into the master branch ahead of the huge merge. I gave a short presentation about this process at the [Stockholm PostgreSQL User Group Meeting](https://www.meetup.com/Stockholm-PostgreSQL-User-Group/events/229759302/).



## New Features

The full list of features is listed in the PostgreSQL 8.3 release notes, some notable highlights include (in no specific order):

* [ENUM](https://www.postgresql.org/docs/8.3/static/datatype-enum.html) and [UUID](https://www.postgresql.org/docs/8.3/static/datatype-uuid.html) datatypes
* [Full text search](https://www.postgresql.org/docs/8.3/static/textsearch.html)
* HOT ([Heap-Only Tuples](http://pgsql.tapoueh.org/site/html/misc/hot.html))
* Spreading out checkpoint writes
* Top N sorting
* [Removal of implicit casts](http://petereisentraut.blogspot.de/2008/03/readding-implicit-casts-in-postgresql.html)
* [Plan cache invalidation](http://merlinmoncure.blogspot.de/2007/09/as-previously-stated-postgresql-8.html)

Most importantly, this merge brings all the catalog changes required to do [database upgrades](https://www.postgresql.org/docs/current/static/pgupgrade.html) in the future. We are not yet there, and are still missing tools to do the upgrade process - but the groundwork is laid. It also relieves the situation with PostgreSQL drivers and tools, many of them no longer supporting old versions (like 8.2).

```
SELECT version();
                      version
------------------------------------------------------------
 PostgreSQL 8.3.23 (Greenplum Database 4.3.99.00 build dev)
```


## Features whose functionality differ between PostgreSQL and Greenplum

List taken from the commit message:

[Lazy XIDs](https://www.postgresql.org/message-id/46DD9464.2010906%40phlo.org) feature in upstream reduces XID consumption, by not assigning XIDs to read-only transactions. That optimization has not yet been implemented for GPDB distributed transactions, however, so practically all queries in GPDB still consume XIDs, whether they're read-only or not.

[temp_tablespaces](https://www.postgresql.org/docs/9.1/static/runtime-config-client.html) GUC was added in upstream, but it has been disabled in GPDB, in favor of GPDB-specific system to decide which [filespace](http://gpdb.docs.pivotal.io/4350/admin_guide/ddl/ddl-tablespace.html) to use for temporary files.

B-tree indexes can now be used to answer "col IS NULL" queries. That support has not been implemented for bitmap indexes.

Support was added for "[top N](http://use-the-index-luke.com/sql/partial-results/top-n-queries)" sorting, speeding up queries with ORDER BY and LIMIT. That support was not implemented for *tuplesort_mk.c*, however, so you only get that benefit with *enable_mk_sort=off*.

Multi-worker [autovacuum support](https://www.postgresql.org/docs/8.3/static/routine-vacuuming.html) was merged, but autovacuum as whole is still disabled in GPDB.

One notable feature included in this merge is the support for plan cache invalidation. GPDB contained a hack to invalidate all plans in master between transactions, for the same purpose, but the proper plan cache invalidation is a much better solution. However, because the GPDB hack also handled dropped/recreated functions in some cases, if we just leave it out and replace with the 8.3 plan cache invalidation, there will be a regression in those cases. To fix, this merge commit includes a backport the rest of the plan cache invalidation support from PostgreSQL 8.4, which handles functions and operators too. As a result of that, the *gp_plpgsql_clear_cache_always* GUC is removed, as it's no longer needed. This also includes new test cases in the plpgsql cache regression test, to demonstrate the improvements.


## What’s next

Now that PostgreSQL 8.3 is merged in Greenplum, we plan to bump the version number from 4.3 to 5.0. However we are still not ready to release this product. Beyond merging the code, we also need to work on:

* Implement the tools and process to do an upgrade, especially from 4.3 to 5.0
* Stabilizing the catalog changes, and occasionally catalog corruptions
* Improve the replication process between primary and standby
* Only with these features in place, we truly can say that we made one huge step forward towards merging with the most recent PostgreSQL version. Without a good upgrade procedure in place, we will hurt many existing customers, and don’t give them a chance to try out the new version.

We also plan to merge more recent PostgreSQL versions, 8.4, 9.0 and so on. But that will probably happen after we released 5.0.


