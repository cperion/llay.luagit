local ffi = require("ffi")
require("clay_ffi")

local bit = require("bit")
local band, bor = bit.band, bit.bor

local M = {}

local Clay__SizingType = {
    FIT = 0,
    GROW = 1,
    PERCENT = 2,
    FIXED = 3,
}

local Clay_LayoutDirection = {
    LEFT_TO_RIGHT = 0,
    TOP_TO_BOTTOM = 1,
}

local CLAY__MAXFLOAT = 3.402823466e+38

local MAX_ELEMENTS = 8192
local MAX_MEMORY = 1024 * 1024 * 4

local arena_memory = ffi.new("uint8_t[?]", MAX_MEMORY)
local arena = ffi.new("Clay_Arena")
arena.memory = arena_memory
arena.capacity = MAX_MEMORY
arena.nextAllocation = 0

local MAX_RENDER_COMMANDS = 8192
local render_commands = ffi.new("Clay_RenderCommand[?]", MAX_RENDER_COMMANDS)
local render_commands_count = 0

local MAX_LAYOUT_ELEMENTS = 8192
local layout_elements = ffi.new("Clay_LayoutElement[?]", MAX_LAYOUT_ELEMENTS)
local layout_elements_count = 0

local open_element_stack = ffi.new("int32_t[?]", 512)
local open_element_stack_count = 0

local measure_text_fn = nil

local layout_dimensions = ffi.new("Clay_Dimensions", {width=800, height=600})

local element_counter = 0

local next_element_id = 1

local function allocate_in_arena(size, alignment)
    local next_ptr = arena.nextAllocation
    local aligned = band(next_ptr + alignment - 1, -alignment)
    arena.nextAllocation = aligned + size
    return ffi.cast("void*", aligned)
end

local function open_element_internal(config)
    if layout_elements_count >= MAX_LAYOUT_ELEMENTS then
        error("Max layout elements exceeded")
    end
    
    local idx = layout_elements_count
    layout_elements_count = layout_elements_count + 1
    local elem = layout_elements + idx
    
    ffi.fill(elem, ffi.sizeof("Clay_LayoutElement"))
    
    elem.id = next_element_id
    next_element_id = next_element_id + 1
    elem.dimensions.width = 0
    elem.dimensions.height = 0
    elem.minDimensions.width = 0
    elem.minDimensions.height = 0
    elem.elementConfigs.length = 0
    
    if config ~= nil then
        if type(config) == "table" then
            local config_ptr = ffi.new("Clay_LayoutConfig")
            if config.sizing ~= nil then
                if config.sizing.width ~= nil then
                    config_ptr.sizing.width.type = config.sizing.width.type or Clay__SizingType.FIT
                    if config.sizing.width.minMax ~= nil then
                        config_ptr.sizing.width.size.minMax.min = config.sizing.width.minMax.min or 0
                        config_ptr.sizing.width.size.minMax.max = config.sizing.width.minMax.max or 0
                    else
                        config_ptr.sizing.width.size.minMax.min = 0
                        config_ptr.sizing.width.size.minMax.max = 0
                    end
                end
                if config.sizing.height ~= nil then
                    config_ptr.sizing.height.type = config.sizing.height.type or Clay__SizingType.FIT
                    if config.sizing.height.minMax ~= nil then
                        config_ptr.sizing.height.size.minMax.min = config.sizing.height.minMax.min or 0
                        config_ptr.sizing.height.size.minMax.max = config.sizing.height.minMax.max or 0
                    else
                        config_ptr.sizing.height.size.minMax.min = 0
                        config_ptr.sizing.height.size.minMax.max = 0
                    end
                end
            end
            if config.padding ~= nil then
                config_ptr.padding.left = config.padding.left or 0
                config_ptr.padding.right = config.padding.right or 0
                config_ptr.padding.top = config.padding.top or 0
                config_ptr.padding.bottom = config.padding.bottom or 0
            end
            if config.childGap ~= nil then
                config_ptr.childGap = config.childGap
            end
            if config.childAlignment ~= nil then
                config_ptr.childAlignment.x = config.childAlignment.x or 0
                config_ptr.childAlignment.y = config.childAlignment.y or 0
            end
            if config.layoutDirection ~= nil then
                config_ptr.layoutDirection = config.layoutDirection
            end
            elem.layoutConfig = config_ptr
        elseif type(config) == "cdata" then
            elem.layoutConfig = config
        end
    end
    
    open_element_stack[open_element_stack_count] = idx
    open_element_stack_count = open_element_stack_count + 1
    
    return elem
end

local function close_element_internal()
    if open_element_stack_count <= 0 then
        error("Close element called with no open elements")
    end
    
    open_element_stack_count = open_element_stack_count - 1
end

local function add_render_command(bound_box, bg_color)
    if render_commands_count >= MAX_RENDER_COMMANDS then
        error("Max render commands exceeded")
    end
    
    local cmd = render_commands + render_commands_count
    render_commands_count = render_commands_count + 1
    
    cmd.boundingBox.x = bound_box.x or 0
    cmd.boundingBox.y = bound_box.y or 0
    cmd.boundingBox.width = bound_box.width or 0
    cmd.boundingBox.height = bound_box.height or 0
    cmd.renderData.backgroundColor = bg_color or ffi.new("Clay_Color", {r=0, g=0, b=0, a=0})
    cmd.text.length = 0
    cmd.text.chars = nil
    cmd.configId = 0
    cmd.id = 0
end

local function calculate_sized_size(elem, parent_size, axis)
    local config = elem.layoutConfig
    if config == nil then
        return 0
    end
    
    local sizing_axis = axis == 0 and config.sizing.width or config.sizing.height
    local sizing_type = sizing_axis.type
    
    if sizing_type == Clay__SizingType.FIXED then
        return sizing_axis.size.minMax.min
    elseif sizing_type == Clay__SizingType.FIT then
        return sizing_axis.size.minMax.min
    elseif sizing_type == Clay__SizingType.GROW then
        return sizing_axis.size.minMax.min
    elseif sizing_type == Clay__SizingType.PERCENT then
        return parent_size * sizing_axis.size.percent
    end
    
    return 0
end

local function calculate_layout()
    local root_elem = nil
    
    if layout_elements_count > 0 then
        root_elem = layout_elements + 0
    end
    
    if root_elem ~= nil then
        root_elem.dimensions.width = layout_dimensions.width
        root_elem.dimensions.height = layout_dimensions.height
    end
    
    for i = 0, layout_elements_count - 1 do
        local elem = layout_elements + i
        local config = elem.layoutConfig
        
        if i > 0 then
            local parent_idx = i - 1
            if parent_idx >= 0 then
                local parent = layout_elements + parent_idx
                local dir = 0
                if config ~= nil then
                    dir = config.layoutDirection
                end
                
                local child_width = 0
                local child_height = 0
                
                if dir == Clay_LayoutDirection.LEFT_TO_RIGHT then
                    child_width = calculate_sized_size(elem, parent.dimensions.width, 0)
                    child_height = calculate_sized_size(elem, parent.dimensions.height, 1)
                else
                    child_width = calculate_sized_size(elem, parent.dimensions.width, 0)
                    child_height = calculate_sized_size(elem, parent.dimensions.height, 1)
                end
                
                elem.dimensions.width = child_width
                elem.dimensions.height = child_height
            end
        end
    end
    
    local position_x = 0
    local position_y = 0
    
    for i = 0, layout_elements_count - 1 do
        local elem = layout_elements + i
        local config = elem.layoutConfig
        
        if config ~= nil and config.padding ~= nil then
            position_x = position_x + config.padding.left
            position_y = position_y + config.padding.top
        end
        
        local bbox = ffi.new("Clay_BoundingBox")
        bbox.x = position_x
        bbox.y = position_y
        bbox.width = elem.dimensions.width
        bbox.height = elem.dimensions.height
        
        local color = ffi.new("Clay_Color", {r=200, g=200, b=200, a=255})
        add_render_command(bbox, color)
        
        if i > 0 then
            local parent_idx = i - 1
            if parent_idx >= 0 then
                local parent = layout_elements + parent_idx
                local parent_config = parent.layoutConfig
                
                if parent_config ~= nil then
                    local dir = parent_config.layoutDirection
                    local gap = parent_config.childGap or 0
                    local padding = parent_config.padding or ffi.new("Clay_Padding")
                    
                    if dir == Clay_LayoutDirection.LEFT_TO_RIGHT then
                        position_x = position_x + elem.dimensions.width + gap
                    else
                        position_x = position_x - elem.dimensions.width
                        position_y = position_y + elem.dimensions.height + gap
                    end
                end
            end
        end
    end
end

function M.initialize(capacity, dims)
    if capacity then
        MAX_MEMORY = capacity
    end
    
    if dims then
        layout_dimensions.width = dims.width or 800
        layout_dimensions.height = dims.height or 600
    end
    
    return {initialized = true}
end

function M.begin_layout()
    layout_elements_count = 0
    open_element_stack_count = 0
    render_commands_count = 0
    next_element_id = 1
    ffi.fill(layout_elements, ffi.sizeof("Clay_LayoutElement") * MAX_LAYOUT_ELEMENTS)
    ffi.fill(render_commands, ffi.sizeof("Clay_RenderCommand") * MAX_RENDER_COMMANDS)
end

function M.end_layout()
    calculate_layout()
    
    local result = ffi.new("Clay_RenderCommandArray")
    result.capacity = MAX_RENDER_COMMANDS
    result.length = render_commands_count
    result.internalArray = render_commands
    
    return result
end

function M.open_element(config)
    open_element_internal(config)
end

function M.close_element()
    close_element_internal()
end

function M.open_text_element(text, config)
    local elem = open_element_internal(config)
    
    if text and measure_text_fn then
        local dims = measure_text_fn(text, 16)
        elem.dimensions.width = dims.x
        elem.dimensions.height = dims.y
    elseif text then
        elem.dimensions.width = #text * 10
        elem.dimensions.height = 20
    end
end

function M.set_dimensions(width, height)
    layout_dimensions.width = width or 800
    layout_dimensions.height = height or 600
end

function M.set_measure_text(fn)
    measure_text_fn = fn
end

local djb2_hash = {
    5381,
    33,
    0,
    0,
}

function M.hash_string(str, seed)
    local hash = seed or 5381
    local len = str and #str or 0
    
    for i = 1, len do
        local c = string.byte(str, i)
        hash = ((hash * 33) + c) % 4294967296
    end
    
    return hash
end

M.__SizingType = Clay__SizingType
M.__LayoutDirection = Clay_LayoutDirection

return M
