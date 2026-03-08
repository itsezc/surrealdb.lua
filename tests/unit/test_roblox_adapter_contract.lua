local function assert_contains(haystack, needle, label)
  if not haystack:find(needle, 1, true) then
    error("expected roblox adapter to contain " .. label)
  end
end

local function test_roblox_adapter_contract()
  local file = io.open("src/roblox/adapter.luau", "r")
  if not file then
    error("missing src/roblox/adapter.luau")
  end

  local content = file:read("*a")
  file:close()

  assert_contains(content, "HttpService:RequestAsync", "RequestAsync transport call")
  assert_contains(content, "pcall", "pcall protection")
  assert_contains(content, "status = result.StatusCode", "status mapping")
end

return {
  { name = "roblox adapter contract", run = test_roblox_adapter_contract },
}
