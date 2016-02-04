---
authors:
- ascherbaum
categories:
- PostgreSQL
- Meetup
date: 2016-01-29T16:54:32+01:00
draft: false
short: |
  Pivotal hosted a PostgreSQL Meetup in Berlin. Speakers: Andres Freund and Oleksandr Shulgin.
title: PostgreSQL Meetup in Berlin, 2016-01-26
---

[Meetups](http://www.meetup.com/) serve two main purposes: listen to good talks, and meet other people who share a common interest in a topic.

## Meet other people.

{{< responsive-figure src="/images/PostgreSQL-Meetup-2016-01-26/entrance.png" class="right small" >}}

Berlin has a very active [Meetup](http://www.meetup.com/) scene - and [PostgreSQL](http://www.meetup.com/PostgreSQL-Meetup-Berlin/) is no exception. [This time](http://www.meetup.com/PostgreSQL-Meetup-Berlin/events/227391375/), "meet other people" was hosted by Pivotal, and took place in the [EMC Berlin](http://www.emc.com/de-de/index.htm) office. Pizza and beverages help starting a conversation on different [PostgreSQL](https://www.postgresql.org/) topics, which kept going after the talks. Finally security asked us to leave the office, because they wanted to lock the office.


## Talks

Two speakers presented PostgreSQL related topics:

### Andres Freund:

{{< responsive-figure src="/images/PostgreSQL-Meetup-2016-01-26/Andres_Freund.png" class="right small" >}}

Andres Freund from [Citus Data](https://www.citusdata.com/) talked about [Performance Optimization](http://anarazel.de/talks/berlin-meetup-2016-01-26/io.pdf) for a PostgreSQL database. The focus was on [Shared Memory](http://www.postgresql.org/docs/current/static/kernel-resources.html) settings, and how to streamline the performance and avoid hickups in the I/O.

[The slide deck can be found here](http://anarazel.de/talks/berlin-meetup-2016-01-26/io.pdf).




### Oleksandr Shulgin: Streaming huge databases using logical decoding

{{< responsive-figure src="/images/PostgreSQL-Meetup-2016-01-26/Oleksandr_Shulgin.png" class="right small" >}}

[Zalando](https://www.zalando.de/) is a heavy user of PostgreSQL and a regular contributor of tools to the PostgreSQL ecosystem. Also they are an early adaptor of upcoming PostgreSQL releases and do quite a lot of beta testing.

Oleksandr shows how the [Logical Decoding](http://www.postgresql.org/docs/9.4/static/logicaldecoding-explanation.html), which is new in PostgreSQL 9.4, can be used to feed data into a standby system.

[The slide deck can be found here](http://www.slideshare.net/AlexanderShulgin3/streaming-huge-databases-using-logical-decoding).

