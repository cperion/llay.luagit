local core = require("core")
local shell = require("shell")

local M = {}

function M.init(capacity, dims)
    if capacity and type(capacity) == "number" then
        return core.initialize(capacity, dims)
    else
        return core.initialize(nil, capacity)
    end
end

function M.begin_layout()
    core.begin_layout()
end

function M.end_layout()
    return core.end_layout()
end

function M.set_dimensions(width, height)
    core.set_dimensions(width, height)
end

M.container = shell.container
M.row = shell.row
M.column = shell.column
M.box = shell.box
M.text = shell.text
M.style = shell.style

M.set_measure_text = core.set_measure_text

M._core = core

return M
