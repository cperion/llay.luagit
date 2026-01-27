local ffi = require("ffi")
package.path = "./src/?.lua;" .. package.path

local llay = require("init")

print("Llay Basic Example")
print("==================")

llay.init(1024 * 1024 * 16)
llay.set_dimensions(800, 600)

llay.begin_layout()

-- Using declarative API
llay.Element({
	layout = {
		layoutDirection = 0, -- LEFT_TO_RIGHT
		childGap = 10
	}
}, function()
	-- Child 1
	llay.Element({
		id = "Child1",
		backgroundColor = {255, 0, 0, 255},
		layout = {
			sizing = { width = 100, height = 50 }
		}
	})
	
	-- Child 2  
	llay.Element({
		id = "Child2", 
		backgroundColor = {0, 255, 0, 255},
		layout = {
			sizing = { width = 150, height = 50 }
		}
	})
end)

local commands = llay.end_layout()

print("Rendered " .. commands.length .. " command(s)")
for i = 0, commands.length - 1 do
    local cmd = commands.internalArray[i]
    print(string.format("  %d: x=%.0f y=%.0f w=%.0f h=%.0f", i, cmd.boundingBox.x, cmd.boundingBox.y, cmd.boundingBox.width, cmd.boundingBox.height))
end
