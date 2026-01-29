#!/usr/bin/env /usr/bin/env luajit
-- Llay + Raylib Cards Demo
-- Simple demonstration of the Llay layout engine with Raylib backend.
-- Shows: Basic layout, cards, text rendering, and the capture API.

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

-- ==================================================================================
-- Colors Helper (raylib Color struct)
-- ==================================================================================

local function Color(r, g, b, a)
	return ffi.new("Color", r, g, b, a or 255)
end

-- ==================================================================================
-- Window Configuration
-- ==================================================================================

local WINDOW_WIDTH = 1024
local WINDOW_HEIGHT = 768

-- Initialize raylib
rl.SetConfigFlags(rl.FLAG_VSYNC_HINT)
rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Llay + Raylib Demo")

-- Initialize llay with 16MB arena
llay.init(1024 * 1024 * 16, { width = WINDOW_WIDTH, height = WINDOW_HEIGHT })

-- Mock text measurement (simplified for demo)
-- 10px wide per character, 20px height
llay.set_measure_text_function(function(text, config, userdata)
	return { width = #text * 10, height = 20 }
end)

-- ==================================================================================
-- Main Loop
-- ==================================================================================

while not rl.WindowShouldClose() do
	-- Handle window resize
	if rl.IsWindowResized() then
		WINDOW_WIDTH = rl.GetScreenWidth()
		WINDOW_HEIGHT = rl.GetScreenHeight()
		llay.set_dimensions(WINDOW_WIDTH, WINDOW_HEIGHT)
	end

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
		llay.Text("Capture API Demo - Click on cards!", {
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
				local card_id = "card_" .. i
				local is_hovered = llay.pointer_over(card_id)
				local is_captured = llay.is_captured(card_id)
				
				-- Change color based on interaction state
				local base_r, base_g, base_b = 60 + i * 20, 60 + i * 20, 100 + i * 20
				if is_captured then
					-- Darken when captured (mouse down)
					base_r, base_g, base_b = base_r - 30, base_g - 30, base_b - 30
				elseif is_hovered then
					-- Lighten when hovered
					base_r, base_g, base_b = base_r + 20, base_g + 20, base_b + 20
				end
				
				llay.Element({
					id = card_id,
					layout = {
						sizing = { width = "GROW", height = 150 },
						padding = { 16, 16, 16, 16 },
					},
					backgroundColor = { r = base_r, g = base_g, b = base_b, a = 255 },
					cornerRadius = 8,
				}, function()
					llay.Text("Card " .. i, {
						fontSize = 18,
						color = { r = 255, g = 255, b = 255, a = 255 },
					})
					if is_hovered then
						llay.Text("Hovered!", {
							fontSize = 14,
							color = { r = 200, g = 255, b = 200, a = 255 },
						})
					end
				end)
				
				-- Handle capture for this card
				if is_hovered and rl.IsMouseButtonPressed(0) then
					llay.capture(card_id)
				end
				if is_captured and rl.IsMouseButtonReleased(0) then
					print("Card " .. i .. " clicked!")
					llay.release_capture()
				end
			end
		end)
		
		-- Instructions
		llay.Element({
			layout = {
				sizing = { width = "GROW", height = "FIT" },
				padding = { 20, 20, 20, 20 },
			},
			backgroundColor = { r = 30, g = 30, b = 35, a = 255 },
			cornerRadius = 6,
		}, function()
			llay.Text("New Capture API Features:", {
				fontSize = 16,
				color = { r = 255, g = 255, b = 255, a = 255 },
			})
			llay.Text("- llay.capture(id) - Capture pointer for an element", {
				fontSize = 14,
				color = { r = 180, g = 180, b = 180, a = 255 },
			})
			llay.Text("- llay.release_capture() - Release captured element", {
				fontSize = 14,
				color = { r = 180, g = 180, b = 180, a = 255 },
			})
			llay.Text("- llay.is_captured(id) - Check if element is captured", {
				fontSize = 14,
				color = { r = 180, g = 180, b = 180, a = 255 },
			})
			llay.Text("- llay.pointer_over(id) - Check if pointer is over element", {
				fontSize = 14,
				color = { r = 180, g = 180, b = 180, a = 255 },
			})
		end)
	end)

	local render_commands = llay.end_layout()

	-- Update pointer state
	local mouse_pos = rl.GetMousePosition()
	local mouse_down = rl.IsMouseButtonDown(0)
	llay.set_pointer_state(mouse_pos.x, mouse_pos.y, mouse_down)

	-- ==================================================================================
	-- Render with raylib
	-- ==================================================================================

	rl.BeginDrawing()
	rl.ClearBackground(rl.RAYWHITE)

	for i = 0, render_commands.length - 1 do
		local cmd = render_commands.internalArray[i]
		local bounds = cmd.boundingBox

		-- Render rectangles
		if cmd.commandType == llay._core.Llay_RenderCommandType.RECTANGLE then
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
		if cmd.commandType == llay._core.Llay_RenderCommandType.TEXT then
			local text_data = cmd.renderData.text
			local text = ffi.string(text_data.stringContents.chars, text_data.stringContents.length)
			local color = text_data.textColor

			rl.DrawText(
				text,
				math.floor(bounds.x),
				math.floor(bounds.y),
				math.floor(text_data.fontSize),
				Color(color.r, color.g, color.b, color.a)
			)
		end
	end

	rl.EndDrawing()
end

rl.CloseWindow()
