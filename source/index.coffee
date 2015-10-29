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

  class IOC.Dictionary
    constructor: (props = {}) ->
      @definitions = props.definitions ?= {}

    set: (name, value) ->
      @definitions[name] = value

    get: (name, value) ->
      @definitions[name]

    isDefined: (name) ->
      @definitions[name] != undefined

  class IOC.Container
    createPromise: $.createPromise

    constructor: (props = {}) ->
      @components = props.components ?= new IOC.Dictionary
      @resolutions = props.resolutions ?= new IOC.Dictionary

    setComponent: (name, component) ->
      @components.set name, component

    resolveComponent: (name, done) ->
      @resolutions.set name, @components.get(name).resolve(this) unless @resolutions.isDefined(name)
      @resolutions.get(name).then done.bind(null, null), done

  class IOC.Component

    createPromise: $.createPromise

    constructor: (props = {}) ->
      @injection = props.injection
      @factory = props.factory

    resolve: (container) ->
      @createPromise (resolve, reject) =>
        done = (error, result) -> if error? then resolve error else reject result
        @injection.inject container, @factory, done

    getDependencies: ->
      @injection.getDependencies()

  class IOC.Injection
    asyncMap: $.asyncMap
    asyncWaterfall: $.asyncWaterfall

    constructor: (props = {}) ->
      @dependencies = props.dependencies ? []
      @transformation = props.transformation

    getDependencies: ->
      @dependencies.slice()

    resolveDependencies: (container, done) ->
      resolveComponent = container.resolveComponent.bind container
      @asyncMap @dependencies, resolveComponent, done

    applyTransformation: (args, done) ->
      return done null, [] unless @transformation?
      return done null, @transformation args

    inject: (container, fn, done) ->
      series = Array \
        @resolveDependencies.bind(this, container),
        @applyTransformation.bind(this),
        (args, done) -> fn args..., done

      @asyncWaterfall series, done

  class IOC.DependencyGraph
    constructor: (props = {}) ->
      @components = props.components ? {}

    addComponent: (name, dependencies = []) ->
      @components[name] = dependencies

    validate: ->
      @assertComponentDependenciesDefined()
      @assertIsAcyclic()

  return IOC

module.exports = configure()
