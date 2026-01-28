local ffi = require("ffi")
local core = require("core")
require("llay_ffi")

local M = {}

-- ==================================================================================
-- Render Callback Registry (for Custom drawing)
-- ==================================================================================

local _render_callbacks = {}

function M._reset_render_callbacks()
    for k in pairs(_render_callbacks) do _render_callbacks[k] = nil end
end

function M.get_render_callback(id)
    return _render_callbacks[id]
end

-- ==================================================================================
-- Enums & Constants
-- ==================================================================================
-- Re-exposing core enums for the API
M.LayoutDirection = { LEFT_TO_RIGHT = 0, TOP_TO_BOTTOM = 1 }
M.AlignX = { LEFT = 0, CENTER = 1, RIGHT = 2 }
M.AlignY = { TOP = 0, CENTER = 1, BOTTOM = 2 }
M.SizingType = { FIT = 0, GROW = 1, PERCENT = 2, FIXED = 3 }
M.TextWrap = { WORDS = 0, NEWLINES = 1, NONE = 2 }
M.PointerCapture = { CAPTURE = 0, PASSTHROUGH = 1 }
M.FloatingAttachToElement = { NONE = 0, PARENT = 1, ELEMENT_WITH_ID = 2, ROOT = 3 }
M.FloatingClipToElement = { NONE = 0, ATTACHED_PARENT = 1 }

-- ==================================================================================
-- Config Converters (Lua Table -> C Struct)
-- ==================================================================================

local function parse_sizing_axis(val)
	local axis = ffi.new("Clay_SizingAxis")
	if type(val) == "table" then
		if val.type then -- Manual definition
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
			-- Infer based on fields
			if val.percent then
				axis.type = M.SizingType.PERCENT
				axis.size.percent = val.percent
			elseif val.min or val.max then
				axis.type = M.SizingType.FIT -- Default if min/max provided without type? Usually implies FIT or GROW
				if val.fit then
					axis.type = M.SizingType.FIT
				end -- specific flag
				axis.size.minMax.min = val.min or 0
				axis.size.minMax.max = val.max or 0 -- 0 implies maxfloat usually handled in core
			end
		end
	elseif type(val) == "number" then
		axis.type = M.SizingType.FIXED
		axis.size.minMax.min = val
		axis.size.minMax.max = val
	elseif type(val) == "string" then
		if val == "GROW" then
			axis.type = M.SizingType.GROW
		elseif val == "FIT" then
			axis.type = M.SizingType.FIT
		end
	end
	return axis
end

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

local function parse_layout_config(tbl)
	local c = ffi.new("Clay_LayoutConfig")
	if not tbl then
		return c
	end

	if tbl.sizing then
		if tbl.sizing.width then
			c.sizing.width = parse_sizing_axis(tbl.sizing.width)
		end
		if tbl.sizing.height then
			c.sizing.height = parse_sizing_axis(tbl.sizing.height)
		end
	end

	if tbl.padding then
		c.padding = parse_padding(tbl.padding)
	end
	if tbl.childGap then
		c.childGap = tbl.childGap
	end

	if tbl.childAlignment then
		c.childAlignment.x = tbl.childAlignment.x or tbl.childAlignment[1] or M.AlignX.LEFT
		c.childAlignment.y = tbl.childAlignment.y or tbl.childAlignment[2] or M.AlignY.TOP
	end

	if tbl.layoutDirection then
		c.layoutDirection = tbl.layoutDirection
	end

	return c
end

local function parse_text_config(tbl)
	local c = ffi.new("Clay_TextElementConfig")
	c.textColor = parse_color(tbl.color or { 0, 0, 0, 255 })
	c.fontId = tbl.fontId or 0
	c.fontSize = tbl.fontSize or 24
	c.letterSpacing = tbl.letterSpacing or 0
	c.lineHeight = tbl.lineHeight or 0
	c.wrapMode = tbl.wrapMode or M.TextWrap.WORDS
	return c
end

local function parse_border_config(tbl)
	local b = ffi.new("Clay_BorderElementConfig")
	if not tbl then
		return b
	end
	if tbl.color then
		b.color = parse_color(tbl.color)
	end
	if tbl.width then
		if type(tbl.width) == "table" then
			b.width.left = tbl.width.left or tbl.width.x or 0
			b.width.right = tbl.width.right or tbl.width.x or 0
			b.width.top = tbl.width.top or tbl.width.y or 0
			b.width.bottom = tbl.width.bottom or tbl.width.y or 0
			b.width.betweenChildren = tbl.width.betweenChildren or 0
		else
			b.width.left = tbl.width
			b.width.right = tbl.width
			b.width.top = tbl.width
			b.width.bottom = tbl.width
		end
	end
	return b
end

local function parse_floating_config(tbl)
	local f = ffi.new("Clay_FloatingElementConfig")
	if not tbl then
		return f
	end
	if tbl.offset then
		f.offset = { x = tbl.offset.x or 0, y = tbl.offset.y or 0 }
	end
	if tbl.expand then
		f.expand = { width = tbl.expand.width or 0, height = tbl.expand.height or 0 }
	end
	f.parentId = tbl.parentId or 0
	f.zIndex = tbl.zIndex or 0
	f.attachPoints.element = tbl.attachPoints and tbl.attachPoints.element or 0
	f.attachPoints.parent = tbl.attachPoints and tbl.attachPoints.parent or 0
	f.pointerCaptureMode = tbl.pointerCaptureMode or M.PointerCapture.CAPTURE
	f.attachTo = tbl.attachTo or 0
	f.clipTo = tbl.clipTo or 0
	return f
end

local function parse_clip_config(tbl)
	local c = ffi.new("Clay_ClipElementConfig")
	if not tbl then
		return c
	end
	c.horizontal = tbl.horizontal or false
	c.vertical = tbl.vertical or false
	if tbl.childOffset then
		c.childOffset = { x = tbl.childOffset.x or 0, y = tbl.childOffset.y or 0 }
	end
	return c
end

local function parse_corner_radius(val)
	local c = ffi.new("Clay_CornerRadius")
	if type(val) == "number" then
		c.topLeft = val
		c.topRight = val
		c.bottomLeft = val
		c.bottomRight = val
	elseif type(val) == "table" then
		c.topLeft = val.topLeft or 0
		c.topRight = val.topRight or 0
		c.bottomLeft = val.bottomLeft or 0
		c.bottomRight = val.bottomRight or 0
	end
	return c
end

-- ==================================================================================
-- ID Helpers (mimic CLAY_ID() macros)
-- ==================================================================================

-- Standard ID
function M.ID(str)
	return core.Llay__GetElementId(str)
end

-- ID with Index (for loops)
function M.IDI(str, index)
	return core.Llay__HashStringWithOffset(str, index, 0)
end

-- Local ID (scoped to parent)
function M.ID_LOCAL(str)
	local parentId = core.get_parent_element_id()
	return core.Llay__HashStringWithOffset(str, 0, parentId)
end

-- Local ID with Index
function M.IDI_LOCAL(str, index)
	local parentId = core.get_parent_element_id()
	return core.Llay__HashStringWithOffset(str, index, parentId)
end

-- ==================================================================================
-- Element Constructors
-- ==================================================================================

function M.Element(arg1, arg2, arg3)
	-- Handle multiple patterns for compatibility:
	-- 1. CLAY(id, config) { children } -> Element(id, config, children_fn) - C API style
	-- 2. CLAY(config) { children } -> Element(config, children_fn) - Lua convenience style
	-- 3. Element(config) -> Element(config) - No children
	
	local id = nil
	local config = nil
	local children_fn = nil
	
	-- Pattern detection
	if type(arg1) == "table" and arg1.id ~= nil and type(arg1.id) == "number" then
		-- Pattern 1: First arg is Clay_ElementId
		id = arg1
		config = arg2
		children_fn = arg3
	elseif type(arg1) == "table" then
		-- Pattern 2 or 3: First arg is config table
		config = arg1
		children_fn = arg2
	end
	
	-- Parse config
	local declaration = ffi.new("Clay_ElementDeclaration")
	
	if config then
		local layout_config = parse_layout_config(config.layout)
		declaration.layout = layout_config
		declaration.backgroundColor = parse_color(config.backgroundColor)
		if config.cornerRadius then
			declaration.cornerRadius = parse_corner_radius(config.cornerRadius)
		end
		if config.border then
			declaration.border = parse_border_config(config.border)
		end
		if config.floating then
			declaration.floating = parse_floating_config(config.floating)
		end
		if config.clip then
			declaration.clip = parse_clip_config(config.clip)
		end

		local aspect_ratio = config.aspectRatio or (config.layout and config.layout.aspectRatio)
		if aspect_ratio and aspect_ratio ~= 0 then
			declaration.aspectRatio.aspectRatio = aspect_ratio
		end

		if config.image then
			declaration.image.imageData = config.image.imageData
		end

		if config.custom then
			declaration.custom.customData = config.custom.customData
		end
		if config.userData then
			declaration.userData = config.userData
		end
		
		-- Check if config has an id field (string) - convenience pattern
		if config.id and type(config.id) == "string" and not id then
			id = M.ID(config.id)
		end
	end

	-- Open element with or without ID
	if id then
		core.open_element_with_id(id)
	else
		core.open_element()
	end
	
	-- Auto-fill childOffset if clip is enabled but not provided
	-- This must happen AFTER open_element because get_scroll_offset() queries the open element
	local needsChildOffset = config.clip and (config.clip.childOffset == nil or type(config.clip.childOffset) == "function")
	if needsChildOffset then
		local offset
		if type(config.clip.childOffset) == "function" then
			offset = config.clip.childOffset()
		else
			offset = core.get_scroll_offset()
		end
		-- Update the already-created clip config
		declaration.clip.childOffset.x = offset.x or 0
		declaration.clip.childOffset.y = offset.y or 0
	end
	
	core.configure_open_element(declaration)

	if children_fn then
		children_fn()
	end

	core.close_element()
end

function M.Text(text, config)
	local textCfg = parse_text_config(config or {})
	-- Use the new core function
	core.open_text_element(text, textCfg)
end

function M.Custom(config, render_fn)
	local id_str = config.id or ("auto_cust_" .. tostring(#_render_callbacks))
	local id_obj = core.Llay__GetElementId(id_str)

	_render_callbacks[id_obj.id] = render_fn

	local declaration = ffi.new("Clay_ElementDeclaration")
	declaration.layout = parse_layout_config(config.layout or config)
	if config.backgroundColor then
		declaration.backgroundColor = parse_color(config.backgroundColor)
	end
	if config.cornerRadius then
		declaration.cornerRadius = parse_corner_radius(config.cornerRadius)
	end

	declaration.custom.customData = ffi.cast("void*", 1)

	core.open_element_with_id(id_obj)
	core.configure_open_element(declaration)
	core.close_element()
end

return M
