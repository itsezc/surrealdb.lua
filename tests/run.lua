local suites = {
  require("tests.unit.test_promise"),
  require("tests.unit.test_client"),
  require("tests.unit.test_fivem_adapter"),
  require("tests.unit.test_roblox_adapter_contract"),
}

local total = 0
local passed = 0

for _, suite in ipairs(suites) do
  for _, test in ipairs(suite) do
    total = total + 1
    local ok, err = pcall(test.run)
    if ok then
      passed = passed + 1
      io.write("[PASS] " .. test.name .. "\n")
    else
      io.write("[FAIL] " .. test.name .. "\n")
      io.write("       " .. tostring(err) .. "\n")
    end
  end
end

io.write("\nSummary: " .. tostring(passed) .. "/" .. tostring(total) .. " tests passed\n")

if passed ~= total then
  os.exit(1)
end
