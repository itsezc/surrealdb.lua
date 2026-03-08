local Core = require("src.core.client")
local Json = require("src.core.json")

local Module = {}

function Module.new_client(config)
  config = config or {}

  local merged = {
    url = config.url,
    namespace = config.namespace,
    database = config.database,
    token = config.token,
    timeout_ms = config.timeout_ms,
    adapter = config.adapter,
  }

  return Core.new_client(merged)
end

Module.core = Core
Module.json = Json

return Module
