local Surreal = require("src.fivem")

local client = Surreal.new_client({
  url = "http://127.0.0.1:8000",
  namespace = "game",
  database = "main",
})

-- Promise
client:sign_in({ user = "root", pass = "secret" })
  :and_then(function()
    return client:query("SELECT * FROM player LIMIT 1;")
  end)
  :and_then(function(rows)
    print("[surrealdb.lua] Promise query result:", json.encode(rows))
  end)
  :catch(function(err)
    print("[surrealdb.lua] Promise error:", err.kind, err.message)
  end)

-- Callback
client:query("SELECT * FROM player LIMIT 1;", {}, function(err, rows)
  if err then
    print("[surrealdb.lua] Callback error:", err.kind, err.message)
    return
  end

  print("[surrealdb.lua] Callback query result:", json.encode(rows))
end)

-- Surreal.register_exports(client)
