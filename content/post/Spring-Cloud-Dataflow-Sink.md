---
authors:
- heatherf
- ianfisher
categories:
- Spring Dataflow

date: 2016-09-28T15:39:29-07:00
draft: true
short: |
  Short description for index pages, and under title when viewing a post. Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam.
title: Everything and the Spring Cloud Dataflow Sink
---

# Intro

## Generate a Sink Project
The Spring Cloud Stream initializr can be found at [http://start-scs.cfapps.io/]. Here, generate a Gradle project with the Log Sink dependency. Fill out the Project Metadata as desired. Ours looked like:

![Project Metadata](/images/spring-cloud-dataflow-sink/project-metadata.png)

## Create the Custom Sink Logger

Next, write the code for the logger.

In our directory io.pivotal.configuration, we created a SinkConfiguration file that looked like this:

```
package io.pivotal.configuration;

import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;
import org.springframework.cloud.stream.annotation.EnableBinding;
import org.springframework.cloud.stream.messaging.Sink;
import org.springframework.integration.annotation.ServiceActivator;

@EnableBinding(Sink.class)
public class SinkConfiguration {
    private static final Log logger = LogFactory.getLog(SinkConfiguration.class);

    @ServiceActivator(inputChannel=Sink.INPUT)
    public void loggerSink(String payload) {
        logger.info("Hello, Charmander. The time is: " + payload);
    }
}
```

############################################# COME BACK AND EXPLAIN ABOVE ANNOTATIONS

## Update build.gradle file
The Initializr will create a build.gradle file that uses the most recent version of Spring, currently 1.4.1. As of September 2016, this version is not compatible with the latest release of Spring Cloud Stream Sinks, so we used Spring 1.4.0.

```
buildscript {
	ext {
		springBootVersion = '1.4.0.RELEASE'
	}
	...
}
```

Additionally, for deploying to Cloud Foundry, you'll need a message queue binder. We used RabbitMQ.

```
dependencies {
	compile('org.springframework.cloud:spring-cloud-stream-binder-rabbit')
  ...
}
```

## Deploy Dataflow Server

Download and push the Cloud Foundry Dataflow Server jar found under Spring Cloud Data Flow Server Implementations on [https://cloud.spring.io/spring-cloud-dataflow/] to Cloud Foundry.

`cf push charmander-dataflow-server -p ~/Downloads/spring-cloud-dataflow-server-cloudfoundry-1.0.0.RELEASE.jar --no-start`

Create the services your server will need:

`cf create-service rediscloud 30mb redis`

`cf create-service cloudamqp lemur rabbit`

`cf create-service p-mysql 100mb my_mysql`

Bind the services:

`cf bind-service charmander-dataflow-server redis`

`cf bind-service charmander-dataflow-server rabbit`

`cf bind-service charmander-dataflow-server my_mysql`

Set the environment variables:

```
cf set-env charmander-dataflow-server SPRING_CLOUD_DEPLOYER_CLOUDFOUNDRY_URL https://api.run.pivotal.io
cf set-env charmander-dataflow-server SPRING_CLOUD_DEPLOYER_CLOUDFOUNDRY_ORG {org}
cf set-env charmander-dataflow-server SPRING_CLOUD_DEPLOYER_CLOUDFOUNDRY_SPACE {space}
cf set-env charmander-dataflow-server SPRING_CLOUD_DEPLOYER_CLOUDFOUNDRY_DOMAIN cfapps.io
cf set-env charmander-dataflow-server SPRING_CLOUD_DEPLOYER_CLOUDFOUNDRY_STREAM_SERVICES rabbit
cf set-env charmander-dataflow-server SPRING_CLOUD_DEPLOYER_CLOUDFOUNDRY_USERNAME {email}
cf set-env charmander-dataflow-server SPRING_CLOUD_DEPLOYER_CLOUDFOUNDRY_PASSWORD {password}

cf set-env dataflow-server MAVEN_REMOTE_REPOSITORIES_REPO1_URL https://repo.spring.io/libs-release
```

Restage the server:
`cf restage charmander-dataflow-server`

More thorough docs for setting up Dataflow on Cloud Foundry can be found here: http://docs.spring.io/spring-cloud-dataflow-server-cloudfoundry/docs/current-SNAPSHOT/reference/htmlsingle/#_deploying_on_cloud_foundry

## Deploy the Sink App

### Host the Sink Jar

We chose to host the sink jar on AWS S3, but you could use any public url or maven repo to do so. First, you will need to build the jar using gradle.

`./gradlew clean assemble`

This will create a jar file in `build/libs`.

### Install Dataflow Shell

The Dataflow Shell application is one of the main ways you will interact with and configure the Dataflow server.

Download the shell for the Dataflow Server:
`wget http://repo.spring.io/release/org/springframework/cloud/spring-cloud-dataflow-shell/1.0.0.RELEASE/spring-cloud-dataflow-shell-1.0.0.RELEASE.jar`

Run the jar to get a shell prompt:
`java -jar ~/Downloads/spring-cloud-dataflow-shell-1.0.0.RELEASE.jar`

### Register the Sink App

From the Dataflow shell, connect to your Dataflow server:
`dataflow:>dataflow config server http://charmander-dataflow-server.cfapps.io`

Then, register your sink app:
`dataflow:>app register --name hello-charmander-log --type sink --uri https://link-to-your-jar.jar`

## Create the Stream
The Dataflow server has a dashboard at http://charmander-dataflow-server.cfapps.io/dashboard. Your sink `hello-charmander-log` will be listed there.

In order for data to flow to your sink, you'll need a source. We'll use the ready-made timer source on the Maven Repositories.

`dataflow:>app register --name time --type source --uri maven://org.springframework.cloud.stream.app:time-source-rabbit:1.0.2.RELEASE`

Go back to dashboard and see them.

Click on "Streams" tab on dashboard.
Click on "Create Stream"

View logs in CF
