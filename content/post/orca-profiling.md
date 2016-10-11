---
authors:
- Add another author here
- vraghavan 
- d
- hsyuan
- oarap
- xinzweb
- ivannovick
categories:
- Databases
- GPDB
- HAWQ
- PQO
- GPORCA
- Query Optimization
- SQL
date: 2016-09-28T14:01:14-07:00
draft: true
short: |
  [GPORCA](https://github.com/greenplum-db/gporca) is Pivotal’s Query Optimizer for [Greenplum Database](https://github.com/greenplum-db/gpdb) and [Apache HAWQ](https://github.com/apache/incubator-hawq) (incubating). In this post, we describe how users can profile query compilation with GPORCA. This will aid user in understanding where the time and memory is being spent by and how to influence its decision making.
title: Profiling Query Compilation Time with GPORCA
---

Pivotal’s Query Optimizer (PQO) is designed to find the fastest way to execute SQL queries in a distributed environments such as Pivotal’s [Greenplum Database](https://github.com/greenplum-db/gpdb). The open source version of PQO is termed as [GPORCA](https://github.com/greenplum-db/gporca). When processing large amounts of data, a 
naive query plan might take orders of magnitude more time than the optimal plan, in some cases will not complete after several hours as shown in our experimental study <sup><a href="1" class="alert-link">[1]</a></sup>. To generate the optimal plan, GPORCA considers thousands of alternative query execution plans and makes a cost based decision. 

In this post, we will describe parameter settings that a GPDB users can use to 

* Influence GPORCA's decision process to pick a certain class of execution plans (also known as hints).
* Print the GPORCA state during the query optimization phases.
* Enumerate the list of transformations that were applied during query optimization.
* Report where the query compilation time was spent inside GPORCA.

Pivotal’s Greenplum Database (GPDB) is based on Postgres. We therefore use the Grand Unified Configuration (GUC) subsystem inside PostgreSQL to pass optimizer specific parameter settings to GPORCA.

## Running example

In the blog, I will be using the Query Q1 from the TPC-H Benchmark[2] as the illustrating example.

```
select  'tpch1',
l_returnflag,
l_linestatus,
sum(l_quantity) as sum_qty,
sum(l_extendedprice) as sum_base_price,
sum(l_extendedprice * (1 - l_discount)) as sum_disc_price,
sum(l_extendedprice * (1 - l_discount) * (1 + l_tax)) as sum_charge,
avg(l_quantity) as avg_qty,
avg(l_extendedprice) as avg_price,
avg(l_discount) as avg_disc,
count(*) as count_order
from lineitem
where l_shipdate <= date '1998-12-01' - interval '108 day'
group by (l_returnflag, l_linestatus)
order by (l_returnflag, l_linestatus);

```

## GPORCA Workflow

{{< responsive-figure src="/images/orca-profiling/arch.png" >}}

GPORCA and its host system (GPDB or HAWQ) use a data exchange language (DXL) to exchange information such as the query, metadata information, database settings, etc.

* **Algebrizer (Query To DXL Translator)**, takes as input a parsed GPDB query object and returns its DXL representation of the input query object. The serialized DXL is then shipped to GPORCA for optimization. DXL has some basic assumptions such as (a) having clauses are converted into select predicates, (2) group by logical operator has a project list that contains only grouping columns and aggregates and not expression, etc. To ensure that the DXL conforms to these assumption the algebrization mutates the input query into a normalized query form. 

* **DXL To Logical Expression Translator** takes as input the DXL query object and converts it into an internal logical tree representation on which optimization is done.

* **Expression Pre-Processing** takes as input an logical expression tree and produces an equivalent logical expression tree after applying some transformation rules. In GPORCA there are two classes of transformation rules, namely (1) rules that are always beneficial such as pushing select to the scan, removing unnecessary computed columns, contradiction detections, etc., and (2) rules that generate equivalent plans but the best plan is a cost based decision such as join order, multi-stage aggregation, etc.

* **GPORCA Optimization Phases**  Orca uses a search mechanism to navigate through the space of possible plan alternatives and identify the plan with the least estimated cost. The search mechanism is enabled by a specialized  {\em Job Scheduler} that creates dependent or parallel work units to perform query optimization in three main steps: *exploration*, where equivalent logical expressions are generated, *implementation* where physical plans are generated, and *optimization*, where required physical properties (e.g., sort order) are enforced  and plan alternatives are costed. 
* **Statistics Derivation** takes as input a logical expression and statistics to return the output cardinality.

* **Physical Expression To DXL Translation** takes as input an expression tree that represents the physical plan and converts it into its DXL representation.

* **DXL to PlannedStmt Translator** Takes the DXL representation of the physical plan and converts it into GPBD specific planned statement object.

* **Metadata Translator** converts all database objects needed during query optimization such as table schema, indexes, constraints and column statistics.

A detailed look at the steps involved in optimizing a query with GPROCA can be found in our white paper <sup><a href="2" class="alert-link">[2]</a></sup> and in our GPDB documentation <sup><a href="3" class="alert-link">[3]</a></sup>.

## How does one know where GPORCA is spending its time?

There are scenarios when a user may want to see what is the most time consuming aspect of the query compilation. Based on this the user may decide to provide hints to GPORCA to pick a plan of a particular shape or produce a plan quicker.

To express this intent of logging GPORCA metrics, GPDB users must enable **both** of these GUCs at the query level.

* `set optimizer_print_optimization_stats = on;`
* `set client_min_messages='log';`


For TPC-H query Q1 enabling these GUCs produces the following GPORCA metrics to be displayed.

{{< responsive-figure src="/images/orca-profiling/modified-output.png" >}}

GPORCA metrics that are measured are:

* Break down of where GPORC spends its time
* Time needed for GPORCA to get the relevant information about the database objects (such as, schema, statistics, indexes available, constraints, etc.) from the host system.
* List of transformation rules employed for plan generation


## Footnotes
<a name="1"><sup>[1]</sup></a> [New Benchmark Results: Pivotal Query Optimizer Speeds Up Big Data Queries Up To 1000x](https://blog.pivotal.io/big-data-pivotal/products/new-benchmark-results-pivotal-query-optimizer-speeds-up-big-data-queries-up-to-1000x).

<a name="2"><sup>[2]</sup></a> [Orca: A Modular Query Optimizer Architecture for Big Data](https://pivotal.io/big-data/white-paper/orca-a-modular-query-optimizer-architecture-for-big-data).

<a name="3"><sup>[3]</sup></a> [Enabling PQO in GPDB](http://gpdb.docs.pivotal.io/4390/admin_guide/query/topics/query-piv-opt-enable.html).

