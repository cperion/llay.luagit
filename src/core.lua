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

local MAX_MEMORY = 1024 * 1024 * 4
local arena_memory = nil
local context = nil

local measure_text_fn = nil

local next_element_id = 1

function Clay__Array_Allocate_Arena(capacity, item_size, arena)
    local total_size = capacity * item_size
    local aligned_ptr = band(arena.nextAllocation + 15, -16)
    local next_alloc = aligned_ptr + total_size
    
    if ffi.cast("size_t", next_alloc) > arena.capacity then
        error("Arena capacity exceeded")
    end
    
    arena.nextAllocation = next_alloc
    return ffi.cast("void*", arena.memory + aligned_ptr)
end

local function array_get(array, index)
    if index < 0 or index >= array.capacity then
        return nil
    end
    return array.internalArray[index]
end

local function array_add(array, item)
    if array.length >= array.capacity then
        error("Array capacity exceeded")
    end
    array.internalArray[array.length] = item
    array.length = array.length + 1
    return array.internalArray[array.length - 1]
end

local function array_set(array, index, value)
    if index < 0 or index >= array.capacity then
        error("Array index out of bounds for set")
    end
    if index >= array.length then
        array.length = index + 1
    end
    array.internalArray[index] = value
end

local function array_remove_swapback(array, index)
    if index < 0 or index >= array.length then
        error("Array index out of bounds for remove")
    end
    array.length = array.length - 1
    if index < array.length then
        array.internalArray[index] = array.internalArray[array.length]
    end
end

local function Clay__int32_tArray_Add(array, value)
    return array_add(array, value)
end

local function Clay__int32_tArray_Get(array, index)
    return array_get(array, index)
end

local function Clay__int32_tArray_Set(array, index, value)
    return array_set(array, index, value)
end

local function Clay__int32_tArray_RemoveSwapback(array, index)
    return array_remove_swapback(array, index)
end

local function Clay__AddHashMapItem(elementId, layoutElement)
    if context.layoutElementsHashMapInternal.length == context.layoutElementsHashMapInternal.capacity - 1 then
        return nil
    end
    
    local item = ffi.new("Clay_LayoutElementHashMapItem")
    item.elementId = elementId
    item.layoutElement = layoutElement
    item.nextIndex = -1
    item.generation = context.generation + 1
    
    local hashBucket = elementId.id % context.layoutElementsHashMap.capacity
    local hashItemIndex = context.layoutElementsHashMap.internalArray[hashBucket]
    local hashItemPrevious = -1
    
    while hashItemIndex ~= -1 do
        local hashItem = context.layoutElementsHashMapInternal.internalArray + hashItemIndex
        if hashItem.elementId.id == elementId.id then
            item.nextIndex = hashItem.nextIndex
            if hashItem.generation <= context.generation then
                hashItem.elementId = elementId
                hashItem.generation = context.generation + 1
                hashItem.layoutElement = layoutElement
                hashItem.nextIndex = -1
            end
            return hashItem
        end
        hashItemPrevious = hashItemIndex
        hashItemIndex = hashItem.nextIndex
    end
    
    local newHashItem = context.layoutElementsHashMapInternal.internalArray + context.layoutElementsHashMapInternal.length
    newHashItem.elementId = item.elementId
    newHashItem.layoutElement = item.layoutElement
    newHashItem.nextIndex = item.nextIndex
    newHashItem.generation = item.generation
    newHashItem.onHoverFunction = nil
    newHashItem.hoverFunctionUserData = nil
    
    context.layoutElementsHashMapInternal.length = context.layoutElementsHashMapInternal.length + 1
    
    if hashItemPrevious ~= -1 then
        (context.layoutElementsHashMapInternal.internalArray + hashItemPrevious).nextIndex = context.layoutElementsHashMapInternal.length - 1
    else
        context.layoutElementsHashMap.internalArray[hashBucket] = context.layoutElementsHashMapInternal.length - 1
    end
    
    return newHashItem
end

local function Clay__GetHashMapItem(id)
    local hashBucket = id % context.layoutElementsHashMap.capacity
    local elementIndex = context.layoutElementsHashMap.internalArray[hashBucket]
    
    while elementIndex ~= -1 do
        local hashEntry = context.layoutElementsHashMapInternal.internalArray + elementIndex
        if hashEntry.elementId.id == id then
            return hashEntry
        end
        elementIndex = hashEntry.nextIndex
    end
    
    return nil
end

local function allocate_config_from_table(config_table)
    local config = ffi.new("Clay_LayoutConfig")
                
    if config_table.sizing then
        if config_table.sizing.width then
            config.sizing.width.type = config_table.sizing.width.type or Clay__SizingType.FIT
            if config_table.sizing.width.minMax then
                config.sizing.width.size.minMax.min = config_table.sizing.width.minMax.min or 0
                config.sizing.width.size.minMax.max = config_table.sizing.width.minMax.max or 0
            end
        end
        if config_table.sizing.height then
            config.sizing.height.type = config_table.sizing.height.type or Clay__SizingType.FIT
            if config_table.sizing.height.minMax then
                config.sizing.height.size.minMax.min = config_table.sizing.height.minMax.min or 0
                config.sizing.height.size.minMax.max = config_table.sizing.height.minMax.max or 0
            end
        end
    end
                    
    if config_table.padding then
        config.padding.left = config_table.padding.left or 0
        config.padding.right = config_table.padding.right or 0
        config.padding.top = config_table.padding.top or 0
        config.padding.bottom = config_table.padding.bottom or 0
    end
                    
    if config_table.childGap then
        config.childGap = config_table.childGap
    end
                    
    if config_table.childAlignment then
        config.childAlignment.x = config_table.childAlignment.x or 0
        config.childAlignment.y = config_table.childAlignment.y or 0
    end
                    
    if config_table.layoutDirection then
        config.layoutDirection = config_table.layoutDirection
    end
    
    return config
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
    if context.layoutElements.length <= 0 then
        return
    end
    
    local root_elem = context.layoutElements.internalArray + 0
    root_elem.dimensions.width = context.layoutDimensions.width
    root_elem.dimensions.height = context.layoutDimensions.height
    
    local position_x = 0
    local position_y = 0
    
    for i = 0, context.layoutElements.length - 1 do
        local elem = context.layoutElements.internalArray + i
        local config = elem.layoutConfig
        
        if i > 0 then
            local parent = context.layoutElements.internalArray + (i - 1)
            local dir = 0
            if config ~= nil then
                dir = config.layoutDirection
            else
                dir = parent.layoutConfig.layoutDirection
            end
                
            local child_width = calculate_sized_size(elem, parent.dimensions.width, 0)
            local child_height = calculate_sized_size(elem, parent.dimensions.height, 1)
            
            elem.dimensions.width = child_width
            elem.dimensions.height = child_height
        end
    end
    
    for i = 0, context.layoutElements.length - 1 do
        local elem = context.layoutElements.internalArray + i
        local config = elem.layoutConfig
        
        if config ~= nil then
            position_x = position_x + config.padding.left
            position_y = position_y + config.padding.top
        end
        
        local cmd = array_add(context.renderCommands, ffi.new("Clay_RenderCommand"))
        cmd.boundingBox.x = position_x
        cmd.boundingBox.y = position_y
        cmd.boundingBox.width = elem.dimensions.width
        cmd.boundingBox.height = elem.dimensions.height
        cmd.renderData.backgroundColor = ffi.new("Clay_Color", {r=200, g=200, b=200, a=255})
        cmd.text.length = 0
        cmd.text.chars = nil
        cmd.configId = 0
        cmd.id = elem.id
        
        if i > 0 then
            local parent = context.layoutElements.internalArray + (i - 1)
            local parent_config = parent.layoutConfig
            
            if parent_config ~= nil then
                local dir = parent_config.layoutDirection
                local gap = parent_config.childGap or 0
                
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

function M.initialize(capacity, dims)
    capacity = capacity or MAX_MEMORY
    arena_memory = ffi.new("uint8_t[?]", capacity)
    
    context = ffi.new("Clay_Context")
    context.internalArena.capacity = capacity
    context.internalArena.memory = arena_memory
    context.internalArena.nextAllocation = 0
    context.layoutDimensions.width = (dims and dims.width) or 800
    context.layoutDimensions.height = (dims and dims.height) or 600
    
    local max_elements = 8192
    local max_commands = 8192
    local max_stack = 512
    
    context.layoutElements.capacity = max_elements
    context.layoutElements.length = 0
    context.layoutElements.internalArray = Clay__Array_Allocate_Arena(max_elements, ffi.sizeof("Clay_LayoutElement"), context.internalArena)
    
    context.renderCommands.capacity = max_commands
    context.renderCommands.length = 0
    context.renderCommands.internalArray = Clay__Array_Allocate_Arena(max_commands, ffi.sizeof("Clay_RenderCommand"), context.internalArena)
    
    context.openLayoutElementStack.capacity = max_stack
    context.openLayoutElementStack.length = 0
    context.openLayoutElementStack.internalArray = Clay__Array_Allocate_Arena(max_stack, ffi.sizeof("int32_t"), context.internalArena)
    
    context.layoutElementsHashMapInternal.capacity = max_elements
    context.layoutElementsHashMapInternal.length = 0
    context.layoutElementsHashMapInternal.internalArray = ffi.cast("Clay_LayoutElementHashMapItem*", Clay__Array_Allocate_Arena(max_elements, ffi.sizeof("Clay_LayoutElementHashMapItem"), context.internalArena))
    
    context.layoutElementsHashMap.capacity = max_elements
    context.layoutElementsHashMap.length = 0
    context.layoutElementsHashMap.internalArray = ffi.cast("int32_t*", Clay__Array_Allocate_Arena(max_elements, ffi.sizeof("int32_t"), context.internalArena))
    
    for i = 0, max_elements - 1 do
        context.layoutElementsHashMap.internalArray[i] = -1
    end
    
    return context
end

function M.begin_layout()
    context.layoutElements.length = 0
    context.renderCommands.length = 0
    context.openLayoutElementStack.length = 0
    next_element_id = 1
    
    context.layoutDimensions.width = context.layoutDimensions.width or 800
    context.layoutDimensions.height = context.layoutDimensions.height or 600
end

function M.end_layout()
    calculate_layout()
    
    local result = ffi.new("Clay_RenderCommandArray")
    result.capacity = context.renderCommands.capacity
    result.length = context.renderCommands.length
    result.internalArray = context.renderCommands.internalArray
    
    return result
end

function M.open_element(config)
    if context.layoutElements.length >= context.layoutElements.capacity then
        error("Max layout elements exceeded")
    end
    
    local elem = array_add(context.layoutElements, ffi.new("Clay_LayoutElement"))
    elem.id = next_element_id
    next_element_id = next_element_id + 1
    elem.dimensions.width = 0
    elem.dimensions.height = 0
    elem.minDimensions.width = 0
    elem.minDimensions.height = 0
    elem.elementConfigs.length = 0
    
    if config ~= nil then
        if type(config) == "table" then
            elem.layoutConfig = allocate_config_from_table(config)
        elseif type(config) == "cdata" then
            elem.layoutConfig = config
        end
    end
    
    array_add(context.openLayoutElementStack, context.layoutElements.length - 1)
end

function M.close_element()
    if context.openLayoutElementStack.length <= 0 then
        error("Close element called with no open elements")
    end
    context.openLayoutElementStack.length = context.openLayoutElementStack.length - 1
end

function M.open_text_element(text, config)
    M.open_element(config)
    
    local len = context.layoutElements.length - 1
    if len >= 0 then
        local elem = context.layoutElements.internalArray + len
        
        if text and measure_text_fn then
            local dims = measure_text_fn(text, 16)
            elem.dimensions.width = dims.x
            elem.dimensions.height = dims.y
        elseif text and #text > 0 then
            elem.dimensions.width = #text * 10
            elem.dimensions.height = 20
        end
    end
end

function M.set_dimensions(width, height)
    context.layoutDimensions.width = width or 800
    context.layoutDimensions.height = height or 600
end

function M.set_measure_text(fn)
    measure_text_fn = fn
end

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
