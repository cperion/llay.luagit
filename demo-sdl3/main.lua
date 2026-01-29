#!/usr/bin/env luajit

-- Single-window SDL3 demo for Llay

print("DEBUG: Loading dependencies...")

-- Add paths for dependencies
package.path = package.path .. ";../src/?.lua;./sdl3-ffi/?.lua;./?.lua"

local ffi = require("ffi")
print("DEBUG: ffi loaded")

local sdl = require("sdl3_ffi")
print("DEBUG: sdl loaded")

local ttf = require("sdl3_ttf")
print("DEBUG: ttf loaded")

local llay = require("init")
print("DEBUG: llay loaded")

-- Window dimensions
local WINDOW_WIDTH = 1024
local WINDOW_HEIGHT = 768

print("DEBUG: Initializing SDL3...")
-- Initialize SDL3
assert(sdl.init(sdl.INIT_VIDEO), "SDL init failed")
print("DEBUG: SDL init OK")

print("DEBUG: Initializing SDL3_ttf...")
assert(ttf.init(), "SDL3_ttf init failed")
print("DEBUG: TTF init OK")

print("DEBUG: Creating window...")
-- Create window
local window = sdl.createWindow("Llay + SDL3 Demo", WINDOW_WIDTH, WINDOW_HEIGHT, 0)
assert(window ~= nil, "Failed to create window")
print("DEBUG: Window OK")

print("DEBUG: Creating renderer...")
-- Create renderer
local renderer = sdl.createRenderer(window, nil)
assert(renderer ~= nil, "Failed to create renderer")
print("DEBUG: Renderer OK")

print("DEBUG: Loading fonts...")
-- Load font
local font = ttf.openFont("/usr/share/fonts/adwaita-sans-fonts/AdwaitaSans-Regular.ttf", 16)
if font == nil then
	print("DEBUG: Trying alternative font...")
	-- Try alternative fonts
	font = ttf.openFont("/usr/share/fonts/google-carlito-fonts/Carlito-Regular.ttf", 16)
end
if font == nil then
	print("DEBUG: Trying another alternative font...")
	font = ttf.openFont("/usr/share/fonts/adwaita-mono-fonts/AdwaitaMono-Regular.ttf", 16)
end
assert(font ~= nil, "Failed to load font - tried AdwaitaSans, Carlito, AdwaitaMono")
print("DEBUG: Font OK")

print("DEBUG: Setting up text measurement...")
-- Text measurement function for llay
local function measure_text(text_str, config)
	local w_ptr = ffi.new("int[1]")
	local h_ptr = ffi.new("int[1]")
	local success = ttf.getStringSize(font, text_str, #text_str, w_ptr, h_ptr)
	if success then
		return { width = w_ptr[0], height = h_ptr[0] }
	else
		-- Fallback estimation
		return { width = #text_str * 10, height = 16 }
	end
end

print("DEBUG: Initializing llay...")
-- Initialize llay
llay.init(1024 * 1024 * 16, { width = WINDOW_WIDTH, height = WINDOW_HEIGHT }) -- 16MB arena
print("DEBUG: llay init OK")

print("DEBUG: Setting measure text function...")
llay.set_measure_text_function(measure_text)
print("DEBUG: Measure text function OK")

-- Test font measurement once
print("Testing font measurement...")
local test_w = ffi.new("int[1]")
local test_h = ffi.new("int[1]")
local ok = ttf.getStringSize(font, "Test", 4, test_w, test_h)
print("Font test result:", ok, test_w[0], test_h[0])

-- Helper to create SDL_Color
local function SDL_Color(r, g, b, a)
	return ffi.new("SDL_Color", r, g, b, a or 255)
end

-- Main loop
local running = true
local event = ffi.new("SDL_Event")
local frame_count = 0

print("DEBUG: Entering main loop...")

while running do
	-- Handle events
	while sdl.pollEvent(event) do
		if event.type == sdl.EVENT_QUIT then
			running = false
		elseif event.type == sdl.EVENT_WINDOW_CLOSE_REQUESTED then
			running = false
		end
	end

	if frame_count == 0 then
		print("DEBUG: Frame 0 - Building layout...")
	end

	-- Build layout
	llay.begin_layout()

	if frame_count == 0 then
		print("DEBUG: Frame 0 - Building element tree...")
	end

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
		llay.Text("Llay + SDL3 Demo", {
			fontSize = 32,
			color = { r = 220, g = 220, b = 220, a = 255 },
		})

		-- Subtitle
		llay.Text("Powered by SDL3 - The Latest!", {
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
					backgroundColor = { r = 60 + i * 10, g = 60 + i * 10, b = 100 + i * 10, a = 255 },
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

	if frame_count == 0 then
		print("DEBUG: Frame 0 - Ending layout...")
	end

	local render_commands = llay.end_layout()

	if frame_count == 0 then
		print("DEBUG: Frame 0 - Layout complete, commands:", render_commands and render_commands.length or "nil")
	end

	-- Clear screen
	sdl.setRenderDrawColor(renderer, 43, 43, 43, 255)
	sdl.renderClear(renderer)

	if frame_count == 0 then
		print("DEBUG: Frame 0 - Rendering commands...")
	end

	-- Render commands
	for i = 0, render_commands.length - 1 do
		local cmd = render_commands.internalArray[i]
		local bounds = cmd.boundingBox

		-- Draw rectangles
		if cmd.commandType == llay._core.Clay_RenderCommandType.RECTANGLE then
			local rect_data = cmd.renderData.rectangle
			local color = rect_data.backgroundColor

			sdl.setRenderDrawColor(renderer, color.r, color.g, color.b, color.a)

			local rect = ffi.new("SDL_FRect", {
				x = bounds.x,
				y = bounds.y,
				w = bounds.width,
				h = bounds.height,
			})
			sdl.renderFillRect(renderer, rect)
		end

		-- Draw text with SDL3_ttf
		if cmd.commandType == llay._core.Clay_RenderCommandType.TEXT then
			local text_data = cmd.renderData.text
			local text = ffi.string(text_data.stringContents.chars, text_data.stringContents.length)
			local color = text_data.textColor

			-- Render text to surface (SDL3 API: needs length parameter)
			local surface = ttf.renderTextBlended(font, text, #text, SDL_Color(color.r, color.g, color.b, color.a))
			if surface ~= nil then
				-- Create texture from surface
				local texture = sdl.createTextureFromSurface(renderer, surface)
				if texture ~= nil then
					local dest = ffi.new("SDL_FRect", {
						x = bounds.x,
						y = bounds.y,
						w = surface.w,
						h = surface.h,
					})
					sdl.renderTexture(renderer, texture, nil, dest)
					sdl.destroyTexture(texture)
				end
				sdl.destroySurface(surface)
			end
		end
	end

	if frame_count == 0 then
		print("DEBUG: Frame 0 - Presenting...")
	end

	-- Present
	sdl.renderPresent(renderer)

	-- Cap frame rate
	sdl.delay(16) -- ~60 FPS

	frame_count = frame_count + 1
	if frame_count == 5 then
		print("DEBUG: Frame 5 complete - running stable")
	end
end

-- Cleanup
ttf.closeFont(font)
sdl.destroyRenderer(renderer)
sdl.destroyWindow(window)
ttf.quit()
sdl.quit()
