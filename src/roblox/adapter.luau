--!strict

local HttpService = game:GetService("HttpService")

export type RequestOptions = {
  url: string,
  method: string?,
  headers: { [string]: string }?,
  body: string?,
  timeout_ms: number?,
}

export type Response = {
  status: number,
  body: string,
  headers: { [string]: string },
}

local Adapter = {}

function Adapter.request(options: RequestOptions, callback: (any?, Response?) -> ())
  local request = {
    Url = options.url,
    Method = options.method or "POST",
    Headers = options.headers or {},
    Body = options.body or "",
  }

  local ok, result = pcall(function()
    return HttpService:RequestAsync(request)
  end)

  if not ok then
    callback(result, nil)
    return
  end

  callback(nil, {
    status = result.StatusCode,
    body = result.Body or "",
    headers = (result.Headers :: any) or {},
  })
end

return Adapter
