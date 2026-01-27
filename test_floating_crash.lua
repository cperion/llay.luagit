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

print("11. Creating floating element...")
llay.Element({
    layout = { sizing = { width = 180, height = "FIT" }, padding = 10 },
    backgroundColor = { 0, 0, 0, 220 },
    cornerRadius = 6,
    floating = {
        attachTo = llay.FloatingAttachToElement.ROOT,
        zIndex = 100,
        offset = { x = 100, y = 100 },
    },
})
print("12. Floating element created")

print("13. Ending layout...")
local commands = llay.end_layout()
print("14. Layout ended, commands:", commands.length)

print("SUCCESS!")