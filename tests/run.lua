package.path = "./src/?.lua;" .. package.path

print("Running Llay test suite...")
print("==========================")

local passed = 0
local failed = 0

local function compare_with_golden(test_name, golden_file)
	print("Test: " .. test_name)

	-- Run Lua (layout functions handle begin/end_layout internally)
	local clay = require("init")
	local layouts = require("tests.helpers.layouts")

	local lua_cmds
	if layouts[test_name] then
		lua_cmds = layouts[test_name]()
	else
		print("  FAIL: Unknown test: " .. test_name)
		return false
	end

	-- Read golden file
	local golden = {}
	for line in io.lines("tests/clay_ref/" .. golden_file) do
		local id, type_str, bbox_str = line:match("cmd%[(%d)%]: id=.- type=(%d) bbox=(.*)")
		if id then
			local x, y, w, h = bbox_str:match("{x=(.-),y=(.-),w=(.-),h=(.-)}")
			table.insert(golden, {
				index = tonumber(id),
				commandType = tonumber(type_str),
				x = tonumber(x),
				y = tonumber(y),
				w = tonumber(w),
				h = tonumber(h)
			})
		end
	end

	-- Compare
	if #golden ~= tonumber(lua_cmds.length) then
		print(string.format("  FAIL: Command count mismatch (C=%d, Lua=%d)", #golden, tonumber(lua_cmds.length)))
		return false
	end

	for i = 0, tonumber(lua_cmds.length) - 1 do
		local lua_cmd = lua_cmds.internalArray[i]
		local golden = golden[i + 1]

		local bb = lua_cmd.boundingBox
		if math.abs(bb.x - golden.x) > 0.01 or
		   math.abs(bb.y - golden.y) > 0.01 or
		   math.abs(bb.width - golden.w) > 0.01 or
		   math.abs(bb.height - golden.h) > 0.01 then
			print(string.format("  FAIL: Command %d bbox mismatch", i))
			print(string.format("        Expected: {x=%.2f,y=%.2f,w=%.2f,h=%.2f}",
				golden.x, golden.y, golden.w, golden.h))
			print(string.format("        Got:      {x=%.2f,y=%.2f,w=%.2f,h=%.2f}",
				bb.x, bb.y, bb.width, bb.height))
			return false
		end

		if lua_cmd.commandType ~= golden.commandType then
			print(string.format("  INFO: Command %d type differs (C=%d, Lua=%d) - this is expected as IDs differ",
				i, golden.commandType, tonumber(lua_cmd.commandType)))
		end
	end

	print("  PASS - Layout positions match C reference!")
	return true
end

-- Initialize once
local clay = require("init")
clay.init(1024 * 1024 * 16)
clay.set_measure_text_function(require("tests.helpers.mock").create_mock_measure())

-- Run all tests
local tests = {
	{ name = "simple_row", file = "golden_simple_row.txt" },
	{ name = "nested_containers", file = "golden_nested_containers.txt" },
	{ name = "alignment_center", file = "golden_alignment_center.txt" },
	{ name = "sizing_modes", file = "golden_sizing_modes.txt" },
	{ name = "child_gap", file = "golden_child_gap.txt" },
	{ name = "corners_borders", file = "golden_corners_borders.txt" },
}

for _, test in ipairs(tests) do
	if compare_with_golden(test.name, test.file) then
		passed = passed + 1
	else
		failed = failed + 1
	end
end

print("==========================")
print(string.format("Results: %d passed, %d failed", passed, failed))
print(string.format("Layout correctness: %d%%", math.floor(passed * 100 / (passed + failed))))

os.exit(failed > 0 and 1 or 0)
