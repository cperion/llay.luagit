-- Modern Workspace Demo for Llay Layout Engine
-- Showcasing: Scrolling, Text Wrapping, Floating Elements, and Zero-GC UI logic.

local ffi = require("ffi")
local llay = require("init")

-- Theme Configuration
local COLORS = {
	BG_DARK = { 18, 18, 22, 255 },
	SIDEBAR = { 26, 27, 35, 255 },
	CARD = { 34, 36, 46, 255 },
	ACCENT = { 110, 120, 240, 255 },
	ACCENT_HOVER = { 130, 140, 255, 255 },
	TEXT = { 220, 225, 235, 255 },
	TEXT_DIM = { 140, 145, 160, 255 },
	BORDER = { 50, 55, 70, 255 },
}

local fonts = {}
local commands = nil
local screen_w, screen_h = 1024, 768
local scroll_dy = 0 -- Captured wheel delta

-- Mock Data
local tasks = {}
for i = 1, 20 do
	table.insert(tasks, {
		title = "Optimizing JIT Trace #" .. i,
		desc = "Investigate the guard failure in the hot loop of the spatial partitioner.",
		done = i % 3 == 0,
	})
end

-- 1. Correct Text Measurement
-- (Maps Llay fontIds to Love2D Font Objects)
local function love_measure_text(text, config)
	local font = fonts.default
	if config.fontId == 1 then
		font = fonts.bold
	elseif config.fontId == 2 then
		font = fonts.small
	end

	return {
		width = font:getWidth(text),
		height = font:getHeight(),
	}
end

function love.load()
	fonts.small = love.graphics.newFont(12)
	fonts.default = love.graphics.newFont(15)
	fonts.bold = love.graphics.newFont(15, "mono")
	fonts.title = love.graphics.newFont(22)

	llay.init(1024 * 1024 * 16) -- 16MB Arena
	llay.set_dimensions(screen_w, screen_h)
	llay.set_measure_text_function(love_measure_text)

	love.window.setMode(screen_w, screen_h, { resizable = true, vsync = true })
	love.window.setTitle("Llay Workspace Demo")
end

-- 2. Declarative UI Logic
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
				local is_hovered = llay.pointer_over("nav_" .. i)
				llay.Element({
					id = "nav_" .. i,
					layout = {
						sizing = { width = "GROW", height = 32 },
						childAlignment = { llay.AlignX.LEFT, llay.AlignY.CENTER },
						padding = { 10, 0, 0, 0 },
					},
					backgroundColor = is_hovered and COLORS.ACCENT or { 0, 0, 0, 0 },
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
					padding = { 0, 20, 0, 0 }, -- Right padding for scrollbar space
					childGap = 12,
				},
				clip = { vertical = true, horizontal = false },
			}, function()
				for i, task in ipairs(tasks) do
					llay.Element({
						id = "task_" .. i,
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
						-- Checkbox
						llay.Element({
							layout = { sizing = { width = 20, height = 20 } },
							backgroundColor = task.done and COLORS.ACCENT or { 0, 0, 0, 0 },
							cornerRadius = 4,
							border = { color = COLORS.ACCENT, width = 2 },
						})

						-- Labels
						llay.Element({
							layout = {
								sizing = { width = "GROW", height = "FIT" },
								layoutDirection = llay.LayoutDirection.TOP_TO_BOTTOM,
								childGap = 2,
							},
						}, function()
							llay.Text(task.title, { color = COLORS.TEXT, fontSize = 16, fontId = 1 })
							llay.Text(task.desc, { color = COLORS.TEXT_DIM, fontSize = 13 })
						end)
					end)
				end
			end)
		end)
	end)

	-- 3. Floating Element (Tooltip)
	if llay.pointer_over("nav_1") then
		llay.Element({
			layout = { sizing = { width = 180, height = "FIT" }, padding = 10 },
			backgroundColor = { 0, 0, 0, 220 },
			cornerRadius = 6,
			floating = {
				attachTo = llay.FloatingAttachToElement.ROOT,
				zIndex = 100,
				pointerCaptureMode = llay.PointerCapture.PASSTHROUGH,
				offset = { x = love.mouse.getX() + 15, y = love.mouse.getY() + 15 },
			},
		}, function()
			llay.Text("Click to view core engine architecture and JIT logs.", { color = COLORS.TEXT, fontSize = 12 })
		end)
	end

	commands = llay.end_layout()
end

function love.update(dt)
	-- 1. Sync pointer position
	llay.set_pointer_state(love.mouse.getX(), love.mouse.getY(), love.mouse.isDown(1))

	-- 2. Generate layout (this populates the hover states for the CURRENT frame)
	render_ui()

	-- 3. Update scroll momentum based on the layout we just generated
	llay.update_scroll_containers(true, 0, scroll_dy, dt)
	scroll_dy = 0
end

function love.draw()
	if not commands then
		return
	end

	for i = 0, commands.length - 1 do
		local cmd = commands.internalArray[i]
		local b = cmd.boundingBox

		if cmd.commandType == llay._core.Llay_RenderCommandType.RECTANGLE then
			local c = cmd.renderData.rectangle.backgroundColor
			local r = cmd.renderData.rectangle.cornerRadius
			love.graphics.setColor(c.r / 255, c.g / 255, c.b / 255, c.a / 255)
			love.graphics.rectangle(
				"fill",
				math.floor(b.x),
				math.floor(b.y),
				math.floor(b.width),
				math.floor(b.height),
				r.topLeft
			)
		elseif cmd.commandType == llay._core.Llay_RenderCommandType.BORDER then
			local c = cmd.renderData.border.color
			local r = cmd.renderData.border.cornerRadius
			local w = cmd.renderData.border.width
			love.graphics.setColor(c.r / 255, c.g / 255, c.b / 255, c.a / 255)
			love.graphics.setLineWidth(w.left)
			love.graphics.rectangle(
				"line",
				math.floor(b.x),
				math.floor(b.y),
				math.floor(b.width),
				math.floor(b.height),
				r.topLeft
			)
		elseif cmd.commandType == llay._core.Llay_RenderCommandType.TEXT then
			local d = cmd.renderData.text
			local c = d.textColor

			local font = fonts.default
			if d.fontId == 1 then
				font = fonts.bold
			elseif d.fontId == 2 then
				font = fonts.small
			end

			love.graphics.setFont(font)
			love.graphics.setColor(c.r / 255, c.g / 255, c.b / 255, c.a / 255)
			love.graphics.print(
				ffi.string(d.stringContents.chars, d.stringContents.length),
				math.floor(b.x),
				math.floor(b.y)
			)
		elseif cmd.commandType == llay._core.Llay_RenderCommandType.SCISSOR_START then
			love.graphics.setScissor(b.x, b.y, b.width, b.height)
		elseif cmd.commandType == llay._core.Llay_RenderCommandType.SCISSOR_END then
			love.graphics.setScissor()
		end
	end

	-- Debug Overlay
	love.graphics.setScissor()
	love.graphics.setColor(1, 1, 1, 0.5)
	love.graphics.setFont(fonts.small)
	love.graphics.print(
		string.format(
			"FPS: %d | Commands: %d | Memory: %.2f MB",
			love.timer.getFPS(),
			commands.length,
			collectgarbage("count") / 1024
		),
		10,
		screen_h - 20
	)
end

function love.wheelmoved(x, y)
	scroll_dy = y
end

function love.resize(w, h)
	screen_w, screen_h = w, h
	llay.set_dimensions(w, h)
end
