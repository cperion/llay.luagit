local ffi = require("ffi")

local layouts = {}

layouts.simple_row = function(api)
    api.begin_layout(800, 600)
    
    local layout = ffi.new("Clay_LayoutConfig")
    layout.layoutDirection = 0
    layout.childGap = 0
    
    api.open_element(layout)
    
    local child1 = ffi.new("Clay_LayoutConfig")
    child1.sizing.width.type = 0
    child1.sizing.width.size.minMax.min = 100
    child1.sizing.width.size.minMax.max = 100
    child1.sizing.height.type = 0
    child1.sizing.height.size.minMax.min = 50
    child1.sizing.height.size.minMax.max = 50
    api.open_element(child1)
    api.close_element()
    
    local child2 = ffi.new("Clay_LayoutConfig")
    child2.sizing.width.type = 0
    child2.sizing.width.size.minMax.min = 200
    child2.sizing.width.size.minMax.max = 200
    child2.sizing.height.type = 0
    child2.sizing.height.size.minMax.min = 50
    child2.sizing.height.size.minMax.max = 50
    api.open_element(child2)
    api.close_element()
    
    api.close_element()
    
    return api.end_layout()
end

return layouts
