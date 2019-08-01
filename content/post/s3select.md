---
authors:
- xiwei
categories:
- Greenplum
- PXF
- S3
- S3 Select
- AWS 
date: 2019-07-17T09:00:00Z
draft: true
short: |
  With support of S3 Select from PXF, Greenplum users can now make highly efficient queries to external S3 data source at potentially cheaper cost.
title: How PXF helps Greenplum users to make highly efficient queries with S3 Select
---

## Overview
TODO: 
1) wording makes it seem like s3-select is a PXF feature. it is, but we should first define what s3 select is (an amazon feature) that users can now utilize with PXF (mention support CSV and Parquet, maybe future for JSON)
2) I think we can beef up the background a bit more with explanation about GPDB (MPP database based on Postgres) that uses an external table feature

With support of S3 Select by PXF, users can make more efficient queries against S3 object stores with simple SQL expressions from Greenplum. When enabled, PXF utilizes S3 Select to do query predicate and column projection pushdown to S3. This helps users to retrieve only a subset of data from an object with simple SQL expressions rather than having the entire data object transmitted to Greenplum via PXF, and then letting Greenplum to filter data and return it to the users. Therefore with S3 Select, the cost of making query can be largely reduced and the efficiency increased significantly.

{{< responsive-figure src="/images/s3-select/s3-select.png" class="center" >}}

TODO: let's talk a bit more about what PXF is

## Preparation
### Setting up S3 Bucket
- Using AWS S3
https://docs.aws.amazon.com/AmazonS3/latest/gsg/SigningUpforS3.html
https://docs.aws.amazon.com/AmazonS3/latest/gsg/CreatingABucket.html
- Using Minio: https://min.io/product

TODO: explaining what the DDL is :https://gpdb.docs.pivotal.io/6-0Beta/pxf/objstore_text.html#write_s3textsimple_example

### Configuring PXF for S3 Bucket
- https://gpdb.docs.pivotal.io/latest/pxf/access_objstore.html


After setting up their own S3 object storages, users can setup [GPDB (Greenplum Database)](https://gpdb.docs.pivotal.io/5200/install_guide/install_guide.html) and [configure PXF](https://gpdb.docs.pivotal.io/6-0Beta/pxf/objstore_cfg.html).

With GPDB and PXF running, in the database CLI, users can create external tables and specify the option to enable S3 Select when preparing to query their S3 data sources. The SQL query strings they entered through Greenplum will be processed by PXF to determine whether the query can be optimized by S3 Select.

TODO: explain URL query parameters
Here is an example for creating an external table under command shell ([psql](http://postgresguide.com/utilities/psql.html)):
```SQL
CREATE EXTERNAL TABLE orders_from_s3 (id int, name text)
LOCATION ('pxf://bucket-name/path/in/s3/?PROFILE=s3:parquet&s3-select=ON&SERVER=s3')
FORMAT 'CSV';
```

## Performance Comparison
The following output is the result of querying against S3 data object storage for a file of 10 GB. The first query is to the external table with S3 Select ON, and the second one is to another table with S3 Select OFF. Both table are pointing to the same file in the same S3 storage bucket:

TODO: explain URL query parameters
```console
pxfautomation=# \timing               Timing is on.
pxfautomation=# select l_orderkey, l_partkey, l_linenumber from lineitem_s3_select_10g where l_orderkey =3 and l_partkey = 42970;
 l_orderkey | l_partkey | l_linenumber
------------+-----------+--------------
          3 |     42970 |            1
(1 row)

Time: 60862.229 ms
pxfautomation=# select l_orderkey, l_partkey, l_linenumber from lineitem_s3_10g where l_orderkey =3 and l_partkey = 42970;
 l_orderkey | l_partkey | l_linenumber
------------+-----------+--------------
          3 |     42970 |            1
(1 row)

Time: 1636251.519 ms
pxfautomation=#
```

{{< responsive-figure src="/images/s3-select/S3-Select-diagram.jpg" class="center" >}}



---
### Acknowledgement
(to be completed)

### References
https://aws.amazon.com/about-aws/whats-new/2018/04/amazon-s3-select-is-now-generally-available/

https://aws.amazon.com/blogs/aws/s3-glacier-select/
