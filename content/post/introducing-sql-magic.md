---
authors:
- chrisrawles
categories:
- Data Science
- Jupyter Notebook
- SQL
- Greenplum
- Apache Spark
date: 2017-07-13T17:51:13-04:00
draft: false
short: |
    An IPython library to help data scientists write SQL code
title: "sql_magic: Jupyter Magic to Write SQL for Apache Spark and Relational Databases"
image: /images/sql_magic_wide.png
---

{{< responsive-figure src="/images/sql_magic_wide.png" class="center">}}

Data scientists love Jupyter Notebook, Python, and Pandas. And they also write SQL. I created sql_magic to facilitate writing SQL code from Jupyter Notebook to use with both Apache Spark (or Hive) and relational databases such as PostgreSQL, MySQL, Pivotal Greenplum and HDB, and others. The library supports [SQLAlchemy](https://www.sqlalchemy.org/) connection objects, [psycopg](http://initd.org/psycopg/) connection objects, [SparkSession and SQLContext](https://docs.databricks.com/spark/latest/gentle-introduction/sparksession.html) objects, and other connections types. The `%%read_sql` magic function returns results as a Pandas DataFrame for analysis and visualization. 


~~~
%%read_sql df_result
SELECT {col_names}
FROM {table_name}
WHERE age < 10
~~~


The sql_magic library expands upon current libraries such as [ipython-sql](https://github.com/catherinedevlin/ipython-sql) with the following features: 

* Support for both Apache Spark and relational database connections simultaneously
* Asynchronous execution (useful for long queries)
* Browser notifications for query completion

~~~
# installation
pip install sql_magic
~~~

Check out the [GitHub repository](https://github.com/pivotal/sql_magic) for more information.

---

Links:

* [GitHub repository](https://github.com/pivotal/sql_magic)
* [Jupyter Notebook](http://jupyter.org/)
* [Pandas](http://pandas.pydata.org/)
* [SQLAlchemy](https://www.sqlalchemy.org/)
* [Pivotal Greenplum](https://pivotal.io/pivotal-greenplum)
* [Pivotal HDB](https://pivotal.io/pivotal-hdb)
* [Apache Spark](http://spark.apache.org/)
* [ipython-sql](https://github.com/catherinedevlin/ipython-sql)
