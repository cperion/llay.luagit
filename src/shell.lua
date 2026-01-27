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
-- Element Constructors
-- ==================================================================================

function M.Element(config, children_fn)
	local declaration = ffi.new("Clay_ElementDeclaration")

	declaration.layout = parse_layout_config(config.layout)
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

	if config.image then
		declaration.image.imageData = config.image.imageData
	end
	if config.custom then
		declaration.custom.customData = config.custom.customData
	end
	if config.userData then
		declaration.userData = config.userData
	end

	core.open_element()
	core.configure_open_element(declaration)

	if children_fn then
		children_fn()
	end

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
