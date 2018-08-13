---
authors:
- aloverso
- wscarborough
categories:
- Spring
- API
- Contract Testing
date: 2018-08-07T19:35:22Z
draft: false
short: |
  Banish magic numbers from your frontend contract tests!
title: Frontend Contract Tests Without Magic Numbers
image: /images/pairing.jpg
---

This blog post is about frontend contract testing ([here's a primer on contract tests if you'd like to learn more](https://spring.io/blog/2018/02/13/spring-cloud-contract-in-a-polyglot-world)), and making assertions about contract responses without hardcoding magic numbers into your frontend tests.

We will explain how we fell into the magic number anti-pattern in our frontend tests. Then, we demonstrate how to use a contract-stub reader to avoid this. We'll link you to an npm library we wrote, to use in your own code. Additionally, we provide a recipe for a build-your-own version if you don't use npm or just-do-not-do-JavaScript.js

The examples provided here are written in Kotlin and JavaScript, making use of Spring Boot, Spring Cloud Contract, and Jest. However, the patterns discussed are usable across any language or framework.

## Motivation

We recently encountered a situation on a project where our frontend contract tests were becoming hard to read due to magic numbers and strings that were required for them to pass on the frontend.

We didn't originally intend to place these magic numbers in our tests, but wound up adding them to help assert on response shape. After all, if our response has the right shape then it can be processed correctly.
It is really easy to fall into this magic-number trap! Here's what this looks like in a contract test:

```javascript
describe('fetching noodles', () => {
  it('should fetch the latest noodle ratings',  async () => {
    const noodleFetcher = new NoodleFetcher()

    const noodleResponse = await noodleFetcher.fetchNoodles()
    expect(noodleResponse).toEqual([
      {
        "noodle": "wheat",
        "rating": 10
      },
      {
        "noodle": "rice",
        "rating": 11
      },
      {
        "noodle": "zucchini",
        "rating": 9
      }
    ])
  })
})
```

You can see that we expect to get a list of noodles, and we expect those noodles to be in a specific format. As a result, there are a lot of magic strings and numbers here! For example, why does "wheat" have a rating of 10 instead of some other number? It's not immediately clear where this data coming from, and why we bother to assert on it. You wouldn't have any context about this data unless you went out of your way to see what was defined in the Spring Cloud Contract file:

```groovy
package contracts

org.springframework.cloud.contract.spec.Contract.make {
    request {
        method 'GET'
        url '/api/noodles'
    }
    response {
        status 200
        body '''
      [
          {
             "noodle": "wheat",
             "rating": 10
          },
          {
               "noodle": "rice",
               "rating": 11
            },
            {
               "noodle": "zucchini",
               "rating": 9
            }
      ]
   '''
    }
}
```


These files live in completely different locations in our codebase, and someone new to the project may not recognize their relationship. This sort of tribal knowledge will be lost if any long term developers leave the project without informing new developers, and it could easily become one of those scary "don't touch that; it just works" pieces of code.

Because of this disconnect, it is painful to maintain this kind of test. Why should these numbers be a permanent part of our frontend code, if the contract is likely to change as development progresses and our API changes with it? How can we make it more obvious that the test depends on the contract?

One solution could be to assert that all expected keys exist in the payload, and that their values have the correct type. For example, we could assert that the `noodle` key exists and that its value is a string. But this would still leave us with more maintenance in the future if the contract should change or if we just have a large response object to parse.

However, we would like to propose a simpler way of dealing with these issues by asserting on the generated response body rather than asserting on individual values.

## High Level Explanation

A Spring application that uses the Spring Cloud Contract library generates new JSON stubs every time that it passes its contract tests. Although these JSON stubs are meant to be loaded by WireMock, there is no reason why you can't just load them up and parse them yourself in your own frontend tests! This has numerous advantages over asserting on random number and string fields because:

- It allows you to write shorter, more focused, and easier to maintain contract tests. The latest generated contract JSON will automatically be used in your frontend tests.
- It allows you to focus more on parsing a general response shape than worrying about the specific details of a particular stubbed response.
- It allows you to keep magic numbers, strings, and other values out of your frontend tests while still allowing for historical matching if needed (e.g. you could check out an old commit, and regenerate contract JSON from earlier versions of the project).

In order to do this, you need to be able to read generated contract stubs into your test and parse them as JSON. This way, you can assert that your frontend `NoodleFetcher` gets and parses the data from the server correctly, without actually caring what that data is.

## Server Setup

To view the setup of our Spring application, [check out our demo repository](https://github.com/Anne-and-Walter/spring-cloud-contract-json-reader-demo). It is a barebones Spring application with a single controller called `NoodleController` that returns a hardcoded list of noodles and their respective ratings.

```kotlin
@CrossOrigin(origins=["*"])
@RestController
class NoodleController {

    @GetMapping("/api/noodles")
    fun getNoodles(): List<Noodle> {
        return listOf(
                Noodle(
                        noodle = "wheat",
                        rating = 10
                ),
                Noodle(
                        noodle = "rice",
                        rating = 11
                ),
                Noodle(
                        noodle = "zucchini",
                        rating = 9
                )
        )
    }
}

data class Noodle(
        val noodle: String,
        val rating: Int
)
```


We have a contract test for `NoodleController` to assert that it fulfills its part of the handshake bargain - when requested for noodles at `/api/noodles`, it will return a defined list. 

*(Please note that in a more extensive codebase that did not hardcode its controllers, these values would be stubbed in your backend application test code so that your controller will always return the same values and pass the contract test.)*

## Client setup

For demo purposes, we created just one client file- a `NoodleFetcher` responsible for making a server call to get noodles and their ratings from our Spring API. And to test the `NoodleFetcher`, we have a `NoodleFetcher` test that makes use of the generated contract JSON:

```javascript
const { NoodleFetcher } = require('../NoodleFetcher')
const readJsonContractFile = require('spring-cloud-contract-json-reader');

describe('fetching noodles', () => {
  it('should fetch noodle ratings with contracts',  async () => {
    const noodleFetcher = new NoodleFetcher()
    const contractData = await readJsonContractFile('shouldReturnAvailableNoodles.json')

    const noodleResponse = await noodleFetcher.fetchNoodles()
    expect(noodleResponse).toEqual(JSON.parse(contractData))
  })
});
```

This test is much simpler than the original one that you saw at the beginning of this article, and it no longer has any magic numbers or strings. Hooray! We use a function called `readJsonContractFile` to load in the JSON generated from our backend contract test, and simply assert that our `NoodleFetcher` reads in the same data that WireMock returns from our contract.

To help make this technique easier to use, we created [an npm library](https://www.npmjs.com/package/spring-cloud-contract-json-reader) that loads contract stubs that were generated by Spring Cloud Contract and parses them as JSON. The library is [open-sourced on GitHub](https://github.com/Anne-and-Walter/spring-cloud-contract-json-reader).

Although we used this on a Kotlin (Spring) and JavaScript project, this technique could be used with other languages/frameworks as well. One interesting use case would be for iOS or Android test suites to load in generated contract JSON stubs and use them for validation! Another would be for a RESTful API that consumes other RESTful APIs to use generated contract JSON stubs to help make sure that it receives and parses the correct response.

If you want to implement this pattern with any other language, here's a pseudocode recipe for creating your own `readJsonContractFile` in any language:

```
fun readContractJsonFile(filename) {
  // get absolute path to code from version control system
  var repoRoot = exec('git rev-parse --show-top-level')
  // get relative path to contract stubs from user-set env var
  var pathToContracts = env['CONTRACT_JSON_BASE_PATH']
  // create absolute path to contract file
  var absolutePath = [repoRoot, pathToContracts, filename).join("/")
  // return contract as object
  return json.parse(readFile(absolutePath))
}
```

Enjoy! Go forth and banish those magic numbers!
