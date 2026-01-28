#!/usr/bin/env luajit

-- Minimal SDL3_ttf test
package.path = package.path .. ";./sdl3-ffi/?.lua"

local ffi = require("ffi")
local sdl = require("sdl3_ffi")
local ttf = require("sdl3_ttf")

print("1. Initializing SDL3...")
local sdl_ok = sdl.init(sdl.INIT_VIDEO)
print("   SDL init:", sdl_ok)

print("2. Initializing SDL3_ttf...")
local ttf_ok = ttf.init()
print("   TTF init:", ttf_ok)

if not ttf_ok then
	print("   ERROR: TTF_Init failed!")
	os.exit(1)
end

print("3. Creating window...")
local window = sdl.createWindow("Font Test", 400, 300, 0)
print("   Window:", window ~= nil)

if window == nil then
	print("   ERROR: Failed to create window!")
	ttf.quit()
	sdl.quit()
	os.exit(1)
end

print("4. Creating renderer...")
local renderer = sdl.createRenderer(window, nil)
print("   Renderer:", renderer ~= nil)

if renderer == nil then
	print("   ERROR: Failed to create renderer!")
	sdl.destroyWindow(window)
	ttf.quit()
	sdl.quit()
	os.exit(1)
end

print("5. Opening font...")
local font = ttf.openFont("/usr/share/fonts/adwaita-sans-fonts/AdwaitaSans-Regular.ttf", 20)
print("   Font:", font ~= nil)

if font == nil then
	print("   ERROR: Failed to load font!")
	sdl.destroyRenderer(renderer)
	sdl.destroyWindow(window)
	ttf.quit()
	sdl.quit()
	os.exit(1)
end

print("6. Getting font size...")
local font_size = ttf.getFontSize(font)
print("   Font size:", font_size)

print("7. Measuring text...")
local w_ptr = ffi.new("int[1]")
local h_ptr = ffi.new("int[1]")
local text = "Hello World"
local ok = ttf.getStringSize(font, text, #text, w_ptr, h_ptr)
print("   Success:", ok)
print("   Size:", w_ptr[0], "x", h_ptr[0])

print("8. Rendering text...")
local color = ffi.new("SDL_Color", 255, 255, 255, 255)
local surface = ttf.renderTextBlended(font, text, #text, color)
print("   Surface:", surface ~= nil)

if surface ~= nil then
	print("   Surface size:", surface.w, "x", surface.h)
	sdl.destroySurface(surface)
end

print("9. Cleanup...")
ttf.closeFont(font)
sdl.destroyRenderer(renderer)
sdl.destroyWindow(window)
ttf.quit()
sdl.quit()

print("All tests completed successfully!")
