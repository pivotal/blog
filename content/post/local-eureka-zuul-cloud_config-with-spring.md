---
authors:
- bjstks
categories:
- Java
- Spring
- Annotations
- Spring Boot
date: 2019-01-15T00:00:00Z
draft: false
short: |
  Example and explanation of how to set up a common use case with the Spring Cloud Netflix stack to prototype for local development.
title: Eureka, Zuul, and Cloud Configuration - Local Development
---

## Overview

A couple of recent projects I have been on have started our engagement with the Netflix stack described here, and because I wanted to have a way to quickly prototype, I set up this demo.  This will be a Spring Boot API that uses Spring Cloud Configuration, Eureka Service Discovery, and a Zuul router.  Hopefully, by the end of the demo, you will see how easy it is to create this popular use case.  If you want to see the code first, or only care about the code, look [here](https://github.com/bjstks/zuulreka-config).  However, if you want a description of each component, and a look at some code snippets on how the components work, read on.

I went with a single repository for all of the components because simply, it is easier to work with.  I would agree that eventually it would be better to move the Spring Cloud Configuration and API to be in their own separate repository and have all of the 'local only' components have their own repository.  For now, let's keep it simple.

To look ahead, the Eureka Server/Discovery Service will be the registry for all of the micro-services - Spring Cloud Configuration, Spring Cloud Zuul Router, and Spring Boot API.  Once everything is put together, the domain will look like this:

{{< responsive-figure src="/images/local-eureka-zuul-cloud_config-with-spring/boxes-and-lines.png" class="center" >}}

## Details

All of the Spring Cloud components will use a `build.gradle` file that looks similar. Depending on which component you are in, only the compile time dependencies will differ.  As I go through each component I will only specify those dependencies that should change to make it less redundant and to focus on the small amount of configuration changes we will have to make to include the necessary dependencies.  Notice that I am using the recently released `Finchley.SR1` for the Spring Cloud dependencies and Spring Boot 2.0+.  Here is the framework of the `.gradle` file you will include in each component:

```gradle
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
    }
}

dependencies {
    testCompile('org.springframework.boot:spring-boot-starter-test')
}

```

### [Spring Cloud Netflix](http://cloud.spring.io/spring-cloud-netflix/single/spring-cloud-netflix.html)

> Eureka is a REST (Representational State Transfer) based service that is primarily used in the AWS cloud for locating services for the purpose of load balancing and failover of middle-tier servers. We call this service, the Eureka Server. Eureka also comes with a Java-based client component, the Eureka Client, which makes interactions with the service much easier. The client also has a built-in load balancer that does basic round-robin load balancing. At Netflix, a much more sophisticated load balancer wraps Eureka to provide weighted load balancing based on several factors like traffic, resource usage, error conditions etc to provide superior resiliency.
>
> -- <cite>Netflix GitHub</cite>

Grab the `build.gradle` framework mentioned above, and plug in the following dependency and you are good to go for your Eureka Server.  This component will only be used locally because you can leverage the [PCF Service - Service Registry](http://docs.pivotal.io/spring-cloud-services/1-5/common/service-registry/using-the-dashboard.html) when your micro-services are deployed to [Pivotal Cloud Foundry](https://pivotal.io/pcf-dev) or [Pivotal Web Services](https://run.pivotal.io/).

```gradle
compile('org.springframework.cloud:spring-cloud-starter-netflix-eureka-server')
```

This is a standard Spring Boot application with the extra [`@EnableEurekaServer`](http://cloud.spring.io/spring-cloud-static/Finchley.SR1/single/spring-cloud.html#spring-cloud-eureka-server) annotation that will auto configure a Eureka Server and Client.

```java
package io.template.zuulrekaconfig;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.netflix.eureka.server.EnableEurekaServer;

@EnableEurekaServer
@SpringBootApplication
public class EurekaApplication {

    public static void main(String[] args) {
        SpringApplication.run(EurekaApplication.class, args);
    }
}
```
<small><i>~/zuulreka-config/components/eureka/EurekaApplication.java</i></small>

Since we just want to discover other instances with this component (and not be considered a Eureka Client), I will make it so the application does not try to connect or get the registry from another Eureka Server.  I also set the application name and the port as to not conflict with the other components.

```yaml
spring:
  application:
    name: eureka

server:
  port: 8282

eureka:
  client:
    register-with-eureka: false
    fetch-registry: false
```
<small><i>~/zuulreka-config/components/eureka/src/main/resources/application.yml</i></small>

### [Spring Cloud Configuration](http://cloud.spring.io/spring-cloud-config/single/spring-cloud-config.html)

> Spring Cloud Config provides server-side and client-side support for externalized configuration in a distributed system. With the Config Server, you have a central place to manage external properties for applications across all environments.
>
> -<cite>Spring Cloud Configuration GitHub</cite>

This is another local only component, because you can leverage [PCF Service - Config Server](http://docs.pivotal.io/spring-cloud-services/1-5/common/config-server/using-the-dashboard.html) when your microservices are deployed to [PCF](https://pivotal.io/pcf-dev) or [PWS](https://run.pivotal.io/).  Same as the Eureka Server, the `build.gradle` for Cloud Configuration Server, a Eureka Client, is just like the template. The difference is to include these dependencies:

```gradle
compile(
    'org.springframework.cloud:spring-cloud-config-server',
    'org.springframework.cloud:spring-cloud-starter-netflix-eureka-client')
```

The Cloud Configuration Spring Boot application should activate the Configuration Server and Eureka Client configurations by using the [`@EnableConfigServer`](http://cloud.spring.io/spring-cloud-static/Finchley.SR1/single/spring-cloud.html#spring-cloud-eureka-server) and [`@EnableEurekaClient`](https://cloud.spring.io/spring-cloud-static/Dalston.SR5/multi/multi__service_discovery_eureka_clients.html) annotations.  [`@EnableConfigServer`](https://cloud.spring.io/spring-cloud-config/multi/multi__spring_cloud_config_server.html#_spring_cloud_config_server) will allow remote clients to connect to Configuration Server to use an externalized set of properties.  Enabling the Eureka Client tells the Eureka Server that it wants to register and when it registers, other services can use the `spring.application.name` defined in the `bootstrap.yml` to reference it.

```java
package io.template.zuulrekaconfig;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.config.server.EnableConfigServer;
import org.springframework.cloud.netflix.eureka.EnableEurekaClient;

@EnableConfigServer
@EnableEurekaClient
@SpringBootApplication
public class CloudConfigApplication {

    public static void main(String[] args) {
        SpringApplication.run(CloudConfigApplication.class, args);
    }
}
```
<small><i>~/zuulreka-config/components/cloud-config/src/main/java/io/template/zuulrekaconfig/CloudConfigApplication.java</i></small>

Because of Spring Boot's [Application Context Hierarchies](https://cloud.spring.io/spring-cloud-static/spring-cloud-commons/2.0.0.M9/multi/multi__spring_cloud_context_application_context_services.html#_application_context_hierarchies), when the Eureka Clients start, they need to tell the Eureka Server as early as possible that they need to connect.  We can do this with a `bootstrap.yml`:

```yaml
spring:
  application:
    name: cloud-config

eureka:
  client:
    serviceUrl:
      defaultZone: ${EUREKA_URI:http://localhost:8282/eureka}
```
<small><i>~/zuulreka-config/components/cloud-config/src/main/resources/bootstrap.yml</i></small>

The `application.yml` declares an explicit port and makes sure the `native` profile is set by default.  [The `native` profile](https://cloud.spring.io/spring-cloud-config/multi/multi__spring_cloud_config_server.html#_file_system_backend) will allow the `.yml` property files to reside within the cloud configuration component [instead of having to use a fake GitHub file](https://cloud.spring.io/spring-cloud-config/multi/multi__spring_cloud_config_server.html#_spring_cloud_config_server).

```yaml
server:
  port: 9999

spring:
  profiles:
    active: native
```
<small><i>~/zuulreka-config/components/cloud-config/src/main/resources/application.yml</i></small>

Later, I will show the `zuul` and `netflix-protected`, externalized properties that will reside in this component.

### [Spring Zuul Router & Filtering](https://github.com/netflix/zuul)

> Zuul is an edge service that provides dynamic routing, monitoring, resiliency, security, and more.
>
> <cite>Netflix GitHub</cite>

This component __must__ be deployed if you were to use [PCF](https://pivotal.io/pcf-dev) or [PWS](https://run.pivotal.io/) because Zuul is not provided as an [add on service in the Pivotal Services Marketplace](https://pivotal.io/platform/services-marketplace).  Same as usual, use the aforementioned `build.gradle` but use these dependencies instead:

```gradle
compile(
    "org.springframework.cloud:spring-cloud-starter-config",
    'org.springframework.cloud:spring-cloud-starter-netflix-zuul',
    'org.springframework.cloud:spring-cloud-starter-netflix-eureka-client')
```

This is another Spring Boot application that has the [`@EnableEurekaClient`](https://cloud.spring.io/spring-cloud-static/Dalston.SR5/multi/multi__service_discovery_eureka_clients.html) so it can be registered with the Eureka Server.  It also has the `@EnableZuulProxy` annotation to set up a Zuul server endpoint and installs some reverse proxy filters in it, so it can forward requests to backend servers.

```java
package io.template.zuulrekaconfig;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.netflix.eureka.EnableEurekaClient;
import org.springframework.cloud.netflix.zuul.EnableZuulProxy;

@EnableZuulProxy
@EnableEurekaClient
@SpringBootApplication
public class ZuulApplication {

    public static void main(String[] args) {
        SpringApplication.run(ZuulApplication.class, args);
    }
}
```
<small><i>~/zuulreka-config/components/zuul/src/main/java/io/template/zuulrekaconfig/ZuulApplication.java</i></small>

Next, set up the Spring application context to define the components name, how to connect to the Spring Cloud Configuration and Service Discovery using a `bootstrap.yml` file:

```yaml
server:
  port: 8080

spring:
  application:
    name: zuul
  cloud:
    config:
      uri: http://localhost:9999

eureka:
  client:
    serviceUrl:
      defaultZone: ${EUREKA_URI:http://localhost:8282/eureka}
```
<small><i>~/zuulreka-config/components/zuul/src/main/resources/bootstrap.yml</i></small>

By convention, the routes will be configured using the `spring.application.name` (with prefixes stripped) so there is no need to map a route the the `netflix-protected` component.  This is made possible by using a combination of Spring, Eureka, and Ribbon, which you can read about [here](http://cloud.spring.io/spring-cloud-static/Finchley.SR1/single/spring-cloud.html#netflix-zuul-reverse-proxy).  If/when the Zuul instance needs a set of properties, they would be added to the Spring Cloud Configuration Server at `src/main/resources/zuul.yml`.

### Spring Boot Web application

The last component is a simple Spring Boot API.  This component will be discoverable by the Eureka Server, use properties from the Spring Cloud Configuration server, and be routed through the Zuul Router. Use the base `build.gradle` mentioned at the beginning and use these compile time dependencies:

```gradle
compile(
    'org.springframework.boot:spring-boot-starter-web',
    'org.springframework.boot:spring-boot-starter-actuator',
    'org.springframework.cloud:spring-cloud-starter-config',
    'org.springframework.cloud:spring-cloud-starter-netflix-eureka-client')
```

I want it to be registered with the Eureka Server so I will use the [`@EnableEurekaClient`](https://cloud.spring.io/spring-cloud-static/Dalston.SR5/multi/multi__service_discovery_eureka_clients.html) annotation again.

```java
package io.template.zuulrekaconfig;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.netflix.eureka.EnableEurekaClient;

@EnableEurekaClient
@SpringBootApplication
public class NetflixProtectedApplication {

    public static void main(String[] args) {
        SpringApplication.run(NetflixProtectedApplication.class, args);
    }
}
```
<small><i>~/zuulreka-config/components/netflix-protected/src/main/java/io/template/zuulrekaconfig/NetflixProtectedApplication.java</i></small>

This controller will get the `external.property` from the Spring Cloud Configuration Server and return it when you hit the controller through the Zuul router.  __This is how we will know that everything is connected the right way.__  Also note the [`@RefreshScope`](https://cloud.spring.io/spring-cloud-static/spring-cloud.html#_refresh_scope) annotation that, with a little bit of extra work, will save us some time by refreshing the properties once the Configuration Server has updated.  

```java
package io.template.zuulrekaconfig;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RefreshScope
@RestController
public class DemoController {

    @Value("${external.property}") String property;

    @GetMapping("/hello")
    public ResponseEntity<String> hello() {
        return ResponseEntity.ok(property);
    }
}
```
<small><i>~/zuulreka-config/components/netflix-protected/src/main/java/io/template/zuulrekaconfig/DemoController.java</i></small>

We should use the `bootstrap.yml` to define the [servlet context path](https://docs.spring.io/spring-boot/docs/current/reference/htmlsingle/#_custom_context_path), the application name, the location of the Spring Cloud Configuration and Eureka Servers.

```yaml
server:
  port: 8181
spring:
  application:
    name: netflix-protected
  cloud:
    config:
      uri: http://localhost:9999

eureka:
  client:
    serviceUrl:
      defaultZone: ${EUREKA_URI:http://localhost:8282/eureka}
```
<small><i>~/zuulreka-config/components/netflix-protected/src/main/resources/bootstrap.yml</i></small>

And similar to the `zuul` component, the `netflix-protected` component will have its properties defined in the `cloud-config` component:

```yaml
external:
  property: hello universe

management:
  endpoints:
    web:
      exposure:
        include: refresh
```
<small><i>~/zuulreka-config/components/cloud-config/src/main/resources/netflix-protected.yml</i></small>

The management property shown will expose the actuator's refresh endpoint to tell the API to check for any property updates.  I should also point out that the Configuration Server would need to be restarted for this to work and the `@RefreshScope` annotation __must__ be applied to the component leveraging the property - not on the Application Class (I wanted that to work too).  The final step would be to post to the `actuator/refresh` endpoint:

`curl -x post localhost:8181/netflix-protected/actuator/refresh`

## Finale

Now to see it all work, start the Eureka Server, Cloud Configuration Server, Zuul and API Applications.  Take a quick breather because in short, the service registry needs about a minute and a half to register - however if you want to know more about this, check out [this section](http://cloud.spring.io/spring-cloud-netflix/single/spring-cloud-netflix.html#_why_is_it_so_slow_to_register_a_service) in the docs.

Once all the services are started, use an http client to get the message from the `netflix-protected` controller, going through the Zuul Router:
`curl http://localhost:8080/netflix-protected/hello`

Now, to check that the `@RefreshScope` annotation is working - change the `external.property` for the `netflix-protected` application to say `hello universe!`, and restart the Configuration Server.  Next, `POST` to the `actuator/refresh` endpoint so the API will refresh its properties.  Finally, run the same curl command and get the updated property.

And it is as simple as that.  [Drop me a line](mailto:bstokes@pivotal.io) if you have any feedback for me.  In a follow up article, I will explain how to have this same setup in a Pivotal Cloud Foundry environment.

## Reference
+ [Netflix Eureka](https://github.com/netflix/eureka/wiki/eureka-at-a-glance)
+ [Spring Cloud](https://cloud.spring.io/spring-cloud-static/spring-cloud.html)
+ [Spring Cloud Netflix](http://cloud.spring.io/spring-cloud-static/spring-cloud-netflix/2.0.0.RELEASE/)
+ [Spring Cloud Config](http://cloud.spring.io/spring-cloud-static/spring-cloud-config/2.0.0.RELEASE/)
+ [Spring Cloud Router and Filter: Zuul](http://cloud.spring.io/spring-cloud-static/Finchley.SR1/single/spring-cloud.html#_router_and_filter_zuul)
+ [More Spring Cloud Router and Filter](https://cloud.spring.io/spring-cloud-netflix/multi/multi__router_and_filter_zuul.html)
