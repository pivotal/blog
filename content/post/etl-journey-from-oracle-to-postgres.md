---
authors:
- damien
- jackcoy

categories:
- ETL
- oracle
- postgres
- database
date: 2016-04-04T08:54:47-07:00
draft: false

short: |
  How we transferred a legacy Oracle database to a new Postgres database in a 3 hour window.

title: ETL Journey from Oracle to Postgres
---


## Overview

We recently rewrote an entire application for a client. The original had been running in production for over 10 years.
It was still used in production when we started the rewrite and thus had a lot of data.
Our client wanted to do a Big Bang release, so we needed to transfer all of the data in a small amount of time into the new application.

Here are the constraints we were working under:

 * Transfer data from Oracle to Postgres
 * Maximum of 6 hours of downtime
 * Readonly access to the old database
 * New database hosted on Heroku

So we started with a simple script, and iterated over a few weeks to reach our goal. To make that happen it was important to run the ETL every day.
Automating the process was very important to support continuous feedback and acceptance of user stories.
The rest of the article will describe our automated process and what we learned during its development.

## Steps

 * [Export using `expdp`]({{< ref "#expdp" >}})
 * [Download with `scp`]({{< ref "#scp" >}})
 * [Restore into local CentOS VM]({{< ref "#local-restore" >}})
 * [Transfer to local Postgres]({{< ref "#transfer" >}})
 * [Transform data into new schema]({{< ref "#transform" >}})
 * [Restore the data onto Heroku Database]({{< ref "#remote-restore" >}})

### Export using expdp {#expdp}

[Expdp](https://docs.oracle.com/cd/E11882_01/server.112/e22490/dp_export.htm) and [Impdp](https://docs.oracle.com/cd/E11882_01/server.112/e22490/dp_import.htm)
are Oracle recommended tools for exporting and importing database schemas and data.

There was a *__lot__* of data in the old system, we realized quickly that we would not import all of it.
A quick win was to try and limit the amount of data we would export: either through time ranges or by entirely discarding some tables.
In our case we could exclude an entire Audit table containing more than 16 million records.

Sample [`expdp` command](http://dba-oracle.com/t_oracle_expdp_tips.htm):

```
export ORACLE_HOME=/u01/oracle/product/11.1.0/db_1
export ORACLE_SID=MY_DB_NAME
export TABLES_TO_EXPORT=production.reservation,production.payment,production.user

/u01/oracle/product/11.1.0/db_1/bin/expdp DB_EXPORT_USER/amazingPassword@//dbserver:1521/MY_DB_NAME dumpfile=etl.dmp logfile=etl.dmp.log content=data_only directory=DMPDIR tables=$TABLES_TO_EXPORT \
"query=production.reservation:\"WHERE creation_time >= '01-JAN-15'\", production.payment:\"WHERE valid = 1\""
```

We ran the above code using `ssh` on the legacy production server.

(Note: `DMPDIR` here refers to a directory record that we had to manually create in the Oracle database.)

### Download with SCP {#scp}

The only thing worth noting about this step is to make sure to use compression.
We noticed a significant speed increase in file transfer time. Somewhere close to 4 times as fast.

```
scp -C john@myserver:/u01/oracle/myDumps/etl.dmp ~/Downloads/myDumpfile.dmp
```

Also make sure you can automate this using ssh keys for authentication.

### Restore into local CentOS VM {#local-restore}

CentOS is by far the easiest Linux system to setup with Oracle. It's also easy to setup in VMWare or VirtualBox.
Make sure you run it on a beefy machine, having an SSD will improve restore and read times when transferring to Postgres later.

We use `impdp` for the restore:
```
impdp production/production "DIRECTORY=downloads" "DUMPFILE=myDumpfile.dmp" "TABLE_EXISTS_ACTION=truncate"
```
The `downloads` directory is similar to the previous `DMPDIR` we used with `expdp`.
It points at a shared folder we setup on our VM, which is located in our local MacOSX `~/Downloads` folder.
Make sure you truncate tables before importing using the `TABLE_EXISTS_ACTION`,
this will make it a lot easier to run over and over again.

### Transfer to local Postgres {#transfer}

Before we can easily perform all the transformation of the data, we need to get an identical schema into our local Postgres database.
We tried multiple approaches, one of them was the [`ora2pg` script](http://ora2pg.darold.net/) but we found that solution to be too slow.
What worked really well for us  was using a [Foreign Data Wrapper](https://github.com/laurenz/oracle_fdw) to extract the data from Oracle into an identical schema in our local Postgres database.
`Foreign Data Wrapper` is not optimal to run complex queries against, but it works great for transferring data into Postgres using simple `INSERT INTO... SELECT...` statements.

For this you will need to setup a schema with foreign data tables mapping to the Oracle tables you care about, and a local schema with the same structure.
Then you can transfer the data like so:

```
INSERT INTO etl.payments (user_id, reservation_id, amount)
    SELECT user_id, reservation_id, amount FROM foreign_data.payments
    WHERE reservation_id IN (SELECT id FROM etl.reservation);
```

Here, `etl` is the local Postgres schema, and `foreign_data` is the one with the foreign tables.
As you see in our `where` condition we were able to take advantage of existing imported data to limit the records we imported.

### Transform data into new schema {#transform}

In our scenario we were with a set of clients that had grown in familiarity with Ruby and we decided to use Ruby as our language
to both structure and test our Data Transformations.

At first there was much debate about which language/framework we should use, but in the end it did not really have an effect,
because most of our transformation code was written in pure sql and using a single database connection.
We used the [`sequel` gem](https://github.com/jeremyevans/sequel) to execute SQL directly on our Postgres database and it also allowed us additional flexibility for cases that were too complex to maintain with raw queries.

Because of these choices, testing became easy. We could insert data into our `etl` schema, run our transformation service,
then assert the correct records were inserted into our public schema.

Some general guidelines on performing the transformations:

 * Disable foreign key constraints before you start.
 * Restore foreign key constraints after processing the data.
 * Use `source_id` columns containing `x-urn:origin_table:origin_id` style values in your target tables.
   Refer to [Uniform Resource Name](https://en.wikipedia.org/wiki/Uniform_Resource_Name).
 * Learn how to use Postgres' awesome features:
 [common table expressions](http://www.postgresql.org/docs/current/static/queries-with.html),
 [window functions](http://www.postgresql.org/docs/current/static/tutorial-window.html),
 [aggregate functions](http://www.postgresql.org/docs/current/static/functions-aggregate.html)...
 * Don't hesitate to cleanup data before processing it in a generic fashion.
   For example, we had a few records in the legacy system with columns containing invalid XML.
   It was much easier to fix these columns ahead of time and run the transformations afterwards.
   Obviously you do not want to perform this on the production database,
   but the Postgres schema that matches production is a good place for that.

#### Getting started

Before we dive into some of the useful SQL techniques we used, we think it's worth mentioning some of our first steps in transforming the data.
There were a lot of tables in the old system, and much of this data still exists in the new system.
It could be intimidating at first, so we had to find a good starting point.

First we tried to tackle the easiest tables then work towards the hardest ones, the ones with more relations.
This approach proved to be difficult, because much of the easier tables were shown on pages that were centered around some of the harder tables.
This meant testing and accepting these ETL stories could not be done until we had more data.

After struggling through that approach, we took a step back and decided to do the exact opposite: we started with the most *central* table in the system.
For our first iteration of the import, we associated it to "dummy" records, then iterated through the relationships until we no longer needed the "dummy" entries.

This allowed for us to immediately and continuously see the efforts of our transformations in our application.

Now onto some Postgres/SQL features we found most useful during this process!


#### Common Table Expressions

This feature is great for breaking the problem down into easily understood chunks. It helps make queries easier to understand.
For example:

```
WITH
    payment_notes_xml AS (
        SELECT
            id                                    AS payment_id,
            unnest(xpath('//NOTE', notes :: XML)) AS note_xml
        FROM payments
    )
INSERT INTO payment_notes (payment_id, note, type)
    SELECT
        payment_id,
        xpath('//TEXT/text()') AS note,
        xpath('//TYPE/text()') AS type
    FROM payment_notes_xml
```

Common table expressions (CTE) allow you to name a query for later use in your SQL. CTE's can be read from (and joined to) as if they were a table in your database.
In this example, we also show the use of [unnest](http://www.postgresql.org/docs/current/static/functions-array.html) and [xpath](http://www.postgresql.org/docs/current/static/functions-xml.html).
The `xpath` function allows us to extract the text and type from each `NOTE` node in the notes XML column.
The `unnest` function then expands the given array into individual rows.

The following XML would result in three rows being inserted into the `payment_notes` table:

```
<NOTES>
    <NOTE>
        <TEXT>foo</TEXT>
        <TYPE>Internal</TYPE>
    </NOTE>
    <NOTE>
        <TEXT>bar</TEXT>
        <TYPE>Internal</TYPE>
    </NOTE>
    <NOTE>
        <TEXT>baz</TEXT>
        <TYPE>Public</TYPE>
    </NOTE>
</NOTES>
```

#### Window Functions

Window functions are functions that can be applied to a set of rows once they are grouped.
For example, you could find the most recent payments of each user using the `row_number` window function:

```
WITH payment_ranks AS (
    SELECT
        id,
        amount,
        user_id,
        paid_at,
        row_number() OVER (PARTITION BY user_id ORDER BY paid_at DESC) AS rank
    FROM payments
)

SELECT * FROM payment_ranks WHERE rank = 1;
```

#### Aggregate Functions

Aggregate functions can be used to group multiple results into a single result.

```
WITH reservation_payment_users as (
    SELECT
        reservation_id,
        array_agg(user_id) as all_user_ids
    FROM payments
    GROUP BY reservation_id
)
```
This example shows how you can select all of the user_ids that paid for a given reservation in one row.

#### DISTINCT ON

Throughout our Transform step, we found the `DISTINCT ON` feature to be rather helpful.
Whether we were trying to remove duplicate entries coming from the production database,
or grab the first associated record based on an `ORDER BY` clause.

```
SELECT DISTINCT ON (payments.user_id)
    users.id, payments.id
FROM users
LEFT JOIN payments ON payments.user_id = users.id
ORDER BY payments.paid_at DESC;
```

This example shows how we can get the latest payment for each user.

### Restore the data onto Heroku Database {#remote-restore}

Once the transformations are done, generate a dump of your local database, then upload it to S3 using the [provided s3-bash tools](https://aws.amazon.com/code/Amazon-S3/943).
We upload it to S3 so that we can perform the restore using Heroku's `run` command, downloading the dump then restoring it.
Running it using a dyno is much faster as it will be on the same network as the database itself.
Using the [`pg_restore`](http://www.postgresql.org/docs/current/static/app-pgrestore.html)
command provides more flexibility than using
the built-in [`heroku pg:restore`](https://devcenter.heroku.com/articles/heroku-postgres-import-export) command.

```
heroku run -s standard-2x "wget https://s3.amazonaws.com/my-app/dumps/myDumpFile -O tmp/etl.dmp && pg_restore --clean --no-acl --no-owner --verbose --jobs=6 --username=my_user -h my_host --dbname=my_db -p 1234 tmp/etl.dmp"
```

In order to find the best performance here, you will want to play with the `--jobs` argument and the type of dyno you want to use,
`-s standard-2x` here.

### You're all done!

After a few weeks of development we were ready to run this against the production database
and helped our client do the switch in just a few hours to the shiny new application!
