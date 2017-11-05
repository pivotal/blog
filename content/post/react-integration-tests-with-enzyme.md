---
authors:
- jacek
- bgrohbiel
categories:
- React
- Enzyme
- Javascript
- Testing
date: 2017-11-05T14:05:25Z
draft: false
short: |
  We used Enzyme, a popular React unit testing library, for full-on frontend integration tests.
  Find out how our setup greatly improves feedback and avoid the pitfalls we've come across.
title: React integration testing with Enzyme
image: /images/react-integration-tests-with-enzyme.gif
---

# The beginning
Earlier this year while setting up a React-Redux project, we realised
that various React seeds were missing integration tests.
The seeds usually shipped configuration for unit tests and acceptance tests.

We found the lack of integration tests in a React Redux application was particularly painful
because of the following two reasons:

- The decoupled design of Redux: The Redux building blocks like reducers, components, middleware don’t know of each others existence. Testing individual bits in isolation gives absolutely no confidence that they work together.
- JavaScript is a dynamically typed language: when the app’s state structure changes, the compiler cannot help find unit tests that need adjusting

We were interested to test how any subset or even all the loosely coupled parts together - with a tight feedback loop, hence no browser or Selenium involved.

## Enzyme to the rescue?
[Enzyme](http://airbnb.io/enzyme/) is a test utility which allows you to take a React component, render it in memory
and inspect the output with a jQuery-like API.
Primarily it is used as a unit test library:
you typically render one component with its nested components
and verify that the output is as expected.
Enzyme implements React components' lifecycle methods
and is suitable for testing of things like prop updates,
state changes, event handlers or unmount hooks.

Fortunately for us everything in React is a component,
in particular the router and the store provider.
Technically, nothing stops Enzyme from rendering the entire app in memory
and acting as an integration test engine.

Enzyme can be run in node using [jsdom](https://github.com/tmpvar/jsdom) to simulate a browser.


# The example app
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
let screen;

beforeEach(async () => {
    mockApi.mockGetItems([{id: 11, name: 'apples'}, {id: 12, name: 'bananas'}]);
    screen = mount(<App/>);
    await asyncFlush();
});

it('displays shopping items fetched from the server', () => {
    expect(getItems()).toEqual(['apples', 'bananas']);
});

getItems() {
  return screen.find('[data-qa="item-name"]').map(node => node.text());
}
~~~

We set up a mock server response with two items on the list, mount the app, wait for it to
fetch the items from the server (more on that below) and assert the app renders those items.
It's a very simple test, but it touches the router, middleware, reducers and components,
so it adds a lot of confidence in different parts of the app working together.

## Waiting for asynchronous events
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

## Testing user interactions
Let’s move on to testing a more complex scenario - adding an item to the list.
The `beforeEach` block a bit earlier initialises the list with
apples and bananas. In the test below, we add carrots and simulate that
someone else simultaneously deleted apples and added dill.

The first `expect` checks the state before,
while the other one after the server response has been handled.

~~~JavaScript
it('users can add items to the shopping list simultaneously', async () => {
    // optimistic update (local only):
    clickAddNewItemButton();
    fillInItemName('carrots');
    clickSaveNewItemButton();

    expect(getItems()).toEqual(['apples', 'bananas', 'carrots']);

    // sync with server:
    mockApi.mockGetItems([{id: 12, name: 'bananas'}, {id:13, name: 'carrots'}, {id: 14, name: 'dill'}]);
    await asyncFlush();

    expect(getItems()).toEqual(['bananas', 'carrots', 'dill']);
});

clickAddNewItemButton() {
    const button = screen.find(`[data-qa="${'add-new-item'}"]`)
    click(button);
}

fillInItemName(name) {
    const input = screen.find(`[data-qa="${'new-item-name'}"]`)
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

## Testing url states
As opposed to testing user interactions, you probably also want to test url states.
Continuing with the shopping list example, there are two ways to get to the new item form:
- By interaction: user going to the root address and navigating to `/new-item` with an internal link (we named this warm start);
- By url state: user going to `/new-item` straight away (we named this cold start).

They should see exactly the same page regardless of how they arrived at that URL
however each of these cases executes slightly different code.
Integration tests will look slightly different depending on whether we do
warm start or cold start:

Warm start:
```
beforeEach(async () => {
    screen = mount(<App />);
    clickAddNewItemButton();
    await asyncFlush();
});
```

Cold start:
```
beforeEach(async () => {
    screen = mount(<App />);
    const store = screen.find(Provider).prop('store');
    store.dispatch(push('/new-item'));
    await asyncFlush();
});
```

It is worth noting that testing states by interactions can become cumbersome in larger applications.
The more interations a test requires, the more likely it is that one of the interactions fails. If this is the case, it is hard to figure out what exactly went wrong. In particularly keeping oversight on the stubs as the number of interactions increase is difficult and makes debugging hard.
With cold start tests some of that red noise goes away.

In the beginning of the project we wrote mainly interaction-based integration tests in Enzyme. As the application grew, we switched more and more to setting state through the url state, and then kept the interactions focused on the test at hand. Complicated interactions we ran as acceptance tests.

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
where our React component will be attached. We can introduce a `dom`
to our test:

~~~JavaScript
let dom;

let screen;

beforeEach(() => {
    mockDate.set(new Date(2017, 11, 31));
    dom = document.createElement("div");
    screen = mount(<App/>, { attachTo: this.dom });
});

it('renders current date', () => {
    expect(getDate()).toBe('31/12/2017');
});

getDate() {
    return dom.querySelector('[data-qa="today"]').innerHTML;
}
~~~

It was only a bit more difficult than this with Leaflet where we had to
monkeypatch a few functions that Leaflet was calling internally.

# Do we need acceptance tests?
Our integration tests became so rich, they were quite similar to our acceptance tests in terms of interactions. Yet, we decided that in the case of our application there was value in keeping both:

- The acceptance tests exercised both frontend and backend - no stubs, real interactions.
- The acceptance tests run in a browser and allowed to test a particular version of IE.
- The acceptance tests were checking the app in warm start view, and JavaScript integration tests were exercising cold start more often.

Interesting further research could have been to integrate a Contract Testing framework such as [Pact](https://docs.pact.io/) or [Spring Cloud Contract](https://cloud.spring.io/spring-cloud-contract/)). With such a tool, it would be possible to verify the correctness of every stub, and orchestrate the stubs better. Perhaps that would have helped to increase the confidence in the integration tests further.


# Looking back on integration tests with Enzyme
Enzyme integration testing is a bit unusual and we weren't really sure where it was going to get us.
Here are some good and bad sides we found:

## The yeahs
- Tests can run in Node, so they are *insanely* fast.
  Hundreds of tests involving UI interactions and visiting multiple pages run in a matter of a few seconds. Feedback is fast, coverage is vast.
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
- Running in Node environment, Enzyme tests cannot fully replace browser testing that guarantees we are not
  missing some polyfill or lacking a hack required by IE.

# Summary
We took an experimental path and used Enzyme for writing integration tests that mounted
an entire React-Redux application.
There were a few things that we had to figure out in order to make it work for a large application
such as mocking server responses, testing the UI around asynchronous callbacks and testing
integrations with non-React code.
As a result, we had roughly 500 tests running within seconds and providing us with important confidence before kicking off the few notoriously slow acceptance tests.

*Thanks to Callum, Daniela and Gagan for reading early versions of this post!*
