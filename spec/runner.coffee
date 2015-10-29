Jasmine = require 'jasmine'
jasmine = new Jasmine
jasmine.loadConfigFile 'spec/support/jasmine.json'
jasmine.execute()
