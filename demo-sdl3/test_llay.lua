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

-- Now load llay
print("Loading llay...")
local llay = require("init")
print("Llay loaded")

print("Initializing llay...")
llay.init(1024 * 1024, { width = 400, height = 300 })
print("Llay initialized")
