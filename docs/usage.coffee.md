
# Usage

    IOC = require './source'
    container = new IOC.Container
    assert = require 'assert'

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

    container.resolveComponent "foobar", (error, foobar) ->
      throw error if error?
      assert.equal foobar, "FOOBAR"
