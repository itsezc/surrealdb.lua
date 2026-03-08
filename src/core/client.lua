local Promise = require("src.core.promise")
local Errors = require("src.core.errors")
local DefaultJson = require("src.core.json")

local Client = {}
Client.__index = Client

local MODULE = {}

local UNSUPPORTED_METHODS = {
  live = true,
  kill = true,
  ["let"] = true,
  unset = true,
}

local function resolve_json()
  local fivem_json = rawget(_G, "json")
  if type(fivem_json) == "table" and type(fivem_json.encode) == "function" and type(fivem_json.decode) == "function" then
    return {
      encode = function(value)
        return fivem_json.encode(value)
      end,
      decode = function(text)
        return fivem_json.decode(text)
      end,
    }
  end

  local game_obj = rawget(_G, "game")
  if game_obj ~= nil then
    local ok, http_service = pcall(function()
      return game_obj:GetService("HttpService")
    end)
    if ok and http_service and type(http_service.JSONEncode) == "function" and type(http_service.JSONDecode) == "function" then
      return {
        encode = function(value)
          return http_service:JSONEncode(value)
        end,
        decode = function(text)
          return http_service:JSONDecode(text)
        end,
      }
    end
  end

  return DefaultJson
end

local function assert_config(config)
  if type(config) ~= "table" then
    error("new_client(config): config must be a table")
  end

  if type(config.url) ~= "string" or config.url == "" then
    error("new_client(config): config.url must be a non-empty string")
  end

  if type(config.adapter) ~= "table" or type(config.adapter.request) ~= "function" then
    error("new_client(config): config.adapter.request(options, callback) is required")
  end
end

local function trim_trailing_slash(url)
  if url:sub(-1) == "/" then
    return url:sub(1, -2)
  end
  return url
end

local function callbackify(promise, cb)
  if type(cb) ~= "function" then
    return promise
  end

  promise:and_then(function(result)
    cb(nil, result)
    return result
  end, function(err)
    cb(err, nil)
    return Promise.reject(err)
  end)

  return promise
end

local function as_params(params)
  if params == nil then
    return {}
  end

  if type(params) ~= "table" then
    return { params }
  end

  return params
end

local function extract_token(value)
  if type(value) == "string" then
    return value
  end

  if type(value) == "table" then
    if type(value.token) == "string" then
      return value.token
    end
    if type(value.jwt) == "string" then
      return value.jwt
    end
  end

  return nil
end

local function split_data_and_cb(data, cb, default_data)
  if type(data) == "function" and cb == nil then
    return default_data, data
  end
  return data, cb
end

local function is_empty_table(value)
  if type(value) ~= "table" then
    return false
  end
  return next(value) == nil
end

local function parse_relation_string(relation)
  if type(relation) ~= "string" then
    return nil, nil, nil
  end

  local from, kind, target = relation:match("^(.-)%-%>(.-)%-%>(.-)$")
  if from == nil or kind == nil or target == nil then
    return nil, nil, nil
  end

  if from == "" or kind == "" or target == "" then
    return nil, nil, nil
  end

  return from, kind, target
end

function Client:_next_id()
  self._id = self._id + 1
  return self._id
end

function Client:_rpc_url()
  return self._url .. "/rpc"
end

function Client:_build_headers()
  local headers = {
    ["Content-Type"] = "application/json",
    ["Accept"] = "application/json",
  }

  if type(self._token) == "string" and self._token ~= "" then
    headers["Authorization"] = "Bearer " .. self._token
  end

  if type(self._namespace) == "string" and self._namespace ~= "" then
    headers["Surreal-NS"] = self._namespace
  end

  if type(self._database) == "string" and self._database ~= "" then
    headers["Surreal-DB"] = self._database
  end

  return headers
end

function Client:_encode_payload(payload)
  local ok, encoded = pcall(self._json.encode, payload)
  if not ok then
    return nil, Errors.transport_error("Failed to encode RPC payload", encoded)
  end

  if type(encoded) ~= "string" then
    return nil, Errors.transport_error("JSON encoder must return a string", encoded)
  end

  return encoded, nil
end

function Client:_decode_payload(body)
  local ok, decoded = pcall(self._json.decode, body)
  if not ok then
    return nil, Errors.decode_error("Failed to decode RPC response", body, decoded)
  end

  if type(decoded) ~= "table" then
    return nil, Errors.decode_error("Decoded RPC response is not a table", body, decoded)
  end

  return decoded, nil
end

function Client:_request_rpc(method, params)
  if UNSUPPORTED_METHODS[method] then
    return Promise.reject(Errors.not_supported(method))
  end

  local payload = {
    id = self:_next_id(),
    method = method,
    params = as_params(params),
  }

  local body, encode_err = self:_encode_payload(payload)
  if encode_err then
    return Promise.reject(encode_err)
  end

  return Promise.new(function(resolve, reject)
    self._adapter.request({
      url = self:_rpc_url(),
      method = "POST",
      headers = self:_build_headers(),
      body = body,
      timeout_ms = self._timeout_ms,
    }, function(transport_err, response)
      if transport_err then
        reject(Errors.transport_error("Transport request failed", transport_err))
        return
      end

      if type(response) ~= "table" then
        reject(Errors.transport_error("Transport returned an invalid response", response))
        return
      end

      local status = response.status or response.status_code or response.code
      local raw_body = response.body or response.data or ""
      if type(raw_body) ~= "string" then
        raw_body = tostring(raw_body)
      end

      if type(status) ~= "number" then
        reject(Errors.transport_error("Transport response missing numeric status", response))
        return
      end

      if status < 200 or status >= 300 then
        reject(Errors.http_error(status, raw_body, response))
        return
      end

      local decoded, decode_err = self:_decode_payload(raw_body)
      if decode_err then
        reject(decode_err)
        return
      end

      if decoded.error ~= nil then
        local rpc_err = Errors.rpc_error(decoded.error)
        reject(rpc_err)
        return
      end

      resolve(decoded.result)
    end)
  end)
end

function Client:rpc(method, params, cb)
  local promise = self:_request_rpc(method, params)
  return callbackify(promise, cb)
end

function Client:ping(cb)
  return self:rpc("ping", {}, cb)
end

function Client:version(cb)
  return self:rpc("version", {}, cb)
end

function Client:info(cb)
  return self:rpc("info", {}, cb)
end

function Client:sign_in(credentials, cb)
  local promise = self:rpc("signin", { credentials })
  promise = promise:and_then(function(result)
    local token = extract_token(result)
    if token then
      self._token = token
    end
    return result
  end)
  return callbackify(promise, cb)
end

function Client:sign_up(credentials, cb)
  local promise = self:rpc("signup", { credentials })
  promise = promise:and_then(function(result)
    local token = extract_token(result)
    if token then
      self._token = token
    end
    return result
  end)
  return callbackify(promise, cb)
end

function Client:authenticate(token, cb)
  local promise = self:rpc("authenticate", { token })
  promise = promise:and_then(function(result)
    if type(token) == "string" and token ~= "" then
      self._token = token
    else
      local extracted = extract_token(result)
      if extracted then
        self._token = extracted
      end
    end
    return result
  end)
  return callbackify(promise, cb)
end

function Client:invalidate(cb)
  local promise = self:rpc("invalidate", {})
  promise = promise:and_then(function(result)
    self._token = nil
    return result
  end)
  return callbackify(promise, cb)
end

function Client:use(namespace, database, cb)
  local promise = self:rpc("use", { namespace, database })
  promise = promise:and_then(function(result)
    self._namespace = namespace
    self._database = database
    return result
  end)
  return callbackify(promise, cb)
end

function Client:query(sql, vars, cb)
  vars, cb = split_data_and_cb(vars, cb, {})
  if vars == nil or is_empty_table(vars) then
    return self:rpc("query", { sql }, cb)
  end
  return self:rpc("query", { sql, vars }, cb)
end

function Client:select(resource, cb)
  return self:rpc("select", { resource }, cb)
end

function Client:insert(resource, data, cb)
  data, cb = split_data_and_cb(data, cb, nil)
  return self:rpc("insert", { resource, data }, cb)
end

function Client:insert_relation(resource, data, cb)
  data, cb = split_data_and_cb(data, cb, nil)
  return self:rpc("insert_relation", { resource, data }, cb)
end

function Client:create(resource, data, cb)
  data, cb = split_data_and_cb(data, cb, nil)
  return self:rpc("create", { resource, data }, cb)
end

function Client:upsert(resource, data, cb)
  data, cb = split_data_and_cb(data, cb, nil)
  return self:rpc("upsert", { resource, data }, cb)
end

function Client:update(resource, data, cb)
  data, cb = split_data_and_cb(data, cb, nil)
  return self:rpc("update", { resource, data }, cb)
end

function Client:merge(resource, data, cb)
  data, cb = split_data_and_cb(data, cb, nil)
  return self:rpc("merge", { resource, data }, cb)
end

function Client:patch(resource, patches, cb)
  patches, cb = split_data_and_cb(patches, cb, nil)
  return self:rpc("patch", { resource, patches }, cb)
end

function Client:delete(resource, cb)
  return self:rpc("delete", { resource }, cb)
end

function Client:relate(relation, data, cb)
  data, cb = split_data_and_cb(data, cb, nil)

  if type(relation) == "table" then
    local from = relation.from or relation["in"] or relation[1]
    local kind = relation.kind or relation.edge or relation[2]
    local target = relation["with"] or relation.out or relation.to or relation[3]
    if from ~= nil and kind ~= nil and target ~= nil then
      return self:rpc("relate", { from, kind, target, data }, cb)
    end
  end

  local from, kind, target = parse_relation_string(relation)
  if from ~= nil then
    return self:rpc("relate", { from, kind, target, data }, cb)
  end

  return self:rpc("relate", { relation, data }, cb)
end

function Client:run(name, args, cb)
  args, cb = split_data_and_cb(args, cb, {})
  return self:rpc("run", { name, args or {} }, cb)
end

function Client:set_token(token)
  self._token = token
end

function Client:get_token()
  return self._token
end

function Client:live(cb)
  return callbackify(Promise.reject(Errors.not_supported("live")), cb)
end

function Client:kill(id, cb)
  return callbackify(Promise.reject(Errors.not_supported("kill")), cb)
end

function Client:let(key, value, cb)
  return callbackify(Promise.reject(Errors.not_supported("let")), cb)
end

function Client:unset(key, cb)
  return callbackify(Promise.reject(Errors.not_supported("unset")), cb)
end

function MODULE.new_client(config)
  assert_config(config)

  local self = setmetatable({}, Client)
  self._url = trim_trailing_slash(config.url)
  self._adapter = config.adapter
  self._json = resolve_json()
  self._namespace = config.namespace
  self._database = config.database
  self._token = config.token
  self._timeout_ms = config.timeout_ms
  self._id = 0

  return self
end

return MODULE
