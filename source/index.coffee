configure = (configuration) ->

  class Configuration
    constructor: (properties = {}) ->
      @[key] = val for own key,val of properties

    require: (name) ->
      require name

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
      Error.captureStackTrace @, @constructor

  class ComponentDependenciesUndefined extends CustomError
    componentName: undefined
    undefinedDependencies: undefined

    Object.defineProperty @prototype, "message", get: ->
      "Component '#{@componentName}' " +
      "has undefined dependencies: [#{@undefinedDependencies}]"

  class ComponentCyclic extends CustomError
    componentName: undefined
    cycles: undefined

    inspectCycles: ->
      mapFn = (cycle) -> "* #{cycle.join(" > ")}"
      @cycles.map(mapFn).join("\n")

    Object.defineProperty @prototype, "message", get: ->
      "Component '#{@componentName}' has cycles:\n" +
      @inspectCycles()

  class ComponentUndefined extends CustomError
    componentName: undefined

    Object.defineProperty @prototype, "message", get: ->
      "Component not defined: '#{@componentName}'"

  class Dictionary
    @definitions: undefined

    constructor: (properties = {}) ->
      @[key] = val for own key,val of properties
      @definitions ?= {}

    set: (name, value) ->
      @definitions[name] = value

    get: (name, value) ->
      @definitions[name]

    isDefined: (name) ->
      @definitions[name] != undefined

    isUndefined: (name) ->
      @definitions[name] == undefined

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
    components: undefined
    promises: undefined

    constructor: (properties = {}) ->
      @[key] = val for own key,val of properties

      @components ?= new Components
      @promises ?= new Promises

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
    dependencies: undefined
    factory: undefined

    constructor: (properties = {}) ->
      @[key] = val for own key,val of properties

      @dependencies ?= []
      @factory ?= null

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
    ComponentUndefined: ComponentUndefined
    ComponentDependenciesUndefined: ComponentDependenciesUndefined
    ComponentCyclic: ComponentCyclic
    Dictionary: Dictionary
    Components: Components
    Promises: Promises
    Container: Container
    Component: Component

module.exports = configure()
