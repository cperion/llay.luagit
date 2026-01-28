#!/usr/bin/env luajit

package.path = package.path .. ";../src/?.lua;./sdl3-ffi/?.lua"

local ffi = require("ffi")
local sdl = require("sdl3_ffi")
local ttf = require("sdl3_ttf")

print("Initializing...")
assert(sdl.init(sdl.INIT_VIDEO))
print("SDL OK")
assert(ttf.init())
print("TTF OK")

local window = sdl.createWindow("Test", 400, 300, 0)
local renderer = sdl.createRenderer(window, nil)
print("Window OK")

local font = ttf.openFont("/usr/share/fonts/adwaita-sans-fonts/AdwaitaSans-Regular.ttf", 16)
print("Font:", font ~= nil)

-- Simple loop
local event = ffi.new("SDL_Event")
local running = true

while running do
	while sdl.pollEvent(event) do
		if event.type == sdl.EVENT_QUIT then
			running = false
		end
	end
	
	sdl.setRenderDrawColor(renderer, 43, 43, 43, 255)
	sdl.renderClear(renderer)
	
	-- Render some text
	local text = "Hello"
	local color = ffi.new("SDL_Color", 255, 255, 255, 255)
	local surface = ttf.renderTextBlended(font, text, #text, color)
	if surface ~= nil then
		local texture = sdl.createTextureFromSurface(renderer, surface)
		if texture ~= nil then
			local dest = ffi.new("SDL_FRect", 10, 10, surface.w, surface.h)
			sdl.renderTexture(renderer, texture, nil, dest)
			sdl.destroyTexture(texture)
		end
		sdl.destroySurface(surface)
	end
	
	sdl.renderPresent(renderer)
	sdl.delay(16)
end

ttf.closeFont(font)
sdl.destroyRenderer(renderer)
sdl.destroyWindow(window)
ttf.quit()
sdl.quit()

print("Done!")
