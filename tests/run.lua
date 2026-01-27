package.path = "./src/?.lua;" .. package.path

local function run_test(name)
    print("Running test_" .. name .. ".lua...")

    local ok, err = pcall(function()
        dofile("tests/test_" .. name .. ".lua")
    end)

    if ok then
        return true
    else
        print("  FAIL: " .. tostring(err))
        return false
    end
end

local tests = {
    "layout",
    "sizing",
    "render",
}

print("Running Llay test suite...")
print()

local passed = 0
local failed = 0

for _, name in ipairs(tests) do
    if run_test(name) then
        passed = passed + 1
    else
        failed = failed + 1
    end
end

print()
print(string.format("Results: %d passed, %d failed", passed, failed))

os.exit(failed > 0 and 1 or 0)
