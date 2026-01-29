-- Modern Workspace Demo for Llay Layout Engine (Raylib version)
-- Demonstrates: Scrolling, Text Wrapping, Floating Elements, Custom Rendering,
-- Capture API for interactions, and Zero-GC UI logic.

package.path = "../src/?.lua;" .. package.path

local ffi = require("ffi")
local llay = require("init")

-- ==================================================================================
-- Theme Configuration
-- ==================================================================================

local COLORS = {
	BG_DARK = { r = 18, g = 18, b = 22, a = 255 },
	SIDEBAR = { r = 26, g = 27, b = 35, a = 255 },
	CARD = { r = 34, g = 36, b = 46, a = 255 },
	ACCENT = { r = 110, g = 120, b = 240, a = 255 },
	ACCENT_HOVER = { r = 130, g = 140, b = 255, a = 255 },
	ACCENT_ACTIVE = { r = 90, g = 100, b = 220, a = 255 },
	TEXT = { r = 220, g = 225, b = 235, a = 255 },
	TEXT_DIM = { r = 140, g = 145, b = 160, a = 255 },
	BORDER = { r = 50, g = 55, b = 70, a = 255 },
	TOGGLE_ON = { r = 110, g = 200, b = 120, a = 255 },
	TOGGLE_OFF = { r = 60, g = 65, b = 75, a = 255 },
}

-- ==================================================================================
-- Raylib Helpers
-- ==================================================================================

local function Color(r, g, b, a)
	return ffi.new("Color", r, g, b, a or 255)
end

local temp_rect = ffi.new("Rectangle", { x = 0, y = 0, width = 0, height = 0 })
local temp_color = ffi.new("Color", { r = 0, g = 0, b = 0, a = 0 })
local scissor_stack = {}

local function ColorFromTable(c)
	temp_color.r = c.r
	temp_color.g = c.g
	temp_color.b = c.b
	temp_color.a = c.a
	return temp_color
end

local function iround(x)
	return math.floor(x + 0.5)
end

-- ==================================================================================
-- State
-- ==================================================================================

local commands = nil
local screen_w, screen_h = 1024, 768
local scroll_dy = 0
local last_gc_time = 0

-- Mock Data
local tasks = {}
local task_ids = {}
for i = 1, 20 do
	table.insert(tasks, {
		title = "Optimizing JIT Trace #" .. i,
		desc = "Investigate the guard failure in the hot loop of the spatial partitioner.",
		done = i % 3 == 0,
	})
	task_ids[i] = "task_" .. i
end

local nav_ids = { "nav_1", "nav_2", "nav_3", "nav_4" }

-- Toggle Widget State
local toggles = {}

-- ==================================================================================
-- Text Measurement
-- ==================================================================================

local function measure_text(text, config, userdata)
	local char_width = config.fontSize and config.fontSize / 1.5 or 10
	return {
		width = #text * char_width,
		height = config.fontSize or 20,
	}
end

-- ==================================================================================
-- Custom Toggle Widget using Custom Rendering
-- ==================================================================================

local function toggle(id, checked)
	if toggles[id] == nil then
		toggles[id] = checked
	end

	-- Get interaction state using capture API
	local is_hovered = llay.pointer_over(id)
	local is_captured = llay.is_captured(id)
	
	-- Visual states
	local bg_color = toggles[id] and COLORS.TOGGLE_ON or COLORS.TOGGLE_OFF
	if is_hovered and not toggles[id] then
		bg_color = { r = 80, g = 85, b = 95, a = 255 }
	end

	-- Build element with custom rendering
	llay.Custom({
		id = id,
		layout = { sizing = { width = 52, height = 28 } },
		backgroundColor = bg_color,
		cornerRadius = 14,
	}, function(rect, painter)
		local knob_x = toggles[id] and (rect.x + rect.width - 16) or (rect.x + 4)
		local knob_y = rect.y + rect.height / 2
		
		-- Draw knob
		painter:circle({ x = knob_x, y = knob_y }, 10, { r = 255, g = 255, b = 255, a = 255 })
		
		-- Draw hover glow
		if is_hovered then
			painter:circle({ x = knob_x, y = knob_y }, 12, { r = 255, g = 255, b = 255, a = 30 })
		end
	end)

	-- Handle interaction using capture API
	if is_hovered and rl.IsMouseButtonPressed(0) then
		llay.capture(id)
	end
	
	if is_captured and rl.IsMouseButtonReleased(0) then
		toggles[id] = not toggles[id]
		llay.release_capture()
	end

	return toggles[id]
end

-- ==================================================================================
-- UI Layout
-- ==================================================================================

local function render_ui()
	llay.begin_layout()

	-- Root Container
	llay.Element({
		layout = {
			sizing = { width = "GROW", height = "GROW" },
			layoutDirection = llay.LayoutDirection.LEFT_TO_RIGHT,
		},
		backgroundColor = COLORS.BG_DARK,
	}, function()
		-- SIDEBAR
		llay.Element({
			id = "sidebar",
			layout = {
				sizing = { width = 240, height = "GROW" },
				layoutDirection = llay.LayoutDirection.TOP_TO_BOTTOM,
				padding = { 20, 20, 30, 30 },
				childGap = 20,
			},
			backgroundColor = COLORS.SIDEBAR,
			border = { color = COLORS.BORDER, width = { right = 1 } },
		}, function()
			llay.Text("PROJECTS", { color = COLORS.TEXT_DIM, fontSize = 12, fontId = 1 })

			for i, name in ipairs({ "Core Engine", "UI Toolkit", "Network Layer", "Shaders" }) do
				local nav_id = nav_ids[i]
				local is_hovered = llay.pointer_over(nav_id)
				
				llay.Element({
					id = nav_id,
					layout = {
						sizing = { width = "GROW", height = 32 },
						childAlignment = { llay.AlignX.LEFT, llay.AlignY.CENTER },
						padding = { 10, 0, 0, 0 },
					},
					backgroundColor = is_hovered and COLORS.ACCENT or { r = 0, g = 0, b = 0, a = 0 },
					cornerRadius = 6,
				}, function()
					llay.Text(name, { color = COLORS.TEXT, fontSize = 15 })
				end)
			end
		end)

		-- MAIN CONTENT
		llay.Element({
			layout = {
				sizing = { width = "GROW", height = "GROW" },
				layoutDirection = llay.LayoutDirection.TOP_TO_BOTTOM,
				padding = { 40, 40, 40, 40 },
				childGap = 30,
			},
		}, function()
			-- Header
			llay.Element({
				layout = {
					sizing = { width = "GROW", height = "FIT" },
					layoutDirection = llay.LayoutDirection.TOP_TO_BOTTOM,
					childGap = 4,
				},
			}, function()
				llay.Text("Engineering Sprint", { color = COLORS.TEXT, fontSize = 28, fontId = 1 })
				llay.Text(
					"Active tasks for the current LuaJIT optimization phase.",
					{ color = COLORS.TEXT_DIM, fontSize = 14 }
				)
			end)

			-- Scrollable Task List
			llay.Element({
				id = "TaskListContainer",
				layout = {
					sizing = { width = "GROW", height = "GROW" },
					layoutDirection = llay.LayoutDirection.TOP_TO_BOTTOM,
					padding = { 0, 20, 0, 0 },
					childGap = 12,
				},
				clip = { vertical = true, horizontal = false },
			}, function()
				for i, task in ipairs(tasks) do
					llay.Element({
						id = task_ids[i],
						layout = {
							sizing = { width = "GROW", height = "FIT" },
							padding = { 16, 16, 16, 16 },
							layoutDirection = llay.LayoutDirection.LEFT_TO_RIGHT,
							childGap = 16,
							childAlignment = { nil, llay.AlignY.CENTER },
						},
						backgroundColor = COLORS.CARD,
						cornerRadius = 10,
						border = { color = COLORS.BORDER, width = 1 },
					}, function()
						-- Custom Toggle Widget
						local task_done = toggle("toggle_" .. i, task.done)

						-- Labels container
						llay.Element(llay.ID_LOCAL("labels"), {
							layout = {
								sizing = { width = "GROW", height = "FIT" },
								layoutDirection = llay.LayoutDirection.TOP_TO_BOTTOM,
								childGap = 2,
							},
						}, function()
							llay.Text(
								task.title,
								{ color = task_done and COLORS.TEXT_DIM or COLORS.TEXT, fontSize = 16, fontId = 1 }
							)
							llay.Text(task.desc, { color = COLORS.TEXT_DIM, fontSize = 13 })
						end)
					end)
				end
			end)
		end)
	end)

	-- Floating Element (Tooltip) - shows on hover
	if llay.pointer_over("nav_1") then
		local mouse_pos = rl.GetMousePosition()
		llay.Element(llay.ID("tooltip"), {
			layout = { sizing = { width = 180, height = "FIT" }, padding = 10 },
			backgroundColor = { r = 0, g = 0, b = 0, a = 220 },
			cornerRadius = 6,
			floating = {
				attachTo = llay.FloatingAttachToElement.ROOT,
				zIndex = 100,
				pointerCaptureMode = llay.PointerCapture.PASSTHROUGH,
				offset = { x = mouse_pos.x + 15, y = mouse_pos.y + 15 },
			},
		}, function()
			llay.Text("Click to view core engine architecture and JIT logs.", { color = COLORS.TEXT, fontSize = 12 })
		end)
	end

	commands = llay.end_layout()
end

-- ==================================================================================
-- Initialization
-- ==================================================================================

rl.SetConfigFlags(rl.FLAG_VSYNC_HINT)
rl.InitWindow(screen_w, screen_h, "Llay Workspace Demo - Raylib")

llay.init(1024 * 1024 * 16, { width = screen_w, height = screen_h })
llay.set_measure_text_function(measure_text)

-- ==================================================================================
-- Main Loop
-- ==================================================================================

while not rl.WindowShouldClose() do
	-- Handle window resize
	if rl.IsWindowResized() then
		screen_w = rl.GetScreenWidth()
		screen_h = rl.GetScreenHeight()
		llay.set_dimensions(screen_w, screen_h)
	end

	-- Handle scroll input
	local wheel = rl.GetMouseWheelMove()
	if wheel ~= 0 then
		scroll_dy = wheel * -30
	end

	-- Get pointer state
	local mouse_pos = rl.GetMousePosition()
	local mouse_down = rl.IsMouseButtonDown(0)

	-- Build UI
	render_ui()

	-- Update llay pointer state
	llay.set_pointer_state(mouse_pos.x, mouse_pos.y, mouse_down)

	-- Update scroll containers
	local scrolled = llay.update_scroll_containers(true, 0, scroll_dy, rl.GetFrameTime())
	scroll_dy = 0

	-- Rebuild if scrolled
	if scrolled then
		render_ui()
	end

	-- Periodic GC
	last_gc_time = last_gc_time + rl.GetFrameTime()
	if last_gc_time > 1.0 then
		collectgarbage("step", 100)
		last_gc_time = 0
	end

	-- ==================================================================================
	-- Render
	-- ==================================================================================

	rl.BeginDrawing()
	rl.ClearBackground(rl.RAYWHITE)

	-- Reset scissor state
	rl.EndScissorMode()
	for k in pairs(scissor_stack) do
		scissor_stack[k] = nil
	end

	-- Process render commands
	if commands then
		for i = 0, commands.length - 1 do
			local cmd = commands.internalArray[i]
			local b = cmd.boundingBox

			if cmd.commandType == llay._core.Llay_RenderCommandType.RECTANGLE then
				local c = cmd.renderData.rectangle.backgroundColor
				temp_rect.x = iround(b.x)
				temp_rect.y = iround(b.y)
				temp_rect.width = iround(b.width)
				temp_rect.height = iround(b.height)
				rl.DrawRectangleRec(temp_rect, ColorFromTable(c))
				
			elseif cmd.commandType == llay._core.Llay_RenderCommandType.BORDER then
				local c = cmd.renderData.border.color
				local w = cmd.renderData.border.width
				temp_rect.x = iround(b.x)
				temp_rect.y = iround(b.y)
				temp_rect.width = iround(b.width)
				temp_rect.height = iround(b.height)
				rl.DrawRectangleLinesEx(temp_rect, w.left or 1, ColorFromTable(c))
				
			elseif cmd.commandType == llay._core.Llay_RenderCommandType.TEXT then
				local d = cmd.renderData.text
				local c = d.textColor
				local text = ffi.string(d.stringContents.chars, d.stringContents.length)
				local font_size = d.fontSize or 20
				rl.DrawText(text, iround(b.x), iround(b.y), font_size, ColorFromTable(c))
				
			elseif cmd.commandType == llay._core.Llay_RenderCommandType.SCISSOR_START then
				table.insert(scissor_stack, { x = b.x, y = b.y, width = b.width, height = b.height })
				rl.BeginScissorMode(math.floor(b.x), math.floor(b.y), math.ceil(b.width), math.ceil(b.height))
				
			elseif cmd.commandType == llay._core.Llay_RenderCommandType.SCISSOR_END then
				table.remove(scissor_stack)
				if #scissor_stack > 0 then
					local prev = scissor_stack[#scissor_stack]
					rl.BeginScissorMode(prev.x, prev.y, prev.width, prev.height)
				else
					rl.EndScissorMode()
				end
				
			elseif cmd.commandType == llay._core.Llay_RenderCommandType.CUSTOM then
				local draw_fn = llay.get_render_callback(cmd.id)
				if draw_fn then
					local rect = { x = b.x, y = b.y, width = b.width, height = b.height }
					local painter = {
						rect = function(self, r, color, radius)
							temp_rect.x = iround(r.x)
							temp_rect.y = iround(r.y)
							temp_rect.width = iround(r.width)
							temp_rect.height = iround(r.height)
							rl.DrawRectangleRounded(
								temp_rect,
								(radius or 0) / math.max(r.width, r.height),
								4,
								ColorFromTable(color)
							)
						end,
						circle = function(self, center, radius, color)
							rl.DrawCircleV(
								ffi.new("Vector2", { x = center.x, y = center.y }),
								radius,
								ColorFromTable(color)
							)
						end,
					}
					draw_fn(rect, painter)
				end
			end
		end

		-- Safety cleanup
		rl.EndScissorMode()
		rl.DrawFPS(10, 10)
	end

	rl.EndDrawing()
end

rl.CloseWindow()
