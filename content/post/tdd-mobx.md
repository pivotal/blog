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

```
import React from 'react';
import { observable } from 'mobx';
import { renderIntoDocument, Simulate } from 'react-addons-test-utils';
import { findDOMNode } from 'react-dom';
import _ from 'lodash';
import App from 'components/app.js';

describe('App', () => {
  let store;

  beforeEach(() => {
    store = observable({
      todos: [],
      addTodo: jasmine.createSpy(),
      removeTodo: jasmine.createSpy()
    });
  });

...
```

##### Testing that the component is observing the store

Testing that the component is tracking updates in the store involves testing that the component is re-rendered upon a change to an observed property. In our case, we want to see that a todo list starts out empty, but updates with todo items when an item is added to the store.

```
...

  it('is an observer of todos', () => {
    const component = renderIntoDocument(<App store={store}/>);
    const domElement = findDOMNode(component);

    const items = () => {
      return domElement.querySelectorAll('[data-test="item"]');
    };

    expect(items().length).toEqual(0);

    component.props.store.todos = [{id: 1, content: 'item'}];

    const itemText = _.map(items(), (item) => {
      return item.textContent;
    });
    expect(itemText).toEqual(['item']);
  });

...
```



