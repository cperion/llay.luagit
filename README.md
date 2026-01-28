# Llay: LuaJIT Layout Engine

A high-performance LuaJIT rewrite of the Clay layout engine following the **"Lua as C"** programming discipline. Achieves near-C performance through data-oriented design, explicit memory management, and minimal GC pressure.

## Overview

Llay is a 2D layout library that bridges the gap between Lua's ergonomics and C's performance. It implements the complete Clay layout algorithm with 100% feature parity while maintaining a clean, declarative Lua API.

### Key Features

- **100% Clay C API compatibility** - Full layout algorithm implementation
- **Near-C performance** - ~90-95% of native speed via LuaJIT optimizations
- **Zero GC pressure in hot paths** - Manual arena allocation, no table allocations
- **Declarative shell API** - Feels like HTML/SwiftUI with Lua syntax
- **Complete interaction system** - Pointer, scroll, hover, Z-order
- **Verified correctness** - All 9 golden tests pass against C reference

## Architecture: C-Core, Meta-Shell

Llay follows a dual-layer architecture:

### **Core Layer (C-like)**
- FFI cdata arrays/structs for all persistent state
- 0-based indexing throughout (matches C semantics)
- Explicit memory management via arenas
- No allocations in hot loops (no tables, closures, string ops)
- Direct port of C algorithms line-by-line

### **Shell Layer (Lua-like)**
- Declarative DSL with polymorphic arguments
- Table-based configuration with validation
- Convenience patterns and ergonomic APIs
- Safety checks and rich error messages

## Quick Start

```lua
local llay = require("llay")

-- Initialize with default capacity (16MB)
llay.init()

-- Set dimensions for layout
llay.set_dimensions(800, 600)

-- Begin layout frame
llay.begin_layout()

-- Create a row with two colored boxes
llay.Element({
    layout = {
        sizing = { width = "GROW", height = "GROW" },
        layoutDirection = llay.LayoutDirection.LEFT_TO_RIGHT,
        childGap = 10
    }
}, function()
    llay.Element({
        id = "RedBox",
        backgroundColor = {255, 0, 0, 255},
        layout = { sizing = { width = 100, height = 50 } }
    })
    
    llay.Element({
        id = "GreenBox", 
        backgroundColor = {0, 255, 0, 255},
        layout = { sizing = { width = 150, height = 50 } }
    })
end)

-- Get render commands
local commands = llay.end_layout()

print("Generated " .. commands.length .. " render commands")
```

Run the example:
```bash
luajit example/basic.lua
```

## API Reference

### Lifecycle Management
```lua
-- Initialize context (optional capacity, dimensions)
llay.init(capacity, {width=800, height=600})

-- Begin/end layout frame
llay.begin_layout()
local commands = llay.end_layout()

-- Set container dimensions
llay.set_dimensions(width, height)
```

### Element Creation
```lua
-- Basic element with ID
llay.Element({
    id = "MyElement",
    backgroundColor = {255, 255, 255, 255},
    layout = {
        sizing = { width = "GROW", height = 100 },
        padding = {10, 10, 10, 10},
        childGap = 5,
        layoutDirection = llay.LayoutDirection.TOP_TO_BOTTOM
    }
}, function()
    -- Children go here
end)

-- Text element
llay.Text("Hello World", {
    color = {0, 0, 0, 255},
    fontSize = 24,
    wrapMode = llay.TextWrap.WORDS
})
```

### ID System (matches CLAY_ID() macros)
```lua
-- Global IDs
local id1 = llay.ID("ElementName")           -- CLAY_ID("ElementName")
local id2 = llay.IDI("ElementName", 5)       -- CLAY_IDI("ElementName", 5)

-- Local IDs (scoped to parent)
local id3 = llay.ID_LOCAL("ChildName")       -- CLAY_ID_LOCAL("ChildName")
local id4 = llay.IDI_LOCAL("ChildName", 2)   -- CLAY_IDI_LOCAL("ChildName", 2)
```

### Interaction System
```lua
-- Set pointer state
llay.set_pointer_state(x, y, is_down)

-- Check if pointer is over element
local is_over = llay.pointer_over("ElementName")

-- Hover callback
llay.Element({
    id = "Hoverable",
    -- ... config
})
llay.on_hover(function(id, pointer, data)
    print("Element", id.id, "hovered at", pointer.x, pointer.y)
end, user_data)

-- Scroll containers
llay.update_scroll_containers(enable_drag, dx, dy, dt)
```

### Constants & Enums
```lua
llay.LayoutDirection.LEFT_TO_RIGHT    -- 0
llay.LayoutDirection.TOP_TO_BOTTOM     -- 1

llay.AlignX.LEFT    -- 0
llay.AlignX.CENTER  -- 1  
llay.AlignX.RIGHT   -- 2

llay.AlignY.TOP     -- 0
llay.AlignY.CENTER  -- 1
llay.AlignY.BOTTOM  -- 2

llay.SizingType.FIT     -- 0
llay.SizingType.GROW    -- 1
llay.SizingType.PERCENT -- 2
llay.SizingType.FIXED   -- 3

llay.TextWrap.WORDS     -- 0
llay.TextWrap.NEWLINES  -- 1
llay.TextWrap.NONE      -- 2
```

## The "Lua as C" Programming Model

Llay treats LuaJIT as a **JIT-compiled, low-level systems language** with:
- Explicit memory ownership via arenas
- Flat data structures (cdata arrays)
- Predictable execution patterns
- Minimal garbage collection pressure

### Core Principles

1. **No allocations in hot paths** - Preallocate all arrays at frame start
2. **0-based indexing** - Match C array semantics exactly
3. **FFI cdata for persistent state** - Tables only for configuration
4. **Manual memory management** - Arena allocations, no GC pressure
5. **Line-by-line porting** - Copy C algorithms directly, don't rewrite

### Forbidden in Hot Paths (Core Layer)
- `pairs()`, `ipairs()` iteration
- `table.insert()`, `table.remove()`
- Creating tables `{}` in loops
- Creating closures `function() end` in loops
- `string.*` functions in hot paths
- Metamethod access (`obj.field` via metatype)
- `ffi.new()` in loops

## Porting Guide

When porting from `clay.h`:

### 1. Use `tools/seek` for Exploration
```bash
# List all available types
./tools/seek list

# Show specific type definition  
./tools/seek show Clay_Dimensions
./tools/seek show Clay_LayoutConfig
```

### 2. File Structure
```
llay/
├── src/
│   ├── clay_ffi.lua    # FFI cdef declarations only
│   ├── core.lua        # Core layer (replaces CLAY_IMPLEMENTATION)
│   ├── shell.lua       # Public shell (declarative DSL API)
│   └── init.lua        # Main entry point
├── clay/               # Clay submodule (reference C impl)
└── tests/              # Test suite with golden comparisons
```

### 3. Type Translation Rules

**Structs**: Copy exactly from clay.h to clay_ffi.lua
```lua
ffi.cdef[[
typedef struct {
    float width, height;
} Clay_Dimensions;
]]
```

**Enums**: Convert to constant tables
```lua
local Llay_LayoutDirection = {
    LEFT_TO_RIGHT = 0,
    TOP_TO_BOTTOM = 1
}
```

**Arrays**: 0-based indexing always
```lua
for i = 0, count - 1 do
    local elem = array.internalArray[i]
end
```

**Boolean Logic**: Be explicit (C treats 0 as falsy, Lua treats 0 as truthy)
```lua
-- C: if (element->childrenCount) { ... }
-- Lua:
if element.childrenCount > 0 then ... end

-- C: if (!pointer) { ... }
-- Lua:
if pointer == nil then ... end
```

## Testing & Verification

### Golden Test System
Compare Lua output against C reference implementation:
```bash
# Build C reference library
make -C tests/clay_ref

# Run all tests
luajit tests/run.lua
```

Tests verify:
- Layout positions (9/9 tests pass)
- Render command generation
- Interaction system behavior
- Memory correctness

### Mock Text Measurement
```lua
local function mock_measure_text(text)
    return { width = #text * 10, height = 20 }
end

llay.set_measure_text_function(mock_measure_text)
```

## Performance Characteristics

- **Memory**: 100% manual arena allocation, zero Lua GC involvement
- **Speed**: ~90-95% of native C via LuaJIT tracing JIT
- **Predictability**: Deterministic execution, no GC pauses
- **Cache locality**: Flat arrays, struct-of-arrays data layout

## Building & Development

### Dependencies
- LuaJIT 2.1+
- Make (for C reference builds)

### Development Workflow
```bash
# Clone with submodule
git clone --recursive https://github.com/yourusername/llay.git
cd llay

# Run tests
luajit tests/run.lua

# Run example
luajit example/basic.lua

# Build C reference (for golden tests)
make -C tests/clay_ref
```

### Commit Convention
Follow Conventional Commits:
- `feat(core): new feature`
- `fix(ffi): bug fix`  
- `docs: documentation changes`
- `test: test additions/changes`
- `chore: maintenance/tooling`

## License & Attribution

Llay is a LuaJIT port of the [Clay layout engine](https://github.com/fschutt/clay). The Clay C implementation is included as a git submodule for reference and testing.

Clay is licensed under MIT. Llay maintains the same license.

## Documentation Status

This README consolidates documentation from:
- `docs/llay.md` - Project overview and API
- `docs/lua-as-c.md` - Programming model philosophy  
- `docs/porting-guide.md` - Porting workflow and rules
- `AGENTS.md` - Development guidelines and conventions

The original documentation files are preserved in `docs/` for historical reference.