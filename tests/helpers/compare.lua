local ffi = require("ffi")

local EPSILON = 0.0001

local function float_eq(a, b)
    return math.abs(a - b) < EPSILON
end

local function color_eq(a, b)
    return float_eq(a.r, b.r)
        and float_eq(a.g, b.g)
        and float_eq(a.b, b.b)
        and float_eq(a.a, b.a)
end

local function bbox_eq(a, b)
    return float_eq(a.x, b.x)
        and float_eq(a.y, b.y)
        and float_eq(a.width, b.width)
        and float_eq(a.height, b.height)
end

local function compare_render_commands(c_array, lua_array)
    if c_array.length ~= lua_array.length then
        return false, string.format(
            "Length mismatch: C=%d, Lua=%d",
            c_array.length, lua_array.length
        )
    end
    
    for i = 0, c_array.length - 1 do
        local c_cmd = c_array.internalArray[i]
        local lua_cmd = lua_array.internalArray[i]
        
        if not bbox_eq(c_cmd.boundingBox, lua_cmd.boundingBox) then
            return false, string.format(
                "BoundingBox mismatch at index %d:\n  C:   {x=%f, y=%f, w=%f, h=%f}\n  Lua: {x=%f, y=%f, w=%f, h=%f}",
                i,
                c_cmd.boundingBox.x, c_cmd.boundingBox.y,
                c_cmd.boundingBox.width, c_cmd.boundingBox.height,
                lua_cmd.boundingBox.x, lua_cmd.boundingBox.y,
                lua_cmd.boundingBox.width, lua_cmd.boundingBox.height
            )
        end
    end
    
    return true
end

local function dump_render_commands(array, filename)
    local f = io.open(filename, "w")
    if not f then error("Failed to open " .. filename) end
    
    for i = 0, array.length - 1 do
        local cmd = array.internalArray[i]
        f:write(string.format(
            "%d: x=%f y=%f w=%f h=%f\n",
            i,
            cmd.boundingBox.x, cmd.boundingBox.y,
            cmd.boundingBox.width, cmd.boundingBox.height
        ))
    end
    f:close()
end

return {
    float_eq = float_eq,
    color_eq = color_eq,
    bbox_eq = bbox_eq,
    compare_render_commands = compare_render_commands,
    dump_render_commands = dump_render_commands,
    EPSILON = EPSILON,
}
