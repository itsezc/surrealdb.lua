local Adapter = {}

local function normalize_headers(headers)
  if type(headers) ~= "table" then
    return {}
  end
  return headers
end

function Adapter.request(options, callback)
  if type(PerformHttpRequest) ~= "function" then
    callback("PerformHttpRequest is not available in this runtime")
    return
  end

  local request_options = nil
  if options.timeout_ms ~= nil then
    request_options = { timeout = options.timeout_ms }
  end

  PerformHttpRequest(
    options.url,
    function(status_code, body, response_headers, error_data)
      if type(status_code) ~= "number" then
        callback(error_data or "Invalid status code from PerformHttpRequest")
        return
      end

      callback(nil, {
        status = status_code,
        body = body or "",
        headers = response_headers or {},
      })
    end,
    options.method or "POST",
    options.body or "",
    normalize_headers(options.headers),
    request_options
  )
end

return Adapter
