# Llay Porting Tasks

**Context:**
- **Source Truth:** `clay/clay.h`
- **Philosophy:** [docs/lua-as-c.md](docs/lua-as-c.md) (0-based indexing, FFI structs, no GC in hot paths)
- **Porting Rules:** [docs/porting-guide.md](docs/porting-guide.md)

**Recent Progress:**
- `fix(tools): support CLAY_PACKED_ENUM macro-based type definitions` (e8042c9)
- `feat(ffi): add missing type definitions for text and layout` (a4f7722)

**Summary:**
- Phase 1 (FFI Types): ~90% complete (missing some Floating enums)
- Phase 2 (Core Infrastructure): ~60% complete (hashmap items pending)
- Phase 3 (Layout Algorithms): Not started
- Phase 4 (Rendering): Not started
- Phase 5 (Shell API): ~60% complete (helpers pending)
- Phase 6 (Verification): ~50% complete (complex tests pending)

## Phase 1: FFI Definitions (`src/clay_ffi.lua`)

Use `tools/seek show <Name>` to extract these from `clay.h`. This is the primary method for exploring clay.h—direct file reading is a fallback.

- [ ] **Base Types**
    - [x] `Clay_Vector2`, `Clay_Dimensions`, `Clay_BoundingBox`
    - [x] `Clay_Color`, `Clay_String`, `Clay_StringSlice`
    - [x] `Clay_Arena`
 - [x] **Enums** (Convert to `local Enum = { A = 0, B = 1 }`)
     - [x] `Clay_LayoutDirection`
     - [x] `Clay__SizingType`
     - [x] `Clay_TextElementConfigWrapMode`
     - [x] `Clay_TextAlignment`
     - [ ] `Clay_FloatingAttachPointType`, `Clay_PointerCaptureMode`, `Clay_FloatingAttachToElement`, `Clay_FloatingClipToElement`
- [ ] **Config Structs**
    - [x] `Clay_Sizing`, `Clay_Padding`, `Clay_LayoutConfig`
    - [x] `Clay_TextElementConfig`
    - [x] `Clay_ImageElementConfig`, `Clay_FloatingElementConfig`
    - [x] `Clay_CustomElementConfig`, `Clay_BorderElementConfig`, `Clay_SharedElementConfig`
 - [x] **Internal Structs**
     - [x] `Clay_LayoutElement` (Complex nested unions - check `clay_ffi.lua` matches `clay.h`)
     - [x] `Clay_RenderCommand`
     - [x] `Clay__MeasuredWord` (Text measurement caching)
     - [x] `Clay__MeasureTextCacheItem`
     - [x] `Clay_LayoutElementHashMapItem`
     - [x] `Clay__ScrollContainerDataInternal`
- [ ] **Context**
    - [x] `Clay_Context` struct definition (Must match `clay.h` context exactly for memory layout)

## Phase 2: Core Infrastructure (`src/core.lua`)

Implementation of the memory management and basic data structures.

- [x] **Memory Arena**
    - [x] `Clay__Array_Allocate_Arena` (Generic allocator for arrays)
    - [x] `Clay_CreateArenaWithCapacityAndMemory` equivalent (`M.initialize`)
 - [x] **Arrays** (Port `CLAY__ARRAY_DEFINE` macros manually)
     - [x] `Clay_LayoutElementArray`
     - [x] `Clay_RenderCommandArray`
     - [x] `Clay__int32_tArray` (Utility: `add`, `get`, `set`, `remove_swapback`)
     - [x] `Clay__StringArray`
     - [x] `Clay__WrappedTextLineArray`
     - [x] `Clay__MeasureTextCacheItemArray`
 - [x] **HashMap Logic**
     - [x] `Clay__HashString` (Port hash algorithm - DJB2 hash at core.lua:307-317)
     - [ ] `Clay__AddHashMapItem` (Collision handling logic)
     - [ ] `Clay__GetHashMapItem`
- [ ] **Element Management**
    - [x] `Clay__OpenElement`
    - [x] `Clay__CloseElement`
    - [ ] `Clay__ConfigureOpenElement` (Handling Config attachments)
    - [ ] `Clay__GetOpenLayoutElement`

## Phase 3: Layout Algorithms (`src/core.lua`)

**Crucial:** Adhere to 0-based indexing loops. See docs/porting-guide.md.

- [ ] **Text Measurement & Caching**
    - [ ] `Clay__MeasureTextCached` (Hash map lookup)
    - [ ] `Clay__MeasureText` (The actual sizing logic)
- [ ] **Sizing Logic (`Clay__SizeContainersAlongAxis`)**
    This is the core layout engine. Break it down:
    - [ ] Pass 1: Size `FIXED` and `PERCENT` containers.
    - [ ] Pass 2: Calculate `innerContentSize` and `growContainerCount`.
    - [ ] Pass 3: Distribute free space to `GROW` containers.
    - [ ] Pass 4: Compress containers if parent doesn't fit (and not wrapping).
- [ ] **Final Layout (`Clay__CalculateFinalLayout`)**
    - [ ] X-Axis Sizing Pass (Call `SizeContainersAlongAxis(true)`)
    - [ ] Text Wrapping Loop (Calculate line breaks based on width)
    - [ ] Height propagation (Child height affecting parent)
    - [ ] Y-Axis Sizing Pass (Call `SizeContainersAlongAxis(false)`)
    - [ ] Final Position Calculation (DFS Traversal)
        - [ ] Calculate absolute positions (x, y)
        - [ ] Handle `Floating` elements (Z-index sorting, absolute positioning)
        - [ ] Handle `Scroll` containers (Offset child positions)

## Phase 4: Rendering (`src/core.lua`)

- [ ] **Command Generation**
    - [ ] `Clay__CreateRenderCommands` (Iterate calculated layout)
    - [ ] Culling check (`Clay__ElementIsOffscreen`)
    - [ ] Scissor commands for `Scroll` containers
    - [ ] Rect/Border/Text command generation
- [ ] **Scroll Handling**
    - [ ] `Clay_UpdateScrollContainers` (Momentum, delta handling)
    - [ ] `Clay_GetScrollContainerData`

## Phase 5: Shell API (`src/shell.lua`)

The user-facing Lua interface.

- [x] **Element Constructors**
    - [x] `container`, `row`, `column` (Generic wrappers)
    - [x] `text` (String/Config handling)
- [ ] **Configuration Helpers**
    - [ ] `ID("string")` -> Hashed ID
    - [ ] `Layout({ ... })` -> `Clay_LayoutConfig` cdata
    - [ ] `Rectangle({ color = ... })` -> Background color handling
- [ ] **Input Handling**
    - [ ] `Clay_SetPointerState` binding
    - [ ] `Clay_Hovered` binding

## Phase 6: Verification

- [ ] **Basic Tests**
    - [x] `test_layout.lua` (Simple row)
    - [x] `test_sizing.lua` (Fixed sizing)
- [ ] **Complex Tests** (Compare against C reference output)
    - [ ] Nested `GROW` containers
    - [ ] Text wrapping behavior
    - [ ] Scroll container offsets
    - [ ] Floating element positioning
