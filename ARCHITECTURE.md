# Architecture: Llay (Layout) vs. Llui (Framework)

This document outlines the architectural boundary between the **Llay** layout engine and the **Llui** high-level user interface library.

## 1. The Separation of Concerns

| Responsibility | **Llay** (The Engine) | **Llui** (The Framework) |
| :--- | :--- | :--- |
| **Role** | Low-level Layout Calculator | High-level Widget Library |
| **Data** | Rectangles, IDs, Scroll offsets | Styles, Themes, Input State |
| **Output** | List of Render Commands | Interactive Widgets (Buttons, Sliders) |
| **Rendering** | Agnostic (defines `Custom` type) | Backend-Specific (Raylib/Love2D adapters) |
| **Logic** | None (pure layout) | Interaction Logic (`clicked`, `hovered`) |

---

## 2. Changes Required in Llay

To support custom drawing (needed for rounded toggles, circular avatars, etc.) without polluting Llay with rendering logic, we add **Render Closure Support** to the Llay Shell.

**File:** `llay/src/shell.lua`

We add a registry to map Layout IDs to Lua Functions. This allows the layout engine to say *"Draw ID #5 here"*, and the renderer to look up *"Function #5"* and execute it.

### New API: `llay.Custom(config, render_fn)`

```lua
-- Internal registry, cleared every frame
local _render_callbacks = {}

-- 1. Reset registry at start of frame
function M.begin_layout()
    for k in pairs(_render_callbacks) do _render_callbacks[k] = nil end
    core.begin_layout()
end

-- 2. The Custom Element Wrapper
function M.Custom(config, render_fn)
    -- Ensure we have a stable ID
    local id_str = config.id or ("auto_cust_" .. tostring(#_render_callbacks))
    local id_obj = core.ID(id_str)

    -- Store the drawing logic for later
    _render_callbacks[id_obj.id] = render_fn

    -- Tell Core to layout this element
    core.open_element_with_id(id_obj)

    local decl = ffi.new("Clay_ElementDeclaration")
    decl.layout = parse_layout_config(config)
    -- Signal to C that this is a CUSTOM command
    decl.custom.customData = nil

    core.configure_open_element(decl)
    core.close_element()
end

-- 3. Accessor for the Renderer
function M.get_render_callback(id)
    return _render_callbacks[id]
end
```

---

## 3. The Llui Architecture

**Llui** is the implementation layer. It implements the "Egui Philosophy" (Tokens, Visuals, Interaction).

### File Structure

```text
llui/
├── init.lua          # Context & Lifecycle
├── style.lua         # Design Tokens & Theming
├── interact.lua      # Interaction State Machine (Hover/Active)
├── widgets.lua       # Widget Library
├── renderer.lua      # Command Processor
└── backend/
    └── raylib.lua    # The "Painter" Implementation
```

### 3.1 Styling (`llui/style.lua`)

We adopt the **5-State Visual Model**.

```lua
-- Defines how a widget looks in every possible state
Style.visuals.widgets = {
    inactive = { bg = Colors.gray,    border = Colors.transparent },
    hovered  = { bg = Colors.light,   border = Colors.white },
    active   = { bg = Colors.dark,    border = Colors.white },
    -- etc...
}
```

### 3.2 Interaction (`llui/interact.lua`)

Llui wraps Llay's raw pointer queries into a state response.

```lua
function M.response(id)
    local hovered = llay.pointer_over(id)
    local down = raylib.IsMouseButtonDown(0)

    local state = "inactive"
    if hovered then
        state = down and "active" or "hovered"
    end

    return {
        state = state,
        clicked = (hovered and raylib.IsMouseButtonReleased(0))
    }
end
```

### 3.3 Widgets (`llui/widgets.lua`)

Widgets combine **Layout** (Llay), **Style** (Llui), and **Drawing** (Closures).

**Example: A Custom Toggle Switch**

```lua
function M.toggle(id, checked)
    local resp = interact.response(id)
    local style = style.get(resp.state)

    -- We ask Llay for space (Layout)
    -- And provide a closure for drawing (Rendering)
    llay.Custom({
        id = id,
        width = 40, height = 20
    }, function(rect, painter)
        -- This code runs LATER, during the render pass

        -- Draw background pill
        painter:rect(rect, style.bg, 10)

        -- Draw circle knob
        local knob_x = checked and (rect.x + 20) or rect.x
        painter:circle({x=knob_x, y=rect.y}, 8, style.fg)
    end)

    if resp.clicked then checked = not checked end
    return checked
end
```

### 3.4 The Renderer (`llui/renderer.lua`)

The renderer ties it all together. It iterates Llay's commands and dispatches them.

```lua
function M.render(commands)
    local painter = require("llui.backend.raylib")

    for i = 0, commands.length - 1 do
        local cmd = commands[i]

        if cmd.type == "RECTANGLE" then
            painter:rect(cmd.box, cmd.color, cmd.radius)

        elseif cmd.type == "CUSTOM" then
            -- Retrieve the closure stored in Llay Shell
            local draw_fn = llay.get_render_callback(cmd.id)

            -- Execute it, passing the computed layout box and the painter
            if draw_fn then
                draw_fn(cmd.boundingBox, painter)
            end
        end
    end
end
```

---

## 4. Summary of Flow

1.  **User Code:** Calls `llui.toggle(...)`.
2.  **Llui:** Calculates Style state. Calls `llay.Custom(config, closure)`.
3.  **Llay Shell:** Stores `closure` in a table `[id] = closure`. Tells C Core to add element.
4.  **Llay Core (C):** Calculates `x, y, w, h`. Generates a `CUSTOM` Render Command with `id`.
5.  **User Code:** Calls `llui.render()`.
6.  **Llui Renderer:** Sees `CUSTOM` command. Looks up `closure` using `id`. Calls `closure(rect, painter)`.
7.  **Painter (Raylib):** Draws the pixels.

This architecture keeps **Llay** pure (it only knows about rectangles and IDs) while giving **Llui** infinite flexibility to draw whatever it wants using the backend painter.