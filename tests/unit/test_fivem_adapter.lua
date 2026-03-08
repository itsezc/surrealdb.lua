local Adapter = require("src.fivem.adapter")

local function assert_equal(actual, expected, message)
  if actual ~= expected then
    error((message or "assert_equal failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
  end
end

local function test_perform_http_request_mapping()
  local captured = nil

  _G.PerformHttpRequest = function(url, cb, method, body, headers, options)
    captured = {
      url = url,
      method = method,
      body = body,
      headers = headers,
      options = options,
    }
    cb(200, "{\"result\":true}", { ["content-type"] = "application/json" }, nil)
  end

  local response_err = nil
  local response_value = nil

  Adapter.request({
    url = "http://127.0.0.1:8000/rpc",
    method = "POST",
    body = "{}",
    headers = { ["Content-Type"] = "application/json" },
    timeout_ms = 5000,
  }, function(err, response)
    response_err = err
    response_value = response
  end)

  assert_equal(response_err, nil)
  assert_equal(response_value.status, 200)
  assert_equal(response_value.body, "{\"result\":true}")
  assert_equal(captured.url, "http://127.0.0.1:8000/rpc")
  assert_equal(captured.options.timeout, 5000)

  _G.PerformHttpRequest = nil
end

return {
  { name = "fivem adapter maps PerformHttpRequest", run = test_perform_http_request_mapping },
}
