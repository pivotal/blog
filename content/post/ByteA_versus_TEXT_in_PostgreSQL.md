---
authors:
- ascherbaum
categories:
- PostgreSQL
- Performance
date: 2016-05-23T12:57:19+02:00
draft: false
short: |
  One of our customers switched from MongoDB to PostgreSQL, and the migration tool created all data fields as ByteA instead of TEXT. Makes one wonder, if there is a performance difference and if TEXT could be a wiser choice.
title: ByteA versus TEXT in PostgreSQL (for textual data)
---

One of our customers switched from [MongoDB](https://www.mongodb.com/) to [PostgreSQL](https://www.postgresql.org/), because the [JSON](https://en.wikipedia.org/wiki/JSON) performance in MongoDB was not sufficient.

The application is already running faster on PostgreSQL, but for now it must run in parallel on both platforms, and queries (using a framework) have to work equally on both databases. Therefore the superior [JSON and JSONB functionality in PostgreSQL](http://www.postgresql.org/docs/current/static/datatype-json.html) can't be used here - for now. However the migration tool chose to make every data field a _ByteA_ column in PostgreSQL - and I wondered if that is a good choice. Therefore I created a small test case to measure the read and write performance of [ByteA](http://www.postgresql.org/docs/current/static/datatype-binary.html) and [TEXT](http://www.postgresql.org/docs/current/static/datatype-character.html). A common recommendation is to encode data somehow (in [Base64](https://en.wikipedia.org/wiki/Base64), as example) and then store it in _TEXT_ instead of _ByteA_. So I measured the overhead of that approach as well.


## Test approach

The actual test is written in [Perl](https://www.perl.org/), but here is an abstract of what is measured.

### The database

The single table used here is always an integer column (think of a primary key), and a data field:

~~~sql
CREATE TABLE test (id INT, data BYTEA);
CREATE TABLE test (id INT, data TEXT);
~~~

I decided not to create a Primary Key, in order to avoid the performance overhead.


### The data

For every test I chose a string with 1000 random characters.

~~~perl
use String::Random;

my $data = "";
my $write_data = "";
for (my $a = 1; $a <= 100; $a++) {
    my $rand = new String::Random;
    if ($param2 eq 'BYTEA') {
        $data .= $rand->randpattern("bbbbbbbbbb");
        $write_data = $data;
    } elsif ($param2 eq 'TEXT') {
        $data .= $rand->randpattern("..........");
        $write_data = $data;
    } elsif ($param2 eq 'BASE64') {
        $data .= $rand->randpattern("bbbbbbbbbb");
        $write_data = encode_base64($data);
    }
}
~~~

The Perl module "[String::Random](http://search.cpan.org/~steve/String-Random-0.22/)" takes care of creating a random string. For _ByteA_, a truly random character, for _TEXT_ the string is in the printable characters area. The Base64 encoding takes place here, but the original string is stored and compared later with what was read from the database (not part of the performance test).


### The read test

To measure the read performance, a single string is written into the table, and then read multiple times.

~~~perl
for (my $a = 1; $a <= $param1; $a++) {
    $start_time = [gettimeofday];
    $query = "SELECT * FROM test";
    $st = $main::db->prepare($query);
    $st->execute;
    $row = $st->fetchrow_hashref;
    $st->finish;
    $end_time = [gettimeofday];
    $intermediate_time += tv_interval($start_time, $end_time);
}
~~~

No index overhead, just a very simple query and one single row in the table. The average over three runs is used. The data is compared which was written to disk, but the comparisation happens after the second time is taken.


### The write test

To measure the write performance, the data is written into the table using a prepared statement, only the execution time is measured.

~~~perl
$query = "INSERT INTO test (id, data) VALUES (?, ?)";
$st = $main::db->prepare($query);
for (my $a = 1; $a <= $param1; $a++) {
    $start_time = [gettimeofday];
    $st->bind_param(1, '1');
    if ($param2 eq 'BYTEA') {
        $st->bind_param(2, $write_data, { pg_type => PG_BYTEA });
    } elsif ($param2 eq 'TEXT') {
        $st->bind_param(2, $write_data, { pg_type => PG_TEXT });
    } elsif ($param2 eq 'BASE64') {
        $st->bind_param(2, $write_data, { pg_type => PG_TEXT });
    }
    $st->execute;
    $end_time = [gettimeofday];
    $intermediate_time += tv_interval($start_time, $end_time);
}
$st->finish;
~~~

Again the results are averaged over three runs.


## The results

### Read performance

Many use cases rely on a good read performance. Not surprisingly, the performance for the _TEXT_ datatype is around 15% better than the _ByteA_ datatype.

{{< responsive-figure src="/images/ByteA_versus_TEXT_in_PostgreSQL/read.png" >}}

It is a bit surprising that the overhead for reading base64 encoded data is around 10% better than reading the binary data in _ByteA_.


### Write performance

At first glance, the numbers for writing into the different datatypes show no real difference.

{{< responsive-figure src="/images/ByteA_versus_TEXT_in_PostgreSQL/write.png" >}}

Looking into the detail, there is a very small difference, and using _TEXT_ is only slightly faster than using _ByteA_.

{{< responsive-figure src="/images/ByteA_versus_TEXT_in_PostgreSQL/write-20000.png" >}}


## Conclusions

Switching from _ByteA_ to _TEXT_ will result in an instant performance improvement for read queries. That is a big gain, given that no application code has to be changed. The write performance will not change much.

Even switching from _ByteA_ to encoded data (like Base64) will improve the read performance - this approach can be considered if the application can be changed, and truly binary data is stored in the database.


## Transformation

In our case, the table is created automatically, and it is not a problem to redo the entire operation using _TEXT_ instead of _ByteA_. However if you are in a similar situation, the following SQL command shows how to change the datatype:

~~~sql
ALTER TABLE <table name> ALTER COLUMN <column name> TYPE TEXT;
~~~

