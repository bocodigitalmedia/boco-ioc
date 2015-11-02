IOC = require('./source').configure()
container = new IOC.Container
defineComponent = (key, properties) ->
  component = new IOC.Component properties
  container.components.set key, component

definitions =
  host:
    dependencies: null
    factory: (done) -> done null, "localhost"
  port:
    dependencies: null
    factory: (done) -> done null, 3000
  uri:
    dependencies: ["host", "port"]
    factory: (host, port, done) -> done null, "mongodb://#{host}:#{port}"

defineComponent key, properties for own key, properties of definitions

container.resolveComponent "uri", (error, result) ->
  console.error error.stack if error?
  console.log result if result
  process.exit (if error? then 1 else 0)
