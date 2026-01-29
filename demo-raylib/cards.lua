#!/usr/bin/env /usr/bin/env luajit
-- NOTE: Run this with raylua_s, not standard luajit!
-- Usage: ./raylib-lua/raylua_s main.lua

-- Add parent directory to package path to find llay
package.path = "../src/?.lua;" .. package.path

-- Load FFI for structs
local ffi = require("ffi")

-- llay is loaded via require (note: rl is provided by raylua_s)
local ok, llay = pcall(require, "init")
if not ok then
	print("Error loading llay:", llay)
	os.exit(1)
end

-- Colors helper (raylib Color struct)
local function Color(r, g, b, a)
	return ffi.new("Color", r, g, b, a or 255)
end

-- Window dimensions
local WINDOW_WIDTH = 1024
local WINDOW_HEIGHT = 768

-- Initialize raylib
rl.SetConfigFlags(rl.FLAG_VSYNC_HINT)
rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Llay + Raylib Demo")

-- Initialize llay with 16MB arena
llay.init(1024 * 1024 * 16, { width = WINDOW_WIDTH, height = WINDOW_HEIGHT })

-- Mock text measurement (Raylib text measurement is complex for now)
-- 10px wide per character, 20px height
llay.set_measure_text_function(function(text, config, userdata)
	return { width = #text * 10, height = 20 }
end)

-- Main loop
while not rl.WindowShouldClose() do
	-- Build layout
	llay.begin_layout()

	llay.Element({
		layout = {
			sizing = { width = "GROW", height = "GROW" },
			layoutDirection = llay.LayoutDirection.TOP_TO_BOTTOM,
			padding = { 20, 20, 20, 20 },
			childGap = 16,
		},
		backgroundColor = { r = 43, g = 43, b = 43, a = 255 },
	}, function()
		-- Title
		llay.Text("Llay + Raylib Demo", {
			fontSize = 32,
			color = { r = 220, g = 220, b = 220, a = 255 },
		})

		-- Subtitle
		llay.Text("Working!", {
			fontSize = 20,
			color = { r = 180, g = 220, b = 255, a = 255 },
		})

		-- Card row
		llay.Element({
			layout = {
				layoutDirection = llay.LayoutDirection.LEFT_TO_RIGHT,
				childGap = 16,
			},
		}, function()
			for i = 1, 3 do
				llay.Element({
					layout = {
						sizing = { width = "GROW", height = 150 },
						padding = { 16, 16, 16, 16 },
					},
					backgroundColor = { r = 60 + i * 20, g = 60 + i * 20, b = 100 + i * 20, a = 255 },
					cornerRadius = 8,
				}, function()
					llay.Text("Card " .. i, {
						fontSize = 18,
						color = { r = 255, g = 255, b = 255, a = 255 },
					})
				end)
			end
		end)
	end)

	local render_commands = llay.end_layout()

	-- Render with raylib
	rl.BeginDrawing()
	rl.ClearBackground(rl.RAYWHITE)

	for i = 0, render_commands.length - 1 do
		local cmd = render_commands.internalArray[i]
		local bounds = cmd.boundingBox

		-- Render rectangles
		if cmd.commandType == llay._core.Clay_RenderCommandType.RECTANGLE then
			local rect_data = cmd.renderData.rectangle
			local color = rect_data.backgroundColor

			rl.DrawRectangleRec(
				ffi.new("Rectangle", {
					x = bounds.x,
					y = bounds.y,
					width = bounds.width,
					height = bounds.height,
				}),
				Color(color.r, color.g, color.b, color.a)
			)
		end

		-- Render text
		if cmd.commandType == llay._core.Clay_RenderCommandType.TEXT then
			local text_data = cmd.renderData.text
			local text = ffi.string(text_data.stringContents.chars, text_data.stringContents.length)
			local color = text_data.textColor

			rl.DrawText(
				text,
				math.floor(bounds.x),
				math.floor(bounds.y),
				math.floor(bounds.height),
				Color(color.r, color.g, color.b, color.a)
			)
		end
	end

	rl.EndDrawing()
end

rl.CloseWindow()
