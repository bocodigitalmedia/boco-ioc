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
      @componentName = props.componentName
      @dependenciesNotDefined = props.dependenciesNotDefined
      super @getMessage()
      Error.captureStackTrace @, @constructor

    getMessage: ->
      "Component '#{@componentName}' " +
      "has undefined dependencies: [#{@dependenciesNotDefined}]"

  class IOC.ComponentNotAcyclic extends Error
    constructor: (props = {}) ->
      @name = @constructor.name
      @componentName = props.componentName
      @cycles = props.cycles
      @message = @getMessage()
      Error.captureStackTrace @, @constructor

    getMessage: ->
      message = "Component '#{@componentName}' has cycles:\n"
      @cycles.forEach (cycle) ->
        message += "*  #{cycle.join(' > ')}"
      message

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

      @createPromise (resolve, reject) =>
        component.resolve this, (error, result) ->
          return reject error if error?
          return resolve result

    ensureComponentPromise: (name) ->
      return if @componentPromises.isDefined name
      @componentPromises.set name, @createComponentPromise(name)

    getComponentDependenciesNotDefined: (name) ->
      component = @components.get name
      component.dependencies.filter @components.isUndefined.bind(@components)

    assertComponentDependenciesDefined: (name) ->
      dependenciesNotDefined = @getComponentDependenciesNotDefined name
      return if dependenciesNotDefined.length is 0

      throw new IOC.ComponentDependenciesNotDefined \
        componentName: name
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
        componentName: name
        cycles: cycles

    validateComponent: (name) ->
      return if @componentPromises.isDefined name
      @assertComponentDependenciesDefined name
      @assertComponentIsAcyclic name

    resolveComponent: (name, done) ->
      @validateComponent name
      @ensureComponentPromise name
      @componentPromises.get(name).then done.bind(null, null), done

  class IOC.Component
    asyncMap: $.asyncMap
    asyncWaterfall: $.asyncWaterfall

    constructor: (props = {}) ->
      @dependencies = props.dependencies ? []
      @factory = props.factory

    resolveDependencies: (container, done) ->
      resolveComponent = container.resolveComponent.bind container
      @asyncMap @dependencies, resolveComponent, done

    applyFactory: (args, done) ->
      @factory args..., done

    resolve: (container, done) ->
      series = Array \
        @resolveDependencies.bind(this, container),
        @applyFactory.bind this

      @asyncWaterfall series, done


  return IOC

module.exports = configure()
