# boco-ioc

![npm version](https://img.shields.io/npm/v/boco-ioc.svg)
![npm license](https://img.shields.io/npm/l/boco-ioc.svg)
![dependencies](https://david-dm.org/bocodigitalmedia/boco-ioc.png)

Inversion of Control & Dependency Injection for javascript.

* Highly configurable
* Supports asynchronous dependencies
* Lazy-loads dependencies
* Automatically maintains dependency cache

## Installation

Installation is available via [npm]

```sh
$ npm install boco-ioc
```

## Usage

Create a container, then define some components:

```coffee
IOC = require 'boco-ioc'
container = new IOC.Container

# You can define components using a properties hash
container.defineComponent "foo",
  dependencies: null
  factory: (done) -> done null, "FOO"

# Or pass in the dependencies and factory as arguments
container.defineComponent "bar", null, (done) ->
  done null, "BAR"

# Or determine the dependencies automatically
container.defineComponent "foobar", (foo, bar, done) ->
  done null, foo + bar
```

### Resolving a Component

Given a component name, the container will resolve that component:

```coffee
container.resolveComponent "foobar", (error, foobar) ->
  throw error if error?
  expect(foobar).toEqual "FOOBAR"
  ok()
```

[npm]: http://npmjs.org
