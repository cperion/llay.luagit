#!/usr/bin/env luajit
-- example/basic.lua - Basic usage example

package.path = "./src/?.lua;" .. package.path

local llay = require("init")

print("Llay Basic Example")
print("==================")

-- Initialize
llay.init(1024 * 1024)

-- Set dimensions
llay.set_dimensions(800, 600)

-- Begin layout
llay.begin_layout()

-- Build a simple row
llay.row {
    gap = 10,
    function()
        llay.text { "Hello", size = 24 }
        llay.text { "World", size = 24 }
    end
}

-- End layout
local commands = llay.end_layout()

print("Rendered " .. commands.length .. " command(s)")
print("TODO: Implement actual layout calculation")
