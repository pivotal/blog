---
authors:
- mkollasch
categories:
- Declarative Programming
- datalog
date: 2017-01-13T09:25:41-07:00
short: |
  Using a popular academic program, FizzBuzz, and an extreme declarative programming approach using Datalog, we examine the thought process and benefits for enforcing separation of concerns with declarative programming.
title: Enforcing Separation of Concerns with Declarative Programming
---

Software is a young profession, both historically and demographically, and its rapid growth introduces a risk that we programmers will learn less than we ought from the breadth of work that preceded us. We can counteract this, and improve the quality of our thought and output, by exposing ourselves to uncommon approaches and extreme concepts.

In that spirit, and in the hopes that it will be found interesting, we present an implementation of Fizzbuzz using Datalog. It sounds like a joke, but, as shall be seen, the *extreme concept* applied can be extrapolated to day-to-day engineering to improve code quality. Fizzbuzz stands in for business logic, which, to reduce defect rate, should be separated from application flow; Datalog is a tool intended specifically for the approach which will make that separation more perfect. Following an introduction to the problem and the tools, we walk through writing the code, then discuss implications and applications.

## Glossary

*Datalog*: A deductive database system and a declarative programming language for accessing the same. In addition to standalone implementations, Datalog can be embedded into other programming languages, and libraries and tools derived from its principles also exist. A Datalog database contains atomic *facts* and derived *rules* concerning some user-defined domain, and a *query* against a database returns a set of zero or more facts implied by them. Widely regarded as academic and obscure.

*Fizzbuzz*: A simple, common programming exercise intended to reveal the thought process of the implementor. For some range of nonnegative integers, typically 1 to 100, the program must display the numbers in order, except that numbers divisible by 3 are replaced with "fizz", numbers divisible by 5 are replaced with "buzz", and numbers divisible by both 3 and 5 are replaced with "fizzbuzz". Widely regarded as trivial and unrealistic.

*Practical*: Technically possible, organizationally feasible, and economically valuable.

## How to read Datalog

Here is an example program, as it would appear in [an interactive Datalog environment](http://datalog.sourceforge.net/). Lines preceded with `>` are input; lines without it are output.

```no-highlight
> mortal(X) :- man(X).
> man(socrates).
> mortal(socrates)?
mortal(socrates).
```

## Exercise

Before we get right into writing code, let's understand the problem a bit better. It's good to separate business logic from presentation logic. The business logic deals with ideas like what a number is, what it means for a number to be divisible by 3 or 5, and when a number should be replaced with `fizz` or `buzz`. The presentation logic deals with putting the numbers or their replacements in order. To help enforce this separation of concerns, we'll write the business logic and the presentation logic in completely separate languages, although there can be reasons to prefer keeping them the same. This post is chiefly concerned with the implementation of business logic, but a prototype presentation layer will also be provided.

While implementing the business logic, we'll start by creating the interface that the presentation will consume. We'll then implement the behavior backing that interface in terms of the interfaces of its components, then implement those components recursively in the same way, all the way down to primitive operations. In a more substantial project, it might be beneficial to implement mock versions of these components for the sake of testing, but for the purposes of this demonstration, mocks have been skipped. This process will leave us with multiple unimplemented components at once. We'll prioritize between them using the heuristic that more specific components should be preferred; this will help us identify the correct primitives and reveal components that are shared.

The interface that the requirements imply is the ability to make a Datalog query for the Fizzbuzz representation of a given number. That is, we want to issue a query like `display(100, X)?` and receive a fact like `display(100, buzz).` indicating that the number "100" has a Fizzbuzz representation of "buzz".

```datalog
display(N, X) :- isbare(N), N = X.
display(N, fizz) :- isfizz(N).
display(N, buzz) :- isbuzz(N).
display(N, fizzbuzz) :- isfizzbuzz(N).
```

The bodies of these `display` rules are defined in terms of the unimplemented rules `isbare`, `isfizz`, `isbuzz`, and `isfizzbuzz`, and the heads refer to the literal values `fizz`, `buzz`, and `fizzbuzz` [^1]. The literals are meaningless, so we're done with them. The rules, we can define like this:

[^1]: It would be valid to call it `fizz` instead of `isfizz`, and so forth, as they would still have been distinguishable by their arity.

```datalog
isbare(N) :- notdivisible(N, 3), notdivisible(N, 5).
isfizz(N) :- divisible(N, 3), notdivisible(N, 5).
isbuzz(N) :- notdivisible(N, 3), divisible(N, 5).
isfizzbuzz(N) :- divisible(N, 3), divisible(N, 5).
```

In defining these rules, we've introduced references to some other terms which are still undefined. In addition to the rules `divisible` and `notdivisible`, we used the strings `3` and `5`, which are domain terms with no intrinsic meaning. Some environments provide arithmetic logic as a convenience for common tasks, but for the purposes of this exercise, the definition of the numeral `3` is *business logic* that we must implement.

Following our pattern of working with more specific and less primitive ideas first, we'll leave `3` and `5` aside for now, and define our divisibility rules. For this, we'll define it in terms of another business concept: the `modulus` operation. A number `N` is divisible by a number `D` if `N` modulo `D` is equal to zero, and not divisible if the modulus is not zero.

```datalog
divisible(N, D) :- modulus(N, D, 0).
notdivisible(N, D) :- modulus(N, D, X), nonzero(X).
```

This has introduced more terms we need to define: `modulus` itself, the `nonzero` rule, and the literal character string `0`, a third business value. We'll implement `modulus` first, because it's more specific:

```datalog
modulus(N, D, 0) :- N = D.
modulus(N, D, R) :- less(N, D), N = R.
modulus(N, D, R) :- subtract(N, D, X), modulus(X, D, R).
```

Note that `N`, `D`, and `R` stand for Numerator, Denominator, and Remainder, respectively. A number modulo itself is always zero. When the numerator is less than the denominator, the remainder is simply the numerator. The third rule applies Euclidean division: the remainder of N divided by D will equal the remainder of N divided by (D minus N).

This has introduced a need to define the domain notions `less` and `subtract`, and also depends on the still-undefined term `0`. We also still need to define `nonzero`. It's unclear whether `less`, `subtract`, or `nonzero` should come next in our heuristic, so we'll do them in alphabetical order.

```datalog
less(A, B) :- successor(A, B).
less(A, B) :- successor(A, X), less(X, B).
```

`A` is less than `B` if `B` is the successor to `A`, or if the successor to `A` is itself less than `B`. `successor` is more general than `subtract` and `nonzero`, so we'll continue:

```datalog
nonzero(N) :- successor(X, N).
```

Zero is the natural number which is not a successor, so if a number `N` is a successor, it is nonzero.

```datalog
subtract(M, 0, D) :- M = D.
subtract(M, S, D) :- successor(X, M), successor(Y, S), subtract(X, Y, D).
```

Note that `M`, `S`, and `D` stand for Minuend, Subtrahend, and Difference, respectively. The first rule asserts that subtracting `0` from any value results in that value. The second clause recursively asserts that the difference between two numbers is equal to the difference between the two numbers to which they are respectively the successors. That is, 3-2 = 2-1 = 1-0, which is defined by the first clause.

We have now observed that the `successor` operation has emerged during the implementation of three different business rules. `successor` is primitive, it is not composed of anything; the only thing that makes a number some other number's successor is because we say so. So let's say so, and in so doing also define `5` as the successor to `4`:

```datalog
successor(4, 5).
```

Now we have to define `4`, and so forth:

```datalog
successor(3, 4).
successor(2, 3).
successor(1, 2).
successor(0, 1).
```

`0`, of course, is not a successor. We have now defined all the logic needed to calculate how the Fizzbuzz algorithm should display any number that exists. If we perform a query of the form `display(3, A)?`, we'll get back the fact `display(3, fizz).`, read something like "The displayed form of 3 as fizz." If we run the query `display(A, B)?`, we'll get back results like that for every number that exists in the database.

There's a problem: the customer wants information about the Fizzbuzz values of a hundred numbers, but our database contains only six. In order to evaluate strange input like the string `100`, it has to be entered into the system. This doesn't really have anything to do with business logic *per se*, but rather is a data entry problem that we'll defer to the system consuming our API.

All of the consumers of our system will be represented by a single shell script, which will generate the data that the user requires and format the output, but if this were a real product, this behavior might be spread across multiple client applications.

## Analysis

What's significant about this is that that we have implemented our business rules in a purely declarative way. Everything that is needed to determine whether some input is "fizz" or "buzz" has been written in a way that is unconcerned with computational details like loops, strings, classes, or IEEE 754 floating point representations. If the business should decide to change its rules, we only need to change the code that describes the rules. We won't need to change the code that describes how the rules are executed because we never wrote any such code in the first place.

Datalog is an extreme example of a purely declarative programming language. In declarative programming, the programmer does not directly specify the behavior of the computer, but rather specifies what result is desired, delegating to some other system the process of translating that into a computational strategy. Trivially, any programming language except assembly is to some extent declarative. It can be thought of as one end of a continuum, with imperative programming at the opposite end.

One of the strongest examples of the declarative programming paradigm is in SQL, Structured Query Language. The programmer *declares* the desired relations and records, but the database engine performs the computations that store and retrieve data. It's also common even in very imperative languages to implement a declarative API or a declarative domain-specific language, such as the `routes.rb` file in Ruby on Rails, in which the user declares what routes should exist, or Haskell's `IO` monad, which amounts to declaring which I/O operations should be performed. Even humble HTML is declarative, as it exposes no means to specify how to render a tag.

Good programming practices encourage us to pursue a separation of concerns in our code, for a variety of benefits. Declarative programming is a means to separate the concerns "What shall be computed?" and "How shall it be computed?" into two separate systems - in the case of the above example, the former system is the domain code we wrote, and the latter system is the Datalog engine executing the code. The cost of this approach is that both systems must be implemented.

Using the declarative paradigm to separate implementation details from domain logic - even when it does not involve a deductive database system like Datalog - was likely already part of your toolbox. Being more mindful of the significance of decisions like that may help you take fuller advantage of them.

## Source Code

Client application:

```bash
#!/bin/bash

generate () {
  COUNT=$1
  if [[ $COUNT -lt 6 ]]; then
    return
  fi
  for I in seq 6 $COUNT
    do
      echo "successor($((I-1)), $I)."
  done
}

MAX=$1
if [[ $MAX =~ ^[0-9]+$ ]]; then
  RESULTS=echo $(generate $MAX) $(cat fizzbuzz.dl) $(echo display\(X,Y\)?) | datalog -
  echo "$RESULTS" | cut -d "(" -f2- | sort -n | cut -d " " -f2- | cut -d ")" -f1 | tail -n +2 | head -n $MAX
else
  echo "Usage: $0 <number>"
  exit 1
fi
```

Datalog source, `fizzbuzz.dl`:

```datalog
display(N, X) :- isbare(N), N = X.
display(N, fizz) :- isfizz(N).
display(N, buzz) :- isbuzz(N).
display(N, fizzbuzz) :- isfizzbuzz(N).

isbare(N) :- notdivisible(N, 3), notdivisible(N, 5).
isfizz(N) :- divisible(N, 3), notdivisible(N, 5).
isbuzz(N) :- notdivisible(N, 3), divisible(N, 5).
isfizzbuzz(N) :- divisible(N, 3), divisible(N, 5).

divisible(N, D) :- modulus(N, D, 0).
notdivisible(N, D) :- modulus(N, D, X), nonzero(X).

modulus(N, D, 0) :- N = D.
modulus(N, D, R) :- less(N, D), N = R.
modulus(N, D, R) :- subtract(N, D, X), modulus(X, D, R).

less(A, B) :- successor(A, B).
less(A, B) :- successor(A, X), less(X, B).

nonzero(N) :- successor(X, N).

subtract(M, 0, D) :- M = D.
subtract(M, S, D) :- successor(X, M), successor(Y, S), subtract(X, Y, D).

successor(0, 1).
successor(1, 2).
successor(2, 3).
successor(3, 4).
successor(4, 5).
```

Usage: Save the above Datalog code as `fizzbuzz.dl`, the shell script as something executable, install [datalog](http://datalog.sourceforge.net/), and follow the instructions given by executing the script.
