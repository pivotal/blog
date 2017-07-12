---
authors:
- mparker
categories:
- Agile
- TDD
date: 2017-06-20T16:43:05-04:00
draft: false
short: |
  A guide to understanding and effectively utilizing test doubles.
title: The Test Double Rule of Thumb
image: /images/pairing.jpg
---

{{< responsive-figure src="/images/pairing.jpg" class="left" >}}

## TL;DR

Use doubles to stand in for collaborating components in your tests:

* Use a **dummy** to ensure a collaborator is **never used** in a certain scenario. 
* Use **stubs** to double **read only** collaborators. 
* Use **spies** to double **write only** collaborators. 
* Refactor a spy into a **mock** to **dry up duplicate spy verification** between tests.
* Use **fakes** to double **read/write** collaborators, and write contract tests to verify their behavior.
* Join these doubles together into new combinations when appropriate, but carefully weigh the tradeoffs when doing so

**And lastly, break all of these rules whenever the benefit they provide isn't worth the cost.**

* [Who Is This Post For?](#who-is-this-post-for)
* [Overview](#overview)
* [What's a Test Double?](#what-s-a-test-double)
* [A Guide to Choosing the Appropriate Test Double](#a-guide-to-choosing-the-appropriate-test-double)
  * [Dummy](#dummy)
  * [Spy](#spy)
  * [Mock](#mock)
  * [Stub](#stub)
  * [Fake](#fake)
    * [Contract Test](#contract-test)
* [Double Combos](#double-combos)
* [What about test double libraries?](#what-about-test-double-libraries)
* [On the Importance of Communicating Precisely](#on-the-importance-of-communicating-precisely)

## Who Is This Post For?

Test Driven Development (TDD) is a practice that seems simple in concept, yet often proves challenging in practice. Perhaps you've recently started learning TDD, and you're ready to move beyond the simple examples of testing a class with no collaborators. This post will introduce you to "doubling" – a practice you'll find essential when testing your real world code.

Or perhaps you've been practicing TDD for a while, and although you've used test doubles through test double libraries, you've never taken the time to study the fives types of test doubles specifically. This post will help you understand test doubles more clearly, and wield them more effectively. 

## Overview

We'll start by describing the term "test double" and where it comes from. Then we'll examine each type of double, focusing on the rules of thumb and analyzing the tradeoffs. Then, we'll look at test double libraries, their value, and their danger, which will segue into a discussion on the importance of communicating precisely. 

## What's a Test Double?

A test double is simply a stand-in for something that would be otherwise real in the execution of your program. 

The term *test double* is borrowed from Hollywood. That might surprise you; I sometimes teach a little workshop on testing and often find that engineers that do TDD don't know where the term *test double* comes from. I didn't know at first either. It's a play on the term "stunt double." What's a stunt double? Well, Hollywood likes to make action movies. In those movies, the actors have to act out dangerous situations—stunts like jumping out of a speeding train. The problem is, famous actors get paid a lot of money, and if they got hurt or killed, the movie would be ruined. Investors don't like risk, so instead of asking the highly paid actor to act out dangerous scenarios, directors pay someone else that looks like the actor to do it. This person, or “double”, isn't famous; and if the double gets hurt or killed, the movie isn't ruined. 

Well, test doubles are not all that different. They double for real objects, and make it easier for us to test the behavior we want. It's easy to test an object that has no collaborators; however, when an object collaborates with other objects, it can make testing harder. 

For example, perhaps a collaborator reads information from an external system that we have no control over; in that case, unless we double that collaborator and simulate the external system, we won't have any way to elicit all of the possible use cases and error conditions that can arise from interacting with that external system. 

Or perhaps we have control over that external system, but it's still incredibly slow to interact with; coupling your tests to it would make your tests too slow to be useful. 

Another pain point can arise from testing objects that interact with asynchronous collaborators; test doubles can help us address those challenges. 

Or imagine a scenario where there are many possible collaborators that could be provided at runtime to satisfy a specific type; although we own the type, we don't own the implementations. In this situation, we can use a test double (and potentially a contract test). 

Lastly, imagine that setting up and tearing down a collaborator is expensive or tedious; we could potentially use a test double to ease testing in this situation.

These examples are illustrative, not exhaustive. You will find all kinds of situations in which test doubles could be useful when testing real-world code.

## A Guide to Choosing the Appropriate Test Double

There are five primary types of test doubles: 

* Dummy (a double that blows up when used)
* Stub (a double with hard-coded return values)
* Spy (a double that you can interrogate to verify it was used correctly)
* Mock (a spy that verifies itself)
* Fake (a behavioral mimic)

For a concise introduction to them, start with Robert Martin's[ The Little Mocker](https://8thlight.com/blog/uncle-bob/2014/05/14/TheLittleMocker.html). Instead of repeating his descriptions, I'd like to complement them here. 

During this post, we'll be testing the control algorithm for launching a missile. Here's the API for our control algorithm:

```java
static void launchMissile(Missile missile, LaunchCode launchCode){
  //..
}
```

The `launchMissile` algorithm's job is to determine if the provided `LaunchCode` is valid, and if so, to launch the missile. 

Now, while testing this, we don't want `launchMissile` to interact with a real, live missile. That could be disastrous, to say the least. Instead, we'll want to double that missile. That means that `launchMissile` can't depend on a real missile. Instead, it should depend on the idea of a missile, and allow the runtime to provide a missile to work with. The "idea" of a missile is the `Missile` interface. 

Without going into too much detail, it's worth noting that we just described using the dependency inversion principle to safely test our control algorithm. Dependency inversion is what happens when the source code dependencies oppose the runtime flow of control. For example, imagine that our weapons system is operational, and our `launchMissile` is interacting with a `MegaMissile9000` class created by a missile vendor. At runtime, our `launchMissile` method will pass control to their `MegaMissile9000`. However, their `MegaMissile9000` implements our `Missile` interface – in other words, they have a source code dependency on us. That's dependency inversion in a nutshell. The runtime flow of control moves in one direction – from high level policy (i.e., our control algorithm) to low level details (i.e., their missile) – but the source code dependencies travel in the opposite direction: the low level details depend on the high level policy. And whenever you're testing something that collaborates with inverted dependencies, you'll almost always want to double those inverted dependencies in the test. 

### Dummy

To fire the missile, valid launch codes must be provided. There's lots of ways launch codes could be invalid. For example, they might be expired. In that scenario, you want to ensure that the missile is not fired — obviously, that's really, really important. What's one way you could get some confidence from an automated test that missile was not fired in that scenario? You could use a dummy missile:

```java
class DummyMissile implements Missile {
  @Override
  void launch(){
    throw new RuntimeException();
  }
}
```

As we noted above, a Dummy is a double that blows up (no pun intended) if it gets used. This `DummyMissile` throws exceptions whenever anyone tries to call `launch()` on it. Now, you can write a test that will fail if `launchMissile` attempts to use the `DummyMissile`: 

```java
@Test
void givenExpiredLaunchCodes_MissileIsNotLaunched(){
  launchMissile(new DummyMissile(), expiredLaunchCode);
}
```

And that's it. Now if `launchMissile` attempts to call `launch()` on the `DummyMissile`, the `DummyMissile` will throw an exception, and the test will fail. 

#### Trade-offs

Dummies are simple. You can drop them into a test and feel somewhat satisfied that the dummy was never used. 

However, you might argue that this test isn't very intuitive. Indeed, there's no assertion in it. Even if you know what a dummy is, it might still not be clear how this test works. 

Also, I mentioned above that you can feel "somewhat satisfied". That's because the following implementation would make the test pass: 

```java
static void launchMissile(Missile missile, LaunchCode launchCode){
  try {
    missile.launch();
  } catch (Exception e){}
}
```

In other words, an evil implementer could launch the missile and still make the test pass. To address some of these concerns, let's see what this test would have looked like had we used a Spy instead of a Dummy.

### Spy

Let's revisit the `givenExpiredLaunchCodes_MissileIsNotLaunched` test. Instead of a dummy, let's create a `MissileSpy`:

```java
class MissileSpy implements Missile {
  private boolean launchWasCalled = false;
  @Override
  void launch(){
    launchWasCalled = true;
  }

  boolean launchWasCalled(){
    return launchWasCalled;
  }
}
```

Notice that we created a private boolean flag to determine if the `launch()` method has been called. We also created a spy method `launchWasCalled()` for interrogation. Now we can use the spy in our test like this:

```java
@Test
void givenExpiredLaunchCodes_MissileIsNotLaunched(){
  MissileSpy missileSpy = new MissileSpy();

  launchMissile(missileSpy, expiredLaunchCode);

  assertFalse(missileSpy.launchWasCalled());
}
```

If launchMissile uses the launch method on missileSpy, the test will fail!

#### Trade-offs

Compare and contrast this test with the previous test where we used a dummy. You might argue that this test is more readable. Even if you didn't really know what a Spy was, you could probably still read this test and understand how it works.  It has a traditional test structure: setup, act, assert – and the assertion is explicit. 

It also feels more robust. It was possible to make the original test that used a dummy pass by swallowing the exception the dummy threw in the production code, which would have had disastrous consequences. However, by using a spy, we've eliminated the possibility of such foul play. 

On the other hand, there's more code – and unlike a Dummy, if you forget to assert on the spy, you could get a false positive. The test is also more coupled to the implementation now – it knows specifics about the implementation, instead of just focusing on behavioral outputs. 

Let's look at what we could do in a situation where multiple tests need to verify that the missile isn't launched. 

### Mock

Our product owners have a new requirement: out of an abundance of caution, they want us to disable the missile anytime we abort a launch due to invalid launch codes. They call is a "code red" abort. We start by updating our first test: 

```java
@Test
void givenExpiredLaunchCodes_MissileIsNotLaunched(){
  MissileSpy missileSpy = new MissileSpy();

  launchMissile(missileSpy, expiredLaunchCode);

  assertFalse(missileSpy.launchWasCalled());

  assertTrue(missileSpy.disableWasCalled());
}
```

Our product owners also give us another new requirement: launch codes must be cryptographically signed in order to be valid, and therefore, if someone tries to launch a missile with unsigned launch codes, the missile shouldn't launch. We write another test: 

```java
@Test
void givenUnsignedLaunchCodes_MissileIsNotLaunched(){
  MissileSpy missileSpy = new MissileSpy();

  launchMissile(missileSpy, unsignedLaunchCode);

  assertFalse(missileSpy.launchWasCalled());
  assertTrue(missileSpy.disableWasCalled());
}
```

Notice that we've duplicated the assertions between the two scenarios. Cleaning up that duplication will make the test easier to read. We start by creating a helper method in the test called `verifyCodeRedAbort`: 

```java
private void verifyCodeRedAbort(){
  assertFalse(missileSpy.launchWasCalled());

  assertTrue(missileSpy.disableWasCalled());
}
```

Then, noticing that this method really just calls methods on `missileSpy`, we decide to move the method down onto the `missileSpy` itself:

```java
class MissileSpy implements Missile {
  private boolean launchWasCalled = false;
  private boolean disableWasCalled = false;

  @Override
  void launch(){
    launchWasCalled = true;
  }

  boolean launchWasCalled(){
    return launchWasCalled;
  }

  boolean disableWasCalled(){
    return disableWasCalled;
  }

  void verifyCodeRedAbort(){
    assertFalse(launchWasCalled());

    assertTrue(disableWasCalled());
  }

}
```

Now that `verifyCodeRedAbort` is the only method that calls `launchWasCalled()` and `disableWasCalled()`, we decide to inline the two methods: 

```java
class MissileSpy implements Missile {
  private boolean launchWasCalled = false;
  private boolean disableWasCalled = false;

  @Override
  void launch(){
    launchWasCalled = true;
  }

  @Override 
  void disable(){
    disableWasCalled = true;
  }

  void verifyCodeRedAbort(){
    assertFalse(launchWasCalled);
    assertTrue(disableWasCalled);
  }
}
```

At this point, the name `MissileSpy` seems misleading. You can no longer interrogate this spy through its public interface. Instead, all you can tell it to do is to verify that a code red abort happened. 

So if it's not a spy, what is it? A mock! Mocks are simply self-verfiying spies. So, we rename `MissileSpy` to `MockMissile` and update the tests: 

```java
@Test
void givenUnsignedLaunchCodes_MissileIsNotLaunched(){
  MockMissile mockMissile = new MockMissile();
  
  launchMissile(mockMissile, unsignedLaunchCode);

  mockMissile.verifyCodeRedAbort();
}

@Test
void givenExpiredLaunchCodes_MissileIsNotLaunched(){
  MockMissile mockMissile = new MockMissile();

  launchMissile(mockMissile, expiredLaunchCode);

  mockMissile.verifyCodeRedAbort();
}
```

It's important to emphasize that we didn't start with a mock; instead, we refactored from a spy to a mock after noticing certain code smells: *Duplicated Code* and *Feature Envy*. We then used the *Extract Method* and *Move Method* refactorings to clean up the code, thereby transforming our Spy into a Mock. If code smells and named refactorings are new to you, you can find out more about them in Martin Fowler's [Refactoring](https://www.amazon.com/Refactoring-Improving-Design-Existing-Code/dp/0201485672) book. It's easily one of the most essential books written on software development and craftsmanship; it's also the reason that IDEs have automated refactorings built right into them.

#### Tradeoffs

There's a small tradeoff here in indirection. Where we had explicit assertions in the tests before, we now have a single call to `verifyCodeRedAbort`. You could argue that we have increased the cognitive burden of understanding the tests, since now you have to look into the mock to understand all of the details of the expected behavior.

However, if we have multiple tests that all make the same set of multiple assertions about a spy, that also increases the cognitive burden of understanding the test suite. That duplication also exposed us to a maintenance burden: if we needed to add another assertion to that list of assertions (e.g., imagine we also needed to sound the `alarm()` on the missile), we would have had to go to each test and add the assertion. The possibility of making a *copy/paste* error is high, and the time it takes to make that change is high compared to the Mock solution. The Mock centralized all of the assertions into a single place, meaning there's only one place in the code where we need to make a change whenever the meaning of a *codeRedAbort* changes. 

As an aside, there's a little more duplication in this test that this author would clean up if left to his own devices. 

```java
@Before
void setup(){
  mockMissile = new MockMissile();
}

@Test
void givenUnsignedLaunchCodes_CodeRedAbort(){
  launchMissile(mockMissile, unsignedLaunchCode);

  mockMissile.verifyCodeRedAbort();
}

@Test
void givenExpiredLaunchCodes_CodeRedAbort(){
  launchMissile(mockMissile, expiredLaunchCode);

  mockMissile.verifyCodeRedAbort();
}
```

### Stub

Although we haven't mentioned stubs yet, we've been using them. You might have noticed that I never defined `unsignedLaunchCode` or `expiredLaunchCode`. What are they? They're stubs! They might look something like this: 

```java
class UnsignedLaunchCodeStub extends ValidLaunchCodeStub {
  @Override
  boolean isUnsigned(){
    return true;
  }
}

class ExpiredLaunchCodeStub extends ValidLaunchCodeStub {
  @Override
  boolean isExpired(){
    return true;
  }
}

class ValidLaunchCodeStub extends LaunchCode {
  @Override
  boolean isUnsigned(){
    return false;
  }

  @Override
  boolean isExpired(){
    return false;
  }
}
```

As you can see, stubs double read-only collaborators and provide hard-coded return values. In this case, we took a stub of a valid launch code, then invalidated it by overriding the `isUnsigned` or `isExpired` methods. 

This is nice, since it gives us the appearance of a launch code in a given state without having to do all the work to put a real launch code into that state. If we used real launch codes instead, we would have to set them up correctly, which would make our tests coupled to their setup requirements and behavior. That coupling would lead to fragile tests (tests that break even though the behavior they're testing hasn't changed) since changes to those LaunchCode setup requirements would require our test to change too in order to continue working properly.

### Fake

The only test double we haven't covered yet is a fake. That's because we haven't needed it. If you look back at the rules of thumb listed in the *TL;DR,* you'll see that we said to use fakes to double collaborators with read/write interfaces. Well, so far, none of our collaborators have a read/write interface. The `LaunchCode` has a read-only interface (i.e., it only has query methods on it), while the `Missile` has a write-only interface (i.e., it only has void methods). That's why stubs, spies, and mocks made a lot of sense. Stubs double read-only interfaces; spies and mocks double write-only interfaces. 

Let's imagine a new requirement: launch codes can only be used once. If someone gives us launch codes that we've used to launch another missile before, we must perform a "code red abort." 

We start by writing the test: 

```java
@Test
void reusedLaunchCodeTriggersCodeRedAbort(){
  launchMissile(missile,     validLaunchCode);
  launchMissile(mockMissile, validLaunchCode);

  mockMissile.verifyCodeRedAbort();
}
```

In this test, we use the same launch code (`validLaunchCode`) twice. The first time we use it, we launch `missile`. The second time, we attempt to launch `mockMissile`. We then verify that we've performed a code red abort on the `mockMissile` launch. 

There's a problem. How will we keep track of the fact that `validLaunchCode` has been used? Obviously, `launchMissile` itself can't have a memory between calls - it's a static method! And a `LaunchCode` is an immutable value object. 

Clearly, we've run into the need for persistence! We have to persist – *beyond the lifetime of the process* – the fact that we've used a launch code. But how should we persist it? Should we use a database? Can we? If so, what kind? SQL, or NOSQL? Or should we use a simple key/value store? What ORM should we use? Or should we forgo ORM frameworks entirely? What are the security tradeoffs between these different technologies and frameworks? And where will our control algorithm be deployed? What are the constraints of that environment that we have to consider?

That's a lot of questions that we need to answer. We'll need to talk to a lot of people to come to a decision. What if we make the wrong decision? We don't even know what kind of API we'd like yet for our persistence layer. 

Whenever you're in this situation, ask yourself this: can you delay this technical decision for some time while you accumulate more information? That way, when it comes time to make a decision, you'll have more data to draw on. 

In this case, we can certainly delay making those technical decisions, *while still moving forward with implementing this requirement*. Remember, to help us make those technical decisions about persistence, one of the things we'd like to know is what kind of API we would ideally like to have for our persistence solution. So let's tease that out first. 

Let's imagine an interface called `UsedLaunchCodes` that keeps track of, well, used launch codes! We'll need to provide an instance of an implementation of that interface to launchMissile:

```java
@Test
void reusedLaunchCodeTriggersCodeRedAbort(){
  launchMissile(missile,     validLaunchCode, usedLaunchCodes);
  launchMissile(mockMissile, validLaunchCode, usedLaunchCodes);

  mockMissile.verifyCodeRedAbort();
}
```

Doing some programming by wishful thinking, we write the code we wish we had in `launchMissile`:

```java
static void launchMissile(Missile missile, LaunchCode launchCode, UsedLaunchCodes usedLaunchCodes){
  if (usedLaunchCodes.contains(launchCode) || /*more invalid cases*/)
    missile.disable()
  else {
    missile.launch();
    usedLaunchCodes.add(launchCode);
  }
}
```

We've penciled in two methods we wish we had: contains and add. Furthermore, it's clear that there's a relationship between the two: `usedLaunchCodes` should contain launch codes that have been added! Also, notice that the repo has a read/write interface. This sounds like a job for... a fake!

Fakes are quite different from the four other types of test doubles. The other test doubles are easy to distinguish from the real collaborators they're a double for. For example, it's hard to imagine mistaking a dummy or a stub for their real counterparts. Fakes, on the other hand, are intended to be indistinguishable from their real counterparts. They should mimic all of the expected behavior of the type that they are doubling. In fact, it's essential that they mimic the type's behavior, since we intend to pass them to our production code from our tests and let the production code use them just like the real thing. 

How do we ensure a piece of code does exactly what's expected of it? We write a test! 

```java
class UsedLaunchCodesTest {
  @Test
  void contains(){
    UsedLaunchCodes usedLaunchCodes = new FakeUsedLaunchCodes();

    assertFalse(usedLaunchCodes.contains(launchCode));

    usedLaunchCodes.add(launchCode);

    assertTrue(usedLaunchCodes.contains(launchCode));
  }
}
```

For now, we've hardcoded our test against a `FakeUsedLaunchCodes`. Don't worry about that for now; let's just get our `FakeUsedLaunchCodes` to pass this test.

```java
class FakeUsedLaunchCodes implements UsedLaunchCodes {
  private HashSet<LaunchCode> set = new HashSet<>();

  void add(LaunchCode launchCode){
    set.add(launchCode);
  }

  boolean contains(LaunchCode launchCode){
    return set.contains(launchCode);
  }
}
```

You might be saying to yourself, "Hey, that's cheating! Our fake doesn't persist beyond the lifetime of the process - it just stores everything in memory!" And you're right, but that's exactly the point! Our goal is to make the fake exhibit the type's behavior in the cheapest way possible. We're allowed to cheat. That's why it's called a Fake! It's an imposter!

Now that we've got our `FakeUsedLaunchCodes`, we can use it in the `reusedLaunchCodeTriggersCodeRedAbort` test: 

```java
@Test
void reusedLaunchCodeTriggersCodeRedAbort(){
  UsedLaunchCodes usedLaunchCodes = new FakeUsedLaunchCodes();

  launchMissile(missile,     validLaunchCode, usedLaunchCodes);
  launchMissile(mockMissile, validLaunchCode, usedLaunchCodes);

  mockMissile.verifyCodeRedAbort();
}
```

And our test now passes!

#### Contract Test

Let's look back at the `UsedLaunchCodesTest`. Right now, it's hardcoded to test `FakeUsedLaunchCodes`. But that test really represents the behavior that we expect of any class implementing the type `UsedLaunchCodes`. That's called a "Contract Test." That term goes back a long way; J. B. Rainsberger pioneered these types of tests in the early to mid 2000s. You can read his original writings on the topic on the [C2 Wiki](http://wiki.c2.com/?AbstractTestCases). The contract metaphor feels apt; just like contracts in the real world, contract tests have two parties. The writer of the contract test and the implementer of the contract test are both agreeing to something. The writer agrees that any code that passes the contract test will work as expected in their system. The implementer agrees to make their code behave as expected by passing the contract test.

We can turn our `UsedLaunchCodesTest` into a contract test by making it abstract (I'll also rename it slightly): 

```java
abstract class UsedLaunchCodesContract {
  protected UsedLaunchCodes usedLaunchCodes;
  protected abstract UsedLaunchCodes createUsedLaunchCodes();

  @Before
  void setup(){
    usedLaunchCodes = createUsedLaunchCodes();
  }

  @Test
  void contains(){
    assertFalse(usedLaunchCodes.contains(launchCode));

    usedLaunchCodes.add(launchCode);

    assertTrue(usedLaunchCodes.contains(launchCode));
  }
}
```

And then we can make a new test for our `FakeUsedLaunchCodes` that extends `UsedLaunchCodesContract` and implements the abstract `createRepo` method: 

```java
 class FakeUsedLaunchCodesTest extends UsedLaunchCodesContract {
 
   @Override
   protected UsedLaunchCodes createUsedLaunchCodes(){
     return new FakeUsedLaunchCodes();
   }
   
 }
```

Our `FakeUsedLaunchCodes` inherits all of the tests in the contract. As an aside, it's worth noting that we're using the factory method pattern (which is itself a specialization of the template method pattern) here. If those patterns are new to you, I recommend reading about them in Robert Martin's book *Agile Software Engineering: Principles, Patterns, and Practices*.

Later, when we make all of those hard technical decisions around persistence and we're ready to build our real `UsedLaunchCodes` implementation, the good news is the tests for that implementation are already written! All we have to do is make our real persistence solution pass the `UsedLaunchCodesContract` test. 

#### Trade-offs

By using a fake, we were able to delay decisions about persistence technologies and frameworks while gaining information about a desirable API for our persistence layer.

Fakes are great – *when the behavior you're mimicking is simple*. However, when the behavior is complex, or when there's simply a lot of behavior to fake, then the benefit the fake provides might be outweighed by the cost of implementation. In that case, see if another test double (or combination of test doubles) will do – or if you could use a real collaborator instead of a double at all. 

Also, keep in mind that there are degrees of fakes. The fake we created in this example was a full-on behavioral mimic. That's quite a commitment. In this case, the behavior we're mimicking is incredibly simple, so the commitment isn't a burden. 

However, Fakes can also be less of a commitment. Perhaps there's only a portion of the interface that you're interested in faking. Or perhaps you only want to mimic a certain piece of expected behavior in a very naive way (for an example, go back and re-read the Fake section in [The Little Mocker](https://8thlight.com/blog/uncle-bob/2014/05/14/TheLittleMocker.html)). In those cases, you won't need a contract test for the fake.

Lastly, it's worth noting that, by teasing out the API we wish we had for our persistence layer *before* choosing a persistence technology, we've actually created some requirements for our ideal persistence technology. The API we've teased out is synchronous; it also assumes immediate consistency (as opposed to eventual consistency). Obviously, an ACID-compliant database would work well here. However, what if the organization instead forced a BASE persistence technology onto us? That would apply a sort of backpressure onto this design. In that case, one way we could manage that backpressure is by pushing the complexity down into the adapter layer, adapting the asynchronous, eventually consistent persistence technology into the synchronous, immediately consistent API that we've teased out here (likely through polling and blocking).  


### Double Combos

Although we haven't seen it yet, it's possible to create double combos – i.e., a single double that is, in itself, multiple different types of doubles. I often find it useful to combine dummies with stubs or spies. For example: 

```
class DummySpyMissile implements Missile {
  private boolean disableWasCalled = false;

  @Override
  void launch(){
    throw new RuntimeExpection();
  }

  @Override 
  void disable(){
    disableWasCalled = true;
  }

  boolean disableWasCalled(){
    return disableWasCalled;
  }
}
```

This is a dummy that blows up when launch is called. But you can also spy on it to see if disable was called. 

#### Trade-offs

You typically combine doubles to make your tests easier to write, or to clean up duplication in the tests. However, keep in mind that you're also increasing the cognitive burden of understanding the double. And all of the trade-offs you had to weigh for a single test double type now have to be weighed together for your combination double. Use them with care. YMMV. 

## What about test double libraries?

Even if you had never formally studied test doubles before reading this article, chances are, if you've ever done any amount of automated testing, you've used doubles. And if you're like me, you were probably introduced to doubles through testing libraries. I first learned about doubles by using *rspec* many years ago. If you're a Java programmer, your first introduction was likely through *Mockito*, or perhaps *JMock*, depending on how long you've been testing. If you're a Javascript programmer, you may have first learned about spies through *Jasmine*.

Many of these libraries do a great job of helping you utilize test doubles; the challenge is, they don't always make it clear what kind of test double you're using. For example, in *rspec*, you call the method `double` to create all different types of doubles. With no arguments, a dummy is created. With hash arguments, a stub is created. When combined with `expect` `to_receive`  statements, the stubs are transformed into spies – that get automatically verified at the end of the test. *Mockito* suffers from a similar challenge. Doubles are created through a `mock` method – and by default, those doubles are spies. They can be turned into spy/stub combos by using the `when` method. 

I don't say any of this to diminish their value. Used effectively, they can reduce the amount of code required to create doubles, which is fantastic! Many of them also have other helpful features – like ensuring that a mock is verified at the end of the test for you, so that you don't have to remember to call the verify method yourself. However, if you've never made your own test doubles without a framework, you may struggle to use the frameworks effectively, or weigh the tradeoffs you are making by using a library instead of rolling your own.

## On the Importance of Communicating Precisely

As Robert Martin points out in [The Little Mocker](https://8thlight.com/blog/uncle-bob/2014/05/14/TheLittleMocker.html), many developers use the term "mock" and “mocking” to mean “double” and “doubling” in general. Robert Martin refers to this as “slang.” However, the problem is larger than that. Many developers use all of the terms imprecisely; for example, they might say “fake” when they mean “stub”, or “stub” when they mean “dummy”, or “mock” when they mean “spy.” Or they might refer to all of them as simply “mocks.” 

This abuse of test double terminology is often not intentional, and never malicious. Sometimes developers use the wrong term because they don't know about all five types of test doubles, but just one or two. Or developers know the right type of test double to use, but disagree on the name of that test double. As we saw in the previous section, this is largely caused by conflicting terminology in test double libraries.

There's value in being precise. Developers that precisely understand the five types of test doubles, and the trade-offs inherent in their use, can wield test doubles effectively. Developers that communicate clearly with each other can collaborate with each other more efficiently. Precisely named doubles in the code can spread precise understandings of those doubles, raising the quality of engineering on the team.

As professionals, it's incumbent upon us to both clearly understand our profession *and* clearly communicate it. If your doctor referred to your liver as your spleen, or your heart as your brain, you might not have a lot of confidence in his or her abilities. True, those are all organs, but they all serve different functions. Or imagine listening to two surgeons about to operate on you argue with each other about the names of their surgical tools; you might question whether or not you should go through with the operation.

Let us resolve to hold ourselves to the same standards that we hold other professionals to. Let us understand clearly, use effectively, and communicate precisely the tools of our trade.

