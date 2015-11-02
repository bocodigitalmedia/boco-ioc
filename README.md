
# IOC

Inversion of Control & Dependency Injection for javascript.

* Highly configurable
* Supports asynchronous dependencies
* Lazy-loads dependencies
* Automatically maintains dependency cache

# Usage

```coffee
IOC = require './source'
container = new IOC.Container
assert = require 'assert'

# You can define components using a properties hash
container.defineComponent "foo",
  dependencies: null
  factory: (done) -> done null, "FOO"

# Or pass in the dependencies and factory as arguments
container.defineComponent "bar", null, (done) ->
  done null, "BAR"

# Or determine the dependencies automatically
container.defineComponent "foobar", (foo, bar, done) ->
  done null, foo + bar

container.resolveComponent "foobar", (error, foobar) ->
  throw error if error?
  assert.equal foobar, "FOOBAR"
```

# License

The MIT License (MIT)

Copyright (c) [2015] [Christian Bradley]

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
