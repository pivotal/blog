---
authors:
- ascherbaum
categories:
- Greenplum Database
- Databases
- Testing
- Regression Tests
date: 2018-04-05T17:19:22Z
draft: false
short: |
  How to create new regression tests for Greenplum Database
title: Create Regression Tests for Greenplum Database
---

In today's software development world, testing is a fundamental and necessary part of the entire lifecycle of the product. Software projects grow in size and complexity, many developers submit code changes, and the project has to run on many different platforms. It is almost impossible to cover all such cases without a good number of tests which proof that any new change does not break existing functionality.

## Greenplum Database

Currently the [Greenplum Database](https://greenplum.org/) (GPDB) [code base](https://github.com/greenplum-db/gpdb) is just shy of 1.5 million lines of code. Around 55% of the code - according to [sloccount](https://www.dwheeler.com/sloccount/) - is C code, and 23% is SQL files. The remaining percentages are distributed among Makefiles, header files, documentation and a number of different scripting languages. GPDB runs on, and supports several different Linux flavors, and the client tools are available for an even broader range of platforms: Linux, several Unix flavors, and Windows. Integration into a number of external tools is available, as example for backup using [Netbackup](https://en.wikipedia.org/wiki/NetBackup) or [Data Domain](https://en.wikipedia.org/wiki/Dell_EMC_Data_Domain). In turn, GPDB provides extended functionality with a number of external libraries, like [PostGIS](https://postgis.net/) or [MADlib](https://pivotal.io/madlib). Other projects or companies provide ready-to-go installations, just to mention [Apache Bigtop](http://bigtop.apache.org/) or the [Dell EMC Data Computing Appliance](https://pivotal.io/emc-dca) here.


## Regression Tests

This puts huge pressure on the development, to spot any potential problem as early as possible - in theory even before a new piece of code is merged. To cover all bases, Greenplum Database provides a large number of tests, named [Regression Tests](https://github.com/greenplum-db/gpdb/tree/master/src/test/regress). In addition to the regression tests there are [additional test suits](https://github.com/greenplum-db/gpdb/tree/master/src/test) which cover other aspects of the database functionality. For this blog post we focus on the regression tests, because they are compatible with upstream [PostgreSQL](https://www.postgresql.org/).


### How does it work?

At a very basic level, the regression test provides a file with SQL commands which are executed against the database, and an answer file containing the expected output.

The files with SQL commands are placed in *[src/test/regress/sql/](https://github.com/greenplum-db/gpdb/tree/master/src/test/regress/sql)*, and the filename ends in *.sql*. The answer files are found in *[src/test/regress/expected/](https://github.com/greenplum-db/gpdb/tree/master/src/test/regress/expected)*, and each filename ends in *.out*. Also the basename of the output file (without extension) is the same as the SQL command file.


### How are the regression tests scheduled?

Running the regression tests requires a running database. The [top-level Makefile](https://github.com/greenplum-db/gpdb/blob/master/Makefile) target *create-demo-cluster* will create such a database cluster, and the automatically created shell script *gpAux/gpdemo/gpdemo-env.sh* contains environment values which are required to run the tests, or connect to the database cluster.

```
make create-demo-cluster
. gpAux/gpdemo/gpdemo-env.sh
```

All usual tests against this cluster are run by invoking the top-level Makefile target *installcheck-world*:

```
make installcheck-world
```

This will run a number of different schedules, which are defined in *schedule* files in *src/test/regress/*. GPDB inherits the *[parallel_schedule](https://github.com/greenplum-db/gpdb/blob/master/src/test/regress/parallel_schedule)*, *[serial_schedule](https://github.com/greenplum-db/gpdb/blob/master/src/test/regress/serial_schedule)* and *[standby_schedule](https://github.com/greenplum-db/gpdb/blob/master/src/test/regress/standby_schedule)* from upstream. These files are usually not touched, to make merging with upstream easier. When adding new Greenplum Database specific regression tests, consider adding them to the *[greenplum_schedule](https://github.com/greenplum-db/gpdb/blob/master/src/test/regress/greenplum_schedule)* file.

Every schedule file contains lines starting with "test: ". Every group of tests is specified in such a line, all tests in one group are executed in parallel. If an entire group is finished, the test moves on to the next group in the schedule file. The test is named by using the basename of the filename in the *sql* directory, again without using the *.sql* extension.


### Idempotent results

It is important that regression tests provide stable - idempotent - results when the test is run multiple times. Otherwise the expected answer will differ, and produce an error.

Consider a test which writes 5 dates into a table, and the functionality of the test is to verify that there are indeed 5 rows. An unstable version of the test might just select the 5 rows, and compare the output with the expected answer file:

```
SELECT * FROM reg_test;
 id |    data
----+------------
  1 | 2018-03-12
  2 | 2018-03-13
  3 | 2018-03-14
  4 | 2018-03-15
  5 | 2018-03-16
(5 rows)
```

Obviously this might fail at some point, if the date changes. A better way to run this test is by just counting the number of rows:

```
SELECT COUNT(*) AS count FROM reg_test;
 count
-------
     5
(1 row)
```

As long as the table contains exactly 5 rows, this test will pass.


### Alternative answers

For some tests it is not possible to provide idempotent results, because the output might differ slightly. For such cases, several different answer files can be provided in the *expected* directory. Each answer file is suffixed by an underscore and a number, starting with "1":

- regtest_1.out
- regtest_2.out
- regtest_3.out

The regression test tool will run the test, and compare the output against all available answer files. If one answer file matches, the test will pass.


### Ignoring parts of the test

Some parts of the regression test are not important for the result. As example, it might be necessary to create a procedual language in order to test stored procedures. However several tests might do the same step, and it will fail for any except the first test. To cover such cases it is possible to ignore parts of the test. This works by wrapping the parts of the test which are to be ignored into *start_ignore* and *end_ignore* lines.

In the *.sql* file:

```
--start_ignore
CREATE LANGUAGE plpythonu;
--end_ignore
```

In the *.out* file:

```
--start_ignore
CREATE LANGUAGE
--end_ignore
```

No matter if this block succeeds or not, the text between *start_ignore* and *end_ignore* is ignored when the result is compared.

But be careful: if a test starts a transaction, and fails, the transaction is aborted and this might affect other results down the road. The failing transaction must be rolled back before continuing with further tests.


### Sorting results

Greenplum Database executes queries in parallel on all segments. Unless an *ORDER BY* is specified in the query, the results from a query might come back in any order. Obviously this does not work well with an answer file which only specifies one version of the expected result set.

To work around this problem, the results of a regression test query, and the answers from the *expected* file, are always sorted before they are compared. This way, an *ORDER BY* is not necessary in each and every query. This method will still find errors if the result set itself differs, however there is a small chance that errors slip through which depend on the sort order of the rows. If it is possible that a query might return the correct data in the wrong order, make sure that the regression test query covers this case as well.



## Conclusion

It's not complicated to add new regression tests, and every new feature should be covered by tests. This also applies for most major bugfixes.

If unsure, ask the following questions:

* Is the functionality already covered by existing regression tests?
* Can existing tests be expanded to cover the new functionality, or is a whole new test - possibly with a new schedule - necessary?
* Where to place the new tests? Most likely next to similar existing tests.
* Is the test idempotent, or might it produce unstable results?
* Which parts of the test are necessary, and which parts can be blacked out by using an ignore block?
