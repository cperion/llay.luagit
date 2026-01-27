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
llay.set_measure_text_function(function(textSlice, config, userData)
    return ffi.new("Clay_Dimensions", {
        width = textSlice.length * 10,
        height = 20
    })
end)
print("8. Text measurement set")

print("9. Beginning layout...")
llay.begin_layout()
print("10. Layout begun")

print("11. Creating parent with Text child...")
llay.Element({
    layout = {
        sizing = { width = "GROW", height = "GROW" },
        layoutDirection = llay.LayoutDirection.LEFT_TO_RIGHT,
    },
    backgroundColor = { 18, 18, 22, 255 },
}, function()
    print("12. Creating Text element...")
    llay.Text("PROJECTS", { color = { 140, 145, 160, 255 }, fontSize = 12, fontId = 1 })
    print("13. Text created")
end)
print("14. Parent created")

print("15. Ending layout...")
local commands = llay.end_layout()
print("16. Layout ended, commands:", commands.length)

print("SUCCESS!")
