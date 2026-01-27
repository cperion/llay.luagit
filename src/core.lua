-- core.lua - Core layer (C-like, replaces CLAY_IMPLEMENTATION)
-- This module contains the actual layout engine implementation

local ffi = require("ffi")
require("clay_ffi")  -- Load Clay FFI definitions

local bit = require("bit")
local band, bor = bit.band, bit.bor

local min, max = math.min, math.max

local M = {}

-- Constants from clay.h enums
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

local Clay_LayoutAlignmentX = {
    LEFT = 0,
    RIGHT = 1,
    CENTER = 2,
}

local Clay_LayoutAlignmentY = {
    TOP = 0,
    BOTTOM = 1,
    CENTER = 2,
}

-- Global context
local MAX_MEMORY = 1024 * 1024
local arena_memory = ffi.new("uint8_t[?]", MAX_MEMORY)
local arena = ffi.new("Clay_Arena")
arena.memory = arena_memory
arena.capacity = MAX_MEMORY
arena.nextAllocation = ffi.cast("uintptr_t", arena_memory)

-- Context struct (TODO: fill in fields from clay.h)
local context = {
    internalArena = arena,
    layoutDimensions = ffi.new("Clay_Dimensions", {width=800, height=600}),
}

-- Memory management
function M.allocate(size, alignment)
    local next = context.internalArena.nextAllocation
    local aligned = band(next + alignment - 1, -alignment)
    context.internalArena.nextAllocation = aligned + size
    
    if ffi.cast("uintptr_t", context.internalArena.nextAllocation) > 
       ffi.cast("uintptr_t", context.internalArena.memory) + context.internalArena.capacity then
        error("Arena capacity exceeded")
    end
    
    return ffi.cast("void*", aligned)
end

-- Math helpers (ported from clay.h)
local function CLAY__MAX(x, y)
    return x > y and x or y
end

local function CLAY__MIN(x, y)
    return x < y and x or y
end

-- Public API (TODO: implement)
function M.initialize(capacity, dimensions)
    -- TODO: Initialize context with given capacity and dimensions
    return context
end

function M.begin_layout()
    -- TODO: Begin layout calculation
end

function M.end_layout()
    -- TODO: End layout and return render commands
    return ffi.new("Clay_RenderCommandArray")
end

function M.open_element(config)
    -- TODO: Open element with config
end

function M.close_element()
    -- TODO: Close current element
end

function M.open_text_element(text, config)
    -- TODO: Open text element
end

function M.set_dimensions(width, height)
    context.layoutDimensions.width = width
    context.layoutDimensions.height = height
end

function M.set_measure_text(fn)
    -- TODO: Set text measurement callback
end

-- Internal helpers (TODO: implement)
function M.hash_string(string, seed)
    -- TODO: Hash string (scalar version from clay.h)
    return 0
end

M.__SizingType = Clay__SizingType
M.__LayoutDirection = Clay_LayoutDirection

return M
