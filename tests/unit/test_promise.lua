local Promise = require("src.core.promise")

local function assert_equal(actual, expected, message)
  if actual ~= expected then
    error((message or "assert_equal failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
  end
end

local function test_resolve_chain()
  local promise = Promise.resolve(2):and_then(function(value)
    return value * 3
  end)

  local ok, result = promise:await(20)
  assert_equal(ok, true, "promise should resolve")
  assert_equal(result, 6, "resolved value should be transformed")
end

local function test_reject_and_catch()
  local promise = Promise.reject("boom")
    :catch(function(err)
      return "handled:" .. err
    end)

  local ok, result = promise:await(20)
  assert_equal(ok, true)
  assert_equal(result, "handled:boom")
end

local function test_finally_runs()
  local called = false
  local promise = Promise.resolve("ok"):finally(function()
    called = true
  end)

  local ok, result = promise:await(20)
  assert_equal(ok, true)
  assert_equal(result, "ok")
  assert_equal(called, true, "finally should be called")
end

return {
  { name = "promise resolve chain", run = test_resolve_chain },
  { name = "promise reject catch", run = test_reject_and_catch },
  { name = "promise finally", run = test_finally_runs },
}
