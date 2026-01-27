local ffi = require("ffi")

local function create_mock_measure()
    return {
        measure = function(text, fontSize)
            return ffi.new("Clay_Vector2", {
                x = (#text or 0) * fontSize * 0.6,
                y = fontSize
            })
        end
    }
end

return {
    create_mock_measure = create_mock_measure,
}
