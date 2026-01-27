local ffi = require("ffi")
local core = require("core")
local compare = require("tests.helpers.compare")

print("  Testing basic row layout...")

core.initialize()
core.set_measure_text(function(t, fs) return ffi.new("Clay_Vector2", {x=#t*10, y=fs}) end)

core.begin_layout()

local row_config = ffi.new("Clay_LayoutConfig")
row_config.layoutDirection = 0
row_config.childGap = 10
core.open_element(row_config)

local child1 = ffi.new("Clay_LayoutConfig")
child1.sizing.width.type = 3
child1.sizing.width.size.minMax.min = 100
child1.sizing.width.size.minMax.max = 100
child1.sizing.height.type = 3
child1.sizing.height.size.minMax.min = 50
child1.sizing.height.size.minMax.max = 50
core.open_element(child1)
core.close_element()

local child2 = ffi.new("Clay_LayoutConfig")
child2.sizing.width.type = 3
child2.sizing.width.size.minMax.min = 150
child2.sizing.width.size.minMax.max = 150
child2.sizing.height.type = 3
child2.sizing.height.size.minMax.min = 50
child2.sizing.height.size.minMax.max = 50
core.open_element(child2)
core.close_element()

core.close_element()

local result = core.end_layout()

if result.length ~= 3 then
    error("Expected 3 render commands, got " .. result.length)
end

local cmd1 = result.internalArray[1]
if not compare.float_eq(cmd1.boundingBox.x, 0.0) then
    error("First child x position incorrect")
end

local cmd2 = result.internalArray[2]
if not compare.float_eq(cmd2.boundingBox.x, 110.0) then
    error("Second child x position incorrect: got " .. cmd2.boundingBox.x)
end

print("  PASS")
