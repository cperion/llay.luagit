# Llay: Lua Layout Engine

> **Note:** This file has been superseded by the consolidated README.md. The content has been merged with docs/lua-as-c.md, docs/porting-guide.md, and docs/testing.md into a single authoritative documentation file in the root. This file is preserved for historical reference only.

A LuaJIT rewrite of the Clay layout engine following the "Lua as C" programming discipline.

## Overview

Llay is a high-performance 2D layout library written in LuaJIT using the FFI. It follows a data-oriented design with explicit memory management and minimal GC pressure, achieving near-C performance while maintaining Lua's ergonomics.

## Architecture

Llay follows the "C-core, Meta-shell" architecture:

- **Core Layer:** cdata arrays/structs, index-based loops, explicit memory management (C-like)
- **Shell Layer:** declarative DSL, ergonomic APIs, safety checks (Lua-like)

## Declarative Shell API

The shell provides a declarative DSL that feels like HTML or SwiftUI using Lua's syntactic sugar.

### Key Patterns

1. **Polymorphic Arguments:** Detect if the argument is a String (simple text) or a Table (complex config)
2. **Array-Closure Pattern:** Use the numeric array part of the table `t[1]` to hold the children function

### Example Usage

```lua
local llay = require("llay")

local function MyUI()
    -- Unary String (Simple)
    llay.text "Welcome to Llay"

    -- Unary Table (Config)
    llay.container {
        id = "Sidebar",
        width = 300,
        color = {50, 50, 50, 255},
        
        -- Children Closure (index [1])
        function()
            llay.text { "Menu Item 1", size = 24, color = {255,255,255,255} }
            
            llay.row {
                gap = 10,
                function()
                    llay.button "Save"
                    llay.button "Cancel"
                end
            }
        end
    }
end
```

### Shell Implementation

#### Generic Element Wrapper

```lua
local function make_element(element_type)
    return function(arg)
        local config_ptr = Core.AllocConfig()
        local children_fn = nil
        local id = 0

        if type(arg) == "table" then
            id = get_hashed_id(arg.id)
            children_fn = arg[1]

            if arg.width then
                config_ptr.sizing.width.type = Core.ENUM.FIXED
                config_ptr.sizing.width.size.minMax.max = arg.width
            elseif arg.width == "grow" then
                config_ptr.sizing.width.type = Core.ENUM.GROW
            end
            
            if arg.color then
                config_ptr.backgroundColor.r = arg.color[1]
                config_ptr.backgroundColor.g = arg.color[2]
                config_ptr.backgroundColor.b = arg.color[3]
                config_ptr.backgroundColor.a = arg.color[4]
            end
        elseif type(arg) == "string" then
            id = get_hashed_id(arg)
        end

        Core.OpenElement(config_ptr, id)

        if children_fn then
            children_fn()
        end

        Core.CloseElement()
    end
end
```

#### Text Handling

```lua
function Shell.text(arg)
    local content = ""
    local config_ptr = Core.AllocTextConfig()
    
    if type(arg) == "string" then
        content = arg
    elseif type(arg) == "table" then
        content = arg[1]
        
        if arg.size then config_ptr.fontSize = arg.size end
        if arg.color then 
            config_ptr.textColor.r = arg.color[1]
        end
    end
    
    Core.OpenTextElement(content, #content, config_ptr)
end
```

### Style Objects

Pre-calculated C structs for performance optimization:

```lua
local styles = {
    sidebar = llay.style({
        width = 300,
        padding = {10, 10, 10, 10},
        color = {50, 50, 50, 255}
    })
}

llay.column {
    styles.sidebar,
    id = "Sidebar",
    function()
        llay.text "Fast!"
    end
}
```

#### Mixin Handling

```lua
if type(arg[1]) == "cdata" then
    config_ptr[0] = arg[1]
    children_fn = arg[2]
else
    children_fn = arg[1]
end
```

### Zero-Garbage Option (Builder Pattern)

For maximum performance in hot paths:

```lua
llay.box()
    :id("Sidebar")
    :width(300)
    :children(function()
        -- ...
    end)
```

LuaJIT's "New Table Optimization" (NTO) makes the declarative syntax fast enough for 99% of UI use cases.

### API Summary

| Element | Syntax Sugar | Description |
| :--- | :--- | :--- |
| Containers | `llay.row { gap=10, func }` | Uses array part `[1]` for children closure |
| Text | `llay.text "Hello"` | Unary string argument |
| Text Config | `llay.text { "Hello", size=20 }` | Unary table, string at `[1]` |
| Styles | `llay.style { ... }` | Returns a C-struct for reuse |
| Mixins | `llay.row { style, func }` | Pass style at `[1]`, func at `[2]` |

## Project Structure

```
llay/
├── clay/              # Clay layout engine (git submodule)
├── lua-as-c.md        # Programming model documentation
├── llay.md            # Project documentation (this file)
├── src/
│   ├── core/          # Core layer (C-like, LuaJIT FFI)
│   ├── shell/         # Shell layer (declarative DSL)
│   └── renderer/      # Rendering integration
└── examples/          # Usage examples
```

## Dependencies

- LuaJIT 2.1 or later
- Clay layout engine (as git submodule)

## License

TBD
