---
authors:
- ascherbaum
categories:
- PostgreSQL
- Greenplum Database
- Databases
date: 2016-02-27T01:58:42+01:00
draft: false
short: |
  How to find out the current TransactionID in Greenplum Database
title: Current TransactionID in Greenplum Database
---

Recently, during a training, a colleague asked me how to find out the current TransactionID in a [Greenplum Database](http://greenplum.org/) system. This piece of information is important in order to find out if a [VACUUM](http://gpdb.docs.pivotal.io/4370/ref_guide/sql_commands/VACUUM.html) run is required on a table.

### PostgreSQL

In [PostgreSQL](http://www.postgresql.org/) (Greenplum Database is a PostgreSQL fork) this is easy:

Current TransactionID in PostgreSQL:
```
postgres=> SELECT txid_current();
 txid_current 
--------------
          816
(1 row)
```

### Greenplum

Unfortunately, the [merge process](https://github.com/greenplum-db/gpdb) with PostgreSQL has not yet merged in this function. Therefore things get a bit more complicated, and a workaround is required. The system table '*pg_locks*' shows, among other information, the TransactionID. Selecting from this table will show at least two records: one *AccessShareLock* on '*pg_locks*' itself, and one *ExclusiveLock* on the current TransactionID.

Current TransactionID in Greenplum:
```
postgres=> SELECT transactionid FROM pg_locks
WHERE pid = pg_backend_pid() AND locktype = 'transactionid' AND mode = 'ExclusiveLock' AND granted = 't';
 transactionid
---------------
          1325
(1 row)
```

In most cases it is enough to just limit the results by '*pid*' and '*locktype*'.

Current TransactionID in Greenplum (shorter):
```
postgres=> SELECT transactionid FROM pg_locks
WHERE pid = pg_backend_pid() AND locktype = 'transactionid';
 transactionid
---------------
          1325
(1 row)
```

On the downside, this query is consuming yet another TransactionID, if run in a separate transaction.