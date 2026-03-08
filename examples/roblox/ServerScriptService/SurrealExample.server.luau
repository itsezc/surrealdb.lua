--!strict

local ServerStorage = game:GetService("ServerStorage")
local Surreal = require(ServerStorage.Packages.SurrealDB.roblox)

local client = Surreal.new_client({
  url = "http://127.0.0.1:8000",
  namespace = "game",
  database = "main",
})

client:sign_in({ user = "root", pass = "secret" })
  :and_then(function()
    return client:query("SELECT * FROM player LIMIT 1;")
  end)
  :and_then(function(rows)
    print("Promise query result", rows)
  end)
  :catch(function(err)
    warn("Promise error", err.kind, err.message)
  end)

client:query("SELECT * FROM player LIMIT 1;", {}, function(err, rows)
  if err then
    warn("Callback error", err.kind, err.message)
    return
  end

  print("Callback query result", rows)
end)
