---
authors:
- frankgh
- user
categories:
- Greenplum
- PXF
- JDBC
- Partitioning
- Parallel
- JDBC Reads

date: 2019-09-24T09:00:00Z
draft: false
short: |
  Parallel data reads from external databases in PXF using JDBC Partitioning
title: 'Greenplum: Speeding up JDBC Reads in PXF Using Partitioning'

---
Pivotal Greenplum Database® is an advanced, fully featured, open source data warehouse.
Greenplum provides powerful and rapid analytics on petabyte scale data volumes.

PXF is a query federation engine that accesses data residing in external systems
such as Hadoop, Hive, HBase, relational databases through JDBC, S3, Google Cloud Storage,
among other external systems.

In this post we will show how to optimize transferring 50GB of data between two
Greenplum clusters.
First, we will transfer data without any partitioning strategy. Without partitioning,
only a single segment will be accessing data from the second Greenplum cluster.
Later, we will add a partition strategy and transfer data in parallel from the 
external Greenplum cluster. We will show 6X speedups when using a partitioning
strategy to transfer data between the two Greenplum clusters.

## PXF JDBC Read Partitioning

The PXF JDBC connector can read data in parallel from an external SQL table
by creating sub-queries that retrieve a subset of data. A PXF cluster can
read data in parallel by issuing sub-queries concurrently to the external database.


To obtain optimal performance a the partition column needs to be identified. One
should choose a partition column that can take advantage of concurrent reads.
For example, in Oracle a partitioning key column can be used. In Greenplum we
can take advantage of the special column `gp_segment_id` to take advantage
of parallel reads. When using `gp_segment_id` in Greenplum, each segment will
only scan its own data, and then hand off that data to master.

PXF JDBC Read Partitioning can significantly speed up access to external database
tables, speeding up data querying or data loading.

### Partition Types

PXF supports three types of partitions: INT, DATE, and ENUM.

**1. INT Partition**

   This partition type is intended for numeric columns. The columns do not necessarily
   have to be integer, but the partition range has to be numeric. For example,
   `&PARTITION_BY=year:int&RANGE=2011:2013&INTERVAL=1` will generate the following
   sub-queries to the external database:
    
   - `WHERE year < 2011`
   - `WHERE year >= 2011 AND year < 2012`
   - `WHERE year >= 2012 AND year < 2013`
   - `WHERE year >= 2013`
   - `WHERE year IS NULL`
   
   Each sub-query will be processed by a different PXF thread, and possibly by a
   different PXF server.

**2. DATE Partition**

   Similar to the INT partition, the date partition will generate sub-queries in the
   specified interval. For example,
   `&PARTITION_BY=createdate:date&RANGE=2013-01-01:2013-03-01&INTERVAL=1:month` will
   generate the following sub-queries to the external database:
   
   - `WHERE createdate < '2013-01-01'`
   - `WHERE createdate >= '2013-01-01' AND createdate < '2013-02-01'`
   - `WHERE createdate >= '2013-02-01' AND createdate < '2013-03-01'`
   - `WHERE createdate >= '2013-03-01'`
   - `WHERE createdate IS NULL`
   
**3. ENUM Partition**

   The enum partition will generate partitions given the discrete values provided.
   For example, `&PARTITION_BY=color:enum&RANGE=red:yellow:blue` will generate
   the following sub-queries to the external database:
   
   - `WHERE color = 'red'`
   - `WHERE color = 'yellow'`
   - `WHERE color = 'blue'`
   - `WHERE color <> 'red' AND color <> 'yellow' AND color <> 'blue'`
   - `WHERE color is NULL`


Please refer to the PXF JDBC [official documentation](https://gpdb.docs.pivotal.io/latest/pxf/jdbc_pxf.html)
for more information.

## The experiment

For the experiment we have two Greenplum clusters, let's call them `cluster1` and `cluster2`.
`cluster1` has about
50GB of [TPC-H](http://www.tpc.org/tpch/) lineitem data, and `cluster2` is empty.

We will transfer data from `cluster1` into `cluster2` with and without a JDBC
partitioning strategy.

### Setup

For the experiment we provision two clusters in Google Cloud, with 1 master and
7 segment hosts for each cluster. Each segment host has 4 segments for a total of
28 segments. For the compute instance type we chose `n1-highmen-4` with 100GB of
disk space each. The two clusters are deployed on the same region and the same
subnet.

This 18 minute video runs through the experiment and shows the results:

{{< youtube ARW-WJID3ME >}}

#### External Table DDL without partitioning

~~~greenplum
CREATE EXTERNAL TABLE lineitem_external (LIKE lineitem)
LOCATION('pxf://lineitem?PROFILE=jdbc&SERVER=greenplum')
FORMAT 'CUSTOM' (formatter='pxfwritable_import');
~~~

#### External Table DDL partitioned by `gp_segment_id`

~~~greenplum
CREATE EXTERNAL TABLE lineitem_partitioned (LIKE lineitem)
LOCATION('pxf://lineitem?PROFILE=jdbc&PARTITION_BY=gp_segment_id:int&RANGE=0:27&INTERVAL=1&SERVER=greenplum')
FORMAT 'CUSTOM' (formatter='pxfwritable_import');
~~~

With partitioning, the PXF JDBC connector will issue 31 queries to `cluster1`:

   - `WHERE gp_segment_id < 0`
   - `WHERE gp_segment_id >= 0 AND gp_segment_id < 1`
   - ....
   - `WHERE gp_segment_id >= 26 AND gp_segment_id < 27`
   - `WHERE gp_segment_id >= 27`
   - `WHERE gp_segment_id IS NULL`

## Results

{{< responsive-figure src="/images/pxf-speeding-up-jdbc-reads/fig1.png" class="center" >}}

## Conclusion

When using the PXF JDBC connector, consider using a partitioning strategy when
reading data from an external database into Greenplum. A good partitioning strategy
will produce transfer speedups and increase overall performance on JDBC reads
using PXF. To choose a good partitioning strategy you need to take into account
how data is stored on the external database. In our experiment above, we took
advantage of Greenplum's distribution policy by issuing one query per segment,
and each segment was accessing its own data. We saw a 6X transfer speedup by
utilizing this strategy. In other databases, for example Oracle, you can use a
different criteria such as data partitions, to speed up your reads.