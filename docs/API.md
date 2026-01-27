# Llay API Reference

Complete documentation for the Llay LuaJIT layout engine.

## Architecture Overview

Llay follows a **C-core, Meta-shell** architecture:

- **core.lua**: Low-level FFI bindings, hot paths with zero GC pressure
- **shell.lua**: High-level declarative DSL using Lua tables
- **init.lua**: Public API wrapper with lifecycle management

## Lifecycle API

### init(capacity, [width, height])

Initialize the layout engine.

```lua
local llay = require("init")
llay.init(1024 * 1024 * 16, 800, 600)  -- 16MB capacity, 800x600 viewport

-- Alternative: pass dimensions as table
llay.init(1024 * 1024 * 16, {800, 600})
llay.init(nil, {width=800, height=600})  -- Use default capacity
```

**Parameters:**
- `capacity` (number, optional): Arena size in bytes. Default: 16MB
- `width` (number, optional): Viewport width
- `height` (number, optional): Viewport height

**Returns:** Nothing

---

### begin_layout()

Start a new layout frame.

```lua
llay.begin_layout()
```

**Returns:** Nothing

---

### end_layout()

Finish layout calculation and return render commands.

```lua
local commands = llay.end_layout()

-- Iterate commands
for i = 0, commands.length - 1 do
    local cmd = commands.internalArray[i]
    if cmd.commandType == llay.RenderCommandType.RECTANGLE then
        local bbox = cmd.boundingBox
        -- draw rectangle at bbox.x, bbox.y, bbox.width, bbox.height
    end
end
```

**Returns:** `Clay_RenderCommandArray*` (FFI cdata)

---

### set_dimensions(width, height)

Update viewport dimensions.

```lua
function love.resize(w, h)
    llay.set_dimensions(w, h)
end
```

**Parameters:**
- `width` (number): New viewport width
- `height` (number): New viewport height

**Returns:** Nothing

---

### set_measure_text_function(fn)

Register text measurement callback.

```lua
llay.set_measure_text_function(function(text, config)
    -- text: Clay_String struct { length, chars* }
    -- config: Clay_TextElementConfig struct
    
    local text_str = ffi.string(text.chars, text.length)
    
    return {
        width = my_font:getWidth(text_str),
        height = my_font:getHeight()
    }
end)
```

**Parameters:**
- `fn` (function): Callback receiving `(text, config)` and returning `{width, height}`

**Returns:** Nothing

---

## Declarative API

### Element(config [, children_fn])

Creates a layout element with optional children.

```lua
-- Simple element
llay.Element({
    layout = {
        sizing = { width = "GROW", height = 100 }
    },
    backgroundColor = {255, 0, 0, 255}
})

-- Element with children
llay.Element({
    id = "sidebar",
    layout = {
        sizing = { width = 220, height = "GROW" },
        layoutDirection = llay.LayoutDirection.TOP_TO_BOTTOM,
        padding = 16,
        childGap = 12
    }
}, function()
    llay.Element({ layout = { sizing = { width = "GROW", height = 50 } }})
    llay.Element({ layout = { sizing = { width = "GROW", height = 50 } }})
end)
```

**Config Table:**

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Element identifier for interactions |
| `layout` | table | Layout configuration (see below) |
| `backgroundColor` | table\|table | RGBA: `{r, g, b, a}` or `{r, g, b}` |
| `cornerRadius` | number\|table | Corner radius in pixels. Number for all corners, or table: `{topLeft, topRight, bottomLeft, bottomRight}` |
| `border` | table | Border configuration (see Border Config) |
| `floating` | table | Floating element config (see Floating Config) |
| `aspectRatio` | number | Width/height ratio (e.g., 1.777 for 16:9) |
| `image` | table | Image element config |
| `custom` | table | Custom element config |
| `userData` | any | User data attached to element |

**Layout Config:**

| Field | Type | Description |
|-------|------|-------------|
| `sizing` | table | `{ width = ..., height = ... }` (see Sizing) |
| `layoutDirection` | enum | `llay.LayoutDirection.LEFT_TO_RIGHT` or `TOP_TO_BOTTOM` |
| `padding` | number\|table | Padding in pixels. Number for all sides, or directional: `{left, right, top, bottom}` |
| `childGap` | number | Gap between children in pixels |
| `childAlignment` | table | `{ x = AlignX, y = AlignY }` or `{ AlignX, AlignY }` |

**Sizing Values:**

```lua
-- Fixed size
sizing = { width = 200, height = 100 }

-- Grow to fill available space
sizing = { width = "GROW", height = "GROW" }

-- Fit to content
sizing = { width = "FIT", height = "FIT" }

-- Percentage of parent (0.0 to 1.0)
sizing = { width = { type = llay.SizingType.PERCENT, percent = 0.5 }, height = 200 }

-- Grow with min/max constraints
sizing = { 
    width = { type = "GROW", min = 200, max = 500 },
    height = { type = "FIT", min = 50 }
}
```

---

### Text(text, config)

Creates a text element.

```lua
llay.Text("Hello World", {
    color = {255, 255, 255, 255},
    fontSize = 24,
    fontId = 1,
    letterSpacing = 1.5,
    lineHeight = 1.2,
    wrapMode = llay.TextWrap.WORDS
})
```

**Config Table:**

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `color` | table | `{0, 0, 0, 255}` | Text color RGBA |
| `fontSize` | number | 24 | Font size in pixels |
| `fontId` | number | 0 | Font identifier |
| `letterSpacing` | number | 0 | Additional letter spacing |
| `lineHeight` | number | 0 | Line height multiplier (0=auto) |
| `wrapMode` | enum | `WORDS` | `WORDS`, `NEWLINES`, or `NONE` |

---

## Enums & Constants

### LayoutDirection

```lua
llay.LayoutDirection.LEFT_TO_RIGHT  -- 0
llay.LayoutDirection.TOP_TO_BOTTOM  -- 1
```

---

### AlignX

```lua
llay.AlignX.LEFT    -- 0
llay.AlignX.CENTER  -- 1
llay.AlignX.RIGHT   -- 2
```

---

### AlignY

```lua
llay.AlignY.TOP     -- 0
llay.AlignY.CENTER  -- 1
llay.AlignY.BOTTOM  -- 2
```

---

### SizingType

```lua
llay.SizingType.FIT     -- 0
llay.SizingType.GROW    -- 1
llay.SizingType.PERCENT -- 2
llay.SizingType.FIXED   -- 3
```

---

### TextWrap

```lua
llay.TextWrap.WORDS     -- 0 (default)
llay.TextWrap.NEWLINES  -- 1
llay.TextWrap.NONE      -- 2
```

---

### PointerCapture

```lua
llay.PointerCapture.CAPTURE     -- 0
llay.PointerCapture.PASSTHROUGH -- 1
```

---

### RenderCommandType

Used when iterating render commands:

```lua
llay.RenderCommandType.NONE            -- 0
llay.RenderCommandType.RECTANGLE       -- 1
llay.RenderCommandType.BORDER          -- 2
llay.RenderCommandType.TEXT            -- 3
llay.RenderCommandType.IMAGE           -- 4
llay.RenderCommandType.SCISSOR_START   -- 5
llay.RenderCommandType.SCISSOR_END     -- 6
llay.RenderCommandType.CUSTOM          -- 7
```

---

## Interaction API

### set_pointer_state(x, y, is_down)

Update pointer position and state.

```lua
function love.update()
    local x, y = love.mouse.getPosition()
    llay.set_pointer_state(x, y, love.mouse.isDown(1))
end
```

**Parameters:**
- `x` (number): Pointer X coordinate
- `y` (number): Pointer Y coordinate
- `is_down` (boolean): Pointer button state

**Returns:** Nothing

---

### update_scroll_containers(enable_drag, dx, dy, dt)

Update scroll container states.

```lua
llay.update_scroll_containers(
    love.mouse.isDown(1),    -- enable drag
    0,                       -- dx (scroll delta x)
    mouse_wheel_y * 100,     -- dy (scroll delta y)
    love.timer.getDelta()    -- dt (delta time)
)
```

**Parameters:**
- `enable_drag` (boolean): Enable drag scrolling
- `dx` (number): Horizontal scroll delta
- `dy` (number): Vertical scroll delta
- `dt` (number): Delta time in seconds

**Returns:** Nothing

---

### pointer_over(id_string)

Check if pointer is over an element.

```lua
if llay.pointer_over("sidebar") then
    -- Pointer is over sidebar
end
```

**Parameters:**
- `id_string` (string): Element ID

**Returns:** `boolean`

---

### ID(id_string)

Get element ID hash for a string.

```lua
local element_id = llay.ID("sidebar")
-- Returns Clay_ElementId struct: { id, offset, baseId, stringId }
```

**Parameters:**
- `id_string` (string): Element identifier

**Returns:** `Clay_ElementId` (FFI cdata)

---

### IDI(id_string, index)

Get indexed element ID (for loops).

```lua
for i = 1, 10 do
    llay.Element({ id = llay.IDI("button", i) })
end
```

**Parameters:**
- `id_string` (string): Base element identifier
- `index` (number): Index value

**Returns:** `Clay_ElementId` (FFI cdata)

---

### ID_LOCAL(id_string)

Get locally-scoped element ID (scoped to parent).

```lua
llay.Element({ id = "parent" }, function()
    -- This "child" ID resolves to "parent.child" implicitly
    llay.Element({ id = llay.ID_LOCAL("child") })
end)
```

**Parameters:**
- `id_string` (string): Local element identifier

**Returns:** `Clay_ElementId` (FFI cdata)

---

### IDI_LOCAL(id_string, index)

Get indexed local element ID (scoped to parent).

**Parameters:**
- `id_string` (string): Local element identifier
- `index` (number): Index value

**Returns:** `Clay_ElementId` (FFI cdata)

---

### sort_z_order()

Sort render commands by Z-order (for floating/popup elements).

```lua
llay.begin_layout()
-- ... build layout ...
llay.sort_z_order()
local commands = llay.end_layout()
```

**Returns:** Nothing

---

### on_hover(fn[, user_data])

Register hover callback for current element.

```lua
llay.Element({ id = "button" }, function()
    llay.on_hover(function(id, pointer, data)
        print("Hovered!", data.message)
    end, { message = "Hello" })
end)
```

**Parameters:**
- `fn` (function): Callback receiving `(element_id, pointer_data, user_data)`
- `user_data` (any, optional): Data passed to callback

**Returns:** Nothing

**Note:** Must be called inside an element declaration, before closing the element.

---

## Render Commands

After `end_layout()`, iterate commands:

```lua
local commands = llay.end_layout()

for i = 0, commands.length - 1 do
    local cmd = commands.internalArray[i]
    
    if cmd.commandType == llay.RenderCommandType.RECTANGLE then
        local bbox = cmd.boundingBox
        local color = cmd.renderData.rectangle.backgroundColor
        local cornerRadius = cmd.renderData.rectangle.cornerRadius
        
        -- Draw rectangle
        
    elseif cmd.commandType == llay.RenderCommandType.TEXT then
        local text = cmd.renderData.text
        local config = cmd.renderData.text.textElementConfig
        local bbox = cmd.boundingBox
        
        -- Render text
        
    elseif cmd.commandType == llay.RenderCommandType.SCISSOR_START then
        local bbox = cmd.boundingBox
        -- Enable scissor/clipping
        
    elseif cmd.commandType == llay.RenderCommandType.SCISSOR_END then
        -- Disable scissor/clipping
    end
end
```

### Command Structure

```lua
{
    id = number,                    -- Element ID
    commandType = RenderCommandType,
    boundingBox = {                 -- Clay_BoundingBox
        x = number, y = number,
        width = number, height = number
    },
    renderData = {                  -- Union
        rectangle = {
            backgroundColor = { r, g, b, a },
            cornerRadius = { topLeft, topRight, bottomLeft, bottomRight }
        },
        text = {
            string = { length, chars* },
            textElementConfig = { ... }
        }
    }
}
```

---

## Advanced Configurations

### Border Config

```lua
border = {
    color = {255, 255, 255, 255},  -- RGBA
    width = 2                      -- All sides
}

-- Different widths per side
border = {
    color = {255, 255, 255, 255},
    width = {
        left = 2, right = 2,
        top = 1, bottom = 1,
        betweenChildren = 1        -- Between child elements
    }
}
```

---

### Floating Config

```lua
floating = {
    offset = { x = 10, y = 20 },   -- Offset from attachment
    expand = { width = 100, height = 50 },  -- Expand dimensions
    zIndex = 1000,                 -- Z-order (higher = on top)
    parentId = 123,                -- Parent element ID
    attachPoints = {
        element = llay.FloatingAttachPoint.CENTER_CENTER,
        parent = llay.FloatingAttachPoint.LEFT_TOP
    },
    pointerCaptureMode = llay.PointerCapture.CAPTURE,
    attachTo = llay.FloatingAttachTo.PARENT,  -- or ELEMENT_WITH_ID, ROOT
    clipTo = llay.FloatingClipTo.PARENT       -- or NONE
}
```

---

## Complete Example

```lua
local ffi = require("ffi")
local llay = require("init")

-- Initialize
llay.init(1024 * 1024 * 16, 800, 600)

-- Set text measurement
llay.set_measure_text_function(function(text, config)
    local str = ffi.string(text.chars, text.length)
    return {
        width = love.graphics.getFont():getWidth(str),
        height = love.graphics.getFont():getHeight()
    }
end)

-- Build layout
function draw_ui()
    llay.begin_layout()
    
    llay.Element({
        layout = {
            sizing = { width = "GROW", height = "GROW" },
            padding = 20,
            childGap = 16
        }
    }, function()
        -- Header
        llay.Element({
            id = "header",
            layout = {
                sizing = { width = "GROW", height = 60 }
            },
            backgroundColor = {50, 50, 50, 255},
            cornerRadius = 8
        }, function()
            llay.Text("My App", {
                color = {255, 255, 255, 255},
                fontSize = 24
            })
            
            llay.on_hover(function(id, pointer, data)
                print("Header hovered!")
            end)
        end)
        
        -- Content area
        llay.Element({
            layout = {
                sizing = { width = "GROW", height = "GROW" },
                layoutDirection = llay.LayoutDirection.LEFT_TO_RIGHT,
                childGap = 16
            }
        }, function()
            -- Sidebar (fixed width)
            llay.Element({
                id = "sidebar",
                layout = {
                    sizing = { width = 200, height = "GROW" }
                },
                backgroundColor = {60, 60, 60, 255}
            })
            
            -- Main content (grows)
            llay.Element({
                id = "content",
                layout = {
                    sizing = { width = "GROW", height = "GROW" }
                },
                backgroundColor = {40, 40, 40, 255}
            })
        end)
    end)
    
    llay.sort_z_order()  -- For floating elements
    return llay.end_layout()
end

-- Main loop
function love.update(dt)
    local x, y = love.mouse.getPosition()
    llay.set_pointer_state(x, y, love.mouse.isDown(1))
end

function love.draw()
    local cmds = draw_ui()
    
    -- Render commands
    for i = 0, cmds.length - 1 do
        local cmd = cmds.internalArray[i]
        local bbox = cmd.boundingBox
        
        if cmd.commandType == llay.RenderCommandType.RECTANGLE then
            local color = cmd.renderData.rectangle.backgroundColor
            local radius = cmd.renderData.rectangle.cornerRadius
            
            love.graphics.setColor(color.r/255, color.g/255, color.b/255, color.a/255)
            love.graphics.rectangle("fill",
                bbox.x, bbox.y,
                bbox.width, bbox.height,
                radius.topLeft
            )
        end
    end
    
    -- Hover example
    if llay.pointer_over("sidebar") then
        print("Mouse over sidebar!")
    end
end
```

---

## Performance Notes

- **C-core**: Use `for i = 0, count - 1 do` loops, cdata arrays, no allocations in hot paths
- **Arena allocation**: All memory pre-allocated at init, no GC pressure during layout
- **Text cache**: 2-generation LRU cache for text measurements
- **ID hashing**: String hashing done once, uses uint32 IDs internally
- **Batch processing**: Layout calculated in single pass, render commands generated sequentially

---

## Error Handling

Check errors after `end_layout()`:

```lua
local error = llay._core.context.error
if error.errorType ~= llay.ErrorType.NONE then
    print("Layout error:", error.errorType, ffi.string(error.errorText.chars, error.errorText.length))
end
```

**Error Types:**
- `ERROR_TYPE_NONE`
- `ERROR_TYPE_TEXT_MEASUREMENT_FUNCTION_NOT_PROVIDED`
- `ERROR_TYPE_ARENA_CAPACITY_EXCEEDED`
- `ERROR_TYPE_ELEMENTS_CAPACITY_EXCEEDED`
- `ERROR_TYPE_TEXT_MEASUREMENT_CAPACITY_EXCEEDED`
- `ERROR_TYPE_DUPLICATE_ID`
- `ERROR_TYPE_FLOATING_CONTAINER_PARENT_NOT_FOUND`
- `ERROR_TYPE_PERCENTAGE_OVER_1`
- `ERROR_TYPE_INTERNAL_ERROR`
- `ERROR_TYPE_UNBALANCED_OPEN_CLOSE`

---

## License

This is a LuaJIT port of the Clay layout engine. See original Clay license for details.