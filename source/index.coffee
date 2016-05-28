configure = ({Async, Promise, Glob, Path, EventEmitter, promiseCallback} = {}) ->

  if typeof require is 'function'
    Async ?= require 'async'
    Promise ?= require 'bluebird'
    Glob ?= require 'glob'
    Path ?= require 'path'
    EventEmitter ?= require('events').EventEmitter

  promiseCallback ?= (promise, done) ->
    fn = if typeof promise.done is 'function' then 'done' else 'then'
    resolve = (args...) -> done null, args...
    reject = (error) -> done error
    promise[fn] resolve, reject

  class Exception extends Error
    name: null
    payload: null

    constructor: (payload) ->
      return new Exception payload unless @ instanceof Exception
      @payload = payload
      @name = @constructor.name
      Error.captureStackTrace @, @constructor

  class ComponentTimedOut extends Exception
    constructor: (payload) ->
      return new ComponentTimedOut payload unless @ instanceof ComponentTimedOut
      super payload
      @message = "Component '#{@payload.key}' timed out."

  class NotImplemented extends Exception
    constructor: (payload) ->
      return new NotImplemented payload unless @ instanceof NotImplemented
      super payload
      @message = "Not implemented."

  class ComponentAlreadyDefined extends Exception
    constructor: (payload) ->
      return new ComponentAlreadyDefined payload unless @ instanceof ComponentAlreadyDefined
      super payload
      @message = "Component already defined: '#{@payload.key}'."

  class ComponentNotDefined extends Exception
    constructor: (payload) ->
      return new ComponentNotDefined payload unless @ instanceof ComponentNotDefined
      super payload
      @message = "Component not defined: '#{@payload.key}'."

  class ComponentDependenciesNotDefined extends Exception
    constructor: (payload) ->
      return new ComponentDependenciesNotDefined payload unless @ instanceof ComponentDependenciesNotDefined
      super payload
      @message = "Component '#{@payload.key}' has undefined dependencies: #{@payload.dependencies.join(',')}."

  class ComponentNotAcyclic extends Exception
    constructor: (payload) ->
      return new ComponentNotAcyclic payload unless @ instanceof ComponentNotAcyclic
      super payload

      count = @payload.cycles.length
      cycles = @payload.cycles
        .map((cycle, index) -> "\t#{index}: #{cycle.join '/'}")
        .join "\n"

      @message = "Component '#{@payload.key}' has #{count} dependency cycle(s):\n#{cycles}"

  class Component
    key: null
    dependencies: null
    factory: null
    factoryType: null

    constructor: (props = {}) ->
      @key = props.key
      @factoryType = props.factoryType ? null
      @dependencies = props.dependencies ? null
      @factory = props.factory ? (injections..., done) ->
        return done NotImplemented() if typeof done is 'function'
        throw NotImplemented()

    getDependencyKeys: ->
      throw NotImplemented()

    guessFactoryType: ->
      'async'

    getFactoryType: ->
      @factoryType ? @guessFactoryType()

    injectPromiseFactory: (injections, done) ->
      @injectSyncFactory injections, (error, promise) ->
        return done error if error?
        promiseCallback promise, done

    injectAsyncFactory: (injections, done) ->
      return done NotImplemented() if typeof done is 'function'
      throw NotImplemented()

    injectSyncFactory: (injections, done) ->
      return done NotImplemented() if typeof done is 'function'
      throw NotImplemented()

    inject: (injections, done) ->

      switch @getFactoryType()
        when 'promise' then @injectPromiseFactory injections, done
        when 'async' then @injectAsyncFactory injections, done
        when 'sync' then @injectSyncFactory injections, done
        else throw Error("Cannot inject component, unknown factoryType: '#{@factoryType}'")

  class ComponentWithDependenciesArray extends Component

    getDependencyKeys: ->
      @dependencies ? []

    guessFactoryType: ->
      return 'sync' if @factory.length is @dependencies.length
      return 'async'

    injectAsyncFactory: (injections, done) ->
      try @factory injections..., done
      catch error then done error

    injectSyncFactory: (injections, done) ->
      try done null, @factory(injections...)
      catch error then done error

  class ComponentWithDependenciesObject extends Component

    getDependencyKeys: ->
      ({key, val} for own key, val of @dependencies).map ({key, val}) ->
        if typeof val is 'string' then val else key

    guessFactoryType: ->
      return 'sync' if @dependencies.length is 0 and @factory.length is 0
      return 'sync' if @factory.length is 1
      return 'async'

    createInjectionObject: (injections) ->
      collectInjections = (memo, key, index) ->
        memo[key] = injections[index]
        memo

      injectionKeys = (key for own key of @dependencies)
      injectionObject = injectionKeys.reduce collectInjections, {}

      injectionObject

    injectSyncFactory: (injections, done) ->
      injectionObject = @createInjectionObject injections

      try done null, @factory(injectionObject)
      catch error then done error

    injectAsyncFactory: (injections, done) ->
      injectionObject = @createInjectionObject injections

      try @factory injectionObject, done
      catch error then done error

  class ComponentWithoutDependencies extends Component
    getDependencyKeys: ->
      []

    guessFactoryType: ->
      return 'async' if @factory.length is 1
      return 'sync'

    injectAsyncFactory: (injections, done) ->
      try @factory done
      catch error then done error

    injectSyncFactory: (injections, done) ->
      try done null, @factory()
      catch error then done error

  class Container
    components: null
    promises: null
    componentFactory: null
    componentTimeout: null

    constructor: (props = {}) ->
      @components = props.components ? Object.create(null)
      @promises = props.promises ? Object.create(null)
      @componentFactory = props.componentFactory ? new ComponentFactory
      @componentTimeout = props.componentTimeout ? 30000
      @emitter = props.emitter ? new EventEmitter

    on: (args...) -> @emitter.on args...
    once: (args...) -> @emitter.once args...
    removeListener: (args...) -> @emitter.removeListener args...
    removeAllListeners: (args...) -> @emitter.removeAllListeners args...

    defineComponent: (key, args...) ->
      throw ComponentAlreadyDefined {key} if @components[key]?
      @components[key] = @componentFactory.construct args...
      delete @promises[key]

      @emitter.emit "component.defined",
        key: key
        container: @

    createComponentPromise: (key) ->
      @emitter.emit "component.resolving",
        key: key
        container: @

      new Promise (resolve, reject) =>

        done = (error, result) =>
          clearTimeout timeoutId if timeoutId?

          if error?
            reject error
            @emitter.emit 'component.error',
              key: key
              container: @
              error: error
          else
            resolve result
            @emitter.emit 'component.resolved',
              key: key
              container: @
              result: result

        timeoutId = setTimeout done.bind(null, ComponentTimedOut({key})), @componentTimeout
        component = @components[key]
        dependencyKeys = component.getDependencyKeys()

        Async.map dependencyKeys, @resolveComponent.bind(@), (error, injections) ->
          return done error if error?
          component.inject injections, done

    isComponentDefined: (key) ->
      @components[key]?

    assertComponentDefined: (key) ->
      throw ComponentNotDefined {key} unless @isComponentDefined(key)

    assertComponentDependenciesDefined: (key) ->
      component = @components[key]
      dependencies = component.getDependencyKeys().filter (key) => !@isComponentDefined(key)

      throw ComponentDependenciesNotDefined {key, dependencies} if dependencies.length

    getComponentCycles: (key, stack = []) ->
      return [stack.concat(key)] if key in stack

      component = @components[key]
      return [] unless component?

      stack = stack.concat key

      reduceDependencyCycles = (memo, key) =>
        memo.concat @getComponentCycles(key, stack)

      dependencyKeys = component.getDependencyKeys()
      dependencyKeys.reduce reduceDependencyCycles, []

    assertComponentAcyclic: (key) ->
      cycles = @getComponentCycles key
      throw ComponentNotAcyclic {key, cycles} if cycles.length

    validateComponent: (key) ->
      @assertComponentDefined key
      @assertComponentDependenciesDefined key
      @assertComponentAcyclic key

    validateComponents: ->
      @validateComponent key for own key of @components

    resolveComponent: (key, done) ->

      unless @promises[key]
        try @validateComponent key
        catch error then done error
        @promises[key] = @createComponentPromise key

      promiseCallback @promises[key], done

  class ComponentFactory

    construct: ({key, dependencies, depends, factory, factoryType}) ->
      dependencies ?= depends

      unless dependencies?
        return new ComponentWithoutDependencies {key, factory, factoryType}

      if Array.isArray dependencies
        return new ComponentWithDependenciesArray {key, dependencies, factory, factoryType}

      if typeof dependencies is 'object'
        return new ComponentWithDependenciesObject {key, dependencies, factory, factoryType}

      throw Error "Cannot construct component, invalid dependencies."

  class ComponentLoader

    load: ({container, componentsDir, pattern}) ->
      componentsDir ?= Path.resolve __dirname, "components"
      pattern ?= "**/*(*.coffee|*.js)"

      Glob.sync(pattern, cwd: componentsDir).forEach (componentPath) ->
        dirname = Path.dirname componentPath
        filename = Path.basename componentPath
        extname = Path.extname componentPath
        modname = do ->
          filename.slice 0, filename.length - extname.length

        key = if dirname is '.' then modname else Path.join(dirname, modname)
        definition = require Path.resolve(componentsDir, dirname, filename)
        container.defineComponent key, definition

  IOC = {
    configure,
    Container,
    ComponentFactory,
    Component,
    ComponentWithoutDependencies,
    ComponentWithDependenciesObject,
    ComponentWithDependenciesArray,
    Exception,
    NotImplemented,
    ComponentNotDefined,
    ComponentDependenciesNotDefined,
    ComponentNotAcyclic,
    ComponentAlreadyDefined
    ComponentLoader
  }

module.exports = configure()
