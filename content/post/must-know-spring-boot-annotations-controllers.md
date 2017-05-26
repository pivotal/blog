---
authors:
- ianfisher
categories:
- Spring
- Spring Boot
- Annotations
- MVC
date: 2017-05-26T08:18:03-07:00
draft: false
short: |
  Learn about the most essential, must-know annotations for Spring Boot controllers.
title: "Must-Know Spring Boot Annotations: Controllers"
---

# Spring Boot controller annotations

<div class="alert alert-info">
This post was written with Spring Boot v1.5.
</div>

## Wh@t @re @nnotations @ll @bout?

The questions I most commonly get asked by people new to [Spring](https://spring.io/) and [Spring Boot](http://projects.spring.io/spring-boot/) are, "What's the deal with all these annotations?!" and, "Which ones do I _actually_ need to use?"

This post aims to explain the basics of the most common annotations used in Spring Boot controllers. This is by no means intended to be a reference for every feature available to Spring controllers, but should get you started with the basics of setting up a web app that can serve HTML and API endpoints.

In this post we will cover:

1. [Controller types (generic vs. REST)](#ControllerTypes)
1. [Routes](#Routes)
1. [Receiving data](#ReceivingData)
1. [Controller examples](#Examples)

### Annotation basics

Before we dig in, it's important to understand what Java annotations actually are. At a high level, annotations are simply a way to add metadata to Java classes, fields, and methods. Annotations can be made available to the compiler and/or the Java runtime. If you're new to annotations, you can think of them as comments for the compiler or your app's code itself.

Spring makes heavy use of annotations for all kinds of things. For example, a class can be annotated with `@Controller`, `@Service`, or `@Repository` to signify that it is one of those types of objects in your app. In this post, we will be focusing on classes annotated with `@Controller` and the related `@RestController` annotation.

## <a name="ControllerTypes">Controller types</a>

Controllers come in two flavors: generic and REST. You want to put exactly one of these annotations on your controller class.

`@Controller` is often used to serve web pages. By default, your controller methods will return a `String` that indicates which template to render or which route to redirect to.

`@RestController` is often used for APIs that serve JSON, XML, etc. Your controller methods will return an object that will be serialized to one or more of these formats.

It's important to note that generic controllers (annotated with `@Controller`) can also return JSON, XML, etc., but that is outside the scope of this post. Some examples of different controller techniques can be found in [this Spring Boot Guide](https://spring.io/guides/gs/actuator-service/).

## <a name="Routes">Routes</a>

A route is comprised of a URL path and a HTTP method (GET, POST, PUT, PATCH, DELETE). In Spring apps, routes are declared by annotating methods in a controller class.

### HTTP Methods

Methods in your controller can be annotated with one of the following `*Mapping` annotations to specify the HTTP method they handle:

* `@GetMapping`
* `@PostMapping`
* `@PutMapping`
* `@PatchMapping`
* `@DeleteMapping`

These annotations all take in an optional parameter to specify the path; e.g. `@GetMapping("/users")`

A typical REST controller might map its routes like this:

```java
@RestController
public class UsersController {
    @GetMapping("/users")
    public List<User> index() {...}

    @GetMapping("/users/{id}")
    public User show(...) {...}

    @PostMapping("/users")
    public User create(...) {...}

    @PutMapping("/users/{id}")
    public User update(...) {...}

    @DeleteMapping("/users/{id}")
    public void delete(...) {...}
}
```

Another common pattern is to put a `@RequestMapping` annotation on the controller itself. This will prefix all routes within the controller with the specified path.

We could change our example above to be written like this:

```java
@RestController
@RequestMapping("/users")
public class UsersController {
    @GetMapping
    public List<User> index() {...}

    @GetMapping("{id}")
    public User show(...) {...}

    @PostMapping
    public User create(...) {...}

    @PutMapping("{id}")
    public User update(...) {...}

    @DeleteMapping("{id}")
    public void delete(...) {...}
}
```

### Response status

Controller methods can specify a custom response status code. The default for methods returning a value is `200 OK`, and `204 No Content` for void methods.

```java
@PostMapping
@ResponseStatus(HttpStatus.CREATED)
public User create(...) {...}
```

### Path variables

Values provided as path variables can be captured by adding a `@PathVariable` parameter to the method.

```java
// DELETE /users/123

@DeleteMapping("/users/{id}")
public void delete(@PathVariable long id) {...}
```

By default, the parameter name must match the variable name in the path; e.g. a path of `"/users/{id}"` must be accompanied by a `@PathVariable` named `id`. However, this can be overridden if desired.

```java
// GET /users/me@example.com/edit

@GetMapping("/users/{email}/edit")
public String edit(@PathVariable("email") String userEmail) {...}
```

## <a name="ReceivingData">Receiving data</a>

### Query string parameters

Similarly to path parameters, query string parameters can be captured with `@RequestParam`.

```java
// GET /users?count=10

@GetMapping("/users")
public List<User> index(@RequestParam int count) {...}
```

By default, the name of the variable must match the name of the query string parameter, but this can be overridden as well.

```java
// GET /users?num_per_page=50

@GetMapping("/users")
public List<User> index(@RequestParam("num_per_page") int numPerPage) {...}
```

### Posting HTML forms

If we want to create a user with a name and email, we would want a controller method that handles requests from a form like this:

```html
<form action="/users" method="POST">
  <input name="name"/>
  <input name="email"/>
  <button type="submit">Create User</button>
</form>
```

We would create a request model for our Spring app that matches the form structure:

```java
class UserCreateRequest {
    private String name;
    private String email;

    /* Getters & Setters omitted */
}
```

The controller method can then capture the form values by specifying a `@ModelAttribute` parameter.

```java
@PostMapping("/users")
public User create(@ModelAttribute UserCreateRequest request) {...}
```

### Posting JSON

Just like the form example above, we will create a user with a name and email. We want a controller method that handles a JSON POST body like this:

```javascript
{
  "name": "Som Eone",
  "email": "someone@example.com"
}
```

We can use the same request model since it also matches the JSON structure:

```java
class UserCreateRequest {
    private String name;
    private String email;

    /* Getters & Setters omitted */
}
```

Our create method uses the `@RequestBody` annotation to capture the JSON POST body and deserialize it to our `UserCreateRequest` model:

```java
@PostMapping
public User create(@RequestBody UserCreateRequest request) {...}
```

## <a name="Examples">Controller examples</a>

Here are examples using all of the annotations discussed above to create controllers. The controllers don't actually do anything useful (like creating or deleting users), but simply illustrate the annotations needed to create this type of class.

### Generic controller

These controller methods return Strings that indicate the template path to render or the route to redirect to.

```java
@Controller
@RequestMapping("/users")
public class UsersController {
    @GetMapping
    public String index() {
        return "users/index";
    }

    @GetMapping("{id}")
    public String show(@PathVariable long id) {
        return "users/show";
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public String create(@ModelAttribute UserCreateRequest request) {
        return "redirect:/users";
    }

    @PutMapping("{id}")
    public String update(@PathVariable long id, @RequestBody UserUpdateRequest request) {
        return "redirect:/users/" + id;
    }

    @DeleteMapping("{id}")
    public String delete(@PathVariable long id) {
        return "redirect:/users";
    }
}
```

### REST controller

These controller methods return objects that will be serialized to JSON, XML, etc. They do not render HTML templates.

```java
@RestController
@RequestMapping("/users")
public class UsersController {
    @GetMapping
    public List<User> index() {
        return new ArrayList<User>();
    }

    @GetMapping("{id}")
    public User show(@PathVariable long id) {
        return new User();
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public User create(@RequestBody UserCreateRequest request) {
        return new User();
    }

    @PutMapping("{id}")
    public User update(@PathVariable long id, @RequestBody UserUpdateRequest request) {
        return new User();
    }

    @DeleteMapping("{id}")
    public void delete(@PathVariable long id) {}
}
```

## Summary

Hopefully this post has been useful in learning how to create simple controllers in a Spring Boot app. Configuring an app using annotations can seem a bit overwhelming at first, but by knowing the basics you can get a lot done very quickly.

It's also worth knowing that Spring controllers are very powerful and flexible, with many features outside the scope of this article. That said, I would encourage you to get familiar with the basics before deciding which of the more advanced features you need.

Happy Spring development, everyone!
