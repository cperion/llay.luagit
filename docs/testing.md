# Testing Strategy for Llay

> **Note:** This documentation has been consolidated into the main [README.md](../README.md). Please refer to the README for the most up-to-date documentation. This file is preserved for historical reference.

## Overview

Llay uses a comprehensive testing strategy to ensure 100% correctness against the C reference implementation (Clay). The testing approach combines golden file comparison, unit tests, and integration tests.

## Golden Test System

### Concept
Generate identical layouts in both C (Clay) and Lua (Llay), then compare the resulting render commands byte-for-byte.

### Implementation
1. **C Reference Program**: `tests/clay_ref/generate_golden.c`
   - Uses the original Clay C library
   - Builds predefined layout test cases
   - Outputs render commands to golden text files

2. **Lua Test Runner**: `tests/run.lua`
   - Uses the Llay Lua implementation
   - Builds identical layout test cases
   - Compares outputs against golden files

3. **Golden Files**: `tests/clay_ref/golden_*.txt`
   - Text files containing C reference output
   - Format: `cmd[0]: id=... type=0 bbox={x=0,y=0,w=100,h=50}`

### Test Cases
Current golden tests cover:
- `simple_row` - Basic row layout
- `nested_containers` - Deep nesting
- `alignment_center` - Child alignment
- `sizing_modes` - FIXED, GROW, PERCENT sizing
- `child_gap` - Spacing between children
- `corners_borders` - Rounded corners and borders
- `aspect_ratio` - Aspect ratio preservation
- `fit_sizing` - FIT sizing with min/max constraints
- `border_between_children` - Border spacing between children

## Mock Measurement System

Text measurement is mocked for deterministic testing:

```lua
local function mock_measure_text(text, config)
    -- Deterministic: 10px per character, 20px height
    return { width = #text * 10, height = 20 }
end

llay.set_measure_text_function(mock_measure_text)
```

## Interaction System Testing

The interaction system is tested separately in `tests/test_interaction_system.lua`:
- Pointer hover detection
- Scroll container behavior
- Z-order with floating elements
- Pointer state machine

## Float Comparison Epsilon

Due to floating-point precision differences between C and Lua, comparisons use an epsilon:

```lua
local EPSILON = 0.0001
local function float_eq(a, b)
    return math.abs(a - b) < EPSILON
end
```

## Build and Test Commands

```bash
# Build C reference library
make -C tests/clay_ref

# Run all golden tests
luajit tests/run.lua

# Run interaction tests
luajit tests/test_interaction_system.lua

# Regenerate golden files (if Clay C implementation changes)
make regenerate
```

## Test-Driven Development Workflow

When porting new features from clay.h:

1. **First**: Add the test case to `tests/helpers/layouts.lua`
2. **Then**: Build C reference: `make regenerate`
3. **During**: Port the feature to Llay
4. **After**: Verify: `luajit tests/run.lua`

## Coverage Goals

- **Layout correctness**: 100% match with C reference
- **Memory safety**: Arena bounds checking in debug mode
- **Interaction correctness**: Verified behavior
- **Performance**: No regressions from "Lua as C" discipline
- **API compatibility**: Full Clay C API surface

## Historical Note

This testing strategy was critical for the successful port of Clay to LuaJIT. The golden test system caught numerous subtle bugs in layout calculations that would have been difficult to find through manual inspection alone.