local ffi = require("ffi")
package.path = "./src/?.lua;" .. package.path

local llay = require("init")

print("Llay Basic Example")
print("==================")

llay.init(1024 * 1024 * 4)
llay.set_dimensions(800, 600)

llay.begin_layout()

-- Direct core API usage for now
local config = ffi.new("Clay_LayoutConfig")
config.layoutDirection = 0
config.childGap = 10
llay._core.open_element(config)

local child1_config = ffi.new("Clay_LayoutConfig")
child1_config.sizing.width.type = 3
child1_config.sizing.width.size.minMax.min = 100
child1_config.sizing.width.size.minMax.max = 100
child1_config.sizing.height.type = 3
child1_config.sizing.height.size.minMax.min = 50
child1_config.sizing.height.size.minMax.max = 50
llay._core.open_element(child1_config)
llay._core.close_element()

local child2_config = ffi.new("Clay_LayoutConfig")
child2_config.sizing.width.type = 3
child2_config.sizing.width.size.minMax.min = 150
child2_config.sizing.width.size.minMax.max = 150
child2_config.sizing.height.type = 3
child2_config.sizing.height.size.minMax.min = 50
child2_config.sizing.height.size.minMax.max = 50
llay._core.open_element(child2_config)
llay._core.close_element()

llay._core.close_element()

local commands = llay.end_layout()

print("Rendered " .. commands.length .. " command(s)")
for i = 0, commands.length - 1 do
    local cmd = commands.internalArray[i]
    print(string.format("  %d: x=%.0f y=%.0f w=%.0f h=%.0f", i, cmd.boundingBox.x, cmd.boundingBox.y, cmd.boundingBox.width, cmd.boundingBox.height))
end
