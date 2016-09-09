---
authors:
- dat
- magarwal
categories:
- Data Science
- Machine Learning
- TDD
- Agile
- Pair Programming
date: 2016-09-09T09:03:56+02:00
draft: true
short: |
  Demystifying Test-Driven Development for Data Science.
title: Test-Driven Development for Data Science
---

_Joint work by [Dat Tran](https://de.linkedin.com/in/dat-tran-a1602320) (Senior Data Scientist) and [Megha Agarwal](https://uk.linkedin.com/in/agarwal22megha) (Data Scientist II)._

This is a follow up post on [API First for Data Science](http://engineering.pivotal.io/post/api-first-for-data-science/) and [Pairing for Data Scientists](http://engineering.pivotal.io/post/pairing-on-data-science/) with a specific focus on Test-Driven Development.

## Motivation

Test-Driven Development (TDD) has [plethora](http://pivotal-guides.cfapps.io/craftsmanship/tdd/) of advantages. You might be wondering how is TDD relevant for data science? While building smart apps, as Data Scientists, we are really contributing in shaping the brain of the application which will drive actions in real-time. We have to ensure that the core driving component is always behaving as expected, and this is where TDD comes to our rescue.

## Data Science and TDD

TDD for data science can be a bit more tricky than software engineering. Data science has a fair share of exploration involved where we are trying to find which features and algorithms will contribute best to solve the problem in hand. Do we strictly test drive all our features right from the exploratory phase, when we know a lot of them might not make into production? In the initial days of exploring how TDD fits the DS space, we tried a bunch of stuff. We highlight why we started test driving our DS use case and what worked the best for us.

Now imagine you are a logistics company and this shiny little 'smart' app has figured out the best routes for your drivers for the following day. Next day is your moment of truth! The magic better work, else you can only imagine the chaos and loss it can create. Now what if we say we can ensure that the app will always generate the most optimised route? We suddenly have more confidence in our application. There is no secret ingredient here! We can wrap up our predictions in a test case which allows us to trust the model only when it’s error rate is below a certain threshold.

Now I know you would ask, why would we put a model in production which doesn’t have the desired error rate at first place? But we are dealing with real life data here, things can go haywire pretty fast and we might end up with a broken or (if you are even more lucky) no model depending on how robust our code base is. TDD can not only help us ensure that nothing went wrong while developing our model but also prompts us to think what we want our model to achieve and forces us to think about edge cases where things can potentially go wrong. TDD allow us to be more confident.

So TDD saves the day, let’s start TDD everything? Not quite when it comes to data science. As discussed in one of our previous [blog posts](http://engineering.pivotal.io/post/api-first-for-data-science/), we have two phases in our data science engagements: exploratory and production. Test driving all the features and algorithms stringently during exploratory phase is bit of an overkill. We felt we were investing a lot of time in throw away work. That made the exploration phase quite intensive and slowed us considerably. Eventually we found a fine balance between the TDD and DS.

After the exploratory phase, once we have figured out which model and features suits the use case the best, we actually start test driving feature generation, model development and integration bits. Our model evaluation from the exploratory phase helps us set expectations around the model’s performance. We leverage this information in our TDD to make sure the model is behaving as expected in production.

Here are few things to keep in mind while test driving data science use cases:

1. Start TDD once you have a fair idea of what model and features will go in production.
2. Don’t test drive everything! Figure out the core functionalities of your code. For e.g. while feature generation, if a feature is generated using simple count functionality of SQL, trust that SQL’s in-build count functionality is already well tested. Writing another test around that won’t add much value.
3. We [pair-programming](http://engineering.pivotal.io/post/pairing-on-data-science/). So we test drive things in a ping pong manner, i.e. one person comes up with a test case, the companion makes it pass and then the role reverses.
4. Have separate unit and integrations test suite.
5. Mock behaviours where appropriate.
6. As a general rule of thumb, ensure your entire test suite runs within 10 min.

## Example

Let’s demonstrate TDD for data science with an example. Assume we are given two features x and y for five observations and the problem at hand is to cluster those data points into meaningful clusters.

| Obs | X | Y |
|:-----|:---|:---|
| A   | 1 | 1 |
| B   | 1 | 0 |
| C   | 0 | 2 |
| D   | 2 | 4 |
| E   | 3 | 5 |

This problem is typically an [unsupervised problem](https://en.wikipedia.org/wiki/Unsupervised_learning) where no labelled data is given and the goal is to find hidden structure in the data. Real-life examples can be found in many marketing divisions where their goal is to create meaningful clusters in order to target their customers efficiently with personalized campaigns.

Moreover, in reality, our data is much larger. For example we’ve dealt with datasets where we had more than one hundred features or where the number of observations could go into the millions. Therefore in order to solve such a problem, we leverage [MLlib](http://spark.apache.org/docs/latest/ml-guide.html), Spark’s machine learning (ML) library. [Spark](http://spark.apache.org/) is especially good for solving big data problems and runs on Java, Scala, R or Python. In our case, we favor Python as this is the first language choice for the majority of data scientist. Therefore we will use PySpark, Spark’s Python API.

**Exploration Phase**

In the exploration phase we don’t test drive our code but the main objective is to find the right algorithm to solve our problem. We will use a Jupyter notebook to do it (see figure 1, the notebook can be found [here](https://github.com/datitran/spark-tdd-example/blob/master/Clustering%20Example%20with%20PySpark.ipynb)). Looking at the data, for example [k-means](https://en.wikipedia.org/wiki/K-means_clustering) could be an appropriate solution which is a commonly used clustering algorithms. Its core idea is to classify a given data set through a number of predefined clusters (assume k clusters) through a number of simple rules (usually minimizing the total-intra cluster variance).

{{< responsive-figure src="/images/jupyter-notebook-clustering-pyspark.png" class="center" >}}
<p align="center">
  Figure 1: Jupyter notebook
</p>

From figure 2, we can see that k-means did a great job in separating our dataset. With respective to this, it was fairly easy due to the amount of data/variables and the way how it was generated. In real-life choosing the “optimal” number of k becomes less obvious if there are more observations and/or features.

However k-means might not be the best choice in all scenario. In that case we will have to experiment with different clustering algorithms. Few popular clustering algorithm can be found [here](http://scikit-learn.org/stable/modules/clustering.html#clustering). In this case, k-means seems to be a good choice.

{{< responsive-figure src="/images/output-kmeans.png" class="center" >}}
<p align="center">
  Figure 2: Our data along with the assigned labels from k-means and cluster centers
</p>

**Production Phase**

In the production phase, we want to operationalize our model.  For new data points, we want to re-calculate our cluster centers on a regular basis and then store the updated model to assign labels to fresh incoming data. In this phase, we use test-driven development to ensure that our codebase is clean, robust and trustworthy.

To test our code, we use a single node Spark application. On UNIX, we can easily install Apache Spark using [brew](http://brew.sh/), our primary package manager for OS X:

~~~ssh
brew install apache-spark
~~~

Then we need to add this to the bash profile:

~~~ssh
export SPARK_HOME="/usr/local/Cellar/apache-spark/2.0.0/libexec/"
~~~

> _Tip: It also make sense to change the logger setting from INFO to ERROR_

> Change logging settings:

> * `cd /usr/local/Cellar/apache-spark/2.0.0/libexec/conf`
> * `cp log4j.properties.template log4j.properties`
> * Set info to error: `log4j.rootCategory=ERROR, console`

> The main reason is that everything that happens inside Spark gets logged to the shell console e.g. every time you run actions like count, take or collect, you will see the full directed acyclic graph dissolve and this can be a lot if there are many transformations at each stage.

Now let’s start with creating our needed files, in our case we need `clustering.py` and `test_clustering.py`. After creating it let’s first start with the test script. We need to import various modules.

~~~python
import os
import sys
import unittest

try:
    # Append PySpark to PYTHONPATH / Spark 2.0.0
    sys.path.append(os.path.join(os.environ['SPARK_HOME'], "python"))
    sys.path.append(os.path.join(os.environ['SPARK_HOME'], "python", "lib",
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

As you can see, we added the `SPARK_HOME` to our `PYTHONPATH`, so that it recognizes PySpark. Moreover, we imported SparkSession which is now the new entry point into Spark since version 2.0.0.

Afterwards, we can import the modules from our `clustering.py` script. Then we define in the `setUp` a single node Spark application and then stop it in the `tearDown`. This means that every time we run a new test, a new Spark application is created and then will close after the test is done.

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

The next step is to mock the data. In our case since the data is small we can use it straight ahead. In practice if the data can have millions observations or variables, we only need to take a subset of the real data. The amount of data that you mock depends on the complexity of the data. If the data is fairly homogenous then imitating a small amount is enough. If the data is heterogenous more mock data is needed to cover all possible cases that might break the pipeline of our model training.

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

Our best practice is then to check if the count of the mock data is equal to the number we created. The reason is that testing PySpark application is not easy. The error you get from failing test is usually rubbish, a mixture of Java and Python tracebacks. Therefore checking the count of number ensures that the data is created. We would also suggest to print results out as much as possible if the tests fail.

~~~python
def test_count(self):
    """Check if mock data has five rows."""
    self.assertEqual(len(self.mock_df.collect()), 5)
~~~

In the next step, we can start with writing our first test. Looking at the dataset, we created a DataFrame with a tuple of three values. Looking at the [documentation]((http://spark.apache.org/docs/latest/api/python/_modules/pyspark/ml/clustering.html#KMeans)) of k-means in MLlib/ML, we can see that we need a DenseVector as input. So one of the first implementation that you need is to convert the data type so that it can be used in MLlib and the test could be to check if the data type is as expected.

The test looks like this:

~~~python
def test_convert_df(self):
    """Check if dataframe has the form (id, DenseVector)."""
    input_df = clustering.convert_df(self.spark, self.mock_df)
    self.assertEqual(input_df.dtypes, [('id', 'string'),
                                       ('features', 'vector')])
~~~

Now we can implement our first function:

~~~python
def convert_df(spark, data):
    """Transform dataframe into the format that can be used by Spark ML."""
    input_data = data.rdd.map(lambda x: (x[0], DenseVector(x[1:])))
    df = spark.createDataFrame(input_data, ["id", "features"])
    return df
~~~

This implementation looks good and we can run our first test. It should pass! The next test might be then to check if the rescaling of the variables is correct. Scaling is very important as it speeds up k-means to find the cluster centers and also is used to encounter the curse of dimensionality. For this test, we basically take results from our exploration phase. As said testing a data science model is not like testing a software features. There is a stochastic component and in order to remove the randomness we use the exploration phase to do it.

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

Afterwards, we implement our code:

~~~python
def rescale_df(data):
    """Rescale the data."""
    standardScaler = StandardScaler(inputCol="features", outputCol="features_scaled")
    scaler = standardScaler.fit(data)
    scaled_df = scaler.transform(data)
    return scaled_df
~~~

The final test could be then to check the results of the algorithm itself. With regards to our example, this is quite easy as our data was artificially made up. In real projects, the expected results are always not easy to get especially for supervised learning problem where the output is probabilities. Therefore one solution is to use the outputted class instead of probabilities or we could print out the probabilities and use this as our expected results. Always remember the main goal is to test the analytical pipeline from data cleaning, feature extraction, model building, model evaluation to model storing!

~~~python
def test_assign_cluster(self):
    """Check if rows are labeled are as expected."""
    input_df = clustering.convert_df(self.spark, self.mock_df)
    scaled_df = clustering.rescale_df(input_df)
    label_df = clustering.assign_cluster(scaled_df)
    self.assertEqual(label_df.rdd.map(lambda x: x.label).collect(),
                     [0, 0, 0, 1, 1])
~~~

Finally, we can define our last function:

~~~python
def assign_cluster(data):
    """Train kmeans on rescaled data and then label the rescaled data."""
    kmeans = KMeans(k=2, seed=1, featuresCol="features_scaled", predictionCol="label")
    model = kmeans.fit(data)
    label_df = model.transform(data)
    return label_df
~~~

As you can see from the above implementation, we still could do some refactoring like taking the arguments out of the function and set global variables. Now you might wonder that we we haven’t talked about reading from database and storing the model. As already mentioned we don’t test this. This is basically real testing with hitting a real database or storing it somewhere so that you can use it on new data.



