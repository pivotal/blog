---
authors:
- Kong-Yew, Chan
- Francisco, Guerrero
- user
categories:
- Greenplum
- Minio

date: 2019-02-25T12:30:00Z
draft: false
short: |
  Parallel data transfer data between Greenplum and Minio
title: Using Greenplum to access Minio distributed object storage server

---
Pivotal Greenplum Database® (GPDB) is an advanced, fully featured, open source data warehouse. GPDB provides powerful and rapid analytics on petabyte scale data volumes. Greenplum 5.17.0 brings support to [access highly-scalable cloud object storage systems](https://gpdb.docs.pivotal.io/latest/pxf/access_objstore.html) such as Amazon S3, Azure Data Lake, Azure Blob Storage, and Google Cloud Storage.

Minio is a high performance distributed object storage server, designed for
large-scale private cloud infrastructure. Since Minio supports S3 protocol, GPDB can also access Minio server that is deployed on-premise or cloud. One of the advantages of using Minio is pluggable storage backend that supports DAS, JBODs, external storage backends such as NAS, Google Cloud Storage and as well as Azure Blob Storage.

In this post, you will learn to setup Greenplum with Minio in 10 minutes.  

## Use cases:
### Storing cold data

Enterprises are leveraging external storage systems to store cold data such as
historical sales data, old transaction data, and so on.  Data that can be effectively
stored on external storage systems such as Minio distributed object storage.
Whenever Greenplum customers want to run analytics workloads on such datasets,
customers can leverage PXF to dynamically load data from Minio into their Greenplum cluster.
Since Minio provides virtual storage for Kubernetes, local drive, NAS, Azure, GCP,
Cloud Foundry and DC/OS, this use cases enable import / export operations to those
virtual storage systems.

### Sharing data with external systems

Typically, enterprises have needs to share data with multiple RDBMS and systems across the organization. One of the data sharing patterns is to store the data in an distributed object storage system such as Minio.  Greenplum users export existing data into Minio so other applications can access the shared data from Minio.


## How to configure Minio in Greenplum
You can configure GPDB to access external tables such as [Minio](https://docs.pivotal.io/partners/minio-greenplum/index.html), S3 and any S3 compatible object storage including [Dell EMC Elastic Cloud Storage](https://www.dellemc.com/en-us/storage/ecs/index.htm)(ECS).

1. Login as gpadmin
   ```bash
   $ su - gpadmin
   ```
2. Create a PXF Server
   ```bash
   $ mkdir -p $PXF_CONF/servers/minio 
   ```
   *Note: A PXF server configuration inside `$PXF_CONF/servers` is analogous to
   [Foreign Data Wrapper Servers](https://www.postgresql.org/docs/9.4/postgres-fdw.html)
   where each server represents a distinct remote system you want to connect to.
3. Copy the provided minio template into the server
   ```bash
   $ cp $PXF_CONF/templates/minio-site.xml $PXF_CONF/servers/minio
   ```
   ```bash
   $ cat $PXF_CONF/servers/minio/minio-site.xml
   <?xml version="1.0" encoding="UTF-8"?>
   <configuration>
       <property>
           <name>fs.s3a.endpoint</name>
           <value>YOUR_MINIO_URL</value>
       </property>
       <property>
           <name>fs.s3a.access.key</name>
           <value>YOUR_AWS_ACCESS_KEY_ID</value>
       </property>
       <property>
           <name>fs.s3a.secret.key</name>
           <value>YOUR_AWS_SECRET_ACCESS_KEY</value>
       </property>
       <property>
           <name>fs.s3a.fast.upload</name>
           <value>true</value>
       </property>
       <property>
           <name>fs.s3a.path.style.access</name>
           <value>true</value>
       </property>
   </configuration>
   ```
4. Configure **`YOUR_MINIO_URL`**, **`YOUR_AWS_ACCESS_KEY_ID`**,
and **`YOUR_AWS_SECRET_ACCESS_KEY`** properties in `$PXF_CONF/servers/minio/minio-site.xml`
   ```bash
   $ sed -i "s|YOUR_MINIO_URL|http://minio1:9000|" $PXF_CONF/servers/minio/minio-site.xml
   $ sed -i "s|YOUR_AWS_ACCESS_KEY_ID|minio|" $PXF_CONF/servers/minio/minio-site.xml 
   $ sed -i "s|YOUR_AWS_SECRET_ACCESS_KEY|minio123|" $PXF_CONF/servers/minio/minio-site.xml
   ```
5. Use psql to create external table that uses the `minio` server to access the `stocks.csv` text file
   in our minio `testbucket`.
   ```sql
   CREATE EXTERNAL TABLE stock_fact_external (
   stock text,
   stock_date text,
   price text
   )
   LOCATION('pxf://testbucket/stocks.csv?PROFILE=s3:text&SERVER=minio')
   FORMAT 'TEXT';
   ```
6. Use sql query to retrieve data from Minio. This query returns the resultset from Minio servers that are preloaded with sample files under `testbucket`.
   ```sql
   gpadmin=# select count(*) from stock_fact_external;
    count
   -------
      561
   (1 row)
   ```
   ```sql
   gpadmin=# select * from stock_fact_external limit 10;
    stock  | stock_date | price
   --------+------------+-------
    symbol | date       | price
    MSFT   | Jan 1 2000 | 39.81
    MSFT   | Feb 1 2000 | 36.35
    MSFT   | Mar 1 2000 | 43.22
    MSFT   | Apr 1 2000 | 28.37
    MSFT   | May 1 2000 | 25.45
    MSFT   | Jun 1 2000 | 32.54
    MSFT   | Jul 1 2000 | 28.4
    MSFT   | Aug 1 2000 | 28.4
    MSFT   | Sep 1 2000 | 24.53
   (10 rows)
   ```
--



### Conclusion
This post describes how to configure Greenplum to access Minio. For more details, please read this example on this [github repository](https://github.com/kongyew/greenplum-pxf-examples/tree/master/usecase8). For more information about PXF, please read this [page](https://gpdb.docs.pivotal.io/latest/pxf/objstore_cfg.html)

In summary, you can use Minio, distributed object storage to dynamically scale your Greenplum clusters.
