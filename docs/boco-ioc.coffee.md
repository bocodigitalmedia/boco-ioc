# boco-ioc

![npm version](https://img.shields.io/npm/v/boco-ioc.svg)
![npm license](https://img.shields.io/npm/l/boco-ioc.svg)
![dependencies](https://david-dm.org/bocodigitalmedia/boco-ioc.png)

Inversion of Control & Dependency Injection for javascript.

* Highly configurable
* Supports asynchronous dependency factories as well as promises
* Lazy-loads dependencies
* Automatically maintains dependency cache

## Installation

Installation is available via [npm]

```sh
$ npm install boco-ioc
```

## Usage

```coffee
IOC = require 'boco-ioc'
Promise = require 'bluebird'

# Create a container
container = new IOC.Container

# define a component with a synchronous factory
container.defineComponent 'foo',
  factory: -> 'Foo'

# define a component with an asynchronous factory (callback)
container.defineComponent 'bar',
  factory: (done) -> done null, 'Bar'

# define a component by returning a promise from your factory
# note: you must set the `factoryType` to 'promise'
container.defineComponent 'baz',
  factoryType: 'promise'
  factory: -> Promise.resolve 'Baz'

# any string value can be used as your component id
container.defineComponent 'qux/value',
  factory: -> 'Qux'

# an array of dependencies gets injected as ordered arguments
container.defineComponent 'joined/foo+bar',
  depends: ['foo', 'bar']
  factory: (foo, bar) -> foo + bar

# a dependency map gets injected as a single object
container.defineComponent 'joined/bar+baz',
  dependencies:
    bar: true
    baz: true
  factory: ({bar, baz}, done) -> done null, bar + baz

# you can specify the id of your components in a dependency map
container.defineComponent 'joined/baz+qux',
  dependencies:
    baz: true
    qux: 'qux/value'
  factoryType: 'promise'
  factory: ({baz, qux}) -> Promise.resolve baz + qux
```

### Resolving a Component

Given a component name, the container will resolve that component:

```coffee
container.defineComponent 'joined/all',
  dependencies:
    fooBar: 'joined/foo+bar'
    barBaz: 'joined/bar+baz'
    bazQux: 'joined/baz+qux'
  factory: ({fooBar, barBaz, bazQux}) ->
    fooBar + barBaz + bazQux

container.resolveComponent 'joined/all', (error, result) ->
  throw error if error?
  expect(result).toEqual 'FooBarBarBazBazQux'
  ok()
```
### Loading Components

Load all components from a given directory. The relative path name will be used as the component id.

```coffee
Path = require 'path'

loader = new IOC.ComponentLoader
componentsDir = './components'
pattern = '**/*(*.coffee)'

loader.load {container, componentsDir, pattern}

container.resolveComponent 'examples/one', (error, result) ->
  throw error if error?
  expect(result).toEqual 1
```

[npm]: http://npmjs.org
