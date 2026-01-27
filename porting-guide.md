# Porting Clay to LuaJIT

Systematic guidelines for porting `clay.h` to LuaJIT using the **Lua-as-C** paradigm. The goal is to minimize translation friction and prevent logical errors from creeping in during the port.

## File Structure & Scope

Split the library to separate the "C-definition" from the "Implementation":

- **`src/ffi.lua`**: Contains **only** the `ffi.cdef` declarations. Copy the C structs here.
- **`src/core.lua`**: Contains the logic. This replaces `CLAY_IMPLEMENTATION`.
- **`src/shell.lua`**: The public shell (the declarative DSL API).
- **`src/init.lua`**: Main entry point.

## The Golden Rule: 0-Based Indexing

Lua uses 1-based indexing for tables. C uses 0-based for arrays. **Since we are using FFI cdata arrays (`int32_t[?]`), we must stick to 0-based indexing in the Core.**

- **Do not** convert loops to 1-based
- **Do not** add `+1` to indices
- Write loops exactly as C logic dictates

```c
// C
for (int i = 0; i < count; i++) { ... }
```

```lua
-- Lua (Core)
for i = 0, count - 1 do ... end
```

## Struct & Type Translation Guidelines

### Structs

Copy struct definitions exactly. Do not rename fields.

### Unions

`clay.h` uses anonymous unions (e.g., inside `Clay_SizingAxis`). LuaJIT supports this. Keep them exactly as is.

### Enums

C Enums are just integers. In Lua, define them as a read-only table of constants to avoid magic numbers.

```c
// C
typedef enum { CLAY_LEFT_TO_RIGHT, CLAY_TOP_TO_BOTTOM } Clay_LayoutDirection;
```

```lua
-- Lua
local Clay_LayoutDirection = {
    LEFT_TO_RIGHT = 0,
    TOP_TO_BOTTOM = 1
}
```

### Pointers vs Values

In C, `Clay_LayoutConfig config` is a value, `Clay_LayoutConfig* config` is a pointer.

In LuaJIT:

- **Reading:** `element.config` usually returns a *copy* (reference wrapper) or value depending on access
- **Guideline:** Explicitly use pointers for everything that acts as mutable state
  - Use `ffi.cast("Clay_LayoutConfig*", ptr)` if you need to perform pointer arithmetic
  - Pass pointers to functions, not copies

## Memory Management Guidelines

Clay uses an internal Arena. We must replicate this manual memory management.

### The "Global" Context

`clay.h` uses static variables (e.g., `Clay__currentContext`). In Lua, these become **Module Locals** in `core.lua`.

```lua
local context = ffi.new("Clay_Context") -- The persistent instance
local internal_arena = ffi.new("uint8_t[?]", MAX_MEMORY) -- The heap
```

### Arrays (The Array Macro)

`clay.h` uses macros like `CLAY__ARRAY_DEFINE` to define dynamic array structs (size, capacity, pointer).

**Translation:** Do not use a Lua generator. Write a specific `init_array` function that slices the Arena.

```lua
-- C: CLAY__ARRAY_DEFINE(Clay_RenderCommand, Clay_RenderCommandArray)
-- Lua Pattern:
local function Array_Allocate_Arena(capacity, element_type_size)
    local ptr = context.internalArena.nextAllocation
    context.internalArena.nextAllocation = ptr + (capacity * element_type_size)
    return ffi.cast(element_type_ptr, context.internalArena.memory + ptr)
end
```

## Control Flow & Logic Translation

### Macros

`clay.h` uses macros for min/max/string handling.

**Guideline:** Convert macros to `local function` inside `core.lua`. LuaJIT will inline them effectively.

```lua
local function CLAY__MAX(x, y) return x > y and x or y end
local function CLAY__MIN(x, y) return x < y and x or y end
```

### Boolean Logic

C treats `0`, `NULL`, and `false` as falsy. Lua treats `0` as truthy.

**Guideline:** Be explicit in conditions.

```c
// C
if (element->childrenCount) { ... }
if (!pointer) { ... }
```

```lua
-- Lua
if element.childrenCount > 0 then ... end
if pointer == nil then ... end
```

### Pointer Arithmetic

Clay does `ptr++` or `ptr += offset`.

**Guideline:** LuaJIT supports pointer arithmetic on typed pointers.

```lua
-- C:  char *chars = buffer->internalArray + buffer->length;
-- Lua: local chars = buffer.internalArray + buffer.length
```

**Note:** Ensure the variable being added to is a cdata pointer, not a Lua number.

## Specific `clay.h` Features Translation

### `CLAY(...)` Macro (The Latch)

The C macro `CLAY(...)` uses a `for` loop hack to open and close elements.

**Translation:** This disappears in the Core. The Core only exposes `OpenElement` and `CloseElement`. The "Shell" (API layer) handles the nesting via closures.

### String Handling (`Clay_String`)

Clay handles strings as `{ length, chars* }` (slices).

**Guideline:** Do not convert to Lua strings internally. Keep them as structs.

- When receiving a Lua string from API: `ffi.cast("const char*", str)`
- String equality: Use `ffi.string` only if necessary for hashing, or write a `memcmp` helper in Lua for the hot path

### SIMD

`clay.h` has optional SIMD for hashing.

**Guideline:** Drop SIMD for the initial port. LuaJIT's compiler generates very good assembly for simple loops. Port the scalar fallback version of `Clay__HashString`.

## Workflow Checklist (Execution Order)

1. **Dependency-Free Types:** Port `Vector2`, `Color`, `Dimensions`, `BoundingBox` to `ffi.lua`
2. **Config Types:** Port `LayoutConfig`, `ElementConfig` structs to `ffi.lua`
3. **Context Definition:** Port `Clay_Context` to `ffi.lua`
4. **Arena Logic:** Implement `Clay__Array_Allocate_Arena` in `core.lua`
5. **Math/Hash:** Port `Clay__HashString` and math helpers
6. **Measure Text:** Port `Clay_SetMeasureTextFunction` logic
   - **Note:** This requires a callback. Use `ffi.cast` to store the Lua callback, or simple Lua function variable storage since we are in Lua land
7. **Layout Engine:** Port `Clay__CalculateFinalLayout` and `Clay__SizeContainersAlongAxis` (This is the hardest part)
8. **Render Command Generation:** Port `Clay__CreateRenderCommands`
9. **Public API:** Wrap `OpenElement`, `CloseElement`, `BeginLayout`, `EndLayout`

## Verification Strategy (The "Diff" Test)

To ensure correctness without debugging logical needles in a haystack:

1. Create a **C** program using `clay.h` that builds a specific, complex static layout and dumps the `Clay_RenderCommandArray` (x, y, width, height, color) to a text file
2. Create a **Lua** script using the port that builds the *exact same layout*
3. Dump the Lua render commands to a text file
4. **Diff** the two text files. They should be identical down to the float epsilon

## Example Translation: `Clay__SizeContainersAlongAxis`

### C Original

```c
void Clay__SizeContainersAlongAxis(bool xAxis) {
    Clay_Context* context = Clay_GetCurrentContext();
    // ...
    for (int i = 0; i < bfsBuffer.length; ++i) {
        int32_t parentIndex = Clay__int32_tArray_GetValue(&bfsBuffer, i);
        Clay_LayoutElement *parent = Clay_LayoutElementArray_Get(&context->layoutElements, parentIndex);
        // ...
    }
}
```

### Lua Port

```lua
local function Clay__SizeContainersAlongAxis(xAxis) -- boolean
    local context = Clay_GetCurrentContext()
    -- ...
    for i = 0, bfsBuffer.length - 1 do -- 0-based loop
        local parentIndex = Clay__int32_tArray_GetValue(bfsBuffer, i)
        local parent = context.layoutElements + parentIndex
        -- ...
    end
end
```
