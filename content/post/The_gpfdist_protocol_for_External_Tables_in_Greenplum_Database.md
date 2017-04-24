---
authors:
- ascherbaum
categories:
- Greenplum Database
- Databases
date: 2017-04-24T01:18:23+01:00
draft: false
short: |
  The internals of the gpfdist protocol used for External Tables in Greenplum Database
title: The gpfdist protocol for External Tables in Greenplum Database
---

# The gpfdist:// protocol in External Tables

One of the most used features in [Greenplum Database](https://www.greenplum.org/) (GPDB) is parallel data loading using external tables with the gpfdist protocol. This blog post will answer frequently asked questions about this feature.



## Frequently Asked Questions

1. How does this feature work, in general?
2. Does it work in parallel?
3. Can file patterns be used? Or subdirectories?
4. How exactly does the data transfer and parsing work?
5. Must a DNS name be used for the gpfdist host?
6. How many segment databases will load the data?
7. Can the number of segment databases, which will load the data, be limited?
8. Can the gpfdist daemon run on another host? Or can it run on a database host?
9. How many gpfdist processes can be used in parallel?
10. Where does the data processing happen?
11. What happens if data from gpfdist arrives on the wrong segment host?
12. Can the data transport be secured?
13. Is it possible to assign passwords to gpfdist?
14. Can an external table be both readable and writable?
15. What happens if an error happens during data reading?
16. How is invalid input data handled?
17. What happens if two gpfdist daemons read data from the same directory?
18. How is the data distributed in writable external tables?
19. Does gpfdist work with IPv4 and IPv6?






## 1. How does this feature work, in general?

External tables in GPDB can be either READABLE or WRITABLE, the default (if nothing is specified) is READABLE. The gpfdist protocol always involves a small daemon (_gpfdist_) which can run on any host in the network - as long as the host has a direct network connection to every GPDB segment host.


### READABLE External Table

The definition for an External Table points the database to a location where the _gpfdist_ daemon is running. The *LOCATION* is part of the table definition:

```
CREATE READABLE EXTERNAL TABLE gpfdist_test_ext_1_read (
  LIKE gpfdist_test_int
)
LOCATION ('gpfdist://etlhost:8000/input_data_1.csv')
FORMAT 'CSV' (HEADER DELIMITER AS ',');
```

In this simple example, the _gpfdist_ daemon is running on a host named "etlhost", on port 8000. Keep in mind that every segment server must be able to resolve "etlhost" to an IP-address. It's not enough if just the master server can resolve this name. Alternatively specify the IP-address instead of a hostname, if you have no DNS resolver setup in the network.

When the database attempts to read from the external table, the segment databases will open a TCP connection to "etlhost" on port 8000, and ask the _gpfdist_ daemon to read the file "input_data_1.csv". It's important to note that the database only specifies the filename(s), all the reading is done by the _gpfdist_ daemon. Therefore it is not required that the database has login credentials on "etlhost".

```
SELECT * FROM gpfdist_test_ext_1_read;
```

Every segment database will ask the _gpfdist_ daemon for a chunk of data. The daemon will read up to 32 kB of data from the input file, an send it back to the segment database. No parsing happens in the _gpfdist_ daemon, except search for line endings. This makes reading extremely fast, because the daemon can literally read the data line by line until the 32 kB buffer is full.

Once the chunk of data reaches the segment database, it is handled like any regular CSV file: data is split into lines, and every line is parsed according to the table definition.


### WRITABLE External Table

A Writable External Table exports data to gpfdist, which in turn writes it out to the file specified in the location:


```
CREATE WRITABLE EXTERNAL TABLE gpfdist_test_ext_1_write (
  LIKE gpfdist_test_int
)
LOCATION ('gpfdist://etlhost:8000/output_data_1.csv')
FORMAT 'CSV' (HEADER DELIMITER AS ',');
```

The table definition merely defines where the data shall be written. The actual write only happens once data is inserted into the table:


```
INSERT INTO gpfdist_test_ext_1_write
SELECT * FROM gpfdist_test_int;
```

Note that the data is written to the server where the _gpfdist_ daemon is running, into the specified data directory.


### gpfdist daemon


On the gpfdist side, upon starting the _gpfdist_ daemon a directory name is specified. That is the "working directory" for gpfdist, and every filename specified in an external table definition is relative to this directory.


```
gpfdist -d /data/source/ -p 8000
```

In the example above, gpfdist is started and will not return the commandline until it's terminated (with Ctrl+C). That makes it suitable to supply additional verbose (-v) or very verbose (-V) options, and watch what gpfdist is doing. To start _gpfdist_ as daemon, end the line with an ampersend to send the program into the shell background:

```
gpfdist -d /data/source/ -p 8000 &
```

To end the daemon, simply send a kill signal:

```
killall -15 gpfdist
```



## 2. Does it work in parallel?

Reading data using gpfdist is extremely fast. This solution scales on several fronts:

### Scale gpfdist

Data can not only be read from one gpfdist instance, but from multiple instances in parallel. This allows to spread out the input data over several physical ETL hosts.


```
CREATE READABLE EXTERNAL TABLE gpfdist_test_ext_2_read (
  LIKE gpfdist_test_int
)
LOCATION ('gpfdist://etlhost1:8000/input_data_1.csv',
          'gpfdist://etlhost1:8001/input_data_2.csv',
          'gpfdist://etlhost2:8000/input_data_3.csv',
          'gpfdist://etlhost2:8001/input_data_4.csv',
          'gpfdist://etlhost3:8000/input_data_5.csv',
          'gpfdist://etlhost3:8001/input_data_6.csv')
FORMAT 'CSV' (HEADER DELIMITER AS ',');
```

This example reads - in parallel - from 6 different _gpfdist_ daemons, running on 3 different hosts. That is a typical data loading scenario: many servers have 2 [RAID](https://en.wikipedia.org/wiki/RAID) controllers, therefore it makes sense to have the data spread out across both controllers, and have 1 _gpfdist_ daemon running on a directory on each controller.


### Scale the database

In a typical old-fashion data warehouse, data is loaded from a single ETL host. Using gpfdist, the data source is no longer the bottleneck of the data loading process, but instead now the database itself is under pressure to handle the flow of incoming data.

This can be solved by scaling out the GPDB database, adding more segment hosts and therefore providing more raw disk bandwith to load the data. [Expanding the database](https://gpdb.docs.pivotal.io/43120/admin_guide/expand/expand-main.html) is an one-time operation, and does only require a short downtime to finish the expansion.



## 3. Can file patterns be used? Or subdirectories?

The table definition can include a wide range of patterns to match certain input files. Here are some examples:


Specify a filename:

```
LOCATION ('gpfdist://etlhost1:8000/input_data_1.csv')
```


Use all CSV files in the gpfdist working directory:

```
LOCATION ('gpfdist://etlhost1:8000/*.csv')
```


Read all CSV files with data from the year 2016:

```
LOCATION ('gpfdist://etlhost1:8000/2016-*.csv')
```


Read all files in the working directory:

```
LOCATION ('gpfdist://etlhost1:8000/*')
```


Read all CSV files in a subdirectory:

```
LOCATION ('gpfdist://etlhost1:8000/2016-12/*.csv')
```

Note: if you re-create external tables very often, make sure you [VACUUM](https://gpdb.docs.pivotal.io/43120/utility_guide/client_utilities/vacuumdb.html) your catalog tables on a regular basis.



## 4. How exactly does the data transfer and parsing work?

Let's dive in into the technical details. _gpfdist_ is started with verbose options, to show us the details. An input file with several 100 kB of data is used to have enough input for every segment in the database.


```
CREATE READABLE EXTERNAL TABLE gpfdist_test_ext_4_read (
  data TEXT
)
LOCATION ('gpfdist://etlhost1:8000/input_data_big.csv')
FORMAT 'CSV' (HEADER DELIMITER AS ',');
```

```
SELECT data FROM gpfdist_test_ext_4_read;
```

Let's see what gpfdist is doing in detail:

```
2017-04-19 23:18:02 8147 INFO [0:1:0:7] ::ffff:127.0.0.1 requests /input_data_big.csv
2017-04-19 23:18:02 8147 INFO [0:1:0:7] got a request at port 8341:
 GET /input_data_big.csv HTTP/1.1
2017-04-19 23:18:02 8147 INFO [0:1:0:7] request headers:
2017-04-19 23:18:02 8147 INFO [0:1:0:7] Host:127.0.53.53:8000
2017-04-19 23:18:02 8147 INFO [0:1:0:7] Accept:*/*
2017-04-19 23:18:02 8147 INFO [0:1:0:7] X-GP-XID:1492616768-0000000025
2017-04-19 23:18:02 8147 INFO [0:1:0:7] X-GP-CID:0
2017-04-19 23:18:02 8147 INFO [0:1:0:7] X-GP-SN:0
2017-04-19 23:18:02 8147 INFO [0:1:0:7] X-GP-SEGMENT-ID:1
2017-04-19 23:18:02 8147 INFO [0:1:0:7] X-GP-SEGMENT-COUNT:4
2017-04-19 23:18:02 8147 INFO [0:1:0:7] X-GP-LINE-DELIM-LENGTH:-1
2017-04-19 23:18:02 8147 INFO [0:1:0:7] X-GP-PROTO:1
2017-04-19 23:18:02 8147 INFO [0:1:0:7] X-GP-MASTER_HOST:127.0.0.1
2017-04-19 23:18:02 8147 INFO [0:1:0:7] X-GP-MASTER_PORT:5432
2017-04-19 23:18:02 8147 INFO [0:1:0:7] X-GP-CSVOPT:m1x34q34h1
2017-04-19 23:18:02 8147 INFO [0:1:0:7] X-GP_SEG_PG_CONF:/data/seg2/gpsne1/postgresql.conf
2017-04-19 23:18:02 8147 INFO [0:1:0:7] X-GP_SEG_DATADIR:/data/seg2/gpsne1
2017-04-19 23:18:02 8147 INFO [0:1:0:7] X-GP-DATABASE:gpadmin
2017-04-19 23:18:02 8147 INFO [0:1:0:7] X-GP-USER:gpadmin
2017-04-19 23:18:02 8147 INFO [0:1:0:7] X-GP-SEG-PORT:40001
2017-04-19 23:18:02 8147 INFO [0:1:0:7] X-GP-SESSION-ID:8
2017-04-19 23:18:02 8147 INFO remove sessions
2017-04-19 23:18:02 8147 INFO [0:1:1:7] r->path /data/source/input_data_big.csv
2017-04-19 23:18:02 8147 INFO [0:1:1:7] new session trying to open the data stream
2017-04-19 23:18:02 8147 INFO [0:1:1:7] new session successfully opened the data stream
2017-04-19 23:18:02 8147 INFO [0:1:1:7] new session (1): (/data/source/input_data_big.csv, 1492616768-0000000025.0.0.1)
2017-04-19 23:18:02 8147 INFO [0:1:1:7] joined session (/data/source/input_data_big.csv, 1492616768-0000000025.0.0.1)
2017-04-19 23:18:02 8147 INFO [1:1:1:7] ::ffff:127.0.0.1 GET /input_data_big.csv - OK
```

There are several interesting pieces in this. First the filename or file pattern which is requested: _/input_data_big.csv_.

Next the internal session id. This will be used in subsequent requests for more data.

```
2017-04-19 23:18:02 8147 INFO [0:1:0:7] X-GP-XID:1492616768-0000000025
```

Also the database informs gpfdist of the number of segments used:

```
2017-04-19 23:18:02 8147 INFO [0:1:0:7] X-GP-SEGMENT-COUNT:4
```

And which segment is requesting the data:

```
2017-04-19 23:18:02 8147 INFO [0:1:0:7] X-GP-SEGMENT-ID:1
```

Next comes a bit of debugging, gpfdist is serving chunks of data to segment 1:

```
2017-04-19 23:18:02 8147 DEBUG [1:1:1:7] F 31 /data/source/input_data_big.csv
2017-04-19 23:18:02 8147 DEBUG [1:1:1:7] O 43
2017-04-19 23:18:02 8147 DEBUG [1:1:1:7] L 2
2017-04-19 23:18:02 8147 DEBUG [1:1:1:7] D 32759
2017-04-19 23:18:02 8147 DEBUG [1:1:1:7] header size: 67
2017-04-19 23:18:02 8147 DEBUG [1:1:1:7] send header bytes 0 .. 67 (top 67)
2017-04-19 23:18:02 8147 DEBUG [1:1:1:7] send data bytes off buf 0 .. 32759 (top 32759)
2017-04-19 23:18:02 8147 DEBUG [1:1:1:7] F 31 /data/source/input_data_big.csv
2017-04-19 23:18:02 8147 DEBUG [1:1:1:7] O 32802
2017-04-19 23:18:02 8147 DEBUG [1:1:1:7] L 711
2017-04-19 23:18:02 8147 DEBUG [1:1:1:7] D 32742
2017-04-19 23:18:02 8147 DEBUG [1:1:1:7] header size: 67
2017-04-19 23:18:02 8147 DEBUG [1:1:1:7] send header bytes 0 .. 67 (top 67)
2017-04-19 23:18:02 8147 DEBUG [1:1:1:7] send data bytes off buf 0 .. 32742 (top 32742)
2017-04-19 23:18:02 8147 DEBUG [1:1:1:7] F 31 /data/source/input_data_big.csv
2017-04-19 23:18:02 8147 DEBUG [1:1:1:7] O 65544
2017-04-19 23:18:02 8147 DEBUG [1:1:1:7] L 1420
2017-04-19 23:18:02 8147 DEBUG [1:1:1:7] D 32729
2017-04-19 23:18:02 8147 DEBUG [1:1:1:7] header size: 67
2017-04-19 23:18:02 8147 DEBUG [1:1:1:7] send header bytes 0 .. 67 (top 67)
2017-04-19 23:18:02 8147 DEBUG [1:1:1:7] send data bytes off buf 0 .. 32729 (top 32729)
2017-04-19 23:18:02 8147 DEBUG [1:1:1:7] F 31 /data/source/input_data_big.csv
2017-04-19 23:18:02 8147 DEBUG [1:1:1:7] O 98273
2017-04-19 23:18:02 8147 DEBUG [1:1:1:7] L 2128
2017-04-19 23:18:02 8147 DEBUG [1:1:1:7] D 32747
2017-04-19 23:18:02 8147 DEBUG [1:1:1:7] header size: 67
2017-04-19 23:18:02 8147 DEBUG [1:1:1:7] send header bytes 0 .. 67 (top 67)
2017-04-19 23:18:02 8147 DEBUG [1:1:1:7] send data bytes off buf 0 .. 32747 (top 32747)
2017-04-19 23:18:02 8147 DEBUG [1:1:1:7] F 31 /data/source/input_data_big.csv
2017-04-19 23:18:02 8147 DEBUG [1:1:1:7] O 131020
2017-04-19 23:18:02 8147 DEBUG [1:1:1:7] L 2837
2017-04-19 23:18:02 8147 DEBUG [1:1:1:7] D 32759
2017-04-19 23:18:02 8147 DEBUG [1:1:1:7] header size: 67
2017-04-19 23:18:02 8147 DEBUG [1:1:1:7] send header bytes 0 .. 67 (top 67)
2017-04-19 23:18:02 8147 DEBUG [1:1:1:7] send data bytes off buf 0 .. 32759 (top 32759)
2017-04-19 23:18:02 8147 DEBUG [1:1:1:7] F 31 /data/source/input_data_big.csv
2017-04-19 23:18:02 8147 DEBUG [1:1:1:7] O 163779
2017-04-19 23:18:02 8147 DEBUG [1:1:1:7] L 3546
2017-04-19 23:18:02 8147 DEBUG [1:1:1:7] D 32742
2017-04-19 23:18:02 8147 DEBUG [1:1:1:7] header size: 67
2017-04-19 23:18:02 8147 DEBUG [1:1:1:7] send header bytes 0 .. 67 (top 67)
2017-04-19 23:18:02 8147 DEBUG [1:1:1:7] send data bytes off buf 0 .. 32742 (top 32742)
```

The debug output shows that 32 kB data chunks (32759 Bytes, 32742 Bytes, 32729 Bytes, ...) are sent to segment 1.

And now another segment joins:

```
2017-04-19 23:18:02 8147 INFO [0:2:0:9] ::ffff:127.0.0.1 requests /input_data_big.csv
2017-04-19 23:18:02 8147 INFO [0:2:0:9] got a request at port 8343:
 GET /input_data_big.csv HTTP/1.1
2017-04-19 23:18:02 8147 INFO [0:2:0:9] request headers:
2017-04-19 23:18:02 8147 INFO [0:2:0:9] Host:127.0.53.53:8000
2017-04-19 23:18:02 8147 INFO [0:2:0:9] Accept:*/*
2017-04-19 23:18:02 8147 INFO [0:2:0:9] X-GP-XID:1492616768-0000000025
2017-04-19 23:18:02 8147 INFO [0:2:0:9] X-GP-CID:0
2017-04-19 23:18:02 8147 INFO [0:2:0:9] X-GP-SN:0
2017-04-19 23:18:02 8147 INFO [0:2:0:9] X-GP-SEGMENT-ID:3
2017-04-19 23:18:02 8147 INFO [0:2:0:9] X-GP-SEGMENT-COUNT:4
2017-04-19 23:18:02 8147 INFO [0:2:0:9] X-GP-LINE-DELIM-LENGTH:-1
2017-04-19 23:18:02 8147 INFO [0:2:0:9] X-GP-PROTO:1
2017-04-19 23:18:02 8147 INFO [0:2:0:9] X-GP-MASTER_HOST:127.0.0.1
2017-04-19 23:18:02 8147 INFO [0:2:0:9] X-GP-MASTER_PORT:5432
2017-04-19 23:18:02 8147 INFO [0:2:0:9] X-GP-CSVOPT:m1x34q34h1
2017-04-19 23:18:02 8147 INFO [0:2:0:9] X-GP_SEG_PG_CONF:/data/seg4/gpsne3/postgresql.conf
2017-04-19 23:18:02 8147 INFO [0:2:0:9] X-GP_SEG_DATADIR:/data/seg4/gpsne3
2017-04-19 23:18:02 8147 INFO [0:2:0:9] X-GP-DATABASE:blog
2017-04-19 23:18:02 8147 INFO [0:2:0:9] X-GP-USER:gpadmin
2017-04-19 23:18:02 8147 INFO [0:2:0:9] X-GP-SEG-PORT:40003
2017-04-19 23:18:02 8147 INFO [0:2:0:9] X-GP-SESSION-ID:8
2017-04-19 23:18:02 8147 INFO [0:2:3:9] joined session (/data/source/input_data_big.csv, 1492616768-0000000025.0.0.1)
2017-04-19 23:18:02 8147 INFO [1:2:3:9] ::ffff:127.0.0.1 GET /input_data_big.csv - OK
```

This time it's segment 2, but it's the same session id (1492616768) as in the first request. This tells gpfdist that this request joins the already existing connections, and wants to have a piece from the data as well.

Now both of these connections are served chunks of data, in this case until the file ends:


```
2017-04-19 23:18:02 8147 INFO session_get_block: end session due to EOF
2017-04-19 23:18:02 8147 INFO session end.
2017-04-19 23:18:02 8147 INFO [1:2:3:9] sent EOF: succeed
2017-04-19 23:18:02 8147 INFO [1:2:3:9] request end
2017-04-19 23:18:02 8147 INFO [1:2:3:9] detach segment request from session
2017-04-19 23:18:02 8147 INFO [1:2:3:9] successfully shutdown socket
2017-04-19 23:18:02 8147 INFO session_get_block: end session is_error: 0
2017-04-19 23:18:02 8147 INFO session end.
2017-04-19 23:18:02 8147 INFO [1:1:1:7] sent EOF: succeed
2017-04-19 23:18:02 8147 INFO [1:1:1:7] request end
2017-04-19 23:18:02 8147 INFO [1:1:1:7] detach segment request from session
2017-04-19 23:18:02 8147 INFO [1:1:1:7] session has finished all segment requests
2017-04-19 23:18:02 8147 INFO [1:1:1:7] successfully shutdown socket
2017-04-19 23:18:02 8147 INFO [1:2:3:9] peer closed after gpfdist shutdown
2017-04-19 23:18:02 8147 INFO [1:2:3:9] unsent bytes: 0 (-1 means not supported)
2017-04-19 23:18:02 8147 INFO [1:2:3:9] successfully closed socket
2017-04-19 23:18:02 8147 INFO [1:1:1:7] peer closed after gpfdist shutdown
2017-04-19 23:18:02 8147 INFO [1:1:1:7] unsent bytes: 0 (-1 means not supported)
2017-04-19 23:18:02 8147 INFO [1:1:1:7] successfully closed socket
```


And something else happens: the other two missing segments appear, and want data as well.

```
2017-04-19 23:18:02 8147 INFO [0:3:0:7] ::ffff:127.0.0.1 requests /input_data_big.csv
2017-04-19 23:18:02 8147 INFO [0:3:0:7] got a request at port 8345:
 GET /input_data_big.csv HTTP/1.1
2017-04-19 23:18:02 8147 INFO [0:3:0:7] request headers:
2017-04-19 23:18:02 8147 INFO [0:3:0:7] Host:127.0.53.53:8000
2017-04-19 23:18:02 8147 INFO [0:3:0:7] Accept:*/*
2017-04-19 23:18:02 8147 INFO [0:3:0:7] X-GP-XID:1492616768-0000000025
2017-04-19 23:18:02 8147 INFO [0:3:0:7] X-GP-CID:0
2017-04-19 23:18:02 8147 INFO [0:3:0:7] X-GP-SN:0
2017-04-19 23:18:02 8147 INFO [0:3:0:7] X-GP-SEGMENT-ID:0
2017-04-19 23:18:02 8147 INFO [0:3:0:7] X-GP-SEGMENT-COUNT:4
2017-04-19 23:18:02 8147 INFO [0:3:0:7] X-GP-LINE-DELIM-LENGTH:-1
2017-04-19 23:18:02 8147 INFO [0:3:0:7] X-GP-PROTO:1
2017-04-19 23:18:02 8147 INFO [0:3:0:7] X-GP-MASTER_HOST:127.0.0.1
2017-04-19 23:18:02 8147 INFO [0:3:0:7] X-GP-MASTER_PORT:5432
2017-04-19 23:18:02 8147 INFO [0:3:0:7] X-GP-CSVOPT:m1x34q34h1
2017-04-19 23:18:02 8147 INFO [0:3:0:7] X-GP_SEG_PG_CONF:/data/seg1/gpsne0/postgresql.conf
2017-04-19 23:18:02 8147 INFO [0:3:0:7] X-GP_SEG_DATADIR:/data/seg1/gpsne0
2017-04-19 23:18:02 8147 INFO [0:3:0:7] X-GP-DATABASE:blog
2017-04-19 23:18:02 8147 INFO [0:3:0:7] X-GP-USER:gpadmin
2017-04-19 23:18:02 8147 INFO [0:3:0:7] X-GP-SEG-PORT:40000
2017-04-19 23:18:02 8147 INFO [0:3:0:7] X-GP-SESSION-ID:8
2017-04-19 23:18:02 8147 INFO [0:3:0:7] session already ended. return empty response (OK)
2017-04-19 23:18:02 8147 INFO [0:3:0:7] HTTP EMPTY: ::ffff:127.0.0.1 GET /input_data_big.csv - OK
2017-04-19 23:18:02 8147 INFO [0:3:0:7] sent EOF: succeed
2017-04-19 23:18:02 8147 INFO [0:3:0:7] request end
2017-04-19 23:18:02 8147 INFO [0:3:0:7] detach segment request from session
2017-04-19 23:18:02 8147 INFO [0:3:0:7] successfully shutdown socket
2017-04-19 23:18:02 8147 INFO [0:3:0:7] peer closed after gpfdist shutdown
2017-04-19 23:18:02 8147 INFO [0:3:0:7] unsent bytes: 0 (-1 means not supported)
2017-04-19 23:18:02 8147 INFO [0:3:0:7] successfully closed socket
```

```
2017-04-19 23:18:03 8147 INFO [0:4:0:7] ::ffff:127.0.0.1 requests /input_data_big.csv
2017-04-19 23:18:03 8147 INFO [0:4:0:7] got a request at port 8347:
 GET /input_data_big.csv HTTP/1.1
2017-04-19 23:18:03 8147 INFO [0:4:0:7] request headers:
2017-04-19 23:18:03 8147 INFO [0:4:0:7] Host:127.0.53.53:8000
2017-04-19 23:18:03 8147 INFO [0:4:0:7] Accept:*/*
2017-04-19 23:18:03 8147 INFO [0:4:0:7] X-GP-XID:1492616768-0000000025
2017-04-19 23:18:03 8147 INFO [0:4:0:7] X-GP-CID:0
2017-04-19 23:18:03 8147 INFO [0:4:0:7] X-GP-SN:0
2017-04-19 23:18:03 8147 INFO [0:4:0:7] X-GP-SEGMENT-ID:2
2017-04-19 23:18:03 8147 INFO [0:4:0:7] X-GP-SEGMENT-COUNT:4
2017-04-19 23:18:03 8147 INFO [0:4:0:7] X-GP-LINE-DELIM-LENGTH:-1
2017-04-19 23:18:03 8147 INFO [0:4:0:7] X-GP-PROTO:1
2017-04-19 23:18:03 8147 INFO [0:4:0:7] X-GP-MASTER_HOST:127.0.0.1
2017-04-19 23:18:03 8147 INFO [0:4:0:7] X-GP-MASTER_PORT:5432
2017-04-19 23:18:03 8147 INFO [0:4:0:7] X-GP-CSVOPT:m1x34q34h1
2017-04-19 23:18:03 8147 INFO [0:4:0:7] X-GP_SEG_PG_CONF:/data/seg3/gpsne2/postgresql.conf
2017-04-19 23:18:03 8147 INFO [0:4:0:7] X-GP_SEG_DATADIR:/data/seg3/gpsne2
2017-04-19 23:18:03 8147 INFO [0:4:0:7] X-GP-DATABASE:blog
2017-04-19 23:18:03 8147 INFO [0:4:0:7] X-GP-USER:gpadmin
2017-04-19 23:18:03 8147 INFO [0:4:0:7] X-GP-SEG-PORT:40002
2017-04-19 23:18:03 8147 INFO [0:4:0:7] X-GP-SESSION-ID:8
2017-04-19 23:18:03 8147 INFO [0:4:2:7] session already ended. return empty response (OK)
2017-04-19 23:18:03 8147 INFO [0:4:2:7] HTTP EMPTY: ::ffff:127.0.0.1 GET /input_data_big.csv - OK
2017-04-19 23:18:03 8147 INFO [0:4:2:7] sent EOF: succeed
2017-04-19 23:18:03 8147 INFO [0:4:2:7] request end
2017-04-19 23:18:03 8147 INFO [0:4:2:7] detach segment request from session
2017-04-19 23:18:03 8147 INFO [0:4:2:7] successfully shutdown socket
2017-04-19 23:18:03 8147 INFO [0:4:2:7] peer closed after gpfdist shutdown
2017-04-19 23:18:03 8147 INFO [0:4:2:7] unsent bytes: 0 (-1 means not supported)
2017-04-19 23:18:03 8147 INFO [0:4:2:7] successfully closed socket
```

As one can see, there is nothing left, so they are closed immediately. Because this example is running on a small single node instance, the first two segments (1 & 3) are fast enough to receive all the data. When the database came around to schedule the connections for the other two segments (0 & 2), the data was already served completely.

Nevertheless this example shows that all segments (up to _gp_external_max_segs_, see point 6) will request data in parallel, and get 32 kB chunks of data served.



## 5. Must a DNS name be used for the gpfdist host?

A DNS name is not a requirement, specifying an IP-address works equally well. Using DNS names is more convenient, because the ETL host can be changed without any modification to the external table definition in the database.

By contrast, if the ETL host changes, and the new host has a different IP-address, the table definition for every external table pointing to the old host IP must be updated. If a DNS name is used, the IP-address is just changed in the zone file, and every segment server will pick up the new IP shortly after.




## 6. How many segment databases will load the data?

By default, 64 segment databases will connect to the _gpfdist_ daemon and request data. This setting is configurable: if the ETL host is slow, it makes sense to lower the number. And if multiple _gpfdist_ daemons are used, it might make sense to increase it.

Imagine a GPDB cluster with 12 racks a 16 segment servers a 8 primary databases. 1536 segment databases in total. If all segment databases connect to the _gpfdist_ daemon, the Operating System on the ETL host is quite busy just handling all the TCP connections.

In any case: if the number of segment databases in the cluster is smaller than the configured number, then obviously only as many connections as segment databases are opened.

The parameter name is _gp_external_max_segs_:

```
SELECT name, setting, category, short_desc FROM pg_settings WHERE name = 'gp_external_max_segs';
         name         | setting |    category     |                            short_desc                            
----------------------+---------+-----------------+------------------------------------------------------------------
 gp_external_max_segs | 64      | External Tables | Maximum number of segments that connect to a single gpfdist URL.
(1 row)
```

And can be changed either in the database configuration, or on the fly for one request:

```
SET gp_external_max_segs=1;
```


## 7. Can the number of segment databases, which will load the data, be limited?

The number of segment databases which will read data from gpfdist is already limited by default. See Point 6 for an explanation.




## 8. Can the gpfdist daemon run on another host? Or can it run on a database host?

Absolutely. The _gpfdist_ daemon can run on any host which has a direct network connection to every segment host. A common use case for small systems is to run gpfdist on the standby master, because this system is idle, and is already very well connected to the segment servers.




## 9. How many gpfdist processes can be used in parallel?

There is no real limit on the number of specified gpfdist locations. Internally the database parses the string into a [_Datum_](https://www.postgresql.org/docs/current/static/storage-toast.html), which can store roughly 1 GB of text.



## 10. Where does the data processing happen?

The data is sent in chunks from gpfdist to the segment databases. The _gpfdist_ daemon has no business in deciding if the data is valid, or in which segemnt database the rows belong. This all happens, in parallel, in the segment databases.



## 11. What happens if data from gpfdist arrives on the wrong segment host?

The data is sent in 32 kB chunks from gpfdist to the segment databases. The _gpfdist_ daemon has no idea which row in the chunk belongs to which segment, this is only determined once the segment database parses the lines. The segment database will verify if a row belongs to the current segment database, or must be sent over the [Interconnect](https://gpdb.docs.pivotal.io/43120/install_guide/preinstall_concepts.html#topic9) to another segment database.

This approach leverages the parallel power of all CPUs and the network, because every segment database database can be involved in the resource-consuming data parsing process. And the internal network between the segments is fast enough to flow the parsed tuples from one segment to where they belong.



## 12. Can the data transport be secured?

The gpfdist protocol allows to use [Transport Layer Security](https://en.wikipedia.org/wiki/Transport_Layer_Security) (TLS). The protocol name changes from "gpfdist://" to "gpfdists://", and the DBA has to [provide the certificates](https://gpdb.docs.pivotal.io/43120/admin_guide/load/topics/g-gpfdists-protocol.html) on both ends.

It might also be required (for compliance reasons, as example) to firewall the transport layer between database segments and gpfdist/ETL host(s). Keep in mind that this is a high-traffic connection, where data is flowing as fast as possible from the ETL host to the segments. It's easy to overload a firewall by the amount of traffic, especially when [Deep Packet Inspection](https://en.wikipedia.org/wiki/Deep_packet_inspection) (DPI) is used.



## 13. Is it possible to assign passwords to gpfdist?

No. Anyone can connect to the _gpfdist_ daemon. Make sure that only appropriate users can connect to this host and port.



## 14. Can an external table be both readable and writable?

That is not possible. Two external tables (one readable and one writable) are required.




## 15. What happens if an error happens during data reading?

It depends on the kind of error.

### Network error

In case when something interrupts the data flow to one or multiple segments, or the _gpfdist_ daemon is not running, the entire transaction is aborted and rolled back. If you use [Heap tables](https://gpdb.docs.pivotal.io/43120/admin_guide/ddl/ddl-storage.html), you might end up with a number dead rows in the table, and need to run [VACUUM](https://gpdb.docs.pivotal.io/43120/ref_guide/sql_commands/VACUUM.html) to reclaim the disk space.


### Syntax error

If the query can't be parsed by the database, the query and the transaction are aborted. [SAVEPOINT](https://gpdb.docs.pivotal.io/43120/ref_guide/sql_commands/SAVEPOINT.html)s can be used to work around the aborted transaction.


### Invalid data

Often invalid data is a completely malformed line with just garbage in it, or the column delimiter is missing. That is not something the user or the DBA can prevent, as data comes from external sources. But lines which do not fit the table definition can be redirected into an error table (up to GPDB 4.3) or into the error log (beginning with GPDB 4.3). The DBA can examine the rows in question, and decide if further action is required.


```
CREATE READABLE EXTERNAL TABLE ... (
...
)
LOCATION (...)
FORMAT 'CSV' (HEADER DELIMITER AS ',')
LOG ERRORS INTO read_errors_table SEGMENT REJECT LIMIT 100;
```

This will redirect up to 100 errors per segment into the table named _read_errors_table_. If the error table does not exist, it will be created.

Note: error tables are no longer supported in GPDB 5.0 and newer.

The alternative to error tables is using the error log:

```
CREATE READABLE EXTERNAL TABLE ... (
...
)
LOCATION (...)
FORMAT 'CSV' (HEADER DELIMITER AS ',')
LOG ERRORS SEGMENT REJECT LIMIT 10 PERCENT;
```

The second example stores up to 10% defective rows in the internal error log, which can be accessed using the _gp_read_error_log()_ function.



## 16. How is invalid input data handled?

For a more thorough explanation, see question 15.

In GPDB 4, up to version 4.3, invalid data is written to the error table - if one was specified during creation of the external table.

In GPDB 5, the invalid data is written to the error log, and can be retrieved from there.



## 17. What happens if two gpfdist daemons read data from the same directory?

Different gpfdist processes do not coordinate between each other. If multiple gpfdist processes point to the same files, the data will be read multiple times.



## 18. How is the data distributed in writable external tables?

Data distribution for writable external tables works like data distribution for any other table. A distribution key can be defined:


```
CREATE WRITABLE EXTERNAL TABLE gpfdist_test_ext_18_write (
  LIKE gpfdist_test_int
)
LOCATION ('gpfdist://etlhost:8000/output_data_1.csv',
          'gpfdist://etlhost:8000/output_data_2.csv',
          'gpfdist://etlhost:8000/output_data_3.csv')
FORMAT 'CSV' (HEADER DELIMITER AS ',')
DISTRIBUTED BY (id);
```

Data distribution only makes sense if more than one location target are defined. If only one location is specified, all data is exported into this location.

As an alternative, if no good distribution key is available, the data can be distributed randomly.

```
DISTRIBUTED RANDOMLY;
```


## 19. Does gpfdist work with IPv4 and IPv6?

gpfdist does not care (much) about the used IP version. It will serve requests on the specified port, using whatever protocol the Operating System supports:

```
gpfdist -d /data/source/ -p 8000 -v -V
```

Will result in the following output:

```
2017-04-24 22:47:40 2418 INFO Before opening listening sockets - following listening sockets are available:
2017-04-24 22:47:40 2418 INFO IPV6 socket: [::]:8000
2017-04-24 22:47:40 2418 INFO IPV4 socket: 0.0.0.0:8000
2017-04-24 22:47:40 2418 INFO Trying to open listening socket:
2017-04-24 22:47:40 2418 INFO IPV6 socket: [::]:8000
2017-04-24 22:47:40 2418 INFO Opening listening socket succeeded
2017-04-24 22:47:40 2418 INFO Trying to open listening socket:
2017-04-24 22:47:40 2418 INFO IPV4 socket: 0.0.0.0:8000
2017-04-24 22:47:40 2418 WARN Address already in use (errno = 98), port: 8000
Serving HTTP on port 8000, directory /data/source
```

The output shows that gpfdist opens a socket on both IPv4 and IPv6.
