local ffi = require("ffi")

function love.load()
	print("Testing llay loading...")
	-- Try to load llay
	local success, llay = pcall(require, "init")
	if not success then
		print("Failed to load llay:", llay)
		return
	end

	print("llay loaded successfully")

	-- Test initialization
	llay.init(1024 * 1024) -- 1MB arena

	print("Testing constants...")
	print("LayoutDirection:", llay.LayoutDirection)
	print("AlignX:", llay.AlignX)

	love.window.setMode(800, 600)
end

function love.draw()
	love.graphics.print("Minimal test", 100, 100)
end
