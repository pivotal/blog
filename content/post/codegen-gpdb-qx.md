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
categories:
- GREENPLUM DATABASE
- QUERY EXECUTION
- CODE GENERATION
date: 2016-09-02T10:43:19-04:00
draft: true
short: |
  A code generation based solution inside the GPDB execution engine.
title: Improving Query Execution Speed via Code Generation
---

## Overhead of a Generalized Query Execution Engine


To handle the full range of SQL queries and data type, [GPDB](http://greenplum.org/)’s execution engine is designed with high levels of complexity such as function 
pointers and control flow statements. Making these decisions for each tuple adds up to significant overhead, and prevents efficient usage of modern CPUs, with deep 
pipelines. For instance, profiling [TPCH](http://www.tpc.org/tpch/) Query 1 on two segments with warm cache resulted in 77s for 7GB input table at 45MB/s per segment. 
This clearly shows that GPDB is not IO Bound, but rather CPU Bound. 


## Code Generation 

To address this problem of ineffective CPU utilisation and poor execution time, several state-of-the-art commercial and academic query execution engines have explored 
a Code Generation (CodeGen) based solution. This approach exploits the metadata about the underlying schema and plan characteristics already available at 
query execution time, to produce native code. To elaborate consider the following use case in Postgres-based engine like GPDB. In the code snippet from XXX, we retrieve the 
5th attribute of a tuple.
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

 
At runtime, from the query plan we know for this XXX that variable->varno is neither INNER nor OUTER, thus we can generate code that passes the value of 
econtext->ecxt_scantuple (default case) as an argument to slot_getattr directly. Similarly, from the plan we can initialize the attnum value to a constant. 
A handwritten, and more efficient, code for the above snippet would look like the following: 

```c
return slot_getattr(slot_getattr(econtext->ecxt_scantuple, 5);
```


## CodeGen Approach in Literature: Holistic vs. Hotspots

In literature, there are two major approaches in doing code generation namely (1) holistic macro approach, and (2) hotspot based micro specialisation. 
In the holistic approach the execution looks at optimization opportunities across the whole query plan [1][2]. This may include but not restricted to
merging query operators, converting pull-based execution pattern to push-based model, etc. Alternatively, the hotspot based micro specialisation strategy generates code 
for frequently exercised code paths only [4]. Figure below depicts the CodeGen approach followed in numerous commercial databases. 
 

{{< figure src="/images/codegen/commercial.png" class="center">}}


To incremental deliver value to our customers, we decided to follow the hotspot based methodology in implementing CodeGen and revisit the holistic approach in the near future.


## GPDB Hotspots

When we ran TPC-H queries, the top 10 functions with respect to time spent is shown below. Note that the remaining functions are bundled in a category called “Others”.

{{< responsive-figure src="/images/codegen/profiling.png" >}}

Based on the results, the following hotspots are prime candidates for code generation: 

- Deforming a tuple (see _slot_getsomeattrs function)
- Expression evaluation (see ExecProject, agg_hash_initial_pass, ExecEvalScalarVar)
- Aggregate functions


## Which programming language to use to generate code: C/C++ vs. LLVM?

There are several ways to generate code at runtime, (1) C/C++, (2) Java, (3) Directly in Machine Code and (4) LLVM, to name a few. Given that GPDB code base is in C and C++,
adding Java does not make much sense. Assembly code is also not a good candidate since it is both hard to write as well as maintain. Generating C/C++ code is more developer 
friendly, but optimizing and compiling C/C++ is shown to be slow [2]. 

In contrast, [LLVM](http://llvm.org/) is ideal to generate code since it provides a collection of modular and reusable compiler and toolchain technologies. 
LLVM provides a C++ API for writing code into an intermediate representation (IR), which at runtime can be optimized and turned into native code efficiently.
LLVM IR (a low-level programming language similar to assembly language) is type-safe, target machine-independent, and supports RISC-like instructions and unlimited 
registers. GPDB inherits all of the LLVM code optimizations. Below you can see the equivalent LLVM IR code for our example.
                                                                            
 ```                                                                         
llvm::Value* res = ir_builder()->CreateCall(llvm_slot_getattr_func, {llvm_econtext_ecxt_scantuple, 5});
ir_builder()->CreateRet(res);
```

Commercial databases follow both approaches. For instance, [Redshift](https://aws.amazon.com/redshift/) compiles C++ code [6], while [Impala](https://www.cloudera.com/products/apache-hadoop/impala.html), 
utilizes LLVM. [MemSQL](http://www.memsql.com/) emits a HLL when preparing the query, and then compiles the HLL to emit LLVM IR [7].  



## LLVM Based CodeGen in GPDB

For each operator (e.g., Scan, Agg, etc.) that we have identified as a candidate hotspot that can benefit from code generation we must do the following: 

- Create a CodeGen module
- Generate IR code for the target function
- Compile the IR code into a binary format ready for execution
- Replace the call to the original function by a call to a function
- Destroy the module      

{{< responsive-figure src="/images/codegen/codegen_in_gpdb.png" >}}

Each operator may have one or more code generators, where each code generator has a list of pointers to information related to code generated functions. 
During the initialization of a node, we are able to create a codegened function, since we have all required information.
For example, during InitScan, we are able to generate and compile the codegened version of slot_deform_tuple, since we have access to the slot descriptor.

To elucidate our approach, consider query Q1: SELECT c FROM foo, where the table foo has three integer columns (a,b,c). In this example, we want to CodeGen 
(i.e., generate IR code) only one function, which is executed during Scan, e.g., slot_deform_tuple function. We will now describe the code generation of 
fetching the third column in Scan operator. Table below depicts the places that each operation will be executed.


| Exec. Phase      | Execution Step  | Action related to code generation  |
| --------------  | --------- | --------- |
| Database Start        | Start PostMaster   |   Initialise code generator  |
| QE | Fork QE process | |
| ExecInit | InitMotion | |
| | InitScan| Create Module, Generate IR code for slot_deform_tuple, Compile Module, Add the function pointer of codegened slot_deform_tuple to a struct (e.g., TupleTableSlot - see below )|
| ExecutePlan | ExecMotion| |
| | ExecScan | Call codegened slot_deform_tuple using the function pointer, which was stored in a struct during Init phase (e.g., TupleTableSlot - see below)|
|ExecuteEnd | EndMotion ||
| | EndScan | Destroy module|



 
We store a pointer to the compiled code generated function in a struct for latter use. In our example, the proper struct is the TupleTableSlot. 
Then, during actual execution, we retrieve the function pointer from TupleTableSlot and call the codegened version of the function. Finally, the constructed 
module is destroyed at the end of the Scan operator.



### CodeGen in Deforming a Tuple

During the execution of a simple select query (e.g., SELECT bar FROM foo;), a Scan operator reads a tuple from the disk and adds the bytes to a buffer. 
Then, based on the query and table’s schema, for every attribute, it i) computes its length and the offset of the attribute in the buffer, and ii) copies 
and type casts the value of the attribute from the buffer to a given struct (i.e., TupleTableSlot).

Now, let us assume that we have a table with no variable length attributes. When we retrieve a simple query e.g., SELECT bar1, bar2 FROM foo, during the 
initialization of a Scan operator we know the types of attributes and their constant length. Consequently, when we read the values from the buffer, we already 
know the type and the offset of each attribute. Thus we can generate a function that takes advantage of the table schema and avoids unnecessary computation 
during the execution.

In GPDB code, when we receive the query described above, Scan operator will execute the ExecVariableList function, which evaluates a simple Variable-list projection. 
In particular, for each attribute A in the target list (e.g., bar), it retrieves the slot that A comes from and calls slot_getattr(). slot_get_attr will eventually 
call slot_deform_tuple (through _slot_getsomeattrs), which fetches all yet unread attributes of the slot until the given attribute.
 
Currently we generate code for the code path ExecVariableList > slot_getattr > _slot_getsomeattrs > slot_deform_tuple. The code generated version of 
ExecVariableList supports the cases that all the attributes in target list use the same slot (created during a scan i.e, ecxt_scantuple). Moreover, instead of 
looping over the target list one at a time, this approach uses slot_getattr only once, with the largest attribute index from the target list. If during code 
generation time, the completion is not possible (e.g., attributes use different slots), then function returns false and codegen manager will manage the clean up.

### Codegen in Expression Evaluation

The majority of sql queries include expressions that need to be evaluated. Let Q be the query SELECT a1 FROM foo WHERE a1 < a2; For each tuple of table foo, Scan operator has to evaluate the implicitly-ANDed qual conditions that exist in the query, e.g., a1 < a2. Similarly, an expression might be located at the target list, e.g., SELECT a1 + a2 FROM foo;  Given the qual a1 < a2, the expression tree looks like :
```
      <
     / \
   a1   a2 
```

Below you can see the call stack during the evaluation of the first tuple:

```c
ExecQual> (one qual)
   ExecEvalOper> (operator <)
   |   ExecMakeFunctionResult>   (evaluation function: int4lt )
   |      ExecEvalFuncArgs> (two arguments {a1, a2})
   |      |   ExecEvalVar> (first argument, value of a1)
   |      |   ExecEvalVar> (first argument, value of a2)
   |      int4lt
   | return true/false
```

Let us describe the execution of the above expression tree first. In ExecQual, we have only one qual q. To evaluate q, we call ExecEvalOper, since q is a < operator. 
In ExecEvalOper, we populate q with required information (e.g., function pointers) and call ExecMakeFunctionResult. This function evaluates the arguments to a function 
and then the function itself. In particular, first ExecMakeFunctionResult calls ExecEvalFuncArgs function, which iterates over the arguments of the function 
(i.e., a1 and a2) and calls ExecEvalVar to retrieve the value of the attributes. These values are stored in a FunctionCallInfoData variable. Then it will call the 
evaluation function int4lt (postgres built-in operation) that performs the comparison and returns a bool value, which is also returned to ExecQual.

A code generated function that implements the whole expression tree can avoid all these function calls and also apply numerous optimizations since multiple if cases 
appear in all these functions may not apply.

In GPDB, we generate expression evaluation as follows. In native GPDB code, ExecQual calls ExecEvalOper, which actually invokes the next function 
(e.g., ExecMakeFunctionResult) using a function pointer that is stored in ExprState. During the initialization of the operator (e.g., Scan), we generate a 
function that evaluates the whole expression tree and set the function pointer in ExprState to point at the code generated function.

Given an expression tree, we have implemented a framework that parses the tree, verifies if code can be generated (i.e., we support all operators that are used in 
the tree) and generates the code in a bottom-up manner. For more details on the framework please refer here.  

### Codegen in Aggregate Functions

Let Q be an sql query that calls multiple aggregate (or transition) functions. For example:
```sql
CREATE TABLE foo (i int, j int);
INSERT INTO foo VALUES (1, 2);
INSERT INTO foo VALUES (3, 4);

SELECT sum(i), avg(j) FROM foo; -- Q
```
Below we present the backtrace of aggregate functions’ execution:
```c
> ExecAgg
   > agg_retrieve_direct
      > advance_aggregates
```
advance_aggregates function iterates over the aggregate functions (e.g., sum() and avg()) and evaluates them. In our example, it will first evaluate sum() function. 
The backtrace is presented below:
```c
> advance_aggregates
   > advance_transition_function
      > invoke_agg_trans_func
         > int4_sum
```
advance_aggregates is a great place that code generation can be applied, since i) during the initialization of Agg operator, all required information and function 
pointers are known, ii) we can avoid several function calls per tuple, iii) loop unrolling, and iv) multiple optimizations can be applied, e.g., avoid the use of 
TupleTableSlots and structs (i.e., FunctionCallInfoData) for storing intermediate results and use variables that are stored in stack. 

Currently, we generate code for advance_aggregates function. In particular, the code generated version iterates over all aggregate functions (loop-unrolling) 
and generates code for each function. Since aggregate functions utilize the similar built-in function used in expression evaluation, we utilize the framework 
discussed in Section 5.2 to generate code for built-in functions. The current implementation supports SUM aggregate function on int4 and float8 datatypes.

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


Code generation of Deform Tuple (A) gives us only a small boost in performance. This is due the fact that GPDB already has an optimized version of slot_deform_tuple 
that caches all the offsets of fixed length attributes until the first variable length attribute appears in the tuple. Code generation of Expression Evaluation (B) gives 
us a significant performance bump of 1.25X faster execution than the plan without code generation. When we generate code for Aggregate Functions ( C ) the plan is 1.35X 
faster due to the reduced number of function calls, loop unrolling, and optimization opportunities revealed in the generated code, e.g. no use of TupleTableSlot and 
FunctionCallInfoData. In conclusion, when we employ all three techniques we observed a 2x performance improvement. These preliminary results are very promising and a 
good indicator of early progress with CodeGen.

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