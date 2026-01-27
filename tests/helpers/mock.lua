local ffi = require("ffi")

local function create_mock_measure()
	-- Matches signature: (text, config, userData)
	-- `text` is a Lua string (core converts from FFI).
	return function(text, config, userData)
		local len = type(text) == "string" and #text or (text and text.length or 0)
		return ffi.new("Clay_Dimensions", {
			width = len * 10, -- 10px per char
			height = 20,
		})
	end
end

return {
    create_mock_measure = create_mock_measure,
}
