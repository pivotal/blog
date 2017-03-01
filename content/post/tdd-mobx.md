---
authors:
- syeung
categories:
- TDD
- React
- MobX
- Redux
- Javascript
date: 2017-02-28T16:39:01-04:00
short: |
  A look into testing MobX + React, plus why MobX is a viable alternative to Redux.
title: TDD with React and MobX
---

*Note: The below examples assume you are using Webpack to manage app modules, and Jasmine for testing*

# What is MobX?

[MobX](https://mobx.js.org/) is state manager that is most commonly used with React.

The primary appeal of MobX is that it is intuitive.  The analogy they use on its main page is that it is like an Excel spreadsheet.  There are cells that provide input values (observable properties from the store), and other cells that get updated automatically when those input values change (observers).

# Another State Management Framework??!!!

Admittedly, my interest in MobX came as I was finding some frustrations with Redux, primarily that it involved a lot of boilerplate (e.g., writing actions, writing reducers, creating containers that are connected to the store, etc.), and I found myself hesitant sometimes to introduce it to our clients because it would've added another thing for them to have to learn during their time here.

One way to get around the issues of Redux is to not use Redux at all - just use React and keep actions that call `this.setState` in the top level component. However, this becomes difficult to manage as the number of actions increases.

MobX appears to be a good middleground for these issues. It extracts the responsibility of maintaining a state store and the actions that modify it away from the component, and does it in a way that doesn't introduce too many new parts. 

Its value proposition is quite the opposite of Redux: 

 * Where Redux is extremely explicit about how data travels through components and its state store, MobX is abstracts away many of those details
 * Where Redux is based on immutability of data, MobX leverages mutable data to enhance performance and to make the code arguably simpler to read.

This is a simplistic view of the frameworks, and there are certainly pros and cons to both

{{< responsive-figure src="https://cleancoders.com/assets/images/authors-robert-martin-v0.jpg" class="small center">}}

...but that's a topic for another day.

# Testing MobX

Unfortunately, the main page on MobX doesn't provide any resources on testing, which was the impetus for this blog post.

Luckily, there aren't many parts to MobX, which is why testing has largely been a breeze.  Its relatively small API is also why I believe it to be a safe choice when starting a new React project.

The key things to know are how the MobX decorators (e.g., @observable, and @observer) work to connect the MobX store to React components.

## Testing observer components

_**Note**: The full codebase can be found [here](https://github.com/styeung/mobx-todo) on Github.  A simple companion API is also available [here](https://github.com/styeung/mobx-todo-api)._

### Set Up

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

### Testing that the component is observing the store

I want to create a component that dynamically renders based on a list of todos that are passed in by a store.

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

Correspondingly, we test that the store can be prepopulated with items, which will be reflected when the component renders for the first time:

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

### Testing actions passed from the store to the component

We haven't yet implemented the real MobX store, but we can still test that the component's event handler's are trigger actions provided by the store.

Like any good Todo app, I want to be able to load existing todos from an API, add todos to a list, and remove todos to that list.

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

### App Component Implementation

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

## Testing the MobX store

### Testing observable properties

When testing the MobX store, I want to know which properties are observable (i.e., objects subscribed to the store will react to its change).

In this app, I'd like to drive out the functionality where my store's `todos` property are observable.  To do this, I will leverage MobX's `observe` utility that reacts upon an update to observable properties.

```js
import {observe, useStrict} from 'mobx';
import TodoStore from 'stores/todo_store.js';
import axios from 'axios';

describe('TodoStore', () => {
  let todoStore;

  beforeEach(() => {
    useStrict(false);
  });

  it('makes todos observable', () => {
    todoStore = new TodoStore();

    let isObserved = false;
    const observation = observe(todoStore, (changes) => {
      isObserved = true;
    });

    todoStore.todos = 'something else';
    expect(isObserved).toEqual(true);
  });

...
```

In the above case, I am using the observer callback to update a tracking variable `isObserved`.

### Testing actions

Now, I am going to write tests that drive out actions that update the store's properties. More specifically, I want my Todo app to be able to fetch existing todos from an API, add todos, and remove todos. 

Note that these tests are straightforward in that they do not require any MobX-related utilities.

#### Fetching Todos

```js
import {observe, useStrict} from 'mobx';
import TodoStore from 'stores/todo_store.js';
import axios from 'axios';

describe('TodoStore', () => {
  let todoStore;

  beforeEach(() => {
    useStrict(false);
  });

  ...

  describe('actions', () => {
    let promiseHelper,
        promisePostHelper,
        promiseDeleteHelper;

    beforeEach(() => {
      const fakePromise = new Promise((resolve, reject) => {
        promiseHelper = {
          resolve: resolve
        }
      });

      ...

      spyOn(axios, 'get').and.returnValue(fakePromise);

      ...
    });

    describe('.fetchTodos', () => {
      it('fetches the list of todos from the api', () => {
        todoStore = new TodoStore();
        todoStore.fetchTodos();
        expect(axios.get).toHaveBeenCalledWith('http://localhost:4567/items');
      });

      describe('when fetch is successful', () => {
        it('assigns the response from the api to the store todos', (done) => {
          todoStore = new TodoStore();
          todoStore.fetchTodos();
          promiseHelper.resolve({data: 'stuff'});

          _.defer(() => {
            expect(todoStore.todos).toEqual('stuff');
            done();
          });
        });

        describe('fetch response is non-empty', () => {
          it('sets the currentId to the max id of the fetched todos', (done) => {
            todoStore = new TodoStore();
            todoStore.fetchTodos();

            promiseHelper.resolve({
              data: [ 
                {id: '1', content: 'number 1'}, 
                {id: '100', content: 'number 100'}
              ]
            });

            _.defer(() => {
              expect(todoStore.currentId).toEqual(100);
              done();
            });
          });
        });

        describe('fetch response is empty', () => {
          it('sets the currentId to 0', (done) => {
            todoStore = new TodoStore();
            todoStore.fetchTodos();

            promiseHelper.resolve({data: []});

            _.defer(() => {
              expect(todoStore.currentId).toEqual(0);
              done();
            });
          });
        });
      });
    });

    ...
});
...

```

#### Adding Todos

```js
import {observe, useStrict} from 'mobx';
import TodoStore from 'stores/todo_store.js';
import axios from 'axios';

describe('TodoStore', () => {
  let todoStore;

  beforeEach(() => {
    useStrict(false);
  });

  ...

  describe('actions', () => {
    let promiseHelper,
        promisePostHelper,
        promiseDeleteHelper;

    beforeEach(() => {
      ...

      const fakePostPromise = new Promise((resolve, reject) => {
        promisePostHelper = {
          resolve: resolve
        }
      });

      ...

      spyOn(axios, 'post').and.returnValue(fakePostPromise);

      ...
    });

    ...

    describe('.addTodo', () => {
      beforeEach(() => {
        todoStore = new TodoStore();
      });

      it('makes a post to the api with the id and item', () => {
        todoStore.addTodo('eat lunch');

        expect(axios.post).toHaveBeenCalledWith('http://localhost:4567/item', {id: '1', content: 'eat lunch'});
      });

      describe('when post is successful', () => {
        it('adds the passed in value to the list of todos, assigning a unique id', (done) => {
          todoStore.addTodo('eat lunch');
          promisePostHelper.resolve();

          _.defer(() => {
            const todos = todoStore.todos.slice();
            expect(todos).toContain(jasmine.objectContaining({content: 'eat lunch'}));

            const ids = _.map(todos, (todo) => {
              return todo.id;
            });

            expect(_.uniq(ids).length).toEqual(ids.length);
            done();
          });
        });
      });
    });

    ...
  });
});
...

```

#### Removing Todos

```js
import {observe, useStrict} from 'mobx';
import TodoStore from 'stores/todo_store.js';
import axios from 'axios';

describe('TodoStore', () => {
  let todoStore;

  beforeEach(() => {
    useStrict(false);
  });

  ...

  describe('actions', () => {
    let promiseHelper,
        promisePostHelper,
        promiseDeleteHelper;

    beforeEach(() => {
      ...

      const fakeDeletePromise = new Promise((resolve, reject) => {
        promiseDeleteHelper = {
          resolve: resolve
        }
      });

      spyOn(axios, 'delete').and.returnValue(fakeDeletePromise);
    });

    ...

    describe('.removeTodo', () => {
      it('makes a delete to the api with the id', () => {
        todoStore = new TodoStore();

        todoStore.removeTodo('1');

        expect(axios.delete).toHaveBeenCalledWith('http://localhost:4567/item/1');
      });

      it('removes the todo with the passed in id', (done) => {
        const defaultTodos = [{id: '1', content: 'do homework'}, {id: '2', content: 'watch tv'}]
        todoStore = new TodoStore(defaultTodos);
        todoStore.removeTodo('1');
        promiseDeleteHelper.resolve();

        _.defer(() => {
          const todos = todoStore.todos.slice();
          expect(todos).not.toContain(jasmine.objectContaining({content: 'do homework'}));

          done();
        });
      });
    });
  });
});
...

```

### Todo Store Implementation

A couple notes on our implementation of the todo store.

  * The `@action` decorators are not necessary for MobX's observables to work.  However, if you turn strict mode to 'on' using `useStrict(true)`, then the modification of observable properties can only happen within methods decorated with `@action`.  This helps with readability and enforces best practices (e.g., do not modify the store properties directly from a component).
  * If you use strict mode, note that the `@action` decorator do not apply to scheduled functions like callbacks or those in `then` blocks.  Therefore, you will need to wrap those functions inside MobX's `action` method as well.

```js
import {observable, action, useStrict} from 'mobx';
import _ from 'lodash';
import axios from 'axios';

useStrict(true);

const apiDomain = 'http://localhost:4567';

const getMaxId = (items) => {
  if(_.isEmpty(items)) {
    return 0;
  }

  return _(items)
    .map((item) => { return parseInt(item.id); })
    .max();
};

class TodoStore {
  currentId = 0;

  @observable todos;

  constructor(todos = []) {
    this.todos = todos;
  }

  @action
  fetchTodos() {
    axios.get(apiDomain + '/items').then(action((response) => {
      this.todos = response.data
      this.currentId = getMaxId(this.todos);
    }));
  }

  @action
  addTodo(task) {
    this.currentId++;
    const newTask = {id: String(this.currentId), content: task};
    axios.post(apiDomain + '/item', newTask).then(action(() => {
      this.todos.push(newTask);
    }));
  }

  @action
  removeTodo(id) {
    axios.delete(apiDomain + `/item/${id}`).then(action(() => {
      _.remove(this.todos, (todo) => {
        return todo.id === id;
      });
    }));
  }
}

export default TodoStore;

```
