---
authors:
- mspehlmann
categories:
- Databases
- Query Optimization
- SQL
date: 2016-08-02T9:00:00-08:00
draft: false
short: |
  ORCA is Pivotal's Query Optimizer for big data. We look at how we improved ORCA's understanding of logical constraints.
title: Improving Constraints In ORCA
---

[ORCA](https://github.com/greenplum-db/gporca) is Pivotal's SQL Optimizer for [Greenplum Database](https://github.com/greenplum-db/gpdb) and [HAWQ](https://github.com/apache/incubator-hawq). It's a tool for finding the fastest way to execute SQL queries in a distributed environment. Optimizers are needed because there will be many possible ways to execute a query on your database engine, and a niave query plan might take orders of magnitude more time than the lowest cost plan. The process of finding this lowest cost plan does take compute time, and potentially more than the execution time of the query. One of the goals in designing a query optimizer is to optimize the optimization process itself.

In this post we will look at *constraints* which are ORCA's way of understanding logical restrictions on tables. We will explore a performance issue in how ORCA handled constraints involving array datatypes, and how we diagnosed and solved the problem.

Our solution was rolled out in two stages. First, we implemented a quick, sub-optimal solution. This solution added a user-accessable control knob which allowed us to disable the problematic feature for cases which caused slowdown. We then we developed a general feature which improved ORCA's constraint framework. This effort resulted in a more effiecent way of representing arrays internally to the optimizer, which fixed the original issue without losing functionality.

## Intro to Optimization

ORCA's job is to take a human readable SQL statement and produce an execution plan for the database engine. Internally, ORCA will take this SQL statement and generate an expression tree which is a convenient way for the program to represent the query. ORCA is allowed to transform the tree so long as it produces the same final output. Below is a print out of a SQL query and a simplified view of ORCA's generated plan tree.

```sql
EXPLAIN SELECT * FROM foo, bar WHERE foo.id IN (1,2,3) AND foo.id = bar.id;
```
```
Gather Motion
    Hash Join
        Hash Cond: foo.id = bar.id
            Table Scan on foo
                Filter: id = ANY {1,2,3} AND (id = 1 OR id = 2 OR id = 3)
        Hash
            Table Scan on bar
                Filter: id = 1 OR id = 2 OR id = 3
```

So there's at least one good optimization here, but unfortunately there's a couple of ugly things as well. Can you spot them? 

One thing you'll notice is that there is a constraint on `bar` which wasn't present in the original query. This is because of a trick known as *constraint propagation*. Constraint propagation is a technique which helps speed up execution time of a query. Note that the attributes `foo.id` and `bar.id` are equivalent, and therefore ORCA knows that any condition on `foo.id` must also be true for `bar.id`. A smart optimizer will derive these conditions, generating a plan with as many conditions on attributes as possible. This reduces the amount of data that must be copied and moved around in the executor, generating faster queries. Constraint propagation is one of the good things going on in this query plan.

Going back to the condition on `bar`, there is something strange going on. Instead of having `foo`'s' original constraint of `IN (1,2,3)`, the constraint has been expanded to `id = 1 OR id = 2 OR id = 3`. This feature, known as *array expansion*, is acceptable from a logical perspective. Optimizers' internal representation of a query need only be logically equivalent to the given input. For ORCA's developers, array expansion is actually quite a handy feature. For example, if you translate all array statements into equality statements and you already have code that handles equality, you've essentially saved yourself the hassle of writing tests and functionality for array data types. In fact, most databases will have functionality to evaluate equality and OR statements, but may not have the functionality to execute array statements. Therefore, array expansion has the advantage of creating very general execution plans. However, choices of internal representation can have unintended performance side-effects.

## Issues with Arrays

Going back to the join example we see that `id = ANY {1,2,3} AND (id = 1 OR id = 2 OR id = 3)` is redundant. It's logically correct and therefore returns correct results, but it is wordy, like some kind of cancerous outgrowth. We want succinct, clean expressions. This blemish is one of the rough edges of ORCA. What was actually happening there was the constraint propagated first from `foo` to `bar` and then back from `bar` to `foo`. Since ORCA didn't understand logical equivilence between arrays and OR statements, it appended it as a new constraint. Not wrong, just ugly.

In fact, the real problem is not with the unsightliness of the expression, but in what happens when the `IN` array becomes large. When a query as simple as `SELECT * FROM foo, bar WHERE foo.id = bar.id AND foo.id IN (1,2, [...], 100 )` has 100 elements, the internal representation and manipulation of a 100 element OR/Equality expression became a major performance and memory bottleneck. Some customers commonly run queries with hundreds of elements in an IN list and were experiencing hangups. When we investigated this query, it took over a minute to optimize on one of our development machines, and larger IN lists would crash the optimizer. Intrigued, we performed a trace of large array case using Apple's Instrumentation Tools. Performance tools gave us a simple GUI overlay of the code and relative amount of time take for each preprocessing stage, and then a time breakdown of the longest running calls of each preprocessing stage.

<img src="https://dl.dropboxusercontent.com/s/vlyz6ln3l9xpdi8/code-view.png" height="190" width="640" />

Stages involving constraints seemed to take the longest. We then dived into the methods within the constraint processing stages to see the costliest calls within the preprocessing function call:

```
14758.0  gpopt::CExpressionPreprocessor::PexprPreprocess(..)
8364.0   gpopt::CExpressionPreprocessor::PexprAddPredicatesFromConstraints(..)
1356.0   gpopt::CExpressionPreprocessor::PexprFromConstraints(..)
1350.0   gpopt::CExpression::PdpDerive(..)
681.0    gpopt::CDrvdPropRelational::Derive(..)
681.0    gpopt::CLogical::PpcDeriveConstraintFromPredicates(..)
681.0    gpopt::CConstraint::PcnstrConjDisj(..)
681.0    CConstraintConjunction_CleanupRelease
681.0    gpopt::CConstraint::PdrgpcnstrDeduplicate(..)
677.0    gpopt::CConstraintInterval::PciIntervalFromScalarBoolAnd(..)
677.0    gpopt::CConstraintInterval::PciIntervalFromScalarBoolOr(..)
674.0    gpopt::CConstraintInterval::PciUnion(..)
318.0    gpopt::CConstraintInterval::AppendOrExtend(..)
314.0    gpopt::CRange::PrngExtend(..)
```

This trace, and other investigations, revealed that the vast majority of the time was being spent managing, and walking over large amount of constraint objects which were generated by the expansion and then subsequent exploration of the Expression tree. For example, there is a method in the trace called `PdrgpcnstrDeduplicate` which is trying to deduplicate constraints. From looking at the code, we discovered that it does this without sorting, thus taking O(n<sup>2</sup>) time. This is just one of several slow areas that appears when there are many OR constraints. Therefore, a solution would either need to stop array expansion or implement a smarter way of representing arrays.

## Solution 1

Our first fix took advantage of the fact that constraints, unlike expressions, are optional. Expressions capture the structure of the plan. They hold information about the filter to apply to a table, but they do not understand the logical significance of the filter. In contrast, Constraints are ORCA's way of representing and manipulating logical restrictions. ORCA could generate correct plans without constraints, but it would fail to understand that the predicate `foo.id = 1 AND foo.id <> 1` is a contradiction, and thus returns no tuples. Without constraints, ORCA will produce a plan which faithfully scans every tuple, checking that foo's id is both one and not one. Constraints essentially give ORCA logical manipulation abilities, but without them ORCA will still create valid plans.

When we approached this problem, we realized that a complete fix would take a deep understanding of ORCA, but that a simple approach was straightforward: simply do not expand large arrays.

So back to our fix. The easiest way to solve the problem was to not do array expansion because it is much better for ORCA to produce a suboptimal plan rather than hang the entire system. Our fix was a knob which set a threshold for when ORCA would stop expansion. On small arrays, ORCA would still array expand and propagate constraints, and ORCA would not hang on large arrays. See the difference in plans produced:

**Before**
```sql
EXPLAIN SELECT * FROM foo, bar WHERE foo.id IN (1, 2, 3, ..., 100) AND foo.id = bar.id;
```
```
Gather Motion
    Hash Join
        Hash Cond: foo.id = bar.id
            Table Scan on foo
                Filter: id = ANY {1,2,3, ... , 100} AND
                          (id = 1 OR id = 2 OR id = 3 OR ... OR id = 100)
        Hash
            Table Scan on bar
                Filter: id = 1 OR id = 2 OR id = 3 OR ... OR id = 100

Time: 6068.283 ms
```
**After**
```sql
EXPLAIN SELECT * FROM foo, bar WHERE foo.id IN (1, 2, 3, ..., 100) AND foo.id = bar.id;
```
```
Gather Motion
    Hash Join
        Hash Cond: foo.id = bar.id
            Table Scan on foo
                Filter: id = ANY {1,2,3, ... , 100}
        Hash
            Table Scan on bar

Time: 28.746 ms
```

Notice that the query goes from taking six seconds to optimize to 28 milliseconds. Also, notice that there is no longer any constraint propagation, which could lead to longer running queries in case the underlying tables are big.

## Solution 2

A better solution involved teaching ORCA about array constraints so that it could reason about arrays instead of their expanded conjuncts. If you're interested in technical details, you can review the [Pull Requests](https://github.com/greenplum-db/gporca/pull/76). The main change was to allow a Constraint representation of array statements. This meant that a huge array could be fed into a Constraint and pulled back out of a derivation as an array, instead of as an OR statement. This generates a cleaner looking expression tree, and is much easier to reason about compared with a large OR statement. Further, this cuts down on the number of instantiated objects which cuts down on the number of paths which ORCA must traverse while walking the expression tree to do preprocessing and optimization. Finally, this fix removes the need for the tuning knob which was introduced in the first fix. This is important as databases tend to accumulate these over time and they become unmanageable. The takeaway is that instead of taking a shortcut by reusing general components, a specialized representation was needed.


Going back to our token query, you can see that it has cleaned up nicely and has an acceptable runtime.

**Plan after Array Fix**

```sql
EXPLAIN SELECT * FROM foo, bar WHERE foo.id IN (1, 2, 3, ..., 100) AND foo.id = bar.id;
```
```
Gather Motion
    Hash Join
        Hash Cond: foo.id = bar.id
            Table Scan on foo
                Filter: id = ANY {1,2,3, ... , 100}
        Hash
            Table Scan on bar
                Filter: id = ANY {1,2,3, ... , 100}

Time: 270.038 ms
```

In comparison to adding the knob to control the expansion of arrays, this fix took over a month longer to implement. However, it removes the need for a knob (the first fix). This takes 10x longer to optimize than with no array constraints, but is 240x faster to run than the original array code. A small slowdown in optimization with large arrays is acceptable because it is likely to save a disproportionately larger amount of time in query execution.

## Key Takeaways

The original method of handling arrays in ORCA was convenient because it could leverage logical equivalence to reuse existing code, however it was painfully slow when the input grew reasonably large. Our fix took advantage of the fact that optimizations are optional, so we could disable troublesome ones while working on a permanent fix. Even though both versions of handling array optimization produce logically equivalent plans, one has remarkably better performance as it takes into account ORCA's architecture.

