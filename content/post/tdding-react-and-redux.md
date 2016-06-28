---
authors:
- syeung
categories:
- TDD
- React
- Redux
- Javascript
date: 2016-05-04T16:39:01-04:00
short: |
  Helpful patterns for unit testing a React-Redux app
title: TDDing React + Redux
---

Redux has become an easy way to manage state in a React application due to features such as having one store as the single source of truth, as well as actions and reducers that consist of pure functions.  These hallmarks of Redux simplify unit testing as well. However, despite its simplicity, it is important to ensure proper test coverage for all the moving parts.

In TDDing a React-Redux app, I have found the following flow to be helpful in making sure that I've properly tested all the parts:

1. [Test that a component has received the right state items and actions from the store](#connected-components)
2. [Test that the action does what we expect it to do](#actions)
3. [Test that reducer correctly handles that action (and has an appropriate default/initial state)](#reducers)


*Note: The below examples assume you are using Webpack or Browserify to manage app modules, and Jasmine for testing*

## <a name="connected-components">1.</a> Testing connected components
The true test to see whether Redux and React have been wired up correctly is to ensure that the right pieces of the store state and dispatched actions are passed down from the Redux store to the connected components via `mapStateToProps` and `mapDispatchToProps`, respectively.

Take, for example, the following React component:

```javascript
// app.js

var React = require('react');

var App = React.createClass({
	render: function() {
		return (
			<div>Hello there!</div>
		)
	}
});

module.exports = App;
```

...and it's associated connected component:

```javascript
// connected_app.js

var React = require('react');
var ReactRedux = require('react-redux');
var App = require('./app.js');
var actions = require('../actions/actions.js');

var mapStateToProps = function(state) {
	{
		items: state.items
	}
}

var mapDispatchToProps = function(dispatch) {
	return {
		dispatchAddItem: function() {
			dispatch(actions.addItem());
		}
	}
}

var ConnectedApp = ReactRedux.connect(mapStateToProps, mapDispatchToProps)(App);

module.exports = ConnectedApp;
```

The `<Provider>` component provided by ReactRedux is the gateway by which the Redux store can be accessed by an app's components.  Therefore, when testing a connected component, make sure to wrap the component in a `<Provider>` component:

```javascript
// connected_app_spec.js

var React = require('react');
var Provider = require('react-redux').Provider;
var configureMockStore = require('redux-mock-store');
var App = require('../../js/components/app.js');
var ConnectedApp = require('../../js/components/connected_app.js');
var TestUtils = require('react-test-utils');

describe('ConnectedApp', function() {
	var mockStore = configureMockStore();
	var connectedApp, store, initialItems;
	
	beforeEach(function() {
		initialItems = ['one'];
		var initialState = {
			items: initialItems
		}
		store = mockStore(initialState);
	});
	
	describe('state provided by the store', function() {
		beforeEach(function() {
			connectedApp = TestUtils.renderIntoDocument(<Provider store={store}><ConnectedApp/></Provider>);
		});
		
		...
	});
});
```  

Note that we are leveraging Redux's mock store because a store is needed to for the `ReactRedux.connect` magic to happen between the connected (smart) component and the non-connected (dumb) component.

And now for the assertions...

```javascript
// connected_app_spec.js

var React = require('react');
var Provider = require('react-redux').Provider;
var configureMockStore = require('redux-mock-store');
var actions = require('../../js/actions/actions.js');
var App = require('../../js/components/app.js');
var ConnectedApp = require('../../js/components/connected_app.js');
var TestUtils = require('react-addons-test-utils');

describe('ConnectedApp', function() {
	var mockStore = configureMockStore();
	var connectedApp, store, initialItems;
	
	beforeEach(function() {
		initialItems = ['one'];
		var initialState = {
			items: initialItems
		};
		store = mockStore(initialState);
	});
	
	describe('state provided by the store', function() {
		beforeEach(function() {
			connectedApp = TestUtils.renderIntoDocument(<Provider store={store}><ConnectedApp/></Provider>);
		});
		
		it('passes down items', function() {
			app = TestUtils.findRenderedComponentWithType(connectedApp, App);
			expect(app.props.items).toEqual(initialItems);
		});
	});
});
```

Let's pause here.  Pay attention to the component that we rendered into the document vs. the component that we make assertions on.  __The component that we render is the connected component, while the component that we assert on is the dumb component.__ Don't make the mistake of asserting on the ConnectedApp component, which is how you would usually test components.

Testing that the proper action dispatches are passed down is similar:

```javascript
// connected_app_spec.js

var React = require('react');
var Provider = require('react-redux').Provider;
var configureMockStore = require('redux-mock-store');
var actions = require('../../js/actions/action.js');
var App = require('../../js/components/app.js');
var ConnectedApp = require('../../js/components/connected_app.js');
var TestUtils = require('react-addons-test-utils');

describe('ConnectedApp', function() {
	var mockStore = configureMockStore();
	var connectedApp, app, store, initialItems;
	
	beforeEach(function() {
		initialItems = ['one'];
		var initialState = {
			items: initialItems
		};
		store = mockStore(initialState);
		
		connectedApp = TestUtils.renderIntoDocument(<Provider store={store}><ConnectedApp/></Provider>);
	});
	
	describe('actions passed down by the store', function() {
		var addItemValue;
		
		beforeEach(function() {
			addItemValue = jasmine.createSpyObj('addItemValue', ['type']);
			spyOn(actions, 'addItem').and.returnValue(addItemValue);
			spyOn(store, 'dispatch');
		});
		
		it('passes down the action to add an item', function() {
			app = TestUtils.findRenderedComponentWithType(connectedApp, App);
			app.props.dispatchAddItem();
			expect(store.dispatch).toHaveBeenCalledWith(addItemValue);
		});
	});
});
```

## <a name="actions">2.</a> Testing Actions
### Synchronous
Testing synchronous Actions (or officially, Action Creators) is easy because of the way Redux is designed.  Because the Actions are simply functions that return an object, there are no Redux-specific dependencies, making the tests straightforward.  For example, given an action creator like:

```javascript
// actions.js

function addOne() {
	return {
		type: 'ADD_ONE'
	}
}

module.exports = {
	addOne: addOne
	...
}
```

You can assert that the action returns the correct object:

```javascript
// actions_spec.js

describe('.addOne', function() {
	it('returns an object with the type of ADD_ONE', function() {
		expect(actions.addOne()).toEqual({
			type: 'ADD_ONE'
		});
	});
});
```

### Asynchronous
Testing asynchronous actions is a multi-step process.

1. Asserting that the right asynchronous function is called (e.g., an ajax request)
2. Asserting on the behavior after the asynchronous method is complete.


Compared to testing synchronous actions, testing asynchronous actions is bit trickier because they return a function, not an object.  The logic that we would be testing comes from invoking that function.  In addition, the implementation requires the presence of a store, and more specifically, its dispatch method.  For example:

```javascript
// actions.js

var axios = require('axios'); // axios is a promise-based HTTP client

function fetchData() {
	return function(dispatch) {
		return axios.get('http://www.example.com')
			.then(function(response) {
				dispatch(receiveData(response));
			});
	}
}

function receiveData(response) {
	return {
		type: 'RECEIVE_DATA',
		data: response
	}
}

module.exports = {
	fetchData: fetchData,
	receiveData: receiveData
	...
}
```

While the Redux docs suggest utilizing a mockStore via `configureMockStore` for unit testing actions, the only value it provides is ensuring that the appropriate middlewares (e.g., Thunk) have been added, which doesn't really need to be tested. Instead, we just need a stub in place of the actual dispatch method, and use it to invoke the result of calling the asynchronous action:

```javascript
// actions_spec.js

var axios = require('axios');

describe('.fetchData', function() {
	var dispatch,
	    deferred;
	
	beforeEach(function() {
		deferred = Q.defer();
		spyOn(axios, 'get').and.returnValue(deferred.promise);
		dispatch = jasmine.createSpy();	
	});
	
	it('makes an GET request', function() {
		fetchData()(dispatch);
		expect(axios.get).toHaveBeenCalledWith('http://www.example.com');
	});
});
```

To test the expected behavior after the asynchronous function is complete in the above example, I like to use Q library's deferred object because it simulates a Promise while giving the test writer complete control over when and how the asynchronous function resolves. I then use lodash's `defer` method to run the expectation only after the function within the `then` block has finished running:

```javascript
// actions_spec.js

var axios = require('axios');
var Q = require('q');
var _ = require('lodash');

describe('.fetchData', function() {
	var dispatch,
	    deferred;
	
	beforeEach(function() {
		deferred = Q.defer();
		spyOn(axios, 'get').and.returnValue(deferred.promise);
		dispatch = jasmine.createSpy();	
	});
	
	...
	
	describe('with a successful response', function() {
		it('dispatches receiveData', function(done) {
			fetchData()(dispatch);
			var response = jasmine.createSpyObj('response', ['data']);
			deferred.resolve(response);
			_.defer(function() {
				expect(dispatch).toHaveBeenCalledWith({
					type: 'RECEIVE_DATA',
					data: response
				});
				done();
			});
		});
	});
});

```


## <a name="reducers">3. </a> Testing Reducers

Testing reducers is also simple because their implementations in Redux are essentially switch/case statements.  The main things to test in a Reducer implementation are:

1. The initial state
2. How it handles each action type

For example, given the following action and reducer:

```javascript
// actions.js

function addItem(newItem) {
	return {
		type: 'ADD_ITEM',
		data: newItem
	}
}

module.exports = {
	addItem: addItem
	...
}
```

```javascript
// reducer.js

var _ = require('lodash');

var initialState = {
	items: []
};

function reducer(state, action) {
	if (typeof state === 'undefined') {
		return initialState;
	}
	
	switch(action.type) {
		case 'ADD_ITEM':
			return _.assign({}, state, {
				items: _.concat(state.items, action.data)
			}
		default:
			return state
	}
}

module.exports = reducer;
```

We can test for the expected initial state, and its handling of each action like:

```javascript
// reducer_spec.js

var reducer = require('../js/reducers/reducer.js');

describe('reducer', function() {
	describe('default', function() {
		it('returns the initial state', function() {
			expect(reducer()).toEqual({items: []});
		});
	});
	
	describe('on ADD_ITEM action', function() {
		var state;
		
		beforeEach(function() {
			state = {
				items: ['one']
			}
		});
		
		it('returns the state with the new item added', function() {
			expect(reducer(state, {type: 'ADD_ITEM', data: 'two'})).toEqual({items: ['one', 'two']});
		});
	});
});
```





