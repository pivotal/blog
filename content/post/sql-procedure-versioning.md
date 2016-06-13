---
authors:
- ksemenov
- cdias
categories:
- SQL
- Version control
date: 2016-06-08T09:25:09+01:00
draft: false
short: |
  A versioning strategy for SQL stored procedures provides flexibility for developers both on the DB and the application side.
title: SQL Stored Procedure Versioning Strategy
---

On projects where application components are calling stored procedures in the database, there is always a risk for those components and the DBMS to get out of sync. As the application evolves, there might be a need to change the functionality on the database side based on the changes to other components of the application. In order to avoid confusion and reduce coupling, a versioning strategy can be employed.

## Example
For example, our application needs to call a stored procedure in order to set the currency exchange rate in the system. Assuming the SQL*Plus dialect, the signature of the procedure can look like this:

~~~sql
CREATE OR REPLACE PROCEDURE SET_EXCHANGE_RATE(V_SYMBOL IN VARCHAR2, V_NEW_RATE IN NUMBER)...
~~~

There is a number of change scenarios that may follow the initial implementation:

1. The call signature has to be changed due to requirements.
    1. The default value can be provided for the original procedure, or a return value has been introduced that can be discarded.    
    1. It is impossible to provide a default value to match the new signature from the old procedure.
1. The new requirements are demanding a significant change to the functionality behind the procedure call.
    1. The caller should not be concerned with the change.
    1. The change is significant and might break the expectations - this seems to be a design smell. It would be more appropriate to rename the procedure reflecting the change in functionality.
    
The issues outlined above can be addressed in a number of ways. One approach could be to include the version number as an argument to the stored procedure. This approach, however, seems to be brittle, and would require a switch statement to dispatch the call to the appropriate version, and also it does not allow to change the signature of the procedure.
 
Another approach would be to include the version in the procedure name. This will ensure that the application will always call the version of the procedure it was designed to work with, and would also provide flexibility to add or remove arguments as needed. Thus the initial stored procedure might look like this:

~~~sql
CREATE OR REPLACE PROCEDURE SET_EXCHANGE_RATE$1(V_SYMBOL IN VARCHAR2, V_NEW_RATE IN NUMBER)...
~~~

### Default values available

In our first case, one of the components has to know whether the operation has succeeded. Therefore, an output parameter to communicate success to the application is introduced in the new version of the procedure:
~~~sql
CREATE OR REPLACE PROCEDURE SET_EXCHANGE_RATE$2(V_SYMBOL IN VARCHAR2, V_NEW_RATE IN NUMBER, V_SUCCESS OUT NUMBER)...
~~~

In that case we can update the original procedure to call the new one:
~~~sql
CREATE OR REPLACE PROCEDURE SET_EXCHANGE_RATE$1(V_SYMBOL IN VARCHAR2, V_NEW_RATE IN NUMBER) AS
  V_IGNORED_OUTPUT NUMBER;
BEGIN
  SET_EXCHANGE_RATE$2(V_SYMBOL, V_NEW_RATE, V_IGNORED_OUTPUT);
END;
~~~

Given that we have a proper [test suite](/post/oracle-sql-tdd/), it should tell us that everything is still working as expected.

### New functionality requires more information

Another requirement might dictate that the username has to be recorded in the audit log when a new exchange rate is set. As the user name is not provided in the original procedure call, and a default cannot be assumed, an exception should be raised, indicating the reason for the crash, and a new course of action:
~~~sql
CREATE OR REPLACE PROCEDURE SET_EXCHANGE_RATE$1(V_SYMBOL IN VARCHAR2, V_NEW_RATE IN NUMBER) AS
V_IGNORED_OUTPUT NUMBER;
BEGIN
  RAISE_APPLICATION_ERROR(-90101, 'A deprecated procedure SET_EXCHANGE_RATE$1 called. Please update the application to use SET_EXCHANGE_RATE$2(V_SYMBOL IN VARCHAR2, V_NEW_RATE IN NUMBER, V_USERNAME VARCHAR2) instead.'); 
END;
~~~

### No change to the signature

Another requirement, in contrast to the previous one, might specify that all the changes to exchange rates should be recorded, but the user name is not important. Similar to the first case, when there is no change to the signature, it would still be useful to create a new version of the procedure, and point it to the new one. We would still have our regression tests running against the original version, and additional functionality tests will be covering the second version.

## Conclusion

Keeping the versions of stored procedures in sync with the calling application is vital to the quality and robustness of the whole application. The demonstrated versioning strategy will provide a clear migration path to all development teams, as well as reduce the coupling between the application and the DB interfaces.
