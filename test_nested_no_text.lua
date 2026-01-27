local ffi = require("ffi")
print("1. Loading llay...")
local llay = require("init")
print("2. llay loaded")

print("3. Initializing with 16MB...")
llay.init(1024 * 1024 * 16)
print("4. Initialized")

print("5. Setting dimensions...")
llay.set_dimensions(1024, 768)
print("6. Dimensions set")

print("7. Beginning layout...")
llay.begin_layout()

print("8. Creating root element...")
llay.Element({
    layout = {
        sizing = { width = "GROW", height = "GROW" },
        layoutDirection = llay.LayoutDirection.LEFT_TO_RIGHT,
    },
    backgroundColor = { 18, 18, 22, 255 },
}, function()
    print("9. Creating sidebar...")
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
        -- No text here, just elements
        print("10. Creating simple element...")
        llay.Element({
            layout = { sizing = { width = "GROW", height = 40 } },
            backgroundColor = { 50, 55, 70, 255 },
        })
        print("11. Simple element created")
    end)
    print("12. Sidebar closed")
end)

print("13. Ending layout...")
local commands = llay.end_layout()
print("14. Layout ended, commands:", commands and commands.length or "nil")
print("SUCCESS!")
