# Llay SDL3 Demo

**⚠️ CURRENTLY BROKEN** - The SDL3_ttf FFI bindings are incompatible with llay's FFI context, causing crashes when TTF functions are called from within llay's measure_text callback.

## Status

- Raylib demo: ✅ Working (use `demo-raylib/`)
- SDL3 demo: ❌ Broken due to FFI incompatibility

## Known Issue

When SDL3_ttf is initialized and a font is loaded, calling `TTF_GetStringSize` from within llay's measure_text callback causes a segfault. This appears to be a fundamental incompatibility between:
- llay's LuaJIT FFI bindings (`clay_ffi.lua`)
- SDL3_ttf's FFI bindings (via `sdl3-ffi` submodule)

### Symptom

```lua
local function measure_text(text_str, config)
    local w = ffi.new("int[1]")
    local h = ffi.new("int[1]")
    local success = ttf.getStringSize(font, text_str, #text_str, w, h)  -- CRASHES HERE
    return {width = w[0], height = h[0]}
end
llay.set_measure_text_function(measure_text)
```

### Test Results

| Scenario | Result |
|----------|--------|
| SDL3 alone (no TTF) | ✅ Works |
| SDL3 + TTF (no llay) | ✅ Works |
| llay alone (no SDL/TTF) | ✅ Works |
| llay + SDL3 (no TTF) | ✅ Works |
| llay + SDL3 + TTF (no font load) | ✅ Works |
| llay + SDL3 + TTF (font loaded, no TTF calls) | ✅ Works |
| llay + SDL3 + TTF + measure callback with TTF | ❌ SEGFAULT |

### Possible Causes

1. **FFI Context Contamination**: Some shared FFI state being corrupted
2. **Memory Layout Conflict**: Both libraries may be using overlapping FFI c definitions
3. **Callback Context Issue**: FFI callbacks from llay may not be compatible with TTF's expectations

## Workarounds

None currently known. Use the Raylib demo instead:

```bash
cd demo-raylib
luajit main.lua
```

## Setup (for future investigation)

```bash
cd demo-sdl3

# Initialize submodules
git submodule update --init --recursive

# Install SDL3 dependencies (Fedora)
sudo dnf install SDL3-devel SDL3_ttf-devel

# Try running (will crash)
luajit main.lua
```
