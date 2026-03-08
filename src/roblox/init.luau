--!strict

local Core = require(script.Parent.Parent.core.client)
local Adapter = require(script.Parent.adapter)

export type Config = {
  url: string,
  namespace: string?,
  database: string?,
  token: string?,
  timeout_ms: number?,
  adapter: any?,
}

local Module = {}

function Module.new_client(config: Config)
  local resolved_config = config or ({} :: any)

  local merged = {
    url = resolved_config.url,
    namespace = resolved_config.namespace,
    database = resolved_config.database,
    token = resolved_config.token,
    timeout_ms = resolved_config.timeout_ms,
    adapter = resolved_config.adapter or Adapter,
  }

  return Core.new_client(merged)
end

return Module
