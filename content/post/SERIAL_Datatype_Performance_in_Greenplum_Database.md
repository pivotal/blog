---
authors:
- ascherbaum
categories:
- PostgreSQL
- Greenplum Database
- Databases
- Datatypes
- SERIAL
date: 2016-03-31T10:57:27+01:00
draft: false
short: |
  How to improve the performance of the SERIAL datatype in Greenplum Database
title: SERIAL Datatype Performance in Greenplum Database
---

Storing data in a database, you quickly recognize the need for a unique identifier for every data row. Otherwise it is not always possible to join the data with other tables, or identify a specific data row. Sometimes the data itself does not provide a useful key ("natural key" or "business key"), therefore it is necessary to create a surrogate key. The tool of choice to create such technical key is the [SERIAL datatype](http://gpdb.docs.pivotal.io/4380/ref_guide/data_types.html).

## SERIAL Datatype

The SERIAL datatype is a sequence, attached to a column in a table, and the next value is used as default value in case no value is specified. The following two examples show the steps outlined as SQL commands. The first example creates a table with the *id* column as designated surrogate key:

~~~SQL
CREATE TABLE datatable (id INTEGER NOT NULL PRIMARY KEY, data TEXT);
~~~

The second example creates a sequence, attaches the sequence to the table and adds the default value to the *id* column.

~~~SQL
CREATE SEQUENCE id_sequence;

ALTER SEQUENCE id_sequence OWNED BY datatable.id;

ALTER TABLE datatable
ALTER COLUMN id SET DEFAULT nextval('id_sequence');
~~~

Attaching the *id_sequence* to the *datatable* ensures that the sequence is dropped when the table is dropped. A sequence can only be attached to one table, but it can be used in more than one table as a default value - making it a good candidate for a globally unique key.

The database provides a SERIAL datatype, which is an INTEGER with a sequence attached, and a BIGSERIAL datatype, which is a BIGINT with a sequence attached.

| Datatype  | Numeric type | Numeric short name | Minimum value        | Maximum value       |
| :-------- | :----------- | :----------------- | :------------------- | :------------------ |
| SERIAL    | INTEGER      | INT4               | -2147483648          | +2147483647         |
| BIGSERIAL | BIGINT       | INT8               | -9223372036854775808 | 9223372036854775807 |



### How to use the SERIAL Datatype

Once a table with a SERIAL datatype is created, it is easy to use this feature: just do not specify a value for this column:


~~~SQL
serial=# INSERT INTO datatable (data) VALUES ('some text');
INSERT 0 1
serial=# SELECT * FROM datatable;
 id |   data    
----+-----------
  1 | some text
(1 row)

serial=# INSERT INTO datatable (data) VALUES ('some text');
INSERT 0 1
serial=# SELECT * FROM datatable;
 id |   data    
----+-----------
  1 | some text
  2 | some text
(2 rows)
~~~

The default value will ensure that the next sequence value is used.


### Good to know

A sequence is never rolled back. If an INSERT is rolled back, the value used by *nextval()* is lost, leaving a gap in the *id* column here. This makes a sequence a good source for generating unique keys, but it does not ensure that the values are strictly sequential. Do not use this feature to generate something like "invoice numbers".

Instead of not specifying the column in the INSERT, one can also specify the keyword *DEFAULT*:

~~~SQL
serial=# INSERT INTO datatable (id, data) VALUES (DEFAULT, 'some text');
INSERT 0 1
serial=# SELECT * FROM datatable;
 id |   data
----+-----------
  1 | some text
  2 | some text
  3 | some text
(3 rows)
~~~

This might be necessary when using frameworks which generate SQL queries based on the table structure, and want to include every column of the table.


## SERIAL Datatype in Greenplum

A Greenplum Database cluster uses a number of segment databases, running on shared-nothing segment servers. The segment databases share no data and no information which each other. In order to provide globally unique sequence values to the segments, the database uses a sequence server:

~~~
gpadmin   7718  0.0  0.0 361972 10448 ?    S    15:36   0:00  \_ postgres: port 5432, seqserver process
~~~

Whenever a segment needs a value from the sequence, it connects to the sequence server and asks for the next value. You can imagine that there is some overhead involved. This overhead adds up, especially when you not only insert one or two rows, but millions of them. Fortunately, there is a tuning parameter which can be used to avoid many of the round trips to the sequence server:

~~~SQL
ALTER SEQUENCE id_sequence CACHE 5;
~~~

Setting the cache value to *5* will not only fetch the next value, but every segment database will fetch the next *5* values at once, and use them for the next INSERTs. If the segment database in the end only needs 3 values, the remaining 2 are lost (remember the gaps in the sequence?). However with potentially millions of INSERTs, a few lost values are acceptable.

### Performance improvements using the CACHE parameter

This raises an important question: how big is the performance improvement?

The tests for the following numbers were conducted using a table with two columns (1 SERIAL; 1 floating point, filled with *1*). For comparisation, the tests were run with different cache numbers and with a different number of rows.

The first test, without SERIAL:

~~~SQL
CREATE TABLE serial_cache (id INTEGER DEFAULT '1', data DOUBLE PRECISION);
~~~

All tests with SERIAL:

~~~SQL
CREATE TABLE serial_cache (id SERIAL, data DOUBLE PRECISION);
ALTER SEQUENCE serial_cache_id_seq CACHE <n>;
~~~

The following *CACHE* parameters were tested:

0, 1, 2, 3, 5, 10, 20, 50, 100, 500, 1000

where *y=0* is "no SERIAL" - just an integer with a default value, but not using a sequence.

The following number of rows were tested:

100000, 125000, 150000, 175000, 200000

{{< responsive-figure src="/images/serial_datatype/greenplum_database/serial_by_INSERTs.jpg" alt="Overall runtime for the tests" >}}

Looking at the first graph, it instantly becomes clear that "CACHE=1" - the default, it's the green line - is very slow. Running this test takes almost twice as much time as running the same test with "CACHE=2" (blue line). However this graph is not broken down by the time per INSERT, it just shows the overall runtime for the tests. The next graph breaks down the numbers on a per-query basis:

{{< responsive-figure src="/images/serial_datatype/greenplum_database/serial_total_runtime.jpg" alt="per-query runtime for the tests" >}}

Running INSERTs with "CACHE=1" is several times slower than tuning the *CACHE* parameter. The next graph is limited to the CACHE values between *0* (no SERIAL, just an INTEGER) and *5*. It's clearly visible that using a sequence adds a measurable overhead, compared to the *0* value where no SERIAL is used.

{{< responsive-figure src="/images/serial_datatype/greenplum_database/serial_runtime_x_5.jpg" alt="per-query runtime for the tests, limited to CACHE 0-5" >}}

It's also interesting to see which *CACHE* parameters make sense, and at which point they no longer improve the performance. The following graph shows all *CACHE* parameters, but limits the view to *y=20μs*.

{{< responsive-figure src="/images/serial_datatype/greenplum_database/serial_runtime_y_20.jpg" alt="per-query runtime for the tests, limited to y=20" >}}

In this graph, the improvements look big, even between *CACHE=500* and *CACHE=1000*. However compared in the big picture, *CACHE=1* needs around *900μs*, *CACHE=15* already brings down the query runtime to *10μs*, and *CACHE=1000* only improves this down to around *3μs*. A query without a sequence runs in around *1μs*, for comparisation.



## SERIAL Datatype in PostgreSQL

How does this compare to PostgreSQL, running the same tests?

{{< responsive-figure src="/images/serial_datatype/postgresql/serial_total_runtime.jpg" alt="per-query runtime for the tests" >}}

The query runtime averages around *1.5μs*, just the start with *CACHE=0* comes down to around  *1.1μs*. There is no huge performance loss when using a sequence, compared to the spike in Greenplum Database. Looking into the details:

{{< responsive-figure src="/images/serial_datatype/postgresql/serial_runtime_x_5.jpg" alt="per-query runtime for the tests, limited to CACHE 0-5" >}}
{{< responsive-figure src="/images/serial_datatype/postgresql/serial_runtime_y_2.jpg" alt="per-query runtime for the tests, limited to y=2" >}}

The numbers show that there is a small performance loss when using a sequence. The graph goes up for *CACHE=1*, comes back down for *CACHE=2* and *CACHE=3*, and no further improvements for higher *CACHE* values.


## Conclusion

The INSERT performance in Greenplum Database improves greatly, if a sequence uses at least *CACHE=5*.

