---
authors:
- ianfisher
categories:
- Spring
- Spring Boot
- TDD
- Humans
date: 2016-01-26T16:53:34-08:00
draft: true
short: |
  Learn how to Spring Boot the easy way with TDD and Thymeleaf. All the gain, half the pain!
title: Spring for Normal People
---

## Attn: Normal People

Like many of my friends and fellow engineers, I have recently started working on some [Spring](https://spring.io/) projects, specifically using [Spring Boot](http://projects.spring.io/spring-boot/). It has been several years since I have worked with Spring, and some things were immediately apparent:

1. I had no idea how to do things The Spring Way™.
2. There is a _ton_ of documentation.
3. Almost all the documentation assumes you already know everything about Spring in order to understand it.
4. Almost none of the documentation mentions testing.

I want to fix that.

This is the first blog post I'm writing about Spring for Normal People who aren't Spring experts but still want to get things done quickly with minimal pain. If you've never used Spring before and want to know how to do some of the common tasks most server apps do, I'm here to help spare you some of the blood, sweat, and tears I have shed learning this stuff.

I am assuming a basic knowledge of Java and Gradle, but even if you haven't used either of those before you should be able to pick things up as we go along.

## A humble beginning

In the spirit of doing The Simplest Thing That Could Possibly Work, let's make a web server that serves a single html page. With tests.

### Create a project

Head over to http://start.spring.io. This site lets you create Spring Boot projects with a few clicks and is definitely the easist way to get things up and running. I used most of the default settings but changed the package to com.[loktar](http://wowwiki.wikia.com/wiki/Orcish), selected Java 8, and picked Gradle for our build system. I also added the `Web` and `Thymeleaf` dependencies.

`Web` gives us stuff we need to create web http endpoints and `Thymeleaf` is a Spring-friendly html template engine.

Click the `Generate Project` button and you'll get a zip file with a new, shiny Spring Boot project. Unzip it in your directory of choice and let's take a look at what we have.

##### Follow along at home!

> Project repo: https://github.com/loktar/spring-blog/tree/master/0-html-page
> Generated zip file: https://github.com/loktar/spring-blog/blob/master/0-html-page/html-page.zip

### What's in it?

Spring Boot apps leverage standard Java project structure. If you're not familiar with that, here are some important places you'll need to know:

#### Directories

- `src/main/java` Put your Java code here
- `src/test/java` Put your Java tests here
- `src/main/resources/static` Put your static assets here (css, js, images, etc.)
- `src/main/resources/templates` Put your Thymeleaf html templates here

#### Build configuration

A good place to start to get to know our project is the build file. Since we chose Gradle as our build system, we got a `build.gradle` file that configures our build. This file manages your dependencies and build tasks, sort of like combining a ruby `Gemfile` and `Rakefile`. The interesting bits for us right now are in the `dependencies` section:

```groovy
// build.gradle

dependencies {
	compile('org.springframework.boot:spring-boot-starter-thymeleaf')
	compile('org.springframework.boot:spring-boot-starter-web')
	testCompile('org.springframework.boot:spring-boot-starter-test') 
}
```

Spring Boot has a lot of starter jars, and the project generator has given us the `-web` and `-thymeleaf` ones based on our dependency choices.

#### The application class

For a Spring app, the Application file is the starting point. It has the `main` method that kicks off your app, and the boilerplate version given to us by the project generator will be fine for now.

```java
// src/main/java/HtmlPageApplication.java

package com.loktar;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class HtmlPageApplication {

	public static void main(String[] args) {
		SpringApplication.run(HtmlPageApplication.class, args);
	}
}
```

#### Kick the tires

Let's run our local server by running the `bootRun` gradle task:

```bash
$ ./gradlew bootRun
```

> Using the local `./gradlew` file instead of just `gradle` ensures we use the _project's_ version of gradle instead of whatever version is installed at a system level.

Our server doesn't have anything useful yet, but we should see the comforting message that it has started successfully:

`com.loktar.HtmlPageApplication           : Started HtmlPageApplication in 7.061 seconds (JVM running for 8.021)`

### Our first page

Now it's time for the fun part! In true TDD fashion we want to add some tests before we write any code. We'll be using JUnit and some Spring test helper classes to make it all work.

There are several different ways to test a Spring controller, but let's start by simply asserting we get a successful response for our new page we will be adding at `/welcome`.

```java
// src/test/java/WelcomeControllerTest.java

package com.loktar;

import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.SpringApplicationConfiguration;
import org.springframework.boot.test.WebIntegrationTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.junit4.SpringJUnit4ClassRunner;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@RunWith(SpringJUnit4ClassRunner.class)
@SpringApplicationConfiguration(classes = HtmlPageApplication.class)
@WebIntegrationTest("server.port = 9999")
public class WelcomeControllerTest {
    private MockMvc mvc;

    @Autowired
    private WebApplicationContext wac;

    @Before
    public void beforeEach() throws Exception {
        mvc = MockMvcBuilders.webAppContextSetup(wac).build();
    }

    @Test
    public void welcome_shouldBeSuccessful() throws Exception {
        mvc.perform(get("/welcome").accept(MediaType.TEXT_HTML))
                .andExpect(status().isOk());
    }
}
```

There is a _lot_ going on here. Let's break it down.

First, there's some standard JUnit test stuff. We have a class to put our tests in, and methods with the `@Test` annotation will be run as our unit tests.

```java
public class WelcomeControllerTest {
    @Test
    public void welcome_shouldBeSuccessful() {
    }
}
```

> Remember, test files go in `src/test/java` while app files go in `src/main/java`

Next are the class annotations:

- `@RunWith(SpringJUnit4ClassRunner.class)` tells the class to run with a JUnit test runner that knows about Spring.
- `@SpringApplicationConfiguration(classes = HtmlPageApplication.class)` tells our test which Application class to use. This is important because the Application class has information that tells Spring how to configure the dependency injection engine.
- `@WebIntegrationTest("server.port = 9999")` tells JUnit this is a web integration test and allows us to use the `WebApplicationContext` class in this file. This means we can do integration test things like simulate requests to URL routes and assert on the responses. You don't have to specify `server.port`, but that will cause Spring to assign a random port when the tests are run, and randomness in tests has only ever lead me to pain and misery.

Then, we've added some boilerplate setup for integration tests. Using the `@Autowired` annotation will cause the Spring dependency injection engine to inject a `WebApplicationContext` instance for our `wac` field when our test class is instantiated. We will also need to build a `MockMvc` instance, `mvc`, that we can use to simulate requests.

```java
private MockMvc mvc;

@Autowired
private WebApplicationContext wac;

@Before
public void beforeEach() throws Exception {
    mvc = MockMvcBuilders.webAppContextSetup(wac).build();
}
```

Finally, we have our actual test that makes a `GET` request to our soon-to-be `/welcome` route and asserts that the response's status code `isOk`, i.e. `200`.

```java
mvc.perform(get("/welcome").accept(MediaType.TEXT_HTML))
        .andExpect(status().isOk());
```

#### Fail first

You can run the test with your IDE (e.g. IntelliJ + JUnit) or by running the gradle `test` task, and we get a nice little failure:

```bash
$ ./gradlew test

...

java.lang.AssertionError: Status 
Expected :200
Actual   :404
```

#### Controller time!

Now time for some app code! Here is the first version of our `WelcomeController`:

```java
// src/main/java/WelcomeController.java

package com.loktar;

import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;

@Controller
public class WelcomeController {
    @RequestMapping(value = "/welcome", method = RequestMethod.GET)
    public String welcome() {
        return "welcome";
    }
}
```

And the interesting bits:

- `@Controller` tells Spring this class is a controller that handles HTTP web requests.
- `@RequestMapping(value = "/welcome", method = RequestMethod.GET)` tells Spring this method handles `GET` requests to the `/welcome` route.
- `return "welcome";` tells Spring that we want to use an html template name `welcome`.

If we run our tests again, we see that we get a new error:

`org.springframework.web.util.NestedServletException: Request processing failed; nested exception is org.thymeleaf.exceptions.TemplateInputException: Error resolving template "welcome", template might not exist or might not be accessible by any of the configured Template Resolvers
`

We can add the missing Thymeleaf template here:

```html
<!-- src/main/resources/templates/welcome.html -->

<!DOCTYPE html>
<html>
    <body>
        <h1>Welcome normal people!</h1>
    </body>
</html>
```

Give the test one more spin and we pass!

```bash
$ ./gradlew test
```

And if we fire up our dev server...

```bash
$ ./gradlew bootRun
```

...we can see the new route has been registered:

`s.w.s.m.m.a.RequestMappingHandlerMapping : Mapped "{[/welcome],methods=[GET]}" onto public java.lang.String com.loktar.WelcomeController.welcome()`

And we can check out the page here: [http://localhost:8080/welcome](http://localhost:8080/welcome)

## Until next time...

So there we go - a real Spring Boot project with tests and templates! If this kind of post is useful for folks, I have a long list of topics I am hoping to cover in the future. Leave a comment and let me know what you want to learn about or what has caused you trouble in the past as you were learning, and we can start to help us Normal People get started with Spring. I am admittedly not a Spring expert, so any corrections or suggestions in this post would be much appreciated as well.

Until next time...