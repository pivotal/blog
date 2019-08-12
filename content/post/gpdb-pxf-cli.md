---
authors:
- oliverralbertini
categories:
- Greenplum
- GPDB
- PXF
- CLI
- Utilities
- Amazon S3
- HDFS
date: 2019-09-03T18:00:00Z
draft: false
short: The PXF CLI provides a convenient way to administer PXF servers running on Greenplum

title: Administering a PXF cluster using the PXF Command Line Interface
image: /images/pxfarch.jpg
---

## Objective

This blog aims to demonstrate some simple, but essential workflows that use the PXF CLI to administer an installation of PXF on a Greenplum cluster.

## Prerequisites

This post assumes that a [Greenplum database](https://greenplum.org) cluster is up and running. Greenplum includes an installation of PXF on each host in the cluster. For more set-up information, see the GitHub pages for [Greenplum](https://github.com/greenplum-db/gpdb) and [PXF](https://github.com/greenplum-db/pxf).

## How it works

### Basic architecture

{{< responsive-figure src="/images/pxfarch.png" class="center" caption="Figure 1: data and control flow between a PXF cluster collocated on Greenplum segments and an HDFS cluster.">}}

PXF consists of [Tomcat](https://tomcat.apache.org) servers with REST endpoints on each segment host of the Greenplum cluster. Greenplum master (and standby master, not pictured) hosts do not have PXF servers running on them. However, to enable the use PXF's command line interface, the PXF installations are available on these hosts.

### Command Line Interface (CLI)

The `pxf` command is located in `$GPHOME/pxf/bin` on each host where PXF is installed.

Add the directory to your path and you can begin using it:

~~~bash
[gpadmin@mdw ~]$ export PATH=${GPHOME}/pxf/bin:$PATH
~~~

With the PXF CLI, you can run commands on a specific PXF server (resident on an individual Greenplum segment host) to perform actions like starting and stopping the server, checking the server's status, and other administrative tasks. To make this scalable for large installations, we also provide the ability to run this command across the entire installation.

We begin with the set of commands that operate at the cluster level. These commands simplify performing basic commands (e.g., `start`, `stop`) across the entire cluster:

~~~bash
[gpadmin@mdw ~]$ pxf cluster -h
~~~

~~~terminal
Perform <command> on each segment host in the cluster

Usage: pxf cluster <command>
       pxf cluster {-h | --help}

List of Commands:
  init        Initialize the PXF server instances on master, standby master, and all segment hosts
  reset       Reset PXF (undo initialization) on all segment hosts
  start       Start the PXF server instances on all segment hosts
  status      Get status of PXF servers on all segment hosts
  stop        Stop the PXF server instances on all segment hosts
  sync        Sync PXF configs from master to standby master and all segment hosts

Flags:
  -h, --help   help for cluster

Use "pxf cluster [command] --help" for more information about a command.
~~~

Please note the above cluster-level commands **must** be run from the Greenplum master host. Cluster commands query the database for segment and standby master hostnames, so Greenplum **must** be up and running.

Alternatively, one can also operate the PXF CLI on individual Greenplum segment hosts and run one-off commands to e.g., start, stop, and check the status of the PXF server.

Next, we provide examples of common administration tasks for which the PXF CLI is useful. For these workflows we will use a Greenplum cluster with a master (`mdw`), standby master (`smdw`) and two segment (`sdw1`, `sdw2`) hosts.

## Workflow 1: Initializing PXF on the cluster

Before initializing PXF, choose a directory where you would like PXF configurations to live. It should be accessible by user `gpadmin` on all Greenplum hosts. Set the `PXF_CONF` environment variable to this location, then initialize the cluster.

~~~bash
[gpadmin@mdw ~]$ export PXF_CONF=~/pxf
[gpadmin@mdw ~]$ pxf cluster init
~~~

~~~terminal
Initializing PXF on master and 3 other hosts...
PXF initialized successfully on 4 out of 4 hosts
~~~

The `cluster init` command creates the `PXF_CONF` directory and populates it with several directories on all the hosts.

~~~bash
[gpadmin@mdw ~]$ ls $PXF_CONF
~~~

~~~terminal
conf      keytabs   lib       logs      servers   templates
~~~

Note that although PXF only runs on segment hosts, PXF is still initialized on master and standby master hosts because they are the source of truth for configuration data.

If you decide that having `PXF_CONF` in `gpadmin`'s home directory is undesirable and you want to use a different directory for `PXF_CONF`, you must re-initialize PXF. But first, reset PXF's configuration on the entire cluster:

~~~bash
[gpadmin@mdw ~]$ pxf cluster reset
~~~

~~~terminal
Ensure your PXF cluster is stopped before continuing. This is a destructive action. Press y to continue:
y
Resetting PXF on master and 3 other hosts...
PXF has been reset on 4 out of 4 hosts
~~~

Now you can set the `PXF_CONF` environment variable to another path and initialize the cluster again.

~~~bash
[gpadmin@mdw ~]$ export PXF_CONF=/usr/share/pxf
[gpadmin@mdw ~]$ pxf cluster init
~~~

~~~terminal
Initializing PXF on master and 3 other hosts...
PXF initialized successfully on 4 out of 4 hosts
~~~

## Workflow 2: Starting and stopping PXF on the cluster

Using the cluster command, starting PXF is as simple as

~~~bash
[gpadmin@mdw ~]$ pxf cluster start
~~~

~~~terminal
Starting PXF on 2 segment hosts...
PXF started successfully on 2 out of 2 hosts
~~~

Checking the status should indicate that the cluster is up and running:

~~~bash
[gpadmin@mdw ~]$ pxf cluster status
~~~

~~~terminal
Checking status of PXF servers on 2 hosts...
PXF is running on 2 out of 2 hosts
~~~

If for some reason the PXF server on one of the hosts is down, the PXF CLI will let you know. Let's stop PXF on `sdw1` (note that to run a command against an individual PXF server, we must run the command from that host and omit `cluster` from the command):

~~~bash
[gpadmin@mdw ~]$ ssh sdw1
[gpadmin@sdw1 ~]$ pxf stop
~~~

~~~terminal
Using CATALINA_BASE:   /usr/local/greenplum-db-devel/pxf/pxf-service
Using CATALINA_HOME:   /usr/local/greenplum-db-devel/pxf/pxf-service
Using CATALINA_TMPDIR: /usr/local/greenplum-db-devel/pxf/pxf-service/temp
Using JRE_HOME:        /usr/lib/jvm/jre
Using CLASSPATH:       /usr/local/greenplum-db-devel/pxf/pxf-service/bin/bootstrap.jar:/usr/local/greenplum-db-devel/pxf/pxf-service/bin/tomcat-juli.jar
Using CATALINA_PID:    /usr/local/greenplum-db-devel/pxf/run/catalina.pid
Tomcat stopped.
~~~

Checking the cluster's status from master again,

~~~bash
[gpadmin@mdw ~]$ pxf cluster status
~~~

~~~terminal
Checking status of PXF servers on 2 hosts...
ERROR: PXF is not running on 1 out of 2 hosts
sdw1 ==> Checking if tomcat is up and running...
ERROR: PXF is down - tomcat is not running...
~~~

The output displays the truncated `stderr` message for whichever host had a non-zero return code. This is a pattern that we follow for all cluster-level commands.

## Workflow 3: Syncing configurations

To confirm that PXF is working properly on the cluster, let's [create an external table](https://gpdb.docs.pivotal.io/5210/pxf/objstore_text.html) that accesses data on [Amazon S3](https://aws.amazon.com/s3/), then query that table.

First generate a file with some random words to put in a file on S3.

~~~bash
[gpadmin@mdw ~]$ shuf -n7 /usr/share/dict/words | awk '{print NR","$1}' > random-words.csv
[gpadmin@mdw ~]$ cat random-words.csv
~~~

~~~terminal
1,savvying
2,teleophore
3,automaker
4,vitriolling
5,nonadministrable
6,switch-over
7,stegnosisstegnotic
~~~

Now we have some data to query using PXF. Upload it to S3 using the [AWS Command Line Interface](https://aws.amazon.com/cli/):

~~~bash
[gpadmin@mdw ~]$ aws s3 cp random-words.csv s3://bucket-name/path/
~~~

~~~terminal
upload: ./random-words.csv to s3://bucket-name/path/random-words.csv
~~~

Create an external table pointing at the new file in S3. You need an `int` and a `text` column for the table. In the location clause, we give PXF the bucket name and the path to our file, and specify the `s3:text` profile. See [here](https://gpdb.docs.pivotal.io/5210/pxf/access_objstore.html) for more details about available PXF profiles for cloud object stores. The format clause is set to `csv`, telling Greenplum to expect the data in CSV format.

~~~SQL
[gpadmin@mdw ~]$ psql template1
template1=# CREATE EXTENSION pxf; -- register the PXF extension, needed once per database
template1=# CREATE EXTERNAL TABLE random_words (id int, word text)
template1=#   LOCATION ('pxf://bucket-name/path/random-words.csv?PROFILE=s3:text&SERVER=my_s3')
template1=#   FORMAT 'csv';
~~~

~~~terminal
CREATE EXTERNAL TABLE
~~~

The location clause above specifies a server named `my_s3`, but we have not yet configured this server. When we query our table, PXF returns an exception:

~~~SQL
template1=# SELECT * FROM random_words;
~~~

~~~terminal
ERROR:  remote component error (500) from '127.0.0.1:5888':  type  Exception report   message   javax.servlet.ServletException: org.apache.hadoop.fs.s3a.AWSClientIOException: doesBucketExist on bucket-name: com.amazonaws.AmazonClientException: No AWS Credentials provided by BasicAWSCredentialsProvider EnvironmentVariableCredentialsProvider InstanceProfileCredentialsProvider
~~~

This error indicates that we have not provided credentials for our S3 bucket. This makes sense, since we have not configured a server in `$PXF_CONF/servers/my_s3`, and we didn't provide credentials as parameters in the location clause when we created the table.

Create a server configuration file at `$PXF_CONF/servers/my_s3/s3-site.xml` and edit the file to include your S3 access and secret keys (see [here](https://gpdb.docs.pivotal.io/5210/pxf/objstore_cfg.html) for details).

~~~bash
[gpadmin@mdw ~]$ mkdir "${PXF_CONF}/servers/my_s3"
[gpadmin@mdw ~]$ cp "${PXF_CONF}/templates/s3-site.xml" "${PXF_CONF}/servers/my_s3"
[gpadmin@mdw ~]$ vi "${PXF_CONF}/servers/my_s3/s3-site.xml"
~~~

During the query, each PXF server reads configuration data from disk on their respective hosts. For this reason, we must get the configuration file onto all segment hosts, not just master. The master host acts as a central repository for this data. In case the master host goes down, the standby master must also have this data.

The PXF CLI makes it easy to sync configurations from the master host to all other hosts, including standby master:

~~~bash
[gpadmin@mdw ~]$ pxf cluster sync
~~~

~~~terminal
Syncing PXF configuration files to 3 hosts...
PXF configs synced successfully on 3 out of 3 hosts
~~~

The `cluster sync` operation acts on the `$PXF_CONF/{servers,conf,lib}` directories, making sure that what is on master will be reflected on the master standby and segment hosts.

Let's make sure that the configuration file is now synced onto the remote hosts.

~~~bash
[gpadmin@mdw ~]$ for server in smdw sdw{1,2}; do
> echo -n "${server}: "
> ssh $server ls "$PXF_CONF/servers/my_s3/s3-site.xml"
> done
~~~

~~~terminal
smdw: /usr/share/pxf/servers/my_s3/s3-site.xml
sdw1: /usr/share/pxf/servers/my_s3/s3-site.xml
sdw2: /usr/share/pxf/servers/my_s3/s3-site.xml
~~~

Let's run our query again. This time the query succeeds and returns the expected results.

~~~SQL
template1=# SELECT * FROM random_words;
~~~

~~~terminal
 id |        word
----+--------------------
  1 | savvying
  2 | teleophore
  3 | automaker
  4 | vitriolling
  5 | nonadministrable
  6 | switch-over
  7 | stegnosisstegnotic
(7 rows)
~~~

## Wrapping up

The PXF CLI utility, and especially the cluster sub-command make it easy to administer a PXF cluster, even with large numbers of hosts.
