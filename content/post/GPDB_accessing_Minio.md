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
- Databases
date: 2018-03-07T17:16:22Z
draft: true
short: |
  Using Greenplum to read and write Minio, high performance distributed object storage server
title: Using Greenplum to access Minio, high performance distributed object storage server

---
Pivotal Greenplum Database® is an advanced, fully featured, open source data warehouse. It provides powerful and rapid analytics on petabyte scale data volumes.

Minio is a high performance distributed object storage server, designed for
large-scale private cloud infrastructure.


## Use cases:
Storing warm or cold data in Mimio, object database

Sharing data with external systems



### How to configure MINIO
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
You can configure GPDB to access external tables such as Minio, S3 and any S3 compatible object storage.

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




### Conclusion

TBD
