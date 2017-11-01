+++
title = "Testing Greenplum Database using fault injection"
short = "How to test Greenplum Database using fault injection"
draft = false
date = "2017-11-01T14:00:00Z"
categories = ["Greenplum Database", "Greenplum", "Testing frameworks", "Testing"]
authors = ["ascherbaum"]

+++

Testing is an important part, and best practice, of software development. In many cases testing frameworks are used to confirm that the software conforms to an expected behavior. This can happen by running the tests after a number changes, or fully automated after every commit (think: [Concourse CI](https://concourse.ci/), [Jenkins](https://jenkins.io/), [GitHub Travis CI](https://travis-ci.org/), just to name a few). The latter approach is named "Continuous integration".

At the same time, another more important part is often left out, and not tested: coverage for faults.

What happens if there is a network outage, memory or disks are full, or the software encounters rare circumstances? Such code paths cannot be tested for conformance, but rather faults must be injected and then verified that the software behaves as expected.

Greenplum Database integrates a testing framework called “Fault Injector”. It can be used to simulate many different aspects of faults in the system, and then verify that the product handles the problems.


## Testing different kind of problems

The Fault Injector framework is able to inject a number of different “problems” (fault types) into the running application. The full list of types is defined in [_src/backend/utils/misc/faultinjector.c_](https://github.com/greenplum-db/gpdb/blob/master/src/backend/utils/misc/faultinjector.c), in _FaultInjectorTypeEnumToString_. A few common examples:

* *error*: this generates a “regular” error, useful to test any kind of regular error code paths
* *panic*, _fatal_: like *error*, this injects a panic respective a fatal error
* *sleep*: wait a defined amount of time, useful to simulate problems like slow network responses, user input or access to remote systems
* *memory_full*: behaves like the system suddenly ran out of memory
* *segv*: something is fishy with the memory, and the operating system is about to interject
* *data_corruption*: the data is not what it is expected
* *skip*: raise a problem, but handle it in the software - like adding code for debugging

There are more possible faults which can be injected, but the list above gives a good picture of what is possible.


## Adding a new fault injection case

In order to inject and test faults, first a new fault must be created, using one of the existing fault types. This happens in [_src/backend/utils/misc/faultinjector.c_](https://github.com/greenplum-db/gpdb/blob/master/src/backend/utils/misc/faultinjector.c) in _FaultInjectorIdentifierEnumToString_, a new unique name must be added to the array. A new unique name must also be added to [_src/include/utils/faultinjector.h_](https://github.com/greenplum-db/gpdb/blob/master/src/include/utils/faultinjector.h), in the *FaultInjectorIdentifier_e* typedef.
In the _faultinjector.c_ file, the *FaultInjector_NewHashEntry()* function handles the different kind of faults, the new name must be added to the section handling the desired fault type.

And finally, the fault injection code must added in the software, where the fault is supposed to happen. Look for [*FaultInjector_InjectFaultIfSet()* calls](https://github.com/greenplum-db/gpdb/search?utf8=%E2%9C%93&q=FaultInjector_InjectFaultIfSet&type=) in the existing code.


## Injecting the fault from inside the database

The [*gp_inject_fault*](https://github.com/greenplum-db/gpdb/tree/master/contrib/gp_inject_fault) extension is used to test certain error cases - obviously this should not be used in production but only for testing.

```
CREATE EXTENSION IF NOT EXISTS gp_inject_fault;
```


After adding the new fault injection, and recompiling the database, the new fault can be tested:

```
SELECT gp_inject_fault(...)
```

Some of the parameters are required, some are optional. There is a long version of this function, which requires 8 parameters, and a shorter, more convenient function which requires the 3 most used parameters.


### Short version

* name of the fault which should be injected
* fault type name
* database id (from *gp_segment_configuration*)

```
SELECT gp_inject_fault('executor_run_high_processed', 'skip', dbid)
  FROM gp_segment_configuration
 WHERE role = 'p';
```



### Long/Complete version

* name of the fault which should be injected
* fault type name
* name of the SQL statement to execute
* database name to match the fault
* table name to match the fault
* number of repeats for the fault
* sleep time for the fault
* database id (from *gp_segment_configuration*)

```
SELECT gp_inject_fault('executor_run_high_processed', 'skip', '', '', '', 0, 0, dbid)
  FROM gp_segment_configuration
 WHERE role = 'p';
```


## An example

Recently the fault injection framework was used to test the SPI 64 bit counter. The counter of processed rows (ROW_COUNT) was changed from 32 bit to 64 bit, in order to hold more than 2 billion processed rows in a pl/pgSQL function. Testing this change is complicated, because a large number of rows (more than 4 billion rows, or 2^32+1 rows) must be created (inserted), updated, selected and deleted. This requires a huge amount of disk space, and takes a while. Nothing a developer can run on a laptop.

The fault injector framework is used to test this change. If the system encounters the code for the fault injector, and a certain number of rows is already processed (10000 rows), the number of processed rows is bumped up to a number short before the maximum integer range (2^32-1 rows). The next few operations will exceed the integer range, and if everything works as expected, flow into the bigint range (2^64-1 rows). If the output is not the expected number, and rather shows a negative number, something along the way is not using a 64 bit variable.


### Code changes for this test

* a new fault injector name was created in *src/include/utils/faultinjector.h*, in *FaultInjectorIdentifier_e*: *ExecutorRunHighProcessed*
* a new name was added in *src/backend/utils/misc/faultinjector.c*, in *FaultInjectorIdentifierEnumToString*: *executor_run_high_processed*
* the new fault injector name was added in *src/backend/utils/misc/faultinjector.c*, in *FaultInjector_NewHashEntry()*
* and finally, test code was added to *src/backend/executor/spi.c* and *src/backend/executor/execMain.c*, which bumbs the row counter

The tests creates a table, and then inserts a number rows under fault injector conditions. Only if the number of processed rows exceeds the integer range, the test is valid. Number rows in the table are counted, then every row in the table is updated, and then deleted. In every test, the number of processed rows is again artificially increased and will exceed the integer range.

Test results are compared against a result file, the test is only valid if all results match the expectation.


## Conclusion

Fault injection is a powerful tool to test the system with respect to soft errors. It helps creating confidence that the product is able to handle even such errors which can't be tested using traditional methods.
