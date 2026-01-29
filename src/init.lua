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
	shell._reset_render_callbacks()
	core.begin_layout()
end

function M.end_layout()
	return core.end_layout()
end

function M.set_dimensions(width, height)
	core.set_dimensions(width, height)
end

function M.set_culling_enabled(enabled)
	core.set_culling_enabled(enabled)
end

function M.set_debug_mode_enabled(enabled)
	core.set_debug_mode_enabled(enabled)
end

function M.set_max_element_count(count)
	core.set_max_element_count(count)
end

function M.get_element_data(id_variant)
	local id
	if type(id_variant) == "string" then
		id = core.Llay__GetElementId(id_variant).id
	elseif type(id_variant) == "table" or type(id_variant) == "cdata" then
		id = id_variant.id
	else
		id = id_variant
	end
	return core.get_element_data(id)
end

function M.hovered()
	return core.hovered()
end

function M.set_measure_text_function(fn, userData)
	core.set_measure_text(fn, userData)
end

function M.set_query_scroll_offset_function(fn, userData)
	core.set_query_scroll_offset(fn, userData)
end

-- ==================================================================================
-- Declarative API
-- ==================================================================================

-- Maps to CLAY(...) macro
M.Element = shell.Element

-- Maps to CLAY_TEXT(...) macro
M.Text = shell.Text

-- Custom element with render callback for framework rendering
M.Custom = shell.Custom

-- ==================================================================================
-- Constants & Enums
-- ==================================================================================

M.LayoutDirection = shell.LayoutDirection
M.AlignX = shell.AlignX
M.AlignY = shell.AlignY
M.SizingType = shell.SizingType
M.TextWrap = shell.TextWrap
M.PointerCapture = shell.PointerCapture
M.FloatingAttachToElement = shell.FloatingAttachToElement
M.FloatingClipToElement = shell.FloatingClipToElement

-- ==================================================================================
-- Interaction API
-- ==================================================================================

function M.set_pointer_state(x, y, is_down)
	core.set_pointer_state({ x = x, y = y }, is_down)
end

function M.update_scroll_containers(enable_drag, dx, dy, dt)
	return core.update_scroll_containers(enable_drag, { x = dx, y = dy }, dt)
end

-- ==================================================================================
-- Capture API - Deep module for input capture management
-- ==================================================================================

function M.capture(element_id)
	return core.capture(element_id)
end

function M.release_capture()
	return core.release_capture()
end

function M.get_capture()
	return core.get_capture()
end

function M.is_captured(element_id)
	return core.is_captured(element_id)
end

function M.hit_test(x, y)
	return core.hit_test(x, y)
end

function M.pointer_over(id_string)
	local id = core.Llay__GetElementId(id_string)
	return core.pointer_over(id.id)
end

-- Hashing helper for IDs
function M.ID(str)
	return core.Llay__GetElementId(str)
end

function M.IDI(str, index)
	return shell.IDI(str, index)
end

function M.ID_LOCAL(str)
	return shell.ID_LOCAL(str)
end

function M.IDI_LOCAL(str, index)
	return shell.IDI_LOCAL(str, index)
end

function M.get_render_callback(id)
	return shell.get_render_callback(id)
end

function M.sort_z_order()
	core.sort_roots_by_z()
end

function M.get_scroll_offset()
	return core.get_scroll_offset()
end

-- Pointer Interaction Helpers
function M.on_hover(fn, userData)
	-- This allows: llay.on_hover(function(id, pointer, data) ... end, myData)
	local openElement = core._get_open_element()
	if openElement then
		local hashMapItem = core._get_hash_map_item(openElement.id)
		if hashMapItem then
			hashMapItem.onHoverFunction = fn
			hashMapItem.hoverFunctionUserData = userData
		end
	end
end

-- ==================================================================================
-- Debug / Internals
-- ==================================================================================

M._core = core

return M
