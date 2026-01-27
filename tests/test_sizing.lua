local ffi = require("ffi")
local core = require("core")
local compare = require("tests.helpers.compare")

print("  Testing FIXED sizing...")

core.initialize()
core.begin_layout()

local container = ffi.new("Clay_LayoutConfig")
core.open_element(container)

local fixed_elem = ffi.new("Clay_LayoutConfig")
fixed_elem.sizing.width.type = 3
fixed_elem.sizing.width.size.minMax.min = 100
fixed_elem.sizing.width.size.minMax.max = 100
fixed_elem.sizing.height.type = 3
fixed_elem.sizing.height.size.minMax.min = 50
fixed_elem.sizing.height.size.minMax.max = 50
core.open_element(fixed_elem)
core.close_element()

core.close_element()

local result = core.end_layout()
local cmd = result.internalArray[1]

if not compare.float_eq(cmd.boundingBox.width, 100.0) or not compare.float_eq(cmd.boundingBox.height, 50.0) then
    error(string.format("FIXED sizing failed: got %.1fx%.1f", cmd.boundingBox.width, cmd.boundingBox.height))
end

print("  PASS")
