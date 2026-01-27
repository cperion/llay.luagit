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

print("11. Creating element with border...")
llay.Element({
    layout = {
        sizing = { width = "GROW", height = "GROW" },
        layoutDirection = llay.LayoutDirection.LEFT_TO_RIGHT,
    },
    backgroundColor = { 18, 18, 22, 255 },
}, function()
    print("12. Creating element with border config...")
    llay.Element({
        id = "sidebar",
        layout = {
            sizing = { width = 240, height = "GROW" },
            layoutDirection = llay.LayoutDirection.TOP_TO_BOTTOM,
        },
        backgroundColor = { 26, 27, 35, 255 },
        border = { color = { 50, 55, 70, 255 }, width = { right = 1 } },
    })
end)
print("13. Element with border created")

print("14. Ending layout...")
local commands = llay.end_layout()
print("15. Layout ended, commands:", commands.length)

print("SUCCESS!")