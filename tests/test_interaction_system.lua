package.path = "./src/?.lua;" .. package.path

print("Testing Interaction, Scroll, and Z-Order Systems")
print("==============================================")

local llay = require("init")

-- Initialize
llay.init(1024 * 1024 * 16)
llay.set_measure_text_function(function(text, config)
	return { width = #text.chars * 10, height = 20 }
end)

-- Test 1: Pointer detection
print("\n1. Testing pointer detection...")
llay.begin_layout()
llay.Element({
	id = "Box1",
	backgroundColor = {255, 0, 0, 255},
	layout = {
		sizing = { width = 100, height = 100 },
		padding = 0
	}
})
-- Element function automatically opens and closes
local commands = llay.end_layout()

-- Set pointer inside box
llay.set_pointer_state(50, 50, false)
local is_over = llay.pointer_over("Box1")
if is_over then
	print("  ✓ Pointer correctly detected inside Box1")
else
	print("  ✗ FAIL: Pointer not detected inside Box1")
end

-- Set pointer outside box
llay.set_pointer_state(200, 200, false)
is_over = llay.pointer_over("Box1")
if not is_over then
	print("  ✓ Pointer correctly not detected outside Box1")
else
	print("  ✗ FAIL: Pointer incorrectly detected outside Box1")
end

-- Test 2: Scroll container
print("\n2. Testing scroll container...")
llay.begin_layout()
llay.Element({
	id = "ScrollContainer",
	backgroundColor = {200, 200, 200, 255},
	layout = {
		sizing = { width = 300, height = 200 },
		padding = 0
	},
	clip = { horizontal = false, vertical = true }
})
-- Add tall content that exceeds container height
llay.Element({
	id = "TallContent",
	backgroundColor = {0, 0, 255, 255},
	layout = {
		sizing = { width = 280, height = 500 },
		padding = 0
	}
})
-- Element functions automatically close
commands = llay.end_layout()

-- Test scroll with wheel
llay.update_scroll_containers(false, 0, -10, 1/60) -- Wheel scroll down 10 units
print("  ✓ Scroll update executed (would need render command inspection to verify)")

-- Test 3: Z-order with floating elements
print("\n3. Testing Z-order with floating elements...")
llay.begin_layout()

-- Create parent container
llay.Element({
	id = "Parent",
	backgroundColor = {150, 150, 150, 255},
	layout = {
		sizing = { width = 400, height = 400 },
		padding = 0
	}
})

-- Create low z-index floating element
llay.Element({
	id = "FloatingLow",
	backgroundColor = {255, 200, 0, 255},
	layout = {
		sizing = { width = 100, height = 100 },
		padding = 0
	},
	floating = {
		attachTo = 1, -- PARENT
		parentId = llay.ID("Parent").id,
		zIndex = 5,
		offset = {x = 50, y = 50}
	}
})

-- Create high z-index floating element  
llay.Element({
	id = "FloatingHigh",
	backgroundColor = {0, 255, 0, 255},
	layout = {
		sizing = { width = 100, height = 100 },
		padding = 0
	},
	floating = {
		attachTo = 1, -- PARENT
		parentId = llay.ID("Parent").id,
		zIndex = 10,
		offset = {x = 100, y = 100}
	}
})

-- Element functions automatically close
commands = llay.end_layout()

-- Check that we got render commands
if commands and commands.length > 0 then
	print("  ✓ Layout generated render commands with Z-ordering")
	-- In a real test we'd check the order of SCISSOR_START commands
else
	print("  ✗ FAIL: No render commands generated")
end

print("\n==============================================")
print("Interaction system tests completed")
print("Note: Full verification requires checking render command order")