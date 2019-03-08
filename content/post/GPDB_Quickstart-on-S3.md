---
authors:
- frankgh
- kochan
- user
categories:
- Greenplum
- S3
- PXF
- Query Federation

date: 2019-03-08T12:30:00Z
draft: true
short: |
  Federated queries to AWS S3 from Greenplum
title: Quickstart on how to federate queries to AWS S3 from Greenplum 

---
Pivotal Greenplum Database® (GPDB) is an advanced, fully featured, open source data warehouse. GPDB provides powerful and rapid analytics on petabyte scale data volumes.
Greenplum 5.17.0 brings support to [access highly-scalable cloud object storage systems](https://gpdb.docs.pivotal.io/latest/pxf/access_objstore.html) such as Amazon S3, Azure Data Lake, Azure Blob Storage, and Google Cloud Storage.

[Amazon Simple Storage Service (Amazon S3)](https://aws.amazon.com/s3/) is the largest and most performant, secure, and feature-rich object storage service. With Amazon S3, organizations of all sizes and industries can store any amount of data for any use case, including applications, IoT, data lakes, analytics, backup and restore, archive, and disaster recovery.

In this post, you will learn to setup Greenplum and access the AMEX, NYSE, and NASDAQ stocks histories dataset from S3.

## Use cases
More and more we are seeing enterprise customers storing data in cloud object storage systems such as S3, Azure and Google Cloud. Cloud providers offer cheap storage with guarantees for durability, errors, and security. These factors make it compelling for companies to store historical data in cloud providers. 

### Storing cold data


### Sharing data with external systems


## Prepare data on S3

1. Login to your AWS Account

        https://aws.amazon.com/s3/

2. Create a new bucket or use an existing bucket

3. Download the AMEX, NYSE, and NASDAQ stocks histories dataset from Kaggle

        https://www.kaggle.com/qks1lver/amex-nyse-nasdaq-stock-histories
    *Note: For this example we are going to use the 60 day history CSV.

4. Upload the `history_60d.csv` file to your AWS bucket

5. Obtain your Access Keys (Access Key ID and Secret Access Key)

        https://docs.aws.amazon.com/general/latest/gr/aws-sec-cred-types.html#access-keys-and-secret-access-keys

## Create S3 Configuration on Greenplum

1. Login as `gpadmin`.

        $ su - gpadmin

2. Create a PXF Server Configuration.

        $ mkdir -p $PXF_CONF/servers/s3_stock_history
    *Note: A PXF server configuration in `$PXF_CONF/servers` is analogous to [Foreign Data Wrapper Servers](https://www.postgresql.org/docs/9.4/postgres-fdw.html) where each server represents a distinct remote system you want to connect to.

3. Copy the provided S3 template into the server directory.

        $ cp $PXF_CONF/templates/s3-site.xml $PXF_CONF/servers/s3_stock_history
        $ cat $PXF_CONF/servers/s3_stock_history/s3-site.xml
        <?xml version="1.0" encoding="UTF-8"?>
        <configuration>
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
        </configuration>

4. Configure **`YOUR_AWS_ACCESS_KEY_ID`**, and **`YOUR_AWS_SECRET_ACCESS_KEY`** properties in `$PXF_CONF/servers/s3_stock_history/s3-site.xml` with your AWS Access and Secret Key.

5. Use psql to create external table that uses the `s3_stock_history` server to access the `history_60d.csv` dataset in your AWS bucket.

        CREATE EXTERNAL TABLE stock_fact_external (
          date date,
          symbol text,
          volume int,
          open decimal,
          close decimal,
          high decimal,
          low decimal,
          adjclose decimal)
        LOCATION('pxf://my-s3-bucket/history_60d.csv?PROFILE=s3:text&SERVER=s3_stock_history')
        FORMAT 'CSV' (HEADER);

6. Use SQL query to retrieve data from S3. I have enabled `\timing`, which will measure the time to execute the query.

        gpadmin=# select count(*) from stock_fact_external;
         count
        --------
         324714
        (1 row)

        Time: 4443.171 ms

        gpadmin=# select * from stock_fact_external limit 10;
            date    | symbol | volume  |       open        |       close       |       high        |        low        |     adjclose
        ------------+--------+---------+-------------------+-------------------+-------------------+-------------------+-------------------
         2019-03-01 | A      | 1625900 |              80.0 | 81.23999786376953 | 81.44000244140625 |              80.0 | 81.23999786376953
         2019-02-28 | A      | 1759100 | 79.18000030517578 | 79.44000244140625 |             79.75 | 78.88999938964844 | 79.44000244140625
         2019-02-27 | A      | 1254400 |             78.25 | 79.41999816894531 | 79.55000305175781 |             78.25 | 79.41999816894531
         2019-02-26 | A      | 1992600 | 79.20999908447266 | 78.55000305175781 |  79.2699966430664 | 78.41999816894531 | 78.55000305175781
         2019-02-25 | A      | 1878000 |  78.9000015258789 | 79.33999633789062 | 79.83999633789062 |  78.8499984741211 | 79.33999633789062
         2019-02-22 | A      | 2797700 | 78.16000366210938 | 78.41999816894531 | 78.45999908447266 | 77.83000183105469 | 78.41999816894531
         2019-02-21 | A      | 3570800 | 77.66999816894531 | 77.88999938964844 | 78.58000183105469 |              76.5 | 77.88999938964844
         2019-02-20 | A      | 2076500 | 77.52999877929688 | 78.55999755859375 | 78.80000305175781 | 77.33000183105469 | 78.55999755859375
         2019-02-19 | A      | 2968000 |              78.0 |  77.5199966430664 | 78.31999969482422 | 77.41000366210938 |  77.5199966430664
         2019-02-15 | A      | 1919700 | 77.62999725341797 | 78.30000305175781 | 78.30999755859375 | 77.47000122070312 | 78.30000305175781
        (10 rows)

        Time: 811.991 ms

        gpadmin=# select symbol, volume, date from stock_fact_external where symbol='GOOG' limit 10;
         symbol | volume  |    date
        --------+---------+------------
         GOOG   | 1449800 | 2019-03-01
         GOOG   | 1542500 | 2019-02-28
         GOOG   |  968400 | 2019-02-27
         GOOG   | 1471300 | 2019-02-26
         GOOG   | 1413100 | 2019-02-25
         GOOG   | 1049500 | 2019-02-22
         GOOG   | 1415100 | 2019-02-21
         GOOG   | 1087800 | 2019-02-20
         GOOG   | 1046400 | 2019-02-19
         GOOG   | 1449800 | 2019-02-15
        (10 rows)

        Time: 2368.517 ms


## Conclusion
This blog post demonstrates
