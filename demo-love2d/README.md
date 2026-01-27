# Llay Love2D Demo

A demonstration of the Llay layout engine integrated with Love2D for interactive UI rendering.

## Overview

This demo shows Llay's capabilities:
- Complex UI layout with nested containers
- Interactive hover detection
- Border and corner radius rendering
- Aspect ratio preservation
- Real-time layout regeneration

## Features Demonstrated

### Layout Features
- **Top-to-bottom and left-to-right layouts** - Multiple layout directions
- **Nested containers** - Deep hierarchy with proper sizing
- **Padding and child gaps** - Spacing control
- **Aspect ratio preservation** - Fixed width/height ratios
- **Border rendering** - Visual separation between elements
- **Rounded corners** - Corner radius support

### Interactive Features
- **Hover detection** - Elements highlight when mouse is over them
- **Click interaction** - Layout regenerates on button clicks
- **Pointer state tracking** - Real-time mouse position updates
- **Element identification** - Each element has a unique ID

### Visual Features
- **Color theming** - Consistent color scheme
- **Border rendering** - Visual separation
- **Hover highlights** - Interactive feedback
- **Info overlay** - Runtime statistics display

## Running the Demo

### Prerequisites
- [Love2D](https://love2d.org/) installed (version 11.x or later)
- LuaJIT available in PATH (for Llay dependencies)

### Quick Start
```bash
# From the llay/demo-love2d directory
cd /path/to/llay/demo-love2d
love .
```

### Manual Build & Run
```bash
# Build Llay if needed (from main llay directory)
cd /path/to/llay
luajit tests/run.lua  # Verify Llay works

# Run the demo
cd demo-love2d
love main.lua
```

## Controls

- **Mouse**: Hover over elements to see highlights
- **Left Click**: Click buttons to regenerate layout with new colors
- **R Key**: Force regenerate the entire layout
- **F1 Key**: Print debug information to console
- **ESC Key**: Exit the demo

## Code Structure

```
demo-love2d/
├── main.lua           # Love2D entry point with Llay integration
└── README.md          # This file
```

### Key Integration Points

1. **Text Measurement**: Mock function provides deterministic sizing
2. **Pointer State**: Love2D mouse position fed to Llay's interaction system
3. **Render Commands**: Llay outputs rectangle/border commands, Love2D renders them
4. **Layout Regeneration**: Full layout can be regenerated at runtime

## What Llay Provides

- **Layout calculation**: All positioning and sizing logic
- **Render command generation**: Rectangle and border commands with colors
- **Interaction system**: Hover detection via element IDs
- **Memory management**: Arena allocation with zero GC pressure

## What Love2D Provides

- **Rendering**: Drawing rectangles with colors and rounded corners
- **Input handling**: Mouse and keyboard events
- **Window management**: Display and event loop
- **Font rendering**: Text overlay for UI info

## Performance Notes

- **Zero GC in hot paths**: Llay uses arena allocation, no Lua table allocations in layout
- **Deterministic performance**: Predictable frame times even with complex layouts
- **Real-time regeneration**: Full UI can be regenerated each frame if needed
- **Efficient rendering**: Minimal draw calls via batch rendering

## Extending the Demo

To add more features:

1. **Add text elements**: Integrate Love2D font rendering with Llay's text measurement
2. **Implement scrolling**: Use Llay's scroll container system with Love2D input
3. **Add animations**: Interpolate between layout states
4. **Theme system**: Dynamic color schemes and styles
5. **Complex interactions**: Drag & drop, resizing, etc.

## Debugging

Enable debug output by:
- Pressing F1 for console debug info
- Checking Love2D console for print statements
- Modifying `main.lua` to add more debug prints

## See Also

- [Llay Main Documentation](../README.md) - Complete Llay documentation
- [Llay Tests](../tests/) - Golden test verification system
- [Llay Example](../example/basic.lua) - Simple command-line example