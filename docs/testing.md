# Testing Strategy

> **Note:** This file has been superseded by the consolidated README.md. The content has been merged with docs/llay.md, docs/lua-as-c.md, and docs/porting-guide.md into a single authoritative documentation file in the root. This file is preserved for historical reference only.

Use the original Clay C implementation as the source of truth. Compile it as a shared library and call via FFI to verify our Lua implementation produces identical results.

## Architecture

```
tests/
├── clay_ref/           # Reference C implementation wrapper
│   ├── build.lua       # Compiles clay.h to libclay.so
│   └── init.lua        # FFI bindings to libclay.so
├── helpers/
│   ├── compare.lua     # Output comparison utilities
│   └── layouts.lua     # Shared test layout definitions
├── test_layout.lua     # Layout calculation tests
├── test_sizing.lua     # Sizing algorithm tests
├── test_render.lua     # Render command tests
└── run.lua             # Test runner
```

## Building the Reference Library

Create a simple C wrapper that exposes Clay functions:

```c
// tests/clay_ref/clay_impl.c
#define CLAY_IMPLEMENTATION
#include "../../clay/clay.h"

// Export for shared library
__attribute__((visibility("default")))
Clay_Arena Clay_CreateArenaWithCapacity(uint32_t capacity, void* memory) {
    return Clay_CreateArenaWithCapacityAndMemory(capacity, memory);
}

// ... expose other needed functions
```

Build script:

```lua
-- tests/clay_ref/build.lua
local ffi = require("ffi")

local function build()
    local cc = os.getenv("CC") or "gcc"
    local src = "tests/clay_ref/clay_impl.c"
    local out = "tests/clay_ref/libclay.so"
    
    local cmd = string.format(
        "%s -shared -fPIC -O2 -o %s %s -I.",
        cc, out, src
    )
    
    local ok = os.execute(cmd)
    if not ok then
        error("Failed to build libclay.so")
    end
end

return { build = build }
```

## FFI Bindings to Reference Library

```lua
-- tests/clay_ref/init.lua
local ffi = require("ffi")

-- Load the shared library
local clay_c = ffi.load("./tests/clay_ref/libclay.so")

-- Declare the C API (subset needed for testing)
ffi.cdef[[
    typedef struct { float x, y; } Clay_Vector2;
    typedef struct { float x, y, width, height; } Clay_BoundingBox;
    typedef struct { float r, g, b, a; } Clay_Color;
    
    // ... rest of clay.h types
    
    typedef struct {
        Clay_BoundingBox boundingBox;
        // ... render command fields
    } Clay_RenderCommand;
    
    typedef struct {
        int32_t length;
        int32_t capacity;
        Clay_RenderCommand* internalArray;
    } Clay_RenderCommandArray;
    
    // Functions
    void Clay_BeginLayout(void);
    Clay_RenderCommandArray Clay_EndLayout(void);
    void Clay_SetLayoutDimensions(Clay_Dimensions dimensions);
    // ... other functions
]]

return clay_c
```

## Comparison Utilities

```lua
-- tests/helpers/compare.lua
local ffi = require("ffi")

local EPSILON = 0.0001

local function float_eq(a, b)
    return math.abs(a - b) < EPSILON
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
    bbox_eq = bbox_eq,
    compare_render_commands = compare_render_commands,
    dump_render_commands = dump_render_commands,
}
```

## Shared Test Layouts

Define layouts that both implementations execute identically:

```lua
-- tests/helpers/layouts.lua

-- Each layout is a function that takes an API table
-- and builds a layout using it. This allows the same
-- layout to be built with either C or Lua API.

local layouts = {}

layouts.simple_row = function(api)
    api.begin_layout()
    api.set_dimensions(800, 600)
    
    api.open_element({ layout = { direction = "LEFT_TO_RIGHT" } })
        api.open_element({ sizing = { width = 100, height = 50 } })
        api.close_element()
        
        api.open_element({ sizing = { width = 200, height = 50 } })
        api.close_element()
    api.close_element()
    
    return api.end_layout()
end

layouts.nested_containers = function(api)
    api.begin_layout()
    api.set_dimensions(800, 600)
    
    api.open_element({ layout = { direction = "TOP_TO_BOTTOM" } })
        api.open_element({ layout = { direction = "LEFT_TO_RIGHT" }, sizing = { width = "GROW" } })
            api.open_element({ sizing = { width = 100, height = 100 } })
            api.close_element()
            api.open_element({ sizing = { width = 100, height = 100 } })
            api.close_element()
        api.close_element()
        
        api.open_element({ sizing = { width = "GROW", height = 200 } })
        api.close_element()
    api.close_element()
    
    return api.end_layout()
end

layouts.flex_grow = function(api)
    api.begin_layout()
    api.set_dimensions(800, 600)
    
    api.open_element({ layout = { direction = "LEFT_TO_RIGHT" }, sizing = { width = 800 } })
        api.open_element({ sizing = { width = 100, height = 50 } })
        api.close_element()
        
        api.open_element({ sizing = { width = "GROW", height = 50 } })
        api.close_element()
        
        api.open_element({ sizing = { width = 100, height = 50 } })
        api.close_element()
    api.close_element()
    
    return api.end_layout()
end

return layouts
```

## Test Runner

```lua
-- tests/run.lua
local ffi = require("ffi")

-- Build reference library if needed
local build = require("tests.clay_ref.build")
build.build()

-- Load both implementations
local clay_c = require("tests.clay_ref")
local llay = require("llay.core")

local compare = require("tests.helpers.compare")
local layouts = require("tests.helpers.layouts")

-- Create API wrappers that normalize the interface
local function make_c_api()
    -- Initialize C clay
    local memory = ffi.new("uint8_t[?]", 1024 * 1024)
    clay_c.Clay_Initialize(memory, 1024 * 1024)
    
    return {
        begin_layout = function() clay_c.Clay_BeginLayout() end,
        end_layout = function() return clay_c.Clay_EndLayout() end,
        set_dimensions = function(w, h)
            clay_c.Clay_SetLayoutDimensions(ffi.new("Clay_Dimensions", {w, h}))
        end,
        open_element = function(config)
            -- Translate config to C structs and call
            -- ... 
        end,
        close_element = function() clay_c.Clay_CloseElement() end,
    }
end

local function make_lua_api()
    llay.init(1024 * 1024)
    
    return {
        begin_layout = function() llay.begin_layout() end,
        end_layout = function() return llay.end_layout() end,
        set_dimensions = function(w, h) llay.set_dimensions(w, h) end,
        open_element = function(config) llay.open_element(config) end,
        close_element = function() llay.close_element() end,
    }
end

-- Run tests
local function run_test(name, layout_fn)
    io.write(string.format("Testing %s... ", name))
    
    local c_api = make_c_api()
    local lua_api = make_lua_api()
    
    local c_result = layout_fn(c_api)
    local lua_result = layout_fn(lua_api)
    
    local ok, err = compare.compare_render_commands(c_result, lua_result)
    
    if ok then
        print("PASS")
        return true
    else
        print("FAIL")
        print("  " .. err)
        
        -- Dump for debugging
        compare.dump_render_commands(c_result, "/tmp/c_output.txt")
        compare.dump_render_commands(lua_result, "/tmp/lua_output.txt")
        print("  Dumped to /tmp/c_output.txt and /tmp/lua_output.txt")
        
        return false
    end
end

-- Execute all layout tests
local passed = 0
local failed = 0

for name, layout_fn in pairs(layouts) do
    if run_test(name, layout_fn) then
        passed = passed + 1
    else
        failed = failed + 1
    end
end

print(string.format("\nResults: %d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
```

## Usage

```bash
# Build and run tests
luajit tests/run.lua

# Run specific test file
luajit tests/test_layout.lua
```

## Test Categories

1. **Layout Tests:** Verify bounding box calculations match
2. **Sizing Tests:** Test FIXED, GROW, FIT sizing modes
3. **Direction Tests:** LEFT_TO_RIGHT, TOP_TO_BOTTOM
4. **Padding/Gap Tests:** Spacing calculations
5. **Scroll Tests:** Scroll container behavior
6. **Text Tests:** Text measurement and wrapping (requires mock measure function)
7. **Edge Cases:** Empty containers, single children, deeply nested

## Mock Text Measurement

Both implementations need identical text measurement for tests:

```lua
-- Deterministic mock: 10px per character, 20px height
local function mock_measure_text(text, config)
    return {
        width = #text * 10,
        height = 20
    }
end

-- Set on both C and Lua implementations before tests
clay_c.Clay_SetMeasureTextFunction(mock_measure_text_c)
llay.set_measure_text(mock_measure_text)
```
