# Llay Development Guide

Complete documentation for the Llay project - a high-performance 2D layout library written in LuaJIT.

**Note**: This document consolidates content from multiple original documentation files:
- docs/llay.md
- docs/lua-as-c.md
- docs/porting-guide.md
- docs/testing.md

The individual files are preserved in the `docs/` directory for reference.

---

## Table of Contents

1. [Llay Overview](#llay-overview)
2. [Development Workflow](#development-workflow)
3. [Lua as C Programming Model](#lua-as-c-programming-model)
4. [Porting Guidelines](#porting-guidelines)
5. [Testing Strategy](#testing-strategy)
6. [Tools](#tools)

---

## Llay Overview

### Introduction

Llay is a LuaJIT rewrite of the Clay layout engine following the "Lua as C" programming discipline. This achieves near-C performance through data-oriented design, explicit memory management, and minimal GC pressure.

### Architecture

Llay follows the "C-core, Meta-shell" architecture:

- **Core Layer:** cdata arrays/structs, index-based loops, explicit memory management (C-like)
- **Shell Layer:** declarative DSL, ergonomic APIs, safety checks (Lua-like)

### Project Structure

```
llay/
├── clay/              # Clay layout engine (git submodule - reference C impl)
├── src/
│   ├── ffi.lua        # FFI cdef declarations only - copy C structs exactly
│   ├── core.lua       # Core layer (C-like, replaces CLAY_IMPLEMENTATION)
│   ├── shell.lua      # Public shell (declarative DSL API)
│   └── init.lua       # Main entry point
├── tests/             # Test suite
├── tools/             # Development tools
└── examples/          # Usage examples
```

### Dependencies

- LuaJIT 2.1 or later
- Clay layout engine (as git submodule)

### Declarative Shell API

The shell provides a declarative DSL that feels like HTML or SwiftUI using Lua's syntactic sugar.

#### Key Patterns

1. **Polymorphic Arguments:** Detect if the argument is a String (simple text) or a Table (complex config)
2. **Array-Closure Pattern:** Use the numeric array part of the table `t[1]` to hold the children function

#### Example Usage

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

#### Shell Implementation Patterns

##### Generic Element Wrapper

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

##### Text Handling

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

##### Style Objects

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

##### Mixin Handling

```lua
if type(arg[1]) == "cdata" then
    config_ptr[0] = arg[1]
    children_fn = arg[2]
else
    children_fn = arg[1]
end
```

##### Zero-Garbage Option (Builder Pattern)

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

#### API Summary

| Element | Syntax Sugar | Description |
| :--- | :--- | :--- |
| Containers | `llay.row { gap=10, func }` | Uses array part `[1]` for children closure |
| Text | `llay.text "Hello"` | Unary string argument |
| Text Config | `llay.text { "Hello", size=20 }` | Unary table, string at `[1]` |
| Styles | `llay.style { ... }` | Returns a C-struct for reuse |
| Mixins | `llay.row { style, func }` | Pass style at `[1]`, func at `[2]` |

---

## Development Workflow

### Committing Code

**Commit regularly** - After completing a task or feature, commit with a descriptive message. This is standard practice in this project.

```bash
git add -A
git commit -m "type(scope): description"
```

### Conventional Commits

Use this specification for structured, meaningful commit messages:

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
- `chore: update tools/seek script`

**Breaking changes:**
- Add `!` after type/scope: `feat(api)!: breaking API change`
- Or add footer: `BREAKING CHANGE: <description>`

### Build & Test Commands

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

### Code Style Guidelines

#### Core Principles

**C-Core (Hot Path) Rules:**
- Use cdata arrays/structs for all persistent state
- Zero-based indexing for all cdata arrays: `for i = 0, count - 1 do ... end`
- Integer IDs and numeric enums - no strings in hot paths
- Explicit memory management via arenas
- **NO allocations** in hot loops: no tables, no closures, no string manipulation
- No metamethod dispatch in tight loops: no `__index`, `__call`, `__newindex`
- No `pairs()`/`ipairs()` iteration in core logic
- No `ffi.new` in inner loops

**Shell (Boundary) Rules:**
- Metatables, metatypes, views/proxies allowed
- Table-based configuration and DSLs
- Validation, asserts, rich error messages
- Conveniences and ergonomics

#### Imports

```lua
-- Standard pattern
local ffi = require("ffi")
-- Local bind for hot paths
local bit = require("bit")
local band, bor = bit.band, bit.bor
```

#### Naming Conventions

- **Modules**: lowercase with underscores: `layout_calculator.lua`
- **Functions**: snake_case for core, snake_case for shell
- **Enums**: PascalCase constant tables: `local LayoutDirection = { LEFT_TO_RIGHT = 0, TOP_TO_BOTTOM = 1 }`
- **C structs**: PascalCase matching clay.h: `Clay_LayoutConfig`, `Clay_ElementId`
- **Variables**: camelCase or snake_case (be consistent within file)
- **Constants**: UPPER_CASE: `MAX_MEMORY`, `EPSILON`

#### Type Translation from C to Lua

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
```lua
local config_ptr = ffi.cast("Clay_LayoutConfig*", arena_ptr)
```

#### Code Style Rules

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

#### Memory Management

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

#### Error Handling

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

#### Forbidden in Hot Paths (Core)

- `pairs()`, `ipairs()`
- `table.insert()`, `table.remove()`
- Creating tables `{}` in loops
- Creating closures `function() end` in loops
- `pcall()`, `xpcall()` in hot paths
- `string.*` functions in hot paths
- Metamethod access (`obj.field`, `obj:method()` via metatype)
- `ffi.new()` in loops

#### Required Patterns for Performance

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

# Find a type
./tools/seek list | grep Clay_Render
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
jq '.["parser-directories"] += ["vendor/parsers"]' ~/.config/tree-sitter/config.json > /tmp/config.json
mv /tmp/config.json ~/.config/tree-sitter/config.json
```

See `tools/README.md` for more details.

### Porting from clay.h Checklist

1. Port dependency-free types (Vector2, Color, Dimensions, BoundingBox) to ffi.lua
2. Port config types (LayoutConfig, ElementConfig) to ffi.lua
3. Port Context struct to ffi.lua
4. Implement arena allocation functions in core.lua
5. Port math helpers and hash functions (drop SIMD, use scalar fallback)
6. Port text measurement callback system
7. Port layout engine (hardest part)
8. Port render command generation
9. Wrap public API (OpenElement, CloseElement, BeginLayout, EndLayout)

**Verification**: Build a complex static layout and diff Lua vs C render commands line-by-line.

---

## Lua as C Programming Model

### Summary

A systems-style programming model for LuaJIT where Lua is used as a control language and FFI cdata is used as the primary data representation.

This model treats LuaJIT as a **JIT-compiled, low-level systems language** with:
- explicit memory ownership
- flat data structures
- predictable execution
- minimal garbage collection pressure

The goal is to achieve **C-like performance characteristics** (memory layout, cache locality, determinism) while retaining Lua's productivity, portability, and metaprogramming strengths.

This approach is suitable for real-time systems, engines, simulations, and data-oriented workloads.

### Motivation

#### Problems with idiomatic Lua in hot systems

Traditional Lua patterns rely on:
- tables as objects
- nested structures
- short-lived allocations
- implicit memory management

For high-frequency workloads, this causes:
- GC overhead
- poor cache locality
- non-deterministic performance
- difficult profiling and debugging

#### Why LuaJIT changes the equation

LuaJIT provides:
- a high-quality tracing JIT
- a powerful FFI system
- predictable numeric and pointer semantics

These enable a programming style closer to C than to dynamic scripting — **if the data model is designed accordingly**.

### Core Idea

> Use Lua for control flow and orchestration, and use cdata for all persistent state.

In this model:
- Lua tables are *configuration and glue*
- cdata arrays and structs are *the system*
- algorithms are written as tight, index-based loops
- allocations are explicit and amortized
- GC is avoided in hot paths

### Design Principles

#### 1. Data-Oriented Design First

Prefer **Structure of Arrays (SoA)** over nested structs. Use flat numeric indices instead of object references. Avoid pointer chasing.

Example:
```lua
posX[i], posY[i]
velX[i], velY[i]
mass[i]
```

Not:
```lua
entities[i].position.x
```

#### 2. Stable Indices, Not Objects

Entities/nodes/components are identified by integer IDs. IDs map directly to array indices or indirection tables. Lifetimes are explicit (free lists, generations if needed).

This enables:
- deterministic iteration
- easy serialization
- trivial bulk processing

#### 3. Explicit Memory Management

- Preallocate buffers using `ffi.new("T[?]", capacity)`
- Grow capacity manually (doubling strategy)
- Reuse scratch buffers per frame/tick

Memory ownership rules are explicit and documented.

#### 4. Zero Allocation Hot Paths

In hot loops:
- no table creation
- no closures
- no string manipulation
- no implicit boxing

All temporary state lives in:
- local variables
- preallocated scratch arrays

#### 5. Typed Enums and Bitfields

Replace strings and dynamic flags with numeric enums and packed bitfields (`uint32_t`).

This improves speed, memory footprint, and branch predictability.

#### 6. Deterministic Execution

The system should guarantee:
- same input → same output
- no dependence on GC timing
- no hidden iteration order

This is critical for:
- simulations
- layout systems
- replays
- networking

### Programming Model

#### What Lua is used for
- control flow
- system orchestration
- high-level API
- debugging tools
- build-time code generation

#### What cdata is used for
- persistent state
- large datasets
- frequently accessed fields
- interop boundaries

### Performance Characteristics

#### Expected behavior
- Near-C performance for numeric loops
- Very low GC pressure
- Excellent cache locality
- Predictable frame times

#### Realistic limits
- Slower than hand-tuned C in extreme cases
- Sensitive to JIT availability
- Requires discipline and tooling

For most engine-style workloads, performance is **"fast enough to never matter"**.

### Safety and Debugging Strategy

#### Development mode
- bounds checks
- assertions
- canary values
- optional shadow tables for validation

#### Release mode
- checks disabled
- raw array access
- maximum performance

Debug tooling is considered a first-class requirement, not an afterthought.

### Comparison to Alternatives

| Approach                | Pros                       | Cons                               |
| ----------------------- | -------------------------- | ---------------------------------- |
| Native C/C++            | Maximum control            | Build complexity, ABI, portability |
| Lua tables              | Simple, idiomatic          | GC pressure, poor locality         |
| LuaJIT FFI (this model) | Fast, portable, expressive | Requires discipline                |

### Use Cases

This model is well suited for:
- engines and subsystems
- simulations
- physics / layout / animation solvers
- ECS implementations
- audio/DSP graphs
- data pipelines inside games/tools

### Non-Goals
- Replacing idiomatic Lua everywhere
- Competing with C for low-level OS work
- Providing full memory safety guarantees

This is an **opt-in systems style**, not a default programming paradigm.

### LuaJIT Unique Strengths

The "Lua as C" model gets much stronger when you deliberately use LuaJIT's meta-layer at the boundaries, not in the hot loops.

#### C-core, Meta-shell Architecture

**Rule of thumb:**

> Hot path = "C style" (arrays, integers, no allocation)
> Boundaries = "Lua style" (metamethods, views, safety, ergonomics)

This architecture has two layers:

##### Core layer (the C-like heart)
- storage: cdata arrays / structs
- algorithms: loops over integer indices
- no tables allocated in per-tick/per-frame
- explicit memory growth and reuse

##### Shell layer (LuaJIT meta-features)
- ergonomic user API
- proxies/views
- constructors & builders
- debug checks + diagnostics
- resource lifetime helpers

##### Boundary contract

The shell builds/updates core buffers, then calls core functions that assume:
- data is valid
- types are stable
- no allocations needed

### Unique LuaJIT Features

#### 1. FFI cdata as a real value type

In LuaJIT, cdata isn't just for calling external C—it's a **native, JIT-friendly storage format**.

- Represent your entire world state as typed buffers
- Do pointer arithmetic / indexing like C
- Keep GC pressure low (few Lua objects, lots of cdata)

The real win: **you can wrap cdata with Lua semantics** via metatypes.

#### 2. `ffi.metatype` — "struct methods" without tables

`ffi.metatype("MyStruct", { __index = {...}})` gives you methods on cdata structs with typed field access.

- Use metatype methods for **construction, validation, debugging, convenience**
- Avoid calling metamethods in tight loops; use raw arrays/struct fields there

Metatype is your "header file" experience: types + methods, but you still keep the core data-oriented.

#### 3. Metatables as *views* over cdata

Keep SoA or packed buffers internally, but expose a **table-like view** with `__index` / `__newindex`.

- Nice syntax `entity.pos.x`
- Internally it reads/writes `posX[id]`, `posY[id]`

The "entity object" is a tiny Lua proxy or cdata handle with `__index` mapping property names to typed buffers. Hot loops never use the proxy; they use raw arrays.

This gives you:
- fast internal engine
- nice external "object" feel

#### 4. `__gc` on cdata — deterministic-ish resource lifetime

LuaJIT supports `__gc` for certain cdata objects, useful for systems that hold raw memory blocks, file handles, OS resources.

- Treat some objects like RAII-lite
- Allocate in constructor, attach `__gc` finalizer
- Optionally also provide explicit `:free()` for deterministic release
- Create "arena objects" whose `__gc` frees all buffers in one shot

**Ownership model:** explicit free is the norm; `__gc` is the safety net.

#### 5. `__index` fallback and interned method tables

Avoid storing methods per object. Instead:
- metatype `__index` points to a shared method table
- instances are just raw cdata, no per-instance method tables

This is basically C++ vtables but cheaper and more explicit.

#### 6. Optional runtime safety without sacrificing release performance

**Debug mode:**
- views (metatables) enforce bounds checks, type checks, asserts
- additional metadata arrays (generation counters, canaries)

**Release mode:**
- bypass metamethods in hot paths
- raw indexing only
- checks stripped or gated

You get "C with debug asserts", but in Lua.

#### 7. JIT-friendly control patterns

LuaJIT traces and specializes based on stable types and stable loop bodies. The "Lua as C" style pairs well with:
- integer enums instead of strings
- bitflags instead of dynamic tables
- separated code paths (row-layout vs column-layout) rather than branchy mega-functions

This is similar to how you'd write branchless or predictable code in C.

### Concrete Patterns

#### Pattern A: "Handle + SoA"
- Core state: SoA arrays
- Handle: `uint32_t id`
- Shell exposes `Entity(id)` as a lightweight proxy with `__index` / `__newindex`

#### Pattern B: "Arena object"
- Arena owns all core buffers
- Arena is a cdata object with `__gc` freeing buffers
- Optional `arena:reset()` to reuse memory

#### Pattern C: "Debug view toggles"
- In debug builds, use proxies by default
- In release builds, proxies exist but are opt-in

#### Pattern D: "Bulk operations only"

Avoid per-element callbacks across layers. Expose:
- `get_rects(ids, out)` not `get_rect(id)` in a loop
- `apply_styles(n, style_ids)` not per node function calls

### What Makes This Uniquely LuaJIT

Standard Lua gives you metatables, but not:
- FFI cdata as a primary storage type
- metatypes over cdata
- low-overhead typed arrays/pointers
- JIT specializing hot loops over numeric arrays

The combo is the point:
> **Typed memory core + dynamic meta façade**.

### LuaJIT-as-C Discipline (C-core, Meta-shell)

#### Goal

Guarantee in the core:
- Predictable performance (no GC spikes, minimal allocation)
- Deterministic behavior (stable iteration, stable results)
- Data locality (contiguous arrays, low pointer chasing)
- Debuggability (assertions + introspection without changing core)

And still allow:
- ergonomic APIs
- safety checks
- convenient views
- RAII-ish cleanup

#### Layering Rule: Two Worlds

##### Core (hot path) world

**Must be C-like.** Allowed constructs:
- cdata arrays/structs as primary storage
- integer IDs and indices
- numeric enums / bitflags
- `for i=... do` tight loops
- scratch buffers reused from pools/arenas

**Forbidden in core loops:**
- allocating Lua tables
- creating closures
- using metamethod-driven access (`__index`, `__newindex`, `__call`, etc.)
- string-heavy logic
- `pairs()` / `ipairs()` (non-deterministic / slower)
- calling user callbacks
- implicit growth of arrays/buffers

##### Shell (boundary) world

**Can be Lua-like.** Allowed constructs:
- metatables, metatypes, views/proxies
- validations, asserts, rich error messages
- table-based configuration and DSLs
- convenience methods

Shell is where you pay the dynamic tax.

#### Allocation Discipline

##### Allocation zones

Define explicit zones where allocations are permitted:

**Zone A: Init / load**
- allocate long-lived buffers
- build lookup tables
- compile patterns
- create method tables

**Zone B: Frame/tick boundary**
- grow buffers (amortized)
- reset arenas
- refill scratch pools

**Zone C: Hot loop**
- **no allocations** (hard rule)

##### Amortized growth only

If a buffer must grow:
- grow by doubling (or 1.5x)
- never `ffi.new` per element
- never resize inside an inner loop

##### Strings and tables
- strings are allowed only as **IDs or debug labels**
- tables in hot paths are forbidden
- convert user config tables to packed numeric structs once, then store them

#### Representation Discipline (Data Model)

##### IDs are integers, not references

Every entity/node/etc. is identified by an integer **ID**.
- never store Lua object references in core arrays
- never store cdata pointers to ephemeral objects

##### Indirection & safety (generations)

To avoid use-after-free:
- maintain `generation[id]`
- represent handles as `(id, gen)` or packed 32/64-bit value
- validate handles in shell/debug, not core

**Rule:** core functions accept **validated ids** only; shell enforces validation.

##### Prefer SoA for hot fields
- frequently accessed fields: SoA arrays (`x[i]`, `y[i]`, `vx[i]`…)
- rarely accessed fields can be AoS (`struct Node { ... }`) if it simplifies code

##### No pointer-rich structures in the core

Avoid:
- linked lists using pointers
- trees of heap allocations

Prefer:
- adjacency encoded via indices (`firstChild[i]`, `nextSibling[i]`)
- packed arrays and ranges

#### Metatables / Metatypes Discipline

##### Metatypes are API, not core

`ffi.metatype` is allowed for:
- constructors (`new`, `init`)
- explicit methods (`:free()`, `:reset()`)
- debug printing (`__tostring`)
- convenience accessors (non-hot path)

Metatypes are **for humans**, not for inner loops.

##### Views/proxies are read/write facades only

Using `__index` / `__newindex` is allowed **only** for:
- external API ergonomics
- debug tooling
- scripting layers

**Hard rule:** core algorithms never access state through proxy objects.

##### No metamethod dispatch in tight loops

Forbidden in core loops:
- `obj:method()` where `obj` triggers metatype lookup
- property access that hits `__index`
- `__call` sugar

If you need methods in the core:
- call plain module functions that take raw arrays/ids

#### Ownership & Lifetime Discipline

##### Explicit free is primary

Every owned resource must have:
- `free()` method (deterministic release)
- idempotent (safe to call twice)
- sets handle to "dead" state

##### `__gc` is a safety net

`__gc` is allowed for:
- leak prevention
- cleanup on error paths
- final release of arenas/buffers

But you never *rely* on `__gc` timing.

##### Arena pattern is preferred

For transient memory:
- per-tick/per-frame arena
- `arena:reset()` at boundary
- scratch buffers are reused, never freed

#### API Boundary Contract

##### Shell validates, core assumes

All expensive checks happen at boundary:
- bounds
- handle validity
- enum ranges
- invariant checks

Core functions assume:
- inputs are valid
- buffers are large enough
- IDs are alive

##### Bulk calls only

Crossing boundaries is expensive. Prefer:
- `compute_all(n)` over `compute_one(i)` in loops
- `get_rects(ids, out)` over repeated `get_rect(id)`

#### Determinism Discipline

##### Stable iteration order
- never use hash-table iteration in core logic
- store child lists as ordered indices
- any "unordered set" is represented as:
  - sorted array, or
  - packed dense list + explicit order

##### Float strategy

Pick a float policy and enforce it:
- use doubles consistently (Lua numbers)
- avoid NaNs in outputs (assert in debug)
- clamp where needed

##### No hidden time-dependent behavior
- no GC-dependent behavior
- no reliance on table iteration order
- no implicit randomness without seeded RNG

#### Debug & Instrumentation Discipline

##### Debug mode must be first-class

Provide a build/runtime flag:
- `DEBUG=1` enables checks, assertions, canaries
- `DEBUG=0` strips checks (or gates them)

##### Shadow validation structures (optional)

In debug:
- shadow tables can mirror ownership/state for better error messages
- core stores only compact numeric metadata

##### "Explain" hooks

Core should optionally record:
- reason codes (enums)
- counters/timings
- last error id

But only when debug flag is on.

#### Coding Rules (the "lintable" part)

##### Hard bans in core modules
- `pairs`, `ipairs`
- `table.insert/remove`
- creating tables in loops
- closures created in loops
- `pcall/xpcall` in hot paths
- `string.*` in hot paths
- metamethod access in hot paths
- `ffi.new` in hot loops

##### Required patterns
- `local`-bind hot functions (`local band=bit.band`, etc.) if you use them a lot
- separate functions per major enum path (reduce branching)
- preallocate all output arrays

##### Definition of "core module"

A module is "core" if it is called:
- per element per tick/frame, OR
- in O(n) over large n frequently, OR
- on latency-critical paths

Core modules must follow all hard rules above. Everything else can be normal Lua.

### Conclusion

Treating **LuaJIT as "C with a better macro system"** unlocks a powerful middle ground between scripting and native code. By committing to a cdata-centric, data-oriented design, developers can build high-performance, deterministic systems without sacrificing portability or iteration speed.

---

## Porting Guidelines

Systematic guidelines for porting `clay.h` to LuaJIT using the **Lua-as-C** paradigm. The goal is to minimize translation friction and prevent logical errors from creeping in during the port.

### Exploring clay.h

**Primary method: Use `tools/seek`**

Do not read clay.h directly—use the tree-sitter-based `tools/seek` script to query struct and enum definitions in C codebases.

```bash
# List all available types
./tools/seek list

# Show a specific type definition when porting
./tools/seek show Clay_Dimensions
./tools/seek show Clay_LayoutConfig
./tools/seek show Clay_ElementConfig

# Search for types matching a pattern
./tools/seek list | grep -i sizing
./tools/seek list | grep Config
```

This is the recommended workflow for:
- Discovering available types in clay.h
- Understanding struct field layouts
- Checking enum values and member names
- Copying definitions precisely to `src/ffi.lua`

Direct file reading of `clay.h` is a fallback only. See the Tools section for setup instructions.

### File Structure & Scope

Split the library to separate the "C-definition" from the "Implementation":

- **`src/ffi.lua`**: Contains **only** the `ffi.cdef` declarations. Copy the C structs here.
- **`src/core.lua`**: Contains the logic. This replaces `CLAY_IMPLEMENTATION`.
- **`src/shell.lua`**: The public shell (the declarative DSL API).
- **`src/init.lua`**: Main entry point.

### The Golden Rule: 0-Based Indexing

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

### Struct & Type Translation Guidelines

#### Structs

Copy struct definitions exactly. Do not rename fields.

#### Unions

`clay.h` uses anonymous unions (e.g., inside `Clay_SizingAxis`). LuaJIT supports this. Keep them exactly as is.

#### Enums

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

#### Pointers vs Values

In C, `Clay_LayoutConfig config` is a value, `Clay_LayoutConfig* config` is a pointer.

In LuaJIT:
- **Reading:** `element.config` usually returns a *copy* (reference wrapper) or value depending on access
- **Guideline:** Explicitly use pointers for everything that acts as mutable state
  - Use `ffi.cast("Clay_LayoutConfig*", ptr)` if you need to perform pointer arithmetic
  - Pass pointers to functions, not copies

### Memory Management Guidelines

Clay uses an internal Arena. We must replicate this manual memory management.

#### The "Global" Context

`clay.h` uses static variables (e.g., `Clay__currentContext`). In Lua, these become **Module Locals** in `core.lua`.

```lua
local context = ffi.new("Clay_Context") -- The persistent instance
local internal_arena = ffi.new("uint8_t[?]", MAX_MEMORY) -- The heap
```

#### Arrays (The Array Macro)

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

### Control Flow & Logic Translation

#### Macros

`clay.h` uses macros for min/max/string handling.

**Guideline:** Convert macros to `local function` inside `core.lua`. LuaJIT will inline them effectively.

```lua
local function CLAY__MAX(x, y) return x > y and x or y end
local function CLAY__MIN(x, y) return x < y and x or y end
```

#### Boolean Logic

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

#### Pointer Arithmetic

Clay does `ptr++` or `ptr += offset`.

**Guideline:** LuaJIT supports pointer arithmetic on typed pointers.

```lua
-- C:  char *chars = buffer->internalArray + buffer->length;
-- Lua: local chars = buffer.internalArray + buffer.length
```

**Note:** Ensure the variable being added to is a cdata pointer, not a Lua number.

### Specific clay.h Features Translation

#### `CLAY(...)` Macro (The Latch)

The C macro `CLAY(...)` uses a `for` loop hack to open and close elements.

**Translation:** This disappears in the Core. The Core only exposes `OpenElement` and `CloseElement`. The "Shell" (API layer) handles the nesting via closures.

#### String Handling (`Clay_String`)

Clay handles strings as `{ length, chars* }` (slices).

**Guideline:** Do not convert to Lua strings internally. Keep them as structs.
- When receiving a Lua string from API: `ffi.cast("const char*", str)`
- String equality: Use `ffi.string` only if necessary for hashing, or write a `memcmp` helper in Lua for the hot path

#### SIMD

`clay.h` has optional SIMD for hashing.

**Guideline:** Drop SIMD for the initial port. LuaJIT's compiler generates very good assembly for simple loops. Port the scalar fallback version of `Clay__HashString`.

### Workflow Checklist (Execution Order)

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

### Verification Strategy (The "Diff" Test)

To ensure correctness without debugging logical needles in a haystack:

1. Create a **C** program using `clay.h` that builds a specific, complex static layout and dumps the `Clay_RenderCommandArray` (x, y, width, height, color) to a text file
2. Create a **Lua** script using the port that builds the *exact same layout*
3. Dump the Lua render commands to a text file
4. **Diff** the two text files. They should be identical down to the float epsilon

### Example Translation: `Clay__SizeContainersAlongAxis`

#### C Original

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

#### Lua Port

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

---

## Testing Strategy

Use the original Clay C implementation as the source of truth. Compile it as a shared library and call via FFI to verify our Lua implementation produces identical results.

### Architecture

```
tests/
├── clay_ref/           # Reference C implementation wrapper
│   ├── build.lua       # Compiles clay.h to libclay.so
│   └── init.lua        # FFI bindings to libclay.so
├── helpers/
│   ├── compare.lua     # Output comparison utilities
│   └── layouts.lua     # Shared test layout definitions
├── test_layout.lua     # Layout calculation tests
├── test_sizing.lua     # Sizing algorithm tests
├── test_render.lua     # Render command tests
└── run.lua             # Test runner
```

### Building the Reference Library

Create a simple C wrapper that exposes Clay functions:

```c
// tests/clay_ref/clay_impl.c
#define CLAY_IMPLEMENTATION
#include "../../clay/clay.h"

// Export for shared library
__attribute__((visibility("default")))
Clay_Arena Clay_CreateArenaWithCapacity(uint32_t capacity, void* memory) {
    return Clay_CreateArenaWithCapacityAndMemory(capacity, memory);
}

// ... expose other needed functions
```

Build script:

```lua
-- tests/clay_ref/build.lua
local ffi = require("ffi")

local function build()
    local cc = os.getenv("CC") or "gcc"
    local src = "tests/clay_ref/clay_impl.c"
    local out = "tests/clay_ref/libclay.so"

    local cmd = string.format(
        "%s -shared -fPIC -O2 -o %s %s -I.",
        cc, out, src
    )

    local ok = os.execute(cmd)
    if not ok then
        error("Failed to build libclay.so")
    end
end

return { build = build }
```

### FFI Bindings to Reference Library

```lua
-- tests/clay_ref/init.lua
local ffi = require("ffi")

-- Load the shared library
local clay_c = ffi.load("./tests/clay_ref/libclay.so")

-- Declare the C API (subset needed for testing)
ffi.cdef[[
    typedef struct { float x, y; } Clay_Vector2;
    typedef struct { float x, y, width, height; } Clay_BoundingBox;
    typedef struct { float r, g, b, a; } Clay_Color;

    // ... rest of clay.h types

    typedef struct {
        Clay_BoundingBox boundingBox;
        // ... render command fields
    } Clay_RenderCommand;

    typedef struct {
        int32_t length;
        int32_t capacity;
        Clay_RenderCommand* internalArray;
    } Clay_RenderCommandArray;

    // Functions
    void Clay_BeginLayout(void);
    Clay_RenderCommandArray Clay_EndLayout(void);
    void Clay_SetLayoutDimensions(Clay_Dimensions dimensions);
    // ... other functions
]]

return clay_c
```

### Comparison Utilities

```lua
-- tests/helpers/compare.lua
local ffi = require("ffi")

local EPSILON = 0.0001

local function float_eq(a, b)
    return math.abs(a - b) < EPSILON
end

local function bbox_eq(a, b)
    return float_eq(a.x, b.x)
       and float_eq(a.y, b.y)
       and float_eq(a.width, b.width)
       and float_eq(a.height, b.height)
end

local function compare_render_commands(c_array, lua_array)
    if c_array.length ~= lua_array.length then
        return false, string.format(
            "Length mismatch: C=%d, Lua=%d",
            c_array.length, lua_array.length
        )
    end

    for i = 0, c_array.length - 1 do
        local c_cmd = c_array.internalArray[i]
        local lua_cmd = lua_array.internalArray[i]

        if not bbox_eq(c_cmd.boundingBox, lua_cmd.boundingBox) then
            return false, string.format(
                "BoundingBox mismatch at index %d:\n  C:   {x=%f, y=%f, w=%f, h=%f}\n  Lua: {x=%f, y=%f, w=%f, h=%f}",
                i,
                c_cmd.boundingBox.x, c_cmd.boundingBox.y,
                c_cmd.boundingBox.width, c_cmd.boundingBox.height,
                lua_cmd.boundingBox.x, lua_cmd.boundingBox.y,
                lua_cmd.boundingBox.width, lua_cmd.boundingBox.height
            )
        end
    end

    return true
end

local function dump_render_commands(array, filename)
    local f = io.open(filename, "w")
    for i = 0, array.length - 1 do
        local cmd = array.internalArray[i]
        f:write(string.format(
            "%d: x=%f y=%f w=%f h=%f\n",
            i,
            cmd.boundingBox.x, cmd.boundingBox.y,
            cmd.boundingBox.width, cmd.boundingBox.height
        ))
    end
    f:close()
end

return {
    float_eq = float_eq,
    bbox_eq = bbox_eq,
    compare_render_commands = compare_render_commands,
    dump_render_commands = dump_render_commands,
}
```

### Shared Test Layouts

Define layouts that both implementations execute identically:

```lua
-- tests/helpers/layouts.lua

-- Each layout is a function that takes an API table
-- and builds a layout using it. This allows the same
-- layout to be built with either C or Lua API.

local layouts = {}

layouts.simple_row = function(api)
    api.begin_layout()
    api.set_dimensions(800, 600)

    api.open_element({ layout = { direction = "LEFT_TO_RIGHT" } })
        api.open_element({ sizing = { width = 100, height = 50 } })
        api.close_element()

        api.open_element({ sizing = { width = 200, height = 50 } })
        api.close_element()
    api.close_element()

    return api.end_layout()
end

layouts.nested_containers = function(api)
    api.begin_layout()
    api.set_dimensions(800, 600)

    api.open_element({ layout = { direction = "TOP_TO_BOTTOM" } })
        api.open_element({ layout = { direction = "LEFT_TO_RIGHT" }, sizing = { width = "GROW" } })
            api.open_element({ sizing = { width = 100, height = 100 } })
            api.close_element()
            api.open_element({ sizing = { width = 100, height = 100 } })
            api.close_element()
        api.close_element()

        api.open_element({ sizing = { width = "GROW", height = 200 } })
        api.close_element()
    api.close_element()

    return api.end_layout()
end

layouts.flex_grow = function(api)
    api.begin_layout()
    api.set_dimensions(800, 600)

    api.open_element({ layout = { direction = "LEFT_TO_RIGHT" }, sizing = { width = 800 } })
        api.open_element({ sizing = { width = 100, height = 50 } })
        api.close_element()

        api.open_element({ sizing = { width = "GROW", height = 50 } })
        api.close_element()

        api.open_element({ sizing = { width = 100, height = 50 } })
        api.close_element()
    api.close_element()

    return api.end_layout()
end

return layouts
```

### Test Runner

```lua
-- tests/run.lua
local ffi = require("ffi")

-- Build reference library if needed
local build = require("tests.clay_ref.build")
build.build()

-- Load both implementations
local clay_c = require("tests.clay_ref")
local llay = require("llay.core")

local compare = require("tests.helpers.compare")
local layouts = require("tests.helpers.layouts")

-- Create API wrappers that normalize the interface
local function make_c_api()
    -- Initialize C clay
    local memory = ffi.new("uint8_t[?]", 1024 * 1024)
    clay_c.Clay_Initialize(memory, 1024 * 1024)

    return {
        begin_layout = function() clay_c.Clay_BeginLayout() end,
        end_layout = function() return clay_c.Clay_EndLayout() end,
        set_dimensions = function(w, h)
            clay_c.Clay_SetLayoutDimensions(ffi.new("Clay_Dimensions", {w, h}))
        end,
        open_element = function(config)
            -- Translate config to C structs and call
            -- ...
        end,
        close_element = function() clay_c.Clay_CloseElement() end,
    }
end

local function make_lua_api()
    llay.init(1024 * 1024)

    return {
        begin_layout = function() llay.begin_layout() end,
        end_layout = function() return llay.end_layout() end,
        set_dimensions = function(w, h) llay.set_dimensions(w, h) end,
        open_element = function(config) llay.open_element(config) end,
        close_element = function() llay.close_element() end,
    }
end

-- Run tests
local function run_test(name, layout_fn)
    io.write(string.format("Testing %s... ", name))

    local c_api = make_c_api()
    local lua_api = make_lua_api()

    local c_result = layout_fn(c_api)
    local lua_result = layout_fn(lua_api)

    local ok, err = compare.compare_render_commands(c_result, lua_result)

    if ok then
        print("PASS")
        return true
    else
        print("FAIL")
        print("  " .. err)

        -- Dump for debugging
        compare.dump_render_commands(c_result, "/tmp/c_output.txt")
        compare.dump_render_commands(lua_result, "/tmp/lua_output.txt")
        print("  Dumped to /tmp/c_output.txt and /tmp/lua_output.txt")

        return false
    end
end

-- Execute all layout tests
local passed = 0
local failed = 0

for name, layout_fn in pairs(layouts) do
    if run_test(name, layout_fn) then
        passed = passed + 1
    else
        failed = failed + 1
    end
end

print(string.format("\nResults: %d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
```

### Usage

```bash
# Build and run tests
luajit tests/run.lua

# Run specific test file
luajit tests/test_layout.lua
```

### Test Categories

1. **Layout Tests:** Verify bounding box calculations match
2. **Sizing Tests:** Test FIXED, GROW, FIT sizing modes
3. **Direction Tests:** LEFT_TO_RIGHT, TOP_TO_BOTTOM
4. **Padding/Gap Tests:** Spacing calculations
5. **Scroll Tests:** Scroll container behavior
6. **Text Tests:** Text measurement and wrapping (requires mock measure function)
7. **Edge Cases:** Empty containers, single children, deeply nested

### Mock Text Measurement

Both implementations need identical text measurement for tests:

```lua
-- Deterministic mock: 10px per character, 20px height
local function mock_measure_text(text, config)
    return {
        width = #text * 10,
        height = 20
    }
end

-- Set on both C and Lua implementations before tests
clay_c.Clay_SetMeasureTextFunction(mock_measure_text_c)
llay.set_measure_text(mock_measure_text)
```

---

## Tools

This section contains utilities for working with the Clay layout engine codebase.

### seek

Interface to clay.h using tree-sitter CLI for querying struct and enum definitions.

#### Installation (one-time setup)

```bash
# 1. Clone and build tree-sitter C parser
mkdir -p vendor/parsers
cd vendor/parsers
git clone https://github.com/tree-sitter/tree-sitter-c.git c
cd c
tree-sitter build

# 2. Update tree-sitter config to find parsers (if needed)
jq '.["parser-directories"] += ["vendor/parsers"]' ~/.config/tree-sitter/config.json > /tmp/config.json
mv /tmp/config.json ~/.config/tree-sitter/config.json
```

#### Usage

```bash
# List all struct and enum definitions
./tools/seek list

# Show a specific definition
./tools/seek show Clay_Dimensions
./tools/seek show Clay_LayoutConfig

# Find a type
./tools/seek list | grep Clay_Render
```

#### How it works

The `seek` tool uses tree-sitter CLI to parse and query `clay/clay.h` with the C grammar parser. It runs queries defined in `list-types.scm` to find:
- Struct definitions (`typedef struct { ... } Name`)
- Enum definitions (`typedef enum { ... } Name`)

The tool extracts the type names and their full definitions by matching the syntax tree nodes.

---

## License

TBD
