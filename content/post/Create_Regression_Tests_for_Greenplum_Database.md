---
authors:
- ascherbaum
categories:
- Greenplum Database
- Databases
- Testing
- Regression Tests
date: 2018-03-07T12:16:22Z
draft: true
short: |
  How to create new regression tests for Greenplum Database
title: Create Regression Tests for Greenplum Database
---

In today's software development world, testing is a fundamental part of the entire cycle. Software projects grow in size and complexity, many developers submit all kind of code, and the project has to run on many different platforms. It is almost impossible to cover all such cases without a good number of tests which proof that any new change does not break existing functionality.

## Greenplum Database

Currently the [Greenplum Database](https://greenplum.org/) (GPDB) [code base](https://github.com/greenplum-db/gpdb) is just shy of 1.5 million lines of code. Around 55% of the code - according to [sloccount](https://www.dwheeler.com/sloccount/) - is C code, and 23% are SQL files. The remaining percentages are distributed among Makefiles, header files, documentation and a number of different scripting languages. GPDB runs on, and supports several different Linux flavors, and the client tools are available for an even broader range of platforms: Linux, several Unix flavors, and Windows. Integration into a number of external tools is available, as example for backup using Netbackup or Data Domain. In turn, GPDB provides extended functionality with a number of external libraries, like PostGIS or MADlib. Other projects or companies provide ready-to-go installations, just to mention Apache Bigtop or the Dell EMC Data Computing Appliance here.


## Regression Tests

This puts huge pressure on the development, to spot any potential problem as early as possible - in theory even before a new piece of code is merged. To cover all bases, Greenplum Database provides a large number of tests, named [Regression Tests](https://github.com/greenplum-db/gpdb/tree/master/src/test/regress). In addition to the regression tests there are [additional test suits](https://github.com/greenplum-db/gpdb/tree/master/src/test) which cover other aspects of the database functionality. For this blog post we focus on the regression tests, because they are compatible with upstream [PostgreSQL](https://www.postgresql.org/).


### How does it work?

In principle, the regression test provide a set of SQL commands which are executed against the database, and an answer file containing the expected output.

The files with SQL commands are placed in *src/test/regress/sql/*, and the filename ends in *.sql*. The answer files are found in *src/test/regress/expected/*, and each filename ends in *.out*. Also the basename of the output file (without extension) is the same as the SQL command file.


### How are the regression tests scheduled?

Running the regression tests requires a running database. The top-level Makefile target *create-demo-cluster* will create such a database cluster, and the automatically created shell script *gpAux/gpdemo/gpdemo-env.sh* contains environment values which are required to run the tests, or connect to the database cluster.

```
make create-demo-cluster
. gpAux/gpdemo/gpdemo-env.sh
```

All usual tests against this cluster are run by invoking the top-level Makefile target *installcheck-world*:

```
make installcheck-world
```

This will run a number of different schedules, which are defined in *schedule* files in *src/test/regress/*. GPDB inherits the *parallel_schedule*, *serial_schedule* and *standby_schedule* from upstream. These files are usually not touched, to make merging with upstream easier. When adding new regression tests, consider adding them to the *greenplum_schedule* file.

Every schedule file contains lines starting with "test: ". Every group of tests is specified in such a line, all tests in one group are executed in parallel. If an entire group is finished, the test moves on to the next group in the schedule file. The test is named by using the basename of the filename in the *sql* directory, again without using the *.sql* extension.


### Idempotent results

It is important that regression tests provide stable - idempotent - results when run multiple times. Otherwise the expected answer will differ, and produce an error.

Consider a test which writes 5 dates into a table, and the functionality of the test is to verify that this worked as expected. An unstable version of the test might just select the 5 rows, and compare the output with the expected answer file:

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

Obviously this might fail at some point. A better way to run this test is by just counting the number of rows:

```
SELECT COUNT(*) AS count FROM reg_test;
 count
-------
     5
(1 row)
```

As long as the result contains exactly 5 rows, this test will pass.


### Alternative answers

For some tests it is not possible to provide idempotent results, because the output might differ slightly. For such cases, several different answer files can be provided in the *expected* directory. Each answer file is suffixed by an underscore and a number, starting with "1":

- regtest_1.out
- regtest_2.out
- regtest_3.out

The regression test tool will run the test, and compare the output against all available answer files. If one answer file matches, the test will pass.


### Ignoring parts of the test

Some parts of the regression test are not important for the result. As example, it might be necessary to create a procedual language in order to test stored procedures. However several tests might do the same step, and it will fail for any except the first test. Therefore it is possible to ignore this part of the test.

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

No matter if this block succeeds or not, the text between *start_ignore* and *end_ignore* is ignored.

But be careful: if a test starts a transaction, and fails, the transaction is aborted and this might affect other results down the road.










