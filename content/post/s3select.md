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
date: 2019-09-03T18:00:00Z
draft: false
short: |
  Greenplum's Platform Extension Framework (PXF) supports querying data on AWS S3. PXF now supports AWS S3 Select which will enable Greenplum users to run their queries on data stored in AWS S3 more efficiently with up to 4x performance improvements.
title: Fast Access to Your S3 Data with Greenplum PXF
---

In this article, we introduce the PXF feature that utilizes **[S3 Select](https://aws.amazon.com/blogs/aws/s3-glacier-select/)** for faster access to data on AWS S3. As an introduction to basic concepts, we first provide a brief introduction to the architecture of Greenplum Database (GPDB), user's data that is not managed inside Greenplum Database but rather maintained in a cloud data storage (like AWS S3), an overview of the PXF (Greenplum Platform Extension Framework) and Amazon Simple Storage Service (Amazon S3). This is followed by a techical deep dive of our new PXF's S3 Select feature.

#### **Greenplum Database (GPDB)**
{{< responsive-figure src="/images/s3-select/fig1.png" class="center" >}}

Greenplum Database is a massively parallel processing (MPP) database server with an architecture (*Figure 1*) specially designed to manage large-scale analytic data warehouses and business intelligence workloads. It is based on PostgreSQL open-source technology, and therefore in most cases, very similar to PostgreSQL. Users can interact with Greenplum Database as they would with a PostgreSQL database[[1](https://gpdb.docs.pivotal.io/latest/admin_guide/intro/arch_overview.html)].

#### **External Data Not Managed By Greenplum Database**
Greenplum Database can read from and write to several types of external data sources, including text files, Hadoop file systems, Amazon S3, and web servers. This can be achieved by creating readable and writable external tables with the Greenplum Platform Extension Framework (PXF), and use these tables to query external data or to load data into, or offload data from, Greenplum Database[[2](https://gpdb.docs.pivotal.io/latest/admin_guide/load/topics/g-loading-and-unloading-data.html)].

#### **Greenplum's Platform Extension Framework (PXF)**
{{< responsive-figure src="/images/s3-select/fig2.png" class="center" >}}

The Greenplum Platform Extension Framework (PXF) provides connectors that enable you to access data stored in sources external to your Greenplum Database deployment (*Figure 2*). These connectors map an external data source to a Greenplum Database external table definition. You can query the external table via Greenplum Database, leaving the referenced data in place. Or, you can use the external table to load the data into Greenplum Database for higher performance[[3](https://gpdb.docs.pivotal.io/latest/pxf/intro_pxf.html)].

Currently, PXF is installed with JDBC, Hadoop, Hive, HBase, and Object Store connectors. These connectors enable you to read external data stored in text, Avro, JSON, RCFile, Parquet, SequenceFile, and ORC formats. You can use the JDBC connector to access an external SQL database[[4](https://gpdb.docs.pivotal.io/latest/admin_guide/external/pxf-overview.html)].

#### **Amazon Simple Storage Service (Amazon S3)**
{{< responsive-figure src="/images/s3-select/fig3.png" class="center" >}}

[Amazon Simple Storage Service (Amazon S3)](https://aws.amazon.com/s3/) is an object storage service and one of the building blocks of AWS infrastructure. It provides web services interface that allows its customers to store and retrieve any amount of data.

**S3 Select**: It is an S3 feature designed to increase query performance by up to 400%, and reduce querying costs as much as 80% [as Amazon claims](https://aws.amazon.com/blogs/aws/s3-glacier-select/). It works by retrieving a subset of an object’s data (using simple SQL expressions) instead of the entire object (*Figure 3*), which can be up to 5 terabytes in size. PXF implements support for S3 Select so that users can utilize the benefit of this feature from within Greenplum Database.

## **Motivation**
{{< responsive-figure src="/images/s3-select/fig4.png" class="center" >}}
*Figure 4*, shows how queries and data flows via PXF when we do not use our proposed PXF with S3 Select. To motivate our discussion, we use a query on customer data stored on S3 and filters them on age. Without the support of S3 Select by PXF, all the data from S3 has to be fetched from AWS to Greenplum to be then processed. This naive approach is resource-intensive, requiring significantly more CPU time for GPDB to filter unwanted results and greater network bandwidth to fetch the entire data set (only to be later discarded by the filter).

{{< responsive-figure src="/images/s3-select/fig5.png" class="center" >}}
*Figure 5*, shows the workflow of PXF with S3 Select enabled. In the proposed approach the data filtering process is done on AWS S3's side and the amount of data need to be transmitted through network is vastly reduced for this use case. In addition, this approach helps save the computational usage on the Greenplum's side. It is important to note that the resource utilisational savings is directly proportional to the size of the stored data as well as the selectivity of the filtering dimensions. It is a common use case in the cloud database management systems queries (like data mining, transactional, analytical and ad-hoc queries) are only interested in a small portion of the vast amounts of data stored. This makes PXF with S3 Select crucial for building a scalable solution for quering data lakes.

---

## **Performance Comparison**
{{< responsive-figure src="/images/s3-select/fig6.png" class="center" >}}

The graph in *Figure 6* indicates the results of queries made against Amazon S3 object store with and without S3 Select feature in effect, for multiple file sizes. The time consumed to complete query against each file is the average of results from running the same query multiple times. 

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
(Note the `PROFILE=s3:parquet` clause indicating that PXF will read the file on S3 as Parquet format. Currently, PXF supports CSV and Parquet format of the object files stored on Amazon S3. It may support other formats such as JSON in the future.)

Finally we use the following SQL string to query against these external tables:
```SQL
\timing
SELECT l_orderkey, l_partkey, l_linenumber FROM s3_parquet_no_select WHERE l_orderkey = 3 and l_partkey = 42970;
SELECT l_orderkey, l_partkey, l_linenumber FROM s3_parquet_with_select WHERE l_orderkey = 3 and l_partkey = 42970;
...
```

It is worth noting that, for queries without S3 Select, the time spent for these files of different sizes are quite consistent. While the queries with S3 Select enabled can have a relatively slower performance for the first time (comparing itself on the same query running at a later time). The same query gets constantly faster after the first time. This is due to the caching from the S3 store side.

The benchmarking took place on a Greenplum Database cluster with 16 segment nodes running on the Google Cloud Platform as well as against an Amazon S3 storage within the same geological region. Therefore, the performance may vary comparing to your deployment. It will be affected by many factors such as different simple SQL queries, network speed, bandwidth, and Greenplum Database's cluster configuration (number of segment nodes deployed and so on).

For smaller files ranging from 10MB to 5GB, S3 Select under our benchmark setting did not show significant improvement of query speed as multiple segment nodes helped queries without S3 Select load faster in parallel. Queries showed better performance with S3 Select enabled starting from file size around 50GB. 

It is also worth noting that, S3 Select is not free. There is cost incurred by using S3 Select for data scanning and returning from Amazon S3. The cost per GB varies depending on which region your storage is deployed to. Nonetheless, it could still be cheaper when your queries are looking for a small subset of data from S3, comparing to transmitting the whole file back from S3 through network.


## **Conclusion**
The query speed improved depending on the size of the object file stored on S3. The larger the file size, the more drastic improvement in query speed will occur with the SQL queries structured properly (with column projection and/or filters) and with S3 Select enabled. Even though the improvement of performance is not obvious with smaller sized files on S3, it is still worth having S3 Select in effect whenever a SQL query is deemed as beneficial by PXF, because the amount of data transmitted between S3 stores and Greenplum Database is also reduced.


---
## **Example Walkthough**
For those who are interested in setting up , there are some components required to set up in order to try out S3 Select with PXF and Greenplum Database.
### **Prerequisite**
- **Setting up an S3 Bucket**: Instead of setting up an Amazon S3 bucket as external object store, [Minio](https://min.io/product), an open-sourced project with similar features and APIs is also available for on-premise deployment.
  - For using Amazon S3: [signing up](https://docs.aws.amazon.com/AmazonS3/latest/gsg/SigningUpforS3.html) and [creating bucket](https://docs.aws.amazon.com/AmazonS3/latest/gsg/CreatingABucket.html)
  - For using Minio: [quick start](https://docs.min.io/docs/minio-quickstart-guide.html) and [more specific guide for Greenplum Database and Minio](http://engineering.pivotal.io/post/gpdb_accessing_minio/)
- **Installing Greenplum Database**: [Installation guide](https://gpdb.docs.pivotal.io/latest/install_guide/install_guide.html) or [building Greenplum Database from source](https://github.com/greenplum-db/gpdb#building-gpdb-with-pxf)
- **Configuring PXF for S3 Bucket**: [Introduction](https://gpdb.docs.pivotal.io/5210/pxf/overview_pxf.html) and [configuration guide](https://gpdb.docs.pivotal.io/5210/pxf/access_objstore.html)


Once Greenplum Database and PXF are properly configured and running, users can run the Greenplum Database shell command line by typing (more [guide](http://postgresguide.com/utilities/psql.html) on psql command): 
```terminal
> psql
```
Now in the Greenplum Database psql command line shell, users can create an external table to access files in an S3 object store by providing options to identify the S3 objects and credentials, and enable PXF to use S3 Select. Here is an example of creating an external table: 
```SQL
CREATE EXTERNAL TABLE orders_from_s3 (id int, name text)
LOCATION ('pxf://bucket-name/path/in/s3/?PROFILE=s3:parquet&S3_SELECT=ON&SERVER=s3')
FORMAT 'CSV';
```
In above SQL string,

- `CREATE EXTERNAL TABLE orders_from_s3` tells Greenplum Database to create an external table named `orders_from_s3`
- `(id int, name text)` is the schema of this table
- `LOCATION ('pxf://bucket-name/path/in/s3/?PROFILE=s3:parquet&S3_SELECT=ON&SERVER=s3')` provides information to Greenplum Database such as:
  - the protocol `pxf`, 
  - path of the file object on S3 `bucket-name/path/in/s3/`, 
  - options that PXF needs to process the queries to S3 `?PROFILE=s3:parquet&S3_SELECT=ON&SERVER=s3`. 

Note: here `S3_SELECT=ON` is the option to enable the S3 Select feature through PXF. Click [here](https://gpdb.docs.pivotal.io/latest/pxf/objstore_text.html#profile_text) for more detail on creating external table to read data in an object store. 

Now you can make simple SQL queries to your S3 object store and test out S3 Select. For example:
```sql
SELECT id, name, FROM orders_from_s3 WHERE id = 3;
```
Here `WHERE id = 3` is the filter clause that PXF will recognize and pass to S3 to utilize S3 Select.

On the other hand, queries like this:
```sql
SELECT * FROM orders_from_s3;
```
Even when PXF S3 Select is enabled, queries like this that select all of the data won't utilize the optimization. All the data will be returned from the object file on S3.

---

#### **Acknowledgement**
I'd like to express my appreciation to Francisco Guerrero, Oliver Albertini, Venkatesh Raghavan, Divya Bhargov, Kong Chan, Lisa Owen and Alexander Denissov for their valuable input, help and time spent on this, especially Venkatesh for pairing with me to make it better. Thanks to the Unmanaged Data team for letting me work on this blog. Also thank you for your time reading this.

#### **References**
1. https://gpdb.docs.pivotal.io/latest/admin_guide/intro/arch_overview.html
2. https://gpdb.docs.pivotal.io/latest/admin_guide/load/topics/g-loading-and-unloading-data.html
3. https://gpdb.docs.pivotal.io/latest/pxf/intro_pxf.html
4. https://gpdb.docs.pivotal.io/latest/admin_guide/external/pxf-overview.html
5. https://aws.amazon.com/about-aws/whats-new/2018/04/amazon-s3-select-is-now-generally-available/
6. https://aws.amazon.com/blogs/aws/s3-glacier-select/
