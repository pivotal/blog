---
authors:
- ksemenov
categories:
- SQL
- TDD
- Testing frameworks
- Databases
date: 2017-02-24T11:00:54+01:00
draft: false
short: |
  A quick overview of a new database-agnostic SQL testing framework 
title: Trilogy - the database testing framework
---

# {{< responsive-figure alt="Trilogy" src="/images/trilogy-the-sql-testing-framework/trilogy-green@2x.png" class="right" >}}

A bird's eye view of the new SQL testing framework.  


## Introduction

Having had [various issues](../oracle-sql-tdd/) with database testing using existing 
tools and frameworks, after some further investigation, we have decided to start a new database testing 
framework that would provide the abilities to:

- leverage TDD for database development
- run tests within CI and CD workflows
- easily create new tests and test cases
- share the test cases among team members
- deliver easily readable and shareable reports
- test against various databases
- have some fun along the way

## Design

As any agile project, [Trilogy](https://github.com/pivotal/trilogy) did not have full upfront design. 
Rather, the items outlined above were providing guidance for decisions being made along the way.

### CI/CD integration

The ability to run within a CI/CD workflow was one of the biggest, if not the framework's main purpose. And since 
[Concourse](https://concourse.ci) is the most popular tool within Pivotal, the framework was initially designed so that
it could be used with it. The framework itself has a Concourse 
[test pipeline](https://github.com/pivotal/trilogy/tree/master/ci) that can be used as an example.
The current setup uses Oracle, but adding Postgres to the mix is fairly straightforward and is also planned in the 
nearest future.

### Project format

The chosen project format resolves several issues at the same time. 

Unlike other tools, that require database modifications to run, such as 
[pgTAP](http://pgtap.org/documentation.html#addingpgtaptoadatabase),
[utPLSQL](https://utplsql.github.io/docs/fourstep.html) or 
[Oracle SQL Developer](https://docs.oracle.com/cd/E15846_01/doc.21/e15222/unit_testing.htm#RPTUG45068), Trilogy is
running the tests externally, and does not require any database modifications. More importantly, Trilogy test projects 
are stored externally as plain text files that can be easily added to any VCS, such as git. They can be 
executed anytime against any available database.

The format of the test case definition is based on Markdown for a few reasons. First of all, the developer using the 
framework wouldn't have to deal with a whole new programming language in order to use it. Secondly, the testcase 
definition could be used to produce human-readable reports with every test marked with red or green depending on the
outcome. And, finally, if the text editor has a Markdown preview capability, it's easy to spot any mistakes visually, 
e.g. when a value has been placed in the wrong column of the test table.


## Database independence

Having a tool for Oracle is a good start, but it does not make sense to lock in to a particular
database vendor. Therefore we have decided to leverage the wealth of JDBC database drivers
and abstractions. 

This has brought around a number of problems. For example, the procedural tests do not work
for Postgres, as there is no such thing as a stored procedure, all of the Postgres routines
are functions, even though some of them are functions with a `void` return type. The fact that
JDBC needs to know the return type in advance, forced us to postpone the procedural tests
for Postgres to a later time, and to come up with generic tests instead (see below).

## Current progress

Although, at the time of writing, Trilogy hasn't yet reached version 1.0, it already covers most
critical use cases, and can be extremely useful during development. Feel free to grab the 
[latest release](https://github.com/pivotal/trilogy/releases) and give it a try.

Trilogy can run in two modes: `standalone test case` and `test project`. The standalone test case
mode was the stepping stone for the test project mode, however it can still be useful sometimes.
Both modes are explained in more detail below.

### Standalone test cases

The easiest way to start is the standalone test case. It is a text file with an `.stt` extension
that contains a definition of a single test case (`stt` stands for SQL Testing Tool). Standalone test cases
have less functionality - all of their limitations stem from the fact that a standalone test does not have
any resources it can reference. Therefore, a standalone test case cannot use fixtures, schema, or load any
SQL source before execution.

Each test case must have a meaningful description and a collection of tests. The tests can be either `generic` 
or `procedural`, depending on the test case type, and cannot be mixed in the same file.

#### Generic test case

First line of a generic test case is invariably `# TEST CASE`. The generic test case is very simple.
Every test within it defines a SQL snippet that will be executed as part of the test. Optionally, a 
test can also have any number of named assertions. The reason for having those assertions is solely
for having more granular feedback, as the failed assertion name can be more specific than the test name.
For example:


````
# TEST CASE
Decreasing customer balance
## TEST
Should be able to decrease positive balance
```
DO $$
BEGIN
  DELETE FROM CUSTOMER_TRANSACTIONS;
  UPDATE CUSTOMER_BALANCE SET BALANCE=120 WHERE ID=123;
  DECREASE_BALANCE(123, 120);
END
$$;
```
### ASSERTION
Balance should be zero
```
DO $$
BEGIN
  for row in plpy.execute("SELECT BALANCE FROM CUSTOMER BALANCE WHERE ID=123"):
    if row['BALANCE'] is not 0:
      raise RuntimeError('Balance is expected to be 0')
END
$$ LANGUAGE plpythonu;
```
### ASSERTION
A transaction should be recorded
```
DO $$
DECLARE AMT NUMBER;
BEGIN
  SELECT AMOUNT INTO STRICT AMT FROM CUSTOMER_TRANSACTIONS;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE EXCEPTION 'Expected at least one transaction to have been recorded. None were found.';
    WHEN TOO_MANY_ROWS THEN
      RAISE EXCEPTION 'Expected only one transaction to have been recorded. More than one found.';
  IF AMT <> -120 THEN
    RAISE EXCEPTION 'Expected the transaction amount to be -120, but it was %', AMT;
  END IF;
END
$$ LANGUAGE plpgsql;
```
````

In this case the `TEST` clause does the database setup, and executes the procedure. If an error occurs,
the test will fail, and the error will be reported. If we put the assertions into the same code block,
and one of them fails, we would still get a failure, but will have to decipher the cause of the failure
from the database output.

#### Procedural test case

Procedural test case is a special case of a generic one. The procedure name must follow the words `TEST CASE`
in the first line of the file. Procedural test cases only work with stored procedures and cannot be applied 
to stored functions at the time of writing. They are known to work with Oracle RDBMS, and not with PostgreSQL.
Ironically, this type of test case preceded the generic implementation during the framework development.

##### Data table

The whole test case is tied to a specific stored procedure, and rather than specifying a code block as
a test definition, a data table is used instead. Every column in the table is named after an argument.
Due to the fact a stored procedure can accept an INOUT argument, we have borrowed the idea of suffixing
the OUT arguments as well as the OUT part of the INOUT argument with a `$` sign from Oracle SQL Developer.
The output arguments are optional, and are used to verify the output values. The null values are specified
by using the string `__NULL__`. 

##### Error verification

Additionally, a column with a special name `=ERROR=` can be provided to verify errors. Absence of
a value in this column implies that no error is expected. The special keyword `any` can be used to
denote that an error is expected, but the kind of error is not important. And finally, the error message,
or a part of it can be used to match against the actual error.


A standalone procedural test case can be used to test procedures that do not need any setup to run,
for example, procedures without side effects. Below is an example of a test that assumes presence of
a stored procedure with the signature `DIVIDE(ARG_1 IN NUMBER, ARG_2 IN NUMBER, RESULT OUT NUMBER)`:

````
# TEST CASE DIVIDE
Dividing numbers
## TEST
Integer division
### DATA
|ARG_1     |ARG_2     |RESULT$   |=ERROR=|
|---------:|---------:|---------:|-------|
| 1        | 1        | 1        |       |
| 3        | 3        | 1        |       |
| 58       | 2        | 29       |       |
## TEST
Division by zero
### DATA
|ARG_1     |ARG_2     |RESULT$   |=ERROR=|
|---------:|---------:|---------:|-------|
| 1243     | 0        |          |  zero |
````


## Test projects

In order to make the tests independent of the current database state, they would need to run some
setup code. Additionally, if the developer is using TDD, (s)he would want to regularly re-apply
the code that is being worked on to the test database. Lastly, it is important for many database
tests to apply some fixtures before running the tests so that they would be able to produce predictable 
results.

A test project is divided into folders: `src` for the SQL source currently being worked on, and
`tests` containing tests and all the supporting files.

The supporting files must go into the `tests/fixtures` directory. There are two types of supporting
files: fixtures, and schema. The schema, if used, should be stored as `tests/fixtures/schema.sql`
within the project. The fixtures must be separated between the `tests/fixtures/setup` and
`tests/fixtures/teardown` folders. This allows to use the same name for a fixture in a different
context.

### Test cases

The test cases in a project would look exactly like the standalone ones, but with a few enhancements. Before
specifying the tests, test cases in a project can also specify fixtures to be executed before or after
a certain point. Generic test cases support four points `BEFORE ALL`, `BEFORE EACH TEST`, `AFTER EACH TEST` 
and `AFTER ALL`. In addition to that, procedural test cases also support `BEFORE EACH ROW` and `AFTER EACH ROW`.
The `BEFORE` sections can only reference the `setup` fixtures, while the `AFTER` can only reference the `teardown` ones.
All fixture files are expected to have a `sql` extension and can be referenced either by filename without the
extension, or by converting the filename to a sentence. For example, `grate_some_cheese__.sql` can be either referenced
as `grate_some_cheese__` or as `Grate some cheese`. Each section can contain a list of fixtures to load:

````
# TEST CASE VALIDATE_BALANCE
Example
## BEFORE ALL
- Setup client
## BEFORE EACH TEST
- Set client balance
## AFTER EACH TEST
- Remove transactions
## AFTER ALL
- Remove clients
... rest of the test case ...
````


# Examples

To get a better idea of how the projects are structured and can be used, examine the sample 
[projects](https://github.com/pivotal/trilogy/tree/master/src/test/resources/projects) and 
[test cases](https://github.com/pivotal/trilogy/tree/master/src/test/resources/testcases) in the project's
GitHub repository. These examples are used for testing the framework itself, so, unlike this blog post, they should 
always be up to date.

# Roadmap

- Support for external data loading tools
- Generate a script for the DBA to apply to the production database
- Test run report generation (HTML/PDF)
- Support for LOBs
- Enhanced reporting
- Improve assertion options
- Focusing on one or more tests or test cases
- Transactional management and parallel execution

# Thanks

I want to give special thanks to Brian Butz for his help with the project kick-off, and to the fellow Dublin Pivots -
Gregorio Patricio, Deborah Wood, Cassio Dias, Luis Urraca, Colm Roche and Ian Huston for their invaluable contribution 
to the project.
