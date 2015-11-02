configure = (configuration) ->

  class Configuration

    constructor: (properties = {}) ->
      @[key] = val for own key,val of properties

    require: (name) ->
      require name

    assign: (target, sources...) ->
      sources.forEach (source) ->
        target[key] = value for own key, value of source
      return target

    createEventEmitter: ->
      new (@require("events").EventEmitter)

    createObject: (args...) ->
      Object.create args...

    defineProperty: (args...) ->
      Object.defineProperty args...

    defineProperties: (args...) ->
      Object.defineProperties args...

    createPromise: (resolver) ->
      @require("when").promise resolver

    asyncMap: (array, mapFn, done) ->
      @require("async").map array, mapFn, done

    asyncWaterfall: (series, done) ->
      @require("async").waterfall series, done

  class CustomError extends Error
    name: undefined

    constructor: (properties = {}) ->
      @[key] = val for own key,val of properties
      @name = @constructor.name
      @message = @getMessage()
      Error.captureStackTrace @, @constructor

    getMessage: -> @constructor.name

  class ComponentDependenciesUndefined extends CustomError
    componentName: undefined
    undefinedDependencies: undefined

    getMessage: ->
      "Component '#{@componentName}' " +
      "has undefined dependencies: [#{@undefinedDependencies}]"

  class ComponentCyclic extends CustomError
    componentName: undefined
    cycles: undefined

    getMessage: ->
      "Component '#{@componentName}' has cycles:\n" +
      @inspectCycles()

    inspectCycles: ->
      mapFn = (cycle) -> "* #{cycle.join(" > ")}"
      @cycles.map(mapFn).join("\n")

  class ComponentUndefined extends CustomError
    componentName: undefined

    getMessage: ->
      "Component not defined: '#{@componentName}'"

  class DictionaryEvent
    constructor: (properties = {}) ->
      @name = @constructor.name
      @setPayload properties.payload

    setPayload: (payload = {}) ->
      @payload = {}
      @payload.dictionary = payload.dictionary
      @payload.key = payload.key

  class DictionaryValueSet extends DictionaryEvent

  class DictionaryValueRemoved extends DictionaryEvent

  class Dictionary

    constructor: (properties = {}) ->
      _emitter = properties.eventEmitter ? $.createEventEmitter()

      @emit = (args...) -> _emitter.emit args...
      @addListener = (args...) -> _emitter.addListener args...
      @removeListener = (args...) -> _emitter.removeListener args...
      @removeAllListeners = (args...) -> _emitter.removeAllListeners args...

      _definitions = $.assign $.createObject(null), properties.definitions

      $.defineProperty @, "definitions", enumerable: true, get: ->
        $.assign {}, _definitions

      @get = (key) ->
        _definitions[key]

      @set = (key, value) ->
        result = _definitions[key] = value
        @emit "set", new DictionaryValueSet
          payload: { dictionary: @, key: key }
        return result

      @remove = (key) ->
        value = _definitions[key]
        result = delete _definitions[key]
        @emit "remove", new DictionaryValueRemoved
          payload: { dictionary: @, key: key }
        return result

    addListener: (args...) -> @emitter.addListener args...
    removeListener: (args...) -> @emitter.removeListener args...
    removeAllListeners: (args...) -> @emitter.removeAllListeners args...

    isDefined: (key) ->
      @get(key) != undefined

    isUndefined: (key) ->
      @get(key) == undefined

  class Components extends Dictionary

    getUndefinedDependencies: (name) ->
      @get(name).dependencies.filter @isUndefined.bind(@)

    getCycles: (name, stack = []) ->
      return stack.concat(name) if stack.indexOf(name) isnt -1
      return [] unless @isDefined(name)

      reduceDependencyCycles = (memo, dependency) =>
        cycles = @getCycles dependency, stack
        memo.push cycles if cycles.length isnt 0
        memo

      stack = stack.concat name
      dependencies = @get(name).dependencies
      dependencies.reduce reduceDependencyCycles, []

    assertDefined: (name) ->
      return if @isDefined(name)
      throw new ComponentUndefined
        componentName: name

    assertAcyclic: (name) ->
      cycles = @getCycles name
      return if cycles.length is 0
      throw new ComponentCyclic
        componentName: name
        cycles: cycles

    assertDependenciesDefined: (name) ->
      undefinedDependencies = @getUndefinedDependencies name
      return if undefinedDependencies.length is 0
      throw new ComponentDependenciesUndefined
        componentName: name
        undefinedDependencies: undefinedDependencies

    validate: (name) ->
      @assertDefined name
      @assertAcyclic name
      @assertDependenciesDefined name

  class Promises extends Dictionary

  class Container

    constructor: (properties = {}) ->
      @components = new Components properties.components
      @promises = new Promises properties.promises

      @components.addListener "set", (event) =>
        @promises.remove event.payload.key

      @components.addListener "remove", (event) =>
        @promises.remove event.payload.key

    createComponentPromise: (name) ->
      $.createPromise (resolve, reject) =>
        @components.get(name).resolve this, (error, result) ->
          return reject error if error?
          return resolve result

    ensureComponentPromiseSet: (name) ->
      return if @promises.isDefined name
      @promises.set name, @createComponentPromise(name)
      @promises.get name

    resolveComponent: (name, done) ->
      try
        @components.validate(name) unless @promises.isDefined(name)
        @ensureComponentPromiseSet(name).then done.bind(null, null), done
      catch error then done error

  class Component

    constructor: (properties = {}) ->
      _dependencies = properties.dependencies?.slice() ? []
      _factory = properties.factory

      $.defineProperties @,
        dependencies:
          enumerable: true, get: -> _dependencies.slice()
        factory:
          enumerable: true, get: -> _factory

    resolveDependencies: (container, done) ->
      resolveComponent = container.resolveComponent.bind container
      $.asyncMap @dependencies, resolveComponent, done

    applyFactory: (args, done) ->
      @factory args..., done

    resolve: (container, done) ->
      series = Array \
        @resolveDependencies.bind(this, container),
        @applyFactory.bind this

      $.asyncWaterfall series, done

  $ = new Configuration configuration

  IOC =
    configuration: $
    configure: configure
    Configuration: Configuration
    CustomError: CustomError
    ComponentCyclic: ComponentCyclic
    ComponentDependenciesUndefined: ComponentDependenciesUndefined
    ComponentUndefined: ComponentUndefined
    Component: Component
    Components: Components
    Container: Container
    Dictionary: Dictionary
    DictionaryEvent: DictionaryEvent
    DictionaryValueSet: DictionaryValueSet
    DictionaryValueRemoved: DictionaryValueRemoved
    Promises: Promises

module.exports = configure()
