#!/usr/bin/env luajit

-- Multi-window SDL3 demo for Llay
-- Showcases SDL3's multi-window capability

-- Add paths for dependencies
package.path = package.path .. ";../src/?.lua;./sdl3-ffi/?.lua"

local ffi = require("ffi")
local sdl = require("sdl3_ffi")
local llay = require("init")

-- Window dimensions
local WINDOW_WIDTH = 800
local WINDOW_HEIGHT = 600

-- Initialize SDL3
assert(sdl.init(sdl.INIT_VIDEO), "SDL init failed")

-- Text measurement function for llay
local function measure_text(text_str, config)
	local font_size = config and config.fontSize or 16
	return { width = #text_str * (font_size * 0.6), height = font_size }
end

-- Initialize llay (shared for all windows)
llay.init(1024 * 1024 * 16, { width = WINDOW_WIDTH, height = WINDOW_HEIGHT })
llay.set_measure_text_function(measure_text)

-- Create multiple windows
local windows = {}

-- Window 1: Main UI
table.insert(windows, {
	window = sdl.createWindow("Window 1 - Main UI", WINDOW_WIDTH, WINDOW_HEIGHT, 0),
	color = { r = 43, g = 43, b = 43 },
	title = "Main UI",
	content = "This is window 1 - SDL3 multi-window demo!",
})

-- Window 2: Secondary Panel
table.insert(windows, {
	window = sdl.createWindow("Window 2 - Secondary Panel", WINDOW_WIDTH, WINDOW_HEIGHT, 0),
	color = { r = 30, g = 50, b = 70 },
	title = "Secondary Panel",
	content = "This is window 2 - independent layout!",
})

-- Position windows side by side
sdl.setWindowPosition(windows[1].window, 100, 100)
sdl.setWindowPosition(windows[2].window, 950, 100)

-- Create renderers for each window
for i, win_data in ipairs(windows) do
	assert(win_data.window ~= nil, "Failed to create window " .. i)
	win_data.renderer = sdl.createRenderer(win_data.window, nil)
	assert(win_data.renderer ~= nil, "Failed to create renderer " .. i)
end

-- Main loop
local running = true
local event = ffi.new("SDL_Event")

while running do
	-- Handle events
	while sdl.pollEvent(event) do
		if event.type == sdl.EVENT_QUIT then
			running = false
		elseif event.type == sdl.EVENT_WINDOW_CLOSE_REQUESTED then
			running = false
		end
	end

	-- Render each window
	for win_idx, win_data in ipairs(windows) do
		-- Build layout for this window
		llay.set_dimensions(WINDOW_WIDTH, WINDOW_HEIGHT)
		llay.begin_layout()

		llay.Element({
			layout = {
				sizing = { width = "GROW", height = "GROW" },
				layoutDirection = llay.LayoutDirection.TOP_TO_BOTTOM,
				padding = { 20, 20, 20, 20 },
				childGap = 16,
			},
			backgroundColor = win_data.color,
		}, function()
			-- Title
			llay.Text(win_data.title, {
				fontSize = 28,
				color = { r = 220, g = 220, b = 220, a = 255 },
			})

			-- Content
			llay.Text(win_data.content, {
				fontSize = 16,
				color = { r = 180, g = 180, b = 180, a = 255 },
			})

			-- Window number indicator
			llay.Element({
				layout = {
					sizing = { width = 200, height = 100 },
					padding = { 16, 16, 16, 16 },
					childAlignment = { llay.AlignX.CENTER, llay.AlignY.CENTER },
				},
				backgroundColor = { r = 80, g = 80, b = 120, a = 255 },
				cornerRadius = 12,
			}, function()
				llay.Text("Window " .. win_idx, {
					fontSize = 24,
					color = { r = 255, g = 255, b = 255, a = 255 },
				})
			end)

			-- SDL3 badge
			llay.Element({
				layout = {
					sizing = { width = 150, height = 60 },
					padding = { 12, 12, 12, 12 },
					childAlignment = { llay.AlignX.CENTER, llay.AlignY.CENTER },
				},
				backgroundColor = { r = 100, g = 150, b = 255, a = 255 },
				cornerRadius = 8,
			}, function()
				llay.Text("SDL3", {
					fontSize = 20,
					color = { r = 255, g = 255, b = 255, a = 255 },
				})
			end)
		end)

		local render_commands = llay.end_layout()

		-- Clear screen
		local c = win_data.color
		sdl.setRenderDrawColor(win_data.renderer, c.r, c.g, c.b, 255)
		sdl.renderClear(win_data.renderer)

		-- Render commands
		for i = 0, render_commands.length - 1 do
			local cmd = render_commands.internalArray[i]
			local bounds = cmd.boundingBox

			-- Draw rectangles
			if cmd.commandType == llay._core.Clay_RenderCommandType.RECTANGLE then
				local rect_data = cmd.renderData.rectangle
				local color = rect_data.backgroundColor

				sdl.setRenderDrawColor(win_data.renderer, color.r, color.g, color.b, color.a)

				local rect = ffi.new("SDL_FRect", {
					x = bounds.x,
					y = bounds.y,
					w = bounds.width,
					h = bounds.height,
				})
				sdl.renderFillRect(win_data.renderer, rect)
			end

			-- Draw text (simplified outline)
			if cmd.commandType == llay._core.Clay_RenderCommandType.TEXT then
				local text_data = cmd.renderData.text
				local color = text_data.textColor

				sdl.setRenderDrawColor(win_data.renderer, color.r, color.g, color.b, color.a)
				local text_rect = ffi.new("SDL_FRect", {
					x = bounds.x,
					y = bounds.y,
					w = bounds.width,
					h = bounds.height,
				})
				sdl.renderRect(win_data.renderer, text_rect)
			end
		end

		-- Present
		sdl.renderPresent(win_data.renderer)
	end

	-- Cap frame rate
	sdl.delay(16) -- ~60 FPS
end

-- Cleanup
for _, win_data in ipairs(windows) do
	sdl.destroyRenderer(win_data.renderer)
	sdl.destroyWindow(win_data.window)
end
sdl.quit()
