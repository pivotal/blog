---
draft: true
categories: ["Greenplum", "Apache Spark", "JDBC", "Postgresql"]
authors:
- kochan
- gtadi

short: >
  Learn how to configure Greenplum and Apache Spark using JDBC

title: Greenplum and Apache Spark via JDBC
---
Greenplum Database® is an advanced, fully featured, open source data warehouse. It provides powerful and rapid analytics on petabyte scale data volumes.

Apache Spark is a lightning-fast cluster computing framework that runs programs up to 100x faster than Hadoop MapReduce in-memory. Despite Apache Spark's general purpose data processing and growth in Spark adoption rate, Apache Spark is not a data store as it depends on external data store.

Greenplum users want to use Spark for running in-memory analytics and data pre-processing before loading the data into Greenplum.
Using Postgresql JDBC driver, we can load and unload data between Greenplum and Spark clusters.  

This article illustrates how:

- Apache Spark can perform read and write on Greenplum via JDBC and
- Faster data-transfers are achieved using Spark's built-in parallelism.

### Pre-requisites

- Greenplum is installed and running.
- At least one table is created and contain some data.

###  Start spark-shell with Postgresql driver
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

### Read data from Greenplum

Load data from a Greenplum table with a single data partition in Spark cluster

```scala
scala> val options = Map(
         "url" -> "jdbc:postgresql://localhost:5432/gpadmin", // JDBC url
         "user" -> "gpadmin",
         "password" -> "pivotal",
         "driver" -> "org.postgresql.Driver",// JDBC driver
         "dbtable" -> "greenplum_table") // Table name

scala> val df = spark.read.format("jdbc").options(options).load
df: org.apache.spark.sql.DataFrame = [col_string: string, col_int: int]


scala> df.printSchema()
root
 |-- col_string: string (nullable = true)
 |-- col_int: integer (nullable = true)


scala> df.show() // By default prints 20 rows
+----------+-------+
|col_string|col_int|
+----------+-------+
| aaaaaaaa | 11111 |
+----------+-------+
| bbbbbbbb | 22222 |
+----------+-------+
```

### Write data into Greenplum
In this section, you can write data from Spark DataFrame into Greenplum table. Spark DataFrame class provides four write modes for different use cases.

1.**"Error"** mode means When saving a DataFrame to a data source, if data already exists, an exception is expected to be thrown.

2.**"append"** mode means when saving a DataFrame to a data source, if data/table already exists, contents of the DataFrame are expected to be appended to existing data.

3.**overwrite** mode means that when saving a DataFrame to a data source, if data/table already exists, existing data is expected to be overwritten by the contents of the DataFrame.

4.**ignore** mode means that when saving a DataFrame to a data source, if data already exists, the save operation is expected to not save the contents of the DataFrame and to not change the existing data. This is similar to a CREATE TABLE IF NOT EXISTS in SQL.

This example illustrates how to append DataFrame data into Greenplum table.
~~~scala
scala> :paste
// Entering paste mode (ctrl-D to finish)

val jdbcUrl = s"jdbc:postgresql://greenplumsparkjdbc_gpdb_1/basic_db?user=gpadmin&password=pivotal"
val connectionProperties = new java.util.Properties()

// Append data from DataFrame df into Greenplum table
df.write.mode("Append") .jdbc( url = jdbcUrl, table = "basictable", connectionProperties = connectionProperties)

// Exiting paste mode, now interpreting.
~~~

### Using Spark parallel feature to read data from Greenplum
Spark is a light distributed in-memory computing that scales and distributes workload by creating large number of workers. You can use [Apache Spark JDBC feature](http://spark.apache.org/docs/latest/sql-programming-guide.html#jdbc-to-other-databases) to parallelize the data reads by multiple Spark workers.

For example, you can provide partitionColumn, lowerBound, upperBound, numPartitions parameters, in order to enable Spark executors to split the data and parallelize the read operations. The lowerBound and upperBound parameters are used to decide the partition stride, not for filtering the rows in table. So all rows in the table will be partitioned and returned. This option applies only to reading.


~~~java
scala> :paste
// Entering paste mode (ctrl-D to finish)

// that gives multiple partitions Dataset
val opts = Map(
  "url" -> "jdbc:postgresql://greenplumspark_gpdb_1/basic_db?user=gpadmin&password=pivotal",
  "dbtable" -> "basicdb",
  "partitionColumn" ->"id",
  "lowerBound"->"5",
  "upperBound"->"10",
  "numPartitions"->"100"
   )
val df = spark.
  read.
  format("jdbc").
  options(opts).
  load
// Exiting paste mode, now interpreting.

17/07/07 08:01:38 WARN jdbc.JDBCRelation: The number of partitions is reduced because the specified number of partitions is less than the difference between upper bound and lower bound. Updated number of partitions: 5; Input number of partitions: 100; Lower bound: 5; Upper bound: 10.
opts: scala.collection.immutable.Map[String,String] = Map(lowerBound -> 5, url -> jdbc:postgresql://greenplumspark_gpdb_1/basic_db?user=gpadmin&password=pivotal, partitionColumn -> id, upperBound -> 10, dbtable -> basicdb, numPartitions -> 100)
df: org.apache.spark.sql.DataFrame = [id: int, value: string]

scala> df.show
+---+-------+
| id|  value|
+---+-------+
|  1|  Alice|
|  3|Charlie|
|  5|    Jim|
|  2|    Bob|
|  4|    Eve|
|  6|    Bob|
|  7|    Eve|
|  8|  Alice|
|  9|Charlie|
| 11|  Alice|
| 13|    Jim|
| 15|Charlie|
| 17|    Eve|
| 19|  Alice|
| 21|  Alice|
| 23|    Jim|
| 25|Charlie|
| 27|    Jim|
| 29|    Eve|
| 31|    Bob|
+---+-------+
only showing top 20 rows
...
~~~

## Conclusions
This article shows Pivotal Greenplum works with Apache Spark by using Postgresql JDBC driver.  If you want to try this example in approximately 15 mins, you can use this [github](https://github.com/kongyew/greenplum-spark-jdbc) repository by following the instructions to run Greenplum with Apache Spark.


Note: Apache™ and Apache Spark™ are trademarks of the Apache Software Foundation (ASF).
