---
authors:
- syeung
categories:
- TDD
- React
- Javascript
date: 2016-07-07T20:47:25-04:00
short: |
  A better way to avoid brittle unit tests in React
title: Why you should stub, not shallow render, child components when testing React
---

*Note: The below examples assume you are using Webpack to manage app modules, and Jasmine for testing*

## The Gist
Stubbing/mocking a React component is a better way than shallow rendering to avoid brittle unit tests while still preserving the ability to test the full component lifecycle.

## The Problem

If you've tested a decent-sized React application, you've no doubt encountered the annoyance of having to edit test files of top-level parent components as you build out features of lower-level children.


For example, say you are building a set of components in which the Ancestor component passes down its heirlooms prop to its Child component.

```
//ancestor_spec.jsx

var TestUtils = require('react-addons-test-utils');
var React = require('react');
var ReactDOM = require('react-dom');
var Ancestor = require('../../../app/components/ancestor.jsx');
var Child = require('../../../app/components/child.jsx');

describe('Ancestor', function() {
  var component,
      heirlooms;

  beforeEach(function() {
    heirlooms = {
      foo: 'bar'
    }
  });

  it('has a Child component', function() {
    component = TestUtils.renderIntoDocument(<Ancestor heirlooms={heirlooms}/>);
    var childComponents = TestUtils.scryRenderedComponentsWithType(component, Child);

    expect(childComponents.length).toEqual(1);
  });

  it('passes down the heirlooms prop to the Child', function() {
    component = TestUtils.renderIntoDocument(<Ancestor heirlooms={heirlooms}/>);
    var childComponent = TestUtils.findRenderedComponentWithType(component, Child);
    expect(childComponent.props.heirlooms).toEqual(heirlooms);
  });
});

```
And you implement it as such:

```
//ancestor.jsx

var React = require('react');
var Child = require('./child.jsx');

var Ancestor = React.createClass({
  render: function() {
    return (
      <div>
        <Child heirlooms={this.props.heirlooms}/>
      </div>
    );
  }
});

module.exports = Ancestor;
```

Perfect, all green.

Now let's say you need to drive out the next feature in which you need to add some more detail to the Child component.

```
//child_spec.jsx

var TestUtils = require('react-addons-test-utils');
var React = require('react');
var ReactDOM = require('react-dom');
var Child = require('../../../app/components/child.jsx');

describe('Child', function() {
  var component,
      domElement,
      heirlooms;

  beforeEach(function() {
    heirlooms = {
      jewelry: {
        gold: {
          type: 'bracelet'
        }
      }
    }
  });

  it('renders a statement about the gold jewelry in the heirlooms prop', function() {
    component = TestUtils.renderIntoDocument(<Child heirlooms={heirlooms}/>);
    domElement = ReactDOM.findDOMNode(component);

    expect(domElement.innerHTML).toEqual('Hello, please give me your bracelet');
  });
});
```

```
//child.jsx

var React = require('react');

var Child = React.createClass({
  render: function() {
    return (
      <div>
        {'Hello, please give me your ' + this.props.heirlooms.jewelry.gold.type}
      </div>
    );
  }
});

module.exports = Child;
```

Uh oh. The Child spec passes, but now there is a regression on the Ancestor spec.  You get the error message.

```
TypeError: Cannot read property 'gold' of undefined
```

Turns out that the heirlooms prop needed to have more specificity than was originally thought when the Ancestor component was first written.  Now you have to go back to to `ancestor_spec.jsx` and update the heirlooms fixture to support the new implementation of the Child component, even though none of the Ancestor specs require it.  This is tedious, and you shouldn't need to do this. This, is a test smell.

<iframe src='https://gfycat.com/ifr/ImaginativeSecondBighornsheep' style="display: block; margin: 0 auto; padding: 20px 0;" frameborder='0' scrolling='no' width='640' height='360' allowfullscreen></iframe>

## Shallow rendering to the rescue?

### React TestUtils shallow renderer
[Shallow rendering](https://facebook.github.io/react/docs/test-utils.html#shallow-rendering) from React's TestUtils was the first attempt by Facebook to solve this problem. As explained by the creators, the utility allows you to "render a component 'one level deep'...without worrying about the behavior of child components, which are not instantiated or rendered".

However, it suffers from a few issues. For one, it is difficult to query for child elements of the component that you are testing.  Because the rendering is not occurring on a real DOM, you cannot use methods such as `document.getElementsByClassName` (or any jQuery methods, for that matter).  Furthermore, React's TestUtils methods such as `scryRenderedComponentsWithType`, or `scryRenderedDomComponentsWithClass` do not work either.

The second problem is that shallow rendering does not capture the full lifecycle of the component, such as the `componentWillMount` and `componentDidMount` steps.  These two lifecycle methods are among the most used in the setup of a component, and it is awkward and tough to test them separately, or worse, not test them at all.

### AirBnb's Enzyme
[Enzyme](https://github.com/airbnb/enzyme), a React testing utilities library from AirBnb, addresses some of the shortcomings of React TestUtils' shallow rendering with its [own way of shallow rendering components](https://github.com/airbnb/enzyme/blob/master/docs/api/shallow.md). In particular, it has a much more useful querying API.

With Enzyme, you can find child nodes of shallowly rendered components using a jQuery-like querying syntax. Although it's not a one-to-one mapping of jQuery's API, it does the job quite well.

Unfortunately, like React TestUtils, Enzyme's shallow rendering also does not capture the full lifecycle of the component, meaning `componentWillMount` and `componentDidMount` will not be fired.

## A Better Solution
A better solution is to stub a immediate children of the React component under test before rendering it into the document.  Stubbing a component is to preserve its identity as a React component, while removing any of its user-defined behaviors, e.g., its [lifecycle methods](https://facebook.github.io/react/docs/component-specs.html).

For example, we can create a test helper method that takes in a component class as an argument:

```
//test_helpers.js
var _ = require('lodash');

var lifecycleMethods = [
    'render',
    'componentWillMount',
    'componentDidMount',
    'componentWillReceiveProps',
    'shouldComponentUpdate',
    'componentWillUpdate',
    'componentDidUpdate',
    'componentWillUnmount'
];

var stubComponent = function(componentClass) {
  beforeEach(function() {
    _.each(lifecycleMethods, function(method) {
      if(typeof componentClass.prototype[method] !== 'undefined') {
        spyOn(componentClass.prototype, method).and.returnValue(null);
      }
    });
  });
};

module.exports = {
  stubComponent: stubComponent
};
```

Essentially, when `stubComponent` is called in a test, we are injecting a `beforeEach` block that stubs out the lifecycle methods of the passed-in component class.

Note that we are spying on the component class' prototype because the lifecycle methods are actually defined on the prototype under the hood.

If you need to stub out a component's PropTypes, these are defined on the component class rather than its prototype, so you will need to stub it out like this:

```
var stubComponent = function(componentClass) {
  var originalPropTypes;

  beforeEach(function() {
    originalPropTypes = componentClass.propTypes;

    componentClass.propTypes = {};

    spyOn(componentClass.prototype, 'render').and.returnValue(null);
    spyOn(componentClass.prototype, 'componentWillMount').and.returnValue(null);
    spyOn(componentClass.prototype, 'componentDidMount').and.returnValue(null);
    spyOn(componentClass.prototype, 'componentWillReceiveProps').and.returnValue(null);
    spyOn(componentClass.prototype, 'shouldComponentUpdate').and.returnValue(null);
    spyOn(componentClass.prototype, 'componentWillUpdate').and.returnValue(null);
    spyOn(componentClass.prototype, 'componentDidUpdate').and.returnValue(null);
    spyOn(componentClass.prototype, 'componentWillUnmount').and.returnValue(null);
  });

  afterEach(function() {
    componentClass.propTypes = originalPropTypes;
  });
};

module.exports = {
  stubComponent: stubComponent
};
```

Remember to restore the original propTypes in the `afterEach` block to avoid test pollution.  Although Jasmine's `spyOn` cleans up itself after each `it` block, setting the propTypes to a different value does not.

Now that our test helper is ready, let's put it into action.

```
//ancestor_spec.jsx

var TestUtils = require('react-addons-test-utils');
var React = require('react');
var ReactDOM = require('react-dom');
var Ancestor = require('../../../app/components/ancestor.jsx');
var Child = require('../../../app/components/child.jsx');
var TestHelpers = require('../helpers/test_helpers.js');

var stubComponent = TestHelpers.stubComponent;

describe('Ancestor', function() {
  var renderer,
      component,
      heirlooms;

  stubComponent(Child);

  beforeEach(function() {
    heirlooms = {
      foo: 'bar'
    }
  });

  it('has a Child component', function() {
    component = TestUtils.renderIntoDocument(<Ancestor heirlooms={heirlooms}/>);
    var childComponents = TestUtils.scryRenderedComponentsWithType(component, Child);

    expect(childComponents.length).toEqual(1);
  });

  it('passes down the heirlooms prop to the Child', function() {
    component = TestUtils.renderIntoDocument(<Ancestor heirlooms={heirlooms}/>);
    var childComponent = TestUtils.findRenderedComponentWithType(component, Child);
    expect(childComponent.props.heirlooms).toEqual(heirlooms);
  });
});
```

And voilà, all green tests!
