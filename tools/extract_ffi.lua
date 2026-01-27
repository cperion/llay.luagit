#!/usr/bin/env luajit
-- extract_ffi.lua - Extract FFI declarations from clay.h
-- This script parses clay.h and generates LuaJIT FFI cdef code

local input_file = arg[1] or "clay/clay.h"

print([[local ffi = require("ffi")

ffi.cdef[[
]])

local f = io.open(input_file, "r")
if not f then
    error("Cannot open " .. input_file)
end

local content = f:read("*all")
f:close()

-- Track which blocks we've captured to avoid duplicates
local captured = {}

-- Patterns for different declaration types
local patterns = {
    -- Basic structs
    {'typedef struct%s*{.-}([^;]+)', 'typedef struct'},
    -- Enums
    {'typedef%s+%w+%s*{.-}([^;]+)', 'typedef enum'},
    -- Simple typedefs
    {'typedef%s+([^\n;]+)%s+([^;\n]+);', 'typedef'},
    -- Function pointers
    {'typedef%s+([^(]+)%s*%*([^)]+)%*%s*%([^)]*%)%s*;', 'function_pointer'},
}

-- Extract structs and typedefs
for _, pattern_info in ipairs(patterns) do
    for match in content:gmatch(pattern_info[1]) do
        local decl = match
        
        -- Clean up the declaration
        decl = decl:gsub("%s+", " ")
        decl = decl:gsub("%s*([{};])%s*", "%1")
        
        -- Skip if too short or invalid
        if #decl > 5 and not captured[decl] then
            captured[decl] = true
            
            -- Check if it's a forward declaration (skip those)
            if not decl:match("typedef%s+struct%s+%w+%s+%w+;$") and
               not decl:match("typedef%s+enum%s+%w+%s+%w+;$") then
                print(decl .. ";")
                print()
            end
        end
    end
end

print([[
]]
)

print("Summary:")
print("  Extracted declarations from: " .. input_file)
