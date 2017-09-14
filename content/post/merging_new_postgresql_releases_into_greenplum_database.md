+++
authors = ["hlinnakangas", "dgustafsson", "ascherbaum"]
title = "Merging new PostgreSQL versions into Greenplum Database"
short = "This blog post explains how we plan to merge newer PostgreSQL versions into Greenplum Database."
draft = true
date = "2017-09-07T20:00:00Z"
categories = ["Greenplum Database","PostgreSQL", "Greenplum"]

+++

[_Greenplum Database_](http://greenplum.org/) was originally forked from [_PostgreSQL_](https://www.postgresql.org/) 8.2. With version 5.0, we [merged _PostgreSQL_ 8.3](http://engineering.pivotal.io/post/gpdb_merge_with_postgresql_8.3/) and learned quite a lot along the way. In particular, it is not enough to just merge the database code - the tooling around the database needs to evolve as well, and customers and users want and need an upgrade path. This all got fixed in the past months, and the 5.0 version will roll out of the door soon.

Time to start thinking about the next steps!

## GitHub

Our development takes place on [_GitHub_](https://github.com/greenplum-db/gpdb). After cutting the 5.0 branch ([5X_STABLE](https://github.com/greenplum-db/gpdb/tree/5X_STABLE)), the master branch is again open for new features and patches, which will go into upcoming release.

In order not to "disturb" the main repository with too many commits from the merge, this process was moved into a separate [public repository](https://github.com/greenplum-db/gpdb-postgres-merge). Anyone is welcome to clone this repository and look into merge conflicts. After all conflicts in this repository are solved, and all tests pass, it will be merged back into the main repository.


## Testing

The master repository runs a [_Concourse CI_](https://concourse.ci/) pipeline which constantly [tests every new PR and commit](https://gpdb.ci.pivotalci.info/teams/gpdb/pipelines/gpdb_master). This CI is public. Every time the CI goes red, development is stopped shortly and the reason for the failure is investigated.

For the merge, a [separate pipeline](https://gpdb.ci.pivotalci.info/teams/gpdb/pipelines/postgres_merge) is monitoring the merge repository. We expect this pipeline to be more read than green, nevertheless it will show the progress which is made while resolving all the conflicts.


## Planned steps

Our plan is to have a major release of _Greenplum Database_ once a year, this follows the _PostgreSQL_ release cycle. We also plan to merge 3 _PostgreSQL_ major versions before we release version 6.0 of Greenplum Database. This gives us roughly 3 months to merge one major version, plus additional time to prepare the upcoming release.

The merge of one major _PostgreSQL_ version is again broken down into smaller steps. Each step will process roughly 2-4 months of upstream commits.

Several major features are approached in separate steps and not as part of the merge process. In particular the Windowing functions create a large number of conflicts, as _Greenplum Database_ has it's own implementation, which was already there when this feature was added to _PostgreSQL_.

Another problematic part is the replication code. The existing file-based replication in _Greenplum Database_ will be replaced with [WAL Replication](https://www.postgresql.org/docs/8.4/static/wal-intro.html) (Write-Ahead Logging) from upstream, which was introduced in _PostgreSQL_ 9.0. This feature offers more flexibility for setting up secondary segments, but also requires refactoring of management tools.


## Communication

We have several means of communication:

* [Mailing Lists](http://greenplum.org/mailing-lists/)
* [#Greenplum](irc://freenode.net/#greenplum) [IRC](https://en.wikipedia.org/wiki/Internet_Relay_Chat) channel on [freenode](https://freenode.net/)
* [Greenplum](https://greenplum.slack.com/) on [Slack](https://slack.com/)


## How can you help?

If you want to follow the merge process, the best place is to checkout the [repository](https://github.com/greenplum-db/gpdb-postgres-merge) and look for git merge conflicts.
