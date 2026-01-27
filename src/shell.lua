-- shell.lua - Public shell (declarative DSL API)
-- This module provides the ergonomic, declarative API

local core = require("core")

local M = {}

-- Polymorphic element builder
local function make_element()
    return function(arg)
        local config_ptr
        local children_fn
        local id
        
        if type(arg) == "table" then
            config_ptr = arg
            children_fn = arg[1]
            id = arg.id
        elseif type(arg) == "string" then
            -- Simple string for text element
            M.text(arg)
            return
        end
        
        if config_ptr then
            core.open_element(config_ptr)
        end
        
        if children_fn then
            children_fn()
        end
        
        core.close_element()
    end
end

-- Public API
M.container = make_element()
M.row = make_element()
M.column = make_element()
M.box = make_element()

function M.text(arg)
    local content = ""
    local config_ptr
    
    if type(arg) == "string" then
        content = arg
    elseif type(arg) == "table" then
        content = arg[1] or ""
        config_ptr = arg
    end
    
    core.open_text_element(content, config_ptr)
end

function M.style(arg)
    -- TODO: Return pre-calculated C struct for styling
    return arg
end

-- Direct core access for advanced use
M._core = core

return M
