---
authors:
- pmeskers
categories:
- TDD
- JavaScript
- Promises
- Testing
date: 2016-04-19T10:19:36-04:00
draft: false
short: |
  A straightforward look at how to apply test-driven development to native JavaScript promises.
title: Testing JavaScript's native Promises
---
## Testing JavaScript's native Promises

Promises are not a new concept to JavaScript, with popular implementations already provided by [jQuery](https://api.jquery.com/promise/) and [Q](https://github.com/kriskowal/q). However, with the Promise abstraction now a [built-in object](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise) in ECMAScript and appreciating more widespread browser support, it makes sense to start shifting towards this new interface.

Because of their asynchronous nature, promises can often be confusing to unit test. The purpose of this post will be to demonstrate a simple example of how one might apply TDD and build a test suite around a simple JavaScript service which returns a promise.

In the spirit of using new JS interfaces, we'll also be using the new [Fetch API](https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API/Using_Fetch) as our asynchronous behavior, and we'll be writing our unit tests in [Jasmine](http://jasmine.github.io/2.0/introduction.html).

For more information about the Fetch API, check out these links:

* [https://fetch.spec.whatwg.org/](https://fetch.spec.whatwg.org/)
* [https://jakearchibald.com/2015/thats-so-fetch/](https://jakearchibald.com/2015/thats-so-fetch/)

#### **Getting started**

For this example, let's pretend we're writing some WeatherService, and we want our service to have a method `fetchCurrentTemperature`, which will hit an API and pull out the current temperature.

So, what do we know getting started?

#### **We know what URL we want to hit**

At the very least, we want to make sure we're hitting the right endpoint. So let's make sure that we are calling fetch to the right URL.

```js
describe('.fetchCurrentTemperature', function() {
	beforeEach(function() {
		spyOn(window, 'fetch').and.callThrough();
		WeatherService.fetchCurrentTemperature();
	});

	it('fetches from the weather API', function() {
		expect(window.fetch).toHaveBeenCalledWith('someweatherapi.com');
	});
});
```

This one is pretty straightforward.

```js
// There's lots of ways we can define this service -- let's just keep it simple for now
var WeatherService = {
	fetchCurrentTemperature: fetchCurrentTemperature
};

// This will be our actual function under test
function fetchCurrentTemperature() {
	fetch('someweatherapi.com');
}
```

What do we know next?

#### **We know we are async, and should return a promise**

Since we are performing an asynchronous operation, we should be returning a promise from this function. At this point, we just want to guarantee that the user gets back a promise when invoking the function.

```js
describe('.fetchCurrentTemperature', function() {
	var temperaturePromise;

	beforeEach(function() {
		spyOn(window, 'fetch').and.callThrough();
		temperaturePromise = WeatherService.fetchCurrentTemperature();
	});

	...

	it('returns a promise', function() {
		expect(temperaturePromise).toEqual(jasmine.any(Promise));
	});
});
```

Note that we now keep a reference to the return value of our `fetchCurrentTemperature` invocation as `temperaturePromise`.

And all we have to do is return the call to `fetch`.

```js
function fetchCurrentTemperature() {
	return fetch('someweatherapi.com');
}
```

#### **We know fetches can be successful**

Here is where our tests get a little more interesting. We have a particular context in which our `fetchCurrentTemperature` can run, which is that the network request has been successful. But how do we simulate this?

```js
describe('.fetchCurrentTemperature', function() {

	...

	describe('on successful fetch', function() {
		beforeEach(function() {
			// We need to simulate a succesful network response
		});

		it('resolves its promise with the current temperature', function() {
			// We need our returned promise to have passed along the temperature
		});
	});
});
```

First, let's build a [Response](https://developer.mozilla.org/en-US/docs/Web/API/Response) object. This is what the `.fetch` method's promise is resolved with. Its first argument is the body, which is a string. So let's put an example response together that looks like what the API would actually return.

```js
describe('on successful fetch', function() {
	beforeEach(function() {
		var response = new Response(JSON.stringify({
			temperature: 78
		}));
		// Now we need to resolve our fetch promise with this response
	});
	...
});
```

Now we know what our sample response looks like: let's throw together our assertion which takes advantage of Jasmine's asynchronous `done` function. (For more info on how done works, [read here](http://jasmine.github.io/2.0/introduction.html#section-Asynchronous_Support))

```js
describe('on successful fetch', function() {
	...

	it('resolves its promise with the current temperature', function(done) {
		temperaturePromise.then(function(temperature) {
			expect(temperature).toEqual(78);
			done();
		});
	});
});
```

We've simply chained that returned promise and made sure that our passed in value matches the temperature.

But, we still need to actually use our test Response. In order for us to resolve the fetch with our own response, we need to hook into the fetch and provide our own promise that we can resolve at will.

```js
describe('.fetchCurrentTemperature', function() {
	var temperaturePromise;
	var promiseHelper;

	beforeEach(function() {
		var fetchPromise = new Promise(function(resolve, reject) {
			promiseHelper = {
				resolve: resolve
			};
		});
		spyOn(window, 'fetch').and.returnValue(fetchPromise);
		temperaturePromise = WeatherService.fetchCurrentTemperature();
	});

	...
});
```

We are now creating our own promise, and having all calls to `fetch` return it. Because of the Promise constructor, the only way we can get access to the resolve function is to store a reference to it. You can see we are doing that with this new `promiseHelper` variable.

Let's use this helper in our successful context:

```js
describe('on successful fetch', function() {
	beforeEach(function() {
		var response = new Response(JSON.stringify({
			temperature: 78
		}));
		promiseHelper.resolve(response);
	});

	it('resolves its promise with the current temperature', function(done) {
		temperaturePromise.then(function(temperature) {
			expect(temperature).toEqual(78);
			done();
		});
	});
});
```

Great! Now we have a test that builds a response and simulates resolving a fetch with that response. Let's try to write an implementation:

```js
function fetchCurrentTemperature() {
	return fetch('someweatherapi.com')
		.then(function(response) {
			return response.json();
		})
		.then(function(data) {
			return data.temperature;
		});
}
```

#### **We know fetches can fail**

We also want to define what should happen in the event that our fetching fails. In this case, we just want whatever error was initially raised to be catchable from the returned promise. Let's use a similar strategy as above to write a failure context test.

```js
describe('.fetchCurrentTemperature', function() {
	var temperaturePromise;
	var promiseHelper;

	beforeEach(function() {
		var fetchPromise = new Promise(function(resolve, reject) {
			promiseHelper = {
				resolve: resolve,
				reject: reject
			};
		});
		spyOn(window, 'fetch').and.returnValue(fetchPromise);
		temperaturePromise = WeatherService.fetchCurrentTemperature();
	});

	...

	describe('on unsuccessful fetch', function() {
		var errorObj = { msg: 'Wow, this really failed!' };

		beforeEach(function() {
			promiseHelper.reject(errorObj);
		});

		it('resolves its promise with the current temperature', function(done) {
			temperaturePromise.catch(function(error) {
				expect(error).toEqual(errorObj);
				done();
			});
		});
	});
});
```

This just makes sure that we still catch whatever error the fetch is rejected with. Because we don't intercept any failures, this should already be passing.

```js
// No changes need to be made to our function!
```

#### **Putting it all together**

Here's a look at the final spec and implementation.

```js
describe('.fetchCurrentTemperature', function() {
	var temperaturePromise;
	var promiseHelper;

	beforeEach(function() {
		var fetchPromise = new Promise(function(resolve, reject) {
			promiseHelper = {
				resolve: resolve,
				reject: reject
			};
		});
		spyOn(window, 'fetch').and.returnValue(fetchPromise);
		temperaturePromise = WeatherService.fetchCurrentTemperature();
	});

	it('fetches from the weather API', function() {
		expect(window.fetch).toHaveBeenCalledWith('someweatherapi.com');
	});

	it('returns a promise', function() {
		expect(temperaturePromise).toEqual(jasmine.any(Promise));
	});

	describe('on successful fetch', function() {
		beforeEach(function() {
			var response = new Response(JSON.stringify({
				temperature: 78
			}));
			promiseHelper.resolve(response);
		});

		it('resolves its promise with the current temperature', function(done) {
			temperaturePromise.then(function(temperature) {
				expect(temperature).toEqual(78);
				done();
			});
		});
	});

	describe('on unsuccessful fetch', function() {
		var errorObj = { msg: 'Wow, this really failed!' };

		beforeEach(function() {
			promiseHelper.reject(errorObj);
		});

		it('resolves its promise with the current temperature', function(done) {
			temperaturePromise.catch(function(error) {
				expect(error).toEqual(errorObj);
				done();
			});
		});
	});
});
```

```js
var WeatherService = {
	fetchCurrentTemperature: fetchCurrentTemperature
};

function fetchCurrentTemperature() {
	return fetch('someweatherapi.com')
		.then(function(response) {
			return response.json();
		})
		.then(function(data) {
			return data.temperature;
		});
}
```

### Next Steps

That's it! You made it. We now have a working, tested JS service. There's still some things we can improve upon -- for example, creating a nicer abstraction around our `promiseHelper`, but we can leave that for another post.

Have any questions or comments? Follow up with any discussion over on the corresponding [gist](https://gist.github.com/pmeskers/2530773be429d522db17f224973c8654).
