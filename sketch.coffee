IOC = require('./source').configure()
container = new IOC.Container

defineComponent = (key, properties) ->
  component = new IOC.Component
    dependencies: properties.dependencies
    factory: properties.factory
  container.components.set key, component

value = (val) ->
  factory: (done) -> done null, val

async = (dependencies, factory) ->
  dependencies: dependencies
  factory: factory

ctor = (dependencies, ctor) ->
  dependencies: dependencies
  factory: (args..., done) ->
    try done null, new (ctor.bind(null, args...))
    catch error then done error

sync = (dependencies, factory) ->
  dependencies: dependencies
  factory: (args..., done) ->
    try done null, factory(args...)
    catch error then done error

auto = (fn) ->
  pattern = /\(([^)]*)\)/
  fnArgs = fn.toString().match(pattern)[1].split(/,\s*/)
  lastArg = fnArgs[fnArgs.length-1]
  isAsync = lastArg in ["done", "callback", "cb", "next"]
  isConstructor = /[A-Z]/.test fn.name[0]
  return async fnArgs[0...-1], fn if isAsync
  return ctor fnArgs, fn if isConstructor
  return sync fnArgs, fn

class MyClass
  constructor: (mongodb, uri) ->
    @mongodb = mongodb
    @uri = uri

mongoURIFactory = (host, port) -> "mongodb://#{host}:#{port}"
mongoConnectionFactory = ($require, uri, done) -> $require("mongodb").connect uri, done

definitions =
  $require: value require
  host: value "localhost"
  port: value 27017
  uri: auto mongoURIFactory
  mongodb: auto mongoConnectionFactory
  myClass: auto MyClass

defineComponent key, properties for own key, properties of definitions

container.resolveComponent "myClass", (error, result) ->
  console.error error.stack if error?
  console.log container.components.getParentsOf "uri"
  defineComponent "uri", value "localhost"
  console.log container.promises.definitions
