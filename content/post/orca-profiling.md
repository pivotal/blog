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
date: 2016-10-12
draft: false
short: |
  GPORCA is Pivotal’s Query Optimizer for Greenplum Database and Apache HAWQ (incubating). In this post, we describe how users can profile query compilation with GPORCA. This will aid users in understanding which of GPORCA's steps is the most resource intensive, and what transformations are being triggered. Based on this information, users can provide query hints to reduce or increase the search space, see where the time and memory is being spent, and learn how to influence its decision making.
title: Profiling Query Compilation Time with GPORCA
---

Pivotal’s Query Optimizer (PQO) is designed to find the fastest way to execute SQL queries in a distributed environments such as Pivotal’s [Greenplum Database](https://github.com/greenplum-db/gpdb). The open source version of PQO is named [GPORCA](https://github.com/greenplum-db/gporca). When processing large amounts of data in a distributed environment, a 
naive query plan might take orders of magnitude more time than the optimal plan. In some cases the query plan will not complete, even after several hours, as shown in our experimental study <sup><a href="#1" class="alert-link">[1]</a></sup>. To generate the optimal plan, GPORCA considers thousands of alternative query execution plans and makes a cost-based decision. 

In this post, we will describe parameters that a GPDB user can set to:

* Influence GPORCA's decision process to pick a certain class of execution plans.
* Print the GPORCA state during the query optimization phases.
* Enumerate the list of transformations that were applied during query optimization.
* Report where the query compilation time was spent inside GPORCA.

Pivotal’s Greenplum Database (GPDB) is based on Postgres. We therefore use the Grand Unified Configuration (GUC) subsystem inside PostgreSQL to pass optimizer specific parameter settings to GPORCA.

## Running example

In this blog, we use Query Q1 from the TPC-H Benchmark as the illustrating example.

```
-- tpch q1
SELECT 
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
FROM lineitem
WHERE l_shipdate <= date '1998-12-01' - interval '108 day'
GROUP BY (l_returnflag, l_linestatus)
ORDER BY (l_returnflag, l_linestatus);
```

## GPORCA Workflow

{{< responsive-figure src="/images/orca-profiling/arch.png" >}}

GPORCA and its host system (GPDB or HAWQ) use a data exchange language (DXL) to pass information such as the query, metadata information, and database settings.

* **Algebrizer (Query To DXL Translator)**, takes as input a parsed GPDB or HAWQ query object and returns its DXL representation. The serialized DXL is then shipped to GPORCA for optimization. DXL assumes that `having` clauses are converted into select predicates, and the `group by` logical operator has a project list that contains only grouping columns and aggregates and not expressions. The algebrization mutates the input query into a normalized query form to ensure the DXL conforms to these assumptions.

* **DXL To Logical Expression Translator** takes as input the DXL query object and converts it into an internal logical tree representation on which optimization is done.

* **Expression Pre-Processing** takes as input a logical expression tree and produces an equivalent logical expression tree after applying some heuristics such as pushing select to the scan, removing unnecessary computed columns, and detecting contradictions.

* **GPORCA Optimization Phases**  GPORCA uses a search mechanism to navigate through the space of possible plan alternatives and identify the plan with the least estimated cost. The search mechanism is enabled by a specialized `Job Scheduler` that creates dependent or parallel work units to perform query optimization in three main steps. First, the `exploration` phase increases the search space by generating equivalent logical expressions for each subexpression. Second, in the `implementation` phase, GPORCA considers alternative physical implementation of the different operators. For instance, it might choose between implementing join via a nested loop loop join or a hash join. Or it might choose between implementing a aggregate operation via a streaming or a hash based implementation. Lastly, in the `optimization` phase we enforce the required physical properties (such as distribution, and sort order) and cost the different plan alternatives to pick the best execution plan. 

* **Statistics Derivation** takes as input a logical expression and statistics to return the output cardinality.

* **Physical Expression To DXL Translation** takes as input an expression tree that represents the physical plan and converts it into its DXL representation.

* **DXL to PlannedStmt Translator** Takes the DXL representation of the physical plan and converts it into a host (GPBD or HAWQ) specific planned statement object.

* **Metadata Translator** converts all database objects needed during query optimization such as table schema, indexes, constraints and column statistics.

A detailed look at the steps involved in optimizing a query with GPROCA can be found in our white paper <sup><a href="#2" class="alert-link">[2]</a></sup> and in our GPDB documentation <sup><a href="#3" class="alert-link">[3]</a></sup>.

## How does one know where GPORCA is spending its time?

There are scenarios when a user may want to see what is the most time consuming aspect of the query compilation. Based on this the user may decide to provide hints to GPORCA to pick a plan of a particular shape or produce a plan faster.

To express this intent of logging GPORCA metrics, GPDB users must enable **both** of these GUCs at the query level.

* `set optimizer_print_optimization_stats = on;`
* `set client_min_messages='log';`


For TPC-H query Q1, enabling the above mentioned GUCs produces the following GPORCA metrics for display.

{{< responsive-figure src="/images/orca-profiling/modified-output.png" >}}

GPORCA metrics that are measured are:

* Breakdown of where GPORCA spends its time
* Time needed for GPORCA to get the relevant information about the database objects (such as, schema, statistics, indexes available, and constraints) from the host system.
* List of transformation rules employed for plan generation


## Footnotes
<a name="1"><sup>[1]</sup></a> [New Benchmark Results: Pivotal Query Optimizer Speeds Up Big Data Queries Up To 1000x](https://blog.pivotal.io/big-data-pivotal/products/new-benchmark-results-pivotal-query-optimizer-speeds-up-big-data-queries-up-to-1000x).

<a name="2"><sup>[2]</sup></a> [Orca: A Modular Query Optimizer Architecture for Big Data](https://pivotal.io/big-data/white-paper/orca-a-modular-query-optimizer-architecture-for-big-data).

<a name="3"><sup>[3]</sup></a> [Enabling PQO in GPDB](http://gpdb.docs.pivotal.io/4390/admin_guide/query/topics/query-piv-opt-enable.html).

