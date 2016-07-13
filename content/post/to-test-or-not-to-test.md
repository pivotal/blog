---
authors:
- oswitzer
- tira
categories:
- TDD
- Testing
- Logging
date: 2016-07-12T17:58:22-04:00
draft: true
short: |
    Some things are hard to test, or testing feels tedious and unmeaningful. You start to question whether you should be testing them. Sometimes you're right! This is a guide to help you figure out where the testing ends.
title: To Test or Not to Test
---

In general, things not to test:

- Time itself
- Frameworks
- Things without behavior
	- Models
	- Configuration

That doesn't mean there should be no tests in those areas of your application. You can still test behavior that is driven by time without altering the space-time continuum, or waiting for paint to dry.

## How to test Time

Software doesn’t always happen synchronously. Something might happen once every 30 minutes, after asynchronous service call, or at midnight every Monday. When testing these things, I don’t want my tests to wait around for 30 minutes, a week, or even 1-2 seconds.

I don’t want to test time itself, I just want to feel reasonably confident that my code is interacting with time in the way I expect.

There are lots of tools for helping with this stuff.

In java/Spring, one approach is to create a CurrentTimeProvider to replace any calls to `new Date()`. Then in my tests I can have a fake or mockable currentTimeProvider object.

~~~java
@Component
public class CurrentTimeProvider {
	public Date getDate(){
		return new Date();
	}
}

@Test
public void someTest() {
	Date mockedDate;
	...
	when(currentTimeProvider.getDate()).thenReturn(mockedDate)
}
~~~
Then again, I might find myself using a library which uses time directly. In that case, it comes down to not testing the framework, and just testing that I am using the framework the way I expect.

In Ruby, there is a gem called TimeCop that allows you to mock out time by faking all calls to get system provided time.

Javascript: jasmine clock is pretty great. It’s similar to TimeCop. It lets you instantly travel forward in time, or travel to a specific date or time.

~~~javascript
jasmine.clock().install();
jasmine.clock().mockDate(new Date(2013, 9, 23));
jasmine.clock().tick(3000);
~~~
Or if you’re dealing with async calls to an API
- use `jasmine.Ajax`.
- create your own deferred objects, and resolve or reject promises that way
~~~javascript
var fetchDeferred = $q.defer();
spyOn(someService, 'fetch').and.returnValue(fetchDeferred);
someService.fetch();
spyOn(errorService, 'showError');

fetchDeferred.reject('Something went wrong');

expect(errorService.showError).toHaveBeenCalledWith('Something went wrong');
~~~

Regardless of what method you're using to test your asynchronous code, the goal is to have fast tests.
For integration tests though, you will need to actually wait. The page takes time to load, to render, etc. That means you should be judicious about what to integration test for code that is time-dependant.
If you have a page that periodically updates itself, or an ETL process that runs once a day, I would usually try to only test that at a unit test level, not an integration test level.

## How to test Frameworks

You may have heard "Don't test the framework." What does that mean?

A framework could be anything from Spring or Rails to a single-purpose library. "Don't test the framework" doesn't mean *always* mocking out the framework and treating it as a test boundary.
Sometimes including things the framework does as part of your test is okay. The real lesson is "Don't make more work for yourself by testing the framework."
The reasoning is that the libraries you are using are (hopefully) already tested, and if not, you might want to reconsider using them.

For example if you're testing a popup on a page and you're using Bootstrap to do it, you could test that the popup appears when you click, or you could test that you are configuring your element as a popup.
Of course, you want to avoid testing things that are pure configuration and don't have behavior. So you might just test that it has some properties and not what those properties are. Or you might test that it has some minimum subset for making it a working popup.

A good example where it becomes very difficult to test if you try to include the framework in your test is logging. If you included the framework, your test would have to read from stdout or from a file. Instead you should find a boundary that is easier to test.

## Recognizing things without behavior

In general, good tests should test behavior, not data.

Models that just have simple get/set methods on private fields don't need to be tested. (Sidenote: In general, I don't add behavior besides simple get/set methods on models.)

Things I think of as configuration are also not behavior. I want to test that configuring things has an effect, but I shouldn't need to test that a particular configuration is valid. Ideally, if you change your configuration, all your tests should still pass.

Not everyone will agree that you should test logs, but I think that if you are questioning the value of testing the logs, you should also be questioning the value of logging the logs.
Logging is a behavior. I think there are cases where out of convienience/laziness you will catch even hard-code TDD devs not testing their logs (myself included), but as a best practice, I think it's generally worthwhile to test them.

## Finding Testing Boundaries

So, let's look deeper into our example of testing logs. Why is it hard?

There isn't a good boundary because
- logging is a "side effect" of a method call, so you're not just testing a return value
- outside of the framework (stdout / logfile) isn't a good boundary
- mocking the method we're calling isn't a good boundary (all the logging methods (in Java) are static, and static methods can't be stubbed out easily.)

Ways to resolve this

### Refactor your use of the framework to create a test boundary
- As in the example for mocking time, you could wrap any static method calls with an instance method

~~~java
public class Duck {

    public static logger = Logger.getLogger(MyClass.class);

    public void quack(){
        ...
        loggerWrapper.error(logger, "Could not quack", exception);
    }
}

@Test
public void quack_logsAnError() {
    duck.quack();
    verify(loggerWrapper).error(any(Logger.class), eq("Could not quack"), any(Exception.class));
}
~~~

- or you could change point the logger's logs to a mock Appender object, depending on what logging framework you are using.

### Refactor code to create a test boundary

Consider the following method:

~~~java
class CalculatorApplication {
    public void add(Integer first, Integer second) {
        System.out.println(first + second);
    }
}

~~~

In this scenario, I'm calculating something and logging it within the same method.  I can consider decoupling the part of the method which does the calculation into a different object. This will allow us to test the behavior separately, making a simpler test.

~~~java

class Calculator {
    public Integer add(Integer first, Integer second) {
        return first + second;
    }
}

class CalculatorApplication {
    public void add(Integer first, Integer second) {
        System.out.println(calculator.add(first, second));
    }
}

~~~

Be pragmatic!
Deciding what to test and where to devise your test boundaries is not an exact science. I think of my tests both as a tool for developing robust code and as a medium for communicating to future developers. I use that as a guide to decide whether I want a particular test.
