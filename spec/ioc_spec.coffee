describe "IOC", ->
  uuid = -> require('uuid').v4()
  createSpyObj = (args...) -> jasmine.createSpyObj args...

  spyObjects =
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

    describe "resolving a component", ->
      [componentName, component, resolution] = []

      beforeEach ->
        componentName = uuid()
        resolution = spyObjects.promise()
        component = spyObjects.component()

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
