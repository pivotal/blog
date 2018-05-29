+++
authors = ["dgustafsson", "hlinnakangas"]
categories = ["Greenplum Database", "PostgreSQL", "Greenplum", "Development"]
date = 2018-05-29T10:16:22Z
draft = true
short = "Merging PostgreSQL 8.4, 9.0 and 9.1 into Greenplum Database"
title = "Merging PostgreSQL 8.4, 9.0 and 9.1 into Greenplum Database"
+++



The last several months have been very busy. After initially [merging PostgreSQL 8.3](http://engineering.pivotal.io/post/gpdb_merge_with_postgresql_8.3/) into the Greenplum Database code base, and releasing Greenplum Database version 5, we continued to merge newer PostgreSQL versions. Right now, the [latest merged version is PostgreSQL 9.1](https://github.com/greenplum-db/gpdb/commit/25a90396cd1c52d252a37986e12b63e8e037aa83). Time for a short review.



## Team effort

This merges are a huge team effort, and are proof that distributed teams can work on large scale projects and fix hundreds of open issues in a relatively short time. A total of 19 people contributed to the last merge, helping with solving all outstanding issues and merge conflicts. Another big help is the constant feedback from the Continuous Integration pipeline, which runs all the tests all the time, and shows where tests fail and need to be investigated.

To give you an impression of the amount of changes for the PostgreSQL 9.1 merge: the commit changed close to 3,000 files, added more than 200,000 new entries, and also deleted 65,000 entries from the code base.



## Notable features

The merges bring many new features into Greenplum Database, and the list is too long to list it here completely. But a few items are worth noting:

* Unlogged tables (the table is written to disk, but not the transaction log - this saves I/O and bandwidth): useful for staging tables which do not need to be stored permanently, but are truncated or deleted after loading the data into the database
* SECURITY LABEL: this lays the foundation for external security providers
* Collations allow different text sort orders and character classifications, and can now be applied on a per-column basis - previously this was only available on a per-database level
* GROUP BY can now use columns from underlying tables, without specifying them in the SELECT column list - this works as long as the column names are not ambiguous
* Column level permissions: no more views required in order to control access to specific columns in a table
* Expanded psql support: The psql utility can now work with any Greenplum Database version, it’s no longer required to use the one from the currently running version
* Major overhaul of client and server certificates: both sides can now be authenticated, a must have for security aware users
* Mirrors now use the WAL-based replication from PostgreSQL: the previous file-based replication was removed - In the future this allows multiple mirrors, although more work is required to make that happen
* Changes for new PGXS format: this allows, in theory, to use many plugins from the PostgreSQL world
* The COPY code was refactured, to match more closely with the upstream code


## Open items

Although the majority of the code base from PostgreSQL 8.4, 9.0 and 9.1 is merged in, a small number of items are still open, and we have to decide if these will be worked on, or are not necessary in Greenplum Database. To name a few:

* UUID module: this is useful, but support for the external libraries needs to be solved first
* Recursive CTE: this is quite useful, but needs changes in the planner
* autoexplain module: task is open for takers
* pg_stat_statements module: the data is not sent to the master - yet
* Hot Standby: this topic needs more discussion
