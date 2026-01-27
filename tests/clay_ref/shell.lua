-- C Reference Shell Wrapper
-- Mirrors the Lua shell.lua API but calls the C library functions
local ffi = require("ffi")
local clay_c, c_measure_callback = require("tests.clay_ref.init")

local clay_shell = {}

-- Re-expose enums from clay_ffi
require("src.clay_ffi")
local Clay_LayoutDirection = { LEFT_TO_RIGHT = 0, TOP_TO_BOTTOM = 1 }
local Clay_AlignX = { LEFT = 0, CENTER = 1, RIGHT = 2 }
local Clay_AlignY = { TOP = 0, CENTER = 1, BOTTOM = 2 }
local Clay__SizingType = { FIT = 0, GROW = 1, PERCENT = 2, FIXED = 3 }
local Clay_TextElementConfigWrapMode = { WORDS = 0, NEWLINES = 1, NONE = 2 }
local Clay_TextAlignment = { LEFT = 0, CENTER = 1, RIGHT = 2 }

-- Expose as shell properties
clay_shell.LayoutDirection = Clay_LayoutDirection
clay_shell.AlignX = Clay_AlignX
clay_shell.AlignY = Clay_AlignY
clay_shell.SizingType = Clay__SizingType
clay_shell.TextWrap = Clay_TextElementConfigWrapMode

-- Initialize once
local c_initialized = false
local c_arena_memory = nil
local c_arena = nil

-- Parse sizing axis from Lua table to Clay_SizingAxis
local function parse_sizing_axis(val)
    local axis = ffi.new("Clay_SizingAxis")
    if type(val) == "table" then
        if val.type then
            axis.type = val.type
            if val.min then
                axis.size.minMax.min = val.min
            end
            if val.max then
                axis.size.minMax.max = val.max
            end
            if val.percent then
                axis.size.percent = val.percent
            end
        else
            if val.percent then
                axis.type = Clay__SizingType.PERCENT
                axis.size.percent = val.percent
            elseif val.min or val.max then
                axis.type = Clay__SizingType.FIT
                axis.size.minMax.min = val.min or 0
                axis.size.minMax.max = val.max or 0
            end
        end
    elseif type(val) == "number" then
        axis.type = Clay__SizingType.FIXED
        axis.size.minMax.min = val
        axis.size.minMax.max = val
    elseif type(val) == "string" then
        if val == "GROW" then
            axis.type = Clay__SizingType.GROW
        elseif val == "FIT" then
            axis.type = Clay__SizingType.FIT
        end
    end
    return axis
end

-- Parse padding from Lua table to Clay_Padding
local function parse_padding(val)
    local p = ffi.new("Clay_Padding")
    if type(val) == "table" then
        p.left = val.left or val.x or val[1] or 0
        p.right = val.right or val.x or val[2] or 0
        p.top = val.top or val.y or val[3] or 0
        p.bottom = val.bottom or val.y or val[4] or 0
    elseif type(val) == "number" then
        p.left = val
        p.right = val
        p.top = val
        p.bottom = val
    end
    return p
end

-- Parse color from Lua table to Clay_Color
local function parse_color(val)
    local c = ffi.new("Clay_Color")
    if val then
        c.r = val[1] or val.r or 0
        c.g = val[2] or val.g or 0
        c.b = val[3] or val.b or 0
        c.a = val[4] or val.a or 255
    end
    return c
end

-- Parse corner radius from Lua table to Clay_CornerRadius
local function parse_corner_radius(val)
    local cr = ffi.new("Clay_CornerRadius")
    if type(val) == "table" then
        cr.topLeft = val.topLeft or val[1] or 0
        cr.topRight = val.topRight or val[2] or 0
        cr.bottomLeft = val.bottomLeft or val[3] or 0
        cr.bottomRight = val.bottomRight or val[4] or 0
    else
        cr.topLeft = 0
        cr.topRight = 0
        cr.bottomLeft = 0
        cr.bottomRight = 0
    end
    return cr
end

-- Parse border config
local function parse_border(val)
    local border = ffi.new("Clay_BorderElementConfig")
    if val then
        if val.color then
            border.color = parse_color(val.color)
        end
        if val.width then
            border.width.left = val.width.left or val.width[1] or val.width or 0
            border.width.right = val.width.right or val.width[2] or val.width or 0
            border.width.top = val.width.top or val.width[3] or val.width or 0
            border.width.bottom = val.width.bottom or val.width[4] or val.width or 0
        end
        border.width.betweenChildren = val.betweenChildren or 0
    end
    return border
end

-- Build an element declaration from a Lua config table
local function build_declaration(config)
    local decl = ffi.new("Clay_ElementDeclaration")
    
    -- Layout config
    if config.layout then
        local l = config.layout
        decl.layout.layoutDirection = l.layoutDirection or 0
        decl.layout.childGap = l.childGap or 0
        decl.layout.padding = parse_padding(l.padding or 0)
        
        if l.childAlignment then
            decl.layout.childAlignment.x = l.childAlignment[1] or l.childAlignment.x or 0
            decl.layout.childAlignment.y = l.childAlignment[2] or l.childAlignment.y or 0
        else
            decl.layout.childAlignment.x = 0
            decl.layout.childAlignment.y = 0
        end
        
        if l.sizing then
            decl.layout.sizing.width = parse_sizing_axis(l.sizing.width or l.sizing)
            decl.layout.sizing.height = parse_sizing_axis(l.sizing.height or l.sizing)
        else
            decl.layout.sizing.width = parse_sizing_axis(l.sizing)
            decl.layout.sizing.height = parse_sizing_axis(l.sizing)
        end
    end
    
    -- Colors and styling
    decl.backgroundColor = parse_color(config.backgroundColor)
    decl.cornerRadius = parse_corner_radius(config.cornerRadius)
    
    -- Border
    if config.border then
        decl.border = parse_border(config.border)
    else
        decl.border.width.left = 0
        decl.border.width.right = 0
        decl.border.width.top = 0
        decl.border.width.bottom = 0
    end
    
    -- Custom data
    decl.custom.customData = config.custom and (config.custom.customData or nil) or nil
    
    -- Clip
    if config.clip then
        decl.clip.horizontal = config.clip.horizontal or false
        decl.clip.vertical = config.clip.vertical or false
    end
    
    -- Other configs (initialized to defaults)
    decl.aspectRatio.aspectRatio = 0
    decl.floating.attachTo = 0
    decl.floating.zIndex = 0
    decl.image.imageData = nil
    
    decl.userData = config.userData or nil
    
    return decl
end

-- Public API functions
function clay_shell.begin_layout()
    if not c_initialized then
        error("Clay C not initialized! Call clay_shell.init() first")
    end
    clay_c.Clay_BeginLayout()
end

function clay_shell.end_layout()
    if not c_initialized then
        error("Clay C not initialized! Call clay_shell.init() first")
    end
    return clay_c.Clay_EndLayout()
end

function clay_shell.set_dimensions(w, h)
    if not c_initialized then
        error("Clay C not initialized! Call clay_shell.init() first")
    end
    clay_c.Clay_SetLayoutDimensions(ffi.new("Clay_Dimensions", { width = w, height = h }))
end

function clay_shell.set_measure_text(fn)
    -- This is set once during initialization
end

-- Initialize the C library
function clay_shell.init()
    if c_initialized then
        return
    end
    
    -- Get minimum memory size required
    print("Getting minimum memory size...")
    local min_memory = clay_c.Clay_MinMemorySize()
    print("Minimum memory required: " .. tostring(min_memory) .. " bytes")
    
    -- Create arena with appropriate size
    local C_ARENA_SIZE = min_memory + 4096 -- Add some buffer
    c_arena_memory = ffi.new("uint8_t[?]", C_ARENA_SIZE)
    c_arena = ffi.new("Clay_Arena", {
        memory = c_arena_memory,
        capacity = C_ARENA_SIZE,
        nextAllocation = 0
    })
    
    -- Create dimensions
    local c_dimensions = ffi.new("Clay_Dimensions", { width = 800, height = 600 })
    
    -- Initialize Clay (error handler is optional, pass empty struct)
    local error_handler = ffi.new("Clay_ErrorHandler")
    local c_context = clay_c.Clay_Initialize(c_arena, c_dimensions, error_handler)
    
    if c_context == nil then
        error("Clay_Initialize returned NULL")
    end
    
    print("Clay initialized successfully!")
    
    -- Set measure text callback
    clay_c.Clay_SetMeasureTextFunction(c_measure_callback, nil)
    
    c_initialized = true
end

-- Element API
function clay_shell.Element(config, children_fn)
    clay_c.Clay__OpenElement()
    clay_c.Clay__ConfigureOpenElementPtr(build_declaration(config))
    
    if children_fn then
        children_fn()
    end
    
    clay_c.Clay__CloseElement()
end

-- Text element
function clay_shell.Text(text, config)
    clay_c.Clay__OpenElement()
    clay_c.Clay__ConfigureOpenElementPtr(build_declaration(config or {}))
    
    -- We need to set up text content - this requires special handling
    -- For now, skip text in C wrapper
    -- clay_c.Clay__OpenTextElement(...)
    
    clay_c.Clay__CloseElement()
end

-- Forward compatible: allow calling clay_shell directly as the API
return clay_shell
