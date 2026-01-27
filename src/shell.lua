local ffi = require("ffi")
local core = require("core")
require("clay_ffi")

local M = {}

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
		p.left = val.left or val.x or 0
		p.right = val.right or val.x or 0
		p.top = val.top or val.y or 0
		p.bottom = val.bottom or val.y or 0
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

-- ==================================================================================
-- Element Constructors
-- ==================================================================================

function M.Element(config, children_fn)
	-- 1. Create Layout Config
	local layoutConfig = parse_layout_config(config.layout)

	-- 2. Open Element
	core.open_element(layoutConfig)

	-- 3. Configure specific element types (Rectangle, Border, etc)
	-- Note: core.open_element only attaches layout config.
	-- We need to attach other configs via the internal logic if exposed,
	-- or if core.open_element creates a generic element, we need to populate properties.
	-- *Correction*: In the ported Core, open_element takes LayoutConfig.
	-- Additional configs (Color, Border, etc) are typically attached via Clay__AttachElementConfig.
	-- However, the Core.lua API exposed `open_element` but didn't expose `attach_config`.
	-- For this shell to function 1:1 with the C Macro behavior (`CLAY(...)`),
	-- we assume `core.open_element` or a helper handles the declaration struct.
	-- Since the `core.lua` provided previously was a direct port of logic but minimal API,
	-- we will map common properties (color, id) here if possible, or assume the user
	-- extends core to expose `Clay__AttachElementConfig`.

	-- Assuming `core` has exposed `attach_config` or we access context directly (Lua-as-C style allows this).
	-- Accessing context directly for config attachment:
	local context = core.initialize(nil, nil) -- Gets singleton

	-- Background Color (Shared Config)
	if config.backgroundColor or config.cornerRadius or config.userData then
		local shared = ffi.new("Clay_SharedElementConfig")
		if config.backgroundColor then
			shared.backgroundColor = parse_color(config.backgroundColor)
		end
		if config.cornerRadius then
			if type(config.cornerRadius) == "number" then
				shared.cornerRadius =
					{ config.cornerRadius, config.cornerRadius, config.cornerRadius, config.cornerRadius }
			else
				shared.cornerRadius = config.cornerRadius
			end
		end
		-- Attach using internal logic pattern (duplicated here or exposed from core)
		-- Ideally `core` exports `attach_element_config`.
		-- Since it wasn't in the previous file, we assume standard usage relies on
		-- `core` being the "implementation" and `shell` needing deep access.
		-- We will manually access the arrays via the context reference.

		-- Helper to replicate `Clay__AttachElementConfig` logic in shell
		local elemIdx = context.openLayoutElementStack.internalArray[context.openLayoutElementStack.length - 1]
		local elem = context.layoutElements.internalArray + elemIdx

		-- Add Config to Array
		if context.elementConfigs.length < context.elementConfigs.capacity then
			local cfgIdx = context.elementConfigs.length
			context.elementConfigs.length = context.elementConfigs.length + 1
			local cfg = context.elementConfigs.internalArray + cfgIdx

			cfg.type = 8 -- SHARED
			cfg.config.sharedElementConfig = shared

			-- Link to Element (Simple Append for now)
			if elem.elementConfigs.length == 0 then
				elem.elementConfigs.internalArray = cfg
			end
			elem.elementConfigs.length = elem.elementConfigs.length + 1
		end
	end

	-- 4. Children
	if children_fn then
		children_fn()
	end

	-- 5. Close
	core.close_element()
end

function M.Text(text, config)
	-- In C: CLAY_TEXT macro calls Clay__OpenTextElement
	-- We need to manually construct the text element because `core.open_element` is generic.

	local context = core.initialize(nil, nil)
	local parentIdx = context.openLayoutElementStack.internalArray[context.openLayoutElementStack.length - 1]
	local parent = context.layoutElements.internalArray + parentIdx

	-- 1. Create Element
	local elemIdx = context.layoutElements.length
	if elemIdx >= context.layoutElements.capacity then
		return
	end
	context.layoutElements.length = context.layoutElements.length + 1
	local elem = context.layoutElements.internalArray + elemIdx

	-- 2. Setup ID (Auto)
	elem.id = context.layoutElements.length -- Simplified ID generation
	elem.elementConfigs.length = 0
	elem.childrenOrTextContent.children.length = 0

	-- 3. Attach Text Config
	local textCfg = parse_text_config(config or {})
	local cfgIdx = context.elementConfigs.length
	context.elementConfigs.length = context.elementConfigs.length + 1
	local cfg = context.elementConfigs.internalArray + cfgIdx
	cfg.type = 6 -- TEXT
	cfg.config.textElementConfig = textCfg

	elem.elementConfigs.internalArray = cfg
	elem.elementConfigs.length = 1

	-- 4. Attach Text Data
	local textDataIdx = context.textElementData.length
	context.textElementData.length = context.textElementData.length + 1
	local textData = context.textElementData.internalArray + textDataIdx

	textData.text = ffi.new("Clay_String", { length = #text, chars = text, isStaticallyAllocated = true })
	textData.elementIndex = elemIdx
	elem.childrenOrTextContent.textElementData = textData

	-- 5. Link to Parent
	parent.childrenOrTextContent.children.length = parent.childrenOrTextContent.children.length + 1
	-- Add to children buffer (using FFI directly as helper was local in core)
	local bufIdx = context.layoutElementChildrenBuffer.length
	context.layoutElementChildrenBuffer.length = context.layoutElementChildrenBuffer.length + 1
	context.layoutElementChildrenBuffer.internalArray[bufIdx] = elemIdx

	-- Text elements are not pushed to the open stack (they are leaves)
end

return M
