configure = ($dependencies) ->
  IOC = {}
  IOC.configure = configure

  constructDependencies = (props = {}) ->
    $ = Object.create props

    $.createPromise ?= (resolver) ->
      require("when").promise resolver

    $.asyncMap ?= (array, mapFn, done) ->
      require("async").map array, mapFn, done

    $.asyncWaterfall ?= (series, done) ->
      require("async").waterfall series, done

    return $

  $ = constructDependencies $dependencies

  class IOC.ComponentDependenciesNotDefined extends Error
    constructor: (props = {}) ->
      @name = @constructor.name
      @component = props.component
      @dependenciesNotDefined = props.dependenciesNotDefined
      super @getMessage()
      Error.captureStackTrace @, @constructor

    getMessage: ->
      componentName = @component.name
      dependenciesNotDefined = @dependenciesNotDefined.join ", "
      "Component '#{componentName}' " +
      "has undefined dependencies: [#{dependenciesNotDefined}]"

  class IOC.ComponentNotAcyclic extends Error
    constructor: (props = {}) ->
      @name = @constructor.name
      @component = props.component
      @cycles = props.cycles
      super @getMessage()
      Error.captureStackTrace @, @constructor

    getMessage: ->
      componentName = @component.name
      cycles = @cycles.join ", "
      "Component '#{componentName}' is not acyclic.\n" +
      "Cycles: #{cycles}"

  class IOC.Dictionary
    constructor: (props = {}) ->
      @definitions = props.definitions ?= {}

    set: (name, value) ->
      @definitions[name] = value

    get: (name, value) ->
      @definitions[name]

    isDefined: (name) ->
      @definitions[name] != undefined

    isUndefined: (name) ->
      @definitions[name] == undefined

  class IOC.Container
    createPromise: $.createPromise

    constructor: (props = {}) ->
      @components = props.components ?= new IOC.Dictionary
      @componentPromises = props.componentPromises ?= new IOC.Dictionary

    createComponentPromise: (name) ->
      component = @components.get name
      resolveComponent = @resolveComponent.bind this

      @createPromise (resolve, reject) ->
        component.resolve resolveComponent, (error, result) ->
          return reject error if error?
          return resolve result

    ensureComponentPromise: (name) ->
      return if @componentPromises.isDefined name
      @componentPromises.set name, @createComponentPromise(name)

    getComponentDependenciesNotDefined: (name) ->
      component.dependencies.filter @components.isUndefined.bind(@components)

    assertComponentDependenciesDefined: (name) ->
      component = @components.get name
      dependenciesNotDefined = getComponentDependenciesNotDefined name
      return if dependenciesNotDefined.length is 0

      throw new IOC.ComponentDependenciesNotDefined \
        component: component
        dependenciesNotDefined: dependenciesNotDefined

    findComponentCycles: (name) ->
      stack = []
      cycles = []

      stackContains = (value) ->
        stack.some (name) -> name is value

      visitComponent = (name) =>
        return cycles.push(stack.concat(name)) if stackContains(name)
        stack.push name
        dependencies = @components.get(name).dependencies
        dependencies.forEach visitComponent
        stack.pop()

      visitComponent name
      return cycles

    assertComponentIsAcyclic: (name) ->
      cycles = @findComponentCycles name
      return if cycles.length is 0
      throw new IOC.ComponentNotAcyclic
        component: component
        cycles: cycles

    validateComponent: (name) ->
      return if @componentPromises.isDefined name
      assertComponentDependenciesDefined name
      assertComponentIsAcyclic name

    resolveComponent: (name, done) ->
      @ensureComponentPromise name
      @componentPromises.get(name).then done.bind(null, null), done

  class IOC.Component
    asyncMap: $.asyncMap
    asyncWaterfall: $.asyncWaterfall

    constructor: (props = {}) ->
      @dependencies = props.dependencies ? []
      @factory = props.factory

    resolveDependencies: (resolveComponent, done) ->
      @asyncMap @dependencies, resolveComponent, done

    applyFactory: (args, done) ->
      @factory args..., done

    resolve: (resolveComponent) ->
      series = Array \
        @resolveDependencies.bind this, resolveComponent
        @applyFactory.bind this

      @asyncWaterfall series, (error, result) ->
        return reject error if error?
        return resolve result

  return IOC

module.exports = configure()
