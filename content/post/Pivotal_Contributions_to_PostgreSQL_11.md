+++
authors = ["aagrawal", "apraveen", "dgustafsson", "hlinnakangas", "jchampion", "mplageman", "xinzweb"]
categories = ["Greenplum Database", "PostgreSQL", "Greenplum", "Development"]
date = 2018-03-21T15:16:22Z
draft = true
short = "Summary of Pivotal Contributions to PostgreSQL 11"
title = "How Pivotal contributes to the Development of PostgreSQL 11"
+++

Ever since Pivotal announced to make [Greenplum Database](https://greenplum.org/) Open Source, and we started [merging](http://engineering.pivotal.io/post/gpdb_merge_with_postgresql_8.3/) newer [PostgreSQL](https://www.postgresql.org/) versions, we also decided to support the development of the upstream project. This happens in various ways: by developing and contributing new features, reviewing patches from other contributors, or sending bugfixes to upstream.


## Our Motivation

Not only is the PostgreSQL Project an awesome project with a thriving community, and it is fun to work with, in the long run this strategy has several advantages for us.

Eventually the Greenplum Database merge process might catch up with PostgreSQL releases, and future versions might stay close to the upstream version. Every feature which is not only in our product but also available in upstream makes the merge process easier for us.

This strategy further closes the gap between the original project and the fork, and makes it easier for users to use both projects in parallel.

Last but not least, bringing features into upstream PostgreSQL "exposes" these features to a broader range of reviewing developers as well as users, and the feature is tested on a wider range of platforms, compared to what is supported by Greenplum Database.


## Our Contributions

With PostgreSQL 11 entering the home stretch, it is time to look back and see what we contributed, and where we might be able to improve in the future.

This chapter lists three different kind of contributions:

* Features we contributed
* Features we reviewed
* Major bugfixes we provided

That said, this list is not complete, because we do not count all the small fixes and patches we provided. Let's just focus on the major items here.


### Fix shm_toc.c to always return buffer-aligned memory

This fixes a problem with alignment of memory chunks, which failed on several 32-bit systems.

[Discussion](https://www.postgresql.org/message-id/7e0a73a5-0df9-1859-b8ae-9acf122dc38d@iki.fi)


### Fix pg_atomic_u64 initialization

The pg_atomic_init_u64 variable was not initialized before, this leads to a failure.

[Discussion](https://www.postgresql.org/message-id/20170816191346.d3ke5tpshhco4bnd%40alap3.anarazel.de)


### Optional compression method for SP-GiST

This is a complex patch from multiple authors, which allows adding optional compression in SP-GiST leaf tuples. Originally this functionality was left out intentionally, but looks like PostGIS can make good use of this.

[Discussion Part 1](https://www.postgresql.org/message-id/5447B3FF.2080406@sigaev.ru) and [Part 2](https://www.postgresql.org/message-id/flat/54907069.1030506@sigaev.ru#54907069.1030506@sigaev.ru)


### Fix incorrect handling of subquery pullup in the presence of grouping sets

When constants from a flattened subquery are used in a grouping set, the planner might merge these constants into outer expressions. The grouping set will then fail.

[Discussion](https://postgr.es/m/7dbdcf5c-b5a6-ef89-4958-da212fe10176@iki.fi)


### Support parallel btree index builds

While not the actual author of this patch, the underlying framework was provided by us. This feature allows to use the parallel execution features in PostgreSQL to build or rebuild a btree index.

[Discussion Part 1](http://postgr.es/m/CAM3SWZQKM=Pzc=CAHzRixKjp2eO5Q0Jg1SoFQqeXFQ647JiwqQ@mail.gmail.com) and [Part 2](http://postgr.es/m/CAH2-Wz=AxWqDoVvGU7dq856S4r6sJAj6DBn7VMtigkB33N5eyg@mail.gmail.com)


### Remove to pre-8.2 coding convention for [PG_MODULE_MAGIC](https://www.postgresql.org/docs/devel/static/xfunc-c.html#XFUNC-C-DYNLOAD)

One can say that even Greenplum Database is no longer based on PostgreSQL 8.2, and therefore code which deals with the pre-8.2 module handling can be removed. In reality, PostgreSQL 8.2 is long EOL, and therefore such #ifdef's can be removed. Found while merging a newer PostgreSQL version into Greenplum Database.


### Documentation update for server-side CRL and CA file names

While the funcionality of server-side CRL and CA files was removed before, the documentation was not updated properly. This patch fixes that.

[Discussion](https://www.postgresql.org/message-id/11CD0017-2A65-437D-AED7-0B4231CB7669%40yesql.se)


### Support retaining data dirs on successful TAP tests

While earlier implementations used random directory names, and removed the test output files after the test, this patch moves to use static names and preserves the output of failing tests. This makes it easier to debug a failing TAP test.


### Allow spaces in connection strings in SSL tests

A connection string can include spaces in items, not only between items. Therefore the items, or values, must be quoted properly. It is not enough to just quote the entire string.


### Avoid unnecessary use of pg_strcasecmp for already-downcased identifiers

Across the lexer code, sometimes a simple _strcmp_ was used to match keywords, sometimes the more sophisticated _pg_strcasecmp_. The latter adds additional overhead, because the identifiers are already made lowercase. This patch changes the code base to always use strcmp to match identifiers in the lexer.

[Discussion](https://postgr.es/m/29405B24-564E-476B-98C0-677A29805B84@yesql.se)


### Remove restriction on SQL block length in isolationtester scanner

Previously the isolationtester had a limit of 1024 bytes for each SQL query. That seems a bit low these days, and people already ran into this limit. This patch removes this limit and makes the buffer resizable.

[Discussion](https://postgr.es/m/8D628BE4-6606-4FF6-A3FF-8B2B0E9B43D0@yesql.se)


### Documentation update: Add WaitForBackgroundWorkerShutdown() to bgw docs

The documentation does not mention WaitForBackgroundWorkerShutdown(), this patch fixes that oversight, and also updates the documentation for WaitForBackgroundWorkerStartup().

[Discussion](https://postgr.es/m/C8738949-0350-4999-A1DA-26E209FF248D@yesql.se)


### For wal_consistency_checking, mask page checksum as well as page LSN

For consistency checking of WAL pages, previously only the [LSN](http://paquier.xyz/postgresql-2/postgres-9-4-feature-highlight-lsn-datatype/) was masked when the consistency check is performed. This fix adds the page checksum to the exclude list as well, because a changed LSN will change the consistency check even though the data in the page itself is not changed.

[Discussion](http://postgr.es/m/CALfoeis5iqrAU-+JAN+ZzXkpPr7+-0OAGv7QUHwFn=-wDy4o4Q@mail.gmail.com)


### Fix race condition when changing synchronous_standby_names

When a standby is renamed, there is a race condition that commands can be send async to the old name. This patch fixes that problem.


### Change some bogus PageGetLSN calls to BufferGetLSNAtomic

The PageGetLSN() is only supposed to be used when a process holds an exclusive lock on the buffer. If a process only holds a shared lock on the buffer, the BufferGetLSNAtomic() must be used instead.

A newly introduced assertion uncovered some places which do not follow this rule. This patch fixes all but one of the problems, and the remaining code place is verified as a non-issue.

[Discussion](https://postgr.es/m/CABAq_6GXgQDVu3u12mK9O5Xt5abBZWQ0V40LZCE+oUf95XyNFg@mail.gmail.com)



## Our contributors

Although we have a number of people on all kind of PostgreSQL related projects, the following people contributed to the development of PostgreSQL 11:

* Ashwin Agrawal
* Asim Rama Praveen
* Daniel Gustafsson
* Heikki Linnakangas
* Jacob Champion
* Melanie Plageman
* Xin Zhang



## Outlook

We have some ideas for upcoming PostgreSQL versions.

Greenplum Database has table partitioning for a long time, that is a feature which was only recently added to PostgreSQL. We want to share some of the experiences we made around this feature, and enhance the functionality in PostgreSQL.

Another existing limitation which we would like to remove is the length of text types. Currently that type can roughly hold 1 GB, but for some use cases that is not enough.


