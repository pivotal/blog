---
authors:
- jacek
categories:
- React
- Enzyme
- Javascript
- Testing
date: 2017-09-29T14:05:25Z
draft: true
short: |
  We used Enzyme, a popular React unit testing library, for full-on frontend integration tests.
  Find out how this greatly improved feedback, and avoid some pitfalls we've come across.
title: React integration testing with Enzyme
image: /images/react-integration-tests-with-enzyme.gif
---

# The beginning
Earlier this year while setting up a React Redux project, we realised
there was a layer missing in our testing pyramid: integration tests.
Multiple starter-seeds we looked at had unit tests for components and end-to-end tests
but the latter were slow making for a very long feedback loop.
We figured that fast integration tests could help a lot.

It seemed that lack of integration tests in a React Redux app was particularly painful
because of the following two reasons:

- JavaScript is an untyped language. When the app’s state structure changes, the compiler cannot helpfind unit tests that need adjusting
- In the Redux architecture everything is very loosely coupled. Various parts of the app (reducers, components, middleware) by design don’t know of each others existence as state changes are driven only by dispatched actions. Testing individual bits in isolation gives absolutely no confidence that the whole thing works.

## Enzyme to the rescue?
[Enzyme](http://airbnb.io/enzyme/) is a test utility which allows you to take a React component, render it in memory
and inspect the output with a jQuery-like API.
Primarily it is used as a unit test library:
you typically render one component with it's nested components
and verify that the output is as expected.
Enzyme implements React components' lifecycle methods
and is suitable for testing of things like prop updates,
state changes, event handlers or unmount hooks.

Fortunately for us everything in React is a component,
in particular the router and the store provider.
So, technically, nothing stops Enzyme from rendering the entire app
and acting as an integration test engine.


# The toy app
React tutorials usually use a ToDo list app for demonstration purposes but that idea is a bit worn out now.
All code examples below come from something else entirely: a shopping list app.

{{< responsive-figure src="/images/react-integration-tests-with-enzyme/app.gif" class="center" >}}

If the code snippets on their own don't make much sense to you,
you can find the full source code in
[this Github repo](https://github.com/jacek-rzrz/react-integration-tests-enzyme).

The main app component is simple: we have a list of items rendered by the
`ShoppingList` component and either a link to a new item form or the form itself below it.
Everything is wrapped by a `Router` and Redux store `Provider`.

~~~JavaScript
class App extends Component {

    render() {
        return (
            <Provider store={this.store}>
                <ConnectedRouter history={history}>
                    <div className="app">
                        <h1>Shopping list</h1>
                        <ShoppingList/>
                        <Route path="/new-item" component={ShoppingListItemForm}/>
                        <Route exact path="/" render={() =>
                            <Link to="/new-item" data-qa="add-new-item">New item</Link>
                        }/>
                    </div>
                </ConnectedRouter>
            </Provider>
        );
    }
}
~~~
There also is a Redux middleware that fetches shopping list items from a server
whenever the app navigates to the root URL. When a new item is submitted,
the middleware makes a local optimistic update (appends the new item to the local state)
and navigates to the root URL that causes a refresh of the list.

## Basic integration test
One very basic integration test that we may want is to check that
the app displays shopping list items. Let’s begin by mounting the app with Enzyme!

~~~JavaScript
class AppTestHelper {

  constructor() {
    this.screen = mount(<App/>);
  }

  getItems() {
    return this.screen.find('[data-qa="item-name"]').map(node => node.text());
  }
}
~~~

**That was easy**. In the actual test we need to set up a fake server response
with the items and wait for the app to make a HTTP request and update UI.
~~~JavaScript
beforeEach(async () => {
    mockApi.mockGetItems([{id: 11, name: 'apples'}, {id: 12, name: 'bananas'}]);
    app = new AppTestHelper();
    await asyncFlush();
});

it('displays shopping items fetched from the server', () => {
    expect(app.getItems()).toEqual(['apples', 'bananas']);
});
~~~

## Waiting for all the async
When we call `mount` for the first time in `AppTestHelper` constructor, only the initial
app render happens. It synchronously starts the HTTP request to get the shopping list
from the API items but response callback will be called asynchronously.
The purpose of the `asyncFlush` call is to wait for all async callbacks to run.

~~~JavaScript
const asyncFlush = () => new Promise(resolve => setTimeout(resolve, 0));
~~~

By chaining code on `asyncFlush()` we cause a context switch and effectively
wait for the server response to update the UI.
With the new `async await` syntax in ECMAScript 2017 the test code reads very
similar to synchronous code although stack traces are not as clear as with
synchronous code.

On the project we experimented with our own Promise implementation
that offered a synchronous `flush` function.
It was certainly fun to write it, but it required a lot of bespoke code
that needed to be maintained and wasn't worth the effort
just for the benefit of clean stack traces.

## Interactions
Let’s move on to testing a more complex scenario - adding an item to the list.
The `beforeEach` block a bit earlier initialises the list with
apples and bananas. In the test below, we add carrots and simulate that
at the some time someone deleted apples and added dill.

The first `expect` checks the state before,
while the other one after the server response has been handled.

~~~JavaScript
it('users can add items to the shopping list', async () => {
    // optimistic update (local only):
    app.clickAddNewItemButton();
    app.fillInItemName('carrots');
    app.clickSaveNewItemButton();

    expect(app.getItems()).toEqual(['apples', 'bananas', 'carrots']);

    // sync with server:
    mockApi.mockGetItems([{id: 12, name: 'bananas'}, {id:13, name: 'carrots'}, {id: 14, name: 'dill'}]);
    await asyncFlush();

    expect(app.getItems()).toEqual(['bananas', 'carrots', 'dill']);
});
~~~

UI interaction functions:
~~~JavaScript
clickAddNewItemButton() {
    const button = this.screen.find(`[data-qa="${'add-new-item'}"]`)
    click(button);
}

fillInItemName(name) {
    const input = this.screen.find(`[data-qa="${'new-item-name'}"]`)
    setValue(input, name);
}
~~~

`click` and `setValue` call Enzyme's `simulate`.
It is fairly simple: `simulate('someEvent')` looks for a prop
called `onSomeEvent` and invokes it if there is one.
~~~JavaScript
const click = enzymeNode => {
  enzymeNode.simulate('click', {button: 0}); // button: 0 means left mouse button
};

const setValue = (enzymeNode, value) => {
  enzymeNode.simulate('change', {target: {value}});
  enzymeNode.simulate('blur');
};
~~~

## Warm start vs cold start
Our frontend was a single page app: its sources would load only once per session.
Then everything is local except for any calls to a REST API that the app would do.
When you clicked on a link somewhere on the page you would see address changing in the URL bar
but the page wouldn't actually fully reload
(the browser wouldn't make a HTTP request to the new URL).
The app maintained an internal state - mostly cached resources fetched
from the API. That state would build up as users navigated through
various pages in the application.

Continuing with the shopping list example, there are two ways to get to the new item form:

- User going to the root address and navigating to `/new-item` with an internal link (we called it warm start);
- User going to `/new-item` straight away (cold start).

They should see exactly the same page regardless of how they arrived at that URL
however each of these cases executes slightly different code.
Integration tests will look slightly different depending on whether we do
warm start or cold start:

Warm start:
```
beforeEach(async () => {
    app = new AppTestHelper();
    app.clickAddNewItemButton();
    await asyncFlush();
});
```

Cold start:
```
beforeEach(async () => {
    app = new AppTestHelper();
    app.goTo('/new-item');
    await asyncFlush();
});
```

Difference between the two is very small in this example.
With a real application however,
getting to certain pages in the warm start mode may require multiple interactions.
Then when something major breaks on one page
it affects tests of pages which are later in the user flow.
As a consequence we have a sea of failed tests and it's not clear what actually went wrong
- there is no UI in the browser to look at. Also, keeping oversight on the stubs as the number of interactions increase is difficult and makes debugging harder.
With cold start tests some of that red noise goes away.

During the project we first wrote warm start integration tests in Enzyme
but then realised the benefit of cold start and switched.
In terms of coverage, our end-to-end tests were exercising longer user interactions
so they were mostly testing warm start.

## What if we use non-React libraries?
One of key features of the app we built was a map.
We ended up using [leaflet.js](http://leafletjs.com/)
which did not at the time have a React adapter suitable for us.
It took some figuring out but in the end it turned out that
testing non-React libraries is not *too* difficult with Enzyme.

For the purpose of this section let's say our Shopping List app
uses an old school Calendar (?!) library that manipulates the DOM directly.
It dynamically populates a parent div with some text and a span element containing date:

~~~JavaScript
export function calendar(div) {
    const span = document.createElement("span");
    span.setAttribute("data-qa", "today");
    span.innerHTML = new Date().toLocaleDateString("en-GB");

    div.appendChild(document.createTextNode("Today is "));
    div.appendChild(span);
}
~~~

React component wrapping this library may look like this:
~~~JavaScript
class Calendar extends React.Component {

    render() {
        return <div ref={div => this.div = div} />;
    }

    componentDidMount() {
        calendar(this.div);
    }
}
~~~

And this is how an output HTML can look like in a browser:
~~~html
<div>Today is <span data-qa="today">21/09/2017</span></div>
~~~

If we query Enzyme for an element with attribute `[data-qa="today"]`
it won't return anything because the span with date is not managed by React.
It is created directly at the DOM level, so we need to be inspecting the DOM
in order to find it.

Fortunately, Enzyme's `mount` provides us with a way to pass an element
where our React component will be attached. We can change our `AppTestHelper`
constructor in the following way:

~~~JavaScript
export class AppTestHelper {

    constructor() {
        this.dom = document.createElement("div");
        this.screen = mount(<App/>, { attachTo: this.dom });
    }

    getDate() {
        return this.dom.querySelector('[data-qa="today"]').innerHTML;
    }
}
~~~

It was only a bit more difficult than this with Leaflet where we had to
monkeypatch a few functions that Leaflet was calling internally.

# Looking back
Enzyme integration testing is a bit unusual and we weren't really sure where it was going to get us.
Here are some good and bad sides we found:

## The yeahs
- Tests can run in Node, so they are *insanely* fast.
  Hundreds of tests involving UI interactions and visiting multiple pages run in a matter of a few seconds.
  Feedback is fast, coverage is vast.
- There was less need to run full-blown end-to-end tests, which saves time.
- No context switch for developers between unit and integration tests. It's React, Javascript and Enzyme (almost) all the time.
- You *can* test how non-React libraries integrate with the React app.
- It is easier to test various edge cases then in traditional Selenium tests - e.g. asserting on UI state
  both before and after it updated as a result of a server response.

## The mehs
- Sometimes when tests fail it is hard to tell what actually went wrong as there is no graphical UI to look at.
  It may take a few `console.log(screen.debug())` to find out what's broken. Cold-start approach can help in some cases.
- In some scenarios it is not too easy to set up a test. Usually because of limitations of mocking the API responses.
- Testing non-react libraries requires a bit of fiddling (see example above).
- Enzyme does not clean the state between tests, you will need to manage test pollution yourself by cleaning state after each test.

# Summary
We took an experimental path and used Enzyme for writing integration tests that mounted
an entire React-Redux application.
There were a few things that we had to figure out in order to make it work for a large application
such as mocking server responses, testing the UI around asynchronous callbacks or testing
integrations with non-React code.
The tests were very fast and were giving us a lot of confidence in the frontend before we
started slow end-to-end suite. 

# Looking ahead
Thinking of issues that were causing the integration tests to fail,
many arose from the fact that we were writing untyped code.
In Redux architecture everything revolves around the application state object.
When that object is strongly typed and compiler gives us type errors,
we get quicker feedback on certain defects and spend less time looking why the integration tests are red.

I quickly [played with Typescript and React](https://github.com/jacek-rzrz/react-app-typescript) recently
and was impressed by how easy it is to [add Typescript](https://github.com/Microsoft/TypeScript-React-Starter)
to [create-react-app](https://github.com/facebookincubator/create-react-app).
This is definitely an area I am interested to continue exploring to further improve
developer effectiveness and experience.
