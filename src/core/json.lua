local Json = {}

local ok, dkjson = pcall(require, "src.vendor.dkjson")
if not ok then
  ok, dkjson = pcall(require, "dkjson")
end

if not ok or type(dkjson) ~= "table" then
  error("Unable to load dkjson. Ensure src/vendor/dkjson.lua is present or dkjson is installed")
end

Json.null = dkjson.null

function Json.encode(value)
  local encoded, err = dkjson.encode(value)
  if err then
    error(err)
  end
  return encoded
end

function Json.decode(text)
  local decoded, _, err = dkjson.decode(text, 1, Json.null)
  if err then
    error(err)
  end
  return decoded
end

return Json
