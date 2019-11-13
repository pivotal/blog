---
authors:
- vatsan
categories:
- Data Science
- Greenplum
- Procedural Languages
- Python
date: 2016-03-20T18:00:17-07:00
short: |
  Building machine learning models (ex: scikit-learn) at scale for data parallel problems on Pivotal's MPP databases (Greenplum/HAWQ).
title: Building machine learning models at scale for data parallel problems on Pivotal's MPP databases
---

This is joint work with Heikki Linnakangas and Ivan Novick of Pivotal.

## In-database machine learning at scale on MPP databases

[Greenplum](http://greenplum.org/) and [HAWQ](http://hawq.incubator.apache.org/) are Pivotal's MPP databases with strong analytical capabilities that make them well suited for data science problems at massive scale.  Using in-database machine learning libraries like [MADlib](http://madlib.net) and procedural languages like PL/Python and PL/R which enable data scientists to harness the vast ecosystem of machine learning libraries in Python and R, data scientists can build models on massive datasets. In parallelizing machine learning models, there are two flavors of problems that data scientists encounter:

1. Embarassingly parallel problems or data parallel problems.
2. Model parallel problems and task parallelism

[Data-parallel problems](https://en.wikipedia.org/wiki/Data_parallelism) are those that typically involve building the same machine learning model on different subsets of the full-dataset or for instance, running a grid-search on model parameters, using the same input dataset. These are relatively easy to parallelize on Greenplum and other MPP databases like [HAWQ](http://hawq.incubator.apache.org/) using User Defined Functions (UDFs) in PL/Python, PL/R or any other procedural languages supported by these platforms. More information on this can be found here: [All things Python @ Pivotal](http://www.slideshare.net/SrivatsanRamanujam/all-thingspythonpivotal) (slides 22-30) and here: [gp-xgboost-gridsearch](https://github.com/vatsan/gp_xgboost_gridsearch).  

Model parallel problems or [task parallel](https://en.wikipedia.org/wiki/Task_parallelism) problems typically involve building a machine learning model on a dataset that cannot fit into memory, on a distributed cluster. The [MADlib library](http://madlib.incubator.apache.org/) (slides 31-52 in [All things Python @ Pivotal](http://www.slideshare.net/SrivatsanRamanujam/all-thingspythonpivotal)) explicitly parallelize such models by splitting them into sub-tasks that can be simultaneously executed on multiple nodes of a cluster and combining the results from these sub-tasks to fit the original model. 

[MADlib](http://madlib.incubator.apache.org/) has a very rich collection of machine learning algorithms implemented in-database and is highly performant on large scale datasets. Currently incubating under the [ASF](http://www.apache.org/), new modules are being added with every monthly release of MADlib and the algorithmic breadth has been steadily increasing. Often though, data scientists would love to tap into the vast ocean of machine learning models in other open source projects in Python or R. For instance, [scikit-learn](http://scikit-learn.org/stable/) is a popular library of machine learning algorithms in Python, likewise, there are too many libraries to name in R. Being able to tap into these libraries when the model of choice is not available in MADlib, would greatly increase the productivity of data scientists. Data scientists and engineers write User Defined Functions (UDFs) in PL/Python or PL/R, which import these third party libraries and invoke them on an inputs (typically a `float8[]` or a `text[]`) that's passed to them. We've previously spoken at length about the power of procedural languages in blogs such as [1](https://blog.pivotal.io/data-science-pivotal/products/how-to-scale-native-cc-applications-on-pivotals-mpp-platform-edge-detection-example-part-2), [2](https://blog.pivotal.io/data-science-pivotal/products/twitter-nlp-example-how-to-scale-part-of-speech-tagging-with-mpp-part-2) or meet-up talks such as [3](https://www.youtube.com/watch?v=bgOftbw8xRk).

One limitation while working on data-parallel problems is the `max_field_size` limit of Greenplum/Postgres which disallows UDFs from accepting inputs that exceed 1 GB (ex: a float8[]). Greenpl/HAWQ like Postgres have a [max field size of 1 GB](http://www.postgresql.org/about/). While your database table itself could be of the order of hundreds of terabytes in size, no single field (cell) can exceed 1 GB in size. Each row of data could be composed of several hundred columns and collectively a row of data could be really large, but no single column's value, in a given row can exceed 1 GB. This of course is present for performance reasons, but this not a tunable configuration setting. 

```
(http://www.postgresql.org/about/)
Limit Value
Maximum Database Size Unlimited
Maximum Table Size  32 TB
Maximum Row Size  1.6 TB
Maximum Field Size  1 GB
Maximum Rows per Table  Unlimited
Maximum Columns per Table 250 - 1600 depending on column types
Maximum Indexes per Table Unlimited
```

For data science problems, one may often have to work with datasets that are represented as matrices (or large linear arrays) that may well exceed the max_field_size limit. For instance, in the example here: [gp_xgboost_gridsearch](https://github.com/vatsan/gp_xgboost_gridsearch), several [XGBoost](https://github.com/dmlc/xgboost) models are built in parallel for every possible combination of the input parameters. If the input dataset exceeds 1 GB in size, these UDFs would error out due to the violation of the `max_fieldsize_limit`.  This limitation prevents users from harnessing the full power of the MPP cluster even when segment hosts typically have a lot more memory than the max_field_size limit. Typically, our customers have clusters with anywhere from 4 to 16 nodes (or more), with each node having upto 8 segments. These beefy machines also have a lot of RAM ranging from 64 GB to 256 GB.

Granted, in a multi-user environment, one has to be mindful of not eating into shared RAM to avoid slowing down or preventing other users from executing their queries. However, it would be useful to have the ability to build machine learning models using popular Python & R libraries, that could well exceed the max_fieldsize_limit.

In this blog, we'll demonstrate how to work around the max_fieldsize_limit to write UDFs in PL/Python, that harness popular machine learning libraries like scikit-learn, for training models in parallel, on datasets several tens to hundreds of gigabytes in size. 

## Demonstrating the limitation introduced by the `max_field_size` limit of 1 GB

#### 1. Create a table with rows containing a field close to max_fieldsize (~ 1 GB)
```python
-- An array of 120000000 float8(8 bytes) types = 960 MB
--1) Define UDF to generate large arrays
create or replace function gen_array(x int)
returns float8[]
as
$$
    from random import random
    return [random() for _ in range(x)]
$$language plpythonu;

--2) Create a table
drop table if exists cellsize_test;
create table cellsize_test
as
(
    select
        1 as row,
        y,
        gen_array(120000000) as arr
    from
        generate_series(1, 3) y
) distributed by (row);
```

#### 2. Attempt to pass an input > 1 GB to a UDF to demonstrate how it fails due the violation of max_fieldsize_limit

We first define a User Defined Aggregate (UDA) that concatenates successive rows of data consisting of arrays and returns a large linear array. We could think of this as unstacking a matrix into a collection of row vectors, so that we could pass it into a PL/Python UDF

```python
--1) Define a UDA to concatenate arrays
DROP AGGREGATE IF EXISTS array_agg_array(anyarray) CASCADE;
CREATE ORDERED AGGREGATE array_agg_array(anyarray)
(
    SFUNC = array_cat,
    STYPE = anyarray
);

--2) Define a UDF to consume a really large array and return its size
create or replace function consume_large_array(x float8[])
returns text
as
$$
    return 'size of x:{0}'.format(len(x))
$$language plpythonu;

--3) Invoke the UDF & UDA to demonstrate failure due to max_fieldsize_limit
select
    row,
    consume_large_array(arr)
from
(

    select
        row,
        array_agg_array(arr) as arr
    from
        cellsize_test
    group by
        row
)q;
```

This results in the following error, which confirms the limitation we previously described.

```
DatabaseError: Execution failed on sql '
--1) Define a UDA to concatenate arrays
DROP AGGREGATE IF EXISTS array_agg_array(anyarray) CASCADE;
CREATE ORDERED AGGREGATE array_agg_array(anyarray)
(
    SFUNC = array_cat,
    STYPE = anyarray
);


--2) Define a UDF to consume a really large array and return its size
create or replace function consume_large_array(x float8[])
returns text
as
$$
    return 'size of x:{0}'.format(len(x))
$$language plpythonu;

--3) Invoke the UDF & UDA to demonstrate failure due to max_fieldsize_limit
select
    row,
    consume_large_array(arr)
from
(

    select
        row,
        array_agg_array(arr) as arr
    from
        cellsize_test
    group by
        row
)q;': array size exceeds the maximum allowed (134217727)  (seg42 slice1 sdw1:40000 pid=25165)
```

Now we will demonstrate how to work-around the max_field_size limit by making using of the static & global dictionaries available in PL/Python and PL/R UDFs.

#### 3. Using the global dictionary `GD`, demonstrate how to use a UDF that processes inputs exceeding max_field_size

All PL/Python UDFs have two dictionaries, [SD and GD](http://www.postgresql.org/docs/8.2/static/plpython-funcs.html), that can be used to cache data in memory.

1. SD is private to a UDF, it is used to cache data between function calls in a given transaction.
2. GD is global dictionary, it is available to all UDFs within a transaction.

Here's the approach we'll take:

![large scale sklearn models on mpp](https://raw.githubusercontent.com/pivotal/blog/master/static/images/largescale_sklearn_models_mpp.png)

We will work with the [Wine Quality](https://archive.ics.uci.edu/ml/datasets/Wine+Quality) dataset from the UCI machine learning repository.
We've replicated the rows of the dataset several times, to create a database table with cells which well exceed the `max_field_size` limit.

```sql
select
    *
from
    wine_sample
limit 10;
```

<div>
<table border="1" class="dataframe">
  <thead>
    <tr style="text-align: right;">
      <th></th>
      <th>model</th>
      <th>features</th>
      <th>quality</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <th>0</th>
      <td>2</td>
      <td>[3.0, 13.27, 4.28, 2.26, 20.0, 120.0, 1.59, 0.69, 0.43, 1.35, 10.2, 0.59, 1.56]</td>
      <td>835</td>
    </tr>
    <tr>
      <th>1</th>
      <td>2</td>
      <td>[2.0, 11.56, 2.05, 3.23, 28.5, 119.0, 3.18, 5.08, 0.47, 1.87, 6.0, 0.93, 3.69]</td>
      <td>465</td>
    </tr>
    <tr>
      <th>2</th>
      <td>2</td>
      <td>[2.0, 11.46, 3.74, 1.82, 19.5, 107.0, 3.18, 2.58, 0.24, 3.58, 2.9, 0.75, 2.81]</td>
      <td>562</td>
    </tr>
    <tr>
      <th>3</th>
      <td>2</td>
      <td>[2.0, 12.37, 1.17, 1.92, 19.6, 78.0, 2.11, 2.0, 0.27, 1.04, 4.68, 1.12, 3.48]</td>
      <td>510</td>
    </tr>
    <tr>
      <th>4</th>
      <td>2</td>
      <td>[1.0, 14.22, 3.99, 2.51, 13.2, 128.0, 3.0, 3.04, 0.2, 2.08, 5.1, 0.89, 3.53]</td>
      <td>760</td>
    </tr>
    <tr>
      <th>5</th>
      <td>2</td>
      <td>[2.0, 12.72, 1.81, 2.2, 18.8, 86.0, 2.2, 2.53, 0.26, 1.77, 3.9, 1.16, 3.14]</td>
      <td>714</td>
    </tr>
    <tr>
      <th>6</th>
      <td>2</td>
      <td>[2.0, 13.11, 1.01, 1.7, 15.0, 78.0, 2.98, 3.18, 0.26, 2.28, 5.3, 1.12, 3.18]</td>
      <td>502</td>
    </tr>
    <tr>
      <th>7</th>
      <td>2</td>
      <td>[2.0, 12.47, 1.52, 2.2, 19.0, 162.0, 2.5, 2.27, 0.32, 3.28, 2.6, 1.16, 2.63]</td>
      <td>937</td>
    </tr>
    <tr>
      <th>8</th>
      <td>2</td>
      <td>[2.0, 12.08, 2.08, 1.7, 17.5, 97.0, 2.23, 2.17, 0.26, 1.4, 3.3, 1.27, 2.96]</td>
      <td>710</td>
    </tr>
    <tr>
      <th>9</th>
      <td>2</td>
      <td>[2.0, 12.33, 0.99, 1.95, 14.8, 136.0, 1.9, 1.85, 0.35, 2.76, 3.4, 1.06, 2.31]</td>
      <td>750</td>
    </tr>
  </tbody>
</table>
</div>

One example of a machine learning model we may wish to build on this dataset could be a regression model to predict the quality of the wine using attributes such as:

```
1 - fixed acidity 
2 - volatile acidity 
3 - citric acid 
4 - residual sugar 
5 - chlorides 
6 - free sulfur dioxide 
7 - total sulfur dioxide 
8 - density 
9 - pH 
10 - sulphates 
11 - alcohol 
```

These form the `features` column, which is a `float8[]` in our table listed above. The `model` column in the sample table above, could for instance correspond to all wines grown in a given state in the US. Perhaps we may be interested in building a model to predict the quality of wine grown in every state. This toy problem illustrates the data-parallel nature of the modeling task. Next we'll define the UDFs, and UDAs to accomplish our goal of training a model from say [scikit-learn](scikit-learn.org/) on a dataset well exceeding the `max_field_size`.

#### Define, UDCTs, UDFs and UDAs to accomplish our goal

```python
--1) SFUNC: State transition function, part of a User-Defined-Aggregate definition
-- This function will merely stack every row of input, into the GD variable
drop function if exists stack_rows(
    text,
    text[],
    float8[],
    float8
) cascade;
create or replace function stack_rows(
    key text,
    header text[], -- name of the features column and the dependent variable column
    features float8[], -- independent variables (as array)
    label float8 -- dependent variable column
)
returns text
as
$$
    if 'header' not in GD:
        GD['header'] = header
    if not key:
        gd_key = 'stack_rows'
        GD[gd_key] = [[features, label]]
        return gd_key
    else:
        GD[key].append([features, label])
        return key
$$language plpythonu;

--2) Define the User-Defined Aggregate (UDA) consisting of a state-transition function (SFUNC), a state variable and a FINALFUNC (optional)
drop aggregate if exists stack_rows( 
    text[], -- header (feature names)
    float8[], -- features (feature values),
    float8 -- labels
) cascade;
create ordered aggregate stack_rows(
        text[], -- header (feature names)
        float8[], -- features (feature values),
        float8 -- labels
    )
(
    SFUNC = stack_rows,
    STYPE = text -- the key in GD used to hold the data across calls
);

--3) Create a return type for model results
DROP TYPE IF EXISTS host_mdl_coef_intercept CASCADE;
CREATE TYPE host_mdl_coef_intercept
AS
(
    hostname text, -- hostname on which the model was built
    coef float[], -- model coefficients
    intercept float, -- intercepts
    r_square float -- training data fit
);

--4) Define a UDF to run ridge regression by retrieving the data from the key in GD and returning results
drop function if exists run_ridge_regression(text) cascade;
create or replace function run_ridge_regression(key text)
returns host_mdl_coef_intercept
as
$$
    import os
    import numpy as np   
    import pandas as pd
    from sklearn import linear_model
    
    if key in GD:
        df = pd.DataFrame(GD[key], columns=GD['header'])
        mdl = linear_model.Ridge(alpha = .5)
        X = np.mat(df[GD['header'][0]].values.tolist())
        y = np.mat(df[GD['header'][1]].values.tolist()).transpose()
        mdl.fit(X, y)
        result = [
            os.popen('hostname').read().strip(), 
            mdl.coef_[0], 
            mdl.intercept_[0], 
            mdl.score(X, y)
        ]   
        GD[key] = result        
        result = GD[key]
        del GD[key]
        return result
    else:
        plpy.info('returning None')
        return None
$$ language plpythonu;
```

As seen above, we first defined a state-transition function, which is one of the building blocks of a User-Defined Aggregate. This function takes a row of input (in this case it is a record consisting of a float8[] and a float8 corresponding to the feature vector and the dependent variable) and stacks in the `GD` variable, using a user-specified key. This key in `GD` is accessible by any other UDFs in the same transaction, thus the UDF `run_ridge_regression` retrieves all the stacked rows from the `GD` variable, constructs the input matrix required for the `ridge regression` model of `sklearn` and returns a set of rows as result, where each row of output corresponds to the hostname on which the model was built, the coefficients of the model, the intercept and the [coefficient of determination](https://en.wikipedia.org/wiki/Coefficient_of_determination) of the model on the training dataset. All these building blocks were combined in the definition of the User-Defined Aggregate.

We can invoke our UDAs and UDFs like so:

```sql
select
    model,
    (results).*
from
(
    select
        model,
        run_ridge_regression(
            stacked_input_key
        ) as results
    from
    (
        select
            model,
            stack_rows(
                ARRAY['features', 'quality'], --header or names of input fields
                features, -- feature vector input field
                quality -- label column
            ) as stacked_input_key
        from
            wine_sample
        group by
            model
    )q1
)q2;
```

In the innermost query, we merely stacked the rows of the input table into the GD variable. By grouping by `model`, we're building multiple regression models in parallel, without explicitly parallelizing the implementation of the `ridge regression` model in `scikit-learn`. 

<div>
<table border="1" class="dataframe">
  <thead>
    <tr style="text-align: right;">
      <th></th>
      <th>model</th>
      <th>hostname</th>
      <th>coef</th>
      <th>intercept</th>
      <th>r_square</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <th>0</th>
      <td>10</td>
      <td>sdw13</td>
      <td>[-317.076377948, 62.0500620027, 0.416072749423, 162.375192268, -8.8567342115, 1.55403179538, 56.4122212105, -108.828043759, -208.649699922, 24.895877024, 42.9492673878, 116.389536874, -66.1348558416]</td>
      <td>162.546696</td>
      <td>0.716523</td>
    </tr>
    <tr>
      <th>1</th>
      <td>9</td>
      <td>sdw2</td>
      <td>[-304.109404213, 74.5250737585, -3.43371878258, 139.27084644, -5.72305248882, 0.744595419201, 77.5014353294, -106.588482015, -167.685124503, 90.1516923867, 39.7803072901, 127.645822384, -101.704587526]</td>
      <td>-30.238416</td>
      <td>0.708814</td>
    </tr>
    <tr>
      <th>2</th>
      <td>3</td>
      <td>sdw2</td>
      <td>[-307.18651323, 61.5224373481, 1.47063776707, 193.259830857, -18.6214527421, 2.4335710989, 91.135375234, -86.3640292245, -153.343722551, 3.05688315498, 39.2513828334, 46.1381861423, -72.2478960996]</td>
      <td>156.581033</td>
      <td>0.776013</td>
    </tr>
    <tr>
      <th>3</th>
      <td>4</td>
      <td>sdw14</td>
      <td>[-315.19350321, 65.0837954451, -12.3415435935, 151.63900677, -13.7159306955, 1.3239107062, 42.9091133141, -73.3993821817, -50.9281911399, -15.4088436536, 46.4040342628, 83.3349706245, -53.3831134811]</td>
      <td>223.886378</td>
      <td>0.727271</td>
    </tr>
    <tr>
      <th>4</th>
      <td>5</td>
      <td>sdw9</td>
      <td>[-309.766022096, 100.281441571, -4.41459273681, 133.913228451, -7.24029032969, 1.85096413382, 87.0188975088, -100.394878326, -72.4600856378, 18.50523645, 31.4688276602, 40.273527478, -74.745208132]</td>
      <td>-308.152828</td>
      <td>0.738516</td>
    </tr>
    <tr>
      <th>5</th>
      <td>2</td>
      <td>sdw12</td>
      <td>[-308.143968247, 75.8323235002, -7.24767188617, 153.65120976, -7.21866367193, 2.05021275785, 88.1310253165, -104.709107165, -132.213217375, 41.9375754143, 39.3444712727, 87.2320135084, -83.8829139824]</td>
      <td>-127.344552</td>
      <td>0.720098</td>
    </tr>
    <tr>
      <th>6</th>
      <td>7</td>
      <td>sdw16</td>
      <td>[-292.491831013, 77.9754967544, -2.99699296323, 148.659732944, -9.55581444196, 1.64432942304, 55.6973991837, -84.1137271812, -155.287234458, 17.4856436475, 36.1721932837, 100.274623447, -65.3585353928]</td>
      <td>-69.530631</td>
      <td>0.701506</td>
    </tr>
    <tr>
      <th>7</th>
      <td>8</td>
      <td>sdw6</td>
      <td>[-334.632387783, 51.2647776529, -3.48328272546, 160.491097171, -8.66863247447, 1.08276882394, 33.8001382612, -96.3381754755, -221.760838113, 33.3029881822, 47.5759038967, 129.677807199, -82.2412541428]</td>
      <td>411.147338</td>
      <td>0.701124</td>
    </tr>
    <tr>
      <th>8</th>
      <td>6</td>
      <td>sdw5</td>
      <td>[-347.036682861, 70.7144175077, -4.28001413723, 94.2697061067, -3.8362015069, 1.88077507258, 59.2066215719, -123.776836974, -211.836728045, 19.468199028, 46.5848203245, 96.0841879507, -56.4798790464]</td>
      <td>158.772706</td>
      <td>0.721023</td>
    </tr>
    <tr>
      <th>9</th>
      <td>1</td>
      <td>sdw2</td>
      <td>[-305.207078775, 69.1563749904, 1.85205159406, 142.053062793, -9.84353848356, 2.20689559387, 49.6397176189, -90.0801141803, -217.435154348, 31.7993674214, 42.5733663559, 137.24861027, -75.2972668947]</td>
      <td>21.565687</td>
      <td>0.722828</td>
    </tr>
  </tbody>
</table>
</div>

In the results above, the `hostname` column tell us in which host of the cluster was the `ridge regression` model for the corresponding value in the `model` column was trained on. We can thus confirm that we were able to build `scikit-learn` models in parallel, on a dataset which exceeded the `max_field_size` limit. This allows data scientists to harness the amazing ecosystem of machine learning libraries in Python and R, via procedural languages like PL/Python and PL/R (amongst others), at scale for data parallel problems.

## What about PL/R?

Similar functionality is possible in PL/R as well. Refer to the global variables section on the [PL/R guide](http://www.joeconway.com/plr/doc/plr-global-data.html) for more details. In short, you can assign values to a global environment variable inside your UDFs like so:

```
assign("global_variable_for_your_udf", matrix ,env=.GlobalEnv)
```

## More information

If you'd like to look at the raw `Jupyter notebooks`, you can clone them from [here](https://github.com/vatsan/gp-sql-snippets/blob/master/notebooks/01_max_fieldsize_1gb_workaround.ipynb). 

