---
authors:
- narmenatzoglou
- krajaraman
- shardikar
- chasseur
- frahman
- caragea
- vraghavan
- addison
- xzhang
categories:
- GREENPLUM DATABASE
- QUERY EXECUTION
- CODE GENERATION
date: 2016-09-02T10:43:19-04:00
draft: false
short: |
  A code generation based solution inside the GPDB execution engine.
title: Improving Query Execution Speed via Code Generation
---

## Overhead of a Generalized Query Execution Engine


To handle the full range of SQL queries and data types, [GPDB](http://greenplum.org/)’s execution engine is designed with high levels of complexity such as function 
pointers and control flow statements. Making these decisions for each tuple adds up to significant overhead, and prevents efficient usage of modern CPUs, with deep 
pipelines. 


## Code Generation 

To address this problem of ineffective CPU utilization and poor execution time, several state-of-the-art commercial and academic query execution engines have explored 
a Code Generation (CodeGen) based solution. This approach exploits the metadata about the underlying schema and plan characteristics already available at 
query execution time to compile efficient code that is customized to a particular query. To elaborate consider the following use case in Postgres-based engine like GPDB. In the code snippet from `ExecEvalScalarVar`, 
we retrieve the 5th attribute of a tuple.
```c
switch (variable->varno)
{  
     case INNER:
          slot = econtext->ecxt_innertuple;
   	   break;
     case OUTER:
   	   slot = econtext->ecxt_outertuple;
          break;
     default:
          slot = econtext->ecxt_scantuple;
   	   break;
}
attnum = variable->varattno;
return slot_getattr(slot, attnum);
```

At runtime, we know that `variable->varno` is neither `INNER` nor `OUTER`, so we can skip the switch (and the branch instructions that are generated from it) and 
directly pass `econtext->ecxt_scantuple` to `slot_getattr()`. Similarly, based on the plan we can initialize the `attnum` 
value to a constant. A handwritten, and more efficient, code for the above snippet would look like the following: 

```c
return slot_getattr(econtext->ecxt_scantuple, 5);
```

This code is much simpler, it has fewer instructions (reducing both CPU cycles and instruction cache space used) and no branches that can be mispredicted.
In a successful application of code generation, the time needed to generate, compile, and execute this code is significantly less than the execution of the original code. 
```
Code_Generation_Time + Compilation_Time + Codegened_Code_Execution_Time < Original_Code_Execution_Time
```

## CodeGen Approach in Literature: Holistic vs. Hotspots

In literature, there are two major approaches in doing code generation namely (1) holistic macro approach, and (2) hotspot based micro specialization. 
In the holistic approach the execution looks at optimization opportunities across the whole query plan [1][2]. This may include but is not restricted to
merging query operators, converting pull-based execution pattern to push-based model, etc. Alternatively, the hotspot based micro specialisation strategy generates code 
for frequently exercised code paths only [4]. Figure below depicts the CodeGen approach followed in numerous commercial databases. 
 

{{< figure src="/images/codegen/commercial.png" class="center">}}


To incrementally deliver value to our customers, we decided to follow the hotspot based methodology in implementing CodeGen and revisit the holistic approach in the 
near future. Hotspots approach delivers performance wins without compromising functionality, since the execution engine continues to support 100% of the features 
customer's expect from GPDB and some queries just run faster.


## GPDB Hotspots

When we ran [TPCH](http://www.tpc.org/tpch/) queries, the top 10 functions with respect to time spent are shown below. Note that the remaining functions are bundled in a category called “Others”.

{{< responsive-figure src="/images/codegen/profiling.png" >}}

Based on the results, the following hotspots are prime candidates for code generation: 

- Deforming a tuple (see `_slot_getsomeattrs` function)
- Expression evaluation (see `ExecProject`, `agg_hash_initial_pass`, `ExecEvalScalarVar`)
- Aggregate functions


## Which programming language to use to generate code: C/C++ vs. Java vs. LLVM?

There are several ways to generate code at runtime, (1) C/C++, (2) a managed VM language like Java or C#, (3) Directly in Machine Code and (4) LLVM, to name a few. 
Given that GPDB code base is in C and C++, adding Java or C# does not make much sense. Assembly code is also not a good candidate since it is both hard to write as well as maintain. Generating C/C++ code is more developer 
friendly, but optimizing and compiling C/C++ is shown to be slow [2]. 

In contrast, [LLVM](http://llvm.org/) is ideal for generating code as it provides a collection of modular as well as reusable compiler and toolchain technologies. 
LLVM provides a C++ API for writing code into an intermediate representation (IR), which at runtime can be optimized and turned into native code efficiently.
LLVM IR is a low-level programming language similar to assembly language, which is type-safe, target machine-independent, and supports RISC-like instructions and unlimited 
registers. GPDB inherits all of the LLVM code optimizations. Below you can see the equivalent C++ code, using LLVM C++ API, that is building up LLVM IR code for our example.
                                                                            
 ```                                                                         
llvm::Value* res = ir_builder()->CreateCall(llvm_slot_getattr_func, {llvm_econtext_ecxt_scantuple, 5});
ir_builder()->CreateRet(res);
```

Commercial databases leverage both approaches. For instance, [Redshift](https://aws.amazon.com/redshift/) compiles C++ code [6], while 
[Impala](https://www.cloudera.com/products/apache-hadoop/impala.html) 
utilizes LLVM [8]. [MemSQL](http://www.memsql.com/) emits a high-level language, called [MPL](http://docs.memsql.com/docs/code-generation), when preparing the query, and then compiles the HLL to emit LLVM IR [7].  


## LLVM Based CodeGen in GPDB

For each operator (e.g., Scan, Agg, etc.) that we have identified as a candidate for hotspot code generation, we do the following:

- Create an LLVM module 
- Generate IR code for the target function
- Compile the IR code into a binary format ready for execution
- Replace the call to the original function by a call to the compiled function
- Destroy the module      

{{< responsive-figure src="/images/codegen/codegen_in_gpdb.png" >}}

Each operator may have one or more functions that can be a good candidate for code generation. During the initialization of a node, based on the query plan, if all the 
runtime input variables to a candidate function are available, then we are able to generate its corresponding LLVM IR. This IR is then compiled and ready for execution.
To elaborate, consider query `SELECT c FROM foo`, where the table foo has three integer columns (a,b,c) and is distributed on column a. The following is the distributed 
execution plan inside GPDB. Since the table is distributed across several cluster nodes, the plan gathers all the tuples scanned on each segment. This operation is done
by the GPDB specific node called `GATHER MOTION`.

```
                                   QUERY PLAN
--------------------------------------------------------------------------------
 Gather Motion 3:1  (slice1; segments: 3)  (cost=0.00..13.00 rows=1000 width=4)
   ->  Seq Scan on foo  (cost=0.00..13.00 rows=334 width=4)
 Optimizer status: legacy query optimizer
(3 rows)
```

In above example, during the initialisation of the Scan, one of the candidate functions for code generation is `slot_deform_tuple`. From the execution plan generated by the optimizer,
the GPDB execution engine can determine the third attribute ( c ) is the only column needed and it is at an offset 8 bytes when we read the tuple (ignoring the header metadata for the tuple). 
For completeness the table below depicts the places that each operation will be executed.


| Execution Phase      | Execution Step  | Action related to CodeGen  |
| --------------  | --------- | --------- |
| Database Start        | Start PostMaster   |   Initialize CodeGen  |
| Query Execution | Fork QE process | |
| ExecInit | InitMotion | |
| | InitScan| i) Create module, ii) Generate IR code for `slot_deform_tuple`, iii) Compile code, iv) Add the function pointer of code generated `slot_deform_tuple` to a struct (e.g., `TupleTableSlot`) for later use|
| ExecutePlan | ExecMotion| |
| | ExecScan | Call code generated `slot_deform_tuple` using the function pointer that was stored in a struct during InitScan phase|
|ExecuteEnd | EndMotion ||
| | EndScan | Destroy module|


### CodeGen in Deforming a Tuple

During the execution of the above select query (i.e., `SELECT c FROM foo`), a Scan operator loads a tuple from the disk into an in memory buffer. 
Then, for each such tuple in the table, based on the query and table’s schema, it 

1) computes the length and the offset of every attribute in the tuple,

2) performs any checks (such as nullity checks) on the attribute, and

3) extracts the value of the attribute by copying the appropriate number of bytes from the buffer into a `TupleTableSlot` struct.

Given that `foo` has no variable length attributes, as we described above, at runtime we know the attribute type, column width and its nullability property. Consequently, 
even before reading the values from the buffer, the exact offset of each attribute is known. Thus we can generate a function that takes advantage of the table schema 
and avoids unnecessary computation and checks during the execution. 

Inside GPDB, the overall logic for the simple projection of attributes is contained in the 
the function `ExecVariableList`. The default implementation of this function without CodeGen proceeds in the following code path : `ExecVariableList > slot_getattr > _slot_getsomeattrs > slot_deform_tuple`.
Here, `slot_deform_tuple` does the actual deformation from the buffer to a `TupleTableSlot`. The code generated version of `ExecVariableList` squashes the above code path, 
and gives a performance boost by using constant attribute lengths, dropping unnecessary null checks, unrolling loops and reducing external function calls. 
If such optimization are not possible during code generation, we immediately bail out from the code generation pipeline and use the default GPDB implementation of
`ExecVariableList`.

### CodeGen in Expression Evaluation

In our initial hotspot analysis, we found that Expression Evaluation has potential for improvement with CodeGen. To motivate this intuition, let us expand on the 
initial query by adding a predicate in the WHERE clause: `SELECT c FROM foo WHERE b < c`. For each tuple of table `foo`, Scan operator now has to evaluate the 
the condition `b < c` whose expression tree is depicted below. 

```
     <
    / \
   b   c 
```

The call stack of the above expression during the evaluation of the first tuple is as follows:

```c
ExecQual> (one qual)
   ExecEvalOper> (operator <)
   |   ExecMakeFunctionResult>   (evaluation function: int4lt )
   |      ExecEvalFuncArgs> (two arguments {b, c)
   |      |   ExecEvalVar> (first argument, value of b)
   |      |   ExecEvalVar> (first argument, value of c)
   |      int4lt
   | return true/false
```

In the Scan operator, to evaluate the predicate on each input tuple we call the function `ExecQual`. This in turn calls the function `ExecEvalOper` to evaluate a comparison operator.
As an input parameter to the function `ExecEvalOper`, we pass the metadata needed to execute the function such as the operation being performed, columns as well as constants being 
accessed, etc. `ExecMakeFunctionResult` retrieves the values of the arguments via `ExecEvalFuncArgs`. To handle the general case where in each argument can itself be an 
arbitrary expression `ExecEvalFuncArgs` invokes `ExecEvalVar` to retrieve the columns from the tuple - in our example this is used to get the value of column b an c.
After the column values are retrieved we use the built-in postgres operation `int4lt` to evaluate the less than comparison and return the boolean result.
As seen above even for a simple predicate such as `b < c` the call stack is deep, and the results of each call need to be stored in an intermediate state that is then passed around.

The code generated version of this expression tree avoids these function calls thereby reduce overhead of state maintenance and opens up opportunities for the compiler
to further optimize the evaluation of this expression at execution time. 


### CodeGen in Aggregate Functions

Similarly to expression evaluation, in our profiling results we found a fertile ground for CodeGen at the evaluation of aggregate functions. 
To elaborate, consider query `SELECT sum(c) FROM foo`. Below you can see the call stack during the evaluation of `sum(c)` aggregate function:
```c
> advance_aggregates
   > advance_transition_function
      > invoke_agg_trans_func
         > int4_sum
```

`advance_aggregates` function is called during the execution of an Agg node. Given a tuple, for every aggregate function of the input query, `advance_aggregates` invokes 
`advance_transition_function` to perform the aggregation. `advance_transition_function` is a wrapper of `invoke_agg_trans_func` function. The latter calls a 
built-in function that is used to evaluate the aggregation, in our example this is `int4_sum`, and stores the intermediate aggregate results in a temporary struct. 
These results will be returned to the query issuer after all tuples have been processed. 
 
Code generated version of `advance_aggregates` avoids all these function calls by squashing the call stack, and performs multiple optimizations by avoiding the use of 
temporary structs for storing intermediate results and use simple variables that are stored in stack. 

## Experimental Analysis

We evaluated our proposed code generation framework using TPC-H Query 1 (shown below) over an 1GB dataset.


```sql
-- Schema
CREATE TABLE lineitem (
    l_orderkey integer NOT NULL,
    l_partkey integer NOT NULL,
    l_suppkey integer NOT NULL,
    l_linenumber integer NOT NULL,
    l_quantity float8 NOT NULL,
    l_extendedprice float8 NOT NULL,
    l_discount float8 NOT NULL,
    l_tax float8 NOT NULL,
    l_shipdate date NOT NULL,
    l_commitdate date NOT NULL,
    l_receiptdate date NOT NULL,
    l_returnflag char NOT NULL,
    l_linestatus char NOT NULL,
    l_shipinstruct character(25) NOT NULL,
    l_shipmode character(10) NOT NULL,
    l_comment character varying(44) NOT NULL
)
WITH (appendonly=false) DISTRIBUTED BY (l_orderkey);
```

```sql
-- TPC-H Query 1
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
FROM
   lineitem
WHERE
   l_shipdate <= date '1998-12-01' - interval '90 day'
GROUP BY
   l_returnflag,
   l_linestatus
ORDER BY
   l_returnflag,
   l_linestatus;
```

{{< responsive-figure src="/images/codegen/results.png" >}}


Code generation of Deform Tuple (A) gives us only a small boost in performance. This is due the fact that GPDB already has an optimized version of 
`slot_deform_tuple` that caches all the offsets of fixed length attributes until the first variable length attribute appears in the tuple. 
Code generation of Expression Evaluation (B) gives us a significant performance bump of 1.25X faster execution than the plan without code generation. 
When we generate code for Aggregate Functions ( C ) the plan is 1.35X faster due to the reduced number of function calls, loop unrolling, 
and optimization opportunities revealed in the generated code, e.g. no use of temporary structs. 
In conclusion, when we employ all three techniques we observed a 2x performance improvement. These preliminary results are very promising and a good 
indicator of early progress with CodeGen.
 
## Next Steps

As the next step, we are investigating in the following areas.
 
- Expanding micro specialisation to other operators such as Joins
- Tracking the memory footprint of LLVM modules
- Auto generation of IR code for built-in functions
- Vectorized/block execution
- Merging operators

## Source Code
You can find the current implementation [here](https://github.com/greenplum-db/gpdb/tree/master/src/backend/codegen)!

## References

[1] Krikellas K, Viglas S, Cintra M. Generating code for holistic query evaluation. In ICDE, 2010.

[2] Neumann T. Efficiently compiling efficient query plans for modern hardware. In PVLDB, 4(9):539-50, 2011.

[3] Sompolski J, Zukowski M, Boncz P. Vectorization vs. compilation in query execution. In DAMON, 2011.

[4] Zhang R, Debray S, Snodgrass RT. Micro-specialization: dynamic code specialization of database management systems. In CGO, 2012.

[5] Zhang Y, Yang J. Optimizing I/O for big array analytics. In PVLDB, 5(8):764-75, 2012.

[6] Gupta A, Agarwal D, Tan D, Kulesza J, Pathak R, Stefani S, Srinivasan V. 2015. Amazon Redshift and the Case for Simpler Data Warehouses. In SIGMOD, 2015.

[7] Goyal A. Presentation of MemSQL in Carnegie Mellon University. https://scs.hosted.panopto.com/Panopto/Pages/Viewer.aspx?id=05931d2c-fe66-4d50-b3f2-1a57f467cf96

[8] Wanderman-Milne S, Li N. Runtime Code Generation in Cloudera Impala. In IEEE Data Eng. Bull., 37(1): 31-37, 2014. 