local Module = {}

Module.new_client = require("src.core.client").new_client
Module.Promise = require("src.core.promise")
Module.Errors = require("src.core.errors")
Module.Json = require("src.core.json")

return Module
