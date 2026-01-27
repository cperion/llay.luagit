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

print("9. Testing constants...")
print("LayoutDirection.LEFT_TO_RIGHT:", llay.LayoutDirection.LEFT_TO_RIGHT)
print("FloatingAttachToElement.ROOT:", llay.FloatingAttachToElement.ROOT)

print("SUCCESS! No layout operations.")