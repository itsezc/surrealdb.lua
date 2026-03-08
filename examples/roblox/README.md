# Roblox

Place the SDK modules under `ServerStorage/Packages/SurrealDB` so this path works:

```luau
local Surreal = require(game.ServerStorage.Packages.SurrealDB.roblox)
```

Package shape:

- `SurrealDB/roblox` (ModuleScript from `src/roblox.luau`)
- `SurrealDB/roblox/init` (ModuleScript from `src/roblox/init.luau`)
- `SurrealDB/roblox/adapter` (ModuleScript from `src/roblox/adapter.luau`)
- `SurrealDB/core/client` (ModuleScript from `src/core/client.lua`)
- `SurrealDB/core/promise` (ModuleScript from `src/core/promise.lua`)
- `SurrealDB/core/errors` (ModuleScript from `src/core/errors.lua`)
- `SurrealDB/core/json` (ModuleScript from `src/core/json.lua`)
- `SurrealDB/vendor/dkjson` (ModuleScript from `src/vendor/dkjson.lua`)
