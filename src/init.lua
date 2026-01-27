local core = require("core")
local shell = require("shell")

local M = {}

-- ==================================================================================
-- Lifecycle API
-- ==================================================================================

function M.init(capacity, dims)
	-- Helper to handle optional args
	if type(capacity) == "table" and dims == nil then
		dims = capacity
		capacity = nil
	end
	return core.initialize(capacity, dims)
end

M.initialize = M.init

function M.begin_layout()
	core.begin_layout()
end

function M.end_layout()
	return core.end_layout()
end

function M.set_dimensions(width, height)
	core.set_dimensions(width, height)
end

function M.set_measure_text_function(fn)
	core.set_measure_text(fn)
end

-- ==================================================================================
-- Declarative API
-- ==================================================================================

-- Maps to CLAY(...) macro
M.Element = shell.Element

-- Maps to CLAY_TEXT(...) macro
M.Text = shell.Text

-- ==================================================================================
-- Constants & Enums
-- ==================================================================================

M.LayoutDirection = shell.LayoutDirection
M.AlignX = shell.AlignX
M.AlignY = shell.AlignY
M.SizingType = shell.SizingType
M.TextWrap = shell.TextWrap
M.PointerCapture = shell.PointerCapture

-- ==================================================================================
-- Debug / Internals
-- ==================================================================================

M._core = core

return M
