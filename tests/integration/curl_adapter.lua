local Adapter = {}

local function shell_quote(value)
  local s = tostring(value or "")
  return "'" .. s:gsub("'", "'\\''") .. "'"
end

function Adapter.request(options, callback)
  local headers_file = os.tmpname()
  local body_file = os.tmpname()

  local parts = {
    "curl",
    "--silent",
    "--show-error",
    "--request",
    shell_quote(options.method or "POST"),
    shell_quote(options.url),
    "--dump-header",
    shell_quote(headers_file),
    "--output",
    shell_quote(body_file),
    "--write-out",
    shell_quote("%{http_code}"),
  }

  local headers = options.headers or {}
  for key, value in pairs(headers) do
    parts[#parts + 1] = "--header"
    parts[#parts + 1] = shell_quote(key .. ": " .. tostring(value))
  end

  if options.body and options.body ~= "" then
    parts[#parts + 1] = "--data"
    parts[#parts + 1] = shell_quote(options.body)
  end

  local command = table.concat(parts, " ")
  local handle = io.popen(command .. " 2>&1")
  if not handle then
    os.remove(headers_file)
    os.remove(body_file)
    callback("failed to spawn curl process")
    return
  end

  local output = handle:read("*a") or ""
  local ok = handle:close()
  if ok ~= true then
    os.remove(headers_file)
    os.remove(body_file)
    callback("curl request failed: " .. tostring(output))
    return
  end

  local status = tonumber(output:match("(%d+)%s*$") or output:match("^%s*(%d+)%s*$"))
  if not status then
    os.remove(headers_file)
    os.remove(body_file)
    callback("curl response missing status code: " .. tostring(output))
    return
  end

  local body_handle = io.open(body_file, "r")
  local body = ""
  if body_handle then
    body = body_handle:read("*a") or ""
    body_handle:close()
  end

  local headers = {}
  local header_handle = io.open(headers_file, "r")
  if header_handle then
    for line in header_handle:lines() do
      local key, value = line:match("^([%w%-]+):%s*(.+)$")
      if key and value then
        local lower = key:lower()
        local existing = headers[lower]
        if existing == nil then
          headers[lower] = value
        elseif type(existing) == "table" then
          existing[#existing + 1] = value
        else
          headers[lower] = { existing, value }
        end
      end
    end
    header_handle:close()
  end

  os.remove(headers_file)
  os.remove(body_file)

  callback(nil, {
    status = status,
    body = body,
    headers = headers,
  })
end

return Adapter
