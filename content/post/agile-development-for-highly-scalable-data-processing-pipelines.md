---
authors:
- Swati Soni
- swati
categories:
- Linear-Scale
- Data-Pipeline
- Agile-TDD 
- SPARK 
- Pair-programming
date: 2017-02-01T19:51:08-08:00
draft: false
short: |
  Legacy data processing pipelines are slow, inaccurate, hard to debug, and can cause thousands of dollars in revenue. Conforming to agile methodology and a detailed seven-step approach can ensure an efficient, reliable and high-quality data pipeline on distributed data processing framework like Spark.  Learn how following TDD, careful creation of data structures, and parallel execution results in: code competency and completeness, and a linearly or constantly scalable robust big data processing pipeline. 
title: Agile Development for Highly Scalable Data Processing Pipelines
---

Recently, a client asked Pivotal's Data Science team to help convert some aging T-SQL stored procedures used in their data processing pipeline into better code. The goals were to enable better scalability, improve its testability, and improve runtime performance.  More specifically, our job was to: 

* Improve the reliability and overall accuracy of the resulting code base
* Implement data processing logic in Spark (PySpark specifically) focused on improving performance and scale
* Follow extreme programming principles to improve productivity and seed cultural transformation across the organization

The last point is particularly important. Our goal as an organization is always to transfer knowledge and skills to our clients so they can carry on writing great code after Pivotal departs. Over the course of a few weeks, we delivered results across all three of the objectives above.  The graph below illustrates the performance improvements achieved as a result of the engagement.  As we increased the scope of our code to cover more units, performance scaled constantly (yellow bars and dots) with O(1).  This was a huge performance gain compared to the legacy codebase, which scaled exponentially with more units (green bars and blue dotted line).
{{< responsive-figure src="/images/agile_development_for_highly_scalable_data_pipelines/performance_scale.png" class="center" height="42" width="42">}}
<p align="center">
 Figure 1. Constant O(1) order performance with adding more units.
</p>

How did we, the Pivotal Data Science team and our client pairs, achieve these results? We followed <a name="seven_steps">“A Seven Step Approach”</a> for successful agile code development in processing pipelines for big data:

1. [Interpret legacy data transformation code] (#interpret)
2. [Define data structures] (#define)
3. [Identify reasonably distinct key performance indicators or metrics into implementable sections ] (#partition)
4. [Compose tests for each section ] (#compose_tests)
5. [Produce sufficient code to work for a single entity on a single machine] (#produce_code)
6. [Optimize code for parallel execution of multiple entities] (#optimize)
7. [Define acceptance tests and criteria] (#acceptance)

Here we cover each of the seven steps so you too can build scalable, resilient and dynamic data pipelines to support your big data applications. 

## <a name="interpret"> Step 1. Interpret legacy data transformation code</a>

Legacy data transformation business logic can exist at multiple levels in an application. Often these are written in-line or as parameterized queries within the application code itself. Sometimes they are hidden by an abstraction layer (e.g. Object-relational Mapping aka ORM). In this case, we focused on code embedded in T-SQL stored procedures, a common approach when working with relational databases. 

The procedural code lacks coding functionality, particularly in iterative constructs. The T-SQL code is written without tests which make it difficult to identify data errors in stored procedures. Such errors are not generated until runtime, making them hard to debug. 
To understand the SQL procedure better, we dissect each data modification step into a data flow diagram, which captures the underlying business logic. In simple words, it could look like Figure 2.

{{< responsive-figure src="/images/agile_development_for_highly_scalable_data_pipelines/step_1_figure_2.png" class="center" width="12000" >}}
<p align="center"> Figure 2. Capturing business logic in data flow diagrams. </p>

During this step, inbound/outbound interaction points (columns/rows within data tables), interaction and creation of temporary data tables, SQL-variables, and nested constructs are identified. This step may be irrelevant if documents containing a data dictionary, information about data transformations and corresponding domain logic is provided. Otherwise, (especially in scenarios where you only have access to SQL scripts), it is highly recommended to create data flow diagrams (like the one shown above) before moving to step 2.  

## <a name="define"> Step 2: Define data structures</a>

{{< responsive-figure src="/images/agile_development_for_highly_scalable_data_pipelines/step_2_define_data_structures_1.png" class="center" width="12000" >}}
<p align="center"> Figure 3. Define data structures to support underlying parallel architecture. </p>

To remove data redundancy and achieve data consistency and robustness, in Step 2 we define data structures to encapsulate data and the underlying business logic across multiple machines. Tables with thousands of attributes can disrupt normalized tabular designs. Create disjunctive simpler data frames that introduce modularity and reusability in Python and PySpark code (which is the parallel programming framework used for this lab). Several operations can be performed in parallel on multiple units of data or can be distributed across partitions on a Spark cluster, thus providing scalability.

Data flow diagrams created in the previous step can help identify complex data structures, which involve nested operations and iterative constructs (e.g. while loops). It is important to separate iterations or nested operations which involve the same sets of columns, as these can be captured in a different data structure. Such complexities can introduce undesirable insertion, deletion and updates as any new data and/or attributes are added. A rule of thumb for creating data structures for big data is to avoid small-size data inserts, updates and selective deletes operations associated with data structures. Wherever possible, an append-only operation is preferred to avoid modifications in data that may conflict with information across multiple nodes in a distributed system.

{{< responsive-figure src="/images/agile_development_for_highly_scalable_data_pipelines/step_2_broadcast_variable_new_6.png" class="center" >}}
<p align="center"> Figure 4. Utilize Spark's Broadcast variables. </p>

It’s important to identify and separate data transformations, which operate on mutually exclusive groups of columns or groups of rows, to increase the comprehensibility of the code base. This process also enhances the design of data structures so they are more informative to users.

For in-memory operations, choosing appropriate size and type of data attributes for a data structure can help avoid ‘out of memory’ errors. Long lasting and frequently used data structures are cached in memory/disk to achieve performance. Read only data structures are converted into broadcast variables in Spark, for quicker communication across data partitions. 

Another key structure that exists in Spark is called accumulator.Accumulator provides shared access to variables across partitions on which only cumulative and additive operations can be performed. Accumulators are useful when creating iterative operations.  

## <a name="partition"> Step 3: Identify reasonably distinct key performance indicators or metrics into implementable sections</a>

{{< responsive-figure src="/images/agile_development_for_highly_scalable_data_pipelines/step_3_partition_procedure_into_sections_new_2.png" class="center" >}}
<p align="center"> Figure 5. Identify reasonably distinct KPI's into sections.</p>

One of the key practices of working in extreme programming methodology is to create a prioritized list of the functionality to be developed in the project using an agile project management tool, such as Pivotal Tracker. By creating a backlog of agile user features (called “stories” in Tracker) that describe the functionality to be added over the course of a project, the SQL Server procedure is divided into several functionally testable sections. We identify a section, which could be a combination of SQL statements, as functionally unique and producing key performance indicators or metrics representing business value. Also, one should be able to test a section. 

We use a ‘Given/When/Then’ format as we transcribe each section into a Pivotal Tracker story.  Implementing each story will take us one step closer towards completing the data pipeline. For example, in Figure 5, we see how Section x, which represents a distinct functionality across the SQL procedures, is captured in a Pivotal Tracker story.

{{< responsive-figure src="/images/agile_development_for_highly_scalable_data_pipelines/step_3_sections_into_story.png" class="center small" >}}
<p align="center"> Figure 6. Transcribe sections into Agile features/stories.</p>

## <a name="compose_tests">Step 4. Compose tests for each distinct functionality</a>

A big part of our development culture is to write tests starting on day one. Tests guard against introducing bugs in newly implemented features. With well-tested code, existing functionality remains intact, programmers can more confidently design new ways to implement features, and refactoring becomes easier as the system’s complexity increases with time. 

{{< responsive-figure src="/images/agile_development_for_highly_scalable_data_pipelines/step_4_compose_tests_for_sections_new_1.png" class="center small" >}}
<p align="center"> Figure 7. Discuss, write tests, make them pass, refactor and improve design. </p>

We used the unittest module in Python to compose suites of tests for each section (a team can use any testing framework in its preferred language). Each test has a short setup function, which spins up Spark locally, and a short teardown function that closes the Spark session. Unit tests are written to execute business logic on the local Spark setup. Though sections could be coherent, there exists no dependency between individual tests. We used real data (e.g. copies of production data) in every test scenario so that each test case would optimally cover all verification points.

Following is the setup and teardown functions that execute before each test. In the following code snippet, two tests are written to test a functionality that counts the occurrences of a letter in a list of words. The second test captures an "Exception object" when the letter is not found in a dictionary.

```

class EntityTestCase(unittest.TestCase):

    # setup local Spark session with basic configs 
    def setUp(self):
        """Setup a basic Spark session for testing"""

        SparkSession._instantiatedContext = None
        conf = SparkConf()
        conf.set("spark.executor.memory", "1g")
        conf.set("spark.cores.max", "1")
        conf.set("spark.app.name", "entity_test_suite")
        conf.set("spark.driver.extraLibraryPath", self.getHadoopNative())
        conf.set("spark.ui.port", 6789)

        self.spark = SparkSession.builder.config(conf=conf).getOrCreate()
        self.sc = self.spark.sparkContext
        self.sc.setLogLevel("DEBUG")

        quiet_py4j()

    def tearDown(self):

        """
        Tear down the basic spark test case. This stops the running
        Spark session.
        """

        try:
            self.sc.stop()
            self.spark.stop()
            self.sc._jvm.System.clearProperty("spark.driver.port")
        except:
            print('Exception while tearing down test', sys.exc_info()[0])
        else:
            print('Successfully closed all sockets')
        finally:
            self.sc.stop()
            self.spark.stop()
            self.sc._jvm.System.clearProperty("spark.driver.port")
            self.sc._jvm.System.clearProperty("spark.ui.port")


    def test_get_letter_count_pass(self):
        """Test get_letter_count to return counts of "a" letter present in the data dictionary"""
        list = ["Digital", "Hello", "World", "Boost", "Category"]
        lineData = self.sc.parallelize(list)
	
	count_a = SimpleApp().get_letter_count(lineData, "a")
        assert count_a == 2

    def test_get_letter_count_fail(self):
        """Test get_letter_count to return 0 for counts of a letter not present in the data dictionary"""
        list = ["Digital", "Hello", "World", "Boost", "Category"]
        lineData = self.sc.parallelize(list)
	 
	With self.assertRaises(Exception) as context:
            SimpleApp().get_letter_count(lineData, "A")
            self.assertTrue(‘Unknown Word in dictionary’ in context.exception)
```


## <a name="produce_code"> Step 5. Produce sufficient code to work for a single entity on a single machine</a>

As illustrated in Figure 7, next we write just enough code to make the test pass for one unit of data on one machine. For the sake of implementing just enough while satisfying 'correct' functionality, the code is written for a 'single' entity. 

``` 
    # define the function
    def get_letter_count( file, letter):
        """counts of a letter present in the data dictionary"""
	   count = sum([s.count(letter) for s in file])
	   if count == 0:

		  # log exception, this could again be another data point to capture
        	   raise Exception(‘Unknown Word in dictionary’)
	   return count

   list = ["Digital", "Hello", "World", "Boost", "Category"]

   # define a single list as an entity
   entity_X = sc.parallelize(list)
   
   count_a = sum(entity_X.map(lambda x : get_letter_count(x,'a')).collect()[0])
   
   # Output: count_a : 2 

```

As an additional step, wherever possible, implementation of data structures and business logic can be refactored to improve clarity and design of code. This step ensures that the tests pass and the code executes on Spark.


## <a name="optimize"> Step 6. Optimize for parallel execution of multiple entities</a>

In order to scale for say 'n' number of units, we need to parallelly execute code on a set of machines i.e. using Spark's distributed programming framework. We take the code and tests we implemented so far, and we write additional tests to ensure parallelism. Further, we will write scalable code that wraps functions defined in Step 5 by leveraging lambda architecture. 

In the example below, we define a data frame with each row corresponding to one entity. Each entity has two properties: 'Tokens', a bag of words, and 'Letter', a singular case sensitive letter. To provide parallel execution for multiple entities across the Spark partitions, a new column letter_count is added to the data frame: Letter_count stores the count of the number of times the letter (defined in ‘Letter’ column) occurs in the ‘Tokens’ column.


```
from pyspark.sql.types import *
from pyspark.sql.functions import udf

# Sample Data
data = sc.parallelize([ 
[('Tokens', ["take", "blubber", "pencil", "cloud", "moon", "water", "ant", "lily"]), ('Letter', 'l'), ('Entity', 'A')],
[('Tokens', ["literature", "chair", "two", "window", "cords", "musical", "zebra", "xylophone"]), ('Letter', 't'), ('Entity', 'B')],
[('Tokens', ["website", "banana", "uncle", "softly", "mega", "ten", "awesome", "attach"]), ('Letter', 'p'), ('Entity', 'C')]])

# Convert to tuple
data_converted = data.map(lambda x: (x[0][1], x[1][1], x[2][1]))

# Define schema
schema = StructType([
    StructField("Tokens", ArrayType(StringType()), True), 
    StructField("Letter", StringType(), True),
    StructField("Entity", StringType(), True)
])

# Create dataframe
df = sqlContext.createDataFrame(data_converted, schema)

# create UDFs
def get_letter_count( file, letter):
    count = sum([s.count(letter) for s in file])
    return count

letter_count_udf = udf(get_letter_count, IntegerType())

# build a new feature
df.withColumn('letter_count', letter_count_udf(df.Tokens, df.Letter))

df.show(5, truncate=False)
```
```
# OUTPUT
+------------------------------------------------------------------+------+------+------------+
|Tokens                                                            |Letter|Entity|letter_count|
+------------------------------------------------------------------+------+------+------------+
|[take, blubber, pencil, cloud, moon, water, ant, school, lilly]   |l     |A     |6           |
|[literature, chair, two, window, cords, musical, zebra, xylophone]|t     |B     |3           |
|[website, banana, uncle, softly, mega, ten, awesome, attach]      |p     |C     |0           |
+------------------------------------------------------------------+------+------+------------+

```

## <a name="acceptance"> Step 7. Define acceptance tests and criteria</a>

Acceptance tests for data pipelines are essential to help ensure that the data is transformed in a way that meets business and analytic needs. In the context of redesigning and improving upon an existing data pipeline, we would want to check that the data output before and after the redesign is consistent.  For this, we created a bash script that compares the data points generated from parallel execution of multiple entities to the data points generated by the original SQL server procedures in a serial manner.

Following are the steps for writing such scripts:

1. For all data structures that are present in a section, perform:
  1. Print size, properties, initial “n” number of rows of the data frame to ensure it's correct.
  2. Perform initial count checks on sizes and schema types
  3. Identify key or composite keys
  4. Sort respective data columns per identified keys
2. Perform ‘diff’ operation on sorted data and it’s counterpart procedural output
3. Identify where the diff fails.

Following is a small snippet of code for acceptance testing in bash script:

```
sort spark.dataframe.out | cut -d, -f$key_property-$end_property > .sorted.dataframe
sort sql.table.out | cut -d, -f$key_column-$end_property > .sorted.table

# check the differences between the two files, and captures exit status in the error variable.
# must have diff cli installed.
resultA=$(bash -c '(diff --ignore-space-change --ignore-case --speed-large-files --report-identical-files .sorted.table .sorted.table ); exit $?' 2>&1)
error=$?

# next, the script checks error status
if [ $error -eq 0 ]
then
	# if the exit is zero, test passes, and records are matched 100%.
	echo "Test Passed. "$lines_1" records tested.
	Percentage Matched: 100%"
elif [ $error -eq 1 ]
then
	# if the exit is not zero, 
	# the script counts the mismatched lines, also the mismatch percentage
	# and reports a failed test and the mismatched lines.
	D=''
	mismatch=$(echo $(echo $resultA | expand | sed -e 's/[\ ]/'"$D"'/g' | sed -e $'s/</\\\n/g'| sed -e $'s/>/\\\n/g' | wc -l )/2| bc) 
	mismatch_percent=$(echo "scale=10 ; ($lines_1 - $mismatch) / $lines_1 * 100" | bc)
	echo "Test failed. "$lines_1" records tested." $'\n'"Percentage Matched: "$mismatch_percent 
	echo 'Mismatched lines' $mismatch ' >>'
	echo $'\n'
fi

```

Test code and acceptance tests for all the sections are built on continuous integration (CI) pipelines. Continuous integration pipelines (leading to continuous delivery) are also key requirements and are recommended for a successful data pipeline.  It helps identify integration problems, increases visibility into production quality code and, most of all increases confidence in the code built so far. 

As a practice, we highly recommend adopting continuous delivery, in addition to following these seven steps.

# Main Takeaways

Test driven development is core to delivering efficient and high-quality data pipelines.  Going a step further, following extreme programming principles also help in making data-centric projects successful.  By following a process similar to the [‘7 Step Approach’](#seven_steps) described in this post, we believe that extreme programming can be easy to adopt and apply to a wide spectrum of data-driven use cases.  Below is a recap of the key benefits of following such an approach:

* Follow TDD and extreme programming principles to increase robustness, transparency, and quality of data processing pipelines.
* Parallel execution of multiple entities to speed processing of big data and to increase the agility of model development cycles.
* Incorporate fault tolerance, debug logging, input/output bounds checking and management, and implement normalized data structures to mitigate various types of technical and non-technical risks. 

If you want to learn more:

* [Test-Driven Development for Data Science](http://engineering.pivotal.io/post/test-driven-development-for-data-science/)
* [Agile: The Way to Develop Great Software](https://pivotal.io/agile)
* [Data Science How-To: Using Apache Spark for Sports Analytics](https://content.pivotal.io/blog/how-data-science-assists-sports)

Our team from Pivotal included [Jason Fraser](https://www.linkedin.com/in/jasonfraser/) ( Principal Product Manager ), [Aditya Padhye](https://www.linkedin.com/in/adityapadhye/) ( Data Engineer ) and [Swati Soni](https://www.linkedin.com/in/sonik/) ( Senior Data Scientist ). We collectively delivered this project and was well received by our customers.


