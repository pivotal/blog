---
authors:
- ewayman
categories:
- Data Science
- Luigi
- Greenplum
- Python
- SQL
date: 2017-05-30T14:41:33-07:00
short: This post shows how we use Luigi as a pipeline tool to manage a data science workflow.  We walk through an example analyzing network traffic logs.
title: Using Luigi Pipelines in a Data Science Workflow
---

## Introduction

In this post we explain how to use pipelines as part of an agile data science workflow.  The primary benefits pipelines provide are

* **Automation:** We can run an end-to-end workflow with a single command by chaining tasks with explicitly defined dependencies.
* **Failure Handling:** A pipeline enables monitoring of a workflow by tracking the status of each task. In the event of a failure or interruption, we can alert a user and restart our pipeline from the last completed task.
* **Parameterization:** Variations of a workflow can be run with new data sources or model parameters by making changes to a single configuration file. 
* **Testing:** Implementing tests into our workflow tasks ensures the quality of our data sources at each step and makes it easier to pinpoint errors.

There are many pipelining tools available: [Spring Cloud Data Flow](http://cloud.spring.io/spring-cloud-dataflow/) for production environments, [Airflow](https://airflow.incubator.apache.org/) and [Luigi](https://luigi.readthedocs.io/en/stable/) for general batch processes, and [Azkaban](https://azkaban.github.io/) and [Oozie](http://oozie.apache.org/) for Hadoop workflows.  We will walk through an example of a Luigi pipeline we used to analyze network traffic logs stored in [Greenplum Database (GPDB)](http://greenplum.org/).  We chose Luigi because it is simple to use and written in Python, a staple language for data science. 

{{< responsive-figure src="/images/pca_workflow.png" class="center" >}}

## Mechanics of a Luigi Pipeline

The example code base and a summary of the use case can be found [here](https://github.com/ericwayman/luigi_gdb_pipeline_demo).  At a high level, our workflow consists of detecting anomalous network traffic using [principal component analysis](https://en.wikipedia.org/wiki/Principal_component_analysis).  In total, we developed 24 models - one for each hour of the day.  We define the  pipeline dependency graph  in a single script [```pipeline.py```](https://github.com/ericwayman/luigi_gdb_pipeline_demo/blob/master/pca_pipeline/pipeline.py).  Below we show the header of ```pipeline.py```, which configures our database connection and pipeline parameters.

<script src="https://gist.github.com/ericwayman/250263a2bf87069cb15d9014d0829296.js"></script>

First, we initialize a ```PSQLConn()``` object defined in [```utils.py```](https://github.com/ericwayman/luigi_gdb_pipeline_demo/blob/master/pca_pipeline/utils.py#L24-L41) to create a database connection factory using the [psycopg2](https://github.com/psycopg/psycopg2) library.  We store as environment variables the credentials to connect to our GPDB database.  Next we define three classes: ```DatabaseConfig```, ```ModelConfig``` and ```PathConfig``` which inherit from the ```luigi.Config``` class.  These classes configure table and column names in the database, model hyper-parameters, and output path parameters respectively. The values for these variables are set in the pipeline configuration file: [```luigi.cfg```](https://github.com/ericwayman/luigi_gdb_pipeline_demo/blob/master/pca_pipeline/luigi.cfg).  By default Luigi searches for this file in the current working directory, but we can also set its path with the environment variable: [```LUIGI_CONFIG_PATH```](http://luigi.readthedocs.io/en/stable/configuration.html).  For each section in ```luigi.cfg``` we define a corresponding class with an identical name in ```pipeline.py``` and create a class attribute for each entry in the section.

## Defining a GPDB Task

The building blocks of a pipeline are tasks.  The dependency graph for all tasks that make up the workflow in our example is shown below.

{{< responsive-figure src="/images/luigi_pipeline_dependency_graph.png" class="center small" >}}

The workflow consists of 24 overlapping branches, one for each model.  Each branch is broken down into 5 types of tasks as follows

* Initializing all the necessary schema and user defined functions in our pipeline.
*  Some pre-processing of the raw data.
* For each of the 24 hours we  use the output of the previous step to create a table that is the input table for a model.
* For each of the 24 models, run the MADlib PCA algorithm, which operates in parallel across GPDB nodes.
* Using the output of the PCA models, flag users with highly variant activity.


Below is the code for a task which takes in a table representing a sparse matrix and computes the principal components in an output table using the [```pca_sparse_train```](https://madlib.incubator.apache.org/docs/latest/group__grp__pca__train.html) function in MADlib.  
<script src="https://gist.github.com/ericwayman/283c252d20651e4c54c90d6a05c55df6.js"></script>


A general pipeline task is specified by writing a class which inherits from ```luigi.Task``` and by defining three methods: ```requires()```, ```run()```, and ```output()```.

The ```requires()``` method returns a list of the previous task dependencies: 
~~~~
[CreatePCAInputTable(date=self.date,hour=self.hour_id)]
~~~~
A Luigi task is uniquely specified by its class name and the value of its parameters.  That is, two tasks with the same class name and parameters of the same values are in fact the same instance.  Luigi parameters serve as a shortcut for defining task constructors.  ```RunPCATask()``` and ```CreatePCAInputTable()```each have two parameters: ```date``` and ```hour_id```, which represent the current day and the hour of the day we are modeling respectively.    In the ```requires()``` method, we  specify that ```RunPCATask()``` depends on the input matrix table for the same ```hour_id``` and with all data up to the current day.  So each day we run our pipeline, this task is executed 24 times, once for each value of ```hour_id```.

The ```output()``` method returns a Luigi target object such as a local file, a file on HDFS, or an entry in a database table to indicate successful completion of a task. A target class contains one method: ```exists()``` which returns ```True``` if it exists.  Luigi considers a task successfully completed if and only if the target defined in the task’s ```output()``` method exists.  Before executing  ```RunPCATask()```, Luigi checks for the existence of the output target from the ```CreatePCAInputTable()``` task with the same values for the ```date``` and ```hour_id``` parameters.  If this target does not exist, Luigi will first run the required task.

The ```run()``` method contains the logic for executing the task.  Each of our tasks consists of the following steps: establishing a connection to the GPDB instance, executing a SQL script in the database, and writing to the output file.  The key point is that the query is executed and new tables are created remotely in the database.  The pipeline simply acts as a tool to parameterize, coordinate and run SQL queries in GPDB.  The only data that is written locally to disc is what we write to the ```output()``` file.  For this reason we should use caution to not write large volumes of data to the output file.
After connecting to the database and setting our query parameters, we call the function ```find_principal_components()``` in [```utils.py```](https://github.com/ericwayman/luigi_gdb_pipeline_demo/blob/master/pca_pipeline/utils.py#L73-L82) reproduced below.
<script src="https://gist.github.com/ericwayman/d8d379335b069af5071ea24ae9ce8669.js"></script>

This function is a simple python wrapper around the PL/pgSQL function we created during the exploratory phase of our analysis to drop/create the necessary tables and execute PCA using MADlib.  To safeguard against SQL injection, we bind the python arguments to our function to the query string by using the ```mogrify()``` method and wrapping our parameters in a custom identifier class [```QuotedIdentifier```](https://github.com/ericwayman/luigi_gdb_pipeline_demo/blob/master/pca_pipeline/utils.py#L7-L22), which ensures that the arguments are valid SQL.  The identifier checks the function arguments consist solely of  alpha-numeric characters, underscores and a single period for parameters containing a schema with a table name.

The final step after running our query is writing to the output target.  For this example, we simply select the first row of the output table and copy it to a file.  This verifies that we successfully created and populated a new table with the correct column structure in our database.  Alternatively, it may be useful to write sanity checks or log interesting info about the new table such as the number of rows in the output table or the variances of the principal components for example.  For our final task, which generates a table of anomalous users, we write the list of users to a file for further investigation.

If our task consists of simply executing a query in the database and we do not wish to record any info to a file, we can implement our task as a subclass of the Luigi ```PostgresQuery``` task.  The output for this task is a ```PostgresTarget```, which is an entry in a marker table which contains a list of the tasks completed and their date of execution.  For example, to implement the ```InitializeUserDefinedFunctions()```  task as a ```PostgresQuery``` task, we write:

<script src="https://gist.github.com/ericwayman/738cacc74dcc54f83fe3dc874d5cdc37.js"></script>

The variable ```table``` defines the task description in the marker table, and ```query``` defines the SQL executed by the task.  Here we simply call the helper function ```initialize_user_defined_functions()``` in [```utils.py```](https://github.com/ericwayman/luigi_gdb_pipeline_demo/blob/master/pca_pipeline/utils.py#L48-L52) that opens the relevant SQL script as a file object and returns the content as a string since no formating with parameters is required.  The difference between a ```PostgresQuery``` task and our other tasks are essentially stylistic.

To complete the pipeline, we define our pipeline dependency graph in a final wrapper task which inherits from ```luigi.WrapperTask```.  In the ```requires()``` method of the wrapper class, we return a list of all the tasks of the pipeline.  To run the full pipeline end-to-end, we simply call the wrapper task from command line.  Wrapper tasks are particularly useful for pipelines such as ours where we want to call a task multiple times with different parameters.
<script src="https://gist.github.com/ericwayman/111f8fd9c45b7519f78a9a8168ec408b.js"></script>
    
## Testing Pipelines

A major advantage to wrapping our workflow into a pipeline is the ability to incorporate data level tests into our workflow.  In our example pipeline we run a simple test checking each column of newly created tables for the presence of null values.  Another example of a commonly useful data level test is checking the cardinality of the join keys before joining two tables, as a duplicate record could cause a many-to-many join, which may not be the intended behavior.  With tests that break the workflow early on failure and alert the user, we make it easier to pinpoint issues in the data and can save on wasted computation time.  To notify others of pipeline failures, Luigi supports [email alerts](http://luigi.readthedocs.io/en/stable/configuration.html#email)  which can be configured in the ```email``` section of the ```luigi.cfg``` config file.  

Before running a pipeline in our analytics environment on the full data set, we recommend testing it locally on a small sample of data.  On smaller data sets we can discover bugs quicker, and testing locally eliminates the risk of accidentally deleting a table in our analytics environment. To run GPDB locally, we install the [Pivotal Greenplum Sandbox Virtual Machine](https://network.pivotal.io/products/pivotal-gpdb#/releases/567/file_groups/337) which is available for free download on the Pivotal Network.   This sandbox is an easy-to-use virtual machine which runs in either VirtualBox or VMware Fusion  and contains a pre-built instance of the open source Greenplum database, PL/R and PL/Python as well as the [Apache MADlib (incubating) library](http://madlib.incubator.apache.org/).  

After loading the necessary tables in the GPDB sandbox, configuring the environment variables for the database connection to point to the sandbox database and setting ```luigi.cfg``` to match with the local tables, we are ready to run the pipeline.  We start the local-scheduler with
~~~
$ luigid —background
~~~
To run the pipeline end-to-end we run the wrapper task (```PipelineTask```) in ```pipeline.py``` with
~~~
$ python -m luigi —module pipeline PipelineTask
~~~
We can view our pipeline status and the dependency graph by opening a browser to http://localhost:8082.  

## Conclusion

In summary, while building a pipeline adds some overhead to your workflow, the benefits of coordinating the running, monitoring and data testing multiple iterations of end-to-end models can be well worth the cost.  If you have a workflow with long running batch processes, such as regularly training and scoring variations of a model, then the ability to wrap your workflow into a pipeline is a worthwhile tool to have in your arsenal.

 
