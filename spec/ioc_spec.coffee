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
      [componentName, component, resolution] = []

      beforeEach ->
        componentName = uuid()
        resolution = mocks.promise()
        component = mocks.component()

        components.set componentName, component
        spyOn(resolutions, 'set').and.callThrough()

      describe "when it not yet been resolved", ->
        beforeEach ->
          component.resolve.and.returnValue resolution
          resolutions.set componentName, undefined

        it "resolves the component", ->
          container.resolveComponent componentName
          expect(component.resolve).toHaveBeenCalledWith container

        it "stores and returns the resolution", ->
          result = container.resolveComponent componentName
          expect(resolutions.set).toHaveBeenCalledWith componentName, resolution
          expect(result).toEqual resolution

      describe "when it has already been resolved", ->

        beforeEach ->
          resolutions.set componentName, resolution

        it "returns the stored resolution", ->
          result = container.resolveComponent componentName
          expect(result).toEqual resolution

    describe "resolving", ->
      [componentName, resolution] = []

      beforeEach ->
        componentName = uuid()
        resolution = mocks.promise()
        resolution.then.and.callFake (success) -> success()
        spyOn(container, "resolveComponent").and.returnValue resolution

      it "resolves the component", (done) ->
        container.resolve componentName, (error, result) ->
          expect(container.resolveComponent).toHaveBeenCalledWith componentName
          done(error)

      it "proxies the resolution result on succes", (done) ->
        mockResult = uuid()
        resolution.then.and.callFake (success) -> success mockResult
        container.resolve componentName, (error, result) ->
          expect(result).toEqual mockResult
          done(error)

      it "proxies the resolution error on failure", (done) ->
        mockError = uuid()
        resolution.then.and.callFake (success, failure) -> failure mockError
        container.resolve componentName, (error, result) ->
          expect(error).toEqual mockError
          done()
