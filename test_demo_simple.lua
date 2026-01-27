local ffi = require("ffi")
print("Loading llay...")
local llay = require("init")
print("llay loaded")

print("Testing demo-like initialization...")

-- Initialize
print("1. Initializing...")
llay.init(1024 * 1024 * 16) -- 16MB
print("2. Setting dimensions...")
llay.set_dimensions(1024, 768)

-- Set text measurement
print("3. Setting text measurement...")
llay.set_measure_text_function(function(text, config)
    local text_str = ffi.string(text.chars, text.length)
    return {
        width = #text_str * 10,
        height = 20
    }
end)

-- Test layout with clip
print("4. Testing layout with clip...")
llay.begin_layout()

llay.Element({
    layout = {
        sizing = { width = "GROW", height = "GROW" },
        layoutDirection = llay.LayoutDirection.LEFT_TO_RIGHT,
    },
    backgroundColor = { 18, 18, 22, 255 },
}, function()
llay.Element({
    id = "TaskListContainer",
    layout = {
        sizing = { width = "GROW", height = "GROW" },
        layoutDirection = llay.LayoutDirection.TOP_TO_BOTTOM,
        padding = { 0, 20, 0, 0 },
        childGap = 12,
    },
    clip = { vertical = true, horizontal = false }, -- childOffset auto-filled
}, function()
        print("  Inside clip container")
        llay.Text("Test text", { color = { 220, 225, 235, 255 }, fontSize = 16 })
    end)
end)

local commands = llay.end_layout()
print("Success! Commands:", commands.length)

-- Test floating element
print("\nTesting floating element...")
llay.begin_layout()

llay.Element({
    layout = { sizing = { width = 180, height = "FIT" }, padding = 10 },
    backgroundColor = { 0, 0, 0, 220 },
    cornerRadius = 6,
    floating = {
        attachTo = llay.FloatingAttachToElement.ROOT,
        zIndex = 100,
        offset = { x = 100, y = 100 },
    },
}, function()
    llay.Text("Tooltip text", { color = { 220, 225, 235, 255 }, fontSize = 12 })
end)

commands = llay.end_layout()
print("Success! Commands:", commands.length)

print("\nAll tests passed!")