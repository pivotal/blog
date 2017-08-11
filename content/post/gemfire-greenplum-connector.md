---
draft: true
categories: ["GemFire", "Greenplum"]
authors:
- jchen
date: 2017-08-11T14:00:36.000Z
short: >
  Use GemFire Greenplum Connector to transfer data between GemFire and Greenplum.

title: Introducing GemFire Greenplum Connector
---

The GemFire Greenplum Connector is an extension package built on top of GemFire that maps Greenplum tables and GemFire regions. It enables parallel data movement between the two scale-out systems. With the GemFire Greenplum Connector, the contents of Greenplum tables can now be easily loaded into GemFire, and entire GemFire regions can likewise be easily consumed by Greenplum. With GemFire Greenplum Connector, the users no longer have to perform a flat file export from Greenplum using GPFdist, write custom code to transform the CSV files into plain old Java objects (POJOs), then load the data into GemFire.

The GemFire Greenplum Connector enables users to more easily tackle two use cases:

- Scaling analytics for customer applications
- High speed data ingestion into Greenplum

This article illustrates

- The architecture of GemFire Greenplum Connector
- Parallel bidirectional data transfer between GemFire and Greenplum

# The Architecture of GemFire Greenplum Connector

GGC architecture(figure). parallel data transfer between servers and segments

# Configuration and Setup

Before we start GemFire, the GemFire cache.xml is required. In addition to configure GemFire, this file also configure the connection to Greenplum and the data type mapping between GemFire and Greenplum. Here is an example `cache.xml`:
~~~xml
<?xml version="1.0" encoding="UTF-8"?>
<cache xmlns="http://geode.apache.org/schema/cache"
  xmlns:gpdb="http://schema.pivotal.io/gemfire/gpdb"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://geode.apache.org/schema/cache
  http://geode.apache.org/schema/cache/cache-1.0.xsd
  http://schema.pivotal.io/gemfire/gpdb
  http://schema.pivotal.io/gemfire/gpdb/gpdb-2.4.xsd"
  version="1.0">

  <pdx read-serialized="true" persistent="false">
      <pdx-serializer>
          <class-name>org.apache.geode.pdx.ReflectionBasedAutoSerializer</class-name>
          <parameter name="classes">
              <string>io.pivotal.gemfire.demo.entity.*</string>
          </parameter>
      </pdx-serializer>
  </pdx>
  <jndi-bindings>
      <jndi-binding jndi-name="DemoDatasource" type="SimpleDataSource"
          jdbc-driver-class="org.postgresql.Driver" user-name="gpadmin"
          password="changeme" connection-url="jdbc:postgresql://localhost:5432/gemfire_db">
      </jndi-binding>
  </jndi-bindings>
  <region name="Parent">
      <region-attributes refid="PARTITION">
          <partition-attributes redundant-copies="1" />
      </region-attributes>
      <gpdb:store datasource="DemoDatasource">
          <gpdb:types>
              <gpdb:pdx name="io.pivotal.gemfire.demo.entity.Parent"
                  schema="public"
                  table="parent">
                  <gpdb:id field="id" />
                  <gpdb:fields>
                      <gpdb:field name="id" column="id" />
                      <gpdb:field name="name" />
                      <gpdb:field name="income" class="java.math.BigDecimal" />
                  </gpdb:fields>
              </gpdb:pdx>
          </gpdb:types>
      </gpdb:store>
  </region>
  <gpdb:gpfdist port="8000" />
</cache>
~~~

Details can be found [here](http://ggc.docs.pivotal.io/ggc/mapping.html)


# Import operation

The import operaton copies all rows from a Greenplum table to a GemFire region.

The import implements an upsert functionality: if a Greenplum row imported is already present in a GemFire entry, the entry value will be updated if it has changed. If the Greenplum row does not already exist as a GemFire entry, a new entry is created.

~~~bash
gfsh>import gpdb --region=regionpath
~~~

# Export Operation

An export operaton copies entries from a GemFire® region to a Greenplum table. The export operation supports the UPSERT functionality, which updates a Greenplum row if the GemFire entry to be exported is already present as a Greenplum row. If the Greenplum row does not already exist, a new row is inserted.

~~~bash
gfsh>export gpdb --region=regionpath --type=UPSERT
~~~

In addition to UPSERT, the export operation implements the functionality of one of these: INSERT_ALL, INSERT_MISSING and UPDATE. e.g. The INSERT_MISSING functionality inserts rows into the GPDB table for GemFire region entries that are not already present in the table. It does not update any existing rows in the GPDB table.

~~~bash
gfsh>export gpdb --region=regionpath --type=INSERT_MISSING
~~~

The export operation also supports a `remove-all-entries`, an optional boolean value that, when true, removes all GemFire entries present in the specified region when the export operation is initiated, once changes have been successfully committed to the GPDB table. All exported region entries are removed, independent of which rows are updated or inserted into the GPDB table.

# Statistics
~~~bash
gfsh>list gpdb operations
       Operation Id        | Operation Name | Region Name | Table Name | User Name |          Start Time          | Rows Processed | Bytes Processed
-------------------------- | -------------- | ----------- | ---------- | --------- | ---------------------------- | -------------- | ---------------
cd4050ef-13c0-4538-a749-.. | import         | Child       | child      | root      | Mon Oct 17 15:21:35 PDT 2016 | 60000          | 2880000
~~~

## Cancel Operation
In case you want to cancel an import or export operation that is in progress, you can run the following `gfsh` command, where the `operationId` is the UUID listed from the `list gpdb operation` command.
~~~bash
gfsh>cancel gpdb operation --operationId=f5d241a0-876f-4c64-980a-ed313f3488ca
Found operation to cancel.
~~~

# Java API

In case you want to write Java program that uses GemFire Greenplum Connector, there is a Java API for it. Please refer to the documentation for [import](http://ggc.docs.pivotal.io/ggc/toGemFire.html) and [export](http://ggc.docs.pivotal.io/ggc/toGreenplum.html).

The Java API also supports event listener interface that defines callbacks that will be invoked at various points within the import or export operation. Please refer to [OperationEventListener](http://ggc.docs.pivotal.io/ggc/event-handlers.html) documentation.

# Conclusions
TBD

# Resources
- [Download Pivotal GemFire Greenplum Connector](https://network.pivotal.io/products/pivotal-gemfire)
- [Pivotal GemFire Greenplum Connector Examples](https://github.com/gemfire/gemfire-greenplum-examples)
- [Pivotal GemFire Greenplum Connector Documentation](http://ggc.docs.pivotal.io)
- [Pivotal GemFire Documentation](https://gemfire.docs.pivotal.io)
- [Pivotal Greenplum Documentation](http://gpdb.docs.pivotal.io)
