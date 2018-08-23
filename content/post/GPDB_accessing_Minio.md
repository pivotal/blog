---
authors:
- Kong-Yew, Chan
- user
categories:
- Greenplum
- Minio

date: 2018-03-07T17:16:22Z
draft: true
short: |
  Parallel data transfer data between Greenplum and Minio
title: Using Greenplum to access Minio, distributed object storage server

---
Pivotal Greenplum Database® (GPDB) is an advanced, fully featured, open source data warehouse. GPDB provides powerful and rapid analytics on petabyte scale data volumes. It provides S3 extension to access Amazon Simple Storage Service, a secure, durable, highly-scalable object storage.

Minio is a high performance distributed object storage server, designed for
large-scale private cloud infrastructure. Since Minio supports S3 protocol, GPDB can also access Minio server that is deployed on-premise or cloud. One of the advantages of using Minio is pluggable storage backend that supports DAS, JBODs, external storage backends such as NAS, Google Cloud Storage and as well as Azure Blob Storage.

In this post, you will learn to setup Greenplum with Minio in 10 minutes.  

## Use cases:
**Storing cold data:**

Enterprises are leveraging external storages to store cold data such as sales data, customer data with transaction dates more than 1 year ago. Those data can be effectively stored on external storage such as Minio, distributed object storage. Whenever Greenplum customers want to analyze those cold data, customers can use S3 extension to dynamically load those data from Minio.
Since Minio provides virtual storage for Kubernetes, local drive, NAS, Azure, GCP, Cloud Foundry and DC/OS, this use cases enable import / export operations to those virtual storages.

**Sharing data with external systems**

Typically, enterprises have needs to share data with multiple RDBMS and systems across the organization. One of the data sharing patterns is to store the data in an distributed object storage system such as Minio.  Greenplum users  export existing data into Minio so other applications can access the shared data from Minio.



### How to setup and configure MINIO
In this post, we will use docker to download and setup Minio image on your local machine.
For example, you can start using Minio image by typing the command below in your terminal.

```
$ docker run -p 9000:9000 -v /mnt/data:/data -v /mnt/config:/root/.minio minio/minio server /data
Drive Capacity: 300 GiB Free, 465 GiB Total

Endpoint:  http://172.17.0.2:9000  http://127.0.0.1:9000
AccessKey: QVF3THG805XZ5TIJBPMU
SecretKey: FsKEMRdpOhDaSilcjPpE2QaAnbJzNcS9ijH9z9U3

Browser Access:
   http://172.17.0.2:9000  http://127.0.0.1:9000

Command-line Access: https://docs.minio.io/docs/minio-client-quickstart-guide
   $ mc config host add myminio http://172.17.0.2:9000 QVF3THG805XZ5TIJBPMU FsKEMRdpOhDaSilcjPpE2QaAnbJzNcS9ijH9z9U3

Object API (Amazon S3 compatible):
   Go:         https://docs.minio.io/docs/golang-client-quickstart-guide
   Java:       https://docs.minio.io/docs/java-client-quickstart-guide
   Python:     https://docs.minio.io/docs/python-client-quickstart-guide
   JavaScript: https://docs.minio.io/docs/javascript-client-quickstart-guide
   .NET:       https://docs.minio.io/docs/dotnet-client-quickstart-guide
```

### How to configure GPDB
You can configure GPDB to access external tables such as Minio, S3 and any S3 compatible object storage including [Dell EMC Elastic Cloud Storage](https://www.dellemc.com/en-us/storage/ecs/index.htm)(ECS).

1.Create S3 configuration file (s3.conf). The example below is configured to access Minio service with S3 API version 2.
```
cat <<EOF > /home/gpadmin/s3.conf
[default]
secret = "minio123"
accessid = "minio"
threadnum = 4
chunksize = 67108864
low_speed_limit = 10240
low_speed_time = 60
encryption = false
# true
version = 2
proxy = ""
autocompress = true
verifycert = false
# true
server_side_encryption = ""
# gpcheckcloud config
gpcheckcloud_newline = "\n"
EOF
```
2. Verify the S3.conf is working by using gpcloudcheck.

```
$ gpcheckcloud -c "s3://minio1:9000/testbucket/ config=/home/gpadmin/s3.conf"
File: read_stocks.sql, Size: 1759
File: stocks.csv, Size: 12246
File: testdata.csv, Size: 138
```
3. Next, you can enable S3 Protocol on gpdb

Use psql on the Greenplum docker instance.
```
docker exec -it gpdbminio bash
 root@gpdb-minio:/#
root@gpdb-minio:/code/minio/S3Examples# psql -h localhost -U gpadmin gpadmin
psql (9.5.12, server 8.3.23)
Type "help" for help.
gpadmin=#
```

4. Type these commands to create read and write function for S3
`CREATE OR REPLACE FUNCTION read_from_s3() RETURNS integer AS'$libdir/gps3ext.so','s3_import' LANGUAGE C STABLE;`

`CREATE OR REPLACE FUNCTION write_to_s3() RETURNS integer AS '$libdir/gps3ext.so', 's3_export' LANGUAGE C STABLE;`

`CREATE PROTOCOL s3 (writefunc = write_to_s3,readfunc = read_from_s3);`

For example:
```
psql (9.5.12, server 8.3.23)
Type "help" for help.

gpadmin=# CREATE OR REPLACE FUNCTION read_from_s3() RETURNS integer AS
gpadmin-#     '$libdir/gps3ext.so', 's3_import' LANGUAGE C STABLE;
CREATE FUNCTION
gpadmin=# -- Declare the S3 protocol and specify the function that is used
gpadmin=# -- to read from an S3 bucket
gpadmin=# CREATE PROTOCOL s3 (writefunc = write_to_s3,readfunc = read_from_s3);
ERROR:  protocol "s3" already exists
CREATE PROTOCOL
gpadmin=# CREATE OR REPLACE FUNCTION write_to_s3() RETURNS integer AS
gpadmin-# '$libdir/gps3ext.so', 's3_export'
gpadmin-# LANGUAGE C STABLE;
CREATE FUNCTION
```

5.Use psql to create external table that uses S3 location.
```
CREATE EXTERNAL TABLE stock_fact_external (
stock text,
stock_date text,
price text
)
LOCATION('s3://minio1:9000/testbucket/stocks.csv config=/home/gpadmin/s3.conf')
FORMAT 'TEXT'(DELIMITER=',');
```
4.Use sql query to retrieve data from Minio. This query returns the resultset from Minio servers that are preloaded with sample files under `testbucket`.

```
gpadmin=# select count(*) from stock_fact_external;
 count
-------
   561
(1 row)
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
This post provides examples how to configure Greenplum to access Minio. For more details, please read this example on this [github repository](https://github.com/kongc-organization/greenplum-minio).  

In summary, you can use Minio, distributed object storage to dynamically scale your Greenplum clusters.
