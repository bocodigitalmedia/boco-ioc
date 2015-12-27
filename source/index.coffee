configure = (configuration) ->

  class Configuration

    constructor: (props = {}) ->
      @[key] = val for own key,val of props

    require: (name) ->
      require name

    getFunctionArguments: (fn) ->
      pattern = /\(([^)]*)\)/
      fn.toString().match(pattern)[1].split /,\s*/

    isObject: (value) ->
      value? and typeof value is "object"

    isFunction: (value) ->
      typeof value is "function"

    isArray: (value) ->
      Array.isArray value

    isEmpty: (value) ->
      value? and value.length is 0

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

  class Exception extends Error
    name: undefined

    constructor: (props = {}) ->
      @[key] = val for own key,val of props
      @name = @constructor.name
      @message = @getMessage()
      Error.captureStackTrace @, @constructor

    getMessage: -> @constructor.name

  class NotImplemented extends Exception
    getMessage: -> "Abstract method not implemented."

  class StrategyNotFound extends Exception
    factory: undefined
    args: undefined

    getMessage: ->
      factory = @factory.constructor.name
      "No strategy found for factory '#{factory}' using arguments: [#{@args}]"

  class ComponentDependenciesUndefined extends Exception
    componentName: undefined
    undefinedDependencies: undefined

    getMessage: ->
      "Component '#{@componentName}' " +
      "has undefined dependencies: [#{@undefinedDependencies}]"

  class ComponentCyclic extends Exception
    componentName: undefined
    cycles: undefined

    getMessage: ->
      "Component '#{@componentName}' has #{@cycles.length} cycle(s): " +
      @inspectCycles()

    inspectCycles: ->
      mapFn = (cycle) => "['#{cycle.join("','")}']"
      @cycles.map(mapFn).join(", ")

  class ComponentUndefined extends Exception
    componentName: undefined

    getMessage: ->
      "Component not defined: '#{@componentName}'"

  class DictionaryEvent
    constructor: (props = {}) ->
      @name = @constructor.name
      @setPayload props.payload

    setPayload: (payload = {}) ->
      @payload = {}
      @payload.dictionary = payload.dictionary
      @payload.key = payload.key

  class DictionaryValueSet extends DictionaryEvent

  class DictionaryValueRemoved extends DictionaryEvent

  class Dictionary

    constructor: (props = {}) ->
      _emitter = props.eventEmitter ? $.createEventEmitter()

      @emit = (args...) -> _emitter.emit args...
      @addListener = (args...) -> _emitter.addListener args...
      @removeListener = (args...) -> _emitter.removeListener args...
      @removeAllListeners = (args...) -> _emitter.removeAllListeners args...

      _definitions = $.assign $.createObject(null), props.definitions

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

      @forEach = (callback) =>
        callback value, key, @ for own key, value of _definitions

    reduce: (reduceFn, memo) ->
      @forEach (value, key, target) -> memo = reduceFn memo, value, key, target
      memo

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
      return [stack.concat(name)] if stack.indexOf(name) isnt -1
      return [] unless @isDefined(name)
      stack = stack.concat name

      reduceDependencyCycles = (memo, dependency) =>
        memo.concat @getCycles(dependency, stack)

      dependencies = @get(name).dependencies
      dependencies.reduce reduceDependencyCycles, []

    getParentsOf: (dependee, parents = []) ->

      reduceParents = (parents, component, name) =>
        return parents if component.dependencies.indexOf(dependee) is -1
        return parents unless parents.indexOf(name) is -1
        @getParentsOf name, parents.concat(name)

      @reduce reduceParents, parents

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

    constructor: (props = {}) ->
      @componentFactory = props.componentFactory ? new ComponentFactory
      _components = new Components props.components
      _promises = new Promises props.promises

      _components.addListener "set", (event) =>
        @handleComponentChange event.payload.key

      _components.addListener "remove", (event) =>
        @handleComponentChange event.payload.key

      $.defineProperty @, "components", enumerable: true, get: -> _components
      $.defineProperty @, "promises", enumerable: true, get: -> _promises

    defineComponent: (name, args...) ->
      component = @componentFactory.construct args...
      @components.set name, component

    handleComponentChange: (key) ->
      @promises.remove key
      @components.getParentsOf(key).forEach (parent) =>
        @promises.remove parent

    createComponentPromise: (name) ->
      $.createPromise (resolve, reject) =>
        @components.get(name).resolve this, (error, result) ->
          return reject error if error?
          return resolve result

    ensureComponentPromiseSet: (name) ->
      return if @promises.isDefined name
      @promises.set name, @createComponentPromise(name)

    resolveComponent: (name, done) ->
      try
        @components.validate(name) unless @promises.isDefined(name)
        @ensureComponentPromiseSet(name)
        @promises.get(name).done done.bind(null, null), done
      catch error then done error

  class Component

    constructor: (props = {}) ->
      _dependencies = props.dependencies.slice() if props.dependencies != null
      _dependencies ?= []
      _factory = props.factory

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

  class Strategies
    constructor: (props = {}) ->
      @collection = props.collection ? []

    unshift: (strategy) ->
      @strategies.unshift strategy

    push: (strategy) ->
      @collection.push strategy

    find: (args...) ->
      reduceFn = (memo, strategy) ->
        return memo if memo?
        return strategy if strategy.test(args...)
      @collection.reduce reduceFn, null

  class Strategy
    test: -> throw new NotImplemented
    use: -> throw new NotImplemented

  class PropertiesStrategy extends Strategy
    test: (props, rest...) ->
      use = $.isEmpty(rest) and
            $.isObject(props) and
            $.isFunction(props.factory)

    constructComponent: (props) ->
      new Component props

    use: (props) ->
      @constructComponent props

  class ArgumentsStrategy extends Strategy
    test: (dependencies = [], factory, rest...) ->
      use = $.isEmpty(rest) and
            $.isArray(dependencies) and
            $.isFunction(factory)

    use: (dependencies = [], factory) ->
      new Component dependencies: dependencies, factory: factory

  class AutoFactoryStrategy extends Strategy
    test: (factory, rest...) ->
      use = $.isEmpty(rest) and
            $.isFunction(factory)

    use: (factory) ->
      dependencies = $.getFunctionArguments(factory)[0...-1]
      new Component dependencies: dependencies, factory: factory

  class ComponentFactory
    constructor: (props = {}) ->
      @strategies = props.strategies

      unless @strategies?
        @strategies = new Strategies
        @strategies.push new PropertiesStrategy
        @strategies.push new ArgumentsStrategy
        @strategies.push new AutoFactoryStrategy

    construct: (args...) ->
      strategy = @strategies.find args...
      throw new StrategyNotFound factory: this, args: args unless strategy?
      strategy.use args...

  $ = new Configuration configuration

  IOC =
    configuration: $
    configure: configure
    Configuration: Configuration
    Exception: Exception
    NotImplemented: NotImplemented
    StrategyNotFound: StrategyNotFound
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
    Strategies: Strategies
    Strategy: Strategy
    ComponentFactory: ComponentFactory
    PropertiesStrategy: PropertiesStrategy
    ArgumentsStrategy: ArgumentsStrategy

module.exports = configure()
