local Core = require("src.core.client")
local Adapter = require("src.fivem.adapter")
local Exporter = require("src.fivem.exports")

local Module = {}

function Module.new_client(config)
  config = config or {}

  local merged = {
    url = config.url,
    namespace = config.namespace,
    database = config.database,
    token = config.token,
    timeout_ms = config.timeout_ms,
    adapter = config.adapter or Adapter,
  }

  return Core.new_client(merged)
end

Module.register_exports = Exporter.register_exports

return Module
