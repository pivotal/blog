---
authors:
- frahman
- krajaraman
- vraghavan
- narmenatzoglou
- shardikar
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

[GPDB](http://greenplum.org/)’s execution engine is general purpose, capable of handling a variety of inputs including the full range of SQL and associated data types. 
It currently handles this range of possible inputs with programming constructs such as complex control flow statements and function pointer lookup. 
Making these decisions for each tuple adds up to significant overhead, and prevents efficient usage of modern CPUs, with deep pipelines. For instance, 
profiling [TPCH](http://www.tpc.org/tpch/) Query 1 on two segments with warm cache resulted in 77s for 7GB input table at 45MB/s per segment. This clearly 
shows that GPDB is not IO Bound, but rather CPU Bound. 


## Code Generation

To address this problem of ineffective CPU utilisation and poor execution time, we propose a Code Generation (CodeGen) based solution inside the GPDB execution engine. 
CodeGen utilizes the metadata about the underlying schema and plan characteristics already available at query execution time, to produce native code 
tailored for the specific query and the data types being serviced. To achieve this we employ [LLVM](http://llvm.org/) - a modular code generation framework. LLVM is mature framework 
with a proven track record that provides a C++ API for writing code into an intermediate representation (IR). At runtime, the dynamically generated IR code can 
be further optimized into native code.

Based on our current implementation, we observed 42% (TPCH-Q1 scale 1) performance boost in GPDB.

### Example

Let's take a simple use case, where we need to retrieve the 5th attribute from the slot of a tuple. The interpreted code is depicted below.
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

Interpreted code initializes slot variable using a switch statement. Then slot is passed along with attnum variable as arguments to slot_getattr function. 
At runtime, we know that variable->varno is neither INNER nor OUTER, thus we can generate code that passes the value of econtext->ecxt_scantuple (default case) 
as an argument to slot_getattr directly. Similarly, we know the value of attnum variable, which can be a constant. Concequently, if we were generating code in C, 
the generated code would look like: 

```c
// At runtime we know

return slot_getattr(slot_getattr(econtext->ecxt_scantuple, 5);
```


## Existing Approaches

### Holistic vs. Hotspots

Code generation can be either applied to whole execution engine (i.e., holistic approach [1][2]) or to functions with significant overhead only (i.e., hotspots [4]). 
To support a fully code generated execution engine, engineers can initially follow the hotspots approach and incrementally generate code for more functions that can call 
each other. Figure below depicts the CodeGen approach followed in numerous commercial databases. 
 

{{< figure src="/images/codegen_commercial.png" class="center">}}

### C/C++ vs. LLVM

Generating C/C++ code is more developer friendly, but optimizing and compiling C/C++ is slow [2]. On the other hand, using LLVM benefits in terms of 
compilation time, but it is more laborious and developers should know LLVM. Below you can see the equivalent LLVM IR code for our example.
                                                                            
 ```
// Generator
                                                                            
llvm::Value* res = ir_builder()->CreateCall(llvm_slot_getattr_func, {llvm_econtext_ecxt_scantuple, 5});
ir_builder()->CreateRet(res);
```


LLVM provides a collection of modular and reusable compiler and toolchain technologies. The core of LLVM is the intermediate representation (IR), a low-level programming 
language similar to assembly language. LLVM IR is type-safe, target machine-independent, and supports RISC-like instructions and unlimited registers. GPDB inherits all of 
the LLVM code optimizations.
 
Commercial databases follow follow both approaches. For instance, [Redshift](https://aws.amazon.com/redshift/) compiles C++ code [6], while [Impala](https://www.cloudera.com/products/apache-hadoop/impala.html), 
utilizes LLVM. [MemSQL](http://www.memsql.com/) emits a HLL when preparing the query, and then compiles the HLL to emit LLVM IR [7].  
 
In academia, there are also mixed approaches. [2] presents a hybrid method that uses C++ to support complex operations, and LLVM to glue them together and do minor 
operations like filtering. [1] and [5] use compiled C into a .so and dynamically loading it. 

### CodeGen using LLVM

There are two methods to generate code for a function in LLVM: BuildIR, and ii) TransformIR. In BuildIR method, engineers write LLVM code line-by-line, where 
additional libraries (e.g., wrappers of LLVM C++ API) can be used to simplify development. 
In TransformIR technique, functions are pre-compiled to IR during database compilation and specialized at runtime. Next figure depicts TransformIR method. 
Currently, GPDB follows BuildIR approach, but we plan to utilize TransformIR method in cases that code is not complicated, e.g., built-in functions.

{{< responsive-figure src="/images/transformIR.png" >}}


## CodeGen in GPDB

For each operator (e.g., Scan, Agg, etc.) that calls a code generated function, the following operations are needed to generate code and execute it: 

- Create a Code Gen module
- Generate IR code for the target function
- Compile the IR code into a binary format ready for execution
- Replace the call to the original function by a call to a function
- Destroy the module      

{{< responsive-figure src="/images/codegen_in_gpdb.png" >}}

Below we introduce our approach using an example that describes the above operations in the lifecycle of a query execution. 
Let us assume that we want to execute a query that scans a table, which sends its output tuples to a Motion operator. 
Moreover, for ease of presentation, we assume that we want to codegen (i.e., generate IR code) only one function, which is 
executed during Scan, e.g.,  slot_deform_tuple function. Table below depicts the places that each operation will be executed.


| Exec. Phase      | Execution Step  | Action related to code generation  |
| --------------  | --------- | --------- |
| Start        | Start PostMaster   |   Initialise code generator  |
| QE | Fork QE process | |
| Init | Init Motion | |
| | Init Scan| Create Module, Generate IR code for slot_deform_tuple, Compile Module, Add the function pointer of codegened slot_deform_tuple to a struct (e.g., TupleTableSlot - see below )|
| Execution | ExecMotion| |
| | ExecScan | Call codegened slot_deform_tuple using the function pointer, which was stored in a struct during Init phase (e.g., TupleTableSlot - see below)|
|End | EndMotion ||
| | EndScan | Destroy module|


Each operator may have one or more code generators, where each code generator has a list of pointers to information related to codegened functions. 
During the initialization of a node, we are able to create a codegened function, since we have all required information. For example, 
during InitScan, we are able to generate and compile the codegened version of slot_deform_tuple, since we have access to the slot descriptor. 
Also, we store a pointer to the compiled code generated function in a struct for latter use. In our example, the proper struct is the TupleTableSlot. 
Then, during actual execution, we retrieve the function pointer from TupleTableSlot and call the codegened version of the function. Finally, the constructed 
module is destroyed at the end of the Scan operator.


## Generate code for Hotspots

To identify the functions with significant overhead, we run the entire TPC-H workload 



### CodeGen in Deforming Tuples


### Codegen in Expression Evaluation


### Codegen in Aggregate Functions


## Source Code
You can find the current implementation [here](https://github.com/greenplum-db/gpdb/tree/master/src/backend/codegen)!

## References

[1] Krikellas K, Viglas SD, Cintra M. Generating code for holistic query evaluation. In ICDE, 2010.

[2] Neumann T. Efficiently compiling efficient query plans for modern hardware. In PVLDB, 4(9):539-50, 2011.

[3] Sompolski J, Zukowski M, Boncz P. Vectorization vs. compilation in query execution. In DAMON, 2011.

[4] Zhang R, Debray S, Snodgrass RT. Micro-specialization: dynamic code specialization of database management systems. In CGO, 2012.

[5] Zhang Y, Yang J. Optimizing I/O for big array analytics. In PVLDB, 5(8):764-75, 2012.

[6] Gupta A, Agarwal D, Tan D, Kulesza J, Pathak R, Stefani S, Srinivasan V. 2015. Amazon Redshift and the Case for Simpler Data Warehouses. In SIGMOD, 2015.

[7] Goyal A. Presentation of MemSQL in Carnegie Mellon University. https://scs.hosted.panopto.com/Panopto/Pages/Viewer.aspx?id=05931d2c-fe66-4d50-b3f2-1a57f467cf96