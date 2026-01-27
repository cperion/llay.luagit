# Lua as C

> **Note:** This file has been superseded by the consolidated README.md. The content has been merged with docs/llay.md, docs/porting-guide.md, and docs/testing.md into a single authoritative documentation file in the root. This file is preserved for historical reference only.

A systems-style programming model for LuaJIT where Lua is used as a control language and FFI cdata is used as the primary data representation.

## Summary

This model treats LuaJIT as a **JIT-compiled, low-level systems language** with:

- explicit memory ownership
- flat data structures
- predictable execution
- minimal garbage collection pressure

The goal is to achieve **C-like performance characteristics** (memory layout, cache locality, determinism) while retaining Lua's productivity, portability, and metaprogramming strengths.

This approach is suitable for real-time systems, engines, simulations, and data-oriented workloads.

## Motivation

### Problems with idiomatic Lua in hot systems

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

### Why LuaJIT changes the equation

LuaJIT provides:

- a high-quality tracing JIT
- a powerful FFI system
- predictable numeric and pointer semantics

These enable a programming style closer to C than to dynamic scripting — **if the data model is designed accordingly**.

## Core Idea

> Use Lua for control flow and orchestration, and use cdata for all persistent state.

In this model:

- Lua tables are *configuration and glue*
- cdata arrays and structs are *the system*
- algorithms are written as tight, index-based loops
- allocations are explicit and amortized
- GC is avoided in hot paths

## Design Principles

### 1. Data-Oriented Design First

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

### 2. Stable Indices, Not Objects

Entities/nodes/components are identified by integer IDs. IDs map directly to array indices or indirection tables. Lifetimes are explicit (free lists, generations if needed).

This enables:

- deterministic iteration
- easy serialization
- trivial bulk processing

### 3. Explicit Memory Management

- Preallocate buffers using `ffi.new("T[?]", capacity)`
- Grow capacity manually (doubling strategy)
- Reuse scratch buffers per frame/tick

Memory ownership rules are explicit and documented.

### 4. Zero Allocation Hot Paths

In hot loops:

- no table creation
- no closures
- no string manipulation
- no implicit boxing

All temporary state lives in:

- local variables
- preallocated scratch arrays

### 5. Typed Enums and Bitfields

Replace strings and dynamic flags with numeric enums and packed bitfields (`uint32_t`).

This improves speed, memory footprint, and branch predictability.

### 6. Deterministic Execution

The system should guarantee:

- same input → same output
- no dependence on GC timing
- no hidden iteration order

This is critical for:

- simulations
- layout systems
- replays
- networking

## Programming Model

### What Lua is used for

- control flow
- system orchestration
- high-level API
- debugging tools
- build-time code generation

### What cdata is used for

- persistent state
- large datasets
- frequently accessed fields
- interop boundaries

## Performance Characteristics

### Expected behavior

- Near-C performance for numeric loops
- Very low GC pressure
- Excellent cache locality
- Predictable frame times

### Realistic limits

- Slower than hand-tuned C in extreme cases
- Sensitive to JIT availability
- Requires discipline and tooling

For most engine-style workloads, performance is **"fast enough to never matter"**.

## Safety and Debugging Strategy

### Development mode

- bounds checks
- assertions
- canary values
- optional shadow tables for validation

### Release mode

- checks disabled
- raw array access
- maximum performance

Debug tooling is considered a first-class requirement, not an afterthought.

## Comparison to Alternatives

| Approach                | Pros                       | Cons                               |
| ----------------------- | -------------------------- | ---------------------------------- |
| Native C/C++            | Maximum control            | Build complexity, ABI, portability |
| Lua tables              | Simple, idiomatic          | GC pressure, poor locality         |
| LuaJIT FFI (this model) | Fast, portable, expressive | Requires discipline                |

## Use Cases

This model is well suited for:

- engines and subsystems
- simulations
- physics / layout / animation solvers
- ECS implementations
- audio/DSP graphs
- data pipelines inside games/tools

## Non-Goals

- Replacing idiomatic Lua everywhere
- Competing with C for low-level OS work
- Providing full memory safety guarantees

This is an **opt-in systems style**, not a default programming paradigm.

## LuaJIT Unique Strengths

The "Lua as C" model gets much stronger when you deliberately use LuaJIT's meta-layer at the boundaries, not in the hot loops.

### C-core, Meta-shell Architecture

**Rule of thumb:**

> Hot path = "C style" (arrays, integers, no allocation)
> Boundaries = "Lua style" (metamethods, views, safety, ergonomics)

This architecture has two layers:

#### Core layer (the C-like heart)

- storage: cdata arrays / structs
- algorithms: loops over integer indices
- no tables allocated in per-tick/per-frame
- explicit memory growth and reuse

#### Shell layer (LuaJIT meta-features)

- ergonomic user API
- proxies/views
- constructors & builders
- debug checks + diagnostics
- resource lifetime helpers

#### Boundary contract

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

## Concrete Patterns

### Pattern A: "Handle + SoA"

- Core state: SoA arrays
- Handle: `uint32_t id`
- Shell exposes `Entity(id)` as a lightweight proxy with `__index` / `__newindex`

### Pattern B: "Arena object"

- Arena owns all core buffers
- Arena is a cdata object with `__gc` freeing buffers
- Optional `arena:reset()` to reuse memory

### Pattern C: "Debug view toggles"

- In debug builds, use proxies by default
- In release builds, proxies exist but are opt-in

### Pattern D: "Bulk operations only"

Avoid per-element callbacks across layers. Expose:

- `get_rects(ids, out)` not `get_rect(id)` in a loop
- `apply_styles(n, style_ids)` not per node function calls

## What Makes This Uniquely LuaJIT

Standard Lua gives you metatables, but not:

- FFI cdata as a primary storage type
- metatypes over cdata
- low-overhead typed arrays/pointers
- JIT specializing hot loops over numeric arrays

The combo is the point:

> **Typed memory core + dynamic meta façade**.

## LuaJIT-as-C Discipline (C-core, Meta-shell)

### Goal

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

### Layering Rule: Two Worlds

#### Core (hot path) world

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

#### Shell (boundary) world

**Can be Lua-like.** Allowed constructs:

- metatables, metatypes, views/proxies
- validations, asserts, rich error messages
- table-based configuration and DSLs
- convenience methods

Shell is where you pay the dynamic tax.

### Allocation Discipline

#### Allocation zones

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

#### Amortized growth only

If a buffer must grow:

- grow by doubling (or 1.5x)
- never `ffi.new` per element
- never resize inside an inner loop

#### Strings and tables

- strings are allowed only as **IDs or debug labels**
- tables in hot paths are forbidden
- convert user config tables to packed numeric structs once, then store them

### Representation Discipline (Data Model)

#### IDs are integers, not references

Every entity/node/etc. is identified by an integer **ID**.

- never store Lua object references in core arrays
- never store cdata pointers to ephemeral objects

#### Indirection & safety (generations)

To avoid use-after-free:

- maintain `generation[id]`
- represent handles as `(id, gen)` or packed 32/64-bit value
- validate handles in shell/debug, not core

**Rule:** core functions accept **validated ids** only; shell enforces validation.

#### Prefer SoA for hot fields

- frequently accessed fields: SoA arrays (`x[i]`, `y[i]`, `vx[i]`…)
- rarely accessed fields can be AoS (`struct Node { ... }`) if it simplifies code

#### No pointer-rich structures in the core

Avoid:

- linked lists using pointers
- trees of heap allocations

Prefer:

- adjacency encoded via indices (`firstChild[i]`, `nextSibling[i]`)
- packed arrays and ranges

### Metatables / Metatypes Discipline

#### Metatypes are API, not core

`ffi.metatype` is allowed for:

- constructors (`new`, `init`)
- explicit methods (`:free()`, `:reset()`)
- debug printing (`__tostring`)
- convenience accessors (non-hot path)

Metatypes are **for humans**, not for inner loops.

#### Views/proxies are read/write facades only

Using `__index` / `__newindex` is allowed **only** for:

- external API ergonomics
- debug tooling
- scripting layers

**Hard rule:** core algorithms never access state through proxy objects.

#### No metamethod dispatch in tight loops

Forbidden in core loops:

- `obj:method()` where `obj` triggers metatype lookup
- property access that hits `__index`
- `__call` sugar

If you need methods in the core:

- call plain module functions that take raw arrays/ids

### Ownership & Lifetime Discipline

#### Explicit free is primary

Every owned resource must have:

- `free()` method (deterministic release)
- idempotent (safe to call twice)
- sets handle to "dead" state

#### `__gc` is a safety net

`__gc` is allowed for:

- leak prevention
- cleanup on error paths
- final release of arenas/buffers

But you never *rely* on `__gc` timing.

#### Arena pattern is preferred

For transient memory:

- per-tick/per-frame arena
- `arena:reset()` at boundary
- scratch buffers are reused, never freed

### API Boundary Contract

#### Shell validates, core assumes

All expensive checks happen at boundary:

- bounds
- handle validity
- enum ranges
- invariant checks

Core functions assume:

- inputs are valid
- buffers are large enough
- IDs are alive

#### Bulk calls only

Crossing boundaries is expensive. Prefer:

- `compute_all(n)` over `compute_one(i)` in loops
- `get_rects(ids, out)` over repeated `get_rect(id)`

### Determinism Discipline

#### Stable iteration order

- never use hash-table iteration in core logic
- store child lists as ordered indices
- any "unordered set" is represented as:

  - sorted array, or
  - packed dense list + explicit order

#### Float strategy

Pick a float policy and enforce it:

- use doubles consistently (Lua numbers)
- avoid NaNs in outputs (assert in debug)
- clamp where needed

#### No hidden time-dependent behavior

- no GC-dependent behavior
- no reliance on table iteration order
- no implicit randomness without seeded RNG

### Debug & Instrumentation Discipline

#### Debug mode must be first-class

Provide a build/runtime flag:

- `DEBUG=1` enables checks, assertions, canaries
- `DEBUG=0` strips checks (or gates them)

#### Shadow validation structures (optional)

In debug:

- shadow tables can mirror ownership/state for better error messages
- core stores only compact numeric metadata

#### "Explain" hooks

Core should optionally record:

- reason codes (enums)
- counters/timings
- last error id

But only when debug flag is on.

### Coding Rules (the "lintable" part)

#### Hard bans in core modules

- `pairs`, `ipairs`
- `table.insert/remove`
- creating tables in loops
- closures created in loops
- `pcall/xpcall` in hot paths
- `string.*` in hot paths
- metamethod access in hot paths
- `ffi.new` in hot loops

#### Required patterns

- `local`-bind hot functions (`local band=bit.band`, etc.) if you use them a lot
- separate functions per major enum path (reduce branching)
- preallocate all output arrays

### Definition of "core module"

A module is "core" if it is called:

- per element per tick/frame, OR
- in O(n) over large n frequently, OR
- on latency-critical paths

Core modules must follow all hard rules above. Everything else can be normal Lua.

## Conclusion

Treating **LuaJIT as "C with a better macro system"** unlocks a powerful middle ground between scripting and native code. By committing to a cdata-centric, data-oriented design, developers can build high-performance, deterministic systems without sacrificing portability or iteration speed.
