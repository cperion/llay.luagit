local ffi = require("ffi")
local llay = require("init")

print("Testing llay initialization...")
llay.init(1024 * 1024 * 16) -- 16MB Arena
llay.set_dimensions(1024, 768)

print("Setting up text measurement...")
llay.set_measure_text_function(function(text, config)
    local text_str = ffi.string(text.chars, text.length)
    return {
        width = #text_str * 10,
        height = 20
    }
end)

print("Beginning layout...")
llay.begin_layout()

print("Creating simple element...")
llay.Element({
    layout = {
        sizing = { width = "GROW", height = "GROW" },
        layoutDirection = llay.LayoutDirection.LEFT_TO_RIGHT,
    },
    backgroundColor = { 18, 18, 22, 255 },
}, function()
    print("  Creating child element...")
    llay.Element({
        id = "sidebar",
        layout = {
            sizing = { width = 240, height = "GROW" },
            layoutDirection = llay.LayoutDirection.TOP_TO_BOTTOM,
            padding = { 20, 20, 30, 30 },
            childGap = 20,
        },
        backgroundColor = { 26, 27, 35, 255 },
    }, function()
        print("    Creating text element...")
        llay.Text("PROJECTS", { color = { 140, 145, 160, 255 }, fontSize = 12, fontId = 1 })
    end)
end)

print("Ending layout...")
local commands = llay.end_layout()
print("Success! Commands length:", commands.length)

-- Check if constants are accessible
print("Checking constants...")
print("  Clay_RenderCommandType.RECTANGLE:", llay._core.Clay_RenderCommandType.RECTANGLE)
print("  FloatingAttachToElement.ROOT:", llay.FloatingAttachToElement.ROOT)