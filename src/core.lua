local ffi = require("ffi")
local bit = require("bit")
require("llay_ffi")

local M = {}

-- ==================================================================================
-- Constants & Enums
-- ==================================================================================

local LLAY__EPSILON = 0.01
local LLAY__MAXFLOAT = 3.402823466e+38

local Llay__SizingType = { FIT = 0, GROW = 1, PERCENT = 2, FIXED = 3 }
local Llay_LayoutDirection = { LEFT_TO_RIGHT = 0, TOP_TO_BOTTOM = 1 }
local Llay_AlignX = { LEFT = 0, CENTER = 1, RIGHT = 2 }
local Llay_AlignY = { TOP = 0, CENTER = 1, BOTTOM = 2 }
local Llay__ElementConfigType = {
	NONE = 0,
	BORDER = 1,
	FLOATING = 2,
	CLIP = 3,
	ASPECT = 4,
	IMAGE = 5,
	TEXT = 6,
	CUSTOM = 7,
	SHARED = 8,
}
local Llay_RenderCommandType = {
	NONE = 0,
	RECTANGLE = 1,
	BORDER = 2,
	TEXT = 3,
	IMAGE = 4,
	CUSTOM = 5,
	SCISSOR_START = 6,
	SCISSOR_END = 7,
}
local Llay_TextElementConfigWrapMode = { WORDS = 0, NEWLINES = 1, NONE = 2 }
local Llay_TextAlignment = { LEFT = 0, CENTER = 1, RIGHT = 2 }
local Llay_PointerDataInteractionState = { PRESSED_THIS_FRAME = 0, PRESSED = 1, RELEASED_THIS_FRAME = 2, RELEASED = 3 }
local Llay_PointerCaptureMode = { CAPTURE = 0, PASSTHROUGH = 1 }
local Llay_FloatingAttachToElement = { NONE = 0, PARENT = 1, ELEMENT_WITH_ID = 2, ROOT = 3 }

local LLAY__SPACECHAR_CHARS = ffi.new("char[2]", " \0")
local LLAY__SPACECHAR_SLICE = ffi.new("Clay_StringSlice", { length = 1, chars = LLAY__SPACECHAR_CHARS, baseChars = LLAY__SPACECHAR_CHARS })

-- ==================================================================================
-- GC Anchors (Prevents LuaJIT GC from reaping FFI memory)
-- ==================================================================================

local _ANCHORS = {
    arena_memory = nil,
    context = nil,
    callbacks = {}
}

-- ==================================================================================
-- Globals (Module State)
-- ==================================================================================

local context = nil
local measure_text_fn = nil
local query_scroll_offset_fn = nil
local next_element_id = 1
local DEBUG_MODE = os.getenv("LLAY_DEBUG") == "1"

local _CMD_TEMPLATE = ffi.new("Clay_RenderCommand")
local _openChildrenCounts = nil

-- ==================================================================================
-- Helpers: Math & Memory
-- ==================================================================================

local function LLAY__MAX(a, b)
	return a > b and a or b
end
local function LLAY__MIN(a, b)
	return a < b and a or b
end
local function Llay__FloatEqual(a, b)
	return math.abs(a - b) < LLAY__EPSILON
end

local function Llay__MemCmp(p1, p2, length)
	local s1 = ffi.cast("char*", p1)
	local s2 = ffi.cast("char*", p2)
	for i = 0, length - 1 do
		if s1[i] ~= s2[i] then
			return false
		end
	end
	return true
end

local function Llay__Array_Allocate_Arena(capacity, item_size, arena)
	local total_size = capacity * item_size
	-- Safe 64-byte alignment using 64-bit aware arithmetic
	local current_ptr = tonumber(arena.nextAllocation)
	local padding = (64 - (current_ptr % 64)) % 64
	local aligned_ptr = current_ptr + padding
	
	local next_alloc = aligned_ptr + total_size
	if next_alloc > tonumber(arena.capacity) then
		error("Clay Arena capacity exceeded: Requested " .. total_size .. " bytes. Allocated: " .. next_alloc .. " of " .. tonumber(arena.capacity))
	end
	arena.nextAllocation = next_alloc
	local result = arena.memory + aligned_ptr

	return ffi.cast("void*", result)
end

-- NEW HELPER: Allocate strings in arena to prevent GC corruption
local function Llay__AllocateStringInArena(str)
	if not str then return nil, 0 end
	local len = #str
	local ptr = ffi.cast("char*", Llay__Array_Allocate_Arena(len + 1, 1, context.internalArena))
	ffi.copy(ptr, str, len)
	ptr[len] = 0
	return ptr, len
end

-- ==================================================================================
-- Inspector Module (Runtime Diagnostics)
-- ==================================================================================

local Inspector = {}

function Inspector.check_arena_health()
	if context == nil then
		print("[LLAY INSPECTOR] Context not initialized")
		return
	end
	
	local next_alloc = tonumber(context.internalArena.nextAllocation)
	local cap = tonumber(context.internalArena.capacity)
	local usage_pct = (next_alloc / cap) * 100
	
	print(string.format("[LLAY INSPECTOR] Arena: %d/%d bytes (%.2f%% used)", next_alloc, cap, usage_pct))
	
	if usage_pct > 95 then
		print("[LLAY WARNING] Arena nearly full! Segfault imminent.")
	elseif usage_pct > 80 then
		print("[LLAY INFO] Arena usage high.")
	end
end

function Inspector.validate_pointer(ptr, label)
	if context == nil then
		print("[LLAY INSPECTOR] Context not initialized")
		return
	end
	
	local p_addr = ffi.cast("uintptr_t", ptr)
	local start_addr = ffi.cast("uintptr_t", context.internalArena.memory)
	local end_addr = start_addr + context.internalArena.capacity
	
	local p_num = tonumber(p_addr)
	local start_num = tonumber(start_addr)
	local end_num = tonumber(end_addr)
	
	if p_num < start_num or p_num >= end_num then
		error(string.format("[LLAY CRITICAL] Pointer escape! %s (%p) outside arena [%p - %p]", 
			label or "Unknown", ptr, start_addr, end_addr))
	end
end

function Inspector.trace_stack()
	if context == nil then
		print("[LLAY INSPECTOR] Context not initialized")
		return
	end
	
	local depth = context.openLayoutElementStack.length
	print(string.format("[LLAY INSPECTOR] Stack depth: %d", depth))
	
	if depth > 100 then
		print("[LLAY WARNING] Deep nesting or unbalanced Open/Close detected!")
	end
end

M.Inspector = Inspector

-- Debug helper - get layout element by index
function M._debug_get_element(idx)
	if context.layoutElements.internalArray == nil then
		return nil
	end
	return context.layoutElements.internalArray + idx
end

-- Debug helper - print element structure
function M._debug_print_element(idx, indent)
	indent = indent or 0
	local elem = M._debug_get_element(idx)
	if elem == nil then
		print(string.rep("  ", indent) .. "Element " .. idx .. ": nil")
		return
	end
	
	local indent_str = string.rep("  ", indent)
	print(indent_str .. "Element " .. idx .. ":")
	print(indent_str .. "  children: " .. elem.childrenOrTextContent.children.length)
	for i = 0, elem.childrenOrTextContent.children.length - 1 do
		local childIdx = elem.childrenOrTextContent.children.elements[i]
		print(indent_str .. "    child[" .. i .. "] = " .. childIdx)
		M._debug_print_element(childIdx, indent + 1)
	end
end

local function Llay__GetHashMapItem(id)
	if context.layoutElementsHashMap.internalArray == nil then
		return nil
	end
	local hashBucket = id % context.layoutElementsHashMap.capacity
	local elementIndex = context.layoutElementsHashMap.internalArray[hashBucket]
	while elementIndex ~= -1 do
		local hashEntry = context.layoutElementsHashMapInternal.internalArray + elementIndex
		if hashEntry.elementId.id == id then
			return hashEntry
		end
		elementIndex = hashEntry.nextIndex
	end
	return nil
end

local function Llay__ElementIsOffscreen(boundingBox)
	if context.disableCulling then
		return false
	end
	return (boundingBox.x > context.layoutDimensions.width)
		or (boundingBox.y > context.layoutDimensions.height)
		or (boundingBox.x + boundingBox.width < 0)
		or (boundingBox.y + boundingBox.height < 0)
end

-- ==================================================================================
-- Array Operations
-- ==================================================================================

local function array_add(array, item)
	if array.length >= array.capacity then
		error("Array capacity exceeded")
	end
	if item == nil then
		local ptr = array.internalArray + array.length
		ffi.copy(ptr, _CMD_TEMPLATE, ffi.sizeof("Clay_RenderCommand"))
		array.length = array.length + 1
		return ptr
	else
		array.internalArray[array.length] = item
		array.length = array.length + 1
		return array.internalArray + (array.length - 1)
	end
end

local function int32_array_add(array, value)
	if array.length >= array.capacity then
		error("Int32 Array capacity exceeded")
	end
	array.internalArray[array.length] = value
	array.length = array.length + 1
end

local function int32_array_get(array, index)
	return array.internalArray[index]
end

local function int32_array_set(array, index, value)
	if index < array.capacity then
		array.internalArray[index] = value
		if index >= array.length then
			array.length = index + 1
		end
	end
end

local function int32_array_remove_swapback(array, index)
	if index < 0 or index >= array.length then
		return 0
	end
	array.length = array.length - 1
	local removed = array.internalArray[index]
	array.internalArray[index] = array.internalArray[array.length]
	return removed
end

local function element_id_array_add(array, item)
	if array.length >= array.capacity then
		return
	end
	array.internalArray[array.length] = item
	array.length = array.length + 1
end

local function element_id_array_get(array, index)
	return array.internalArray + index
end

local function Llay__AddHashMapItem(elementId, layoutElement)
	if context.layoutElementsHashMapInternal.length >= context.layoutElementsHashMapInternal.capacity - 1 then
		return nil
	end

	local hashBucket = elementId.id % context.layoutElementsHashMap.capacity
	local hashItemIndex = context.layoutElementsHashMap.internalArray[hashBucket]
	local previousIndex = -1

	while hashItemIndex ~= -1 do
		local hashItem = context.layoutElementsHashMapInternal.internalArray + hashItemIndex
		if hashItem.elementId.id == elementId.id then
			-- COLLISION CHECK: If we already touched this item in the current frame, it's a duplicate ID error.
			if hashItem.generation == context.generation + 1 then
				if DEBUG_MODE then
					print("[LLAY WARNING] Duplicate ID collision in same frame: " .. elementId.id)
				end
			end

			hashItem.generation = context.generation + 1
			hashItem.layoutElement = layoutElement
			hashItem.debugData.collision = false
			return hashItem
		end
		previousIndex = hashItemIndex
		hashItemIndex = hashItem.nextIndex
	end

	local itemIndex = context.layoutElementsHashMapInternal.length
	context.layoutElementsHashMapInternal.length = context.layoutElementsHashMapInternal.length + 1
	local item = context.layoutElementsHashMapInternal.internalArray + itemIndex

	local elementIdStruct = ffi.new("Clay_ElementId")
	elementIdStruct.id = elementId.id
	elementIdStruct.offset = elementId.offset
	elementIdStruct.baseId = elementId.baseId
	elementIdStruct.stringId.length = elementId.stringId.length
	local charsValue = elementId.stringId.chars
	if type(charsValue) == "table" then
		charsValue = charsValue.chars or charsValue[1] or ""
	end
	elementIdStruct.stringId.chars = charsValue
	elementIdStruct.stringId.isStaticallyAllocated = false

	item.elementId = elementIdStruct
	item.layoutElement = layoutElement
	item.nextIndex = -1
	item.generation = context.generation + 1

	item.debugData = array_add(context.debugElementData, ffi.new("Clay__DebugElementData"))

	if previousIndex ~= -1 then
		context.layoutElementsHashMapInternal.internalArray[previousIndex].nextIndex = itemIndex
	else
		context.layoutElementsHashMap.internalArray[hashBucket] = itemIndex
	end

	return item
end

-- ==================================================================================
-- Hashing
-- ==================================================================================

local function Llay__HashString(str, seed)
	local hash = seed or 0
	local len = str and #str or 0
	for i = 1, len do
		local c = string.byte(str, i)
		hash = hash + c
		hash = (hash + bit.lshift(hash, 10)) % 4294967296
		hash = bit.bxor(hash, bit.rshift(hash, 6))
	end
	hash = (hash + bit.lshift(hash, 3)) % 4294967296
	hash = bit.bxor(hash, bit.rshift(hash, 11))
	hash = (hash + bit.lshift(hash, 15)) % 4294967296
	return { id = hash + 1, offset = 0, baseId = seed or 0, stringId = { length = len, chars = str } }
end

local function Llay__HashNumber(offset, seed)
	local hash = seed
	hash = hash + (offset + 48)
	hash = (hash + bit.lshift(hash, 10)) % 4294967296
	hash = bit.bxor(hash, bit.rshift(hash, 6))
	hash = (hash + bit.lshift(hash, 3)) % 4294967296
	hash = bit.bxor(hash, bit.rshift(hash, 11))
	hash = (hash + bit.lshift(hash, 15)) % 4294967296
	return { id = hash + 1, offset = offset, baseId = seed, stringId = { length = 0, chars = nil } }
end

-- Accurate implementation of Clay's HashStringWithOffset
local function Llay__HashStringWithOffset(str, offset, seed)
	local hash = 0
	local base = seed or 0
	local len = #str

	for i = 1, len do
		local c = string.byte(str, i)
		base = base + c
		base = (base + bit.lshift(base, 10)) % 4294967296
		base = bit.bxor(base, bit.rshift(base, 6))
	end
	
	hash = base
	hash = hash + offset
	hash = (hash + bit.lshift(hash, 10)) % 4294967296
	hash = bit.bxor(hash, bit.rshift(hash, 6))

	hash = (hash + bit.lshift(hash, 3)) % 4294967296
	base = (base + bit.lshift(base, 3)) % 4294967296
	
	hash = bit.bxor(hash, bit.rshift(hash, 11))
	base = bit.bxor(base, bit.rshift(base, 11))
	
	hash = (hash + bit.lshift(hash, 15)) % 4294967296
	base = (base + bit.lshift(base, 15)) % 4294967296
	
	return { 
		id = hash + 1, 
		offset = offset, 
		baseId = base + 1, 
		stringId = { length = len, chars = str } 
	}
end

-- ==================================================================================
-- Context & Initialization
-- ==================================================================================

local function Llay__InitializeEphemeralMemory(ctx)
	local max = ctx.maxElementCount
	local arena = ctx.internalArena

	-- Reset Arena
	arena.nextAllocation = ffi.cast("uintptr_t", ctx.arenaResetOffset)

	-- Reset command template to clean state
	ffi.fill(_CMD_TEMPLATE, ffi.sizeof("Clay_RenderCommand"))

	-- Initialize open children counts tracker
	_openChildrenCounts = ffi.new("uint16_t[?]", max)
	for i = 0, max - 1 do _openChildrenCounts[i] = 0 end

	ctx.layoutElementChildrenBuffer =
		{ capacity = max, length = 0, internalArray = ffi.cast("int32_t*", Llay__Array_Allocate_Arena(max, 4, arena)) }
	ctx.layoutElements = {
		capacity = max,
		length = 0,
		internalArray = ffi.cast(
			"Clay_LayoutElement*",
			Llay__Array_Allocate_Arena(max, ffi.sizeof("Clay_LayoutElement"), arena)
		),
	}
	ctx.renderCommands = {
		capacity = max,
		length = 0,
		internalArray = ffi.cast(
			"Clay_RenderCommand*",
			Llay__Array_Allocate_Arena(max, ffi.sizeof("Clay_RenderCommand"), arena)
		),
	}

	ctx.layoutConfigs = {
		capacity = max,
		length = 0,
		internalArray = ffi.cast(
			"Clay_LayoutConfig*",
			Llay__Array_Allocate_Arena(max, ffi.sizeof("Clay_LayoutConfig"), arena)
		),
	}

	-- Reserve index 0 as the default layout config.
	-- Many code paths (e.g. text elements) assume `layoutConfigs.internalArray` points
	-- at a sane FIT-sized config, not the root container's fixed-size config.
	array_add(ctx.layoutConfigs, ffi.new("Clay_LayoutConfig"))

	ctx.elementConfigs = {
		capacity = max,
		length = 0,
		internalArray = ffi.cast(
			"Clay_ElementConfig*",
			Llay__Array_Allocate_Arena(max, ffi.sizeof("Clay_ElementConfig"), arena)
		),
	}
	ctx.textElementConfigs = {
		capacity = max,
		length = 0,
		internalArray = ffi.cast(
			"Clay_TextElementConfig*",
			Llay__Array_Allocate_Arena(max, ffi.sizeof("Clay_TextElementConfig"), arena)
		),
	}
	ctx.sharedElementConfigs = {
		capacity = max,
		length = 0,
		internalArray = ffi.cast(
			"Clay_SharedElementConfig*",
			Llay__Array_Allocate_Arena(max, ffi.sizeof("Clay_SharedElementConfig"), arena)
		),
	}
	ctx.aspectRatioElementConfigs = {
		capacity = max,
		length = 0,
		internalArray = ffi.cast(
			"Clay_AspectRatioElementConfig*",
			Llay__Array_Allocate_Arena(max, ffi.sizeof("Clay_AspectRatioElementConfig"), arena)
		),
	}
	ctx.imageElementConfigs = {
		capacity = max,
		length = 0,
		internalArray = ffi.cast(
			"Clay_ImageElementConfig*",
			Llay__Array_Allocate_Arena(max, ffi.sizeof("Clay_ImageElementConfig"), arena)
		),
	}
	ctx.floatingElementConfigs = {
		capacity = max,
		length = 0,
		internalArray = ffi.cast(
			"Clay_FloatingElementConfig*",
			Llay__Array_Allocate_Arena(max, ffi.sizeof("Clay_FloatingElementConfig"), arena)
		),
	}
	ctx.clipElementConfigs = {
		capacity = max,
		length = 0,
		internalArray = ffi.cast(
			"Clay_ClipElementConfig*",
			Llay__Array_Allocate_Arena(max, ffi.sizeof("Clay_ClipElementConfig"), arena)
		),
	}
	ctx.customElementConfigs = {
		capacity = max,
		length = 0,
		internalArray = ffi.cast(
			"Clay_CustomElementConfig*",
			Llay__Array_Allocate_Arena(max, ffi.sizeof("Clay_CustomElementConfig"), arena)
		),
	}
	ctx.borderElementConfigs = {
		capacity = max,
		length = 0,
		internalArray = ffi.cast(
			"Clay_BorderElementConfig*",
			Llay__Array_Allocate_Arena(max, ffi.sizeof("Clay_BorderElementConfig"), arena)
		),
	}
	ctx.warnings = {
		capacity = 100,
		length = 0,
		internalArray = ffi.cast("Clay__Warning*", Llay__Array_Allocate_Arena(100, ffi.sizeof("Clay__Warning"), arena)),
	}
	ctx.dynamicStringData = {
		capacity = max,
		length = 0,
		internalArray = ffi.cast("char*", Llay__Array_Allocate_Arena(max, 1, arena)),
	}

	ctx.layoutElementIdStrings = {
		capacity = max,
		length = 0,
		internalArray = ffi.cast("Clay_String*", Llay__Array_Allocate_Arena(max, ffi.sizeof("Clay_String"), arena)),
	}
	ctx.wrappedTextLines = {
		capacity = max,
		length = 0,
		internalArray = ffi.cast(
			"Clay__WrappedTextLine*",
			Llay__Array_Allocate_Arena(max, ffi.sizeof("Clay__WrappedTextLine"), arena)
		),
	}
	ctx.layoutElementTreeNodeArray1 = {
		capacity = max,
		length = 0,
		internalArray = ffi.cast(
			"Clay__LayoutElementTreeNode*",
			Llay__Array_Allocate_Arena(max, ffi.sizeof("Clay__LayoutElementTreeNode"), arena)
		),
	}
	ctx.layoutElementTreeRoots = {
		capacity = max,
		length = 0,
		internalArray = ffi.cast(
			"Clay__LayoutElementTreeRoot*",
			Llay__Array_Allocate_Arena(max, ffi.sizeof("Clay__LayoutElementTreeRoot"), arena)
		),
	}
	ctx.layoutElementChildren =
		{ capacity = max, length = 0, internalArray = ffi.cast("int32_t*", Llay__Array_Allocate_Arena(max, 4, arena)) }
	ctx.openLayoutElementStack =
		{ capacity = max, length = 0, internalArray = ffi.cast("int32_t*", Llay__Array_Allocate_Arena(max, 4, arena)) }
	ctx.textElementData = {
		capacity = max,
		length = 0,
		internalArray = ffi.cast(
			"Clay__TextElementData*",
			Llay__Array_Allocate_Arena(max, ffi.sizeof("Clay__TextElementData"), arena)
		),
	}
	ctx.aspectRatioElementIndexes =
		{ capacity = max, length = 0, internalArray = ffi.cast("int32_t*", Llay__Array_Allocate_Arena(max, 4, arena)) }
	ctx.treeNodeVisited =
		{ capacity = max, length = 0, internalArray = ffi.cast("bool*", Llay__Array_Allocate_Arena(max, 1, arena)) }
	ctx.openClipElementStack =
		{ capacity = max, length = 0, internalArray = ffi.cast("int32_t*", Llay__Array_Allocate_Arena(max, 4, arena)) }
	ctx.reusableElementIndexBuffer =
		{ capacity = max, length = 0, internalArray = ffi.cast("int32_t*", Llay__Array_Allocate_Arena(max, 4, arena)) }
	ctx.layoutElementClipElementIds =
		{ capacity = max, length = 0, internalArray = ffi.cast("int32_t*", Llay__Array_Allocate_Arena(max, 4, arena)) }
end

local function Llay__InitializePersistentMemory(ctx)
	local max = ctx.maxElementCount
	local maxMeasure = ctx.maxMeasureTextCacheWordCount
	local arena = ctx.internalArena

	ctx.scrollContainerDatas = {
		capacity = 100,
		length = 0,
		internalArray = ffi.cast(
			"Clay__ScrollContainerDataInternal*",
			Llay__Array_Allocate_Arena(100, ffi.sizeof("Clay__ScrollContainerDataInternal"), arena)
		),
	}
	ctx.layoutElementsHashMapInternal = {
		capacity = max,
		length = 0,
		internalArray = ffi.cast(
			"Clay_LayoutElementHashMapItem*",
			Llay__Array_Allocate_Arena(max, ffi.sizeof("Clay_LayoutElementHashMapItem"), arena)
		),
	}
	ctx.layoutElementsHashMap =
		{ capacity = max, length = 0, internalArray = ffi.cast("int32_t*", Llay__Array_Allocate_Arena(max, 4, arena)) }
	ctx.measureTextHashMapInternal = {
		capacity = max,
		length = 0,
		internalArray = ffi.cast(
			"Clay__MeasureTextCacheItem*",
			Llay__Array_Allocate_Arena(max, ffi.sizeof("Clay__MeasureTextCacheItem"), arena)
		),
	}
	ctx.measureTextHashMapInternalFreeList =
		{ capacity = max, length = 0, internalArray = ffi.cast("int32_t*", Llay__Array_Allocate_Arena(max, 4, arena)) }
	ctx.measuredWordsFreeList = {
		capacity = maxMeasure,
		length = 0,
		internalArray = ffi.cast("int32_t*", Llay__Array_Allocate_Arena(maxMeasure, 4, arena)),
	}
	ctx.measureTextHashMap =
		{ capacity = max, length = 0, internalArray = ffi.cast("int32_t*", Llay__Array_Allocate_Arena(max, 4, arena)) }
	ctx.measuredWords = {
		capacity = maxMeasure,
		length = 0,
		internalArray = ffi.cast(
			"Clay__MeasuredWord*",
			Llay__Array_Allocate_Arena(maxMeasure, ffi.sizeof("Clay__MeasuredWord"), arena)
		),
	}
	ctx.pointerOverIds = {
		capacity = max,
		length = 0,
		internalArray = ffi.cast(
			"Clay_ElementId*",
			Llay__Array_Allocate_Arena(max, ffi.sizeof("Clay_ElementId"), arena)
		),
	}
	ctx.debugElementData = {
		capacity = max,
		length = 0,
		internalArray = ffi.cast(
			"Clay__DebugElementData*",
			Llay__Array_Allocate_Arena(max, ffi.sizeof("Clay__DebugElementData"), arena)
		),
	}

	ctx.arenaResetOffset = tonumber(arena.nextAllocation)
end

-- ==================================================================================
-- Element Configuration
-- ==================================================================================

local function Llay__StoreLayoutConfig(config)
	if context.booleanWarnings.maxElementsExceeded then
		return nil
	end
	return array_add(context.layoutConfigs, config)
end

local function Llay__StoreTextElementConfig(config)
	if context.booleanWarnings.maxElementsExceeded then
		return nil
	end
	return array_add(context.textElementConfigs, config)
end

local function Llay__StoreSharedElementConfig(config)
	if context.booleanWarnings.maxElementsExceeded then
		return nil
	end
	return array_add(context.sharedElementConfigs, config)
end

local function Llay__StoreAspectRatioElementConfig(config)
	if context.booleanWarnings.maxElementsExceeded then
		return nil
	end
	return array_add(context.aspectRatioElementConfigs, config)
end

local function Llay__StoreImageElementConfig(config)
	if context.booleanWarnings.maxElementsExceeded then
		return nil
	end
	return array_add(context.imageElementConfigs, config)
end

local function Llay__StoreCustomElementConfig(config)
	if context.booleanWarnings.maxElementsExceeded then
		return nil
	end
	return array_add(context.customElementConfigs, config)
end

local function Llay__StoreFloatingElementConfig(config)
	if context.booleanWarnings.maxElementsExceeded then
		return nil
	end
	return array_add(context.floatingElementConfigs, config)
end

local function Llay__StoreBorderElementConfig(config)
	if context.booleanWarnings.maxElementsExceeded then
		return nil
	end
	return array_add(context.borderElementConfigs, config)
end

local function Llay__StoreClipElementConfig(config)
	if context.booleanWarnings.maxElementsExceeded then
		return nil
	end
	return array_add(context.clipElementConfigs, config)
end

local function Llay__ElementHasConfig(element, configType)
	for i = 0, element.elementConfigs.length - 1 do
		if element.elementConfigs.internalArray[i].type == configType then
			return true
		end
	end
	return false
end

local function Llay__FindElementConfigWithType(element, configType)
	for i = 0, element.elementConfigs.length - 1 do
		if element.elementConfigs.internalArray[i].type == configType then
			return element.elementConfigs.internalArray[i].config
		end
	end
	return nil
end

local function Llay__GetOpenLayoutElement()
	if context.openLayoutElementStack.length == 0 then
		return nil
	end
	local idx = context.openLayoutElementStack.internalArray[context.openLayoutElementStack.length - 1]
	return context.layoutElements.internalArray + idx
end

local function Llay__UpdateAspectRatioBox(element)
	local configUnion = Llay__FindElementConfigWithType(element, Llay__ElementConfigType.ASPECT)
	if configUnion ~= nil then
		local aspectConfig = configUnion.aspectRatioElementConfig
		if aspectConfig.aspectRatio ~= 0 then
			if element.dimensions.width == 0 and element.dimensions.height ~= 0 then
				element.dimensions.width = element.dimensions.height * aspectConfig.aspectRatio
			elseif element.dimensions.width ~= 0 and element.dimensions.height == 0 then
				element.dimensions.height = element.dimensions.width * (1 / aspectConfig.aspectRatio)
			end
		end
	end
end

local function Llay__AttachElementConfig(configUnion, typeVal)
	if context.booleanWarnings.maxElementsExceeded then
		return
	end
	local openElement = Llay__GetOpenLayoutElement()
	if openElement == nil then
		return
	end

	if openElement.elementConfigs.length == 0 then
		openElement.elementConfigs.internalArray = context.elementConfigs.internalArray + context.elementConfigs.length
	end

	openElement.elementConfigs.length = openElement.elementConfigs.length + 1
	local elemConfig = array_add(context.elementConfigs, ffi.new("Clay_ElementConfig"))
	elemConfig.type = typeVal
	elemConfig.config = configUnion
end

local function Llay__ConfigureOpenElement(declaration)
	local openLayoutElement = Llay__GetOpenLayoutElement()
	if openLayoutElement == nil then
		return
	end

	openLayoutElement.layoutConfig = Llay__StoreLayoutConfig(declaration.layout)

	local sharedConfig = nil
	if declaration.backgroundColor.a > 0 then
		sharedConfig = Llay__StoreSharedElementConfig({
			backgroundColor = declaration.backgroundColor,
			cornerRadius = declaration.cornerRadius,
			userData = declaration.userData,
		})
		Llay__AttachElementConfig({ sharedElementConfig = sharedConfig }, Llay__ElementConfigType.SHARED)
	elseif declaration.cornerRadius.topLeft > 0 or declaration.userData ~= nil then
		sharedConfig = Llay__StoreSharedElementConfig({
			backgroundColor = declaration.backgroundColor,
			cornerRadius = declaration.cornerRadius,
			userData = declaration.userData,
		})
		Llay__AttachElementConfig({ sharedElementConfig = sharedConfig }, Llay__ElementConfigType.SHARED)
	end

	if declaration.image.imageData ~= nil then
		local imageConfig = Llay__StoreImageElementConfig(declaration.image)
		Llay__AttachElementConfig({ imageElementConfig = imageConfig }, Llay__ElementConfigType.IMAGE)
	end

	if declaration.floating.attachTo ~= 0 then
		local floatingConfig = declaration.floating
		local parentIdx = context.openLayoutElementStack.internalArray[context.openLayoutElementStack.length - 2]
		local hierarchicalParent = context.layoutElements.internalArray + parentIdx

		local clipElementId = 0
		if floatingConfig.attachTo == 1 then
			floatingConfig.parentId = hierarchicalParent.id
			if context.openClipElementStack.length > 0 then
				clipElementId = int32_array_get(context.openClipElementStack, context.openClipElementStack.length - 1)
			end
		elseif floatingConfig.attachTo == 2 then
			local parentItem = Llay__GetHashMapItem(floatingConfig.parentId)
			if parentItem then
			end
		elseif floatingConfig.attachTo == 3 then
		end

		local currentElemIdx = context.openLayoutElementStack.internalArray[context.openLayoutElementStack.length - 1]

		local root = array_add(context.layoutElementTreeRoots, ffi.new("Clay__LayoutElementTreeRoot"))
		root.layoutElementIndex = currentElemIdx
		root.parentId = floatingConfig.parentId
		root.clipElementId = clipElementId
		root.zIndex = floatingConfig.zIndex
		
		int32_array_add(context.openClipElementStack, openLayoutElement.id)

		Llay__AttachElementConfig(
			{ floatingElementConfig = Llay__StoreFloatingElementConfig(floatingConfig) },
			Llay__ElementConfigType.FLOATING
		)
	end

	if declaration.custom.customData ~= nil then
		local customConfig = Llay__StoreCustomElementConfig(declaration.custom)
		Llay__AttachElementConfig({ customElementConfig = customConfig }, Llay__ElementConfigType.CUSTOM)
	end

	if declaration.clip.horizontal or declaration.clip.vertical then
		local clipConfig = Llay__StoreClipElementConfig(declaration.clip)
		Llay__AttachElementConfig({ clipElementConfig = clipConfig }, Llay__ElementConfigType.CLIP)

		int32_array_add(context.openClipElementStack, openLayoutElement.id)

		local found = false
		for i = 0, context.scrollContainerDatas.length - 1 do
			if context.scrollContainerDatas.internalArray[i].elementId == openLayoutElement.id then
				context.scrollContainerDatas.internalArray[i].layoutElement = openLayoutElement
				context.scrollContainerDatas.internalArray[i].openThisFrame = true
				found = true
			end
		end
		if not found then
			local scrollData = array_add(context.scrollContainerDatas, ffi.new("Clay__ScrollContainerDataInternal"))
			scrollData.layoutElement = openLayoutElement
			scrollData.elementId = openLayoutElement.id
			scrollData.openThisFrame = true
			scrollData.scrollOrigin = { x = -1, y = -1 }
		end
	end

	if
		declaration.border.width.left > 0
		or declaration.border.width.right > 0
		or declaration.border.width.top > 0
		or declaration.border.width.bottom > 0
		or declaration.border.width.betweenChildren > 0
	then
		local borderConfig = Llay__StoreBorderElementConfig(declaration.border)
		Llay__AttachElementConfig({ borderElementConfig = borderConfig }, Llay__ElementConfigType.BORDER)
	end

	if declaration.aspectRatio.aspectRatio > 0 then
		local aspectConfig = Llay__StoreAspectRatioElementConfig(declaration.aspectRatio)
		Llay__AttachElementConfig({ aspectRatioElementConfig = aspectConfig }, Llay__ElementConfigType.ASPECT)
		int32_array_add(context.aspectRatioElementIndexes, context.layoutElements.length - 1)
	end
end

-- ==================================================================================
-- Text Measurement & Caching
-- ==================================================================================

local function Llay__HashStringContentsWithConfig(text, config)
	local hash = 0
	local offset = 0
	-- Hash Text Chars
	for i = 0, text.length - 1 do
		local c = text.chars[i]  -- Direct access to char pointer
		hash = hash + c
		hash = hash + bit.lshift(hash, 10)
		hash = bit.bxor(hash, bit.rshift(hash, 6))
	end
	-- Hash Config
	hash = hash + config.fontId
	hash = hash + bit.lshift(hash, 10)
	hash = bit.bxor(hash, bit.rshift(hash, 6))

	hash = hash + config.fontSize
	hash = hash + bit.lshift(hash, 10)
	hash = bit.bxor(hash, bit.rshift(hash, 6))

	hash = hash + config.letterSpacing
	hash = hash + bit.lshift(hash, 10)
	hash = bit.bxor(hash, bit.rshift(hash, 6))

	hash = hash + bit.lshift(hash, 3)
	hash = bit.bxor(hash, bit.rshift(hash, 11))
	hash = hash + bit.lshift(hash, 15)
	return hash + 1
end

local function Llay__AddMeasuredWord(word, previousWord)
	if context.measuredWordsFreeList.length > 0 then
		local newItemIndex =
			int32_array_remove_swapback(context.measuredWordsFreeList, context.measuredWordsFreeList.length - 1)
		context.measuredWords.internalArray[newItemIndex] = word
		previousWord.next = newItemIndex
		return context.measuredWords.internalArray + newItemIndex
	else
		previousWord.next = context.measuredWords.length
		return array_add(context.measuredWords, word)
	end
end

local function Llay__MeasureTextCached(text, config)
	if not measure_text_fn then
		return nil
	end

	local id = Llay__HashStringContentsWithConfig(text, config)
	local hashBucket = id % (context.maxMeasureTextCacheWordCount / 32)
	local elementIndexPrevious = 0
	local elementIndex = context.measureTextHashMap.internalArray[hashBucket]

	-- Check Cache with Eviction Logic
	while elementIndex ~= 0 do
		local hashEntry = context.measureTextHashMapInternal.internalArray + elementIndex
		if hashEntry.id == id then
			hashEntry.generation = context.generation
			return hashEntry
		end

		-- Eviction Logic: If item is old, free its words and remove from map
		if context.generation - hashEntry.generation > 2 then
			local nextWordIdx = hashEntry.measuredWordsStartIndex
			while nextWordIdx ~= -1 do
				local word = context.measuredWords.internalArray + nextWordIdx
				int32_array_add(context.measuredWordsFreeList, nextWordIdx)
				nextWordIdx = word.next
			end

			local nextIdx = hashEntry.nextIndex
			hashEntry.measuredWordsStartIndex = -1
			int32_array_add(context.measureTextHashMapInternalFreeList, elementIndex)
			
			if elementIndexPrevious == 0 then
				context.measureTextHashMap.internalArray[hashBucket] = nextIdx
			else
				context.measureTextHashMapInternal.internalArray[elementIndexPrevious].nextIndex = nextIdx
			end
			elementIndex = nextIdx
		else
			elementIndexPrevious = elementIndex
			elementIndex = hashEntry.nextIndex
		end
	end

	-- Create New Cache Item
	local newItemIndex = 0
	if context.measureTextHashMapInternalFreeList.length > 0 then
		newItemIndex = int32_array_remove_swapback(
			context.measureTextHashMapInternalFreeList,
			context.measureTextHashMapInternalFreeList.length - 1
		)
	else
		newItemIndex = context.measureTextHashMapInternal.length
		context.measureTextHashMapInternal.length = context.measureTextHashMapInternal.length + 1
	end

	local measured = context.measureTextHashMapInternal.internalArray + newItemIndex
	measured.measuredWordsStartIndex = -1
	measured.id = id
	measured.generation = context.generation
	measured.nextIndex = context.measureTextHashMap.internalArray[hashBucket]
	context.measureTextHashMap.internalArray[hashBucket] = newItemIndex

	-- Measure Logic
	local start = 0
	local current = 0
	local lineWidth = 0
	local measuredWidth = 0
	local measuredHeight = 0
	local spaceWidth =
		measure_text_fn(ffi.string(LLAY__SPACECHAR_CHARS), config, context.measureTextUserData).width

	local tempWord = ffi.new("Clay__MeasuredWord", { next = -1 })
	local previousWord = tempWord

	while current < text.length do
		local char = text.chars[current]
		if char == 32 or char == 10 then -- space or newline
			local len = current - start
			local dims = { width = 0, height = 0 }
			if len > 0 then
				dims = measure_text_fn(ffi.string(text.chars + start, len), config, context.measureTextUserData)
			end

			measured.minWidth = LLAY__MAX(dims.width, measured.minWidth)
			measuredHeight = LLAY__MAX(measuredHeight, dims.height)

			if char == 32 then
				dims.width = dims.width + spaceWidth
				previousWord = Llay__AddMeasuredWord(
					{ startOffset = start, length = len + 1, width = dims.width, next = -1 },
					previousWord
				)
				lineWidth = lineWidth + dims.width
			end

			if char == 10 then
				if len > 0 then
					previousWord = Llay__AddMeasuredWord(
						{ startOffset = start, length = len, width = dims.width, next = -1 },
						previousWord
					)
				end
				previousWord =
					Llay__AddMeasuredWord({ startOffset = current + 1, length = 0, width = 0, next = -1 }, previousWord)
				lineWidth = lineWidth + dims.width
				measuredWidth = LLAY__MAX(lineWidth, measuredWidth)
				measured.containsNewlines = true
				lineWidth = 0
			end
			start = current + 1
		end
		current = current + 1
	end

	if current - start > 0 then
		local dims = measure_text_fn(ffi.string(text.chars + start, current - start), config, context.measureTextUserData)
		Llay__AddMeasuredWord(
			{ startOffset = start, length = current - start, width = dims.width, next = -1 },
			previousWord
		)
		lineWidth = lineWidth + dims.width
		measuredHeight = LLAY__MAX(measuredHeight, dims.height)
		measured.minWidth = LLAY__MAX(dims.width, measured.minWidth)
	end

	measuredWidth = LLAY__MAX(lineWidth, measuredWidth) - config.letterSpacing
	measured.measuredWordsStartIndex = tempWord.next
	measured.unwrappedDimensions.width = measuredWidth
	measured.unwrappedDimensions.height = measuredHeight

	return measured
end

-- ==================================================================================
-- Sizing Algorithm
-- ==================================================================================

	local function Llay__SizeContainersAlongAxis(xAxis)
	local bfsBuffer = context.layoutElementChildrenBuffer
	local resizableContainerBuffer = context.openLayoutElementStack -- Reuse buffer as scratch

	for rootIndex = 0, context.layoutElementTreeRoots.length - 1 do
		bfsBuffer.length = 0
		local root = context.layoutElementTreeRoots.internalArray[rootIndex]
		local rootElement = context.layoutElements.internalArray + root.layoutElementIndex
		int32_array_add(bfsBuffer, root.layoutElementIndex)
		
		if DEBUG_MODE then
			print("[SIZE] Processing root " .. rootIndex .. " (element " .. root.layoutElementIndex .. ")")
			print("[SIZE] Root has " .. rootElement.childrenOrTextContent.children.length .. " children")
			for ci = 0, rootElement.childrenOrTextContent.children.length - 1 do
				local childIdx = rootElement.childrenOrTextContent.children.elements[ci]
				print("[SIZE]   Child " .. ci .. " is element index " .. childIdx)
			end
		end

		-- Size floating containers to parent
		if Llay__ElementHasConfig(rootElement, Llay__ElementConfigType.FLOATING) then
			local floatingConfig =
				Llay__FindElementConfigWithType(rootElement, Llay__ElementConfigType.FLOATING).floatingElementConfig
			local parentItem = Llay__GetHashMapItem(floatingConfig.parentId)
			if parentItem ~= nil then
				local parentElement = parentItem.layoutElement
				if rootElement.layoutConfig.sizing.width.type == Llay__SizingType.GROW then
					rootElement.dimensions.width = parentElement.dimensions.width
				elseif rootElement.layoutConfig.sizing.width.type == Llay__SizingType.PERCENT then
					rootElement.dimensions.width = parentElement.dimensions.width
						* rootElement.layoutConfig.sizing.width.size.percent
				end
				if rootElement.layoutConfig.sizing.height.type == Llay__SizingType.GROW then
					rootElement.dimensions.height = parentElement.dimensions.height
				elseif rootElement.layoutConfig.sizing.height.type == Llay__SizingType.PERCENT then
					rootElement.dimensions.height = parentElement.dimensions.height
						* rootElement.layoutConfig.sizing.height.size.percent
				end
			end
		end

		-- Size root
		local rootSizing = xAxis and rootElement.layoutConfig.sizing.width or rootElement.layoutConfig.sizing.height
		if rootSizing.type ~= Llay__SizingType.PERCENT then
			local val = xAxis and rootElement.dimensions.width or rootElement.dimensions.height
			val = LLAY__MIN(LLAY__MAX(val, rootSizing.size.minMax.min), rootSizing.size.minMax.max)
			if xAxis then
				rootElement.dimensions.width = val
			else
				rootElement.dimensions.height = val
			end
		end

		local i = 0
		while i < bfsBuffer.length do
			local parentIndex = int32_array_get(bfsBuffer, i)
			local parent = context.layoutElements.internalArray + parentIndex
			local parentConfig = parent.layoutConfig
			
			if DEBUG_MODE then
				print("[BFS] Processing parent " .. parentIndex .. " (" .. bfsBuffer.length .. " in buffer)")
			end

			local growContainerCount = 0
			local parentSize = xAxis and parent.dimensions.width or parent.dimensions.height
			local parentPadding = xAxis and (parentConfig.padding.left + parentConfig.padding.right)
				or (parentConfig.padding.top + parentConfig.padding.bottom)
			local innerContentSize = 0
			local totalPaddingAndGap = parentPadding
			local sizingAlongAxis = (xAxis and parentConfig.layoutDirection == Llay_LayoutDirection.LEFT_TO_RIGHT)
				or (not xAxis and parentConfig.layoutDirection == Llay_LayoutDirection.TOP_TO_BOTTOM)
			local childGap = parentConfig.childGap

			resizableContainerBuffer.length = 0

			-- Pass 1: Identification & Content Calculation
			for j = 0, parent.childrenOrTextContent.children.length - 1 do
				local childIdx = parent.childrenOrTextContent.children.elements[j]
				local child = context.layoutElements.internalArray + childIdx
				local childSizing = xAxis and child.layoutConfig.sizing.width or child.layoutConfig.sizing.height
				local childSize = xAxis and child.dimensions.width or child.dimensions.height

				if childSizing.type == Llay__SizingType.FIXED then
					childSize = childSizing.size.minMax.min
					if xAxis then
						child.dimensions.width = childSize
					else
						child.dimensions.height = childSize
					end
				end

				if
					not Llay__ElementHasConfig(child, Llay__ElementConfigType.TEXT)
					and child.childrenOrTextContent.children.length > 0
				then
					if DEBUG_MODE then
						print("[BFS] Adding child " .. childIdx .. " (buffer size: " .. bfsBuffer.length .. "/" .. bfsBuffer.capacity .. ")")
					end
					int32_array_add(bfsBuffer, childIdx)
				end

				local isText = Llay__ElementHasConfig(child, Llay__ElementConfigType.TEXT)
				if
					childSizing.type ~= Llay__SizingType.PERCENT
					and childSizing.type ~= Llay__SizingType.FIXED
					and (
						not isText
						or (
							Llay__FindElementConfigWithType(child, Llay__ElementConfigType.TEXT).textElementConfig.wrapMode
							== Llay_TextElementConfigWrapMode.WORDS
						)
					)
				then
					int32_array_add(resizableContainerBuffer, childIdx)
				end

				if sizingAlongAxis then
					if childSizing.type ~= Llay__SizingType.PERCENT then
						innerContentSize = innerContentSize + childSize
					end
					if childSizing.type == Llay__SizingType.GROW then
						growContainerCount = growContainerCount + 1
					end
					if j > 0 then
						innerContentSize = innerContentSize + childGap
						totalPaddingAndGap = totalPaddingAndGap + childGap
					end
				else
					innerContentSize = LLAY__MAX(childSize, innerContentSize)
				end
			end

			-- Pass 2: Percent Sizing
			for j = 0, parent.childrenOrTextContent.children.length - 1 do
				local childIdx = parent.childrenOrTextContent.children.elements[j]
				local child = context.layoutElements.internalArray + childIdx
				local childSizing = xAxis and child.layoutConfig.sizing.width or child.layoutConfig.sizing.height
				if childSizing.type == Llay__SizingType.PERCENT then
					local size = (parentSize - totalPaddingAndGap) * childSizing.size.percent
					if xAxis then
						child.dimensions.width = size
					else
						child.dimensions.height = size
					end
					if sizingAlongAxis then
						innerContentSize = innerContentSize + size
					end
					Llay__UpdateAspectRatioBox(child)
				end
			end

			-- Pass 3: Distribute Free Space
			if sizingAlongAxis then
				local sizeToDistribute = parentSize - parentPadding - innerContentSize
				-- Compress
				if sizeToDistribute < 0 then
					-- If parent clips, don't compress children
					local clipConfig = Llay__FindElementConfigWithType(parent, Llay__ElementConfigType.CLIP)
					local canClip = clipConfig
						and (
							(xAxis and clipConfig.clipElementConfig.horizontal)
							or (not xAxis and clipConfig.clipElementConfig.vertical)
						)

					if not canClip then
						while sizeToDistribute < -LLAY__EPSILON and resizableContainerBuffer.length > 0 do
							local largest = 0.0
							local secondLargest = 0.0
							local widthToAdd = sizeToDistribute -- negative value

							-- Find largest and second largest to determine safe compression step
							for k = 0, resizableContainerBuffer.length - 1 do
								local idx = int32_array_get(resizableContainerBuffer, k)
								local child = context.layoutElements.internalArray + idx
								local childSize = xAxis and child.dimensions.width or child.dimensions.height
								if not Llay__FloatEqual(childSize, largest) then
									if childSize > largest then
										secondLargest = largest
										largest = childSize
									elseif childSize > secondLargest then
										secondLargest = childSize
									end
								end
							end

							if secondLargest > 0 then
								widthToAdd = secondLargest - largest
							end
							widthToAdd = LLAY__MAX(widthToAdd, sizeToDistribute / resizableContainerBuffer.length)

							local k = 0
							while k < resizableContainerBuffer.length do
								local idx = int32_array_get(resizableContainerBuffer, k)
								local child = context.layoutElements.internalArray + idx
								local current = xAxis and child.dimensions.width or child.dimensions.height
								local min = xAxis and child.minDimensions.width or child.minDimensions.height

								if Llay__FloatEqual(current, largest) then
									local target = current + widthToAdd
									if target <= min then
										target = min
										int32_array_remove_swapback(resizableContainerBuffer, k)
										-- Don't increment k so we check swapped element
									else
										k = k + 1
									end

									if xAxis then
										child.dimensions.width = target
									else
										child.dimensions.height = target
									end

									sizeToDistribute = sizeToDistribute - (target - current)
								else
									k = k + 1
								end
							end
						end
					end

				-- Expand
				elseif sizeToDistribute > 0 and growContainerCount > 0 then
					-- Filter buffer to only include GROW elements
					local k = 0
					while k < resizableContainerBuffer.length do
						local idx = int32_array_get(resizableContainerBuffer, k)
						local child = context.layoutElements.internalArray + idx
						local sType = xAxis and child.layoutConfig.sizing.width.type
							or child.layoutConfig.sizing.height.type
						if sType ~= Llay__SizingType.GROW then
							int32_array_remove_swapback(resizableContainerBuffer, k)
						else
							k = k + 1
						end
					end

					while sizeToDistribute > LLAY__EPSILON and resizableContainerBuffer.length > 0 do
						local smallest = LLAY__MAXFLOAT
						local secondSmallest = LLAY__MAXFLOAT
						local widthToAdd = sizeToDistribute

						for k = 0, resizableContainerBuffer.length - 1 do
							local idx = int32_array_get(resizableContainerBuffer, k)
							local child = context.layoutElements.internalArray + idx
							local childSize = xAxis and child.dimensions.width or child.dimensions.height
							if not Llay__FloatEqual(childSize, smallest) then
								if childSize < smallest then
									secondSmallest = smallest
									smallest = childSize
								elseif childSize < secondSmallest then
									secondSmallest = childSize
								end
							end
						end

						if secondSmallest ~= LLAY__MAXFLOAT then
							widthToAdd = secondSmallest - smallest
						end
						widthToAdd = LLAY__MIN(widthToAdd, sizeToDistribute / resizableContainerBuffer.length)

						local k = 0
						while k < resizableContainerBuffer.length do
							local idx = int32_array_get(resizableContainerBuffer, k)
							local child = context.layoutElements.internalArray + idx
							local current = xAxis and child.dimensions.width or child.dimensions.height
							local max = xAxis and child.layoutConfig.sizing.width.size.minMax.max
								or child.layoutConfig.sizing.height.size.minMax.max

							if Llay__FloatEqual(current, smallest) then
								local target = current + widthToAdd
								if target >= max then
									target = max
									int32_array_remove_swapback(resizableContainerBuffer, k)
								else
									k = k + 1
								end

								if xAxis then
									child.dimensions.width = target
								else
									child.dimensions.height = target
								end

								sizeToDistribute = sizeToDistribute - (target - current)
							else
								k = k + 1
							end
						end
					end
				end
			else
				-- Off-Axis Sizing
				for k = 0, resizableContainerBuffer.length - 1 do
					local idx = int32_array_get(resizableContainerBuffer, k)
					local child = context.layoutElements.internalArray + idx
					local childSizing = xAxis and child.layoutConfig.sizing.width or child.layoutConfig.sizing.height
					local minSize = xAxis and child.minDimensions.width or child.minDimensions.height
					local maxSize = parentSize - parentPadding

					-- If parent scrolls, grow elements expand to content size, not parent size
					if Llay__ElementHasConfig(parent, Llay__ElementConfigType.CLIP) then
						local clipConfig =
							Llay__FindElementConfigWithType(parent, Llay__ElementConfigType.CLIP).clipElementConfig
						local directionCheck = (xAxis and clipConfig.horizontal) or (not xAxis and clipConfig.vertical)
						if directionCheck then
							maxSize = LLAY__MAX(maxSize, innerContentSize)
						end
					end

					local val = xAxis and child.dimensions.width or child.dimensions.height
					if childSizing.type == Llay__SizingType.GROW then
						val = maxSize
						val = LLAY__MIN(val, childSizing.size.minMax.max)
					end

					val = LLAY__MAX(minSize, LLAY__MIN(val, maxSize))
					if xAxis then
						child.dimensions.width = val
					else
						child.dimensions.height = val
					end
				end
			end
			i = i + 1
		end
	end
end

-- ==================================================================================
-- Final Layout Calculation
-- ==================================================================================

local function Clay__CalculateFinalLayout()
	if context.layoutElements.length == 0 then
		return
	end

	-- 0. Sort roots by Z-index
	M.sort_roots_by_z()

	-- Track roots that need an extra scissor end (to balance root.clipElementId scissor starts)
	local rootNeedsExtraScissorEnd = {}

	-- 1. Size X
	Llay__SizeContainersAlongAxis(true)

	-- 2. Text Wrapping
	for i = 0, context.textElementData.length - 1 do
		local textData = context.textElementData.internalArray + i
		local elem = context.layoutElements.internalArray + textData.elementIndex
		local textConfigUnion = Llay__FindElementConfigWithType(elem, Llay__ElementConfigType.TEXT)
		if textConfigUnion == nil then goto continue_text_wrap end
		local config = textConfigUnion.textElementConfig
		local measured = Llay__MeasureTextCached(textData.text, config)

		local lineWidth = 0
		local lineHeight = config.lineHeight > 0 and config.lineHeight or textData.preferredDimensions.height
		local lineLength = 0
		local lineStart = 0
		local startWrappedLinesCount = context.wrappedTextLines.length

		local wordIdx = measured.measuredWordsStartIndex
		while wordIdx ~= -1 do
			local word = context.measuredWords.internalArray + wordIdx
			local shouldWrap = false
			if config.wrapMode == Llay_TextElementConfigWrapMode.WORDS then
				shouldWrap = (lineWidth + word.width > elem.dimensions.width)
			elseif config.wrapMode == Llay_TextElementConfigWrapMode.NEWLINES then
				shouldWrap = (word.length == 0)
			end

			if shouldWrap and lineLength > 0 then
				array_add(context.wrappedTextLines, {
					dimensions = { width = lineWidth, height = lineHeight },
					line = { length = lineLength, chars = textData.text.chars + lineStart },
				})
				lineWidth = 0
				lineLength = 0
				lineStart = word.startOffset
			end

			if word.length == 0 then
				wordIdx = word.next
				goto continue_word
			end

			lineWidth = lineWidth + word.width
			lineLength = lineLength + word.length
			wordIdx = word.next
			::continue_word::
		end

		if lineLength > 0 then
			array_add(context.wrappedTextLines, {
				dimensions = { width = lineWidth, height = lineHeight },
				line = { length = lineLength, chars = textData.text.chars + lineStart },
			})
		end

		local wrappedCount = context.wrappedTextLines.length - startWrappedLinesCount
		
		textData.wrappedLines.internalArray = context.wrappedTextLines.internalArray + startWrappedLinesCount
		textData.wrappedLines.length = wrappedCount

		elem.dimensions.height = lineHeight * LLAY__MAX(wrappedCount, 1)
		::continue_text_wrap::
	end

	-- 3. Aspect Ratio Height
	for i = 0, context.aspectRatioElementIndexes.length - 1 do
		local idx = int32_array_get(context.aspectRatioElementIndexes, i)
		local elem = context.layoutElements.internalArray + idx
		local config = Llay__FindElementConfigWithType(elem, Llay__ElementConfigType.ASPECT).aspectRatioElementConfig
		elem.dimensions.height = elem.dimensions.width / config.aspectRatio
	end

	-- 4. DFS for Height Propagation
	local dfsBuffer = context.layoutElementTreeNodeArray1
	local tempNode = ffi.new("Clay__LayoutElementTreeNode")
	dfsBuffer.length = 0
	for i = 0, context.layoutElementTreeRoots.length - 1 do
		local root = context.layoutElementTreeRoots.internalArray + i
		context.treeNodeVisited.internalArray[dfsBuffer.length] = false
		local node = array_add(dfsBuffer, ffi.new("Clay__LayoutElementTreeNode"))
		node.layoutElement = context.layoutElements.internalArray + root.layoutElementIndex
	end

	while dfsBuffer.length > 0 do
		local nodeIdx = dfsBuffer.length - 1
		local node = dfsBuffer.internalArray + nodeIdx
		local currentElement = node.layoutElement

		if not context.treeNodeVisited.internalArray[nodeIdx] then
			context.treeNodeVisited.internalArray[nodeIdx] = true
			if
				Llay__ElementHasConfig(currentElement, Llay__ElementConfigType.TEXT)
				or currentElement.childrenOrTextContent.children.length == 0
			then
				dfsBuffer.length = dfsBuffer.length - 1
				goto continue_dfs
			end
			-- Push children (in reverse order so they are processed in correct order)
			for i = currentElement.childrenOrTextContent.children.length - 1, 0, -1 do
				context.treeNodeVisited.internalArray[dfsBuffer.length] = false
				local childNode = array_add(dfsBuffer, ffi.new("Clay__LayoutElementTreeNode"))
				childNode.layoutElement = context.layoutElements.internalArray
					+ currentElement.childrenOrTextContent.children.elements[i]
			end
			goto continue_dfs
		end

		-- Visited (Backtracking)
		dfsBuffer.length = dfsBuffer.length - 1
		local layoutConfig = currentElement.layoutConfig
		if layoutConfig.layoutDirection == Llay_LayoutDirection.LEFT_TO_RIGHT then
			for j = 0, currentElement.childrenOrTextContent.children.length - 1 do
				local child = context.layoutElements.internalArray
					+ currentElement.childrenOrTextContent.children.elements[j]
				local h = LLAY__MAX(
					child.dimensions.height + layoutConfig.padding.top + layoutConfig.padding.bottom,
					currentElement.dimensions.height
				)
				currentElement.dimensions.height = LLAY__MIN(
					LLAY__MAX(h, layoutConfig.sizing.height.size.minMax.min),
					layoutConfig.sizing.height.size.minMax.max
				)
			end
		elseif layoutConfig.layoutDirection == Llay_LayoutDirection.TOP_TO_BOTTOM then
			local contentHeight = layoutConfig.padding.top + layoutConfig.padding.bottom
			for j = 0, currentElement.childrenOrTextContent.children.length - 1 do
				local child = context.layoutElements.internalArray
					+ currentElement.childrenOrTextContent.children.elements[j]
				contentHeight = contentHeight + child.dimensions.height
			end
			contentHeight = contentHeight
				+ (LLAY__MAX(currentElement.childrenOrTextContent.children.length - 1, 0) * layoutConfig.childGap)
			currentElement.dimensions.height = LLAY__MIN(
				LLAY__MAX(contentHeight, layoutConfig.sizing.height.size.minMax.min),
				layoutConfig.sizing.height.size.minMax.max
			)
		end

		::continue_dfs::
	end

	-- 5. Size Y
	Llay__SizeContainersAlongAxis(false)

	-- 6. Render Commands
	context.renderCommands.length = 0
	dfsBuffer.length = 0

	for i = 0, context.layoutElementTreeRoots.length - 1 do
		local root = context.layoutElementTreeRoots.internalArray + i
		local elem = context.layoutElements.internalArray + root.layoutElementIndex

		local rootPosition = { x = 0, y = 0 }

		local floatingConfigUnion = Llay__FindElementConfigWithType(elem, Llay__ElementConfigType.FLOATING)
		local floatingConfig = floatingConfigUnion ~= nil and floatingConfigUnion.floatingElementConfig or nil

		-- Floating elements attached to ROOT are positioned in absolute coordinates.
		if floatingConfig ~= nil and floatingConfig.attachTo == Llay_FloatingAttachToElement.ROOT then
			rootPosition.x = floatingConfig.offset.x
			rootPosition.y = floatingConfig.offset.y
		elseif root.parentId ~= 0 then
			local parentItem = Llay__GetHashMapItem(root.parentId)
			if parentItem then
				local parentBB = parentItem.boundingBox

				if
					floatingConfig.attachPoints.parent == 0
					or floatingConfig.attachPoints.parent == 3
					or floatingConfig.attachPoints.parent == 6
				then
					rootPosition.x = parentBB.x
				elseif
					floatingConfig.attachPoints.parent == 1
					or floatingConfig.attachPoints.parent == 4
					or floatingConfig.attachPoints.parent == 7
				then
					rootPosition.x = parentBB.x + (parentBB.width / 2)
				elseif
					floatingConfig.attachPoints.parent == 2
					or floatingConfig.attachPoints.parent == 5
					or floatingConfig.attachPoints.parent == 8
				then
					rootPosition.x = parentBB.x + parentBB.width
				end

				if
					floatingConfig.attachPoints.element == 1
					or floatingConfig.attachPoints.element == 4
					or floatingConfig.attachPoints.element == 7
				then
					rootPosition.x = rootPosition.x - (elem.dimensions.width / 2)
				elseif
					floatingConfig.attachPoints.element == 2
					or floatingConfig.attachPoints.element == 5
					or floatingConfig.attachPoints.element == 8
				then
					rootPosition.x = rootPosition.x - elem.dimensions.width
				end

				if
					floatingConfig.attachPoints.parent == 0
					or floatingConfig.attachPoints.parent == 1
					or floatingConfig.attachPoints.parent == 2
				then
					rootPosition.y = parentBB.y
				elseif
					floatingConfig.attachPoints.parent == 3
					or floatingConfig.attachPoints.parent == 4
					or floatingConfig.attachPoints.parent == 5
				then
					rootPosition.y = parentBB.y + (parentBB.height / 2)
				elseif
					floatingConfig.attachPoints.parent == 6
					or floatingConfig.attachPoints.parent == 7
					or floatingConfig.attachPoints.parent == 8
				then
					rootPosition.y = parentBB.y + parentBB.height
				end

				if
					floatingConfig.attachPoints.element == 3
					or floatingConfig.attachPoints.element == 4
					or floatingConfig.attachPoints.element == 5
				then
					rootPosition.y = rootPosition.y - (elem.dimensions.height / 2)
				elseif
					floatingConfig.attachPoints.element == 6
					or floatingConfig.attachPoints.element == 7
					or floatingConfig.attachPoints.element == 8
				then
					rootPosition.y = rootPosition.y - elem.dimensions.height
				end

				rootPosition.x = rootPosition.x + floatingConfig.offset.x
				rootPosition.y = rootPosition.y + floatingConfig.offset.y
			end
		end

		local node = array_add(dfsBuffer, ffi.new("Clay__LayoutElementTreeNode"))
		node.layoutElement = elem
		node.position.x = rootPosition.x
		node.position.y = rootPosition.y
		node.nextChildOffset.x = elem.layoutConfig.padding.left
		node.nextChildOffset.y = elem.layoutConfig.padding.top

		if root.clipElementId ~= 0 then
			local clipItem = Llay__GetHashMapItem(root.clipElementId)
			if clipItem then
				local cmd = array_add(context.renderCommands, nil)
				cmd.boundingBox = clipItem.boundingBox
				cmd.commandType = Llay_RenderCommandType.SCISSOR_START
				cmd.zIndex = root.zIndex
				rootNeedsExtraScissorEnd[elem.id] = true
			end
		end
	end

	-- Reset visited
	for i = 0, dfsBuffer.capacity - 1 do
		context.treeNodeVisited.internalArray[i] = false
	end

	while dfsBuffer.length > 0 do
		local nodeIdx = dfsBuffer.length - 1
		local node = dfsBuffer.internalArray + nodeIdx
		local elem = node.layoutElement
		local config = elem.layoutConfig

		if context.treeNodeVisited.internalArray[nodeIdx] then
			-- Backtracking: Handle End Scissor and Borders
			local closeClipElement = false
			if Llay__ElementHasConfig(elem, Llay__ElementConfigType.CLIP) then
				closeClipElement = true
			end

			-- Borders
			if Llay__ElementHasConfig(elem, Llay__ElementConfigType.BORDER) then
				local bbox = {
					x = node.position.x,
					y = node.position.y,
					width = elem.dimensions.width,
					height = elem.dimensions.height,
				}
				if not Llay__ElementIsOffscreen(bbox) then
					local borderConfig =
						Llay__FindElementConfigWithType(elem, Llay__ElementConfigType.BORDER).borderElementConfig
					local sharedConfig = Llay__FindElementConfigWithType(elem, Llay__ElementConfigType.SHARED)
					local cmd = array_add(context.renderCommands, nil)
					cmd.boundingBox = bbox
					cmd.renderData.border.color = borderConfig.color
					cmd.renderData.border.cornerRadius = sharedConfig and sharedConfig.sharedElementConfig.cornerRadius
						or ffi.new("Clay_CornerRadius")
					cmd.renderData.border.width = borderConfig.width
					cmd.userData = sharedConfig and sharedConfig.sharedElementConfig.userData or nil
					cmd.id = elem.id
					cmd.commandType = Llay_RenderCommandType.BORDER

					-- Generate between-children borders (as rectangles, not border commands)
					if borderConfig.width.betweenChildren > 0 and borderConfig.color.a > 0 then
						local layoutConfig = elem.layoutConfig
						local halfGap = layoutConfig.childGap / 2
						local borderOffset = {
							x = layoutConfig.padding.left - halfGap,
							y = layoutConfig.padding.top - halfGap
						}

						local scrollOffset = { x = 0, y = 0 }
						local clipConfig = Llay__FindElementConfigWithType(elem, Llay__ElementConfigType.CLIP)
						if clipConfig ~= nil then
							scrollOffset.x = clipConfig.clipElementConfig.childOffset.x
							scrollOffset.y = clipConfig.clipElementConfig.childOffset.y
						end

						if layoutConfig.layoutDirection == Llay_LayoutDirection.LEFT_TO_RIGHT then
							for i = 0, elem.childrenOrTextContent.children.length - 1 do
								local childIdx = elem.childrenOrTextContent.children.elements[i]
								local child = context.layoutElements.internalArray + childIdx
								if i > 0 then
									local cmd = array_add(context.renderCommands, nil)
									cmd.boundingBox = {
										x = bbox.x + borderOffset.x + scrollOffset.x,
										y = bbox.y + scrollOffset.y,
										width = borderConfig.width.betweenChildren,
										height = elem.dimensions.height
									}
									cmd.renderData.rectangle.backgroundColor = borderConfig.color
									cmd.userData = sharedConfig and sharedConfig.sharedElementConfig.userData or nil
									cmd.id = Llay__HashNumber(elem.id, elem.childrenOrTextContent.children.length + 1 + i).id
									cmd.commandType = Llay_RenderCommandType.RECTANGLE
								end
								borderOffset.x = borderOffset.x + child.dimensions.width + layoutConfig.childGap
							end
						else -- TOP_TO_BOTTOM
							for i = 0, elem.childrenOrTextContent.children.length - 1 do
								local childIdx = elem.childrenOrTextContent.children.elements[i]
								local child = context.layoutElements.internalArray + childIdx
								if i > 0 then
									local cmd = array_add(context.renderCommands, nil)
									cmd.boundingBox = {
										x = bbox.x + scrollOffset.x,
										y = bbox.y + borderOffset.y + scrollOffset.y,
										width = elem.dimensions.width,
										height = borderConfig.width.betweenChildren
									}
									cmd.renderData.rectangle.backgroundColor = borderConfig.color
									cmd.userData = sharedConfig and sharedConfig.sharedElementConfig.userData or nil
									cmd.id = Llay__HashNumber(elem.id, elem.childrenOrTextContent.children.length + 1 + i).id
									cmd.commandType = Llay_RenderCommandType.RECTANGLE
								end
								borderOffset.y = borderOffset.y + child.dimensions.height + layoutConfig.childGap
							end
						end
					end
				end
			end

			if closeClipElement then
				local cmd = array_add(context.renderCommands, nil)
				cmd.commandType = Llay_RenderCommandType.SCISSOR_END
				cmd.id = elem.id
			end

			if rootNeedsExtraScissorEnd[elem.id] then
				local cmd = array_add(context.renderCommands, nil)
				cmd.commandType = Llay_RenderCommandType.SCISSOR_END
				cmd.id = elem.id
				rootNeedsExtraScissorEnd[elem.id] = nil
			end

			dfsBuffer.length = dfsBuffer.length - 1
		else
			context.treeNodeVisited.internalArray[nodeIdx] = true

			local bbox = {
				x = node.position.x,
				y = node.position.y,
				width = elem.dimensions.width,
				height = elem.dimensions.height,
			}

			-- Update Hash Map Bounding Box
			local hashMapItem = Llay__GetHashMapItem(elem.id)
			if hashMapItem then
				hashMapItem.boundingBox = bbox
			end

			local shouldRender = not Llay__ElementIsOffscreen(bbox)
			local shared = Llay__FindElementConfigWithType(elem, Llay__ElementConfigType.SHARED)
			local userData = shared and shared.sharedElementConfig.userData or nil
			local zIndex = 0 -- Assuming 0 if not tracked via tree root

			-- SCISSOR START
			if Llay__ElementHasConfig(elem, Llay__ElementConfigType.CLIP) then
				local clipConfig = Llay__FindElementConfigWithType(elem, Llay__ElementConfigType.CLIP).clipElementConfig
				local cmd = array_add(context.renderCommands, nil)
				cmd.boundingBox = bbox
				cmd.renderData.clip.horizontal = clipConfig.horizontal
				cmd.renderData.clip.vertical = clipConfig.vertical
				cmd.commandType = Llay_RenderCommandType.SCISSOR_START
				cmd.id = elem.id
				cmd.zIndex = zIndex
			end

			if shouldRender then
				-- RECTANGLE
				if shared and shared.sharedElementConfig.backgroundColor.a > 0 then
					local cmd = array_add(context.renderCommands, nil)
					cmd.boundingBox = bbox
					cmd.renderData.rectangle.backgroundColor = shared.sharedElementConfig.backgroundColor
					cmd.renderData.rectangle.cornerRadius = shared.sharedElementConfig.cornerRadius
					cmd.commandType = Llay_RenderCommandType.RECTANGLE
					cmd.userData = userData
					cmd.id = elem.id
					cmd.zIndex = zIndex
				end

				-- TEXT
				if Llay__ElementHasConfig(elem, Llay__ElementConfigType.TEXT) then
					local textConfig =
						Llay__FindElementConfigWithType(elem, Llay__ElementConfigType.TEXT).textElementConfig
					local textData = elem.childrenOrTextContent.textElementData

					local lineHeight = textConfig.lineHeight > 0 and textConfig.lineHeight
						or textData.preferredDimensions.height
					local yPos = (lineHeight - textData.preferredDimensions.height) / 2

					for i = 0, textData.wrappedLines.length - 1 do
						local line = textData.wrappedLines.internalArray + i
						if line.line.length > 0 then
							local offset = 0
							if textConfig.textAlignment == Llay_TextAlignment.CENTER then
								offset = (elem.dimensions.width - line.dimensions.width) / 2
							elseif textConfig.textAlignment == Llay_TextAlignment.RIGHT then
								offset = elem.dimensions.width - line.dimensions.width
							end

							local cmd = array_add(context.renderCommands, nil)
							cmd.boundingBox = {
								x = bbox.x + offset,
								y = bbox.y + yPos,
								width = line.dimensions.width,
								height = line.dimensions.height,
							}
							cmd.renderData.text.stringContents = { length = line.line.length, chars = line.line.chars }
							local textColor = textConfig.textColor or ffi.new("Clay_Color")
							cmd.renderData.text.textColor.r = textColor.r or 0
							cmd.renderData.text.textColor.g = textColor.g or 0
							cmd.renderData.text.textColor.b = textColor.b or 0
							cmd.renderData.text.textColor.a = textColor.a or 255
							cmd.renderData.text.fontId = textConfig.fontId or 0
							cmd.renderData.text.fontSize = textConfig.fontSize or 16
							cmd.renderData.text.letterSpacing = textConfig.letterSpacing or 0
							cmd.renderData.text.lineHeight = textConfig.lineHeight or 0
							cmd.userData = textConfig.userData
							cmd.id = elem.id
							cmd.zIndex = zIndex
							cmd.commandType = Llay_RenderCommandType.TEXT
						end
						yPos = yPos + lineHeight
					end
				end

				-- IMAGE
				if Llay__ElementHasConfig(elem, Llay__ElementConfigType.IMAGE) then
					local imageConfig =
						Llay__FindElementConfigWithType(elem, Llay__ElementConfigType.IMAGE).imageElementConfig
					local cmd = array_add(context.renderCommands, nil)
					cmd.boundingBox = bbox
					cmd.renderData.image.imageData = imageConfig.imageData
					cmd.renderData.image.cornerRadius = shared and shared.sharedElementConfig.cornerRadius
						or ffi.new("Clay_CornerRadius")
					cmd.renderData.image.backgroundColor = shared and shared.sharedElementConfig.backgroundColor
						or ffi.new("Clay_Color")
					cmd.commandType = Llay_RenderCommandType.IMAGE
					cmd.userData = userData
					cmd.id = elem.id
					cmd.zIndex = zIndex
				end

				-- CUSTOM
				if Llay__ElementHasConfig(elem, Llay__ElementConfigType.CUSTOM) then
					local customConfig =
						Llay__FindElementConfigWithType(elem, Llay__ElementConfigType.CUSTOM).customElementConfig
					local cmd = array_add(context.renderCommands, nil)
					cmd.boundingBox = bbox
					cmd.renderData.custom.customData = customConfig.customData
					cmd.renderData.custom.cornerRadius = shared and shared.sharedElementConfig.cornerRadius
						or ffi.new("Clay_CornerRadius")
					cmd.renderData.custom.backgroundColor = shared and shared.sharedElementConfig.backgroundColor
						or ffi.new("Clay_Color")
					cmd.commandType = Llay_RenderCommandType.CUSTOM
					cmd.userData = userData
					cmd.id = elem.id
					cmd.zIndex = zIndex
				end
			end

			if not Llay__ElementHasConfig(elem, Llay__ElementConfigType.TEXT) then
				local contentSize = { width = 0, height = 0 }
				local clipCfgUnion = Llay__FindElementConfigWithType(elem, Llay__ElementConfigType.CLIP)
				local padW = config.padding.left + config.padding.right
				local padH = config.padding.top + config.padding.bottom
				if config.layoutDirection == Llay_LayoutDirection.LEFT_TO_RIGHT then
					for i = 0, elem.childrenOrTextContent.children.length - 1 do
						local child = context.layoutElements.internalArray + elem.childrenOrTextContent.children.elements[i]
						contentSize.width = contentSize.width + child.dimensions.width
						contentSize.height = LLAY__MAX(contentSize.height, child.dimensions.height)
					end
					contentSize.width = contentSize.width + (LLAY__MAX(elem.childrenOrTextContent.children.length - 1, 0) * config.childGap)

					-- Update scroll container bookkeeping (persistent) now that we know the content extent.
					if clipCfgUnion ~= nil then
						for si = 0, context.scrollContainerDatas.length - 1 do
							local scrollData = context.scrollContainerDatas.internalArray + si
							if scrollData.elementId == elem.id then
								scrollData.boundingBox = bbox
								scrollData.contentSize.width = contentSize.width + padW
								scrollData.contentSize.height = contentSize.height + padH
								break
							end
						end
					end

					local extraSpace = elem.dimensions.width - (config.padding.left + config.padding.right) - contentSize.width
					
					if config.childAlignment.x == Llay_AlignX.LEFT then
						extraSpace = 0
					elseif config.childAlignment.x == Llay_AlignX.CENTER then
						extraSpace = extraSpace / 2
					end
					
					node.nextChildOffset.x = node.nextChildOffset.x + extraSpace
				else
					for i = 0, elem.childrenOrTextContent.children.length - 1 do
						local child = context.layoutElements.internalArray + elem.childrenOrTextContent.children.elements[i]
						contentSize.width = LLAY__MAX(contentSize.width, child.dimensions.width)
						contentSize.height = contentSize.height + child.dimensions.height
					end
					contentSize.height = contentSize.height + (LLAY__MAX(elem.childrenOrTextContent.children.length - 1, 0) * config.childGap)

					if clipCfgUnion ~= nil then
						for si = 0, context.scrollContainerDatas.length - 1 do
							local scrollData = context.scrollContainerDatas.internalArray + si
							if scrollData.elementId == elem.id then
								scrollData.boundingBox = bbox
								scrollData.contentSize.width = contentSize.width + padW
								scrollData.contentSize.height = contentSize.height + padH
								break
							end
						end
					end

					local extraSpace = elem.dimensions.height - (config.padding.top + config.padding.bottom) - contentSize.height
					
					if config.childAlignment.y == Llay_AlignY.TOP then
						extraSpace = 0
					elseif config.childAlignment.y == Llay_AlignY.CENTER then
						extraSpace = extraSpace / 2
					end
					
					node.nextChildOffset.y = node.nextChildOffset.y + extraSpace
				end
			end

			if elem.childrenOrTextContent.children.length > 0 then
				local scrollOffsetX = 0
				local scrollOffsetY = 0
				local clipCfgUnion = Llay__FindElementConfigWithType(elem, Llay__ElementConfigType.CLIP)
				if clipCfgUnion ~= nil then
					local clipCfg = clipCfgUnion.clipElementConfig
					scrollOffsetX = clipCfg.childOffset.x
					scrollOffsetY = clipCfg.childOffset.y
				end

				local currentOffset = { x = node.nextChildOffset.x, y = node.nextChildOffset.y }

				for j = 0, elem.childrenOrTextContent.children.length - 1 do
					local childIdx = elem.childrenOrTextContent.children.elements[j]
					local child = context.layoutElements.internalArray + childIdx

					-- Alignment Logic for Child Axis
					if config.layoutDirection == Llay_LayoutDirection.LEFT_TO_RIGHT then
						currentOffset.y = config.padding.top
						local freeSpace = elem.dimensions.height
							- config.padding.top
							- config.padding.bottom
							- child.dimensions.height
						if config.childAlignment.y == Llay_AlignY.CENTER then
							currentOffset.y = currentOffset.y + freeSpace / 2
						elseif config.childAlignment.y == Llay_AlignY.BOTTOM then
							currentOffset.y = currentOffset.y + freeSpace
						end
					else
						currentOffset.x = config.padding.left
						local freeSpace = elem.dimensions.width
							- config.padding.left
							- config.padding.right
							- child.dimensions.width
						if config.childAlignment.x == Llay_AlignX.CENTER then
							currentOffset.x = currentOffset.x + freeSpace / 2
						elseif config.childAlignment.x == Llay_AlignX.RIGHT then
							currentOffset.x = currentOffset.x + freeSpace
						end
					end

					local childNode = array_add(dfsBuffer, ffi.new("Clay__LayoutElementTreeNode"))
					childNode.layoutElement = child
					childNode.position.x = node.position.x + currentOffset.x + scrollOffsetX
					childNode.position.y = node.position.y + currentOffset.y + scrollOffsetY
					childNode.nextChildOffset.x = child.layoutConfig.padding.left
					childNode.nextChildOffset.y = child.layoutConfig.padding.top
					context.treeNodeVisited.internalArray[dfsBuffer.length - 1] = false

					if config.layoutDirection == Llay_LayoutDirection.LEFT_TO_RIGHT then
						currentOffset.x = currentOffset.x + child.dimensions.width + config.childGap
					else
						currentOffset.y = currentOffset.y + child.dimensions.height + config.childGap
					end
				end

				-- Reverse the added children so they are popped in 0..N order
				local childrenCount = elem.childrenOrTextContent.children.length
				if childrenCount > 1 then
					local startIdx = dfsBuffer.length - childrenCount
					local endIdx = dfsBuffer.length - 1
					while startIdx < endIdx do
						-- Swap
						tempNode.layoutElement = dfsBuffer.internalArray[startIdx].layoutElement
						tempNode.position.x = dfsBuffer.internalArray[startIdx].position.x
						tempNode.position.y = dfsBuffer.internalArray[startIdx].position.y
						tempNode.nextChildOffset.x = dfsBuffer.internalArray[startIdx].nextChildOffset.x
						tempNode.nextChildOffset.y = dfsBuffer.internalArray[startIdx].nextChildOffset.y

						dfsBuffer.internalArray[startIdx].layoutElement = dfsBuffer.internalArray[endIdx].layoutElement
						dfsBuffer.internalArray[startIdx].position.x = dfsBuffer.internalArray[endIdx].position.x
						dfsBuffer.internalArray[startIdx].position.y = dfsBuffer.internalArray[endIdx].position.y
						dfsBuffer.internalArray[startIdx].nextChildOffset.x =
							dfsBuffer.internalArray[endIdx].nextChildOffset.x
						dfsBuffer.internalArray[startIdx].nextChildOffset.y =
							dfsBuffer.internalArray[endIdx].nextChildOffset.y

						dfsBuffer.internalArray[endIdx].layoutElement = tempNode.layoutElement
						dfsBuffer.internalArray[endIdx].position.x = tempNode.position.x
						dfsBuffer.internalArray[endIdx].position.y = tempNode.position.y
						dfsBuffer.internalArray[endIdx].nextChildOffset.x = tempNode.nextChildOffset.x
						dfsBuffer.internalArray[endIdx].nextChildOffset.y = tempNode.nextChildOffset.y

						startIdx = startIdx + 1
						endIdx = endIdx - 1
					end
				end
			end
		end
	end
end

-- ==================================================================================
-- Public API
-- ==================================================================================

function M.initialize(capacity, dims)
	capacity = capacity or (1024 * 1024 * 16)
	
	-- ANCHOR THE MEMORY: Prevent GC from reclaiming the arena and context
	_ANCHORS.arena_memory = ffi.new("uint8_t[?]", capacity)
	_ANCHORS.context = ffi.new("Clay_Context")
	
	context = _ANCHORS.context
	context.maxElementCount = 8192
	context.maxMeasureTextCacheWordCount = 16384
	context.internalArena.capacity = capacity
	context.internalArena.memory = ffi.cast("char*", _ANCHORS.arena_memory)
	context.internalArena.nextAllocation = 0
	context.layoutDimensions.width = dims and dims.width or 800
	context.layoutDimensions.height = dims and dims.height or 600

	Llay__InitializePersistentMemory(context)
	Llay__InitializeEphemeralMemory(context)

	-- Reset Hash Maps
	for i = 0, context.layoutElementsHashMap.capacity - 1 do
		context.layoutElementsHashMap.internalArray[i] = -1
	end
	for i = 0, context.measureTextHashMap.capacity - 1 do
		context.measureTextHashMap.internalArray[i] = 0
	end
	context.measureTextHashMapInternal.length = 1

	if DEBUG_MODE then
		Inspector.validate_pointer(context.internalArena.memory, "Arena Base")
	end

	return context
end

function M.begin_layout()
	Llay__InitializeEphemeralMemory(context)
	context.generation = context.generation + 1
	next_element_id = 1
	
	local rootId = M.Llay__GetElementId("Clay__RootContainer")
	M.open_element_with_id(rootId)
	
	M.configure_open_element(ffi.new("Clay_ElementDeclaration", {
		layout = ffi.new("Clay_LayoutConfig", {
			sizing = {
				width = {
					type = 3,
					size = {
						minMax = {
							min = context.layoutDimensions.width,
							max = context.layoutDimensions.width,
						},
					},
				},
				height = {
					type = 3,
					size = {
						minMax = {
							min = context.layoutDimensions.height,
							max = context.layoutDimensions.height,
						},
					},
				},
			},
		}),
	}))
	
	-- initialize tree roots - root element is already at index 0 and on the stack
	local treeRoot = context.layoutElementTreeRoots.internalArray
	treeRoot[0].layoutElementIndex = 0
	treeRoot[0].zIndex = 0
	context.layoutElementTreeRoots.length = 1
end

function M.end_layout()
	M.close_element()
	Clay__CalculateFinalLayout()
	
	if DEBUG_MODE then
		Inspector.check_arena_health()
	end
	
	return context.renderCommands
end

local function Clay__GenerateIdForAnonymousElement(openLayoutElement)
	local parentIdx = int32_array_get(context.openLayoutElementStack, context.openLayoutElementStack.length - 2)
	local parent = context.layoutElements.internalArray + parentIdx
	local slot = parentIdx
	local offset = parent.childrenOrTextContent.children.length + parent.floatingChildrenCount + _openChildrenCounts[slot]
	_openChildrenCounts[slot] = _openChildrenCounts[slot] + 1
	local elementId = Llay__HashNumber(offset, parent.id)

	openLayoutElement.id = elementId.id
	Llay__AddHashMapItem(elementId, openLayoutElement)
	array_add(context.layoutElementIdStrings, elementId.stringId)
	return elementId
end

function M.open_element()
	local elemIdx = context.layoutElements.length
	local elem = array_add(context.layoutElements, ffi.new("Clay_LayoutElement"))
	
	ffi.fill(elem, ffi.sizeof("Clay_LayoutElement"))
	
	int32_array_add(context.openLayoutElementStack, elemIdx)
	
	if context.openClipElementStack.length > 0 then
		local clipId = int32_array_get(context.openClipElementStack, context.openClipElementStack.length - 1)
		int32_array_set(context.layoutElementClipElementIds, elemIdx, clipId)
	end
	
	if context.openLayoutElementStack.length > 1 then
		Clay__GenerateIdForAnonymousElement(elem)
	end
	
	return elem
end

function M.open_element_with_id(elementId)
	local elem = M.open_element()
	local elemIdx = context.layoutElements.length - 1

	elem.id = elementId.id
	Llay__AddHashMapItem(elementId, elem)

	local strId = ffi.new("Clay_String")
	strId.length = elementId.stringId.length
	local charsValue = elementId.stringId.chars
	if type(charsValue) == "table" then
		charsValue = charsValue.chars or charsValue[1] or ""
	end

	-- FIX: Copy ID string to arena to prevent GC corruption of debug strings
	local charsPtr, _ = Llay__AllocateStringInArena(charsValue)
	strId.chars = charsPtr
	strId.isStaticallyAllocated = true

	array_add(context.layoutElementIdStrings, strId)

	return elem
end

function M.configure_open_element(declaration)
	Llay__ConfigureOpenElement(declaration)
end

function M.close_element()
	local closingIdx = int32_array_remove_swapback(context.openLayoutElementStack, context.openLayoutElementStack.length - 1)
	local elem = context.layoutElements.internalArray + closingIdx
	
	if DEBUG_MODE then
		print("[CLOSE] Closing element " .. closingIdx)
		print("[CLOSE]   Stack before: " .. context.openLayoutElementStack.length .. " elements")
		print("[CLOSE]   Buffer size before: " .. context.layoutElementChildrenBuffer.length)
	end
	
	if elem.layoutConfig == nil then
		elem.layoutConfig = context.layoutConfigs.internalArray
	end

	if context.openClipElementStack.length > 0 then
		if
			Llay__ElementHasConfig(elem, Llay__ElementConfigType.CLIP)
			or Llay__ElementHasConfig(elem, Llay__ElementConfigType.FLOATING)
		then
			int32_array_remove_swapback(context.openClipElementStack, context.openClipElementStack.length - 1)
		end
	end

	local childCount = elem.childrenOrTextContent.children.length
	if childCount > 0 then
		local baseIdx = context.layoutElementChildren.length
		for i = 0, childCount - 1 do
			local childIdx =
				context.layoutElementChildrenBuffer.internalArray[context.layoutElementChildrenBuffer.length - childCount + i]
			if DEBUG_MODE then
				print("[CLOSE]   Adding child " .. i .. " with index " .. childIdx .. " from buffer position " .. (context.layoutElementChildrenBuffer.length - childCount + i))
			end
			int32_array_add(context.layoutElementChildren, childIdx)
		end
		elem.childrenOrTextContent.children.elements = context.layoutElementChildren.internalArray + baseIdx
		context.layoutElementChildrenBuffer.length = context.layoutElementChildrenBuffer.length - childCount
		
		if DEBUG_MODE then
			print("[CLOSE]   Now has " .. childCount .. " children at indices: ")
			for i = 0, childCount - 1 do
				print("[CLOSE]     [" .. i .. "]=" .. elem.childrenOrTextContent.children.elements[i])
			end
		end
	end

	local config = elem.layoutConfig
	local padW = config.padding.left + config.padding.right
	local padH = config.padding.top + config.padding.bottom
	
	if config.layoutDirection == Llay_LayoutDirection.LEFT_TO_RIGHT then
		elem.dimensions.width = padW
		for i = 0, childCount - 1 do
			local child = context.layoutElements.internalArray + elem.childrenOrTextContent.children.elements[i]
			elem.dimensions.width = elem.dimensions.width + child.dimensions.width
			-- For cross-axis (height in LEFT_TO_RIGHT), GROW children haven't been sized yet
			-- Use minDimensions (intrinsic size) instead so FIT parent can calculate proper height
			local childHeight = child.dimensions.height
			if child.layoutConfig.sizing.height.type == Llay__SizingType.GROW then
				childHeight = child.minDimensions.height
			end
			elem.dimensions.height = LLAY__MAX(elem.dimensions.height, childHeight + padH)
		end
		elem.dimensions.width = elem.dimensions.width + (LLAY__MAX(childCount - 1, 0) * config.childGap)
	else
		elem.dimensions.height = padH
		for i = 0, childCount - 1 do
			local child = context.layoutElements.internalArray + elem.childrenOrTextContent.children.elements[i]
			elem.dimensions.height = elem.dimensions.height + child.dimensions.height
			-- For cross-axis (width in TOP_TO_BOTTOM), GROW children haven't been sized yet
			-- Use minDimensions (intrinsic size) instead so FIT parent can calculate proper width
			local childWidth = child.dimensions.width
			if child.layoutConfig.sizing.width.type == Llay__SizingType.GROW then
				childWidth = child.minDimensions.width
			end
			elem.dimensions.width = LLAY__MAX(elem.dimensions.width, childWidth + padW)
		end
		elem.dimensions.height = elem.dimensions.height + (LLAY__MAX(childCount - 1, 0) * config.childGap)
	end

	if context.openLayoutElementStack.length > 0 then
		local parentIdx = int32_array_get(context.openLayoutElementStack, context.openLayoutElementStack.length - 1)
		local parent = context.layoutElements.internalArray + parentIdx
		
		if DEBUG_MODE then
			print("[CLOSE]   Parent is element " .. parentIdx)
		end

		if Llay__ElementHasConfig(elem, Llay__ElementConfigType.FLOATING) then
			parent.floatingChildrenCount = parent.floatingChildrenCount + 1
			if DEBUG_MODE then
				print("[CLOSE]   This is a floating child")
			end
		else
			parent.childrenOrTextContent.children.length = parent.childrenOrTextContent.children.length + 1
			if DEBUG_MODE then
				print("[CLOSE]   Adding this child to buffer (parent now has " .. parent.childrenOrTextContent.children.length .. " pending children)")
			end
			int32_array_add(context.layoutElementChildrenBuffer, closingIdx)
		end
	end

	if config.sizing.width.type ~= Llay__SizingType.PERCENT then
		if config.sizing.width.size.minMax.max <= 0 then
			config.sizing.width.size.minMax.max = LLAY__MAXFLOAT
		end
		elem.dimensions.width = LLAY__MIN(
			LLAY__MAX(elem.dimensions.width, config.sizing.width.size.minMax.min),
			config.sizing.width.size.minMax.max
		)
		elem.minDimensions.width = LLAY__MIN(
			LLAY__MAX(elem.minDimensions.width, config.sizing.width.size.minMax.min),
			config.sizing.width.size.minMax.max
		)
	else
		elem.dimensions.width = 0
	end

	if config.sizing.height.type ~= Llay__SizingType.PERCENT then
		if config.sizing.height.size.minMax.max <= 0 then
			config.sizing.height.size.minMax.max = LLAY__MAXFLOAT
		end
		elem.dimensions.height = LLAY__MIN(
			LLAY__MAX(elem.dimensions.height, config.sizing.height.size.minMax.min),
			config.sizing.height.size.minMax.max
		)
		elem.minDimensions.height = LLAY__MIN(
			LLAY__MAX(elem.minDimensions.height, config.sizing.height.size.minMax.min),
			config.sizing.height.size.minMax.max
		)
	else
		elem.dimensions.height = 0
	end

	Llay__UpdateAspectRatioBox(elem)
end

function M.set_measure_text(fn, userData)
	measure_text_fn = fn
	context.measureTextUserData = userData
end

function M.set_query_scroll_offset(fn, userData)
	query_scroll_offset_fn = fn
	context.queryScrollOffsetUserData = userData
end

function M.get_scroll_offset()
	if query_scroll_offset_fn then
		return query_scroll_offset_fn()
	end
	
	local openElement = Llay__GetOpenLayoutElement()
	if not openElement then
		return { x = 0, y = 0 }
	end
	
	-- If the element has no id attached at this point, generate one
	if openElement.id == 0 then
		Clay__GenerateIdForAnonymousElement(openElement)
	end
	
	-- Search through scrollContainerDatas for matching element
	for i = 0, context.scrollContainerDatas.length - 1 do
		local mapping = context.scrollContainerDatas.internalArray + i
		-- Compare by elementId since layoutElement pointer may change between frames
		if mapping.elementId == openElement.id then
			return { x = mapping.scrollPosition.x, y = mapping.scrollPosition.y }
		end
	end
	
	return { x = 0, y = 0 }
end

function M.set_dimensions(w, h)
	context.layoutDimensions.width = w
	context.layoutDimensions.height = h
end

-- ==================================================================================
-- INTERACTION SYSTEM
-- ==================================================================================

function M.point_is_inside_rect(point, rect)
	return point.x >= rect.x and point.x <= rect.x + rect.width and 
		   point.y >= rect.y and point.y <= rect.y + rect.height
end

function M.set_pointer_state(position, isPointerDown)
	if context.booleanWarnings.maxElementsExceeded then return end

	-- FIX 1: Ensure z-order is current before hit testing
	M.sort_roots_by_z()

	-- Ensure position matches C struct layout if passed as table
	if type(position) == "table" and not ffi.istype("Clay_Vector2", position) then
		context.pointerInfo.position.x = position.x
		context.pointerInfo.position.y = position.y
	else
		context.pointerInfo.position = position
	end

	context.pointerOverIds.length = 0
	
	-- FIX 1: Track which root owns capture so we can filter descendants
	local capturedRootIndex = -1
	
	for rootIndex = context.layoutElementTreeRoots.length - 1, 0, -1 do
		-- FIX 1: If we already found a CAPTURE element in a previous (front) root, 
		-- don't process any more background roots
		if capturedRootIndex ~= -1 then
			break
		end
		
		local root = context.layoutElementTreeRoots.internalArray[rootIndex]
		local rootElement = context.layoutElements.internalArray + root.layoutElementIndex
		
		local function hitTest(elemIdx)
			local elem = context.layoutElements.internalArray + elemIdx
			local mapItem = Llay__GetHashMapItem(elem.id)
			if not mapItem then return false end

			-- Floating passthrough: ignore this subtree for hit testing.
			local floatingUnion = Llay__FindElementConfigWithType(elem, Llay__ElementConfigType.FLOATING)
			if floatingUnion ~= nil then
				local floatingCfg = floatingUnion.floatingElementConfig
				if floatingCfg.pointerCaptureMode == Llay_PointerCaptureMode.PASSTHROUGH then
					return false
				end
			end
			
			local hitChild = false
			if not Llay__ElementHasConfig(elem, Llay__ElementConfigType.TEXT) then
				for i = elem.childrenOrTextContent.children.length - 1, 0, -1 do
					if hitTest(elem.childrenOrTextContent.children.elements[i]) then
						hitChild = true
						break
					end
				end
			end
			
			if hitChild then
				-- Bubble up hover state so parent containers (scroll areas, buttons, etc.)
				-- are considered hovered when the pointer is over their children.
				element_id_array_add(context.pointerOverIds, mapItem.elementId)
				return true
			end
			
			if M.point_is_inside_rect(position, mapItem.boundingBox) then
				element_id_array_add(context.pointerOverIds, mapItem.elementId)
				return true
			end
			return false
		end
		
		local found = hitTest(root.layoutElementIndex)
		
		-- Check for pointer capture mode - if this root is a floating element with CAPTURE mode, stop here
		if found then
			local floatingUnion = Llay__FindElementConfigWithType(rootElement, Llay__ElementConfigType.FLOATING)
			if floatingUnion ~= nil then
				local floatingCfg = floatingUnion.floatingElementConfig
				if floatingCfg.pointerCaptureMode == Llay_PointerCaptureMode.CAPTURE then
					capturedRootIndex = rootIndex
					break
				end
			end
		end
	end

	local state = context.pointerInfo.state
	if isPointerDown then
		if state == Llay_PointerDataInteractionState.PRESSED_THIS_FRAME or state == Llay_PointerDataInteractionState.PRESSED then
			context.pointerInfo.state = Llay_PointerDataInteractionState.PRESSED
		else
			context.pointerInfo.state = Llay_PointerDataInteractionState.PRESSED_THIS_FRAME
		end
	else
		if state == Llay_PointerDataInteractionState.RELEASED_THIS_FRAME or state == Llay_PointerDataInteractionState.RELEASED then
			context.pointerInfo.state = Llay_PointerDataInteractionState.RELEASED
		else
			context.pointerInfo.state = Llay_PointerDataInteractionState.RELEASED_THIS_FRAME
		end
	end
end

-- ==================================================================================
-- SCROLL SYSTEM
-- ==================================================================================

function M.update_scroll_containers(enableDragScrolling, scrollDelta, deltaTime, capture_owner_id)
	capture_owner_id = capture_owner_id or 0  -- 0 means no capture
	local isPointerActive = enableDragScrolling and (context.pointerInfo.state <= 1) -- PRESSED_THIS_FRAME or PRESSED
	local highestPriorityScrollData = nil
	local changed = false

	for i = 0, context.scrollContainerDatas.length - 1 do
		local scrollData = context.scrollContainerDatas.internalArray + i
		if not scrollData.openThisFrame then goto next_scroll end

		-- FIX 2: If we have a capture owner, only process if this scroll container IS the owner
		-- or is a child of the owner
		if capture_owner_id ~= 0 and scrollData.elementId ~= capture_owner_id then
			goto next_scroll
		end

		scrollData.openThisFrame = false
		local hashMapItem = Llay__GetHashMapItem(scrollData.elementId)
		if not hashMapItem then goto next_scroll end

		-- Momentum Logic
		if not isPointerActive and scrollData.pointerScrollActive then
			local denom = scrollData.momentumTime
			if denom < 0.001 then denom = 0.001 end

			scrollData.scrollMomentum.x = (scrollData.scrollPosition.x - scrollData.scrollOrigin.x) / (denom * 25)
			scrollData.scrollMomentum.y = (scrollData.scrollPosition.y - scrollData.scrollOrigin.y) / (denom * 25)
			scrollData.pointerScrollActive = false
		end

		-- Apply Friction
		local prevX = scrollData.scrollPosition.x
		local prevY = scrollData.scrollPosition.y
		scrollData.scrollPosition.x = scrollData.scrollPosition.x + scrollData.scrollMomentum.x
		scrollData.scrollMomentum.x = scrollData.scrollMomentum.x * 0.95
		scrollData.scrollPosition.y = scrollData.scrollPosition.y + scrollData.scrollMomentum.y
		scrollData.scrollMomentum.y = scrollData.scrollMomentum.y * 0.95

		-- Mark changed if friction modified position
		if scrollData.scrollPosition.x ~= prevX or scrollData.scrollPosition.y ~= prevY then
			changed = true
		end

		-- Find if pointer is over this container
		-- Iterate in REVERSE to find the LAST added (topmost) element first
		-- pointerOverIds is filled back-to-front during hit testing, so last = top
		for j = context.pointerOverIds.length - 1, 0, -1 do
			if scrollData.elementId == context.pointerOverIds.internalArray[j].id then
				highestPriorityScrollData = scrollData
				break -- Take the last (topmost) match
			end
		end
		::next_scroll::
	end

	if highestPriorityScrollData then
		local scrollElement = highestPriorityScrollData.layoutElement
		local clip = Llay__FindElementConfigWithType(scrollElement, Llay__ElementConfigType.CLIP).clipElementConfig

		local beforeX = highestPriorityScrollData.scrollPosition.x
		local beforeY = highestPriorityScrollData.scrollPosition.y

		-- Wheel Scroll
		if clip.vertical then
			highestPriorityScrollData.scrollPosition.y = highestPriorityScrollData.scrollPosition.y + scrollDelta.y
		end
		if clip.horizontal then
			highestPriorityScrollData.scrollPosition.x = highestPriorityScrollData.scrollPosition.x + scrollDelta.x
		end

		-- Drag Scroll
		if isPointerActive then
			if not highestPriorityScrollData.pointerScrollActive then
				highestPriorityScrollData.pointerOrigin = context.pointerInfo.position
				highestPriorityScrollData.scrollOrigin = highestPriorityScrollData.scrollPosition
				highestPriorityScrollData.pointerScrollActive = true
				highestPriorityScrollData.momentumTime = 0
			else
				if clip.horizontal then
					highestPriorityScrollData.scrollPosition.x = highestPriorityScrollData.scrollOrigin.x + (context.pointerInfo.position.x - highestPriorityScrollData.pointerOrigin.x)
				end
				if clip.vertical then
					highestPriorityScrollData.scrollPosition.y = highestPriorityScrollData.scrollOrigin.y + (context.pointerInfo.position.y - highestPriorityScrollData.pointerOrigin.y)
				end
				highestPriorityScrollData.momentumTime = highestPriorityScrollData.momentumTime + deltaTime
			end
		end

		-- Clamp
		local maxScrollX = -LLAY__MAX(highestPriorityScrollData.contentSize.width - scrollElement.dimensions.width, 0)
		local maxScrollY = -LLAY__MAX(highestPriorityScrollData.contentSize.height - scrollElement.dimensions.height, 0)
		highestPriorityScrollData.scrollPosition.x = LLAY__MAX(LLAY__MIN(highestPriorityScrollData.scrollPosition.x, 0), maxScrollX)
		highestPriorityScrollData.scrollPosition.y = LLAY__MAX(LLAY__MIN(highestPriorityScrollData.scrollPosition.y, 0), maxScrollY)

		-- Mark changed if wheel/drag/clamp modified position
		if highestPriorityScrollData.scrollPosition.x ~= beforeX or highestPriorityScrollData.scrollPosition.y ~= beforeY then
			changed = true
		end

		-- NaN guard (NaN is not equal to itself in Lua)
		if highestPriorityScrollData.scrollPosition.x ~= highestPriorityScrollData.scrollPosition.x then
			highestPriorityScrollData.scrollPosition.x = 0
			highestPriorityScrollData.scrollMomentum.x = 0
		end
		if highestPriorityScrollData.scrollPosition.y ~= highestPriorityScrollData.scrollPosition.y then
			highestPriorityScrollData.scrollPosition.y = 0
			highestPriorityScrollData.scrollMomentum.y = 0
		end
	end

		return changed
end

-- ==================================================================================
-- FLOATING & Z-SORT
-- ==================================================================================

function M.sort_roots_by_z()
	local count = context.layoutElementTreeRoots.length
	if count <= 1 then return end
	-- Stable Bubble Sort for small number of roots (common in UI)
	-- Sort ASCENDING (lower z first) so that lower z-index renders FIRST
	-- Rendering processes in array order, so last element (highest z) renders on top
	-- Front windows have LOWER z-index and render LAST (on top)
	local sorted = false
	while not sorted do
		sorted = true
		for i = 0, count - 2 do
			local current = context.layoutElementTreeRoots.internalArray[i]
			local next = context.layoutElementTreeRoots.internalArray[i+1]
			-- Use < for ascending sort (lower z first)
			if next.zIndex < current.zIndex then
				local tmp = ffi.new("Clay__LayoutElementTreeRoot", current)
				context.layoutElementTreeRoots.internalArray[i] = next
				context.layoutElementTreeRoots.internalArray[i+1] = tmp
				sorted = false
			end
		end
	end
end

-- Helper functions for public API
function M.open_text_element(text, textConfig)
	if context.layoutElements.length >= context.layoutElements.capacity - 1 then return end
	
	local parent = Llay__GetOpenLayoutElement()
	local elemIdx = context.layoutElements.length
	local elem = array_add(context.layoutElements, ffi.new("Clay_LayoutElement"))
	
	-- Zero memory to prevent garbage in elementConfigs.length
	ffi.fill(elem, ffi.sizeof("Clay_LayoutElement"))
	
	-- Hash ID based on parent + child index
	local elementId = Llay__HashNumber(parent.childrenOrTextContent.children.length + parent.floatingChildrenCount, parent.id)
	elem.id = elementId.id
	Llay__AddHashMapItem(elementId, elem)
	
	-- Set default layout config
	elem.layoutConfig = context.layoutConfigs.internalArray
	
	-- IMPORTANT: copy text config into arena so pointer is never dangling
	local storedCfg = Llay__StoreTextElementConfig(textConfig)
	if not storedCfg then return end
	
	-- FIX: Copy text content to arena
	-- Lua strings passed to FFI are not anchored. We must copy them to the arena.
	local charsPtr, len = Llay__AllocateStringInArena(text)
	
	-- Measure (pass the arena pointer)
	local clayString = ffi.new("Clay_String", { length = len, chars = charsPtr, isStaticallyAllocated = true })
	local measured = Llay__MeasureTextCached(clayString, storedCfg)
	
	elem.dimensions.width = measured.unwrappedDimensions.width
	elem.dimensions.height = (storedCfg.lineHeight > 0) and storedCfg.lineHeight or measured.unwrappedDimensions.height
	elem.minDimensions.width = measured.minWidth
	elem.minDimensions.height = elem.dimensions.height
	
	local textData = array_add(context.textElementData, ffi.new("Clay__TextElementData"))
	textData.text = clayString
	textData.preferredDimensions = measured.unwrappedDimensions
	textData.elementIndex = elemIdx
	elem.childrenOrTextContent.textElementData = textData
	
	-- Configs (store pointer to arena-owned config)
	local cfg = array_add(context.elementConfigs, ffi.new("Clay_ElementConfig"))
	cfg.type = Llay__ElementConfigType.TEXT
	cfg.config.textElementConfig = storedCfg
	
	elem.elementConfigs.internalArray = cfg
	elem.elementConfigs.length = 1
	
	-- Parent link
	parent.childrenOrTextContent.children.length = parent.childrenOrTextContent.children.length + 1
	int32_array_add(context.layoutElementChildrenBuffer, elemIdx)
end

function M.pointer_over(id)
	for i=0, context.pointerOverIds.length-1 do
		if context.pointerOverIds.internalArray[i].id == id then return true end
	end
	return false
end

function M.get_parent_element_id()
	if context.openLayoutElementStack.length < 1 then
		return 0
	end
	-- parent of the next element you're about to open is the *current* open element
	local parentIdx = context.openLayoutElementStack.internalArray[context.openLayoutElementStack.length - 1]
	return context.layoutElements.internalArray[parentIdx].id
end

function M.Llay__GetElementId(str)
	return Llay__HashString(str, 0)
end

function M.Llay__HashStringWithOffset(str, offset, seed)
	return Llay__HashStringWithOffset(str, offset, seed)
end

-- Internal functions for interaction API
function M._get_open_element()
	return Llay__GetOpenLayoutElement()
end

function M._get_hash_map_item(id)
	return Llay__GetHashMapItem(id)
end

-- Export enum constants
M.Llay_RenderCommandType = Llay_RenderCommandType
M.Llay__SizingType = Llay__SizingType
M.Llay_LayoutDirection = Llay_LayoutDirection
M.Llay_AlignX = Llay_AlignX
M.Llay_AlignY = Llay_AlignY
M.Llay__ElementConfigType = Llay__ElementConfigType
M.Llay_TextElementConfigWrapMode = Llay_TextElementConfigWrapMode
M.Llay_TextAlignment = Llay_TextAlignment
M.Llay_PointerDataInteractionState = Llay_PointerDataInteractionState
M.Llay_PointerCaptureMode = Llay_PointerCaptureMode
M.Llay_FloatingAttachToElement = Llay_FloatingAttachToElement

function M.set_max_element_count(count)
	if context then
		context.maxElementCount = count
	end
end

function M.set_culling_enabled(enabled)
	if context then
		context.disableCulling = not enabled
	end
end

function M.set_debug_mode_enabled(enabled)
	if context then
		context.debugModeEnabled = enabled
	end
end

function M.get_element_data(id)
	local item = Llay__GetHashMapItem(id)
	if item == nil then
		return { found = false, boundingBox = { x = 0, y = 0, width = 0, height = 0 } }
	end
	return {
		found = true,
		boundingBox = {
			x = item.boundingBox.x,
			y = item.boundingBox.y,
			width = item.boundingBox.width,
			height = item.boundingBox.height
		}
	}
end

function M.hovered()
	if context.booleanWarnings.maxElementsExceeded then return false end

	local openElement = Llay__GetOpenLayoutElement()
	if not openElement then return false end

	if openElement.id == 0 then
		Clay__GenerateIdForAnonymousElement(openElement)
	end

	for i = 0, context.pointerOverIds.length - 1 do
		if context.pointerOverIds.internalArray[i].id == openElement.id then
			return true
		end
	end
	return false
end

return M
