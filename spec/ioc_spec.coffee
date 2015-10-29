describe "IOC", ->
  uuid = -> require('uuid').v4()
  createSpyObj = (args...) -> jasmine.createSpyObj args...

  mocks =
    component: (name = "component_#{uuid()}") -> createSpyObj name, ["resolve"]
    promise: (name = "promise_#{uuid()}") -> createSpyObj name, ["then"]

  IOC = null

  beforeEach ->
    IOC = require("../source").configure()

  describe "Container", ->
    [components, resolutions, container] = []

    beforeEach ->
      components = new IOC.Dictionary
      resolutions = new IOC.Dictionary
      container = new IOC.Container components: components, resolutions: resolutions

    describe "setting components", ->
      [componentName, component] = []

      beforeEach ->
        componentName = uuid()
        component = mocks.component()
        spyOn(components, "set").and.callThrough()

      it "stores the component using the name as a key", ->
        container.setComponent componentName, component
        expect(components.set).toHaveBeenCalledWith componentName, component

    describe "resolving a component", ->
      [componentName, component, resolution, resolutionResult] = []

      beforeEach ->
        resolution = mocks.promise()
        resolutionResult = uuid()
        resolution.then.and.callFake (success) -> success resolutionResult

        componentName = uuid()
        component = mocks.component()
        component.resolve.and.returnValue resolution

        components.set componentName, component
        spyOn(resolutions, 'set').and.callThrough()

      describe "when it has not yet been resolved", ->

        beforeEach ->
          resolutions.set componentName, undefined

        it "resolves the component", (done) ->
          container.resolveComponent componentName, (error) ->
            return done error if error?
            expect(component.resolve).toHaveBeenCalledWith container
            done()

        it "stores the resolution promise", (done) ->
          container.resolveComponent componentName, (error) ->
            return done error if error?
            expect(resolutions.set).toHaveBeenCalledWith componentName, resolution
            done()

        it "proxies the resolution promise result to the callback", (done) ->
          container.resolveComponent componentName, (error, result) ->
            return done error if error?
            expect(result).toEqual resolutionResult
            done()

      describe "when it has already been resolved", ->

        beforeEach ->
          resolutions.set componentName, resolution

        it "proxies the resolution promise result to the callback", (done) ->
          container.resolveComponent componentName, (error, result) ->
            return done error if error?
            expect(result).toEqual resolutionResult
            done()

      describe "when the promise returns an error", ->
        [resolutionError] = []

        beforeEach ->
          resolutionError = uuid()
          resolution.then.and.callFake (success, failure) -> failure resolutionError

        it "proxies the error to the callback", (done) ->
          container.resolveComponent componentName, (error, result) ->
            expect(error).toEqual resolutionError
            done()

  describe "Component", ->

    describe "resolving", ->
