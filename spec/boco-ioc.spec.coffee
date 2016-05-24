$files = {}

describe "boco-ioc", ->

  describe "Usage", ->
    [IOC, Promise, container, done, foo, bar, baz, qux] = []

    beforeEach ->
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

    describe "Resolving a Component", ->

      it "Given a component name, the container will resolve that component:", (ok) ->
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
