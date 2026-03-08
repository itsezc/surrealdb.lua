local Errors = {}

local function as_string(value)
  if value == nil then
    return ""
  end
  if type(value) == "string" then
    return value
  end
  return tostring(value)
end

local function make(kind, code, message, raw)
  return {
    kind = kind,
    code = code,
    message = message,
    raw = raw,
  }
end

function Errors.transport_error(message, raw)
  return make("transport_error", "transport_error", as_string(message), raw)
end

function Errors.http_error(status, body, raw)
  return make("http_error", "http_" .. tostring(status), "HTTP request failed with status " .. tostring(status), {
    status = status,
    body = body,
    raw = raw,
  })
end

local function is_auth_code(code)
  if code == nil then
    return false
  end

  if type(code) == "string" then
    local lowered = code:lower()
    return lowered:find("auth", 1, true) ~= nil
  end

  if type(code) == "number" then
    return code == -32000 or code == 401 or code == 403
  end

  return false
end

function Errors.rpc_error(rpc_error)
  local code = rpc_error and rpc_error.code or "rpc_error"
  local message = rpc_error and rpc_error.message or "RPC request failed"
  local kind = is_auth_code(code) and "auth_error" or "rpc_error"

  return make(kind, code, as_string(message), rpc_error)
end

function Errors.auth_error(message, raw)
  return make("auth_error", "auth_error", as_string(message), raw)
end

function Errors.not_supported(method)
  return make("not_supported", "not_supported", "Method '" .. tostring(method) .. "' is not supported over HTTP in this SDK", {
    method = method,
  })
end

function Errors.decode_error(message, body, raw)
  return make("decode_error", "decode_error", as_string(message), {
    body = body,
    raw = raw,
  })
end

return Errors
