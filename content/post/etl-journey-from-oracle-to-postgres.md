---
authors:
- damien
- jackcoy

categories:
- ETL
- oracle
- postgres
- database
date: 2016-03-02T17:24:27-07:00
draft: true

short: |
  How we transferred a legacy Oracle database to a new Postgres database in a 3 hour window.

title: ETL Journey from Oracle to Postgres
---


## Overview (WIP)

 * ETL from Oracle to Postgres
 * 6 hour downtime maximum
 * Readonly access to old database
 * New database on heroku.
 * Over 20 millions records in old database.
 * Transforming Data from a legacy system to be used in a freshly built codebase.
 * Run the ETL every day to support continuous feedback and acceptance of user stories.

## Steps

 * Export using expdp
 * Download with SCP
 * Restore into local CentOS VM
 * Transfer to local Postgres
 * Transform data into new schema
 * Restore the data onto Heroku Database

### Export using expdp

There was a *__lot__* of data in the old system, we realised quickly that we would not import all of it.
A quick win was to try and limit the amount of data we would export either through time ranges or by entirely discarding some tables.
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

*`DMPDIR` here refers to a directory record that we had to manually create in the Oracle database.

### Download with SCP

Make sure to use compression. We noticed a significant speed increase in file transfer time. Somewhere close to 4 times as fast.
```
scp -C john@myserver:/u01/oracle/myDumps/etl.dmp ~/Downloads/myDumpfile.dmp
```
Also make sure you can automate this using ssh keys for authentication.

### Restore into local CentOS VM

CentOS is by far the easiest Linux system to setup with Oracle. It's also easy to setup in VMWare or VirtualBox.
Make sure you run it on a beefy machine, having an SSD will improve restore time and read times when transferring to Postgres later.

We use `impdp` for the restore:
```
impdp production/production "DIRECTORY=downloads" "DUMPFILE=myDumpfile.dmp" "TABLE_EXISTS_ACTION=truncate"
```
The `downloads` directory is similar to the previous `DMPDIR` we used with `expdp`, it points at a shared folder we setup on our VM, it points at our local MacOSX `~/Downloads` folder.
Make sure you actually truncate tables before importing using the `TABLE_EXISTS_ACTION`,
this will make it a lot easier to run over and over again.

### Transfer to local Postgres

Before we can easily perform all the transformation of the data, we need to get an identical schema into our local Postgres database.
We tried multiple approaches, one of them was the [`ora2pg` script](http://ora2pg.darold.net/) but we found that solution to be too slow.
What worked really well for us  was using a [Foreign Data Wrapper](https://github.com/laurenz/oracle_fdw) to extract the data from Oracle into an identical schema in our local Postgres database.
Foreign Data Wrapper is not optimal to run complex queries against, but it works great for transferring data into Postgres using simple `INSERT INTO... SELECT...` statements.

For this you will need to setup a schema with foreign data tables mapping to the Oracle tables you care about, and a local schema with the same structure.
Then you can transfer the data like so:

```
INSERT INTO etl.payments (user_id, reservation_id, amount)
    SELECT user_id, reservation_id, amount FROM foreign_data.payments
    WHERE reservation_id IN (SELECT id FROM etl.reservation);
```

Here, `etl` is the local Postgres schema, and `foreign_data` is the one with the foreign tables.
As you see in our `where` condition we were able to take advantage of existing imported data to limit the records we imported.

### Transform data into new schema

In our scenario we were with a set of clients that had grown in familiarity with Ruby and we decided to use Ruby as our language
to both structure and test our Data Transformations.

At first there was much debate about which language/framework we should use, but in the end it did not really have an effect,
because most of our transformation code was written in pure sql and using a single database connection.
We used the [`sequel` gem](https://github.com/jeremyevans/sequel) to execute SQL directly on our Postgres database and it also allowed us additional flexibility for cases that were too complex to maintain with raw queries.

Because of these choices, testing became easy. We could insert data into our `etl` schema then run our transformation service, then assert the correct records were inserted into our public schema.

Some general guidelines on performing the transformations:

 * Disable foreign key constraints before you start.
 * Restore foreign key constraints after processing the data.
 * Use `source_id` columns containing `x-urn:origin_table:origin_id` style values in your target tables.
 * Learn how to use Postgres' awesome features:
 [common table expressions](http://www.postgresql.org/docs/current/static/queries-with.html),
 [window functions](http://www.postgresql.org/docs/current/static/tutorial-window.html),
 [aggregate functions](http://www.postgresql.org/docs/current/static/functions-aggregate.html)...
 * Don't hesitate to cleanup data before processing it in a generic fashion. For example, we had a few records in the legacy system with columns containing invalid XML.
 It was much easier to fix these columns ahead of time and run the transformations afterwards.


#### Common Table Expressions

This feature is great for breaking the problem down into easily understood chunks. It helps a lot making queries very easy to understand.
For example:

```
WITH
    payment_notes_from_xml AS (
        SELECT
            id,
            unnest(xpath('//NOTE/text()', notes :: XML)) AS note
        FROM payments
    )
INSERT INTO payment_notes (payment_id, note)
    SELECT id, note FROM payment_notes_from_xml
```

Common table expressions allow you to name a query for later use in your SQL. CTE's can be read from (and joined to) as if they were a table in your database.
In this example, we also show the use of [unnest](http://www.postgresql.org/docs/current/static/functions-array.html) and [xpath](http://www.postgresql.org/docs/current/static/functions-xml.html).
The `xpath` function allows us to extract the text from each `NOTE` node in the notes XML column. The `unnest` function then expands the given array into individual rows.

The following XML would result in three rows being inserted into the `payment_notes` table:

```
<NOTES>
    <NOTE>foo</NOTE>
    <NOTE>bar</NOTE>
    <NOTE>baz</NOTE>
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
        created_at,
        row_number() OVER (PARTITION BY user_id ORDER BY created_at DESC) AS rank
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
This example shows how you can select all of the user_ids that paid for a given reservation on one row.

### Restore the data onto Heroku Database

Once the transformations are done, generate a dump of your local database, upload it to S3 using the [provided s3-bash tools](https://aws.amazon.com/code/Amazon-S3/943).
The reason we upload it to S3 is that we want to perform the restore using Heroku's `run` command, which requires a public URL for the dump location.
Running it using a Dyno is much faster as it will be on the same network as the database itself.
Also you will be able to customize the command you run unlike when using the built-in `heroku pg:restore` command.

```
heroku run -s standard-2x "wget https://s3.amazonaws.com/my-app/dumps/myDumpFile -O tmp/etl.dmp && pg_restore --clean --no-acl --no-owner --verbose --jobs=6 --username=my_user -h my_host --dbname=my_db -p 1234 tmp/etl.dmp"
```

In order to find the best performance here, you will want to play with the `--jobs` argument and the type of dyno you want to use,
`-s standard-2x` here.

### You're all done! (WIP)

That should be it after all that.
