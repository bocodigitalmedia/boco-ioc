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

  class IOC.Container
    createPromise: $.createPromise

    constructor: (props = {}) ->
      @components = props.components ? {}
      @promises = props.promises ? {}
      @validated = props.validated ? false

    defineComponent: (name, component) ->
      @components[name] = component
      @invalidate name

    invalidate: (name) ->
      @validated = false
      delete @promises[name]

    createComponentPromise: (name) ->
      component = @components[name]
      resolveComponent = component.resolve.bind component, this
      @createPromise (resolve, reject) ->
        proxyCallback = (error, result) -> if error? then reject error else resolve result
        resolveComponent proxyCallback

    resolveComponent: (name, done) ->
      promise = @promises[name] ?= @createComponentPromise name
      promise.then done.bind(null, null), done

  class IOC.Component

    constructor: (props = {}) ->
      @injection = IOC.constructInjection props.injection
      @factory = props.factory

    resolve: (container, done) ->
      @injection.inject container, @factory, done

  class IOC.Injection
    asyncMap: $.asyncMap
    asyncWaterfall: $.asyncWaterfall

    constructor: (props = {}) ->
      @dependencies = props.dependencies ? []
      @transformation = props.transformation

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

  return IOC

module.exports = configure()
