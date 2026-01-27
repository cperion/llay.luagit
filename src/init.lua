-- init.lua - Main entry point

local core = require("core")
local shell = require("shell")

local M = {}

-- Initialize with capacity (optional, defaults to 1MB)
function M.init(capacity)
    capacity = capacity or 1024 * 1024
    return core.initialize(capacity, {800, 600})
end

-- Layout control
function M.begin_layout()
    core.begin_layout()
end

function M.end_layout()
    return core.end_layout()
end

function M.set_dimensions(width, height)
    core.set_dimensions(width, height)
end

-- Declarative API
M.container = shell.container
M.row = shell.row
M.column = shell.column
M.box = shell.box
M.text = shell.text
M.style = shell.style

-- Text measurement
M.set_measure_text = core.set_measure_text

-- Core access
M._core = core

return M
