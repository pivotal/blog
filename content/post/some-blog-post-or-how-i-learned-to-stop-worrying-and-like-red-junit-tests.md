---
authors:
- tira
categories:
- Java
- Testing

date: 2016-03-24T13:16:51-05:00
draft: false
short: |
  Tips and tricks for writing tests that fail well.  What to mock, what to name your tests, and how to `when`.
title: "\"Some Blog Post\" or, How I Learned to Stop Worrying and Like Red Junit Tests"
---
{{< responsive-figure src="/images/tira/test_failure_disaster.png" class="right small" >}}

Let me throw this scenario at you: A test is failing. You didn't write it, and the error is really weird. The test name doesn't tell you what the code is supposed to do, but whatever it is, your code isn't doing that. 

That's pretty much worst case scenario for test failures, and it happened to me earlier today.

I don't blame the people who wrote the test. It's tricky to figure out how to write a good test in Java. Seriously! There's no `describe` blocks or `it`s like in [jasmine](http://jasmine.github.io/2.4/introduction.html) and [rspec](http://rspec.info/). How do you even structure a test? I'm not really a fan of Java (Who needs type safety anyway?), but I've learned a few things in the two years I've been here at Pivotal Labs that let me hate it a lot less.

## Test Name Structure

Okay, for starters, you can take advantage of the test method name. 

~~~java
@Test
public void updateCalendar() {
~~~
should become

~~~java
@Test
public void updateCalendar_whenThereIsAnEvent_savesTheEvent() {
~~~
The first time I saw that I was mindblown. It's so simple, but so great! Someone probably told you that method names should never be that long, but I'm just going to let you in on a little secret: tests are special, and it's worth it, believe me. 

This opens you up to having more than one test for one method, and lets your tests be smaller. So instead of a bunch of assertions and a bunch of setup, you can have just a tiny bit of setup that corresponds to that `whenThereIsAnEvent` and one or two assertions that correspond to the last phrase (`savesTheEvent`). It's not quite as nice as real describe blocks, but it's serviceable.  

Now when your test is failing, there's not a lot of code to look at, and the test tells you what it's about. Already this code is going to be so much easier to fix.

You might be thinking, "Wait, I'm writing more than one test per method? Where does it end? How many tests do I write?" I'll get to that. It's at the very end though, so if you're holding your breath, you might need to scroll down.

## Empty Assertions
{{< responsive-figure src="/images/tira/empty_assertions.png" class="right small" >}}

This code looks fine, right?:

~~~java
assertThat(savedUser.getName()).isEqualTo(user.getName());
~~~
It looks fine, but under the surface it might actually have a horrible disease: *Emptiassertionitis*. If `user.name` was never set, this is actually 

~~~java
assertThat(savedUser.getName()).isEqualTo(null); 
~~~
Oh no, that's not what you meant at all! So, to avoid that, I recommend always inlining this kind of thing. 

~~~java
assertThat(savedUser.getName()).isEqualTo("Some Name");
~~~
"But Tira, that isn't dry!" Nope, it isn't. Because this is a test, and tests are special. Tests don't need to be dry, at least not as much as they need to be transparent. If your test data is meaningful and your test failures are obvious, that's a pretty good test in my book.

## Weird Null Pointers

{{< responsive-figure src="/images/tira/e_is_for_exception.jpg" class="right small" >}}

Okay, this is really specific to Java. You know how there is `int` and `Integer` and `long` and `Long` and so on? Well, it turns out that when you try to set one of the lowercase ones to `null`, you get a null pointer exception. It makes sense; the whole point of the wrapper classes is to make the primitives into nullable `Object`s. But still, every time I see a null pointer exception being thrown from an innocent-looking line like:

~~~java
calendarDay.setEventCount(eventCount); // calendarDay is not null
~~~
I have to do a double take. If I'm a little drowsy, sometimes it's three or four takes before I realize what's going on.

As people who write tests, we run into this weird little issue a lot. We don't want to set up all the data that isn't relevant to the test we're writing. We shouldn't have to set it up. But, doing this minimal setup means things are often null that wouldn't be otherwise. Just make them nullable and move on.

If the thing isn't valid as `null`, consider a `@NotNull` validation.

## Helpful Test Data

You may think that test data doesn't matter. It can be anything. But I'm here to tell you that it can matter. It can *be something*.
When I think about setting up test data, I think about what kind of failure messages it will produce. Your test data can tell you what to do next, or it can confuse you.
Here we have ordinary test data:

~~~java
User user = User.builder()
.id("10")
.age(10) // not the only field with this value
.name("Ghengis Khan") // Joke name
.email("email")  // The value is the same as name of the field
.build();
~~~
This test data can actually be a real problem when you have *Emptiassertionitis*-style tests: 

~~~java
assertThat(find(".my-form").getText()).contains(user.getEmail());
~~~
See how that user's email is the same as the field name? There's probably a `<label>email</label>` on the page, so our assertion passes even when the user's email is not being rendered.
If instead you make that into `"some-email@example.com"`, you'll get a nice error that tells you exactly what to fix.
The same thing goes for that `id` field. Make the `id` field into `"some-id-1"` and your error message will point you at the `id` field, without being confused for `age`. It's okay sometimes to use fun names, but when you're deciding between something clever and something clear, go for clear. There's plenty of other stuff to be creative with when you're writing code. And when you aren't going for the clever approach, "Some" is a wonderful word for filling in test data. It won't be confused for real values, and it won't get mixed up with form fields:

~~~java
User user = User.builder()
.id("some-id-1")
.age(10)
.name("Some Name")
.email("some-email@example.com")
.build();
~~~
Wow! This test data is so boring, but so helpful!

{{< responsive-figure src="/images/tira/something_is_blue.png" >}}

## Mockito: How to `when`

A lot of times I see mocks set up like this:
~~~java
when(magician.putInHat(magicObject)).thenReturn(123);
assertThat(whatever.doThing()).isEqualTo(123);
~~~
That's all well and dandy in the sense that you're testing everything you wanted to test. `putInHat` is being called correctly with magicObject. Its return value is coming back and being used as the result of `doThing`. 

But what about when this test is failing? What if you pass in the wrong `MagicObject` to `putInHat`? 

You get `"it is not true that null is equal to 123"`. I mean, I think we can all agree that null is not equal to 123, but this failure doesn't exactly make it obvious that `putInHat` is betraying you and returning `null`. It would never do that in real life, but of course it's a mock because this is a unit test. So how can we get a better test failure? 

Swap in a `Matcher` and a `verify`, for all the same test coverage goodness but with twice the fun:

~~~java
when(magician.putInHat(any(MagicObject.class)).thenReturn(123);
assertThat(whatever.doThing()).isEqualTo(123);
verify(magician).putInHat(magicObject);
~~~
It's one extra line of code, but now our failure message looks like this:
`"expected putInHat to have been called with MagicObject@2456 but actual calls were MagicObject@1234"`

Abracadabra, that's way more helpful.

## What to Mock
You want to write pure unit tests. That means you mock everything that isn't the object you're testing. Right? Wrong. I mean, kind of, but not quite. You could mock everything but please don't. Mock things with behavior. Don't mock Models. 

Consider the following: 

~~~java
@Test 
public void addOne_returnsTheIncrementedValue(){
  valuable.setValue(10);
  assertThat(incrementer.addOne(valuable)).isEqualTo(11);
}
~~~
Imagine that incrementer is working as expected, but this test is failing. It says`"it is not true that null is equal to 11"`. Why? because `valuable` is a mock object. Sure, you could say `when(valuable.getValue()).thenReturn(10)` and your test would work, but it's just really weird and harder to use than newing up an instance of the real thing.

## How Many Tests do I write?

{{< responsive-figure src="/images/tira/too_many_tests.png" class="right small" >}}

When I was first getting into writing unit tests, I kept hearing about how I needed to test edge cases. So I wrote code with all these null checks and exception handling, and almost none of it was necessary and all of it was ugly. Don't think about edge cases. Think about real cases.

Write one test for each side of a control flow. So if you have an `if` in your method, you should have two tests for that method. 

If there is an `if` with an `&&` or `||`, you should have 3 tests.

If there are two objects you have to set up to test all of a method's behavior, consider whether you can separate that into two tests as well. 

The goal is to have simple, meaningful, descriptive tests. Think of tests as comments with proof. Their whole purpose is to communicate to the next developer what the code is doing and why.
