-- tools/seek_clay.lua
-- Usage:
--   luajit tools/seek_clay.lua list        -> Lists all structs/enums
--   luajit tools/seek_clay.lua show <name> -> Extracts definition/impl of <name>
--   luajit tools/seek_clay.lua macros      -> Lists array/wrapper macros to manually expand

local filename = "clay/clay.h"
local f = io.open(filename, "r")
if not f then error("Could not open " .. filename) end
local content = f:read("*all")
f:close()

local cmd = arg[1]
local target = arg[2]

local function print_match(text)
    print("--------------------------------------------------------------------------------")
    print(text)
    print("--------------------------------------------------------------------------------")
end

if cmd == "list" then
    print("--- STRUCTS ---")
    for name in content:gmatch("} (%w+);") do
        print(name)
    end
    print("\n--- ENUMS ---")
    for name in content:gmatch("typedef enum {.-} (%w+);") do
        print(name)
    end

elseif cmd == "macros" then
    print("--- ARRAY MACROS (Need manual porting to core.lua) ---")
    for type, name in content:gmatch("CLAY__ARRAY_DEFINE%((%w+), (%w+)%)") do
        print(string.format("Type: %-30s ArrayName: %s", type, name))
    end

elseif cmd == "show" and target then
    -- Try to find struct/enum definition
    local pattern = "typedef struct.-" .. target .. ";"
    local s, e = content:find(pattern)
    
    if not s then 
        -- Try finding simple typedef
        s, e = content:find("typedef .-" .. target .. ";")
    end

    if not s then
        -- Try finding function implementation
        -- Heuristic: ReturnType Clay__Something(...) {
        s, e = content:find("[%w%*]+%s+" .. target .. "%s*%b()%s*%b{}")
    end

    if s then
        print_match(content:sub(s, e))
    else
        print("Symbol '" .. target .. "' not found.")
    end

else
    print("Usage:")
    print("  luajit tools/seek_clay.lua list")
    print("  luajit tools/seek_clay.lua macros")
    print("  luajit tools/seek_clay.lua show <SymbolName>")
end
