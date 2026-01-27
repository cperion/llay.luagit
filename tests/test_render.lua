local ffi = require("ffi")
local core = require("core")
local compare = require("tests.helpers.compare")

print("  Testing render command structure...")

core.initialize()
core.begin_layout()

-- Container
local container = ffi.new("Clay_LayoutConfig")
core.open_element(container)

-- Element with fixed sizing
local config = ffi.new("Clay_LayoutConfig")
config.sizing.width.type = 3
config.sizing.width.size.minMax.min = 200
config.sizing.width.size.minMax.max = 200
config.sizing.height.type = 3
config.sizing.height.size.minMax.min = 100
config.sizing.height.size.minMax.max = 100
core.open_element(config)
core.close_element()

core.close_element()

local result = core.end_layout()

if result.length ~= 2 then
    error("Expected 2 render commands, got " .. result.length)
end

local cmd = result.internalArray[1]

local valid_bbox = type(cmd.boundingBox) == "cdata" and cmd.boundingBox.width ~= nil
if not valid_bbox then
    error("Render command missing boundingBox")
end

if not compare.float_eq(cmd.boundingBox.width, 200.0) or not compare.float_eq(cmd.boundingBox.height, 100.0) then
    error(string.format("Render command has incorrect size: %.1fx%.1f", cmd.boundingBox.width, cmd.boundingBox.height))
end

print("  PASS")
