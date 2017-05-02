---
authors:
- Add another author here
- dat
- kyle
categories:
- Data Science
- Greenplum
- SQL
- Python
date: 2017-05-02T11:29:57+02:00
draft: true
short: |
  How to train a deep neural network with Keras and TensorFlow and then apply it for scoring on Greenplum.
title: Scoring at Scale with Keras and TensorFlow on Greenplum
---

_Joint work by [Dat Tran](https://de.linkedin.com/in/dat-tran-a1602320) (Senior Data Scientist) and [Kyle Dunn](https://www.linkedin.com/in/kylerdunn/) (Data Engineer)._

This post shows how we use [Keras](https://keras.io/) and [TensorFlow](https://www.tensorflow.org/) to train a deep neural network on a toy problem and then do the scoring on [Greenplum](https://pivotal.io/pivotal-greenplum) in order to benefit from the MPP architecture. The accompanying code is [available on Github](https://github.com/datitran/Krimskrams/tree/master/FraudDetection).

## Motivation

We have many customers who use [Apache MADlib](http://madlib.incubator.apache.org/) to do machine learning on Greenplum; a good fit for users with SQL-based workflow proficiency. Apache MADlib itself offers a wide range of standard machine learning algorithms such as logistic regression, support vector machines or ensemble methods like random forest. MADlib provides highly performant and scalable ML model fitting and scoring when using Greenplum, due to the [Massively Parallel Processing](https://dwarehouse.wordpress.com/2012/12/28/introduction-to-massively-parallel-processing-mpp-database/) (MPP) architecture.

For deep learning capabilities, popular tools like TensorFlow may be more convenient, especially if users are already familiar with them or want to do transfer learning from public models. Deep learning model training involves a huge amount of matrix multiplication - especially deep topologies - an embarrassingly parallel task GPUs are well-suited for. After a model is trained, it can be used in a standalone fashion for inference and prediction. However, if the data is extremely large scalability becomes a concern; for example, a bank might want to detect fraud on millions of transactions with the same model. Bulk analytical operations is an area of differentiation for Greenplum. In this post, we will show how a deep learning model trained with Keras and TensorFlow can be deployed and scored directly in Greenplum.

## Example

### Dataset

We will use a [dataset from Kaggle](https://www.kaggle.com/dalpozz/creditcardfraud) which contains anonymized transactions made by credit cards in September 2013 by European cardholders.

This dataset has only around 285k transactions that occurred in two days. Specifically, it has 28 numerical features (V1, V2, .. V28) that are principal components obtained with [PCA](https://en.wikipedia.org/wiki/Principal_component_analysis), “Time” when the transactions was made and its corresponding “Amount”. Finally it also includes the dependent variable “Class” which is 1 in case of fraud and 0 otherwise.

The dataset is highly unbalanced, the positive class (frauds) accounts for 0.172% of all transactions (see figure 1).

{{< responsive-figure src="/images/scoring-at-scale-with-keras-and-tensorflow-on-pivotal-greenplum/distribution_classes_log_scale.png" class="center" >}}
<p align="center">
  Figure 1: Distribution of the two classes (log scale).
</p>

### Problem

We have a binary classification problem since the goal is to predict whether a transaction is fraud or genuine. And given that there is a high class imbalance, we will focus on precision and recall as measurement criteria for this problem (specifically priority will be given to recall as we don’t want to miss any fraud detection).

### Modeling

Since the data is quite unbalanced, we decided to balance the dataset first. We used the common oversampling technique [SMOTE](https://en.wikipedia.org/wiki/Oversampling_and_undersampling_in_data_analysis#SMOTE) to increase the data for fraud transactions. Moreover, we didn’t do any feature engineering as we wanted to go to the modeling part as early as possible. Also the benefit of using neural networks is that it will gives us good results even if we only use the raw features as it should learn the complexity by itself.

For the modeling part, we used Keras and TensorFlow as backend. This is how our final neural network structure looks like:
~~~
_________________________________________________________________
Layer (type)                 Output Shape              Param #
=================================================================
dense_1 (Dense)              (None, 256)               7424
_________________________________________________________________
dense_2 (Dense)              (None, 128)               32896
_________________________________________________________________
dense_3 (Dense)              (None, 64)                8256
_________________________________________________________________
dense_4 (Dense)              (None, 32)                2080
_________________________________________________________________
dropout_1 (Dropout)          (None, 32)                0
_________________________________________________________________
dense_5 (Dense)              (None, 1)                 33
=================================================================
Total params: 50,689
Trainable params: 50,689
Non-trainable params: 0
_________________________________________________________________
~~~

Note:

* Sigmoid is used as activation function at every node. We also tried ReLU but this didn't perform well.
* Dropout is utilized to prevent overfitting.
* For the loss function, we used binary crossentropy with RMSprop as optimizer (SGD also performed well but needed more epoch to converge).
* We applied mini-batch training (batch_size=32, epoch=20) with early stopping (patience=4) on an AWS [g2.2xlarge instance](https://aws.amazon.com/ec2/instance-types/).
* Stratified k-fold cross-validation where k=10 was also used at the end to evaluate the model against overfitting.

The average loss convergence for both training and validation for each split can be found in figure 2. We can see that the training and validation loss is decreasing very fast which means that the learning rate is probably too high. However, since it is decreasing it is very good for us.

{{< responsive-figure src="/images/scoring-at-scale-with-keras-and-tensorflow-on-pivotal-greenplum/average_loss.png" class="center" >}}
<p align="center">
  Figure 2: Average loss for epoch=20 with early stopping.
</p>

On average we get very high recall and precision values (~99%) for each run (see figure 3).

{{< responsive-figure src="/images/scoring-at-scale-with-keras-and-tensorflow-on-pivotal-greenplum/evaluation_metrics.png" class="center" >}}
<p align="center">
  Figure 3: Various evaluation metrics for the binary classification problem.
</p>

### Scoring on Greenplum

Now we would like to use the trained model and do scoring on Greenplum. For this we first need to install some required packages that we'll use inside our PL/Python scoring routine:

Install pip on each segment (as gpadmin):
~~~
$ curl "https://bootstrap.pypa.io/get-pip.py" | "/usr/local/greenplum-db/ext/python/bin/python"
~~~

Install TensorFlow on each segment (as gpadmin):
~~~
$ pip install tensorflow-1.1.0rc2-cp27-cp27m-linux_x86_64.whl
~~~
_(Note, this package was custom compiled for CENTOS/RHEL6 compatibility)_

Install Keras and h5py (for model loading) on each segment (as gpadmin):
~~~
$ pip install keras
$ pip install h5py
~~~

First, download the data set from Kaggle and then use the following DDL and DML to load the data into Greenplum - you may consider using the single node sandbox from [Pivotal Network](http://greenplum.org/#download):

~~~
CREATE TABLE credit_card
(
    Time NUMERIC, -- how many times this card has been used
    V1 NUMERIC, -- first principal component
    V2 NUMERIC, -- second principal component
    V3 NUMERIC, -- third principal component
    V4 NUMERIC,
    V5 NUMERIC,
    V6 NUMERIC,
    V7 NUMERIC,
    V8 NUMERIC,
    V9 NUMERIC,
    V10 NUMERIC,
    V11 NUMERIC,
    V12 NUMERIC,
    V13 NUMERIC,
    V14 NUMERIC,
    V15 NUMERIC,
    V16 NUMERIC,
    V17 NUMERIC,
    V18 NUMERIC,
    V19 NUMERIC,
    V20 NUMERIC,
    V21 NUMERIC,
    V22 NUMERIC,
    V23 NUMERIC,
    V24 NUMERIC,
    V25 NUMERIC,
    V26 NUMERIC,
    V27 NUMERIC,
    V28 NUMERIC, -- twenty-eighth principal component
    Amount NUMERIC, -- transaction amount
    Class NUMERIC -- the actual classification classes
)
WITH ( APPENDONLY=TRUE, COMPRESSTYPE=zlib, COMPRESSLEVEL=5 )
DISTRIBUTED RANDOMLY ;

COPY credit_card FROM '/home/gpadmin/creditcard.csv' CSV HEADER;
~~~

The PL/Python parallel scoring approach builds on the work from this [blog](http://engineering.pivotal.io/post/running-sklearn-models-at-scale-on-mpp) by [Vatsan Ramanujam](https://github.com/vatsan). The is broken into three parts:

1. Define an aggregation/caching PL/Python function and a scoring PL/Python function
2. Perform the aggregation/caching into memory as a "matrix" (really, a list of lists)
3. Perform the scoring

The following creates a caching function to store the features into a Global Data (GD) dictionary available for subsequent PL/Python functions in the same SQL transaction:

~~~
CREATE FUNCTION stack_rows(
    key text,
    header text[], -- name of the features column
    features float8[] -- independent variables (as array)
)
RETURNS text AS
$$
    if 'header' not in GD:
        GD['header'] = header
    if not key:
        gd_key = 'stack_rows'
        GD[gd_key] = [features]
        return gd_key
    else:
        GD[key].append(features)
        return key
$$
LANGUAGE plpythonu;
~~~

Next a wrapper is created to employ this caching function as a custom SQL aggregation:

~~~
CREATE ORDERED AGGREGATE stack_rows(
        text[], -- header (feature names)
        float8[] -- features (feature values)
)
(
    SFUNC = stack_rows,
    STYPE = text -- the key in GD used to hold the data across calls
);
~~~

The scoring function that is dispatched to to each segments matrix/shard of data is shown below:

~~~
CREATE OR REPLACE FUNCTION score_keras(_model text, _table text)
RETURNS SETOF INTEGER[]
AS
$$

    # Begin: Work around to import Tensorflow
    import sys

    sys.argv = {0: ""}
    __file__ = ""
    # End: Work around to import Tensorflow

    #import numpy as np
    from os import getpid

    if 'model' not in SD:
        from keras.models import load_model
        SD['model'] = load_model(_model)

    result = None
    if _data_key in GD:
        result = SD['model'].predict_classes(GD[_data_key])
        del GD[_data_key]

    return result

$$

LANGUAGE plpythonu IMMUTABLE ;
~~~

To invoke the function, first the custom aggregation function is executed using a Common Table Expression, to stage the data in memory, then perform the scoring:

~~~
WITH cached_data AS (
SELECT
    gp_segment_id,
    stack_rows(
    ARRAY['features'], -- header or names of input fields
    ARRAY[v1, v2, v3, v4, v5, v6, v7,
          v8, v9, v10, v11, v12, v13, v14,
          v15, v16, v17, v18, v19, v20, v21,
          v22, v23, v24, v25, v26, v27, v28] -- feature vector
    ) AS stacked_input_key
FROM
    credit_card
GROUP BY
    gp_segment_id
)

SELECT
    score_keras2(
        '/home/gpadmin/model_file.h5',
        stacked_input_key
    ) AS results
FROM
    cached_data ;
~~~

Note:

* The first argument is the full path to the model (must be on every segment).
* The second argument is the table name containing data to score (optionally schema-qualified).
* If a segment's data shard has the potential to consume a significant amount of RAM, using a spill-to-disk data structure, like [chest](https://github.com/blaze/chest), will be necessary.

### Benchmark Results

{{< responsive-figure src="/images/scoring-at-scale-with-keras-and-tensorflow-on-pivotal-greenplum/benchmark_results.png" class="center" >}}
<p align="center">
  Figure 4: Benchmark results.
</p>

While a modest 2x speedup is achieved, testing was only possible on a single node; actual Greenplum clusters would exhibit an incremental speedup for each additional cluster node, in accordance with [Amdahl's Law](https://en.wikipedia.org/wiki/Amdahl%27s_law).

_Note: TensorFlow automatically utilizes multi-core on a single node which causes some CPU contention in the MPP test environment (~4x speedup is expected from four Greenplum segments)._

## Summary

We showed the workflow to train a neural network with Keras and TensorFlow on a small toy problem. Then we applied the trained model on Greenplum for scoring. We also benchmarked our results in a sandbox environment where we already achieved a modest speedup. We expect a much better performance in an actual cluster environment.
