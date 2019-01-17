---
authors:
- bjstks
categories:
- Java
- Spring
- Annotations
- Spring Boot
- Pivotal Cloud Foundry
date: 2019-01-15T00:00:01Z
draft: true
short: |
  Example and explanation of how to set up a common use case with the Spring Cloud Netflix stack within a PCF deployment.
title: Eureka, Zuul, and Cloud Configuration - Pivotal Cloud Foundry
---


## Overview

In a previous [post](http://engineering.pivotal.io/post/local-eureka-zuul-cloud_config-with-spring/) I explained how you could create several components to build a Netflix stack for local development.  Now, I want to explain how Pivotal Cloud Foundry makes this much easier.  If you do not have a PCF instance to use, you can create a free [PWS account](https://run.pivotal.io/) or use the latest version of [PCF Dev](https://network.pivotal.io/products/pcfdev) (make sure to use the `-s scs` flag) to run PCF on your laptop (which still needs a PWS account sans credit card). And if you do have a PCF instance but do not see the Spring Configuration Server or Service Registry, you should ask your PCF Operator to install [Spring Cloud Services for PCF](https://docs.pivotal.io/spring-cloud-services/2-0/installation.html).

The code for this tutorial is located [here](https://github.com/bjstks/zuulreka-config/tree/pcf-deployment), note that it is on branch `pcf-deployment`.  The final outcome will be a very simplified version of a Netflix stack configured for Pivotal Cloud Foundry.  Two PCF services will be created, the Service Registry, that will discover clients configured to be discovered, and a Spring Cloud Configuration server that will look for property files to serve to their respective, configured applications.  PCF will also host a Zuul router and filter (`zuul`), and an API (`netflix-protected`) that uses a property file from the Cloud Configuration server.  Finally, both `zuul` and `netflix-protected` will be discoverable by the Service Registry server.


### [Spring Cloud Configuration](http://cloud.spring.io/spring-cloud-config/single/spring-cloud-config.html)

We should update the local Spring Cloud Configuration server to use the same configuration files the PCF Spring Cloud Configuration server will use.  Create a `~/zuulreka-config/configurations` folder to keep the properties files for the API.  We can move `~/zuulreka-config/components/cloud-config/src/main/resources/netflix-protected.yml` to the new `configurations` folder.

```
external:
  property: hello world!

management:
  endpoints:
    web:
      exposure:
        include: refresh
```
<small><i>~/zuulreka-config/configurations/netflix-protected.yml</i></small>

I consolidated `~/zuulreka-config/components/cloud-config/src/main/resources/application.yml` and `~/zuulreka-config/components/cloud-config/src/main/resources/bootstrap.yml` and deleted `~/zuulreka-config/components/cloud-config/src/main/resources/application.yml`, because they were both configuring the config server and I like fewer files - you can leave them as is, if you prefer.  Also note that the default `native` profile was removed and the `cloud.config.server.git.uri` property was added.  Because the location is not in the `~/zuulreka-config/components/cloud-config/src/main/resources` anymore, the `native` profile is unnecessary and the location needs to be defined.

```
server:
  port: 9999

spring:
  application:
    name: cloud-config
  cloud:
    config:
      server:
        git:
          uri: ${user.home}/workspace/zuulreka-config/configurations
  output:
    ansi:
      enabled: always

eureka:
  client:
    serviceUrl:
      defaultZone: ${EUREKA_HOST:http://localhost:8282}/eureka
```
<small><i>~/zuulreka-config/components/cloud-config/src/main/resources/bootstrap.yml</i></small>

Because Spring Cloud Configuration needs the `config.server.git.uri` to be a Git repository, we can fake that by initializing the configurations directory as a Git repository and commit the latest properties we want the `netflix-protected` API to use.

{{< responsive-figure src="/images/pcf-eureka-zuul-cloud_config-with-spring/git_init_local.png" >}}

Starting everything locally will have the same exact effect as before with the only difference being where the local Cloud Configuration server loads properties from.


### [Pivotal Cloud Foundry](https://pivotal.io/platform)

To start interfacing with Pivotal Cloud Foundry, download the [cf-cli](https://docs.cloudfoundry.org/cf-cli/).  You can read through the linked cf-cli documentation or you can run `cf help` from your terminal to see what commands are available.  The cli will be how we will manage the services we create and applications we deploy.

Login to your PCF instance by using `cf login` or `cf login --sso` for a code to use if you are using a single sign-on solution.

{{< responsive-figure src="/images/pcf-eureka-zuul-cloud_config-with-spring/cf_login-sso.png" >}}

To see what services and plans are available, run the command `cf marketplace`.

{{< responsive-figure src="/images/pcf-eureka-zuul-cloud_config-with-spring/cf_marketplace.png" >}}

The two services we will need specifically are `p-service-registry` and `p-config-server`, both with a plan of `standard`.  The service registry will run in PCF, waiting for clients to connect to it, so it will only need to be created with a plan and given a name.  Running `cf create-service help` will show how to create a service.  To create the service registry, run `cf create-service standard p-service-registry service-registry`.  As the output suggests, run `cf service service-registry` to check the status of the services creation.

{{< responsive-figure src="/images/pcf-eureka-zuul-cloud_config-with-spring/cf_create-service_service-registry.png" >}}

To make the configurations for the Configuration Server easy to remember, create `config-server-configuration.json` at the root of the project with this content:

```json
{
  "git": {
    "uri": "https://github.com/bjstks/zuulreka-config",
    "label": "pcf-deployment",
    "searchPaths": "configurations"
  }
}
```
<small><i>~/zuulreka-config/config-server-configuration.json</i></small>

The `uri` will be the location of the GitHub repository where the configuration files are located, the `label` is the branch name in this case, and the `searchPaths` are the relative path from the root of that repository.  You can find more about the Git configuration [here](https://docs.run.pivotal.io/spring-cloud-services/config-server/configuring-with-git.html).  With those configurations, create the configuration server that will house your applications properties files with `cf create-service p-config-server standard config-server -c config-server-configuration.yml`. Run `cf service config-server` to check the status of the services creation.

{{< responsive-figure src="/images/pcf-eureka-zuul-cloud_config-with-spring/cf_create-service_config-server.png" >}}

These services can also be created through the user interface from the `Marketplace` section or from a specific `org` and `space` from the `Services` tab.  On the services page, you can select `Add a Service` to find and create the service registry and configuration server.  Once you find and select the services, the wizard will allow you to input the service names and configurations.


### Spring Boot Web application

If you want to see how to create this component from scratch, check out my previous [post](http://engineering.pivotal.io/post/local-eureka-zuul-cloud_config-with-spring/).  For this post, however, I am only going to show how to update the `netflix-protected` component.  The only changes that will need to be made are to update the dependencies so that the application will connect to the PCS instances of the Service Registry and Cloud Configuration servers, update how it connects to those resources, disable security (opposed to configuring it because some of the added dependencies will add Spring Security to the classpath), and create a `manifest.yml` file that will describe to PCF how this application should run.

To update the `netflix-protected` component, add to the `~/zuulreka-config/components/netflix-protected/build.gradle` file by changing the Spring dependency management plugin to also import the spring-cloud-services-dependencies from `io.pivotal.spring.cloud:spring-cloud-services-dependencies:${springBootVersion}`.  Also, include the `io.pivotal.spring.cloud:spring-cloud-services-starter-service-registry` dependency within the `dependencies` section.

```
buildscript {
    ext {
        springBootVersion = '2.0.2.RELEASE'
        springCloudVersion = 'Finchley.SR1'
    }
    repositories {
        mavenCentral()
    }
    dependencies {
        classpath("org.springframework.boot:spring-boot-gradle-plugin:${springBootVersion}")
    }
}

apply plugin: 'java'
apply plugin: 'org.springframework.boot'
apply plugin: 'io.spring.dependency-management'

group = 'io.template'
version = '0.0.1-SNAPSHOT'
sourceCompatibility = 1.8

repositories {
    mavenCentral()
}

dependencyManagement {
    imports {
        mavenBom "org.springframework.cloud:spring-cloud-dependencies:${springCloudVersion}"
        mavenBom "io.pivotal.spring.cloud:spring-cloud-services-dependencies:2.0.1.RELEASE"
    }
}

dependencies {
    runtime('org.springframework.boot:spring-boot-devtools')

    compile(
            'org.springframework.boot:spring-boot-starter-web',
            'org.springframework.boot:spring-boot-starter-actuator',
            'org.springframework.cloud:spring-cloud-starter-config',
            'org.springframework.cloud:spring-cloud-starter-netflix-eureka-client',
            'io.pivotal.spring.cloud:spring-cloud-services-starter-service-registry')

    testCompile('org.springframework.boot:spring-boot-starter-test')
}
```
<small><i>~/zuulreka-config/components/netflix-protected/build.gradle</i></small>

Because this new dependency will add `spring-security` to the classpath, we either need to disable security or configure a username and password.  Security is not the focus of this tutorial, so we will disable security altogether by overriding the `WebSecurityConfigurerAdapter`.  While we are there, we should allow CSRF requests, because we will need to POST, through the Zuul router, to the `/refresh` endpoint to refresh the Config Server properties.

```
package io.template.zuulrekaconfig;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.netflix.eureka.EnableEurekaClient;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configuration.WebSecurityConfigurerAdapter;

@EnableWebSecurity
@EnableEurekaClient
@SpringBootApplication
public class NetflixProtectedApplication extends WebSecurityConfigurerAdapter {

    @Override
    protected void configure(HttpSecurity http) throws Exception {
        http.csrf().disable()
            .authorizeRequests().anyRequest().permitAll();
    }

    public static void main(String[] args) {
        SpringApplication.run(NetflixProtectedApplication.class, args);
    }
}
```
<small><i>~/zuulreka-config/components/netflix-protected/src/main/java/io/template/zuulrekaconfig/NetflixProtectedApplication.java</i></small>

When running locally, we will want to connect to our `localhost` servers, but when we deploy our API to PCF we will want our application to connect to the PCF Services we created earlier.  [Because all PCF services have a specific structure when the application binds](https://docs.cloudfoundry.org/devguide/deploy-apps/environment-variable.html#VCAP-SERVICES), if the PCF Config Server exists, then the property `vcap.services.config-server.credentials.uri` should exist and our application will connect to it, similarly for the Service Registry and the `vcap.services.service-registry.credentials.uri` property.  However, if the application is started locally, the application will try to connect to the `localhost` environment.

```
server:
  port: 8181
spring:
  application:
    name: netflix-protected
  cloud:
    config:
      uri: ${vcap.services.config-server.credentials.uri:http://localhost:9999}
  output:
    ansi:
      enabled: always

eureka:
  client:
    serviceUrl:
      defaultZone: ${vcap.services.service-registry.credentials.uri:http://localhost:8282}/eureka
```
<small><i>~/zuulreka-config/components/netflix-protected/src/main/resources/bootstrap.yml</i></small>

Next we will create an [Application Manifest](https://docs.cloudfoundry.org/devguide/deploy-apps/manifest.html) that describes our application to PCF to cut down on the things we would manually have to configure each time we deployed.  For our manifest, we will need to set our applications name, the [buildpack](https://docs.cloudfoundry.org/buildpacks/), the path to the jar file to be deployed, and the names of the services to bind to once it is deployed.

```
applications:
- name: netflix-protected
  buildpacks:
  - java_buildpack_offline
  path: build/libs/netflix-protected-0.0.1-SNAPSHOT.jar
  services:
  - config-server
  - service-registry
```
<small><i>~/zuulreka-config/components/netflix-protected/manifest.yml</i></small>

Now we can build and push the `netflix-protected` component from the `~/zuulreka-config/components/netflix-protected` directory with `./gradlew clean assemble && cf push -f manifest.yml`.

{{< responsive-figure src="/images/pcf-eureka-zuul-cloud_config-with-spring/cf_push-netflix_protected.png" >}}


### [Spring Zuul Router & Filtering](https://github.com/netflix/zuul)

If you want to see how to create a Zuul Router & Filter, check out my previous [post](http://engineering.pivotal.io/post/local-eureka-zuul-cloud_config-with-spring/).  To update the `zuul` project to connect to the service registry when deployed to PCF and connect to your local instance when ran locally, update the property, `defaultZone` at `~/zuulreka-config/components/zuul/src/main/resources/bootstrap.yml`.

```yaml
eureka:
  client:
    serviceUrl:
      defaultZone: ${vcap.services.service-registry.credentials.uri:http://localhost:8282}/eureka
```
<small><i>~/zuulreka-config/components/zuul/src/main/resources/bootstrap.yml</i></small>

[More information on `VCAP_SERVICES` can be found here](https://docs.cloudfoundry.org/devguide/deploy-apps/environment-variable.html#VCAP-SERVICES), the most important part to note is that the name `service-registry` should match the services name and the trailing `/eureka` should be outside of the curly braces. The syntax `${SOME_ENVIRONMENT_VARIABLE:http://localhost:8282}` will try to use the environment variable `SOME_ENVIRONMENT_VARIABLE` and if it does not find it, will use `http://localhost:8282` explicitly.

We will configure the `zuul` PCF deployment with `~/zuulreka-config/components/zuul/manifest.yml` that will configure the name of the application, buildpack for PCF to use first, location of the assembled jar to be deployed, number of instances it needs to run, and services it should bind to.  We do not need to do a lot with our manifest but to learn about your options, [check out these docs](https://docs.cloudfoundry.org/devguide/deploy-apps/manifest.html).

```yaml
applications:
- name: zuul
  buildpacks:
  - java_buildpack_offline
  path: build/libs/zuul-0.0.1-SNAPSHOT.jar
  services:
  - service-registry
```
<small><i>~/zuulreka-config/components/zuul/manifest.yml</i></small>

Now we can build and push the `zuul` component from the `~/zuulreka-config/components/zuul` directory with `./gradlew clean assemble && cf push -f manifest.yml`.

{{< responsive-figure src="/images/pcf-eureka-zuul-cloud_config-with-spring/cf_push-zuul.png" >}}


## Finale

[The service registry needs about a minute and a half to register both applications](http://cloud.spring.io/spring-cloud-netflix/single/spring-cloud-netflix.html#_why_is_it_so_slow_to_register_a_service).  When it does, we can send a GET request to the Zuul router to get a response from the api we deployed.  Using [httpie](https://httpie.org/), type `http get https://zuul.apps.pcfone.io/netflix-protected/hello` to see the response.  Note that your domain could differ from `apps.pcfone.io`.  

Now, to check that the `@RefreshScope` annotation still works in PCF - change the `external.property` for the `netflix-protected` application to say `hello universe!`. Also add, commit, and push those changes to your repository.  Next, type `http post https://zuul.apps.pcfone.io/netflix-protected/refresh` to have the API refetch the updated properties.  Now typing `http get https://zuul.apps.pcfone.io/netflix-protected/hello` should yield the updated properties.

I hope these tutorials have been useful!  Please reach out and leave me some feedback or just ask for some clarification at [bstokes@pivotal.io](mailto:bstokes@pivotal.io).

## Reference
+ [Cloud Foundry Developer Guide](https://docs.cloudfoundry.org/devguide/index.html)
+ [Spring Cloud Services](https://docs.pivotal.io/spring-cloud-services/2-0/common/)
+ [Spring Cloud](https://cloud.spring.io/spring-cloud-static/spring-cloud.html)
+ [Spring Cloud Netflix](http://cloud.spring.io/spring-cloud-static/spring-cloud-netflix/2.0.0.RELEASE/)
+ [Spring Cloud Config](http://cloud.spring.io/spring-cloud-static/spring-cloud-config/2.0.0.RELEASE/)
+ [Spring Cloud Router and Filter: Zuul](http://cloud.spring.io/spring-cloud-static/Finchley.SR1/single/spring-cloud.html#_router_and_filter_zuul)
+ [More Spring Cloud Router and Filter](https://cloud.spring.io/spring-cloud-netflix/multi/multi__router_and_filter_zuul.html)
