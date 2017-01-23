---
authors:
- heatherf
- ianfisher
categories:
- Spring Cloud Data Flow
- Spring Cloud Data Flow Streams

date: 2016-10-03T10:00:00-07:00
short: |
  Get started with Spring Cloud Data Flow Streams by creating a custom Sink app and deploying to Pivotal Cloud Foundry.
title: Everything and the Spring Cloud Data Flow Sink
---

# Welcome to Data Flow Streams

We recently started evaluating [Spring Cloud Data Flow](https://cloud.spring.io/spring-cloud-dataflow/) for a project and were initially overwhelmed with the capabilities this system provides. Data Flow is a very powerful tool, and we found it a bit tricky to know where to get started. Through our own experimentation and discussion with the Data Flow team, we came up with a minimal setup that we think is very useful for getting started with Data Flow, specifically around [Streams](http://cloud.spring.io/spring-cloud-stream/).

In this post we will show you how to create a simple Data Flow Stream Sink and deploy it to [Pivotal Cloud Foundry](https://run.pivotal.io/). Sinks are the components that terminate Streams, so this seemed like the smallest piece we could implement.

Our [sample Sink app is in a public repo](https://github.com/iad-dev/hello-charmander-dataflow-sink) if you want to check it out.

For context, Streams are made up of Sources, Sinks, and (optionally) Processors. Sources are apps that output messages, Sinks are apps that input messages, and Processors go in the middle with both an input and output. (Technically, [Processors are both Sources and Sinks](https://github.com/spring-cloud/spring-cloud-stream/blob/master/spring-cloud-stream/src/main/java/org/springframework/cloud/stream/messaging/Processor.java))

`[Source] -> [Processor] -> [Sink]`

## Generate a Sink Project

Go to the [Spring Cloud Stream Initializr](http://start-scs.cfapps.io/) and generate a project with the `Log Sink` dependency. We chose to use Gradle, so if you're using Maven you can translate as needed.

Make sure to fill out the Project Metadata as desired. Ours looked like this:

![Project Metadata](/images/spring-cloud-dataflow-sink/project-metadata.png)

![Jackie Chan loves Charmander](/images/spring-cloud-dataflow-sink/charmander-sink.jpg)

## Update Dependencies

The Initializr will create a [build.gradle](https://github.com/iad-dev/hello-charmander-dataflow-sink/blob/master/build.gradle) file that uses the most recent version of Spring Boot, currently 1.4.1. As of September 2016, this version is not compatible with the latest release of Spring Cloud Stream Sinks (1.0.0), so we used Spring Boot 1.4.0 instead.

```
// build.gradle

buildscript {
	ext {
		springBootVersion = '1.4.0.RELEASE'
	}
	...
}
```

Additionally, for deploying to Cloud Foundry, you'll need a message queue binder. We used RabbitMQ since that service is easily available on [Pivotal Web Services](https://run.pivotal.io/) where we will be hosting our apps.

```
// build.gradle

dependencies {
    compile('org.springframework.cloud:spring-cloud-stream-binder-rabbit')
    ...
}
```

## Create a Custom Sink

Next, let's write the code for our Sink app. We decided to simply log the messages received by the Sink to keep things simple, but Sinks can be much more substantial if needed.

We created a `io.pivotal.configuration` package and created a [SinkConfiguration](https://github.com/iad-dev/hello-charmander-dataflow-sink/blob/master/src/main/java/io/pivotal/configuration/SinkConfiguration.java) class that looks like this:

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

This class binds to the Sink input message broker channel and will receive any messages posted there in the `loggerSink` method.

## Deploy the Data Flow Server

In order to deploy our new Sink, we will need a Data Flow Server.

Download the `Cloud Foundry Server` jar found under `Spring Cloud Data Flow Server Implementations` on https://cloud.spring.io/spring-cloud-dataflow/ and push it to Cloud Foundry. We named our server app `charmander-dataflow-server` to avoid naming conflicts on PWS, but you can call yours whatever you like.

Create the Data Flow Server app:

`cf push charmander-dataflow-server -p ~/Downloads/spring-cloud-dataflow-server-cloudfoundry-1.0.0.RELEASE.jar --no-start`

Create the services your Data Flow Server will need:

```text
cf create-service rediscloud 30mb redis
cf create-service cloudamqp lemur rabbit
cf create-service p-mysql 100mb my_mysql
```

Bind the services to the Data Flow Server:

```text
cf bind-service charmander-dataflow-server redis
cf bind-service charmander-dataflow-server rabbit
cf bind-service charmander-dataflow-server my_mysql
```

Set the Data Flow Server environment variables:

```text
cf set-env charmander-dataflow-server SPRING_CLOUD_DEPLOYER_CLOUDFOUNDRY_URL https://api.run.pivotal.io
cf set-env charmander-dataflow-server SPRING_CLOUD_DEPLOYER_CLOUDFOUNDRY_ORG {org}
cf set-env charmander-dataflow-server SPRING_CLOUD_DEPLOYER_CLOUDFOUNDRY_SPACE {space}
cf set-env charmander-dataflow-server SPRING_CLOUD_DEPLOYER_CLOUDFOUNDRY_DOMAIN cfapps.io
cf set-env charmander-dataflow-server SPRING_CLOUD_DEPLOYER_CLOUDFOUNDRY_STREAM_SERVICES rabbit
cf set-env charmander-dataflow-server SPRING_CLOUD_DEPLOYER_CLOUDFOUNDRY_USERNAME {email}
cf set-env charmander-dataflow-server SPRING_CLOUD_DEPLOYER_CLOUDFOUNDRY_PASSWORD {password}

cf set-env charmander-dataflow-server MAVEN_REMOTE_REPOSITORIES_REPO1_URL https://repo.spring.io/libs-release
```

The Cloud Foundry username and password will be used to deploy and manage the Stream apps (such as our Sink), so make sure those credentials can manage apps within your Cloud Foundry space.

Finally, start the Data Flow Server:

`cf start charmander-dataflow-server`

Once the server starts, you can see the Data Flow Server web UI. You can find yours at `https://<your-dataflow-server>.cfapps.io/dashboard`

See the full [Spring Cloud Data Flow for Cloud Foundry documation page](http://docs.spring.io/spring-cloud-dataflow-server-cloudfoundry/docs/current-SNAPSHOT/reference/htmlsingle/#_deploying_on_cloud_foundry) for more info on deploying, including things like setting up security for your server.

## Deploy the Sink App

### Host the Sink Jar

First, build the Sink jar from the Sink's project directory:

`./gradlew clean assemble`

This will package our app into a jar file in `build/libs`.

To deploy your Sink app, you'll need to host the jar file somewhere accessible to the Data Flow Server. We chose to host our Sink jar on AWS S3, but you could use any public url or maven repo.

### Install Data Flow Shell

In order to deploy your app, you'll want to use the [Data Flow Shell app](https://github.com/spring-cloud/spring-cloud-dataflow/tree/master/spring-cloud-dataflow-shell). You can also use the web UI if you prefer.

Download the Data Flow Shell app:

`wget http://repo.spring.io/release/org/springframework/cloud/spring-cloud-dataflow-shell/1.0.0.RELEASE/spring-cloud-dataflow-shell-1.0.0.RELEASE.jar`

Run the jar to get a shell prompt:

`java -jar spring-cloud-dataflow-shell-1.0.0.RELEASE.jar`

### Register the Sink App

From the Data Flow Shell, connect to your Data Flow server:

`dataflow:>dataflow config server https://charmander-dataflow-server.cfapps.io`

Then, register your Sink app:

`dataflow:>app register --name char-log --type sink --uri https://link-to-your-jar.jar`

At this point, we have registered our app within the Data Flow Server. You can verify this on the `Apps` tab of the Data Flow Server dashboard, or with the Shell:

```text
dataflow:>app list
╔════════╤═══════════╤════════╤═══════╗
║ source │ processor │  sink  │ task  ║
╠════════╪═══════════╪════════╪═══════╣
║        │           │char-log│       ║
╚════════╧═══════════╧════════╧═══════╝
```

## Create the Stream

In order for messages to flow into your Sink, you'll need a Stream Source. We'll use the ready-made `time` Source from maven.

`dataflow:>app register --name time --type source --uri maven://org.springframework.cloud.stream.app:time-source-rabbit:1.0.0.RELEASE`

You can verify this app was installed from the web UI `Apps` tab or the Shell:

```text
dataflow:>app list
╔════════╤═══════════╤════════╤═══════╗
║ source │ processor │  sink  │ task  ║
╠════════╪═══════════╪════════╪═══════╣
║ time   │           │char-log│       ║
╚════════╧═══════════╧════════╧═══════╝
```

From the `Apps` tab, clicking on the magnifying glass for the `time` Source will show a list of properties that can be set when using the `time` app in a Stream. We will use `time-unit` and `fixed-delay` for our stream.

There are two ways to create a Stream. First, you can use the Data Flow Shell:

`dataflow:>stream create --name 'char-stream' --definition 'time --time-unit=SECONDS --fixed-delay=5 | char-log'`

This follows the format

`stream create --name '{NAME_OF_STREAM}' --definition '{SOURCE_APP_NAME} {OPTIONAL_SOURCE_PROPERTIES} | {SINK_APP_NAME} {OPTIONAL_SINK_PROPERTIES}'`

Alternatively, you can create a Stream in the Dashboard UI by clicking on the `Streams` tab and then on `Create Stream`. The available Sinks, Sources, and Processors will be on the left of the workspace. You can drag them and then connect Sources to Sinks for the configuration you want.

To setup our stream, drag a `time` and `char-log` (or whatever you called your Sink) from the list on the left into the workspace and connect `time` to `char-log` by clicking the box on the right of `time` and dragging it to the box on the left of `char-log`.

If you click on the `time` module, you will see a gear icon appear in the bottom left corner. Clicking that will let you specify properties for `time`, such as `fixed-delay` and `time-units`. We set `fixed-delay` to `5` and `time-units` to `SECONDS`.

The resulting stream definition will be shown above the flow chart. You can then click on the `Create Stream` button to create it. You will be prompted to give your stream a name.

![Creating a Stream in the UI](/images/spring-cloud-dataflow-sink/create-stream.png)

Your stream `char-stream` and its definition will now be listed in the `Definitions` tab. Go ahead and click `Deploy` and then `Deploy` on the next page (we have no `Deployment Properties` to add).

To see the new Sink and Source apps, go to your Cloud Foundry space and notice that there are two new apps starting up, with some randomly generated words in the app names. It may take a minute or so for those Spring apps to boot up.

![Sink and Source Apps in CF](/images/spring-cloud-dataflow-sink/sink_and_source.png)

To see the logging that is now done by your stream, click on the app for your Sink, the one ending in `char-log`, and tail its logs. It will look something like this:

![Sink Logs](/images/spring-cloud-dataflow-sink/sink_logs.png)

You can see that every 5 seconds, we are letting our Charmander know what time it is (they are forgetful creatures).

Congratulations, your Spring Cloud Data Flow Stream is working!

## What We Did

In review:

1. Create the custom Sink, starting with the Spring Cloud Stream Initializr
1. Deploy the Data Flow Server to Cloud Foundry and set up the Data Flow Shell
1. Register the custom Sink and any other Sources or Sinks with the server
1. Create the Stream
1. Deploy the Stream

Hopefully this will help you get started and dip your toes in the Spring Cloud Data Flow ecosystem!

## More documentation

If you are interested in learning more, this documentation was helpful to us as we were getting to know Data Flow.

### Data Flow
[Spring Cloud Data Flow](https://cloud.spring.io/spring-cloud-dataflow/)

[Spring Cloud Data Flow Reference Guide](http://docs.spring.io/spring-cloud-dataflow/docs/current/reference/htmlsingle/)

### Data Flow for Cloud Foundry
[Spring Cloud Data Flow for Cloud Foundry](http://cloud.spring.io/spring-cloud-dataflow-server-cloudfoundry/)

[Spring Cloud Data Flow Server for Cloud Foundry Reference Guide](http://docs.spring.io/spring-cloud-dataflow-server-cloudfoundry/docs/current-SNAPSHOT/reference/htmlsingle/)

### Stream
[Spring Cloud Stream Reference Guide](http://docs.spring.io/spring-cloud-stream/docs/current/reference/htmlsingle/)
