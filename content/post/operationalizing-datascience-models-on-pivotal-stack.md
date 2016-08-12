---
authors:
- vatsan
- regu
- jin
- kaushik
categories:
- Data Science
- Greenplum
- SCDF
- PCF
- GemFire
date: 2016-08-11T18:00:17-07:00
short: |
  
title: Operationalizing Data Science Models on the Pivotal Stack
---

(Joint work by [Srivatsan Ramanujam](https://www.linkedin.com/in/srivatsan-ramanujam-88891b7), [Regunathan Radhakrishnan](https://www.linkedin.com/in/regu-radhakrishnan-4b76bb1), [Jin Yu](https://au.linkedin.com/in/jin-yu-24412838), [Kaushik Das](https://www.linkedin.com/in/kadas) )

At [Pivotal Data Science](https://pivotal.io/data-science), our
primary charter is to help our customers derive value from their data
assets, be it in the reduction of cost or by increasing revenue by
offering better products and services. While we are not working on
customer engagements, we engage in R&D using our wide array of products.
For instance, we may contribute a new module to
[PDLTools](https://github.com/pivotalsoftware/PDLTools) or
[MADlib](https://github.com/apache/incubator-madlib) - our distributed
in-database machine learning libraries, we might build end-to-end demos
such as [these](https://github.com/vatsan/dspcfboilerplate) or
experiment with new technology and blog about them
[here](https://blog.pivotal.io/tag/data-science).

Last quarter, we set out to explore data science microservices for operationalizing our models for real-time scoring.
Microservices have been the most talked about topic in many Cloud
conferences of late. They’ve gained a large fan following by application
developers, solution architects, data scientists and engineers alike.
For a primer on microservices, we encourage you to checkout the free
e-book from Matt Stine on [“Migrating to Cloud Native Application
Architectures”](https://pivotal.io/platform/migrating-to-cloud-native-application-architectures-ebook).
For web scale companies like Facebook, Google, Amazon or Netflix,
building and deploying data science models might be second nature thanks
to years of R&D investment in their technology stack. However,
enterprises embracing open source platforms like [Cloud
Foundry](https://www.cloudfoundry.org/) and big data processing
environments like [Greenplum](http://greenplum.org/),
[HAWQ](http://hawq.incubator.apache.org/) or
[Geode](http://geode.apache.org/) need quick wins to demonstrate business value through easily
deployable data science model training and scoring pipelines. We set out
to explore how easy it was to build two such model training and scoring
pipelines using open source toolkits from the Pivotal technology stack
including [Pivotal CF](https://pivotal.io/platform) and [Pivotal
BDS](https://pivotal.io/big-data/pivotal-big-data-suite).

**Objective**

In this blog, we describe the data science microservices we built for real-time scoring and
link you to all our relevant code so that you can build it out by
yourself on your own PCF and BDS environments. Our goal was to describe a
reference architecture for operationalizing some of our data science models and demonstrate a proof-of-concept by building
it out. These by no means should be considered to be production ready models nor are the microservices necessarily 12-Factor compliant.
They serve to illustrate the process of deploying data science models on a PaaS like [PCF](https://pivotal.io/platform).

**Data science models**

Text analytics is a common theme in many of our customer engagements.
We’ve applied text analytics and NLP techniques to [predict
churn](https://blog.pivotal.io/data-science-pivotal/features/all-things-pivotal-podcast-episode-10-discussing-natural-language-processing-and-churn-analysis-with-mariann-micsinai-and-niels-kasch),
understand [customer satisfaction or to distill hundreds of thousands
of call center transcriptions into higher level
topics](http://www.slideshare.net/SrivatsanRamanujam/a-pipeline-for-distributed-topic-and-sentiment-analysis-of-tweets-on-pivotal-greenplum-database).
We described some of these techniques by applying it to a fun problem of
analyzing the tweets for NY primaries earlier this year ([Data Science
101: Using Election Tweets to Understand Text
Analytics](https://blog.pivotal.io/data-science-pivotal/features/data-science-101-using-election-tweets-to-understand-text-analytics)).

For this work, we used [sentiment scoring model for tweets](http://www.slideshare.net/SrivatsanRamanujam/a-pipeline-for-distributed-topic-and-sentiment-analysis-of-tweets-on-pivotal-greenplum-database) and the
[doc2vec](https://cs.stanford.edu/~quocle/paragraph_vector.pdf),
[word2vec](https://papers.nips.cc/paper/5021-distributed-representations-of-words-and-phrases-and-their-compositionality.pdf)
models for generating topically related tweets using a KNN algorithm. We
used the implementations in gensim for training our doc2vec model for
obtaining vector representation of tweets. [This
notebook](https://github.com/vatsan/text_analytics_on_mpp/blob/master/neural_language_models/01_news_groups_doc2vec.ipynb)
gives a more detailed walk through of training these models.

Our goal is to demonstrate how to convert the scoring functions of the
sentiment analyzer and the tweet recommender into microservices and
invoke them through a stream processing engine like [Spring Cloud Dataflow](https://cloud.spring.io/spring-cloud-dataflow/). All the components of
the scoring functions can be deployed on CloudFoundry to reap the
benefits of a Cloud Native architecture that Matt describes in his
[book](https://pivotal.io/platform/migrating-to-cloud-native-application-architectures-ebook).

**Reference Architecture**

{{< figure src="/images/operationalizing-datascience-models/1_reference_architecture.png" class="center" >}}

We usually spend between 6-12 weeks on customer
engagements. Once a business problem has been identified and all
relevant data sources have been loaded into a data lake, we proceed to
build statistical models using big data toolkits like
[MADlib](http://madlib.incubator.apache.org/),
[PDLTools](https://github.com/pivotalsoftware/PDLTools) and procedural
languages like
[PL/Python](http://www.slideshare.net/SrivatsanRamanujam/all-thingspythonpivotal)
and [PL/R](https://github.com/pivotalsoftware/gp-r). We use Jupyter
notebooks extensively, with all the heavy lifting happening on a cluster
in the backend and all exploratory data analysis and plotting happening
on the client. Jupyter notebooks make the process of knowledge transfer
and hand-off to our customers effective. Since most of a data
scientist’s time is spent in building, monitoring and updating models,
there should be a simple mechanism for deploying these models for
scoring. The LinkedIn engineering team talked about this “last mile”
problem in their [SIGMOD’ 13
paper](http://dl.acm.org/citation.cfm?id=2463707&dl=ACM&coll=DL&CFID=813141550)
in greater detail. We wrote a Jupyter magic command to automate model
deployment. Our scoring engine is a collection of microservices built
using [SpringBoot](http://projects.spring.io/spring-boot/). We use
[Spring Cloud
DataFlow](https://cloud.spring.io/spring-cloud-dataflow/) as our stream
processing engine and
[GemFire](https://pivotal.io/big-data/pivotal-gemfire) as our
in-memory data grid to cache the data from our analytic data warehouse
(Greenplum) and perform lightweight in-memory analytics. All the components of our scoring pipeline run within
CloudFoundry. The analytics datawarehouse (Greenplum) can be within or
outside of CloudFoundry, as the models can be trained and iterated upon
offline.

The input to our scoring pipeline is a stream of live tweets, buffered
using RabbitMQ (can be substituted with Kafka). Our pipeline compute a
sentiment score for these tweets and also identifies the most similar
tweets from a historical database of tweets.

**Environment**

We spun up a PCF environment on vSphere and through the OpsManager we
installed [GemFire for
PCF](https://network.pivotal.io/products/p-gemfire), [Redis for
PCF](https://network.pivotal.io/products/p-redis), [RabbitMQ for
PCF](https://network.pivotal.io/products/pivotal-rabbitmq-service), all
downloadable from [PivNet](https://network.pivotal.io/). To install
and instantiate GemFire, you’ll also need to install the GemFire CLI for
CF plugin. Detailed instructions on setting up your PCF environment can
be found below. Our Greenplum datawarehouse (GPDB) was a single node
instance running in a Linux box, that was in the same network as our PCF
instance.

<script src="https://gist.github.com/vatsan/654e52ed205eef8b350c4dbc8e892bd4.js"></script>

**Spring Cloud Data Flow**

Spring Cloud Dataflow (SCDF) is a framework for creating composable data
microservices. This makes is easy to create data ingestion pipelines,
real-time analytics etc. The framework has the following components:

-   SCDF shell

-   SCDF server (Dataflow Server)

-   A target runtime such as Cloud Foundry or YARN

-   [Spring Boot Applications](http://cloud.spring.io/spring-cloud-stream-app-starters/) which run as data [sources, processors or sinks](https://github.com/spring-cloud/spring-cloud-stream-app-starters) within the target runtime

-   A binder (RabbitMQ/Kafka) for message passing between these spring boot applications.

{{< figure src="/images/operationalizing-datascience-models/2_scdf.png" class="center" >}}

From the SCDF shell, one can connect to a SCDF server to register spring
boot applications as sources, processors or sinks using the *app
register* command. In the figure above, **http** is a spring boot
application acting as a data source and **cassandra** is another spring
boot application acting as a data sink. Then, one can create a SCDF
stream consisting of sources, processors and sinks (e.g http |
cassandra) from the SCDF shell which gets submitted to the SCDF server.
The SCDF server running in the target runtime is responsible for
spinning up the spring boot applications and ensuring that the messaging
pipeline is setup between these applications. The messaging pipeline
could be RabbitMQ or Kafka.

In this project, we wanted to create a SCDF pipeline for the following
two analytic tasks:

-   Sentiment Scoring of Tweets
-   Recommender for Tweets

To start-off, you'll first need to deploy the SCDF server into your PCF environment, bring up the SCDF shell, register your modules and create the appropriate streams. Sample instructions for these are below.

<script src="https://gist.github.com/vatsan/7b7617bc22613ad508b3d280a2f1458b.js"></script>

In the following sections, we will describe the custom SCDF components
that we developed to create these two pipelines.

**Sentiment Scoring Of Tweets**

We performed the following steps to assign a sentiment score for each of
the tweets:

-   Tokenization and part-of-speech tagging of tweets using [gp-ark-tweet-nlp](https://github.com/vatsan/gp-ark-tweet-nlp) - a PL/Java wrapper on [Ark-Tweet-NLP](http://www.cs.cmu.edu/~ark/TweetNLP/) from CMU,
    that enables us to perform [part-of-speech tagging at scale on our MPP
    databases](https://blog.pivotal.io/data-science-pivotal/products/twitter-nlp-example-how-to-scale-part-of-speech-tagging-with-mpp-part-2).

-   Extract two word-phrases which match a set of certain patterns based on a modification of [Turney’s algorithm](http://www.aclweb.org/anthology/P02-1053.pdf).

-   Compute sentiment score for the extracted phrases based on [mutual information](https://en.wikipedia.org/wiki/Mutual_information).

-   Finally, each tweet gets a score based on the phrases that are present in that tweet. This method of computing sentiment score is completely unsupervised and can be bootstrapped from a dictionary of positive and negative adjectives.

{{< figure src="/images/operationalizing-datascience-models/3_sentiment_scoring_pipeline.png" class="center" >}}

Figure above illustrates all the data microservices that we developed
within SCDF and GemFire to deploy a pipeline that can compute sentiment
scores in real-time on incoming tweets.

-   **Twitter Source:** This is a built-in SCDF component that connects
	to a twitter account and can act as a source of tweets. This
	component takes as input twitter credentials and twitter
	stream properties. More details can be found
	[here](https://github.com/spring-cloud/spring-cloud-stream-app-starters/tree/master/twitter/spring-cloud-starter-stream-source-twitterstream).

-   **Tweet Tokenization:** This SCDF component takes in a tweet and
    performs the following transformations: 
    1. Tokenization 
    2. Part of speech tagging using [ArkTweetNLP](http://www.cs.cmu.edu/~ark/TweetNLP/) 
    3. Extraction of phrases according to [modified Turney
    algorithm](http://www.slideshare.net/SrivatsanRamanujam/a-pipeline-for-distributed-topic-and-sentiment-analysis-of-tweets-on-pivotal-greenplum-database)
    for sentiment scoring
    
    For instance, if the tweet is “hello
    beautiful fantastic happy world”, it would be tokenized and tagged
    as hello(!) beautiful(A) fantastic(A) happy(A) world(N). Then,
    according to Turney’s algorithm we would search through all
    possible trigrams and choose a subset that is in accordance with
    the rules of Turney’s algorithm. In this example, it would extract
    the phrase “beautiful fantastic happy”.

-   **Sentiment Compute Processor:** This SCDF component takes in the
    matching phrases present in each tweet and sends a REST API
    request to GemFire to retrieve the polarity of those phrases.
    Polarity of phrases is cached in GemFire which is a result of
    analyzing twitter training data in Pivotal’s GPDB. Finally,
    average polarity of all the matching phrases in a tweet is
    reported as the sentiment score for the incoming tweet.

The snippet to accomplish this is shown below:

<script src="https://gist.github.com/regunathanr/9fd9a0122cb0d42973d5209f15970c67.js"></script>


-   **REST API:** This SCDF component is a simple processor that takes
    the incoming message and exposes it at a REST endpoint. The
    snippet to accomplish this is shown below:

<script src="https://gist.github.com/regunathanr/bc59ab15d9b688c9d7e473de018943e0.js"></script>

-   **Logging Sink:** This SCDF component is a simple sink end-point for
    debugging purposes. The complete snippet for this component is
    given below:

<script src="https://gist.github.com/regunathanr/1a64177dc706514a8e3c8545e6350b26.js"></script>

Note that within this implementation of ***LoggingSink*** there is no
explicit mention of the binder (RabbitMQ/Kafka). This also holds true
for other SCDF components. The choice of binder is specified in pom.xml
file while building this spring boot application. The implementation of
the application is independent of the messaging pipeline and you don’t
have to change a line of code to build the same spring boot application
from Kafka to RabbitMQ.

**Recommender for Tweets**

{{< figure src="/images/operationalizing-datascience-models/4_tweet_recommender_pipeline.png" class="center" >}}

All of the components are the same as the components in the sentiment
scoring pipeline except for the Tweet Recommender processor. This SCDF
component takes individual tokens from the tweet. For instance, if the
tokens are {W<sub>1</sub>,W<sub>2</sub>...W<sub>n</sub>} then for each W<sub>i</sub>, we send a REST API
request to GemFire for the corresponding wordvector V<sub>i</sub>. Then, all the
V<sub>i</sub>’s are averaged to obtain a vector representation for the tweet
(V<sub>avg</sub>). Finally, we make another GemFire REST API call for finding
K-Nearest neighbors to retrieve similar tweets to the incoming tweets.

**GemFire**

GemFire is a distributed in-memory data grid that provides low latency
data access, in-memory computing along with other distributed data
management capabilities. A GemFire cluster (a distributed system)
typically consists of three key components:

-   **Locators** keep track of cluster members, and provide
    load-balancing services.

-   **Cache servers** (or nodes) are mainly used for hosting data and
    executing GemFire processes. User-defined Java functions can be
    registered on cache servers (known as server-side functions), and
    executed in parallel on distributed servers hosting relevant data.
    Such a data-aware function execution mechanism enables fast
    parallel processing.

-   **Regions** are analogous to tables in a relational database. They
    store data as key-value pairs. A region can be replicated or
    partitioned across multiple cache servers, and can also be
    persisted to disk.

GemFire provides a command-line utility,[
](http://gemfire.docs.pivotal.io/docs-gemfire/latest/tools_modules/gfsh/chapter_overview.html)[gfsh](http://gemfire.docs.pivotal.io/docs-gemfire/latest/tools_modules/gfsh/chapter_overview.html),
for cluster configuration and management. Alternatively, configuration
can be done using[
](http://gemfire.docs.pivotal.io/docs-gemfire/latest/reference/topics/chapter_overview_cache_xml.html#cache_xml)[cache.xml](http://gemfire.docs.pivotal.io/docs-gemfire/latest/reference/topics/chapter_overview_cache_xml.html#cache_xml)
and[
](http://gemfire.docs.pivotal.io/docs-gemfire/latest/reference/topics/gemfire_properties.html#gemfire_properties)[gemfire.properties](http://gemfire.docs.pivotal.io/docs-gemfire/latest/reference/topics/gemfire_properties.html#gemfire_properties)
files; for example you can create regions in cache.xml. Cache servers in
a GemFire cluster can share the same cache.xml, or have their individual
cache configurations.

In this project we used GemFire as the real-time tier to surface
analytics results produced on GPDB to Spring Boot applications. To that
end, we created result publishing microservice on GemFire along with a
Jupyter “publish” magic command to execute the microservice from a
Jupyter notebook. We also implemented GemFire microservices as
server-side functions for lightweight in-memory analytics. Through
GemFire REST APIs Spring Boot applications can query cached analytics
results, and invoke server-side functions without the need of pulling
data over to the application side for processing.

**GemFire-GPDB Connector**

The GemFire-GPDB connector is a GemFire extension that supports parallel
import and export of data between GemFire regions and GPDB tables; see[this
presentation](http://www.slideshare.net/PivotalOpenSourceHub/geodesummit-large-scale-fraud-detection-using-gemfire-integrated-with-greenplum)
for a quick introduction. Using the GemFire-GPDB connector we built a
result publishing microservice that publishes analytics results produced
on GPDB (including phrase polarity/sentiment scores, vector
representations of words and tweets) to GemFire to support streaming
applications.

The connector transfers data directly between GPDB segments and GemFire
cache servers in parallel via GPDB’s external table interface, while the
control of the data movement is communicated from a GemFire server to
GPDB master node via JDBC connection. Each GPDB table is mapped to a
GemFire region. The mapping and the specification of the JDBC connection
are given as part of cache configuration in cache.xml. The example
configuration below maps the “sentiment\_score” table to the
“SentimentScore” region. An empty region named “SentimentScore” will be
created upon the start of the GemFire cluster. The JDBC connection is
bound to a[
](http://gemfire.docs.pivotal.io/docs-gemfire/latest/developing/transactions/configuring_db_connections_using_JNDI.html)[JNDI
data
source](http://gemfire.docs.pivotal.io/docs-gemfire/latest/developing/transactions/configuring_db_connections_using_JNDI.html)
backed by GPDB.

<script src="https://gist.github.com/yuj18/7a7af47e81ab3f90298daafbc4ae9e09.js"></script>

Having configured the GemFire cluster, loading data from GPDB to GemFire
can simply be implemented as a GemFire server-side function as shown
below:

<script src="https://gist.github.com/yuj18/ac7bc3e9d83e816fd059bca806c61f1d.js"></script>

The “execute” method performs the work of the microservice. When
executed on a specific region, it clears the region before loading the
corresponding GPDB table. The function can be invoked from the gfsh
shell:

<script src="https://gist.github.com/yuj18/bc9d4a296bd226a429a84e4e31b0af7c.js"></script>

or via GemFire REST interface, e.g.:

<script src="https://gist.github.com/yuj18/1f5600c931d6206da493caba2f1322b6.js"></script>

Once data is loaded to a GemFire region, it can be conveniently queried
through REST API:

<script src="https://gist.github.com/yuj18/32fe807f968849083a1e38ffcc819927.js"></script>

**Jupyter Magic**

From a data scientist perspective, it is desirable to be able to run the
result publishing microservice in the same development environment as
the development of analytics models. GemFire REST APIs make this
possible. The following code creates a Jupyter magic command for loading
a GPDB table to GemFire from within a Jupyter notebook.The “publish”
command simply sends a REST API request to GemFire to load the
“sentiment\_score” table to its corresponding GemFire region. Check
out this [GitHub
project](https://github.com/vatsan/gp_jupyter_notebook_templates.git)
for the complete implementation.

<script src="https://gist.github.com/yuj18/df145c01b815d16c7413d342dc4dc6e0.js"></script>

**In-Memory Analytics**

In this project we also exploited GemFire’s in-memory computing
capability for real-time analytics microservices. The bulk of the
analytics work is done on GPDB in an offline fashion. GemFire is
primarily used as an in-memory data store to surface the results from
GPDB. But in the scenario where real-time analytics involving the use of
streaming data is desired, it makes more sense to push analytics to the
memory tier as well. This is the case for the tweet recommender as
introduced earlier. For each incoming tweet, it recommends similar
historical tweets in real-time. This can be formulated as a K nearest
neighbor (KNN) search problem. We implemented the KNN search as a
GemFire server-side function. Given a tweet, the function will return K
similar tweets that are cached in a partitioned GemFire region.

A GemFire function can be executed on a particular region or on a
particular set of servers. For a region-dependent function GemFire
automatically determines which servers host the data, and only
distributes the work to the relevant servers for parallel execution. The
flexibility of deciding where to run a function makes it easy to
implement the KNN search in a MapReduce fashion. In the Map phase a
region-dependent KNN search is carried out across multiple servers,
finding local KNNs in parallel from each partition of the region storing
the tweets. In the Reduce phase the local KNN results are collected to a
single server, and aggregated to produce KNNs with respect to the entire
dataset. The tweet recommender processor only need to interact with the
aggregate function (via REST API) to obtain recommended tweets.

The following snippet details the implementation of local KNN search.
The key is to apply KNN search to local data only, using the
“[PartitionRegionHelper.getLocalDataForContext](http://gemfire.docs.pivotal.io/docs-gemfire/latest/developing/function_exec/function_execution.html#function_execution__li_A5CAF0DB522D4B13B409000336D07F20)”
method.

<script src="https://gist.github.com/yuj18/8a655936bb6cddf8d4e9dc87c3b23a59.js"></script>

The local KNN search is initiated by the aggregate function. The use of
the “FunctionService.onRegion” method as shown in the code below
instructs GemFire to run the KNN search locally only on concerned
servers. The local results are collected through “ResultCollector” for
final processing.

<script src="https://gist.github.com/yuj18/972685ba66df0b8725089bfdaf2ea6c7.js"></script>

The aggregate function is expected to run on a single server (can be any
server in the cluster). The server essentially acts as a master node for
the MapReduce process. The following is an example REST API call to the
KNN function:

<script src="https://gist.github.com/yuj18/b1688ffa711da41d9107371ebce52ea4.js"></script>

**Deploying GemFire Microservices on PCF**

Deploying GemFire microservices on PCF involves uploading a[
](https://docs.pivotal.io/gemfire-cf/using_the_data_service.html#configuring_service_instance)[configuration
zip
file](https://docs.pivotal.io/gemfire-cf/using_the_data_service.html#configuring_service_instance)
to the GemFire cluster on PCF. The zip file should contain microservice
implementation jars, any dependency jars, cache.xml, and a cluster
configuration file if needed. The “cf restart-gemfire” command can start
the GemFire cluster with the uploaded configuration as below:

<script src="https://gist.github.com/yuj18/f7d3cc8fc7013f52d1bb5aab44a1870a.js"></script>

Note that GemFire REST API is enabled, which provides immediate access
to all the implemented microservices (server-side functions). The
following example REST API call executes in-memory KNN search on PCF:

<script src="https://gist.github.com/yuj18/90a7f96072a645626bef63f66e678d44.js"></script>

**Summary**

In this project, we have explored and implemented a set of three data
microservices that would help a data scientist’s workflow in deploying a
model into production.

-   The first data microservice is to help a data scientist push a
    trained model from an MPP environment (Greenplum DB or HDB) to an
    in memory data grid (GemFire) where model scoring happens on
    incoming real-time data.

-   The second set of data microservices is to help a data scientist
    set-up a data pipeline using Spring Cloud Dataflow components.
    This set of SCDF components acting as data sources, processors and
    sinks can help the data scientist transform the data sources in a
    way needed for model scoring. Furthermore, this kind of data
    pipeline can be used by data scientists to gather data from
    production workflows for developing models.

-   The third set of data microservices is to score incoming feature
    vectors in real-time and is implemented in an in-memory data
    grid (GemFire) for scalability. If the model requires caching of
    features and multiple data sources for feature extraction, then
    the feature extraction also needs to happen here before scoring.
