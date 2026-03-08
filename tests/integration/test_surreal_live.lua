local Core = require("src.core.client")
local Adapter = require("tests.integration.curl_adapter")

local function env(name, fallback)
  local value = os.getenv(name)
  if value == nil or value == "" then
    return fallback
  end
  return value
end

local function fail(message)
  io.stderr:write("[integration] " .. message .. "\n")
  os.exit(1)
end

local function expect_ok(ok, value, context)
  if not ok then
    local err = value
    local details = err and (err.kind .. ": " .. tostring(err.message)) or tostring(value)
    fail(context .. " failed: " .. details)
  end
  return value
end

local function main()
  local url = env("SURREAL_URL", "http://127.0.0.1:18000")
  local ns = env("SURREAL_NS", "sdk")
  local db = env("SURREAL_DB", "test")
  local user = env("SURREAL_USER", "root")
  local pass = env("SURREAL_PASS", "secret")
  local require_signin = env("SURREAL_REQUIRE_SIGNIN", "0") == "1"

  local client = Core.new_client({
    url = url,
    adapter = Adapter,
  })

  if require_signin then
    local ok, result = client:sign_in({ user = user, pass = pass }):await(5000)
    expect_ok(ok, result, "sign_in")
  end

  do
    local ok, result = client:use(ns, db):await(5000)
    expect_ok(ok, result, "use")
  end

  do
    local ok, result = client:query("DEFINE TABLE people SCHEMALESS;"):await(5000)
    expect_ok(ok, result, "define table")
  end

  do
    local ok, result = client:create("people:ada", { name = "Ada", role = "engineer" }):await(5000)
    expect_ok(ok, result, "create")
  end

  do
    local ok, result = client:merge("people:ada", { role = "principal" }):await(5000)
    expect_ok(ok, result, "merge")
  end

  do
    local ok, result = client:select("people:ada"):await(5000)
    expect_ok(ok, result, "select")
  end

  do
    local ok, result = client:query("CREATE person:one; CREATE person:two;"):await(5000)
    expect_ok(ok, result, "seed relation endpoints")
  end

  do
    local ok, result = client:relate("person:one->knows->person:two", { since = "2026-01-01" }):await(5000)
    expect_ok(ok, result, "relate")
  end

  do
    local ok, result = client:delete("people:ada"):await(5000)
    expect_ok(ok, result, "delete")
  end

  io.write("[integration] all live checks passed\n")
end

main()
