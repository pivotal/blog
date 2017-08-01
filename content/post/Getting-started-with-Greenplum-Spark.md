---
draft: false
categories: ["Greenplum", "Apache Spark", "JDBC", "Postgresql"]
authors:
- kochan
- gtadi
date: 2017-08-01T14:00:36.000Z
short: >
  Using Greenplum and Apache Spark via JDBC in 5 minutes

title: Greenplum and Apache Spark via JDBC
---
Pivotal Greenplum Database® is an advanced, fully featured, open source data warehouse. It provides powerful and rapid analytics on petabyte scale data volumes.

Apache Spark is a lightning-fast cluster computing framework that runs programs up to 100x faster than Hadoop MapReduce in-memory. Despite Apache Spark's general purpose data processing and growth in Spark adoption rate, Apache Spark is not a data store as it depends on external data store.

Greenplum users want to use Spark for running in-memory analytics and data pre-processing before loading the data into Greenplum.
Using Postgresql JDBC driver, we can load and unload data between Greenplum and Spark clusters.  

This article illustrates how:

- Apache Spark can perform read and write on Greenplum via JDBC and
- Faster data-transfers are achieved using Spark's built-in parallelism.

### Pre-requisites

- Greenplum is installed and running.
- At least one table is created and contain some data.

##  **Start spark-shell with Postgresql driver**
Execute the command below to download jar into  ~/.ivy2/jars directory

```bash
[root@master]> $SPARK_HOME/bin/spark-shell --packages org.postgresql:postgresql:42.1.1
.......
```
```
      ____              __
     / __/__  ___ _____/ /__
    _\ \/ _ \/ _ `/ __/  '_/
   /___/ .__/\_,_/_/ /_/\_\   version 2.1.1
      /_/

scala> Class.forName("org.postgresql.Driver")
res1: Class[_] = class org.postgresql.Driver
```

## **Read data from Greenplum**

Load data from a Greenplum table with a single data partition in Spark cluster

```scala
scala> val options = Map(
         "url" -> "jdbc:postgresql://localhost:5432/gpadmin", // JDBC url
         "user" -> "gpadmin",
         "password" -> "pivotal",
         "driver" -> "org.postgresql.Driver",// JDBC driver
         "dbtable" -> "greenplum_table") // Table name

scala> val df_read_final = spark.read.format("jdbc").options(options).load // Reads data as 1 partition
df_read_final: org.apache.spark.sql.DataFrame = [col_string: string, col_int: int]


scala> df_read_final.printSchema()
root
 |-- col_string: string (nullable = true)
 |-- col_int: integer (nullable = true)


scala> df_read_final.show() // By default prints 20 rows
+----------+-------+
|col_string|col_int|
+----------+-------+
|      aaaa|      1|
|      bbbb|      2|
+----------+-------+
```

## **Write data into Greenplum**
Spark DataFrame class provides four different write modes, when saving to Greenplum table

1.**"append"** - if data/table already exists, contents of the DataFrame are appended to existing data.

2.**"error"** - if data already exists, an exception is expected to be thrown.

3.**"ignore"** - if data already exists, the save operation is ignored and table is unchanged.
This is similar to a CREATE TABLE IF NOT EXISTS in SQL.

4.**"overwrite"** - if data/table already exists, contents of the dataframe overwrites table data.

This example illustrates how to append DataFrame data into Greenplum table.
```scala
scala> :paste
// Paste the following multi line code
val df_read_staged = spark.read.format("jdbc")
          .options(options)
          .option("dbtable", "greenplum_table_staged") // Overwrite dbtable with another tablename
          .load
// ctrl+D  
scala> df_read_staged.write.mode("append").format("jdbc").options(options).save
// Appends staged table data to final greenplum_table

scala> df_read_final.show()
+----------+-------+
|col_string|col_int|
+----------+-------+
|      aaaa|      1|
|      bbbb|      2|
|      aaaa|      1|
|      bbbb|      2|
+----------+-------+

scala> df_read_staged.write.mode("overwrite").format("jdbc").options(options).save
// overwrites final greenplum_table with staged table data

scala> df_read_final.show()
+----------+-------+
|col_string|col_int|
+----------+-------+
|      aaaa|      1|
|      bbbb|      2|
+----------+-------+

scala> df_read_staged.write.mode("ignore").format("jdbc").options(options).save

scala> df_read_final.show()
+----------+-------+
|col_string|col_int|
+----------+-------+
|      aaaa|      1|
|      bbbb|      2|
+----------+-------+

scala> scala> df_read_staged.write.mode("error").format("jdbc").options(options).save
org.apache.spark.sql.AnalysisException: Table or view greenplum_table already exists. SaveMode: ErrorIfExists.;
```

## **Spark parallel read from Greenplum**
Spark is a distributed in-memory computing framework, that scales and distributes workload by creating large number of workers. You can use [Apache Spark JDBC feature](http://spark.apache.org/docs/latest/sql-programming-guide.html#jdbc-to-other-databases) to parallelize the data reads by multiple Spark workers.

To parallelize the read operation, specify the following options:

-  `partitionColumn` - column-name based on which partition should occur
-  `lowerBound` - lower bound of partition stride
-  `upperBound` - upper bound of partition stride
-  `numPartitions` - number of tasks to launch

All rows in the table will be partitioned and returned. This option applies only to reading.


```scala

scala> val parallel_options = Map(
         "url" -> "jdbc:postgresql://localhost:5432/gpadmin",
         "user" -> "gpadmin",
         "password" -> "pivotal",
         "driver" -> "org.postgresql.Driver",
         "dbtable" -> "large_greenplum_table",
         "partitionColumn" ->"col_int",
         "lowerBound"->"1",
         "upperBound"->"1000",
         "numPartitions"->"10") // Creates 10 partitions with 100 rows each ideally

scala> val df = spark.read.format("jdbc").options(parallel_options).load // Reads data through 10 partitions in parallel

scala> df.show(5)
+---+-------+
| id|  value|
+---+-------+
|  1|  Alice|
|  3|Charlie|
|  5|    Jim|
|  2|    Bob|
|  4|    Eve|
+---+-------+
```

## Conclusions
This article shows Pivotal Greenplum works with Apache Spark by using Postgresql JDBC driver.
Checkout [github-repo](https://github.com/kongyew/greenplum-spark-jdbc) for more examples on how to access Greenplum from Spark via JDBC.


Note: Apache™ and Apache Spark™ are trademarks of the Apache Software Foundation (ASF).
