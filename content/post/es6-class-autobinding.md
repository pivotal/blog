---
authors:
- pmeskers
categories:
- JavaScript
date: 2016-08-10T10:43:19-04:00
draft: true
short: |
  A quick look at (the lack of) autobinding in ES6 classes, and exploring some options for addressing it.
title: ES6 Classes, Autobinding, and You
---
# ES6 Classes, Autobinding, and You

So you've started using ES6 classes and you notice something unexpected. In some contexts,
certain methods on your classes are not able to reference their class members! Let's take a look at a possible example.

This breakdown assumes familiarity with new ES6 syntax, as well as a basic understanding of how `this` is assigned to function invocations.

## The Problem

### Example 1

Let's take a very simple(albeit impractical) use case -- we have a Person class, which takes a name, and we have a method
for retrieving the name.

```js
class Person {
  constructor(name) {
    this.name = name;
  }

  getName() {
    return this.name;
  }
}

person = new Person("Parappa");
document.write(person.getName());
```

The `getName` method pulls the name property off of `this`. In many cases, this will result in the correct behavior. If we run the above code,
we will see the browser replace the page with the text "Parappa."

However, it's quite simple to produce an example where it falls apart. Let's try this by just creating a function which wraps and invokes
a passed-in function.

```js
executeFn = (fn) => {
  return fn();
}

document.write(executeFn(person.getName));
```

This presents us with an `Uncaught TypeError: Cannot read property 'name' of undefined`. So what happened here? The issue is that all we've passed into `executeFn` is a _reference_ to a function, and as per standard JavaScript, the `this` value will no longer refer to the person instance, because it is occurring in a different execution context. We could think of this function argument as being no different than referencing `Person.prototype.getName` directly.

### Example 2 (React)

A very prevalent occurrence of this is in React components. When using ES6 classes to extend `React.component`, the following may happen:

```js
// https://facebook.github.io/react/docs/reusable-components.html#no-autobinding

export class Counter extends React.Component {
  constructor(props) {
    super(props);
    this.state = {count: props.initialCount};
  }
  tick() {
    this.setState({count: this.state.count + 1});
  }
  render() {
    return (
      <div onClick={this.tick}>
        Clicks: {this.state.count}
      </div>
    );
  }
}
```

The issue here is the click handler which invokes `this.tick`. It will once again not have the correct execution context. 

## Solutions

### Binding in the Constructor

The constructor of our class can own the responsibility of reassigning its methods as bound versions. Now, whenever we reference the getName function on a Person instance, it will already be a bound function. This has the benefit of being supported in ES6, and also is an easily repeatable convention that allows you to "set it and forget it" -- you can always trust your methods to be bound to their class instance. 

```js
class Person {
  constructor(name) {
    this.name = name;
    this.getName = this.getName.bind(this);
  }

  getName() {
    return this.name;
  }
}
```

### ES7 Experimental Syntax

ES7 offers a new syntax for declaring and assigning class members using `=` syntax. The real trick here is that means you can use the new fat arrow syntax now for writing methods, which means the `this` will be passed through from the outer context (For more information about how fat arrow functions get their `this` assignment, have a [read here](http://exploringjs.com/es6/ch_arrow-functions.html)). This has the same benefit of "set and forget" as binding in the constructor, but it is still an experimental language feature, so use at your own risk. 

```js
class Person {
  constructor(name) {
    this.name = name;
  }

  getName = () => {
    return this.name;
  }
}
```

### Binding as needed

For this approach, just make sure you bind the method to its respective instance when you are passing it around as a reference. This strategy has the advantage of being explicit in its binding (you don't need to open up the class to make sure that binding is happening), but it has the downside of placing the burden on you as a class consumer to make sure you are binding when needed. 

```js
document.write(executeFn(person.getName.bind(person)));
```

### Don't use ES6 classes

Lastly, you could always implement `Person` as a non-ES6 class. Classes are just syntactic sugar anyway, so you could always drop back down to ES5 and write something like this:

```js
function Person(name) {
	this.getName = function() {
		return name;
	}
} 

executeFn = (fn) => {
  return fn();
}

person = new Person("Parappa");
document.write(executeFn(person.getName));
```


## Conclusion

Yes, it's unfortunate that autobinding doesn't come out of the box in ES6 classes. But, as you can see, there are ways to mitigate this challenge. The most important thing is to pick a strategy and stick to it -- each solution has its pros and cons, so the best you can do is be consistent with your practice!

Comments are welcome [here!](https://gist.github.com/pmeskers/4e57c5794e266bd40e0e9d2f38c73ac7)
