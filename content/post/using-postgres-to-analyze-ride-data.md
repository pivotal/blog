---
title: Using Postgres to analyze ride data

short: |
  Postgres provides some fantastic functionality to help out with basic data analysis. This article will show you how to generate leaderboards and find streaks in raw sql data.
  
authors: 
- joseph

categories:
- PostgreSQL
- SQL
- Databases

date: 2016-04-28T20:54:48-06:00
draft: false
---

Many web applications show some sort of data analysis based on the state of the database. These analyses are sometimes used for dashboards, to power charts, graphs, and tables, or in more advanced cases to determine decisions that the application will make (smart apps). 

Far too often application developers query the database for the raw data and perform aggregates and other basic analysis in the programming language of choice (aka our "comfort zone"). This not only wastes valuable CPU cycles (especially for larger data sets), but introduces more opportunities for bugs.

In this article we'll learn a few nice sql and postgres features that make the analysis easy to understand and doable in a single query!  We'll start with some basics such as joins and aggregates, and then move on to less known functionality such as window functions. Check out all the code in the [github repo](https://github.com/joerodriguez/activities-postgres-queries).

## The schema

Let's go ahead and create a couple of tables to work with:

```sql
CREATE TABLE trail (
  id   SERIAL PRIMARY KEY,
  name VARCHAR(255)
);

CREATE TABLE ride (
  id           SERIAL PRIMARY KEY,
  user_id      INTEGER,
  trail_id     INTEGER,
  started_at   TIMESTAMP,
  completed_at TIMESTAMP
);
```

This gives us two relations that we'll base all of our exercises off of. The `trail` table is quite straight forward with just a name and id (primary key). The `ride` table is used to store records that represent a person (user_id) completing a ride on a given trail (trail_id). We also know how long the user took to complete the ride given the start and end timestamps. 


## Generating a dataset

Let's use postgres to create some test data for our 2 tables:

```sql
INSERT INTO trail (name) VALUES ('Dirty Bismark'), ('Betasso'), ('Walker Ranch'), ('Picture Rock'), ('Hall Ranch');

INSERT INTO ride (user_id, trail_id, started_at)
  SELECT
    (random() * 9) :: INTEGER + 1                                                          AS user_id,
    (random() * 4) :: INTEGER + 1                                                          AS trail_id,
    TIMESTAMP '2014-01-01 00:00:00' + random() * (now() - TIMESTAMP '2014-01-01 00:00:00') AS started_at
  FROM generate_series(1, 10000);

UPDATE ride
SET completed_at = (started_at + (60*60 + (random() * 180 * 60) :: INTEGER) * '1 second' :: INTERVAL);
```

`generate_series()` is a pretty cool function that belongs to a class of postgres' [set returning functions](http://www.postgresql.org/docs/9.5/static/functions-srf.html), which is why it's used in our FROM clause when we create rides. In this case we create 10,000 ride records with a `user_id` between 1 and 10, and a `trail_id` between 1 and 5.

Then we update each ride, setting the completed_at (which we didn't set during the insert) anywhere between 1 and 3 hours after the started_at.

* * *
## Using aggregates to find trail popularity by month

Let's kick things off by finding out how many times each trail has been ridden each month. Let's aim for our result set to look like this:

 id       | trail_name   | month        | count  
----------|--------------|--------------|-------
 4        | Picture Rock | Jan 2014     | 127           
 2        | Betasso      | Mar 2014     | 126           
 3        | Walker Ranch | Aug 2015     | 124           
 2        | Betasso      | Mar 2015     | 123           
 ...      |              |              |               

We can see that information from both of our tables (trail and ride) will be needed here, so we'll probably need a join. Also the times_ridden column show the `count` over the month and trail, so we'll need to group by both of those. We can use `date_trunc()` on the ride.started_at to remove the day and time information, followed by `to_char()` to format the month and year to be human readable.

```sql
SELECT
  trail_id                                               AS id,
  trail.name                                             AS trail_name,
  to_char(date_trunc('month', completed_at), 'Mon YYYY') AS month,
  count(*)                                               AS count
FROM ride
  JOIN trail ON trail_id = trail.id
GROUP BY 1, 2, 3
ORDER BY 4 DESC;
```

And that should do it! Notice we need to group by both the trail_id (or trail.id) and the trail.name. Once `GROUP BY` is used in conjuction with our aggregate function (count), everything else that we want to select needs to be squashed or collapsed.

Also notice the ordinal reference used in both `GROUP BY` and `ORDER BY`. This is purely for convenience, but be careful: if you reorder your selects and forget to change your ordinal references, it's game over.
 
## Filling in the gaps

There is a subtle issue with the previous query. If a trail wasn't ridden during any month the result will not include a row at all. It would be much nicer to include the row with a 0 value for times_ridden. One solution is to approach the query from the `months` perspective: first let's generate a set of all months that we would like to consider, then we can join from there to our previous query:

```sql
WITH ride_range AS (
    SELECT
      min(completed_at) AS first_ride,
      max(completed_at) AS last_ride
    FROM ride
), months AS (
    SELECT date_trunc('month', generate_series(ride_range.first_ride, ride_range.last_ride, '1 month'))
      AS month
    FROM ride_range
)

SELECT
  trail.id                         AS trail_id,
  trail.name                       AS trail_name,
  to_char(months.month, 'Mon YYYY') AS month,
  count(ride.id)                   AS times_ridden
FROM months
  JOIN trail ON TRUE
  LEFT JOIN ride
    ON ride.trail_id = trail.id
       AND months.month = date_trunc('month', ride.completed_at)
GROUP BY 1, 2, 3
ORDER BY 4;
```

Whoa! A couple of new concepts here. If you haven't seen [common table expressions](http://www.postgresql.org/docs/9.5/static/queries-with.html) (more commonly refered to as "with queries") before, this query will look a strange. CTEs allow us to store a temporary relation by name (ride_range) and then use that relation in a subsequent query. Keep in mind you could always use a subquery in place, but CTEs greatly improve code readability as they allow you to think through problems sequentially. This tool can be very powerful; we can now solve some tough problems by breaking it down step by step, massaging the data along the way. 

Additionally, you should recognize the generate_series function from earlier. In addition to integers `generate_series()` can also be used with timestamps and an interval (1 month). This gives us the full set of months between the 2 dates.

The final query should look pretty similar. It's nearly identical to the previous section, but we select from months first followed by joining to trail and ride. The `LEFT JOIN` is pretty important here as we still want a row even if no ride exists for that trail and month.

* * *
## Using window functions to create leaderboards

Now let's see who the top 3 fastest riders are for each trail:

 id       | user_id | ride_time | rank  
----------|---------|-----------|------ 
 1        | 10      | 01:00:01  | 1     
 1        | 8       | 01:00:19  | 2     
 1        | 6       | 01:00:27  | 3     
 2        | 1       | 01:00:02  | 1     
 2        | 8       | 01:00:06  | 2     
 ...      |         |           |

We can accomplish this with 2 new tools:

### Window functions
While tremendously powerful, window functions are one of the less understood features of SQL. They allow you to perform aggregate like functions over a set of rows, but they do not force you to squash or collapse those rows into one. We can use this feature to assign an ordered rank by "partitioning" the data into buckets (one bucket per trail). 

### DISTINCT ON
While `DISTINCT` lets you find a unique set of values, `DISTINCT ON` works a bit differently. It will help to find a distinct row in a grouping while maintaining identity, unlike GROUP BY. Since our leaderboard shouldn't show the same user more than once, even if they have the three fastest times, DISTINCT ON will be our friend.

* * *
Ok, let's take a look at the query now:

```sql
WITH fastest_ride_per_user AS (
    SELECT DISTINCT ON (user_id, trail_id)
      user_id,
      trail_id,
      ride.completed_at - ride.started_at AS ride_time
    FROM ride
    ORDER BY user_id, trail_id, ride_time
)
  , all_ranks as (
    SELECT
      trail_id AS id,
      user_id,
      to_char(ride_time, 'HH24:MI:SS') AS ride_time,
      rank() OVER (PARTITION BY trail_id ORDER BY ride_time) AS rank
    FROM fastest_ride_per_user
)

select * from all_ranks
  where rank <= 3
ORDER BY trail_id, rank;
```

The fastest_ride_per_user CTE uses DISTINCT ON to find a single record for each user and trail combination. How does it determine which record to choose if there are more than one per combo? It uses the `ORDER BY` clause to choose the smallest `ride_time`. Please note that the initial order by columns must include all columns passed to DISTINCT ON. If no additional columns are passed to order by postgres will choose a record at random; no specific order is guaranteed.

The all_ranks CTE is where things get a bit more interesting. As previously mentioned, window functions allow you to perform aggregate like functions over a "group" without the need to collapse or squash those rows together. In this case (`PARTITION BY trail_id ORDER BY ride_time`) our "group" (or partition) is the trail_id, and we determine rank based on the smallest ride_time. This will give us a full leaderboard for all trails and users. The last step is to simply limit the results to the top three. This outlines the iterative approach that CTEs give us, and the sql is much easier to read versus sub queries.

* * *
## Finding streaks with subtraction
 
What if we wanted to find out the longest consecutive number of days each trail has been ridden? Let's aim for the following result:
 
 id       | trail_name    | streak  
----------|---------------|-------- 
 3        | Walker Ranch  | 128     
 4        | Picture Rock  | 78      
 2        | Betasso       | 75      
 5        | Hall Ranch    | 32      
 1        | Dirty Bismark | 21      

This shows us that Walker Ranch trail has the longest streak at 128 consecutive days ridden (by all users), while the Dirty Bismark trail has the shortest streak at 21 days.

Let's start off with a building block and determine all days that a trail has been ridden at least once:

```sql
SELECT
  trail_id,
  date_trunc('day', completed_at) :: DATE AS day
FROM ride
GROUP BY 1, 2
```

Now that we have the unique combos for trail_id and day, we need to find a way to figure out if days are consecutive and group them together. We can accomplish this by subtracting the `row_number()` within each trail (partition) from the day:

```sql
WITH trail_day_ridden AS (
    SELECT
      trail_id,
      date_trunc('day', completed_at) :: DATE AS day
    FROM ride
    GROUP BY 1, 2
)
SELECT
  trail_id, 
  day,
  day - now() :: DATE -
  row_number()
  OVER (PARTITION BY trail_id
    ORDER BY day) AS grouping
FROM trail_day_ridden

```


This is very cool! Consecutive days get the same `grouping`:

 trail_id | day        | grouping  
----------|------------|---------- 
 1        | 2014-02-21 | -812      
 1        | 2014-02-23 | -811      
 1        | 2014-02-24 | -811      
 1        | 2014-02-25 | -811      
 1        | 2014-02-28 | -809      

### Putting it all together

Now that we have a grouping key for consecutive days, the remainder of the query becomes simpler. We can calculate the streaks with the count function and `GROUP BY` our trail_id and grouping key:

```sql
WITH trail_day_ridden AS (
    SELECT
      trail_id,
      date_trunc('day', completed_at) :: DATE AS day
    FROM ride
    GROUP BY 1, 2
)
  , consecutive_groups AS (
    SELECT
      trail_id, 
      day,
      day - now() :: DATE -
      row_number()
      OVER (PARTITION BY trail_id
        ORDER BY day) AS grouping
    FROM trail_day_ridden
)
  , all_streak_counts AS (
    SELECT
      trail_id,
      count(*) streak
    FROM consecutive_groups
    GROUP BY trail_id, grouping
)

SELECT
  trail.id as id,
  trail.name as trail_name,
  max(streak) as streak
FROM all_streak_counts
  join trail on trail_id = trail.id
GROUP BY 1, 2
ORDER BY streak DESC;
```

And finally we select the `max()` streak only (per trail_id) and voila!

Credit goes out to Erwin Brandstetter on this [stackoverflow answer](http://stackoverflow.com/questions/28227371/how-to-add-a-running-count-to-rows-in-a-streak-of-consecutive-days). Thanks Erwin!

* * * 
## Closing Thoughts
 
After learning some of the tools like DISTINCT ON, CTEs, and window functions, you will feel much more comfortable using SQL to manipulate medium to large datasets. While SQL and relational databases aren't necessarily the right tool for "big data" or advanced analysis, they do serve most business applications quite well for most use cases and reporting needs.

I hope that next time you feel the need to pull raw data back from the database and perform some type of manipulation in your comfort zone, you'll first try and do it in a faster, simpler, and less bug prone sql query!
