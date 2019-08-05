---
authors:
- xiwei
categories:
- Greenplum Database
- GPDB
- Platform Extension Framework
- PXF
- S3 Select
- AWS 
- Amazon S3
- Amazon Simple Storage Service
date: 2019-08-01T09:00:00Z
draft: true
short: |
  As PXF supports S3 Select from AWS S3, Greenplum users can now make more efficient queries to external S3 data source at potentially cheaper cost.
title: How PXF on Greenplum uses S3 Select to make queries more efficient
---
## **Background**
This blog is about introducing a new feature of PXF which helps Greenplum Database users utilize S3 Select for AWS S3. If you're already familiar with GPDB (Greenplum Database), PXF (Greenplum Platform Extension Framework) and Amazon Simple Storage Service (Amazon S3), you can jump to the Overview section.

#### **What is GPDB (Greenplum Database) and External Table?**
{{< responsive-figure src="/images/s3-select/highlevel_arch.jpg" class="right" >}}
Greenplum Database is a massively parallel processing (MPP) database server with an architecture specially designed to manage large-scale analytic data warehouses and business intelligence workloads. It is based on PostgreSQL open-source technology, and therefore in most cases, very similar to PostgreSQL. Users can interact with Greenplum Database as they would with a PostgreSQL database[[1](https://gpdb.docs.pivotal.io/latest/admin_guide/intro/arch_overview.html)].

**External Table**: Greenplum Database can read from and write to several types of external data sources, including text files, Hadoop file systems, Amazon S3, and web servers. This can be achieved by creating readable and writable external tables with the Greenplum Platform Extension Framework (PXF), and use these tables query external data or to load data into, or offload data from, Greenplum Database[[2](https://gpdb.docs.pivotal.io/latest/admin_guide/load/topics/g-loading-and-unloading-data.html)].

#### **What is PXF (Greenplum Platform Extension Framework)?**
{{< responsive-figure src="/images/s3-select/pxfarch.jpg" class="left" >}}
The Greenplum Platform Extension Framework (PXF) provides connectors that enable you to access data stored in sources external to your Greenplum Database deployment. These connectors map an external data source to a Greenplum Database external table definition. You can query the external table via Greenplum Database, leaving the referenced data in place. Or, you can use the external table to load the data into Greenplum Database for higher performance[[3](https://gpdb.docs.pivotal.io/latest/pxf/intro_pxf.html)].

Currently, PXF is installed with JDBC, Hadoop, Hive, HBase, and Object Store connectors. These connectors enable you to read external data stored in text, Avro, JSON, RCFile, Parquet, SequenceFile, and ORC formats. You can use the JDBC connector to access an external SQL database[[4](https://gpdb.docs.pivotal.io/latest/admin_guide/external/pxf-overview.html)].

#### **What is Amazon Simple Storage Service (Amazon S3) and S3 Select?**
{{< responsive-figure src="/images/s3-select/aws_s3_select.png" class="right" >}}
[Amazon Simple Storage Service (Amazon S3)](https://aws.amazon.com/s3/) is an object storage service and one of the building blocks of AWS infrastructure. It provides web services interface that allows its customers to store and retrieve any amount of data.

**S3 Select**: It is an S3 feature designed to increase query performance by up to 400%, and reduce querying costs as much as 80% [as Amazon claims](https://aws.amazon.com/blogs/aws/s3-glacier-select/). It works by retrieving a subset of an object’s data (using simple SQL expressions) instead of the entire object, which can be up to 5 terabytes in size. PXF implements support for S3 Select so that users can utilize the benefit of this feature from within GPDB.

## **Overview**
Now that PXF supports [S3 Select](https://docs.aws.amazon.com/AmazonS3/latest/dev/s3-glacier-select-sql-reference.html), users can make more efficient queries against S3 object stores by running simple SQL queries on Greenplum. When enabled, PXF utilizes S3 Select to do query predicate pushdown and column projection to S3. This helps users retrieve only the subset of data they are interested in rather than having the entire S3 object transmitted via PXF to Greenplum for processing. By utilizing S3 Select, Greenplum users can see significant speedup on certain workloads.

Currently, PXF supports Text and Parquet format of the object files stored on Amazon S3. It may support other formats such as JSON in the future.

{{< responsive-figure src="/images/s3-select/S3-Select-diagram.jpg" class="center" >}}

---
## **Trying it out by yourself**
There are some components required to set up in order to try out S3 Select with PXF and GPDB.
### **Prerequisite**
- **Setting up an S3 Bucket**: other than setting up an Amazon S3 bucket as external object store, [Minio](https://min.io/product), an open-sourced project with similar features and APIs is also available for on-premise deployment.
  - For using Amazon S3: [signing up](https://docs.aws.amazon.com/AmazonS3/latest/gsg/SigningUpforS3.html) and [creating bucket](https://docs.aws.amazon.com/AmazonS3/latest/gsg/CreatingABucket.html)
  - For using Minio: [quick start](https://docs.min.io/docs/minio-quickstart-guide.html) and [more specific guide for GPDB and Minio](http://engineering.pivotal.io/post/gpdb_accessing_minio/)
- **Installing GPDB**: [Installation guide](https://gpdb.docs.pivotal.io/latest/install_guide/install_guide.html) or [building GPDB from source](https://github.com/greenplum-db/gpdb#building-gpdb-with-pxf)
- **Configuring PXF for S3 Bucket**: [introduction](https://gpdb.docs.pivotal.io/5210/pxf/overview_pxf.html) and [configuration guide](https://gpdb.docs.pivotal.io/latest/pxf/access_objstore.html)


Once GPDB and PXF are properly configured and running, users can go into Greenplum Database shell command line by typing (more [guide](http://postgresguide.com/utilities/psql.html) on psql command): 
```terminal
> psql
```
Now under GPDB's command line shell, users can create external tables to access files on S3 object store by providing external table definition and specifying options to enable S3 Select. Here is an example of creating an external table: 
```SQL
CREATE EXTERNAL TABLE orders_from_s3 (id int, name text)
LOCATION ('pxf://bucket-name/path/in/s3/?PROFILE=s3:parquet&S3_SELECT=ON&SERVER=s3')
FORMAT 'CSV';
```
In above SQL string,

- `CREATE EXTERNAL TABLE orders_from_s3` tells GPDB to create an external table named `orders_from_s3`
- `(id int, name text)` is the schema of this table
- `LOCATION ('pxf://bucket-name/path/in/s3/?PROFILE=s3:parquet&S3_SELECT=ON&SERVER=s3')` provides information to GPDB such as:
  - the protocol `pxf`, 
  - path of the file object on S3 `bucket-name/path/in/s3/`, 
  - options that PXF needs to process the queries to S3 `?PROFILE=s3:parquet&S3_SELECT=ON&SERVER=s3'`. 

Note: here `S3_SELECT=ON` is the option to enable the S3 Select feature through PXF. Click [here](https://gpdb.docs.pivotal.io/latest/pxf/objstore_text.html#profile_text) for more detail on creating external table to read data in an object store. 

Now you can make simple SQL queries to your S3 object store and test out S3 Select. For example:
```sql
SELECT id, name, FROM orders_from_s3 WHERE id = 3;
```
Here `WHERE id = 3` is the filter clause that PXF will recognize and passing to S3 to utilize S3 Select.

On the other hand, queries like this:
```sql
SELECT * FROM orders_from_s3;
```
will not be able to utilize S3 Select as it asks S3 to return all the data.

## **Performance Comparison**
{{< responsive-figure src="/images/s3-select/benchmark.png" class="center" >}}

The graph above indicates the results of queries made towards Amazon S3 object store with and without S3 Select feature in effect, for multiple object files with different sizes. The time consumed to complete query against each file is the average of results from running the same query multiple times. 

We created a local table with the following schema:

```SQL
CREATE TABLE lineitem (
    l_orderkey    BIGINT NOT NULL,
    l_partkey     BIGINT NOT NULL,
    l_suppkey     BIGINT NOT NULL,
    l_linenumber  BIGINT NOT NULL,
    l_quantity    DECIMAL(15,2) NOT NULL,
    l_extendedprice  DECIMAL(15,2) NOT NULL,
    l_discount    DECIMAL(15,2) NOT NULL,
    l_tax         DECIMAL(15,2) NOT NULL,
    l_returnflag  CHAR(1) NOT NULL,
    l_linestatus  CHAR(1) NOT NULL,
    l_shipdate    DATE NOT NULL,
    l_commitdate  DATE NOT NULL,
    l_receiptdate DATE NOT NULL,
    l_shipinstruct CHAR(25) NOT NULL,
    l_shipmode     CHAR(10) NOT NULL,
    l_comment VARCHAR(44) NOT NULL
) DISTRIBUTED BY (l_partkey);
```

Then we create different external tables referring to files of different sizes on the S3 store using SQL strings like this:

```SQL
CREATE EXTERNAL TABLE s3_parquet_no_select (LIKE lineitem)
LOCATION ('pxf://your/own/s3/file/path/sample.parquet?PROFILE=s3:parquet&SERVER=s3')
FORMAT 'CSV';

CREATE EXTERNAL TABLE s3_parquet_with_select (LIKE lineitem)
LOCATION ('pxf://your/own/s3/file/path/sample.parquet?PROFILE=s3:parquet&SERVER=s3&S3_SELECT=ON')
FORMAT 'CSV';
```

Finally we use the following SQL string to query against these external tables:
```SQL
\timing
SELECT l_orderkey, l_partkey, l_linenumber FROM s3_parquet_no_select WHERE l_orderkey = 3 and l_partkey = 42970;
SELECT l_orderkey, l_partkey, l_linenumber FROM s3_parquet_with_select WHERE l_orderkey = 3 and l_partkey = 42970;
...
```

It is worth noting that, for queries without S3 Select, the time spent for these files of different sizes are quite consistent. While the queries with S3 Select enabled can have a relatively slower performance for the first time (comparing itself on the same query running at a later time). The same query gets constantly faster after the first time. This is due to the caching from the S3 store side.

The benchmarking took place on a GPDB cluster with 16 segment nodes on the cloud. Therefore, the performance may vary comparing to your deployment. It will be affected by many factors such as different simple SQL queries, network speed, bandwidth, and GPDB's cluster configuration (like how many segment nodes been deployed and so on).

For example, although the following query is against an external table with S3 Select enabled, due to the lack of predicates, column projection, and/or the [LIMIT clause](https://docs.aws.amazon.com/AmazonS3/latest/dev/s3-glacier-select-sql-reference-select.html), S3 will still return the data of the whole file to GPDB.

```SQL
SELECT * FROM s3_parquet_with_select;
```

For smaller files ranging from 10MB to 5GB, S3 Select under our benchmark setting did not show significant improvement of query speed as multiple segment nodes helped queries without S3 Select load faster in parallel. Queries showed better performance with S3 Select enabled starting from file size around 50GB. 

## **Conclusion**
The query speed improved depending on the size of the object file stored on S3. The larger the file size, the more drastic improvement in query speed will occur with the SQL queries structured properly (with column projection and/or filters) and with S3 Select enabled. Even though the improvement of performance is not obvious with smaller sized files on S3, it is still worth having S3 Select in effect whenever a SQL query is deemed as beneficial by PXF, because the amount of data transmitted between S3 stores and GPDB is also reduced.

---

#### **References**
1. https://gpdb.docs.pivotal.io/latest/admin_guide/intro/arch_overview.html
2. https://gpdb.docs.pivotal.io/latest/admin_guide/load/topics/g-loading-and-unloading-data.html
3. https://gpdb.docs.pivotal.io/latest/pxf/intro_pxf.html
4. https://gpdb.docs.pivotal.io/latest/admin_guide/external/pxf-overview.html
5. https://aws.amazon.com/about-aws/whats-new/2018/04/amazon-s3-select-is-now-generally-available/
6. https://aws.amazon.com/blogs/aws/s3-glacier-select/
