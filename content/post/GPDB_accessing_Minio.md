---
authors:
- Kong-Yew, Chan
- user
categories:
- Greenplum
- PostgreSQL
- Greenplum Database
- Minio
- Docker
date: 2018-03-07T17:16:22Z
draft: true
short: |
  Using Greenplum to access Minio, high performance distributed object storage server
title: Using Greenplum to access Minio, high performance distributed object storage server

---
Pivotal Greenplum Database® (GPDB) is an advanced, fully featured, open source data warehouse. GPDB provides powerful and rapid analytics on petabyte scale data volumes. It provides S3 extension to access Amazon Simple Storage Service, a secure, durable, highly-scalable object storage.

Minio is a high performance distributed object storage server, designed for
large-scale private cloud infrastructure. Since Minio supports S3 protocol, GPDB can also access Minio server that is deployed on-premise or cloud.

One of the advantages of using Minio is pluggable storage backend that supports DAS, JBODs, external storage backends such as NAS, Google Cloud Storage and as well as Azure Blob Storage.

In this post, you can quickly learn how to use Greenplum to access Minio.  

## Use cases:
**Storing cold data:**
Enterprises are leveraging external storages to store cold data such as sales data, customer data with transaction dates more than 2 years ago. Those data can be effectively stored on external storage such as Minio, distributed object storage. Whenever Greenplum customers want to analyze those cold data, customers can use S3 extension to dynamically load those data from Minio.

**Sharing data with external systems**

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

[Minio client](https://minio.io/downloads.html#download-client)(mc) provides a modern alternative to UNIX commands like ls, cat, cp, mirror, diff, find etc. It supports filesystems and Amazon S3 compatible cloud storage service (AWS Signature v2 and v4).

You can use mc to create testbucket and copies examples such as stocks.csv, testdata.csv to this testbucket.

```
/usr/bin/mc config host add minio http://minio1:9001 minio minio123;
/usr/bin/mc mb minio/testbucket;
/usr/bin/mc cp /data/S3Examples/stocks.csv minio/testbucket;
/usr/bin/mc cp /data/S3Examples/testdata.csv minio/testbucket;
/usr/bin/mc cp /data/S3Examples/read_stocks.sql minio/testbucket;
/usr/bin/mc policy download minio/testbucket;"
```



### How to configure GPDB
You can configure GPDB to access external tables such as Minio, S3 and any S3 compatible object storage such as [Dell EMC Elastic Cloud Storage](https://www.dellemc.com/en-us/storage/ecs/index.htm) (ECS).

1. Configure S3 feature by creating configuration file (s3.conf). The example below is configured to access Minio service with S3 API version 2
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

2. Configure your database to enable S3 protocol and external tables.

```
CREATE OR REPLACE FUNCTION write_to_s3() RETURNS integer AS
   '$libdir/gps3ext.so', 's3_export' LANGUAGE C STABLE;
   CREATE OR REPLACE FUNCTION read_from_s3() RETURNS integer AS
      '$libdir/gps3ext.so', 's3_import' LANGUAGE C STABLE;
CREATE PROTOCOL s3 (writefunc = write_to_s3, readfunc = read_from_s3);

```
### How to use GPDB to access Minio
1. Use psql to create external table

```
CREATE EXTERNAL TABLE stock_fact_external (
stock text,
stock_date text,
price text
)
LOCATION('s3://minio1:9000/testbucket/stocks.csv config=/home/gpadmin/s3.conf')
FORMAT 'TEXT'(DELIMITER=',');
```
2. Use sql query to retrieve data from Minio.


```
-- query external s3 table
select count(*) from stock_fact_external;
```


-- https://discuss.pivotal.io/hc/en-us/articles/235063748-Troubleshooting-Guide-Configuring-Amazon-S3-with-Greenplum
drop external table stock_fact_external;



### Conclusion
This post helps you to use Greenplum with Minio. The [github repository](https://github.com/kongc-organization/greenplum-minio) demonstrates how to  setup and configure GPDB, in order to access Minio.

TBD
