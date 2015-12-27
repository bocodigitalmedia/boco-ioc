$files = {}

describe "boco-ioc", ->

  describe "Usage", ->
    [IOC, container, done, foo, bar] = []

    beforeEach ->
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

    describe "Resolving a Component", ->

      it "Given a component name, the container will resolve that component:", (ok) ->
        container.resolveComponent "foobar", (error, foobar) ->
          throw error if error?
          expect(foobar).toEqual "FOOBAR"
          ok()
