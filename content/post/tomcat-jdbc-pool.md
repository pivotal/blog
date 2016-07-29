---
authors:
- fhanik
categories:
- Tomcat
- Database
- JDBC Pool
- Migrated Content
date: 2010-04-01T15:19:00+01:00
short: |
  Configuration and use of Apache Tomcat’s high concurrency database connection pool
title: Apache Tomcat jdbc-pool
---

In this article we will focus on configuration of the high-concurrency connection pool. For ease of migration for Tomcat users, the configuration has been written to mimic that of [Commons DBCP](http://commons.apache.org/dbcp/configuration.html).

The [documentation of jdbc-pool](http://people.apache.org/%7Efhanik/jdbc-pool/jdbc-pool.html) covers all the attributes. Please note that these attributes are also available as direct setters on the `org.apache.tomcat.jdbc.pool.DataSource` bean if you're using a dependency injection framework. So in this article we will focus on use cases, and different configurations for Tomcat.


# Simple Connection Pool for MySQL

```xml
<Resource type="javax.sql.DataSource"
            name="jdbc/TestDB"
            factory="org.apache.tomcat.jdbc.pool.DataSourceFactory"
            driverClassName="com.mysql.jdbc.Driver"
            url="jdbc:mysql://localhost:3306/mysql"
            username="mysql_user"
            password="mypassword123"
/>
```

The first thing we notice is the `factory="org.apache.tomcat.jdbc.pool.DataSourceFactory"` attribute.
When Tomcat reads the `type="javax.sql.DataSource"` it will automatically configure its repackaged DBCP, unless you specify a different factory. The factory object is what creates and configures the connection pool itself.

There are two ways to configure `Resource` elements in Apache Tomcat.

## Configure a global connection pool

**File: conf/server.xml**
```xml
<GlobalNamingResources>
  <Resource type="javax.sql.DataSource"
            name="jdbc/TestDB"
            factory="org.apache.tomcat.jdbc.pool.DataSourceFactory"
            driverClassName="com.mysql.jdbc.Driver"
            url="jdbc:mysql://localhost:3306/mysql"
            username="mysql_user"
            password="mypassword123"
  />
</GlobalNamingResources>
```

You then create a `ResourceLink` element to make the pool available to the web applications. If you want the pool available to all applications under the same name, the easiest way is to edit the **File: conf/context.xml**

<Context>
  <ResourceLink type="javax.sql.DataSource"
                name="jdbc/LocalTestDB"
                global="jdbc/TestDB"
/>
 <Context>

*Note, that if you don't want a global pool, move the `Resource` element from server.xml into your context.xml file for the web application.*

And to retrieve a connection from this configuration, the simple Java code looks like
```java
Context initContext = new
 InitialContext();
   Context envContext  = (Context)initContext.lookup("java:/comp/env");
   DataSource datasource = (DataSource)envContext.lookup("jdbc/LocalTestDB");
   Connection con = datasource.getConnection();
```

## Simple in Java

We can achieve the same configuration using just Java syntax.
```java
DataSource ds = new DataSource();
   ds.setDriverClassName("com.mysql.jdbc.Driver");
   ds.setUrl("jdbc:mysql://localhost:3306/mysql");
   ds.setUsername("root");
   ds.setPassword("password");
```
Or to separate out the pool properties
```java
PoolProperties pp = new PoolProperties();
   pp.setDriverClassName("com.mysql.jdbc.Driver");
   pp.setUrl("jdbc:mysql://localhost:3306/mysql");
   pp.setUsername("root");
   pp.setPassword("password");
   DataSource ds = new DataSource(pp);
```
All properties that we make available in XML through the object factory are also available directly on the `PoolProperties` or the `DataSource` objects.

# Sizing the connection pool

We will work with the following attributes to size the connection pool

  * initialSize
  * maxActive
  * maxIdle
  * minIdle

It's important to understand these attributes, as they do seem quite obvious but there are some secrets. Let's nail it down.
```xml
<Resource type="javax.sql.DataSource"
            name="jdbc/TestDB"
            factory="org.apache.tomcat.jdbc.pool.DataSourceFactory"
            driverClassName="com.mysql.jdbc.Driver"
            url="jdbc:mysql://localhost:3306/mysql"
            username="mysql_user"
            password="mypassword123"
            initialSize="10"
            maxActive="100"
            maxIdle="50"
            minIdle="10"
            />
```
The `initialSize=10` is the number of connections that will be established when the connection pool is created

  * When defined in `GlobalNamingResources` the pool is created upon Tomcat startup
  * When defined in `Context` the pool is created when it's first looked up in JNDI

The `maxActive=100` is the maximum number of established connections to the database. This attribute is used to limit the number of connections a pool can have open so that capacity planning can be done on the database side.

The `minIdle=10` is the minimum number of connections always established after the connection pool has reached this size. The pool can shrink to a smaller number of connections if the `maxAge` attribute is used and the connection that should have gone to the idle pool ends up being closed since it has been connected too long. However, typically we see that the number of open connections does not go below this value.

The `maxIdle` attribute is a little bit trickier. It behaves differently depending on if the **pool sweeper** is enabled. The pool sweeper is a background thread that can test idle connections and resize the pool while the pool is active. The sweeper is also responsible for connection leak detection. The pool sweeper is defined by
```java
public boolean isPoolSweeperEnabled() {
        boolean timer = getTimeBetweenEvictionRunsMillis()>0;
        boolean result = timer && (isRemoveAbandoned() && getRemoveAbandonedTimeout()>0);
        result = result || (timer && getSuspectTimeout()>0); 
        result = result || (timer && isTestWhileIdle() && getValidationQuery()!=null);
        return result;
    }
```
The sweeper runs every `timeBetweenEvictionRunsMillis` milliseconds.
The `maxIdle attribute` is defined as follows:

  * Pool sweeper disabled - If the idle pool is larger than `maxIdle`, the connection will be closed when returned to the pool
  * Pool sweeper enabled - Number of idle connections can grow beyond `maxIdle` but can shrink down to `minIdle` if the connection has been idle for longer than minEvictableIdleTimeMillis.

It may sounds strange that the pool can will not close connections even if the idle pool is larger than `maxIdle`. It is actually optimal behavior. Imagine the following scenario:

   1. 100 parallel requests served by 100 threads
   1. Each thread borrows a connection 3 times during a request

In this scenario, if we had `maxIdle="50"` then we could end up closing and opening 50x3 connections. This taxes the database and slows down the application. During peak traffic spikes like this, we want to be able to utilize all the pooled connections. So we definitely want to have the pool sweeper enabled. We will get to that in the next section. There is an additional attribute we mentioned here, `maxAge`. `maxAge` defines the time in milliseconds that a connection can be open/established. When a connection is returned to the pool, if the connection has been connected and the time it was first connected is longer than the `maxAge` value, it will be closed.

As we saw by the isPoolSweeper enabled algorithm, the sweeper is enabled when one of the following conditions is met

  * `timeBetweenEvictionRunsMillis>0` AND `removeAbandoned=true` AND `removeAbandonedTimeout>0`
  * `timeBetweenEvictionRunsMillis>0` AND `suspectTimeout>0`
  * `timeBetweenEvictionRunsMillis>0` AND `testWhileIdle=true` AND `validationQuery!=null`  
    As of version 1.0.9 the following condition has been added
  * `timeBetweenEvictionRunsMillis>0` AND `minEvictableIdleTimeMillis>0`

So in order to get optimal pool sizing, we'd like to modify our configuration to meet one of these conditions
```xml
<Resource type="javax.sql.DataSource"
            name="jdbc/TestDB"
            factory="org.apache.tomcat.jdbc.pool.DataSourceFactory"
            driverClassName="com.mysql.jdbc.Driver"
            url="jdbc:mysql://localhost:3306/mysql"
            username="mysql_user"
            password="mypassword123"
            initialSize="10"
            maxActive="100"
            maxIdle="50"
            minIdle="10"
            suspectTimeout="60"
            timeBetweenEvictionRunsMillis="30000"
            minEvictableIdleTimeMillis="60000"
            />
```

# Validating Connections

Pooling database connections presents a challenge, since pooled connections can become stale. It's often the case that either the database, or perhaps a device in between the pool and the database, timeout the connection. The only way to truly validate a connection is to make a round trip to the database, to ensure the session is still active. In Java 6, the JDBC API addressed this by supplying a [isValid](http://java.sun.com/javase/6/docs/api/java/sql/Connection.html#isValid%28int%29) call on the `java.sql.Connection` interface. Prior to that, pools had to resort to executing a query, such as `SELECT 1` on MySQL. This query is easy for the database to parse, doesn't require any disk access. The `isValid` call is scheduled to be implemented but the pool, intended to be used with Apache Tomcat 6, must also preserve Java 5 compatibility.

## Validation Queries

Validation queries present a few challenges

   1. If called too often, they can degrade the performance of the system
   1. If called too far apart, they can result in stale connections
   1. If the application calls `setTransactionIsolation` with `autoCommit=false`, it can yield a `SQLException` if the application tries to call `setTransactionIsolation` again, since the validation query might have already initiated a new transaction in the DB.

Let's look at the most typical configuration:
```xml
<Resource type="javax.sql.DataSource"
            name="jdbc/TestDB"
            factory="org.apache.tomcat.jdbc.pool.DataSourceFactory"
            driverClassName="com.mysql.jdbc.Driver"
            url="jdbc:mysql://localhost:3306/mysql"
            username="mysql_user"
            password="mypassword123"
            testOnBorrow="true"
            validationQuery="SELECT 1"
            />
```
With this configuration, the query `SELECT 1` is executed each time the Java code calls `Connection con = dataSource.getConnection();`.

This guarantees that the connection has been tested before it's handed to the application. However, for applications using connections very frequently for short periods of time, this has a severe impact on performance. The two other configuration options:

  * testWhileIdle
  * testOnReturn

are not really that helpful, as they do test the connection, but at the wrong time.

Not having validation is not really a choice for a lot of applications. Some applications get around it by setting `minIdle=0` and a low `minEvictableIdleTimeMillis` value so that if connections sit idle long enough to where the database session would time out, the pool will time them out as idle before that happens.

The better solution is to test connections that have not been tested for a while.
```xml
<Resource type="javax.sql.DataSource"
            name="jdbc/TestDB"
            factory="org.apache.tomcat.jdbc.pool.DataSourceFactory"
            driverClassName="com.mysql.jdbc.Driver"
            url="jdbc:mysql://localhost:3306/mysql"
            username="mysql_user"
            password="mypassword123"
            testOnBorrow="true"
            validationQuery="SELECT 1"
            validationInterval="30000"
            />
```
In this configuration, connections would be validated, but no more than every 30 seconds. It's a compromise between performance and connection validation. And as mentioned, if we want to get away with validation all together we could configure the pool to timeout idle connections
```xml
<Resource type="javax.sql.DataSource"
            name="jdbc/TestDB"
            factory="org.apache.tomcat.jdbc.pool.DataSourceFactory"
            driverClassName="com.mysql.jdbc.Driver"
            url="jdbc:mysql://localhost:3306/mysql"
            username="mysql_user"
            password="mypassword123"
            timeBetweenEvictionRunsMillis="5000"
            minEvictableIdleTimeMillis="5000"
            minIdle="0"
            />
```

## Setting up a custom database session

In some use cases it is required to perform some tasks when a new database session is initialized. This could involve executing a simple SQL statement or calling a stored procedure.
This is typically done at the database level, where you can create triggers.
```sql
create or replace trigger logon_alter_session after logon on database
  begin
    if sys_context('USERENV', 'SESSION_USER') = 'TEMP' then
      EXECUTE IMMEDIATE 'alter session ....';
    end if;
  end;
  /
```
This would however affect all users, and in the situations where this is not sufficient and we want a custom query to be executed when a new session is created.
```xml
<Resource name="jdbc/TestDB" auth="Container"
            type="javax.sql.DataSource"
            description="Oracle Datasource"
            url="jdbc:oracle:thin:@//localhost:1521/orcl"
            driverClassName="oracle.jdbc.driver.OracleDriver"
            username="default_user"
            password="password"
            maxActive="100"
            validationQuery="select 1 from dual"
            validationInterval="30000"
            testOnBorrow="true"
            initSQL="ALTER SESSION SET NLS_DATE_FORMAT = &apos;YYYY MM DD HH24:MI:SS&apos;"/>
```
The initSQL is executed exactly once per connection, and that is when the connection is established.

# Connection pool leaks and long running queries

Connection pool also contain some diagnostics. Both jdbc-pool and Commons DBCP are able to detect and mitigate connections that are not being returned to the pool. These are referred to as abandoned to leaked connections as demonstrated here.
```java
Connection con = dataSource.getConnection();
  Statement st = con.createStatement();
  st.executeUpdate("insert into id(value) values (1'); //SQLException here
  con.close();
```
There are five configuration settings that are used to detect these type of error conditions, the first three shared with Common DBCP
```xml
<Resource type="javax.sql.DataSource"
            name="jdbc/TestDB"
            factory="org.apache.tomcat.jdbc.pool.DataSourceFactory"
            driverClassName="com.mysql.jdbc.Driver"
            url="jdbc:mysql://localhost:3306/mysql"
            username="mysql_user"
            password="mypassword123"
            maxActive="100"
            timeBetweenEvictionRunsMillis="30000"
            removeAbandoned="true"
            removeAbandonedTimeout="60"
            logAbandoned="true"
            />
```
  * `removeAbandoned` - set to true if we want to detect leaked connections
  * `removeAbandonedTimeout` - the number of seconds from when `dataSource.getConnection` was called to when we consider it abandoned
  * `logAbandoned` - set to true if we should log that a connection was abandoned. If this option is set to true, a stack trace is recorded during the `dataSource.getConnection` call and is printed when a connection is not returned.

There are of course use cases when we want this type of diagnostics, but we are also running batch jobs that hold a connection for minutes at a time. How do we handle that?
Two additional options/features have been added to support these
```xml
<Resource type="javax.sql.DataSource"
            name="jdbc/TestDB"
            factory="org.apache.tomcat.jdbc.pool.DataSourceFactory"
            driverClassName="com.mysql.jdbc.Driver"
            url="jdbc:mysql://localhost:3306/mysql"
            username="mysql_user"
            password="mypassword123"
            maxActive="100"
            timeBetweenEvictionRunsMillis="30000"
            removeAbandoned="true"
            removeAbandonedTimeout="60"
            logAbandoned="true"
            abandonWhenPercentageFull="50"
            />
```
  * `abandonWhenPercentageFull` - A connection must meet the threshold `removeAbandonedTimeout` AND the number of open connections must exceed the percentage of this value.

Using this property will give connections that would have otherwised been considered abandoned, possibly during a false positive. Setting the value to `100` would mean that connections are not considered abandoned unless we've reached our `maxActive` limit. This gives the pool a bit more flexibility, but it doesn't address our 5 minute batch job using a single connection. In that case, we want to make sure that when we detect that the connection is still being used, we reset the timeout timer, so that the connection wont be considered abandoned. We do this by inserting an interceptor.
```xml
<Resource type="javax.sql.DataSource"
            name="jdbc/TestDB"
            factory="org.apache.tomcat.jdbc.pool.DataSourceFactory"
            driverClassName="com.mysql.jdbc.Driver"
            url="jdbc:mysql://localhost:3306/mysql"
            username="mysql_user"
            password="mypassword123"
            maxActive="100"
            timeBetweenEvictionRunsMillis="30000"
            removeAbandoned="true"
            removeAbandonedTimeout="60"
            logAbandoned="true"
            abandonWhenPercentageFull="50"
            jdbcInterceptors="ResetAbandonedTimer"
            />
```
Interceptor - `org.apache.tomcat.jdbc.pool.interceptor.ResetAbandonedTimer` — can be specified by its fully qualified name or if it lives in the `org.apache.tomcat.jdbc.pool.interceptor` package, by its short class name.
Each time a statement is prepared or a query is executed, the timer will reset the abandon timer on the connection pool. This way, the 5 minute batch job, doing lots of queries and updates, will not timeout.

There are of course situations where you want to know about these scenarios, but you don't want to kill or reclaim the connection, since you are not aware of what impact that will have on your system.
```xml
<Resource type="javax.sql.DataSource"
            name="jdbc/TestDB"
            factory="org.apache.tomcat.jdbc.pool.DataSourceFactory"
            driverClassName="com.mysql.jdbc.Driver"
            url="jdbc:mysql://localhost:3306/mysql"
            username="mysql_user"
            password="mypassword123"
            maxActive="100"
            timeBetweenEvictionRunsMillis="30000"
            logAbandoned="true"
            suspectTimeout="60"
            jdbcInterceptors="ResetAbandonedTimer"
            />
```
The `suspectTimeout` attribute works in the exact same way as the `removeAbandonedTimeout` except that instead of closing the connection, it simply logs a warning and issues a JMX notification with the information. This way, you can find out about these leaks or long running queries without changing the behavior of your system.

# Pooling connections from other data sources

So far we have been dealing with connection pooling around connections acquired using the java.sql.Driver interface. Hence we used the attributes

  * driverClassName
  * url

However, some connection configurations are done using the javax.sql.DataSource or even the javax.sql.XADataSource interfaces, and we need to be able to support those configurations.
In plain Java this is relatively easy.
```java
PoolProperties pp = new PoolProperties();
   pp.setDataSource(myOtherDataSource);
   DataSource ds = new DataSource(pp);
   Connection con = ds.getConnection();
```
Or
```java
DataSource ds = new DataSource();
   ds.setDataSource(myOtherDataSource);
   Connection con = ds.getConnection();
```
We are able to inject another `javax.sql.DataSource` or `javax.sql.XADataSource` object and use that for connection retrieval.
This comes in handy when we deal with XA connections.

For XML configuration, the jdbc-pool comes with a `org.apache.tomcat.jdbc.naming.GenericNamingResourcesFactory` class, a simple class to allow configuration of any type of named resource. To setup a [Apache Derby](http://db.apache.org/derby/) `XADataSource` we can create this snippet:
```xml
<Resource factory="org.apache.tomcat.jdbc.naming.GenericNamingResourcesFactory" 
            name="jdbc/DerbyXA1"
            type="org.apache.derby.jdbc.ClientXADataSource"
            databaseName="sample1"
            createDatabase="create"
            serverName="localhost"
            portNumber="1527"
            user="sample1"
            password="password"/>
```
This is a simple XADataSource that connects to a networked Derby instance on port 1527.

And if you would want to pool the XA connections from this data source we can create the connection pool element next to it.
```
<Resource factory="org.apache.tomcat.jdbc.naming.GenericNamingResourcesFactory"
            name="jdbc/DerbyXA1"
            type="org.apache.derby.jdbc.ClientXADataSource"
            databaseName="sample1"
            createDatabase="create"
            serverName="localhost"
            portNumber="1527"
            user="sample1"
            password="password"/>
            <Resource factory="org.apache.tomcat.jdbc.pool.DataSourceFactory"
            dataSourceJNDI="DerbyXA1"<!--Links to the Derby XADataSource-->
            name="jdbc/TestDB1"
            auth="Container"
            type="javax.sql.XADataSource"
            testWhileIdle="true"
            testOnBorrow="true"
            testOnReturn="false"
            validationQuery="SELECT 1"
            validationInterval="30000"
            timeBetweenEvictionRunsMillis="5000"
            maxActive="100"
            minIdle="10"
            maxIdle="20"
            maxWait="10000"
            initialSize="10"
            removeAbandonedTimeout="60"
            removeAbandoned="true"
            logAbandoned="true"
            minEvictableIdleTimeMillis="30000"
            jmxEnabled="true"
            jdbcInterceptors="ConnectionState;StatementFinalizer;SlowQueryReportJmx(threshold=10000)"
            abandonWhenPercentageFull="75"/>
```
Note how the `type=javax.sql.XADataSource` is set, this will create a [org.apache.tomcat.jdbc.pool.XADataSource](http://svn.apache.org/viewvc/tomcat/trunk/modules/jdbc-pool/java/org/apache/tomcat/jdbc/pool/XADataSource.java?view=markup) instead of [org.apache.tomcat.jdbc.pool.DataSource](http://svn.apache.org/viewvc/tomcat/trunk/modules/jdbc-pool/java/org/apache/tomcat/jdbc/pool/DataSource.java?view=markup)
Here we are linking the two data sources using the `dataSourceJNDI=DerbyXA1` attribute. The two data sources both have to exist in the same namespace, in our example, the jdbc namespace.
*Currently JNDI lookup through `DataSource.setDataSourceJNDI(…)` is not supported, only through the factory object.*

If you inject a

  * `javax.sql.DataSource` object - the pool will invoke `javax.sql.DataSource.getConnection()` method
  * `javax.sql.DataSource` object but specify `username`/`password` in the pool- the pool will invoke `javax.sql.DataSource.getConnection(String username, String password)` method
  * `javax.sql.XADataSource` object - the pool will invoke `javax.sql.XADataSource.getXAConnection()` method
  * `javax.sql.XADataSource` object but specify `username`/`password` in the pool- the pool will invoke `javax.sql.DataSource.getXAConnection(String username, String password)` method

Here is an interesting phenomenon that comes up when you deal with XADataSources. You can cast the returning object as either a `java.sql.Connection` or a `javax.sql.XAConnection` and invoke methods for both interfaces on the same object.
```java
DataSource ds = new DataSource();
   ds.setDataSource(myOtherDataSource);
   Connection con = ds.getConnection();
   if (con instanceof XAConnection) {
     XAConnection xacon = (XAConnection)con;
     transactionManager.enlistResource(xacon.getXAResource());
   }
   Statement st = con.createStatement();
   ResultSet rs = st.executeQuery(SELECT 1);
```

# JDBC Interceptors

To make the implementation flexible the concept of JDBC interceptors was created. The `javax.sql.PooledConnection` that wraps the `java.sql.Connection`/`javax.sql.XAConnection` from the underlying driver or data source is itself an interceptor. The interceptors are based on the [`java.lang.reflect.InvocationHandler`](http://java.sun.com/javase/6/docs/api/java/lang/reflect/InvocationHandler.html) interface. An interceptor is a class that extends the [`org.apache.tomcat.pool.jdbc.JdbcInterceptor`](http://svn.apache.org/viewvc/tomcat/trunk/modules/jdbc-pool/java/org/apache/tomcat/jdbc/pool/JdbcInterceptor.java?view=markup) class.

In this article, we'll cover how interceptors are configured. In our next article, we will go over how to implement custom interceptors and their life cycle.
```xml
<Resource factory="org.apache.tomcat.jdbc.pool.DataSourceFactory"
            ...
            jdbcInterceptors="ConnectionState;StatementFinalizer;SlowQueryReportJmx(threshold=10000)"
 
/>
```
Is the same as
```
<Resource factory="org.apache.tomcat.jdbc.pool.DataSourceFactory"
           ...
           jdbcInterceptors="org.apache.tomcat.jdbc.pool.interceptor.ConnectionState;
           org.apache.tomcat.jdbc.pool.interceptor.StatementFinalizer;
           org.apache.tomcat.jdbc.pool.interceptor.SlowQueryReportJmx(threshold=10000)"
/>
```
A short class name, such as `ConnectionState`, can be used if the interceptor is defined in the `org.apache.tomcat.jdbc.pool.interceptor` package. Otherwise, a fully qualified name is required.
Interceptors are defined in semi colon `;` separated string. Interceptors can have zero or more parameters that are defined within parenthesis. Parameters are comma separated simple key-value pairs.

## Connection State

The `java.sql.Connection` interface exposes a few attributes

  * autoCommit
  * readOnly
  * transactionIsolation
  * catalog

The default value of these attributes can be configured using the following properties for the connection pool.

  * defaultAutoCommit
  * defaultReadOnly
  * defaultTransactionIsolation
  * defaultCatalog

If set, the connection is configured for this when the connection is established to the database. If the `ConnectionState` interceptor is not configured, setting these properties is a one time operation only taking place during connection establishment. If the `ConnectionState` interceptor is configured, the connection is reset to the desired state each time its borrowed from the pool.

Some of these methods result in round trips to the database when queries. For example, a call to `Connection.getTransactionIsolation()` will result in the driver querying the transaction isolation level of the current session. Such round trips can have severe performance impacts for applications that use connections very frequently for very short/fast operations. The `ConnectionState` interceptor caches these values and intercepts calls to the methods that query them to avoid these round trips.

## Statement Finalizer

Java code using the `java.sql` objects should do proper cleanup and closure of resources after they have been used.
An example of code cleanup
```java
Connection con = null;
   Statement st = null;
   ResultSet rs = null;
   try {
     con = ds.getConnection();
     ...
 
   } finally {
     if (rs!=null) try  { rs.close(); } catch (Exception ignore){}
     if (st!=null) try  { st.close(); } catch (Exception ignore){}
     if (con!=null) try { con.close();} catch (Exception ignore){}
   }
```
Some applications are not always written in this way. We previously showed how to configure the pool to diagnose and warn when connections were not closed properly.
The `StatementFinalizer` interceptor makes sure that the `java.sql.Statement` and its subclasses are properly closed when a connection is returned to the pool.

# Getting hold of the actual JDBC connection

The connection proxy that is returned implements the [`javax.sql.PooledConnection`](http://java.sun.com/javase/6/docs/api/javax/sql/PooledConnection.html) so retrieving the connection is pretty straight forward, and no need to cast to a specific class in order to do so.
The same applies if you've configured the pool to handle `javax.sql.XAConnection`.

Another interesting way of retrieving the underlying connection is
```java
Connection con = ds.getConnection();
  Connection underlyingconnection = con.createStatement().getConnection();
```
This is because jdbc-pool does [not proxy statements](https://issues.apache.org/bugzilla/show_bug.cgi?id=48392) by default. There is of course [an interceptor that protects against this](http://svn.apache.org/viewvc/tomcat/trunk/modules/jdbc-pool/java/org/apache/tomcat/jdbc/pool/interceptor/StatementDecoratorInterceptor.java?view=log) use case.

And that's it for now folks. Stay tuned for more in depth articles that will take us under the hood of some neat concurrency traps and tricks.
