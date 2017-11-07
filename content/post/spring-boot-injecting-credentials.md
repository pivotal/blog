---
authors:
- ayen
categories:
- Spring Boot
- Cloud Foundry
- CF

date: 2017-11-06T00:00:00Z
draft: false
short: |
  Configuring Spring Boot apps in Cloud Foundry is super easy once we take advantage of ConfigurationProperties and user-provided services.
title: "Injecting Credentials Into Spring Boot Apps – The Easy Way"
---

## The Problem

Imagine we want to take advantage of some special services, for example, a cat picture service, in our Java or Kotlin Spring Boot application. And let's imagine that, for security reasons, we have a local development instance of the cat picture service, but the development team doesn't or can't have knowledge of the production instance.

How can we get these credentials into the app without lots of code and configuration?

## Spring Cloud Connectors

[Spring Cloud Connectors](https://cloud.spring.io/spring-cloud-connectors/) is a project aimed at making injecting credentials from services easier. But as far as I know, it doesn't do User-Provided Services automatically. So we'll have to take a different approach.

## A Solution

Cloud Foundry has two standard ways of providing configuration to our applications: through the environment, and through _services_, which can be configured through the `cf` command line tool. As far as our Spring Boot app is concerned, however, a service is just yet another environment variable, which is stored in `VCAP_SERVICES`.

In the case of the cat picture service, I generally prefer a user-provided service over environment variables, since a service allows us to group relevant credentials together, and it allows us to bind these credentials to multiple applications if we choose.

So if we run:

~~~bash
cf cups cat_picture_service -p "username,password"
username> Andromeda
password> RitzyAF
Creating user provided service cat_picture_service in org my-org / space development as user@user.com...
OK
~~~

We can then bind the service to our app with `cf bind-service APP_NAME cat_picture_service`.

## But Wait...It's JSON!

Now, check our app's environment with a `cf env` and we'll see:

~~~json
{
  "VCAP_SERVICES": {
    "user-provided": [
      {
        "credentials": {
          "password": "RitzyAF",
          "username": "Andromeda"
        },
        "label": "user-provided",
        "name": "cat_picture_service"
      }
    ]
  }
}
~~~

Unfortunately the `VCAP_SERVICES` environment variable is a JSON blob, which is annoying to parse and hard to reason about (at least, in Spring Boot land).

Don't take on the unnecessary pain of trying to parse it manually! That is no fun.

~~~java
ObjectMapper mapper = new ObjectMapper();
JsonNode vcapServices = mapper.readTree(System.getEnv("VCAP_SERVICES"));

String userProvidedServices = vcapServices.get("user-provided");
// ...more pain here...
~~~

## `@ConfigurationProperties` To The Rescue!

It turns out, Spring Boot already includes the [Cloud Foundry VCAP Environment Post Processor](https://docs.spring.io/spring-boot/docs/current/api/org/springframework/boot/cloud/CloudFoundryVcapEnvironmentPostProcessor.html), which solves this problem for us! When we create a user-provided service, the VCAP post-processor automatically injects our cat_picture_service into the environment for us as a property called  `vcap.services.cat_picture_service.credentials`.

The `@ConfigurationProperties` annotation allows us to take advantage of this by creating a plain old data object which Spring Boot will automatically inject with the corresponding credentials.

#### Java (with Lombok)
~~~java
@Data
@AllArgsConstructor
@Configuration
@ConfigurationProperties("vcap.services.cat_picture_service.credentials")
public class CatPictureServiceProperties {
  private String username;
  private String password;
}
~~~

#### Kotlin
~~~kotlin
@Configuration
@ConfigurationProperties("vcap.services.cat_picture_service.credentials")
data class CatPictureServiceProperties(var username: String = "", var password: String = "")
~~~

And now we can inject a `CatPictureServiceProperties` object anywhere.

#### Java
~~~java
@RestController
public class DemoController {
  public DemoController(CatPictureServiceProperties catPictureServiceProperties) {
      this.catPictureServiceProperties = catPictureServiceProperties;
  }
  // ...
}
~~~

#### Kotlin
~~~kotlin
@RestController
class DemoController(val catPictureServiceProperties: CatPictureServiceProperties) {/* ... */}
~~~

Alternatively, we can omit the `@Configuration` annotation (leaving just `@ConfigurationProperties`) and annotate the class that needs the properties. Both work fine, but IntelliJ doesn't seem to know how to Autowire `@EnableConfigurationProperties`.

~~~java
@RestController
@EnableConfigurationProperties(CatPictureServiceProperties.class) // ::class in Kotlin
~~~

## Local Properties
Now that we are taking advantage of the VCAP post-processor, we can also now easily provide local/development credentials where needed.

#### application-dev.yml
~~~yaml
vcap:
  services:
    cat_picture_service:
      credentials:
        username: ZeroCool
        password: HackThePlanet! # we can bind this to the environment also: ${CAT_PICTURE_SERVICE_PASSWORD}
~~~

#### Command line
~~~bash
export VCAP_SERVICES_CAT_PICTURE_SERVICE_CREDENTIALS_USERNAME='ZeroCool'
export VCAP_SERVICES_CAT_PICTURE_SERVICE_CREDENTIALS_PASSWORD='HackThePlanet!'
~~~

## #Profit
With automatically configured Properties objects, we get fast feedback when our app is misconfigured (i.e. something would be `null`), because Spring Boot will fail to start. And, we can get type-checking on each of our properties! Just mark each field as `int` or `String` or whatever type we expect.

Configuration Properties are the simplest way to get User-Provided Services into your Spring Boot App. Never parse a `VCAP_SERVICES` JSON blob again!
