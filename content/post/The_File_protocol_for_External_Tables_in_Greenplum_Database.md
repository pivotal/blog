---
authors:
- ascherbaum
categories:
- Greenplum Database
- Databases
date: 2017-01-25T01:18:23+01:00
draft: false
short: |
  The internals of the File protocol used for External Tables in Greenplum Database
title: The File protocol for External Tables in Greenplum Database
---

# The file:// protocol in External Tables

[Greenplum Database](https://www.greenplum.org/) (GPDB) has the ability to load data from simple text files. No external tool is required and this works as long as the files are on a segment host which is part of the database cluster. This blog post will answer frequently asked questions about this feature.



## Frequently Asked Questions

1. How does this feature work, in general?
2. What kind of data files can be loaded?
3. Can the file protocol access files on other hosts, which are not part of the cluster?
4. Which part of the database will read the file or files?
5. Is it possible to specify multiple readers? How many files can be opened in parallel?
6. How many files can be opened in parallel?
7. If one segment loads a file, will the data still be distributed to all segments?
8. If two segments on the same host read the same file, what will happen?
9. Is it possible to load the same data file more than once, in the same table definition?



## 1. How does this feature work, in general?

The External Table definition in GPDB points the database to a location where the file can be found. The *LOCATION* is part of the table definition:

```
CREATE READABLE EXTERNAL TABLE file_test_ext_1_read (
  LIKE file_test_int
)
LOCATION ('file://gpdb:5432/data/source/input_data_1.csv')
FORMAT 'CSV' (HEADER DELIMITER AS ',');
```

In this simple example, the file is named *input_data_1.csv*, lives in the directory */data/source/* on host *gpdb*. The format of the data file is [CSV](https://en.wikipedia.org/wiki/Comma-separated_values) and the file has a header line with column names, which will be ignored. The creator of the table is responsible for pointing the location(s) to the correct hosts and files.

The file is however only accessed once the table is read. Therefore the file may or may not exist when the table is created. To show how this works let's create two files with data in */data/source/*:

*input_data_1.csv*:

```
id,data
1,row 1
2,row 2
3,row 3
4,row 4
5,row 5
6,row 6
7,row 7
8,row 8
9,row 9
10,row 10
```

*input_data_2.csv*:

```
id,data
11,row 11
12,row 12
13,row 13
14,row 14
15,row 15
16,row 16
17,row 17
18,row 18
19,row 19
20,row 20
```

And a table in the database to load the data into, plus the external table to read the two files:


```
CREATE TABLE file_test_int (
  id          INTEGER             PRIMARY KEY,
  data        TEXT
);

CREATE READABLE EXTERNAL TABLE file_test_ext_1_read (
  LIKE file_test_int
)
LOCATION ('file://gpdb:5432/data/source/input_data_1.csv',
          'file://gpdb:5432/data/source/input_data_2.csv')
FORMAT 'CSV' (HEADER DELIMITER AS ',');
```

Now load the data from the external table into the internal table:

```
INSERT INTO file_test_int SELECT * FROM file_test_ext_1_read;
INSERT 0 20
```

And take a look at what is in the table:

```
SELECT gp_segment_id,* FROM file_test_int ORDER BY gp_segment_id;

 gp_segment_id | id |  data  
---------------+----+--------
             0 |  3 | row 3
             0 |  5 | row 5
             0 |  7 | row 7
             0 |  9 | row 9
             0 | 11 | row 11
             0 | 13 | row 13
             0 | 15 | row 15
             0 | 17 | row 17
             0 | 19 | row 19
             0 |  1 | row 1
             1 |  4 | row 4
             1 |  6 | row 6
             1 |  8 | row 8
             1 | 10 | row 10
             1 | 12 | row 12
             1 | 14 | row 14
             1 | 16 | row 16
             1 | 18 | row 18
             1 | 20 | row 20
             1 |  2 | row 2
(20 rows)

SELECT gp_segment_id,* FROM file_test_int ORDER BY id;

 gp_segment_id | id |  data  
---------------+----+--------
             0 |  1 | row 1
             1 |  2 | row 2
             0 |  3 | row 3
             1 |  4 | row 4
             0 |  5 | row 5
             1 |  6 | row 6
             0 |  7 | row 7
             1 |  8 | row 8
             0 |  9 | row 9
             1 | 10 | row 10
             0 | 11 | row 11
             1 | 12 | row 12
             0 | 13 | row 13
             1 | 14 | row 14
             0 | 15 | row 15
             1 | 16 | row 16
             0 | 17 | row 17
             1 | 18 | row 18
             0 | 19 | row 19
             1 | 20 | row 20
(20 rows)
```

The data from both files ended up in the internal table in GPDB. The column *gp_segment_id* shows which segment holds each data row - in this example the cluster only has two segments, therefore the data is spread out evenly, according to the distribution key defined on *file_test_int*.



## 2. What kind of data files can be loaded?

The [format](https://gpdb.docs.pivotal.io/43110/ref_guide/sql_commands/CREATE_EXTERNAL_TABLE.html) of the input file(s) is very flexible, but follows a few conditions:

* Every row is one line in the file.
* The delimiter can be specified, but it has to be one byte, multi-byte delimiters are not possible.
* One header line can be specified, however if specified the first line in the file is simply ignored.
  * It is not possible to create the table structure based on the field names in the file.
* Strings can be quoted.
* NULLs can be specified.
* [Newlines](https://en.wikipedia.org/wiki/Newline) (end of line/row) can be any of *LF* (Unix, Linux, macOS), *CRLF* (Windows) or *CR* (other).



## 3. Can the file protocol access files on other hosts, which are not part of the cluster?

That is not possible. The data files are loaded by the hosts specified in the table definition, and these hosts must be part of the cluster. Here is an example for a single node cluster:


```
SELECT dbid,content,role,preferred_role,mode,status,port,hostname,address
  FROM pg_catalog.gp_segment_configuration;

 dbid | content | role | preferred_role | mode | status | port  | hostname | address 
------+---------+------+----------------+------+--------+-------+----------+---------
    1 |      -1 | p    | p              | s    | u      |  5432 | gpdb     | gpdb  
    2 |       0 | p    | p              | s    | u      | 40000 | gpdb     | gpdb  
    3 |       1 | p    | p              | s    | u      | 40001 | gpdb     | gpdb  
(3 rows)
```

In the following example a hostname is used which is not part of the cluster definition:

```
CREATE READABLE EXTERNAL TABLE file_test_ext_3_read (
  LIKE file_test_int
)
LOCATION ('file://127.0.0.1:5432/data/source/input_data_1.csv')
FORMAT 'CSV' (HEADER DELIMITER AS ',');
```

```
SELECT * FROM file_test_ext_3_read;
ERROR:  Could not assign a segment database for "file://127.0.0.1:5432/data/source/input_data_1.csv". There isn't a valid primary segment database on host "127.0.0.1"
```

Even though the *127.0.0.1* is the host the database is running on, the database does now know how to map *127.0.0.1* to one of the hosts in the cluster configuration.

It doesn't matter on which hosts the data file(s) are, as long as all hosts are part of the cluster. For performance reasons it is recommended to spread out the files over all hosts in the cluster. The path can even be a [network share](https://en.wikipedia.org/wiki/Shared_resource), which all segment servers can access.



## 4. Which part of the database will read the file or files?

The creator of the external table specifies which hosts of the database cluster will read the data. This happens by specifying the hostname and port number in the *LOCATION* definition. The database then will map the reading process to one of the segments on the host. The example in question 3 only works because the master runs on the same physical host as the two segment servers (single node configuration).

In order to read two files and spread out the workload across the two segments, the table definition should look as follow:


```
CREATE READABLE EXTERNAL TABLE file_test_ext_5_read (
  LIKE file_test_int
)
LOCATION ('file://gpdb:40000/data/source/input_data_1.csv',
          'file://gpdb:40001/data/source/input_data_2.csv')
FORMAT 'CSV' (HEADER DELIMITER AS ',');
```

By also selecting the hidden column *gp_segment_id* the database reveals which segment is reading which file:

```
SELECT gp_segment_id, * FROM file_test_ext_5_read;

 gp_segment_id | id |  data  
---------------+----+--------
             0 |  1 | row 1
             0 |  2 | row 2
             0 |  3 | row 3
             0 |  4 | row 4
             0 |  5 | row 5
             0 |  6 | row 6
             0 |  7 | row 7
             0 |  8 | row 8
             0 |  9 | row 9
             0 | 10 | row 10
             1 | 11 | row 11
             1 | 12 | row 12
             1 | 13 | row 13
             1 | 14 | row 14
             1 | 15 | row 15
             1 | 16 | row 16
             1 | 17 | row 17
             1 | 18 | row 18
             1 | 19 | row 19
             1 | 20 | row 20
(20 rows)
```


To show that the database picks segment hosts to read the data, the following example specifies the master database (port 5432 - this works, because it is on the same physical host), and a non-existent file:

```
CREATE READABLE EXTERNAL TABLE file_test_ext_2_read (
  LIKE file_test_int
)
LOCATION ('file://gpdb:5432/data/source/input_data_x.csv')
FORMAT 'CSV' (HEADER DELIMITER AS ',');
```

When the external table is accessed, it tries to open the file specified as *LOCATION*, and the error message shows that *seg0* fails to find the file. The database mapped the file reading to the first segment on this host.


```
SELECT * FROM file_test_ext_2_read;
NOTICE:  gfile stat /data/source/input_data_x.csv failure: No such file or directory  (seg0 slice1 gpdb:40000 pid=109621)
NOTICE:  fstream unable to open file /data/source/input_data_x.csv  (seg0 slice1 gpdb:40000 pid=109621)
ERROR:  could not open "file://gpdb:5432/data/source/input_data_x.csv" for reading: 404 file not found  (seg0 slice1 gpdb:40000 pid=109621)
```



## 5. Is it possible to specify multiple readers?

That's possible as long as the number of files does not exceed the number of primary segments on this host:

```
CREATE READABLE EXTERNAL TABLE file_test_ext_7_read (
  LIKE file_test_int
)
LOCATION ('file://gpdb:40000/data/source/input_data_1.csv',
          'file://gpdb:40000/data/source/input_data_2.csv',
          'file://gpdb:40000/data/source/input_data_3.csv')
FORMAT 'CSV' (HEADER DELIMITER AS ',');
```

```
SELECT gp_segment_id, * FROM file_test_ext_7_read;
ERROR:  Could not assign a segment database for "file://gpdb:40000/data/source/input_data_3.csv". There are more external files than primary segment databases on host "gpdb"
```

It doesn't matter that the table definition specified the same segment database 3 times, as long as there are enough primary instances on the same host. If the number of files in this example is reduced to 2, and the same segment is specified twice, the data is still loaded using both segments:


```
CREATE READABLE EXTERNAL TABLE file_test_ext_6_read (
  LIKE file_test_int
)
LOCATION ('file://gpdb:40000/data/source/input_data_1.csv',
          'file://gpdb:40000/data/source/input_data_2.csv')
FORMAT 'CSV' (HEADER DELIMITER AS ',');
```

```
SELECT gp_segment_id, * FROM file_test_ext_6_read;

 gp_segment_id | id |  data  
---------------+----+--------
             1 | 11 | row 11
             1 | 12 | row 12
             1 | 13 | row 13
             1 | 14 | row 14
             1 | 15 | row 15
             1 | 16 | row 16
             1 | 17 | row 17
             1 | 18 | row 18
             1 | 19 | row 19
             1 | 20 | row 20
             0 |  1 | row 1
             0 |  2 | row 2
             0 |  3 | row 3
             0 |  4 | row 4
             0 |  5 | row 5
             0 |  6 | row 6
             0 |  7 | row 7
             0 |  8 | row 8
             0 |  9 | row 9
             0 | 10 | row 10
(20 rows)
```

The *gp_segment_id* corresponds with the *content* column from *pg_catalog.gp_segment_configuration*.

```
SELECT dbid,content,role,preferred_role,mode,status,port,hostname,address
  FROM pg_catalog.gp_segment_configuration;

 dbid | content | role | preferred_role | mode | status | port  | hostname | address 
------+---------+------+----------------+------+--------+-------+----------+---------
    1 |      -1 | p    | p              | s    | u      |  5432 | gpdb     | gpdb  
    2 |       0 | p    | p              | s    | u      | 40000 | gpdb     | gpdb  
    3 |       1 | p    | p              | s    | u      | 40001 | gpdb     | gpdb  
(3 rows)
```


## 6. How many files can be opened in parallel?

See question 5. The number of files is limited to the number of primary segment databases on the host.

There is also a system view *pg_max_external_files* available, which shows how many external files can be used per host:

```
SELECT * FROM pg_catalog.pg_max_external_files;

 hostname | maxfiles 
----------+----------
 gpdb     |        2
(1 row)
```



## 7. If one segment loads a file, will the data still be distributed to all segments?

Reading from the external table always happens in the segment picked by the database. This is visualized using the table from question 4 again:

```
SELECT gp_segment_id, * FROM file_test_ext_5_read;

 gp_segment_id | id |  data  
---------------+----+--------
             0 |  1 | row 1
             0 |  2 | row 2
             0 |  3 | row 3
             0 |  4 | row 4
             0 |  5 | row 5
             0 |  6 | row 6
             0 |  7 | row 7
             0 |  8 | row 8
             0 |  9 | row 9
             0 | 10 | row 10
             1 | 11 | row 11
             1 | 12 | row 12
             1 | 13 | row 13
             1 | 14 | row 14
             1 | 15 | row 15
             1 | 16 | row 16
             1 | 17 | row 17
             1 | 18 | row 18
             1 | 19 | row 19
             1 | 20 | row 20
(20 rows)
```

If data is loaded into the database, using the *INSERT INTO ... SELECT FROM ...* syntax, the data is distributed the same way like any other data loading. The database segments will figure out the target segment based on the distribution key, and send the data to the corresponding segments. In the following example, data is read from two files, and written into the internal table created in question 1:

```
TRUNCATE TABLE file_test_int;

DROP EXTERNAL TABLE IF EXISTS file_test_ext_1_read;
CREATE READABLE EXTERNAL TABLE file_test_ext_1_read (
  LIKE file_test_int
)
LOCATION ('file://gpdb:5432/data/source/input_data_1.csv',
          'file://gpdb:5432/data/source/input_data_2.csv')
FORMAT 'CSV' (HEADER DELIMITER AS ',');

INSERT INTO file_test_int SELECT * FROM file_test_ext_1_read;
```

The data in the internal table, sorted by *gp_segment_id*, shows that the data is distributed evenly.

```
SELECT gp_segment_id,* FROM file_test_int ORDER BY gp_segment_id;
 gp_segment_id | id |  data  
---------------+----+--------
             0 |  3 | row 3
             0 |  5 | row 5
             0 |  7 | row 7
             0 |  9 | row 9
             0 | 11 | row 11
             0 | 13 | row 13
             0 | 15 | row 15
             0 | 17 | row 17
             0 | 19 | row 19
             0 |  1 | row 1
             1 |  4 | row 4
             1 |  6 | row 6
             1 |  8 | row 8
             1 | 10 | row 10
             1 | 12 | row 12
             1 | 14 | row 14
             1 | 16 | row 16
             1 | 18 | row 18
             1 | 20 | row 20
             1 |  2 | row 2
(20 rows)
```

The same data, sorted by *id*, shows that it is spread out according to the distribution key.

```
test=# SELECT gp_segment_id,* FROM file_test_int ORDER BY id;
 gp_segment_id | id |  data  
---------------+----+--------
             0 |  1 | row 1
             1 |  2 | row 2
             0 |  3 | row 3
             1 |  4 | row 4
             0 |  5 | row 5
             1 |  6 | row 6
             0 |  7 | row 7
             1 |  8 | row 8
             0 |  9 | row 9
             1 | 10 | row 10
             0 | 11 | row 11
             1 | 12 | row 12
             0 | 13 | row 13
             1 | 14 | row 14
             0 | 15 | row 15
             1 | 16 | row 16
             0 | 17 | row 17
             1 | 18 | row 18
             0 | 19 | row 19
             1 | 20 | row 20
(20 rows)
```

*row 11* was read from the external table with *gp_segment_id=1*, but resides in the table on *gp_segment_id=0*.



## 8. If two segments on the same host read the same file, what will happen?

The database will reject the external table:

```
CREATE READABLE EXTERNAL TABLE file_test_ext_8_read (
  LIKE file_test_int
)
LOCATION ('file://gpdb:40000/data/source/input_data_1.csv',
          'file://gpdb:40000/data/source/input_data_1.csv')
FORMAT 'CSV' (HEADER DELIMITER AS ',');
ERROR:  location uri "file://gpdb:40000/data/source/input_data_1.csv" appears more than once
```


## 9. Is it possible to load the same data file more than once, in the same table definition?

See question 8, the database will reject a table definition which maps to the same file twice.
