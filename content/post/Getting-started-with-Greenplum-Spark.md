---
draft: true
categories: ["greenplum", "spark", "JDBC"]
authors:
- kongc
short: >
  Learn how to configure Greenplum and Spark using JDBC

title: Getting Started with Greenplum and Spark
---
Spark is a light fast cluster computing runs programs up to 100x faster than Hadoop MapReduce in memory. Despite Spark's general purpose data processing and growth in Spark adoption rate, Apache Spark is not a data store as it depends on external data store.  Some Greenplum customers are using Spark for in-memory processing and they want to load data from Greenplum MPP cluster into Spark cluster.  

This article illustrates how to read and write data between Greenplum and Spark and how to speed-up data transfer throughput by using Spark built-in parallism.

###  How to connect to Greenplum with JDBC driver
In this example, we will describe how to configure JDBC driver 

~~~scala
Class.forName("org.postgresql.Driver")

~~~

### Read data from Greenplum

In this section, we will load data from a Greenplum table .

~~~java
val jdbc_url = s"jdbc:postgresql://${jdbcHostname}:${jdbcPort}/${jdbcDatabase}"
val employees_table = spark.read.jdbc(jdbc_url, "employees", connectionProperties)
~~~

### Write data into Greenplum
In this section, we will load data from a Greenplum table .

~~~java
val jdbc_url = s"jdbc:postgresql://${jdbcHostname}:${jdbcPort}/${jdbcDatabase}"
val employees_table = spark.read.jdbc(jdbc_url, "employees", connectionProperties)
~~~
### Using Spark parallel feature to read data from Greenplum
Scaling the JDBC performance by using JDBC parallelism during the read operation.

You can provide partitionColumn, lowerBound, upperBound, numPartitions parameters , in order to enable Spark executors to split the data and parallelize the read operations.


~~~java
val df = (spark.read.jdbc(url=jdbcUrl,
    dbtable="employees",
    columnName="emp_no",
    lowerBound=1L,
    upperBound=100000L,
    numPartitions=100,
    connectionProperties=connectionProperties))
display(df)
~~~



## Conclusions

TBD


