local Core = require("src.core.client")

local function assert_equal(actual, expected, message)
  if actual ~= expected then
    error((message or "assert_equal failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
  end
end

local function assert_truthy(value, message)
  if not value then
    error(message or "assert_truthy failed")
  end
end

local function make_fixture()
  local fixture = {}
  fixture.decode_map = {}

  fixture.json = {
    encode = function(value)
      fixture.last_encoded = value
      return "encoded"
    end,
    decode = function(body)
      local value = fixture.decode_map[body]
      if value == nil then
        error("missing decode map for body: " .. tostring(body))
      end
      return value
    end,
  }

  fixture.adapter = {
    request = function(options, callback)
      fixture.last_request = options
      callback(fixture.transport_err, fixture.response)
    end,
  }

  fixture.response = {
    status = 200,
    body = "ok",
    headers = {},
  }

  fixture.decode_map.ok = { result = { ok = true } }

  local client = Core.new_client({
    url = "http://127.0.0.1:8000",
    namespace = "app",
    database = "main",
    adapter = fixture.adapter,
  })
  client._json = fixture.json

  return fixture, client
end

local function test_request_envelope_and_headers()
  local fixture, client = make_fixture()

  local ok, result = client:ping():await(20)
  assert_equal(ok, true)
  assert_truthy(result.ok)

  assert_equal(fixture.last_request.url, "http://127.0.0.1:8000/rpc")
  assert_equal(fixture.last_request.method, "POST")
  assert_equal(fixture.last_request.headers["Content-Type"], "application/json")
  assert_equal(fixture.last_request.headers["Surreal-NS"], "app")
  assert_equal(fixture.last_request.headers["Surreal-DB"], "main")

  assert_equal(fixture.last_encoded.method, "ping")
  assert_equal(type(fixture.last_encoded.id), "number")
end

local function test_callback_bridge()
  local fixture, client = make_fixture()
  fixture.decode_map.ok = { result = { rows = 1 } }

  local called = false
  local promise = client:query("SELECT * FROM user", {}, function(err, res)
    assert_equal(err, nil)
    assert_equal(res.rows, 1)
    called = true
  end)

  local ok = promise:await(20)
  assert_equal(ok, true)
  assert_equal(called, true, "callback should be called")
end

local function test_query_omits_empty_vars()
  local fixture, client = make_fixture()
  fixture.decode_map.ok = { result = { ok = true } }

  local ok = client:query("DEFINE TABLE people SCHEMALESS;"):await(20)
  assert_equal(ok, true)
  assert_equal(fixture.last_encoded.method, "query")
  assert_equal(#fixture.last_encoded.params, 1)
  assert_equal(fixture.last_encoded.params[1], "DEFINE TABLE people SCHEMALESS;")
end

local function test_relate_uses_v3_param_shape()
  local fixture, client = make_fixture()
  fixture.decode_map.ok = { result = true }

  local ok = client:relate("person:one->knows->person:two", { since = "2026-01-01" }):await(20)
  assert_equal(ok, true)
  assert_equal(fixture.last_encoded.method, "relate")
  assert_equal(#fixture.last_encoded.params, 4)
  assert_equal(fixture.last_encoded.params[1], "person:one")
  assert_equal(fixture.last_encoded.params[2], "knows")
  assert_equal(fixture.last_encoded.params[3], "person:two")
  assert_equal(fixture.last_encoded.params[4].since, "2026-01-01")
end

local function test_rpc_error_normalization()
  local fixture, client = make_fixture()
  fixture.response = { status = 200, body = "rpc_err", headers = {} }
  fixture.decode_map.rpc_err = {
    error = {
      code = 403,
      message = "unauthorized",
    },
  }

  local ok, err = client:ping():await(20)
  assert_equal(ok, false)
  assert_equal(err.kind, "auth_error")
  assert_equal(err.code, 403)
end

local function test_http_decode_transport_errors()
  local fixture, client = make_fixture()

  fixture.response = { status = 500, body = "server boom", headers = {} }
  local ok_http, err_http = client:ping():await(20)
  assert_equal(ok_http, false)
  assert_equal(err_http.kind, "http_error")

  fixture.response = { status = 200, body = "missing", headers = {} }
  local ok_decode, err_decode = client:ping():await(20)
  assert_equal(ok_decode, false)
  assert_equal(err_decode.kind, "decode_error")

  fixture.transport_err = "network down"
  local ok_transport, err_transport = client:ping():await(20)
  assert_equal(ok_transport, false)
  assert_equal(err_transport.kind, "transport_error")
end

local function test_auth_and_state_transitions()
  local fixture, client = make_fixture()

  fixture.decode_map.signin = { result = "jwt-1" }
  fixture.response = { status = 200, body = "signin", headers = {} }
  local ok_signin = client:sign_in({ user = "root", pass = "root" }):await(20)
  assert_equal(ok_signin, true)
  assert_equal(client:get_token(), "jwt-1")

  fixture.decode_map.authn = { result = true }
  fixture.response = { status = 200, body = "authn", headers = {} }
  local ok_authn = client:authenticate("jwt-2"):await(20)
  assert_equal(ok_authn, true)
  assert_equal(client:get_token(), "jwt-2")

  fixture.decode_map.use = { result = true }
  fixture.response = { status = 200, body = "use", headers = {} }
  local ok_use = client:use("new_ns", "new_db"):await(20)
  assert_equal(ok_use, true)

  fixture.decode_map.ping2 = { result = { ok = true } }
  fixture.response = { status = 200, body = "ping2", headers = {} }
  local ok_ping2 = client:ping():await(20)
  assert_equal(ok_ping2, true)
  assert_equal(fixture.last_request.headers["Surreal-NS"], "new_ns")
  assert_equal(fixture.last_request.headers["Surreal-DB"], "new_db")
  assert_equal(fixture.last_request.headers["Authorization"], "Bearer jwt-2")

  fixture.decode_map.invalidate = { result = true }
  fixture.response = { status = 200, body = "invalidate", headers = {} }
  local ok_invalidate = client:invalidate():await(20)
  assert_equal(ok_invalidate, true)
  assert_equal(client:get_token(), nil)
end

local function test_unsupported_methods()
  local _, client = make_fixture()

  local ok_live, err_live = client:live():await(20)
  assert_equal(ok_live, false)
  assert_equal(err_live.kind, "not_supported")

  local ok_rpc, err_rpc = client:rpc("kill", { "123" }):await(20)
  assert_equal(ok_rpc, false)
  assert_equal(err_rpc.kind, "not_supported")
end

return {
  { name = "client request envelope", run = test_request_envelope_and_headers },
  { name = "client callback bridge", run = test_callback_bridge },
  { name = "client query omits empty vars", run = test_query_omits_empty_vars },
  { name = "client relate uses v3 param shape", run = test_relate_uses_v3_param_shape },
  { name = "client rpc error normalization", run = test_rpc_error_normalization },
  { name = "client http/decode/transport errors", run = test_http_decode_transport_errors },
  { name = "client auth transitions", run = test_auth_and_state_transitions },
  { name = "client unsupported methods", run = test_unsupported_methods },
}
