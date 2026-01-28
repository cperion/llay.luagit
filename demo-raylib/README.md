# Llay + Raylib Demo

This directory contains Llay layout engine demos built with Raylib.

## Prerequisites

- The raylib-lua submodule must be built
- Raylib 5.5 (automatically provided by raylua_s)

## Running the Demos

Use the `raylua_s` interpreter (not standard luajit):

```bash
# Workspace demo (full-featured UI - recommended)
cd demo-raylib
./raylib-lua/raylua_s main.lua

# Cards demo (simple grid)
./raylib-lua/raylua_s cards.lua
```

Or use the Makefile:
```bash
make demo-workspace    # Full workspace demo
make demo-raylib       # Simple cards demo
```

Or use the run script:
```bash
./run.sh workspace     # Full workspace demo (default)
./run.sh cards         # Simple cards demo
```

Press `ESC` or close the window to exit.

## Demos

### 1. `main.lua` - Modern Workspace Demo ⭐

A full-featured application showcasing Llay's capabilities:

**Features:**
- **Sidebar Navigation**: Clickable nav items with hover effects
- **Scrollable Task List**: 20 task cards in a scrollable container
- **Text Wrapping**: Descriptive text wraps to fit containers
- **Hover States**: Visual feedback on pointer interaction
- **Floating Tooltips**: Context-aware popups following mouse pointer
- **Clip/Scissor Regions**: Content outside scroll area is clipped
- **Window Resizing**: Responsive layout on window resize

**Controls:**
- **Mouse Move**: Hover over items to see visual feedback
- **Mouse Wheel**: Scroll the task list
- **Mouse Click**: (Visual feedback for pointer state)
- **Window Resize**: Drag window edges to see responsive layout
- **ESC**: Exit application

### 2. `cards.lua` - Basic Demo

A simple demonstration featuring:
- Grid of colored cards
- Text rendering with mock measurement
- Basic layout containers

**Key features:**
- Shows Llay + Raylib integration
- Demonstrates declarative UI building
- Mock text measurement (10px per character)

A full-featured application showcasing Llay's capabilities:

**Features:**
- **Sidebar Navigation**: Clickable nav items with hover effects
- **Scrollable Task List**: 20 task cards in a scrollable container
- **Text Wrapping**: Descriptive text wraps to fit containers
- **Hover States**: Visual feedback on pointer interaction
- **Floating Tooltips**: Context-aware popups following mouse pointer
- **Clip/Scissor Regions**: Content outside scroll area is clipped
- **Window Resizing**: Responsive layout on window resize

**Controls:**
- **Mouse Move**: Hover over items to see visual feedback
- **Mouse Wheel**: Scroll the task list
- **Mouse Click**: (Visual feedback for pointer state)
- **Window Resize**: Drag window edges to see responsive layout
- **ESC**: Exit application

## Implementation Details

### Text Measurement

Currently uses mock measurement:
```lua
local function measure_text(text, config, userdata)
	local char_width = config.fontSize and config.fontSize / 1.5 or 10
	return {
		width = #text * char_width,
		height = config.fontSize or 20
	}
end
```

This approximates text width based on character count and font size. For accurate measurement, you would need Raylib's `MeasureText` function, but it requires font loading which is more complex.

### Color Scheme

Dark theme matching modern IDE aesthetics:
- Background: `#121216` (very dark gray)
- Sidebar: `#1A1B23`
- Cards: `#22242E`
- Accent: `#6E78F0` (blue-violet)
- Text: `#DCE1EB` (off-white)

### Performance

- Zero-GC render loop (no temporary tables in hot paths)
- 16MB arena for layout calculations
- Efficient command-based rendering
- ~60 FPS with VSYNC enabled

## Raylib vs Other Backends

| Backend | Status | Notes |
|---------|--------|-------|
| **Raylib** | ✅ Working | Use raylua_s interpreter |
| Love2D | ✅ Original | See `demo-love2d/` |
| SDL3 | ❌ Broken | FFI incompatibility with llay |

## Raylib-Lua Notes

The `raylua_s` binary includes pre-compiled FFI bindings for Raylib 5.5 with:
- 910+ loaded FFI entries
- All core Raylib modules (core, text, shapes, textures, models, audio)
- Built-in Font support
- OpenGL rendering backend

**IMPORTANT**: You cannot run these demos with standard `luajit`. The `rl` table is only available in raylua_s.

## Future Enhancements

- [ ] Accurate text measurement with Raylib fonts
- [ ] Custom font loading
- [ ] Image rendering in UI cards
- [ ] Click handling / button actions
- [ ] Drag-and-drop support
- [ ] Animated transitions
