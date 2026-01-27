# AGENTS - Llay Development Guide

## Workflow

**Test-Driven Development** - Always write tests during implementation:

1. Write a test **before** or **during** implementation, not after
2. Run tests frequently: `luajit tests/run.lua`
3. Add new test files to `tests/` when testing new features
4. Mock external dependencies in `tests/helpers/mock.lua`

**Read Porting Guidelines** - **MUST READ** `docs/porting-guide.md` before any porting work:

- Use `tools/seek` to explore clay.h (primary method, direct reading is fallback)
- Follow 0-based indexing in Core (never convert to 1-based)
- Copy struct definitions exactly from clay.h
- Convert C enums to Lua constant tables
- Write explicit boolean logic (C treats 0 as falsy, Lua treats 0 as truthy)
- Use pointers explicitly for mutable state
- No allocations in hot paths (no tables, closures, string manipulation in loops)

1. Mark completed items with `[x]`
2. Add summary at top with progress percentages
3. Note recent commits for reference

**Commit regularly** - After completing a feature, commit with a descriptive message.

```bash
git add -A
git commit -m "type(scope): description"
```

**Conventional Commits** - Use this specification for structured, meaningful commit messages:

Format: `type[optional scope]: <description>`

**Common types:**

- `feat` - New feature (correlates with MINOR in SemVer)
- `fix` - Bug fix (correlates with PATCH in SemVer)
- `docs` - Documentation changes
- `chore` - Maintenance, build, tooling changes
- `refactor` - Code refactoring (no functional change)
- `test` - Test additions/changes
- `perf` - Performance improvements
- `style` - Code style/formatting changes

**Examples:**

- `feat(core): add layout calculation engine`
- `fix(ffi): correct Clay_Arena struct definition`
- `docs(AGENTS): add commit workflow section`
- `test(layout): add row layout tests`
- `chore: update AGENTS.md with conventional commits spec`

**Breaking changes:**

- Add `!` after type/scope: `feat(api)!: breaking API change`
- Or add footer: `BREAKING CHANGE: <description>`

## Project Overview

Llay is a LuaJIT rewrite of the Clay layout engine following the "Lua-as-C" programming discipline. This achieves near-C performance through data-oriented design, explicit memory management, and minimal GC pressure.

**Architecture**: C-core, Meta-shell

- **Core layer**: cdata arrays/structs, index-based loops, explicit memory management (C-like)
- **Shell layer**: declarative DSL, ergonomic APIs, safety checks (Lua-like)

## Build & Test Commands

```bash
# LuaJIT version required: 2.1+
luajit -v

# Run tests
luajit tests/run.lua

# Run specific test file
luajit tests/test_layout.lua
luajit tests/test_sizing.lua
luajit tests/test_render.lua

# Build reference C library (used for verification)
luajit tests/clay_ref/build.lua
```

## Code Style Guidelines

### Core Principles

**C-Core (Hot Path) Rules**:

- Use cdata arrays/structs for all persistent state
- Zero-based indexing for all cdata arrays: `for i = 0, count - 1 do ... end`
- Integer IDs and numeric enums - no strings in hot paths
- Explicit memory management via arenas
- **NO allocations** in hot loops: no tables, no closures, no string manipulation
- No metamethod dispatch in tight loops: no `__index`, `__call`, `__newindex`
- No `pairs()`/`ipairs()` iteration in core logic
- No `ffi.new` in inner loops

**Shell (Boundary) Rules**:

- Metatables, metatypes, views/proxies allowed
- Table-based configuration and DSLs
- Validation, asserts, rich error messages
- Conveniences and ergonomics

### File Structure

```
llay/
├── clay/              # Clay layout engine (git submodule - reference C impl)
├── src/
│   ├── ffi.lua        # FFI cdef declarations only - copy C structs exactly
│   ├── core.lua       # Core layer (C-like, replaces CLAY_IMPLEMENTATION)
│   ├── shell.lua      # Public shell (declarative DSL API)
│   └── init.lua       # Main entry point
└── tests/             # Test suite
```

### Imports

```lua
-- Standard pattern
local ffi = require("ffi")
-- Local bind for hot paths
local bit = require("bit")
local band, bor = bit.band, bit.bor
```

### Naming Conventions

- **Modules**: lowercase with underscores: `layout_calculator.lua`
- **Functions**: snake_case for core, snake_case for shell
- **Enums**: PascalCase constant tables: `local LayoutDirection = { LEFT_TO_RIGHT = 0, TOP_TO_BOTTOM = 1 }`
- **C structs**: PascalCase matching clay.h: `Clay_LayoutConfig`, `Clay_ElementId`
- **Variables**: camelCase or snake_case (be consistent within file)
- **Constants**: UPPER_CASE: `MAX_MEMORY`, `EPSILON`

### Type Translation from C to Lua

**Structs**: Copy exactly from clay.h to ffi.lua

```c
// C
typedef struct {
    float width, height;
} Clay_Dimensions;
```

```lua
-- Lua (ffi.lua)
ffi.cdef[[
typedef struct {
    float width, height;
} Clay_Dimensions;
]]
```

**Enums**: Convert to constant tables (not enums)

```c
// C
typedef enum { CLAY_LEFT_TO_RIGHT, CLAY_TOP_TO_BOTTOM } Clay_LayoutDirection;
```

```lua
-- Lua (core.lua)
local Clay_LayoutDirection = {
    LEFT_TO_RIGHT = 0,
    TOP_TO_BOTTOM = 1
}
```

**Unions**: Keep anonymous unions as-is in cdef - LuaJIT supports them

**Pointers**: Explicitly use pointers for mutable state

- Pass pointers to functions, not

```lua
local config_ptr = ffi.cast("Clay_LayoutConfig*", arena_ptr)
```

### Code Style Rules

**Loops**:

```lua
-- Core (0-based, always)
for i = 0, count - 1 do end

-- NEVER convert to 1-based in core
```

**Boolean Logic**:

```lua
-- C: if (element->childrenCount) { ... }
-- Lua (be explicit)
if element.childrenCount > 0 then ... end

-- C: if (!pointer) { ... }
-- Lua
if pointer == nil then ... end
```

**Macros to Functions**:

```lua
-- C: CLAY__MAX(x, y)
-- Lua
local function CLAY__MAX(x, y) return x > y and x or y end
local function CLAY__MIN(x, y) return x < y and x or y end

-- Local bind hot functions
local min, max = math.min, math.max
```

**String Handling**:

- Keep as Clay_String structs internally: `{ length, chars* }`
- Convert Lua string to C string: `ffi.cast("const char*", str)`
- String equality: use memcmp helper or `ffi.string` for hashing

**Pointer Arithmetic**:

```lua
-- C: char *chars = buffer->internalArray + buffer->length;
-- Lua (ensure variable is typed pointer)
local chars = buffer.internalArray + buffer.length
```

### Memory Management

**Arena Allocation**:

```lua
-- Preallocate
local MAX_MEMORY = 1024 * 1024
local arena = ffi.new("uint8_t[?]", MAX_MEMORY)
local context = {
    internalArena = {
        memory = arena,
        nextAllocation = arena
    }
}

-- Allocate from arena
local function allocate_in_arena(size, align)
    local next = context.internalArena.nextAllocation
    local aligned = bit.band(next + align - 1, -align)
    context.internalArena.nextAllocation = aligned + size
    return ffi.cast("void*", aligned)
end

-- Growth: amortized doubling only at frame boundaries, NEVER in hot loops
```

**Arrays**: Write specific init functions, don't use generators

```lua
-- Pattern: slice from arena
local function allocate_array(capacity, element_type)
    local size = capacity * ffi.sizeof(element_type)
    local ptr = allocate_in_arena(size, 16)
    return ffi.cast(element_type .. "*", ptr)
end
```

### Error Handling

**Core functions**: Assume valid inputs (shell validates)

- No error checking in hot paths
- Use assertions in debug mode

**Shell functions**: Validate all inputs

```lua
function shell.element(config)
    if type(config) ~= "table" then
        error("expected table, got " .. type(config))
    end
    -- ...
end

-- Debug mode flag
local DEBUG = os.getenv("DEBUG") == "1"
if DEBUG then
    -- Add expensive checks here
end
```

### Declarative Shell API Patterns

**Polymorphic Arguments**:

```lua
function Element(arg)
    local config_ptr
    local children_fn
    local id

    if type(arg) == "string" then
        -- Simple unary string: text element
        content = arg
        id = hash_id(arg)
    elseif type(arg) == "table" then
        -- Complex config with optional children at [1]
        id = arg.id and hash_id(arg.id) or 0
        children_fn = arg[1]  -- Children closure
        config_ptr = build_config(arg)
    end
end
```

**Fluent Builder Pattern** (for zero-GC in hot paths):

```lua
llay.box()
    :id("Sidebar")
    :width(300)
    :children(function() end)
```

### Testing Strategy

**Reference Verification**: Build Clay C as shared library, compare outputs

```bash
# Build libclay.so
luajit tests/clay_ref/build.lua

# Run comparison tests
luajit tests/run.lua
```

**Mock Text Measurement**:

```lua
-- Deterministic: 10px per char, 20px height
local function mock_measure_text(text)
    return { width = #text * 10, height = 20 }
end
```

**Float Comparison Epsilon**:

```lua
local EPSILON = 0.0001
local function float_eq(a, b)
    return math.abs(a - b) < EPSILON
end
```

### Forbidden in Hot Paths (Core)

- `pairs()`, `ipairs()`
- `table.insert()`, `table.remove()`
- Creating tables `{}` in loops
- Creating closures `function() end` in loops
- `pcall()`, `xpcall()` in hot paths
- `string.*` functions in hot paths
- Metamethod access (`obj.field`, `obj:method()` via metatype)
- `ffi.new()` in loops

### Required Patterns for Performance

- Preallocate all output arrays
- Local bind hot functions: `local band = bit.band`
- Separate functions per major enum path
- Reuse scratch buffers per frame

### Exploring clay.h

**Primary method: Use `tools/seek`**

The clay.h header file is large (~4400 lines). Use the tree-sitter-based `tools/seek` script to query struct and enum definitions:

```bash
# List all available types
./tools/seek list

# Show a specific type definition
./tools/seek show Clay_Dimensions
./tools/seek show Clay_LayoutConfig

# Search for types matching a pattern
./tools/seek list | grep Config
```

This is the recommended way to explore clay.h when porting types or understanding the API. Direct file reading is a fallback only.

**Setup (one-time):**

```bash
# Clone and build tree-sitter C parser
mkdir -p vendor/parsers
cd vendor/parsers
git clone https://github.com/tree-sitter/tree-sitter-c.git c
cd c
tree-sitter build

# Update tree-sitter config (optional, if needed)
jq '.["parser-directories"] += ["'"$(pwd | sed 's|/c||')"'"]' \
  ~/.config/tree-sitter/config.json > /tmp/config.json
mv /tmp/config.json ~/.config/tree-sitter/config.json
```

See `tools/README.md` for more details.

### Porting from clay.h Checklist

**Rule: Always seek through clay.h first before implementing.** The C implementation is the source of truth—copy algorithms directly rather than rewriting from memory.

```bash
# 1. Seek through clay.h to understand the algorithm
cd clay && rg -A 50 "function_name" clay.h | head -60

# 2. Copy the C logic line-by-line, converting only:
#    - for loops: i++ -> i = i + 1
#    - pointers: struct->field -> struct.field
#    - conditions: if (!x) -> if x == nil
#    - arrays: array[i] -> array.internalArray[i]

# 3. Test after each significant port
luajit tests/run.lua
```

1. Port dependency-free types (Vector2, Color, Dimensions, BoundingBox) to ffi.lua
2. Port config types (LayoutConfig, ElementConfig) to ffi.lua
3. Port Context struct to ffi.lua
4. Implement arena allocation functions in core.lua
5. Port math helpers and hash functions (drop SIMD, use scalar fallback)
6. Port text measurement callback system
7. Port layout engine (hardest part)
8. Port render command generation
9. Wrap public API (OpenElement, CloseElement, BeginLayout, EndLayout)

**Verification**: Build a complex static layout and diff Lua vs C render commands line-by-line

## Documentation

Comprehensive documentation is available in README.md, which consolidates all project documentation including:

- Project overview and declarative shell API usage
- "Lua as C" programming model: architecture philosophy, C-core vs Shell layer separation, performance patterns
- Systematic guidelines for porting clay.h to LuaJIT with type translation rules and workflow checklist
- Testing strategy, reference library build, comparison utilities, and mock measurement helpers

Note: The original individual documentation files (llay.md, lua-as-c.md, porting-guide.md, testing.md) are preserved in the repository for reference but README.md is the authoritative and up-to-date version.
