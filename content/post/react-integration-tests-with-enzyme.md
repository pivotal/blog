---
authors:
- jacek
categories:
- React
- Enzyme
- Javascript
- Testing
date: 2017-09-15T14:05:25Z
draft: true
short: |
  TODO!!!!!
title: React integration testing with Enzyme
image: /images/react-integration-tests-with-enzyme.gif
---

# The beginning
When setting up a new Spring Boot + React Redux project earlier this year we realised
there was a hole in our setup: frontend integration tests weren't really there.
We had unit tests for components and slow and heavy end-to-end tests
but that made for a very long feedback loop. We wanted something fast and more integration-like
for the frontend.

It seemed that lack of integration tests in a React Redux app was particularly painful:

- Because JavaScript is an untyped language. When app's state structure changes, compiler is no help
  in finding which unit tests should be updated.
- Because in Redux architecture everything is very loosely coupled. Various parts of the app (reducers, components, middleware) don't know of each other's existence as state changes are driven only by dispatched actions. Testing individual bits in isolation gives absolutely no confidence that the whole thing works.

## Enzyme to the rescue?
Enzyme is a test utility which allows you to take a React component, render it in memory
and inspect the output with a jQuery-like API.
Primarily it is used as a unit test library:
you typically render one component (and all its nested components)
and verify that the output is as expected.
It implements React components' lifecycle methods
and it is suitable for testing of things like prop updates,
state changes, event handlers or unmount hooks.

Fortunately for us everything in React is a component,
in particular the router and the store provider are.
So technically nothing bars Enzyme from rendering the entire app
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
the app displays shopping list items. Let's mount the app with Enzyme!

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

That was easy. In the actual test we need to set up a fake server response
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
When we first call `mount` in `AppTestHelper` constructor only the initial
app render happens. It starts the HTTP request to get the shopping list
from the API items but response callback will be called asynchronously.
The purpose of the `asyncFlush` call is to make sure all async callbacks have run.

~~~JavaScript
const asyncFlush = () => new Promise(resolve => setTimeout(resolve, 0));
~~~

By chaining code on `asyncFlush()` we cause a context switch and effectively
wait for the server response to update UI.
With the new `async await` syntax in ECMAScript 2017 the code reads very
similar to synchronous code although stack traces are not as clear as with
synchronous code.

On the project we experimented with our own Promise implementation
that offered a synchronous `flush` function.
It was certainly great fun to write but required a lot of bespoke code
that needed to be maintained and perhaps wasn't worth just for the
benefit of clean stack traces.


## Interactions
Let's move on to a more complex test scenario - adding an item to the list.
The `beforeEach` block a bit earlier initialises the list with
apples and bananas. In the test below, we add carrots and simulate that
at the some time someone deleted apples and added dill.

The expect statement before `asyncFlush` checks the state
before and the other one after the sync with server is done.

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

## What if we use non-React libraries?
One of key features of the app we built was a map.
We ended up using [leaflet.js](http://leafletjs.com/)
which did not at a time have a React adapter suitable for us.
It took some figuring out but at the end it turned out that
testing non-React libraries is not too difficult with Enzyme.

For the purpose of this section let's say our Shopping List app
uses an old school Calendar (?!) library full of calls
to functions like `document.createElement`, `setAttribute` and `appendChild`.
One that dynamically populates a parent div with some text and a span element containing date:

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
It is created directly at the DOM level, so we need to be inspecting DOM
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
Enzyme integration testing is a bit unusual and certainly brings some pros and cons.
Let's look at them:

## The yeahs
- Tests can run in Node, so they are **insanely** fast. Tens of tests involving UI interactions and visiting multiple pages run in a matter of seconds. Try to beat that with a real browser!
- Compared to a previous React project when we didn't have such tests, green bar in the frontend gave us a lot of confidence. As a consequence we would run slow end-to-end tests less often.
- No context switch for developers between unit and integration tests. It's React, Javascript and Enzyme (almost) all the time.
- Very simple setup: it's all there in `package.json`, you just `yarn` and you are good to go.

## The mehs
- When tests fail, sometimes it’s hard to see what's wrong. There is no display, and it may take a few `console.log(screen.debug())` to find out what's broken.
- In some scenarios it is not too easy to set up a test. Usually because of limitations of mocking the api responses.
- Testing non-react libraries, although possible, requires a bit of fiddling (see example above).

Overall I think that the experience was good - I would definitely be for setting this up this way again!

# Summary
