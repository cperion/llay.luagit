local ffi = require("ffi")

local function create_mock_measure()
    -- Matches signature: slice, config, userData
    return function(textSlice, config, userData)
        -- textSlice is Clay_StringSlice { length, chars, baseChars }
        -- We just multiply length by a fixed width for testing predictability
        return ffi.new("Clay_Dimensions", {
            width = textSlice.length * 10, -- 10px per char
            height = 20
        })
    end
end

return {
    create_mock_measure = create_mock_measure,
}
