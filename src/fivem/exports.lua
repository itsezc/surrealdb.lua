local Exporter = {}

local DEFAULT_METHODS = {
  "rpc",
  "ping",
  "version",
  "info",
  "sign_in",
  "sign_up",
  "authenticate",
  "invalidate",
  "use",
  "query",
  "select",
  "insert",
  "insert_relation",
  "create",
  "upsert",
  "update",
  "merge",
  "patch",
  "delete",
  "relate",
  "run",
  "set_token",
  "get_token",
  "live",
  "kill",
  "let",
  "unset",
}

function Exporter.register_exports(client, methods)
  if type(exports) ~= "function" then
    error("FiveM exports() global is unavailable")
  end

  local list = methods or DEFAULT_METHODS
  for i = 1, #list do
    local name = list[i]
    exports(name, function(...)
      return client[name](client, ...)
    end)
  end
end

return Exporter
