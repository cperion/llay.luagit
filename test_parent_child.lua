local ffi = require("ffi")
print("1. Loading llay...")
local llay = require("init")
print("2. llay loaded")

print("3. Initializing with 16MB...")
llay.init(1024 * 1024 * 16) -- 16MB
print("4. Initialized")

print("5. Setting dimensions...")
llay.set_dimensions(1024, 768)
print("6. Dimensions set")

print("7. Setting text measurement...")
llay.set_measure_text_function(function(text, config)
    local text_str = ffi.string(text.chars, text.length)
    return {
        width = #text_str * 10,
        height = 20
    }
end)
print("8. Text measurement set")

print("9. Beginning layout...")
llay.begin_layout()
print("10. Layout begun")

print("11. Creating parent with child...")
llay.Element({
    layout = {
        sizing = { width = "GROW", height = "GROW" },
        layoutDirection = llay.LayoutDirection.LEFT_TO_RIGHT,
    },
    backgroundColor = { 18, 18, 22, 255 },
}, function()
    print("12. Inside parent, creating child...")
    llay.Element({
        id = "sidebar",
        layout = {
            sizing = { width = 240, height = "GROW" },
            layoutDirection = llay.LayoutDirection.TOP_TO_BOTTOM,
        },
        backgroundColor = { 26, 27, 35, 255 },
    })
    print("13. Child created")
end)
print("14. Parent with child created")

print("15. Ending layout...")
local commands = llay.end_layout()
print("16. Layout ended, commands:", commands.length)

print("SUCCESS!")