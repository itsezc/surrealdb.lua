local Promise = {}
Promise.__index = Promise

local PENDING = "pending"
local FULFILLED = "fulfilled"
local REJECTED = "rejected"

local function schedule(fn)
  local task_api = rawget(_G, "task")
  if type(task_api) == "table" and type(task_api.defer) == "function" then
    task_api.defer(fn)
    return
  end

  local citizen_api = rawget(_G, "Citizen")
  if type(citizen_api) == "table" and type(citizen_api.SetTimeout) == "function" then
    citizen_api.SetTimeout(0, fn)
    return
  end

  fn()
end

local function is_promise(value)
  return type(value) == "table" and getmetatable(value) == Promise
end

local function flush_handlers(self)
  if self._state == PENDING then
    return
  end

  local handlers = self._handlers
  self._handlers = {}

  for i = 1, #handlers do
    local handler = handlers[i]
    schedule(function()
      local callback = nil
      if self._state == FULFILLED then
        callback = handler.on_fulfilled
      else
        callback = handler.on_rejected
      end

      if callback == nil then
        if self._state == FULFILLED then
          handler.resolve(self._value)
        else
          handler.reject(self._value)
        end
        return
      end

      local ok, result = pcall(callback, self._value)
      if not ok then
        handler.reject(result)
        return
      end

      if is_promise(result) then
        result:and_then(handler.resolve, handler.reject)
      else
        handler.resolve(result)
      end
    end)
  end
end

local function settle(self, state, value)
  if self._state ~= PENDING then
    return
  end

  if state == FULFILLED and is_promise(value) then
    value:and_then(function(resolved)
      settle(self, FULFILLED, resolved)
    end, function(err)
      settle(self, REJECTED, err)
    end)
    return
  end

  self._state = state
  self._value = value
  flush_handlers(self)
end

function Promise.new(executor)
  local self = setmetatable({
    _state = PENDING,
    _value = nil,
    _handlers = {},
  }, Promise)

  local function resolve(value)
    settle(self, FULFILLED, value)
  end

  local function reject(reason)
    settle(self, REJECTED, reason)
  end

  if type(executor) == "function" then
    local ok, err = pcall(executor, resolve, reject)
    if not ok then
      reject(err)
    end
  end

  return self
end

function Promise.resolve(value)
  return Promise.new(function(resolve)
    resolve(value)
  end)
end

function Promise.reject(reason)
  return Promise.new(function(_, reject)
    reject(reason)
  end)
end

function Promise:and_then(on_fulfilled, on_rejected)
  return Promise.new(function(resolve, reject)
    self._handlers[#self._handlers + 1] = {
      on_fulfilled = on_fulfilled,
      on_rejected = on_rejected,
      resolve = resolve,
      reject = reject,
    }

    flush_handlers(self)
  end)
end

function Promise:catch(on_rejected)
  return self:and_then(nil, on_rejected)
end

function Promise:finally(on_finally)
  return self:and_then(function(value)
    if on_finally then
      on_finally()
    end
    return value
  end, function(err)
    if on_finally then
      on_finally()
    end
    return Promise.reject(err)
  end)
end

function Promise:await(timeout_ms)
  local done = false
  local success = false
  local value = nil

  self:and_then(function(result)
    done = true
    success = true
    value = result
  end, function(err)
    done = true
    success = false
    value = err
  end)

  local started = os.clock()
  while not done do
    if timeout_ms and timeout_ms > 0 then
      local elapsed_ms = (os.clock() - started) * 1000
      if elapsed_ms >= timeout_ms then
        return false, "promise timed out"
      end
    end
  end

  return success, value
end

return Promise
