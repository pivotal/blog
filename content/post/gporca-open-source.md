---
authors:
- addison
categories:
- Big Data
- Databases
- Query Optimization
- SQL

date: 2016-01-28T07:00:00-08:00
draft: false
short: |
  GPORCA has achieved an overall 5X performance improvement across all 99 industry standard benchmark queries. Now we call on the community to help take the project to the next level.
title: GPORCA, A Modular Query Optimizer, Is Now Open-Source
---

# GPORCA, A Cost-Based Query Optimizer, Is Now Open Source

Pick your favorite Big Data statistic; we all know that the growth of data has been astounding. What hasn’t kept up is our ability to process this data.  Even the newest big data technologies such as [Apache Spark™](http://spark.apache.org/) are using [rule-based](https://databricks.com/blog/2015/04/13/deep-dive-into-spark-sqls-catalyst-optimizer.html) approaches to query optimization, which often miss potential faster execution plans.

This is why the Pivotal R&D team poured years of work into developing a new query optimizer called GPORCA. Improving the intelligence of query planning was a missed chance in database engineering with huge opportunity for further improving performance.

The truth is, the industry can’t wait for a war over performance to play out between the many new data technologies. By collaborating with leading developers, it will be possible to benefit all users of different database technologies and advance innovation in the industry faster. That is why Pivotal is announcing that the GPORCA query optimizer is now open source and available under the [Apache License v2.0](http://www.apache.org/licenses/LICENSE-2.0).

Currently it is possible to run GPORCA with open source projects [Greenplum Database](http://greenplum.org/) and [Apache HAWQ (incubating)](http://hawq.incubator.apache.org/). We call on the database engineering community to help us increase the portability of GPORCA to work with even more data management platforms.

# Why Should I Care?

Historically, every database has shipped with its own optimizer. That means every software developer spent valuable R&D cycles building one, and maintaining it. This is not a scalable solution, nor does it foster collaborative research.

GPORCA is built as an external plugin, which makes it the perfect test bed for database research that can benefit a wide variety of databases.

Furthermore, GPORCA isn’t just a tool for research and development. It is an enterprise-grade, query optimizer that is handling some of the most demanding SQL workloads at truly Big Data scale.

# What Is GPORCA?

GPORCA is a modular, cost-based query optimizer based on 30 years of [database research](https://d1fto35gcfffzn.cloudfront.net/big-data/white-paper/SIGMODHAWQAdvantages.pdf). Simply put, it takes in a parsed query statement and returns what it considers to be the fastest execution plan for the database. It combines the query with metadata (e.g. statistics, schemas, etc.) and information about the database cluster to generate the execution plan. GPORCA is portable and modular because it can work with more than one database and can easily support new database operators.

## What Can GPORCA Do?

At Pivotal, we are constantly benchmarking our database products to ensure they are getting faster. Currently GPORCA is achieving an overall 5X improvement compared to Pivotal Greenplum’s legacy planner across all 99 of the industry’s most trusted benchmark queries. Some of the very complex queries are up to 1000x faster!

{{< responsive-figure src="/images/gporca/gporcaPerf.png" >}}

Three features of GPORCA are primarily responsible for these performance gains: Dynamic Partition Elimination, SubQuery Unnesting, and Common Table Expression. To read more about these three features, please check [this blog post](https://blog.pivotal.io/big-data-pivotal/products/greenplum-database-adds-the-pivotal-query-optimizer) published in 2015.

GPORCA achieves its portability and modularity by running outside the core database system. Furthermore, the primary optimization techniques are componentized, allowing new operators, transformation, statistical/cost models and other techniques to be added with ease.

{{< responsive-figure src="/images/gporca/gporcaArch.png" >}}

For a more technical deep-dive into GPORCA, we encourage you to take a look at the [white paper](http://pivotal.io/big-data/white-paper/orca-a-modular-query-optimizer-architecture-for-big-data).

# What Can’t GPORCA Do?

As are many things in life, writing a modular query optimizer is about finding balance.  The original design for GPORCA optimized for analytical queries on data warehouses.  We focused on queries that typically would take a few hours, and made them run in a few minutes. For these long running queries, the time needed to compute an optimal plan is small compared with the duration of the query itself.  However, for shorter queries, the time needed to find an optimal plan becomes more important for overall execution time, so this is an area that needs future development effort. This is all about finding balance and bottlenecks.

Furthermore, GPORCA is not feature complete compared to the current planner in GPDB and HAWQ, which is a modified version of the Postgres planner designed to work on MPP databases. When GPORCA encounters an operator it does not currently support, it falls back to the legacy planner.

# Where Is GPORCA Going?

GPORCA needs to become feature complete, matching PostgreSQL’s current support and beyond. Support for external parameters, cubes, multiple grouping sets, inverse distribution functions, ordered aggregates, and indexed expressions is all on the GPORCA roadmap.

With parity and better performance for shorter running queries comes the ultimate goal of GPORCA. We hope one day, GPORCA is the defacto query optimizer in PostgreSQL.

# Why Does GPORCA  Need YOU?

GPORCA is organized as a sub-project of [Greenplum Database](http://greenplum.org/). However, GPORCA is designed to be database agnostic. The contributor team here at Pivotal primarily uses the Greenplum Database as a test bed and to ensure that the GPORCA API is easy to implement.

Here’s how to  get started with GPORCA and the GPORCA community:

1. Head over to [github](https://github.com/greenplum-db/gpos) and check out the GPOS README. After that, you will need to compile both GPORCA and GPDB.

2. Once GPDB is up and running with GPORCA, `set optimizer=on;` will turn on GPORCA.

3. Run explain analyze with GPORCA on and off to see if GPORCA calculates a better query plan.

4. Subscribe to the GPDB developer mailing list: [gpdb-users+subscribe@greenplum.org](mailto:gpdb-users+subscribe@greenplum.org)

5. Get involved in the discussions on github.

6. Collaborate on stories in [Pivotal Tracker](https://www.pivotaltracker.com/n/projects/1523545)

7. Sign the [ICLA/CCLA](https://github.com/greenplum-db/greenplum-db.github.io/wiki/Greenplum-Database-project-contributions-FAQ#q-do-i-need-to-sign-anything-in-order-to-contribute-code-to-greenplum-database) and start sending us [pull requests](https://github.com/greenplum-db/greenplum-db.github.io/wiki/Merging-Pull-Requests)!
