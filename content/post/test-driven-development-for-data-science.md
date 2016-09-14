---
authors:
- dat
- magarwal
categories:
- TDD
- Data Science
- Machine Learning
- Agile
- Pair Programming
date: 2016-09-09T09:03:56+02:00
draft: true
short: |
  Unravelling Test-Driven Development for Data Science.
title: Test-Driven Development for Data Science
---

_Joint work by [Dat Tran](https://de.linkedin.com/in/dat-tran-a1602320) (Senior Data Scientist) and [Megha Agarwal](https://uk.linkedin.com/in/agarwal22megha) (Data Scientist II)._

This is a follow up post on [API First for Data Science](http://engineering.pivotal.io/post/api-first-for-data-science/) and [Pairing for Data Scientists](http://engineering.pivotal.io/post/pairing-on-data-science/) with focus on Test-Driven Development.

## Motivation

Test-Driven Development (TDD) has [plethora](http://pivotal-guides.cfapps.io/craftsmanship/tdd/) of advantages. You might be wondering how is TDD relevant for data science? While building smart apps, as Data Scientists, we are really contributing in shaping the brain of the application which will drive actions in real-time. We have to ensure that the core driving component is always behaving as expected, and this is where TDD comes to our rescue.

**Data Science and TDD**

TDD for data science (DS) can be a bit more tricky than software engineering. Data science has a fair share of exploration involved where we are trying to find which features and algorithms will contribute best to solve the problem in hand. Do we strictly test drive all our features right from the exploratory phase, when we know a lot of them might not make into production? In the initial days of exploring how TDD fits the DS space, we tried a bunch of stuff. We highlight why we started test driving our DS use case and what worked the best for us.

Now imagine you are a logistics company and this shiny little 'smart' app has figured out the best routes for your drivers for the following day. Next day is your moment of truth! The magic better work, else you can only imagine the chaos and loss it can create. Now what if we say we can ensure that the app will always generate the most optimised route? We suddenly have more confidence in our application. There is no secret ingredient here! We can wrap up our predictions in a test case which allows us to trust the model only when it’s error rate is below a certain threshold.

Now I know you would ask, why would we put a model in production which doesn’t have the desired error rate at first place? But we are dealing with real life data here, things can go haywire pretty fast and we might end up with a broken or (if you are even more lucky) no model depending on how robust our code base is. TDD can not only help us ensure that nothing went wrong while developing our model but also prompts us to think what we want our model to achieve and forces us to think about edge cases where things can potentially go wrong. TDD allow us to be more confident.

**TDD is dead, long live TDD**

So TDD saves the day, let’s start TDD everything? Not quite when it comes to data science. As discussed in one of our previous [blog posts](http://engineering.pivotal.io/post/api-first-for-data-science/), we have two phases in our data science engagements: exploratory and production. Test driving all the features and algorithms stringently during exploratory phase is bit of an overkill. We felt we were investing a lot of time in throw away work. That made the exploration phase quite intensive and slowed us considerably. Eventually we found a fine balance between TDD and DS.

After the exploratory phase, once we have figured out which model and features suits the use case the best, we actually start test driving feature generation, model development and integration bits. Our model evaluation from the exploratory phase helps us set expectations around the model’s performance. We leverage this information in our TDD to make sure the model is behaving as expected in production.

Here are few things to keep in mind while test driving data science use cases:

1. Start TDD once you have a fair idea of what model and features will go in production.
2. Don’t test drive everything! Figure out the core functionalities of your code. For e.g. while feature generation, if a feature is generated using simple count functionality of SQL, trust that SQL’s in-build count functionality is already well tested. Writing another test around that won’t add much value.
3. We [pair programme](http://engineering.pivotal.io/post/pairing-on-data-science/). So we test drive things in a ping pong manner, i.e. one person comes up with a test case, the companion makes it pass and then the role reverses.
4. Have separate unit and integrations test suite.
5. Mock behaviours where appropriate.
6. As a general rule of thumb, ensure your entire test suite runs within 10 min.

## Example

Let’s demonstrate TDD for data science with an example. Assume we are given two features x and y for five observations and the problem at hand is to assign these data points to meaningful clusters.

| Obs | X | Y |
|:-----|:---|:---|
| A   | 1 | 1 |
| B   | 1 | 0 |
| C   | 0 | 2 |
| D   | 2 | 4 |
| E   | 3 | 5 |

This is an [unsupervised problem](https://en.wikipedia.org/wiki/Unsupervised_learning) where the goal is to find hidden structure in the data. Real life examples can be found in many marketing divisions where customer segmentation is crucial to develop personalized campaigns. In reality, our data is much larger. For example we’ve dealt with datasets where we had more than a hundred features or millions of observations. In order to address such a problem, we leverage [MLlib](http://spark.apache.org/docs/latest/ml-guide.html), Spark’s machine learning (ML) library. [Spark](http://spark.apache.org/) is good for solving big data problems and supports Python, R, Scala and Java. For this example we will use PySpark, Spark’s Python API.

**Exploration Phase**

In the exploration phase we don’t test drive our code. We aim to find the right algorithm to solve our problem. We will use Jupyter notebook to play around with the data (see figure 1, the notebook can be found [here](https://github.com/datitran/spark-tdd-example/blob/master/Clustering%20Example%20with%20PySpark.ipynb)). In our case, [K-means](https://en.wikipedia.org/wiki/K-means_clustering) could be an appropriate solution for the given dataset. The core idea of k-means is to classify a given data set through a number of predefined clusters (assume k clusters) through a number of simple rules (usually minimizing the total-intra cluster variance).

{{< responsive-figure src="/images/jupyter-notebook-clustering-pyspark.png" class="center" >}}
<p align="center">
  Figure 1: Jupyter notebook of our clustering example with PySpark
</p>

Figure 2 depicts that k-means did a great job in separating our dataset. Clustering was fairly easy in this case due to the few data points and variables. In real life choosing the optimal k becomes less obvious because of more observations and/or features. Also k-means might not always be the best choice. We have to figure out which [clustering algotithm](http://scikit-learn.org/stable/modules/clustering.html#clustering) is best for a given data set. In this case, k-means seems to be a good choice.

{{< responsive-figure src="/images/output-kmeans.png" class="center" >}}
<p align="center">
  Figure 2: Our data along with the assigned labels from k-means and cluster centers
</p>

**Production Phase**

In the production phase, we want to operationalize our model. We want to re-calculate our cluster centers on a regular basis to incorporate information from new data points and then store the updated model to assign labels to fresh incoming data. In this phase, we use test-driven development to ensure that our codebase is clean, robust and trustworthy.

To test our code, we use a single node Spark application. On OS X, we can easily install Apache Spark using [brew](http://brew.sh/):

~~~ssh
brew install apache-spark
~~~

Afterwards we need to add this to the bash profile:

~~~ssh
export SPARK_HOME="/usr/local/Cellar/apache-spark/2.0.0/libexec/"
~~~

_Tip: You might want to change Spark logger setting from `INFO` to `ERROR`_

_Change logging settings:_

* _`cd /usr/local/Cellar/apache-spark/2.0.0/libexec/conf`_
* _`cp log4j.properties.template log4j.properties`_
* _Set info to error: `log4j.rootCategory=ERROR, console`_

_The main reason is that everything that happens inside Spark gets logged to the shell console e.g. every time you run actions like count, take or collect, you will see the full directed acyclic graph and this can be a lot if there are many transformations at each stage._

We create the test script `test_clustering.py` and implement clustering in `clustering.py` script. Now let’s start test driving our code:

~~~python
import os
import sys
import unittest

try:
    # Append PySpark to PYTHONPATH / Spark 2.0.0
    sys.path.append(os.path.join(os.environ["SPARK_HOME"], "python"))
    sys.path.append(os.path.join(os.environ[""SPARK_HOME""], "python", "lib",
                                 "py4j-0.10.1-src.zip"))
except KeyError as e:
    print("SPARK_HOME is not set", e)
    sys.exit(1)

try:
    # Import PySpark modules here
    from pyspark import SparkConf
    from pyspark.sql import SparkSession
except ImportError as e:
    print("Can not import Spark modules", e)
    sys.exit(1)
~~~

As you can see, we added the `SPARK_HOME` to our `PYTHONPATH`, so that it recognizes PySpark. Moreover, we import SparkSession which is now the new entry point into Spark since version 2.0.0.

Then within the test `setUp`, we define a single node Spark application and then stop it in the `tearDown`. This means that every time we run a test, a new Spark application is created and then will close after the test is done.

~~~python
# Import script modules here
import clustering

class ClusteringTest(unittest.TestCase):

    def setUp(self):
        """Create a single node Spark application."""
        conf = SparkConf()
        conf.set("spark.executor.memory", "1g")
        conf.set("spark.cores.max", "1")
        conf.set("spark.app.name", "nosetest")
        SparkSession._instantiatedContext = None
        self.spark = SparkSession.builder.config(conf=conf).getOrCreate()
        self.sc = self.spark.sparkContext
        self.mock_df = self.mock_data()

    def tearDown(self):
        """Stop the SparkContext."""
        self.sc.stop()
        self.spark.stop()
~~~

The next step is to mock the data. In our case since the data is small we can use it straight ahead. In practice the data can have millions observations or variables, we only need to take a subset of the real data. The amount and kind of data that you mock depends on the complexity of the data. If the data is fairly homogenous then imitating a small amount is enough. If the data is heterogenous more mock data to cover various possible cases, that might break the pipeline of our model training, will be needed.

~~~python
def mock_data(self):
    """Mock data to imitate read from database."""
    mock_data_rdd = self.sc.parallelize([("A", 1, 1), ("B", 1, 0),
                                         ("C", 0, 2), ("D", 2, 4),
                                         ("E", 3, 5)])
    schema = ["id", "x", "y"]
    mock_data_df = self.spark.createDataFrame(mock_data_rdd, schema)
    return mock_data_df
~~~

We then write a simple test case to check if the count of the mock data is equal to the number of elements created. This will ensure that spark application is running fine and the data is created appropriately. Testing a PySpark application is not easy. The error returned from a failing test is a mixture of Java and Python tracebacks. Hence debugging can get intense. Printing the results or using a debugger like `ipdb` can come in handy.

~~~python
def test_count(self):
    """Check if mock data has five rows."""
    self.assertEqual(len(self.mock_df.collect()), 5)
~~~

Now we can start with writing our first actual test. We created a DataFrame with a tuple of three values. [K-means]((http://spark.apache.org/docs/latest/api/python/_modules/pyspark/ml/clustering.html#KMeans)) in MLlib/ML, requires a DenseVector as input. So we need to convert the data type first so that it can be used in MLlib. An appropriate test can be to ensure that the data type is what we expect.

Here is the test:

~~~python
def test_convert_df(self):
    """Check if dataframe has the form (id, DenseVector)."""
    input_df = clustering.convert_df(self.spark, self.mock_df)
    self.assertEqual(input_df.dtypes, [("id", "string"),
                                       ("features", "vector")])
~~~

Now we can run our first test with `nosetests` or alternatively, we could also use `pytest`. What do we expect? It should fail! Good we can go ahead and implement our first function, `convert_df` which would make this test pass:

~~~python
def convert_df(spark, data):
    """Transform dataframe into the format that can be used by Spark ML."""
    input_data = data.rdd.map(lambda x: (x[0], DenseVector(x[1:])))
    df = spark.createDataFrame(input_data, ["id", "features"])
    return df
~~~

This implementation looks good and we can run our first test. It should pass! The next step can be to check if we rescale the variables correctly.

~~~python
def test_rescale_df_first_entry(self):
    """Check if rescaling works for the first entry of the first row."""
    input_df = clustering.convert_df(self.spark, self.mock_df)
    scaled_df = clustering.rescale_df(input_df)
    self.assertAlmostEqual(scaled_df.rdd.map(lambda x: x.features_scaled)
                           .take(1)[0].toArray()[0], 0.8770580193070292)

def test_rescale_df_second_entry(self):
    """Check if rescaling works for the second entry of the first row."""
    input_df = clustering.convert_df(self.spark, self.mock_df)
    scaled_df = clustering.rescale_df(input_df)
    self.assertAlmostEqual(scaled_df.rdd.map(lambda x: x.features_scaled)
                           .take(1)[0].toArray()[1], 0.48224282217041214)
~~~

Afterwards, we implement the method, `rescale_df`:

~~~python
def rescale_df(data):
    """Rescale the data."""
    standardScaler = StandardScaler(inputCol="features", outputCol="features_scaled")
    scaler = standardScaler.fit(data)
    scaled_df = scaler.transform(data)
    return scaled_df
~~~

The final test could be to check the results of the algorithm itself. In our case this is quite easy as our data was artificially made up. In real projects, it might not be easy to formulate the expected results especially.

~~~python
def test_assign_cluster(self):
    """Check if rows are labeled are as expected."""
    input_df = clustering.convert_df(self.spark, self.mock_df)
    scaled_df = clustering.rescale_df(input_df)
    label_df = clustering.assign_cluster(scaled_df)
    self.assertEqual(label_df.rdd.map(lambda x: x.label).collect(),
                     [0, 0, 0, 1, 1])
~~~

Finally, we can implement `assign_cluster`:

~~~python
def assign_cluster(data):
    """Train kmeans on rescaled data and then label the rescaled data."""
    kmeans = KMeans(k=2, seed=1, featuresCol="features_scaled", predictionCol="label")
    model = kmeans.fit(data)
    label_df = model.transform(data)
    return label_df
~~~

The tests can be refactored in the above implementation. You might be wondering that we haven’t discussed testing reading from database and storing the model. We have written unit tests here to test the functionality of clustering. Based on the data store in use you can write integration tests to see if we read and write to the database appropriately.

Always remember to test each phase of the data science pipeline right from data cleaning, feature extraction, model building, model evaluation to model storing, each individually and as a whole.



