local core = require("core")

local M = {}

local function make_element()
    return function(arg)
        local config
        local children_fn
        
        if type(arg) == "table" then
            config = arg
            for k, v in pairs(arg) do
                if type(k) ~= "number" and type(v) == "function" then
                    children_fn = v
                    break
                end
            end
            if not children_fn and type(arg[1]) == "function" then
                children_fn = arg[1]
            end
        elseif type(arg) == "function" then
            children_fn = arg
        else
            config = nil
            children_fn = nil
        end
        
        core.open_element(config)
        
        if children_fn and type(children_fn) == "function" then
            children_fn()
        end
        
        core.close_element()
    end
end

M.container = make_element()
M.row = make_element()
M.column = make_element()
M.box = make_element()

function M.text(arg)
    local content = ""
    local config
    
    if type(arg) == "string" then
        content = arg
    elseif type(arg) == "table" then
        content = arg[1] or ""
        config = arg
    end
    
    core.open_text_element(content, config)
end

function M.style(arg)
    return arg
end

M._core = core

return M
