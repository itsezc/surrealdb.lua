# surrealdb.lua

SurrealDB client SDK for Lua and Luau (Roblox), with a shared core for any Lua app, with runtime adapters for FiveM and Roblox.

## Features

- SurrealDB v3 JSON-RPC
- Dual async API via Promises or Callbacks
- Error normalization
- Game server ready: FiveM or Roblox

## Examples

- `examples/fivem` FiveM resource example
- `examples/roblox` Roblox server example

## Public API

Create a client:

```lua
local Surreal = require("src")

local client = Surreal.new_client({
  url = "http://127.0.0.1:8000",
  adapter = my_adapter,
  namespace = "app", -- optional
  database = "main", -- optional
  token = nil,         -- optional
  timeout_ms = 5000,   -- optional
})
```

Methods (`method(..., cb?) -> Promise`):

- `rpc(method, params, cb?)`
- `ping`, `version`, `info`
- `sign_in`, `sign_up`, `authenticate`, `invalidate`
- `use`, `query`
- `select`, `insert`, `insert_relation`, `create`, `upsert`, `update`, `merge`, `patch`, `delete`, `relate`, `run`
- `set_token`, `get_token`

`sign_in` / `sign_up` credentials use `user` / `pass` for SurrealDB v3 RPC.

## Running tests

Unit tests:

```bash
lua tests/run.lua
```

Integration test with Docker (starts SurrealDB container, runs live checks, then cleans up):

```bash
./tests/integration/docker.sh
```

By default this runner uses `--unauthenticated` mode for deterministic CRUD coverage.
To force auth/sign-in coverage:

```bash
SURREAL_AUTH_MODE=authenticated ./tests/integration/docker.sh
```

Environment variables for integration tests:

- `SURREAL_HOST_PORT` (default `18000`, used by Docker runner publish mapping)
- `SURREAL_URL` (default `http://127.0.0.1:18000`)
- `SURREAL_NS` (default `sdk`)
- `SURREAL_DB` (default `test`)
- `SURREAL_USER` (default `root`)
- `SURREAL_PASS` (default `secret`)
- `SURREAL_AUTH_MODE` (`unauthenticated` or `authenticated`, default `unauthenticated`)
