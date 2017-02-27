---
authors:
- syeung
categories:
- TDD
- React
- MobX
- Javascript
date: 2017-02-27T16:39:01-04:00
short: |
  A look into testing MobX with React components, plus why MobX is a viable alternative to Redux.
title: TDD with React and MobX
---

#TDD with React and MobX


I recently started playing around with MobX for my React projects after seeing a lot of buzz about it at the React Europe conference I went to last year.  A part of me wanted to roll my eyes - *"Another one??"*.  It's frustrating to hear that there's another latest and greatest thing just when you're getting comfortable with the existing ecosystem.  It's not a coincidence that this was part of our schwag from the conference:

[insert pic of mug]

However, its popularity has yet to tail off.  Its Github repository now has 7462 stars compared to the ~2200 it had during the React Europe conference.  

[insert pic of star graph]

Admittedly, my interest in it started as I was finding some frustrations with Redux, primarily that it involved a lot of boilerplate (e.g., writing actions, writing reducers, creating containers that are connected to the store, etc.), and I found myself hesitant to introduce it to our clients here at Pivotal Labs because it would've added another thing for them to have to learn during their time here.

One way to get around the issues of Redux is to not use Redux at all - just use React and keep actions that call `this.setState` in the top level component. However, this becomes difficult to manage as the number of actions increases.

MobX appears to be a good middleground for these issues. It extracts the responsibility of maintaining a state store and the actions that modify it away from the component, and does it in a way that doesn't introduce too many new parts. 

Unfortunately, the main page on MobX doesn't provide any resources on testing, which is the impetus for this blog post.

### What is MobX?

MobX is YASM (Yet Another State Manager) that is most commonly used with React.

The primary appeal of MobX is that it is intuitive.  The analogy they use on its main page is that it is like an Excel spreadsheet.  There are cells that provide input values (observable properties from the store), and other cells that get updated automatically when those input values change (observers).

Its value proposition is quite the opposite of Redux: 

 * where Redux is extremely explicit about how data travels through components and its state store, MobX is abstracts away many of those details
 * where Redux is based on immutability of data, MobX leverages mutable data to enhance performance and to make the code arguably simpler to read.

This is a simplistic view of the frameworks, and there are certainly pros and cons to both...but that's a topic for another day.


### Testing experiences thus far

There aren't many parts to MobX, which is why testing has largely been a breeze. The key things to know are how the MobX decorators (e.g., @observable, and @observer) work to connect the MobX store to React components

#### Testing observer components

##### Set Up

Under the hood, the `@observer` decorator provided by the `mobx-react` plugin wraps around a React component class and overrites the render function into a `reactiveRender` function that will get called anytime an observed property from the store is updated. At this point in time, since we are just focusing on the component, we can create a mock MobX store with the relevant `@observable` properties and methods.

```js
import React from 'react';
import { observable, useStrict } from 'mobx';
import { renderIntoDocument, Simulate } from 'react-addons-test-utils';
import { findDOMNode } from 'react-dom';
import _ from 'lodash';
import App from 'components/app.js';

describe('App', () => {
  let store;

  beforeEach(() => {
    //turn off strict mode when testing with mock store
    useStrict(false);

    store = observable({
      todos: [],
      addTodo: jasmine.createSpy(),
      removeTodo: jasmine.createSpy(),
      fetchTodos: jasmine.createSpy()
    });
  });

...
```

Note that we have turned off MobX's strict mode with `useStrict(false)`.

With MobX, strict mode disallows the direct mutation of the store's properties, and requires that you use designated actions to make updates (more on this later).  I decided to turn it off in my component tests because when creating a mock store because I want the freedom to be able to modify the properties without having to create an action for it. 

##### Testing that the component is observing the store

Testing that the component is tracking updates in the store involves testing that the component is re-rendered upon a change to an observed property. In our case, we want to see that a todo list starts out empty, but updates with todo items when an item is added to the store.

```js
...

it('is an observer of todos', () => {
  const component = renderIntoDocument(<App store={store}/>);
  const domElement = findDOMNode(component);

  const items = () => {
    return domElement.querySelectorAll('[data-test="item"]');
  };

  // Assert that there are no items to start with
  expect(items().length).toEqual(0);

  // Upon updating an observed property
  component.props.store.todos = [{id: 1, content: 'item'}];

  const itemText = _.map(items(), (item) => {
    return item.textContent;
  });

  // Assert that there are now items on the page
  expect(itemText).toEqual(['item']);
});

...
```

In testing this, it was discovered that the flow from updating the property to re-rendering the component all happens synchronously, which is certainly a bonus for testing.

Correspondingly, we test that the store can be prepopulated with items, which will be reflected when the component renders for the first time

```js
...

it('displays the list of todos from the store prop', () => {
  store.todos = [{id: 1, content: 'first item'}, {id: 2, content: 'second item'}];
  const component = renderIntoDocument(<App store={store}/>);
  const domElement = findDOMNode(component);

  const items = domElement.querySelectorAll('[data-test="item"]');
  const itemText = _.map(items, (item) => {
    return item.textContent;
  });
  expect(itemText).toEqual(['first item', 'second item']);
});

...
```

##### Testing actions passed from the store to the component

We haven't yet implemented the real MobX store, but we can still test that the component's event handler's are trigger actions provided by the store:

```js
  describe('on mount', () => {
    it('calls fetchTodos from its store prop', () => {
      const component = renderIntoDocument(<App store={store}/>);
      expect(store.fetchTodos).toHaveBeenCalled();
    });
  });

  describe('when add item is pressed', () => {
    it('calls addTodo on its store prop, passing in the input value', () => {
      const component = renderIntoDocument(<App store={store}/>);
      const domElement = findDOMNode(component);
      const inputField = domElement.querySelector('[data-test="item-field"]');

      inputField.value = 'Get rice';
      Simulate.change(inputField);
      Simulate.submit(domElement.querySelector('[data-test="item-form"]'));

      expect(store.addTodo).toHaveBeenCalledWith('Get rice');
    });
  });

  describe('when delete button is clicked for an item', () => {
    it('calls removeTodo on its store prop, passing in the item id', () => {
      store.todos = [{id: '1', content: 'first item'}, {id: '2', content: 'second item'}];
      const component = renderIntoDocument(<App store={store}/>);
      const domElement = findDOMNode(component);

      const itemToBeRemoved = domElement.querySelector('[data-item-id="1"]');
      const deleteButton = itemToBeRemoved.querySelector('[data-test="delete-button"]');

      Simulate.click(deleteButton);

      expect(store.removeTodo).toHaveBeenCalledWith('1');
    });
  });

```

Note that the actions need to be a part of the mock store.

```js
...

beforeEach(() => {
  //turn off strict mode when testing with mock store
  useStrict(false);

  store = observable({
    todos: [],
    addTodo: jasmine.createSpy(),
    removeTodo: jasmine.createSpy(),
    fetchTodos: jasmine.createSpy()
  });
});

...
```

Here's the implementation of the component to pass the above tests:

```js
import React from 'react';
import _ from 'lodash';
import {observer} from 'mobx-react';

@observer
class App extends React.Component {
  constructor(props) {
    super(props);

    this.addTodo = this.addTodo.bind(this);
    this.removeTodo = this.removeTodo.bind(this);
  }

  componentDidMount() {
    this.props.store.fetchTodos();
  }

  addTodo(e) {
    e.preventDefault();
    const item = e.target.elements[0].value;
    this.props.store.addTodo(item);
  }

  removeTodo(e) {
    const id = e.target.parentNode.getAttribute('data-item-id');
    this.props.store.removeTodo(id);
  }

  todos() {
    const todos = _.get(this.props, 'store.todos', []);
    return _.map(todos, (toDo) => {
      return (
        <li key={toDo.id} data-item-id={toDo.id}>
          <span data-test="item">
            {toDo.content}
          </span>
          <button data-test="delete-button" onClick={this.removeTodo}>
            Delete
          </button>
        </li>
      );
    });
  }

  render() {
    return (
      <div>
        <div>Todo List</div>
        <ul>
          {this.todos()}
        </ul>
        <form data-test="item-form" onSubmit={this.addTodo}>
          <input data-test="item-field" type="text" placeholder="Item here..."/>
          <input data-test="add-item" type="submit" value="Add Item"/>
        </form>
      </div>
    );
  }
}

export default App;

```

#### Testing the MobX store

Now that we have a passing tests for the component, we can move on to implementing a real MobX store.

#####


```js

```
