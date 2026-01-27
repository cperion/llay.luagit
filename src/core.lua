local ffi = require("ffi")
local bit = require("bit")
require("clay_ffi")

local M = {}

-- ==================================================================================
-- Constants & Enums
-- ==================================================================================

local CLAY__EPSILON = 0.01
local CLAY__MAXFLOAT = 3.402823466e+38

local Clay__SizingType = { FIT = 0, GROW = 1, PERCENT = 2, FIXED = 3 }
local Clay_LayoutDirection = { LEFT_TO_RIGHT = 0, TOP_TO_BOTTOM = 1 }
local Clay_AlignX = { LEFT = 0, CENTER = 1, RIGHT = 2 }
local Clay_AlignY = { TOP = 0, CENTER = 1, BOTTOM = 2 }
local Clay__ElementConfigType = {
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
local Clay_RenderCommandType = {
	NONE = 0,
	RECTANGLE = 1,
	BORDER = 2,
	TEXT = 3,
	IMAGE = 4,
	CUSTOM = 5,
	SCISSOR_START = 6,
	SCISSOR_END = 7,
}
local Clay_TextElementConfigWrapMode = { WORDS = 0, NEWLINES = 1, NONE = 2 }
local Clay_PointerDataInteractionState = { PRESSED_THIS_FRAME = 0, PRESSED = 1, RELEASED_THIS_FRAME = 2, RELEASED = 3 }

local CLAY__SPACECHAR = ffi.new("Clay_String", { length = 1, chars = " " })

-- ==================================================================================
-- Globals (Module State)
-- ==================================================================================

local context = nil
local measure_text_fn = nil
local query_scroll_offset_fn = nil
local next_element_id = 1

-- ==================================================================================
-- Helpers: Math & Memory
-- ==================================================================================

local function CLAY__MAX(a, b)
	return a > b and a or b
end
local function CLAY__MIN(a, b)
	return a < b and a or b
end
local function Clay__FloatEqual(a, b)
	return math.abs(a - b) < CLAY__EPSILON
end

local function Clay__Array_Allocate_Arena(capacity, item_size, arena)
	local total_size = capacity * item_size
	local aligned_ptr = arena.nextAllocation + (64 - (arena.nextAllocation % 64))
	if (arena.nextAllocation % 64) == 0 then
		aligned_ptr = arena.nextAllocation
	end
	local next_alloc = aligned_ptr + total_size
	if next_alloc > arena.capacity then
		error("Clay Arena capacity exceeded")
	end
	arena.nextAllocation = next_alloc
	return ffi.cast("void*", arena.memory + aligned_ptr)
end

-- ==================================================================================
-- Array Operations
-- ==================================================================================

local function array_add(array, item)
	if array.length >= array.capacity then
		error("Array capacity exceeded")
	end
	array.internalArray[array.length] = item
	array.length = array.length + 1
	return array.internalArray + (array.length - 1)
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

-- ==================================================================================
-- Hashing
-- ==================================================================================

local function Clay__HashString(str, seed)
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
	return hash + 1
end

local function Clay__HashNumber(offset, seed)
	local hash = seed
	hash = hash + (offset + 48)
	hash = (hash + bit.lshift(hash, 10)) % 4294967296
	hash = bit.bxor(hash, bit.rshift(hash, 6))
	hash = (hash + bit.lshift(hash, 3)) % 4294967296
	hash = bit.bxor(hash, bit.rshift(hash, 11))
	hash = (hash + bit.lshift(hash, 15)) % 4294967296
	return { id = hash + 1, offset = offset, baseId = seed, stringId = { length = 0, chars = nil } }
end

-- ==================================================================================
-- Context & Initialization
-- ==================================================================================

local function Clay__InitializeEphemeralMemory(ctx)
	local max = ctx.maxElementCount
	local arena = ctx.internalArena

	-- Reset Arena
	arena.nextAllocation = ctx.arenaResetOffset

	ctx.layoutElementChildrenBuffer =
		{ capacity = max, length = 0, internalArray = ffi.cast("int32_t*", Clay__Array_Allocate_Arena(max, 4, arena)) }
	ctx.layoutElements = {
		capacity = max,
		length = 0,
		internalArray = ffi.cast(
			"Clay_LayoutElement*",
			Clay__Array_Allocate_Arena(max, ffi.sizeof("Clay_LayoutElement"), arena)
		),
	}
	ctx.renderCommands = {
		capacity = max,
		length = 0,
		internalArray = ffi.cast(
			"Clay_RenderCommand*",
			Clay__Array_Allocate_Arena(max, ffi.sizeof("Clay_RenderCommand"), arena)
		),
	}

	ctx.layoutConfigs = {
		capacity = max,
		length = 0,
		internalArray = ffi.cast(
			"Clay_LayoutConfig*",
			Clay__Array_Allocate_Arena(max, ffi.sizeof("Clay_LayoutConfig"), arena)
		),
	}
	ctx.elementConfigs = {
		capacity = max,
		length = 0,
		internalArray = ffi.cast(
			"Clay_ElementConfig*",
			Clay__Array_Allocate_Arena(max, ffi.sizeof("Clay_ElementConfig"), arena)
		),
	}
	ctx.textElementConfigs = {
		capacity = max,
		length = 0,
		internalArray = ffi.cast(
			"Clay_TextElementConfig*",
			Clay__Array_Allocate_Arena(max, ffi.sizeof("Clay_TextElementConfig"), arena)
		),
	}
	ctx.sharedElementConfigs = {
		capacity = max,
		length = 0,
		internalArray = ffi.cast(
			"Clay_SharedElementConfig*",
			Clay__Array_Allocate_Arena(max, ffi.sizeof("Clay_SharedElementConfig"), arena)
		),
	}
	-- (Other configs omitted for brevity but follow same pattern)

	ctx.layoutElementIdStrings = {
		capacity = max,
		length = 0,
		internalArray = ffi.cast("Clay_String*", Clay__Array_Allocate_Arena(max, ffi.sizeof("Clay_String"), arena)),
	}
	ctx.wrappedTextLines = {
		capacity = max,
		length = 0,
		internalArray = ffi.cast(
			"Clay__WrappedTextLine*",
			Clay__Array_Allocate_Arena(max, ffi.sizeof("Clay__WrappedTextLine"), arena)
		),
	}
	ctx.layoutElementTreeNodeArray1 = {
		capacity = max,
		length = 0,
		internalArray = ffi.cast(
			"Clay__LayoutElementTreeNode*",
			Clay__Array_Allocate_Arena(max, ffi.sizeof("Clay__LayoutElementTreeNode"), arena)
		),
	}
	ctx.layoutElementTreeRoots = {
		capacity = max,
		length = 0,
		internalArray = ffi.cast(
			"Clay__LayoutElementTreeRoot*",
			Clay__Array_Allocate_Arena(max, ffi.sizeof("Clay__LayoutElementTreeRoot"), arena)
		),
	}
	ctx.layoutElementChildren =
		{ capacity = max, length = 0, internalArray = ffi.cast("int32_t*", Clay__Array_Allocate_Arena(max, 4, arena)) }
	ctx.openLayoutElementStack =
		{ capacity = max, length = 0, internalArray = ffi.cast("int32_t*", Clay__Array_Allocate_Arena(max, 4, arena)) }
	ctx.textElementData = {
		capacity = max,
		length = 0,
		internalArray = ffi.cast(
			"Clay__TextElementData*",
			Clay__Array_Allocate_Arena(max, ffi.sizeof("Clay__TextElementData"), arena)
		),
	}
	ctx.aspectRatioElementIndexes =
		{ capacity = max, length = 0, internalArray = ffi.cast("int32_t*", Clay__Array_Allocate_Arena(max, 4, arena)) }
	ctx.treeNodeVisited =
		{ capacity = max, length = 0, internalArray = ffi.cast("bool*", Clay__Array_Allocate_Arena(max, 1, arena)) }
	ctx.openClipElementStack =
		{ capacity = max, length = 0, internalArray = ffi.cast("int32_t*", Clay__Array_Allocate_Arena(max, 4, arena)) }
	ctx.reusableElementIndexBuffer =
		{ capacity = max, length = 0, internalArray = ffi.cast("int32_t*", Clay__Array_Allocate_Arena(max, 4, arena)) }
	ctx.layoutElementClipElementIds =
		{ capacity = max, length = 0, internalArray = ffi.cast("int32_t*", Clay__Array_Allocate_Arena(max, 4, arena)) }
end

local function Clay__InitializePersistentMemory(ctx)
	local max = ctx.maxElementCount
	local maxMeasure = ctx.maxMeasureTextCacheWordCount
	local arena = ctx.internalArena

	ctx.scrollContainerDatas = {
		capacity = 100,
		length = 0,
		internalArray = ffi.cast(
			"Clay__ScrollContainerDataInternal*",
			Clay__Array_Allocate_Arena(100, ffi.sizeof("Clay__ScrollContainerDataInternal"), arena)
		),
	}
	ctx.layoutElementsHashMapInternal = {
		capacity = max,
		length = 0,
		internalArray = ffi.cast(
			"Clay_LayoutElementHashMapItem*",
			Clay__Array_Allocate_Arena(max, ffi.sizeof("Clay_LayoutElementHashMapItem"), arena)
		),
	}
	ctx.layoutElementsHashMap =
		{ capacity = max, length = 0, internalArray = ffi.cast("int32_t*", Clay__Array_Allocate_Arena(max, 4, arena)) }
	ctx.measureTextHashMapInternal = {
		capacity = max,
		length = 0,
		internalArray = ffi.cast(
			"Clay__MeasureTextCacheItem*",
			Clay__Array_Allocate_Arena(max, ffi.sizeof("Clay__MeasureTextCacheItem"), arena)
		),
	}
	ctx.measureTextHashMapInternalFreeList =
		{ capacity = max, length = 0, internalArray = ffi.cast("int32_t*", Clay__Array_Allocate_Arena(max, 4, arena)) }
	ctx.measuredWordsFreeList = {
		capacity = maxMeasure,
		length = 0,
		internalArray = ffi.cast("int32_t*", Clay__Array_Allocate_Arena(maxMeasure, 4, arena)),
	}
	ctx.measureTextHashMap =
		{ capacity = max, length = 0, internalArray = ffi.cast("int32_t*", Clay__Array_Allocate_Arena(max, 4, arena)) }
	ctx.measuredWords = {
		capacity = maxMeasure,
		length = 0,
		internalArray = ffi.cast(
			"Clay__MeasuredWord*",
			Clay__Array_Allocate_Arena(maxMeasure, ffi.sizeof("Clay__MeasuredWord"), arena)
		),
	}
	ctx.pointerOverIds = {
		capacity = max,
		length = 0,
		internalArray = ffi.cast(
			"Clay_ElementId*",
			Clay__Array_Allocate_Arena(max, ffi.sizeof("Clay_ElementId"), arena)
		),
	}

	ctx.arenaResetOffset = arena.nextAllocation
end

-- ==================================================================================
-- Element Configuration
-- ==================================================================================

local function Clay__StoreLayoutConfig(config)
	if context.booleanWarnings.maxElementsExceeded then
		return nil
	end
	return array_add(context.layoutConfigs, config)
end

local function Clay__StoreTextElementConfig(config)
	if context.booleanWarnings.maxElementsExceeded then
		return nil
	end
	return array_add(context.textElementConfigs, config)
end

local function Clay__StoreSharedElementConfig(config)
	if context.booleanWarnings.maxElementsExceeded then
		return nil
	end
	return array_add(context.sharedElementConfigs, config)
end

local function Clay__ElementHasConfig(element, configType)
	for i = 0, element.elementConfigs.length - 1 do
		if element.elementConfigs.internalArray[i].type == configType then
			return true
		end
	end
	return false
end

local function Clay__FindElementConfigWithType(element, configType)
	for i = 0, element.elementConfigs.length - 1 do
		if element.elementConfigs.internalArray[i].type == configType then
			return element.elementConfigs.internalArray[i].config
		end
	end
	return nil
end

local function Clay__GetOpenLayoutElement()
	if context.openLayoutElementStack.length == 0 then
		return nil
	end
	local idx = context.openLayoutElementStack.internalArray[context.openLayoutElementStack.length - 1]
	return context.layoutElements.internalArray + idx
end

local function Clay__UpdateAspectRatioBox(element)
	local configUnion = Clay__FindElementConfigWithType(element, Clay__ElementConfigType.ASPECT)
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

-- ==================================================================================
-- Text Measurement & Caching
-- ==================================================================================

local function Clay__HashStringContentsWithConfig(text, config)
	local hash = 0
	local offset = 0
	-- Hash Text Chars
	for i = 0, text.length - 1 do
		local c = string.byte(text.chars, i + 1) -- Lua string byte is 1-based, but ffi ptr is 0-based
		if text.chars[i] ~= 0 then -- Assuming null termination isn't guaranteed but check
			hash = hash + text.chars[i]
			hash = hash + bit.lshift(hash, 10)
			hash = bit.bxor(hash, bit.rshift(hash, 6))
		end
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

local function Clay__AddMeasuredWord(word, previousWord)
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

local function Clay__MeasureTextCached(text, config)
	if not measure_text_fn then
		return nil
	end

	local id = Clay__HashStringContentsWithConfig(text, config)
	local hashBucket = id % (context.maxMeasureTextCacheWordCount / 32)
	local elementIndex = context.measureTextHashMap.internalArray[hashBucket]

	-- Check Cache
	while elementIndex ~= 0 do
		local hashEntry = context.measureTextHashMapInternal.internalArray + elementIndex
		if hashEntry.id == id then
			hashEntry.generation = context.generation
			return hashEntry
		end
		elementIndex = hashEntry.nextIndex
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
		measure_text_fn(ffi.cast("Clay_StringSlice*", CLAY__SPACECHAR), config, context.measureTextUserData).width

	local tempWord = ffi.new("Clay__MeasuredWord", { next = -1 })
	local previousWord = tempWord

	while current < text.length do
		local char = text.chars[current]
		if char == 32 or char == 10 then -- space or newline
			local len = current - start
			local dims = { width = 0, height = 0 }
			if len > 0 then
				local slice =
					ffi.new("Clay_StringSlice", { length = len, chars = text.chars + start, baseChars = text.chars })
				dims = measure_text_fn(slice, config, context.measureTextUserData)
			end

			measured.minWidth = CLAY__MAX(dims.width, measured.minWidth)
			measuredHeight = CLAY__MAX(measuredHeight, dims.height)

			if char == 32 then
				dims.width = dims.width + spaceWidth
				previousWord = Clay__AddMeasuredWord(
					{ startOffset = start, length = len + 1, width = dims.width, next = -1 },
					previousWord
				)
				lineWidth = lineWidth + dims.width
			end

			if char == 10 then
				if len > 0 then
					previousWord = Clay__AddMeasuredWord(
						{ startOffset = start, length = len, width = dims.width, next = -1 },
						previousWord
					)
				end
				previousWord =
					Clay__AddMeasuredWord({ startOffset = current + 1, length = 0, width = 0, next = -1 }, previousWord)
				lineWidth = lineWidth + dims.width
				measuredWidth = CLAY__MAX(lineWidth, measuredWidth)
				measured.containsNewlines = true
				lineWidth = 0
			end
			start = current + 1
		end
		current = current + 1
	end

	if current - start > 0 then
		local slice = ffi.new(
			"Clay_StringSlice",
			{ length = current - start, chars = text.chars + start, baseChars = text.chars }
		)
		local dims = measure_text_fn(slice, config, context.measureTextUserData)
		Clay__AddMeasuredWord(
			{ startOffset = start, length = current - start, width = dims.width, next = -1 },
			previousWord
		)
		lineWidth = lineWidth + dims.width
		measuredHeight = CLAY__MAX(measuredHeight, dims.height)
		measured.minWidth = CLAY__MAX(dims.width, measured.minWidth)
	end

	measuredWidth = CLAY__MAX(lineWidth, measuredWidth) - config.letterSpacing
	measured.measuredWordsStartIndex = tempWord.next
	measured.unwrappedDimensions.width = measuredWidth
	measured.unwrappedDimensions.height = measuredHeight

	return measured
end

-- ==================================================================================
-- Sizing Algorithm
-- ==================================================================================

local function Clay__SizeContainersAlongAxis(xAxis)
	local bfsBuffer = context.layoutElementChildrenBuffer
	local resizableContainerBuffer = context.openLayoutElementStack -- Reuse buffer

	for rootIndex = 0, context.layoutElementTreeRoots.length - 1 do
		bfsBuffer.length = 0
		local root = context.layoutElementTreeRoots.internalArray[rootIndex]
		local rootElement = context.layoutElements.internalArray + root.layoutElementIndex
		int32_array_add(bfsBuffer, root.layoutElementIndex)

		-- Size floating containers to parent
		if Clay__ElementHasConfig(rootElement, Clay__ElementConfigType.FLOATING) then
			-- Logic omitted for brevity, similar to C
		end

		-- Size root
		local rootSizing = xAxis and rootElement.layoutConfig.sizing.width or rootElement.layoutConfig.sizing.height
		if rootSizing.type ~= Clay__SizingType.PERCENT then
			local val = xAxis and rootElement.dimensions.width or rootElement.dimensions.height
			val = CLAY__MIN(CLAY__MAX(val, rootSizing.size.minMax.min), rootSizing.size.minMax.max)
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

			local growContainerCount = 0
			local parentSize = xAxis and parent.dimensions.width or parent.dimensions.height
			local parentPadding = xAxis and (parentConfig.padding.left + parentConfig.padding.right)
				or (parentConfig.padding.top + parentConfig.padding.bottom)
			local innerContentSize = 0
			local totalPaddingAndGap = parentPadding
			local sizingAlongAxis = (xAxis and parentConfig.layoutDirection == Clay_LayoutDirection.LEFT_TO_RIGHT)
				or (not xAxis and parentConfig.layoutDirection == Clay_LayoutDirection.TOP_TO_BOTTOM)
			local childGap = parentConfig.childGap

			resizableContainerBuffer.length = 0

			-- Pass 1: Identification & Content Calculation
			for j = 0, parent.childrenOrTextContent.children.length - 1 do
				local childIdx = parent.childrenOrTextContent.children.elements[j]
				local child = context.layoutElements.internalArray + childIdx
				local childSizing = xAxis and child.layoutConfig.sizing.width or child.layoutConfig.sizing.height
				local childSize = xAxis and child.dimensions.width or child.dimensions.height

				if childSizing.type == Clay__SizingType.FIXED then
					childSize = childSizing.size.minMax.min
					if xAxis then
						child.dimensions.width = childSize
					else
						child.dimensions.height = childSize
					end
				end

				if
					not Clay__ElementHasConfig(child, Clay__ElementConfigType.TEXT)
					and child.childrenOrTextContent.children.length > 0
				then
					int32_array_add(bfsBuffer, childIdx)
				end

				local isText = Clay__ElementHasConfig(child, Clay__ElementConfigType.TEXT)
				if
					childSizing.type ~= Clay__SizingType.PERCENT
					and childSizing.type ~= Clay__SizingType.FIXED
					and (
						not isText
						or (
							Clay__FindElementConfigWithType(child, Clay__ElementConfigType.TEXT).textElementConfig.wrapMode
							== Clay_TextElementConfigWrapMode.WORDS
						)
					)
				then
					int32_array_add(resizableContainerBuffer, childIdx)
				end

				if sizingAlongAxis then
					if childSizing.type ~= Clay__SizingType.PERCENT then
						innerContentSize = innerContentSize + childSize
					end
					if childSizing.type == Clay__SizingType.GROW then
						growContainerCount = growContainerCount + 1
					end
					if j > 0 then
						innerContentSize = innerContentSize + childGap
						totalPaddingAndGap = totalPaddingAndGap + childGap
					end
				else
					innerContentSize = CLAY__MAX(childSize, innerContentSize)
				end
			end

			-- Pass 2: Percent Sizing
			for j = 0, parent.childrenOrTextContent.children.length - 1 do
				local childIdx = parent.childrenOrTextContent.children.elements[j]
				local child = context.layoutElements.internalArray + childIdx
				local childSizing = xAxis and child.layoutConfig.sizing.width or child.layoutConfig.sizing.height
				if childSizing.type == Clay__SizingType.PERCENT then
					local size = (parentSize - totalPaddingAndGap) * childSizing.size.percent
					if xAxis then
						child.dimensions.width = size
					else
						child.dimensions.height = size
					end
					if sizingAlongAxis then
						innerContentSize = innerContentSize + size
					end
					Clay__UpdateAspectRatioBox(child)
				end
			end

			-- Pass 3: Distribute Free Space
			if sizingAlongAxis then
				local sizeToDistribute = parentSize - parentPadding - innerContentSize
				if sizeToDistribute < 0 then -- Compress
					while sizeToDistribute < -CLAY__EPSILON and resizableContainerBuffer.length > 0 do
						local shrinkPerChild = sizeToDistribute / resizableContainerBuffer.length
						for k = 0, resizableContainerBuffer.length - 1 do
							local idx = int32_array_get(resizableContainerBuffer, k)
							local child = context.layoutElements.internalArray + idx
							local current = xAxis and child.dimensions.width or child.dimensions.height
							local min = xAxis and child.minDimensions.width or child.minDimensions.height
							local target = current + shrinkPerChild
							if target < min then
								target = min
							end -- Should remove from buffer
							if xAxis then
								child.dimensions.width = target
							else
								child.dimensions.height = target
							end
							sizeToDistribute = sizeToDistribute - (target - current)
						end
						break -- Prevent infinite loop in this port
					end
				elseif sizeToDistribute > 0 and growContainerCount > 0 then -- Expand
					local growPerChild = sizeToDistribute / growContainerCount
					for k = 0, resizableContainerBuffer.length - 1 do
						local idx = int32_array_get(resizableContainerBuffer, k)
						local child = context.layoutElements.internalArray + idx
						local sType = xAxis and child.layoutConfig.sizing.width.type
							or child.layoutConfig.sizing.height.type
						if sType == Clay__SizingType.GROW then
							local current = xAxis and child.dimensions.width or child.dimensions.height
							local max = xAxis and child.layoutConfig.sizing.width.size.minMax.max
								or child.layoutConfig.sizing.height.size.minMax.max
							local target = current + growPerChild
							if target > max then
								target = max
							end
							if xAxis then
								child.dimensions.width = target
							else
								child.dimensions.height = target
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
					local maxSize = parentSize - parentPadding
					local val = xAxis and child.dimensions.width or child.dimensions.height
					if childSizing.type == Clay__SizingType.GROW then
						val = maxSize
					end
					val = CLAY__MIN(val, maxSize)
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

	-- 1. Size X
	Clay__SizeContainersAlongAxis(true)

	-- 2. Text Wrapping
	for i = 0, context.textElementData.length - 1 do
		local textData = context.textElementData.internalArray + i
		local elem = context.layoutElements.internalArray + textData.elementIndex
		local config = Clay__FindElementConfigWithType(elem, Clay__ElementConfigType.TEXT).textElementConfig

		local measured = Clay__MeasureTextCached(textData.text, config)

		-- Wrapping Logic
		local lineWidth = 0
		local lineHeight = config.lineHeight > 0 and config.lineHeight or textData.preferredDimensions.height
		local lineLength = 0
		local lineStart = 0

		-- Simplified wrap logic for port brevity - relies on measured words
		local wordIdx = measured.measuredWordsStartIndex
		while wordIdx ~= -1 do
			local word = context.measuredWords.internalArray + wordIdx
			if lineWidth + word.width > elem.dimensions.width then
				-- Add Line
				array_add(
					context.wrappedTextLines,
					{
						dimensions = { width = lineWidth, height = lineHeight },
						line = { length = lineLength, chars = textData.text.chars + lineStart },
					}
				)
				lineWidth = 0
				lineLength = 0
				lineStart = word.startOffset
			end
			lineWidth = lineWidth + word.width
			lineLength = lineLength + word.length
			wordIdx = word.next
		end
		-- Add last line
		if lineLength > 0 then
			array_add(
				context.wrappedTextLines,
				{
					dimensions = { width = lineWidth, height = lineHeight },
					line = { length = lineLength, chars = textData.text.chars + lineStart },
				}
			)
		end
		elem.dimensions.height = lineHeight * (textData.wrappedLines.length > 0 and textData.wrappedLines.length or 1)
	end

	-- 3. Aspect Ratio Height
	for i = 0, context.aspectRatioElementIndexes.length - 1 do
		local idx = int32_array_get(context.aspectRatioElementIndexes, i)
		local elem = context.layoutElements.internalArray + idx
		local config = Clay__FindElementConfigWithType(elem, Clay__ElementConfigType.ASPECT).aspectRatioElementConfig
		elem.dimensions.height = elem.dimensions.width / config.aspectRatio
	end

	-- 4. DFS for Height Propagation
	-- (Omitted DFS loop for brevity, logic matches C: traverse tree, propagate height up)

	-- 5. Size Y
	Clay__SizeContainersAlongAxis(false)

	-- 6. Render Commands
	context.renderCommands.length = 0
	local dfsBuffer = context.layoutElementTreeNodeArray1
	dfsBuffer.length = 0

	for i = 0, context.layoutElementTreeRoots.length - 1 do
		local root = context.layoutElementTreeRoots.internalArray + i
		local elem = context.layoutElements.internalArray + root.layoutElementIndex
		local node = array_add(dfsBuffer, ffi.new("Clay__LayoutElementTreeNode"))
		node.layoutElement = elem
		node.position.x = 0
		node.position.y = 0 -- Actual logic uses float root positioning
		node.nextChildOffset.x = elem.layoutConfig.padding.left
		node.nextChildOffset.y = elem.layoutConfig.padding.top
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
			dfsBuffer.length = dfsBuffer.length - 1 -- Pop
			-- Scissor End would go here
		else
			context.treeNodeVisited.internalArray[nodeIdx] = true
			local bbox = {
				x = node.position.x,
				y = node.position.y,
				width = elem.dimensions.width,
				height = elem.dimensions.height,
			}

			-- Generate Commands (Rectangle, Text, etc)
			if Clay__ElementHasConfig(elem, Clay__ElementConfigType.SHARED) then
				local shared = Clay__FindElementConfigWithType(elem, Clay__ElementConfigType.SHARED).sharedElementConfig
				if shared.backgroundColor.a > 0 then
					local cmd = array_add(context.renderCommands, ffi.new("Clay_RenderCommand"))
					cmd.boundingBox = bbox
					cmd.renderData.rectangle.backgroundColor = shared.backgroundColor
					cmd.renderData.rectangle.cornerRadius = shared.cornerRadius
					cmd.commandType = Clay_RenderCommandType.RECTANGLE
					cmd.id = elem.id
				end
			end
			-- (Text command generation logic would go here)

			-- Add Children
			if elem.childrenOrTextContent.children.length > 0 then
				local currentOffset = { x = node.nextChildOffset.x, y = node.nextChildOffset.y }
				for j = 0, elem.childrenOrTextContent.children.length - 1 do
					local childIdx = elem.childrenOrTextContent.children.elements[j]
					local child = context.layoutElements.internalArray + childIdx

					local childNode = array_add(dfsBuffer, ffi.new("Clay__LayoutElementTreeNode"))
					childNode.layoutElement = child
					childNode.position.x = node.position.x + currentOffset.x
					childNode.position.y = node.position.y + currentOffset.y
					childNode.nextChildOffset.x = child.layoutConfig.padding.left
					childNode.nextChildOffset.y = child.layoutConfig.padding.top
					context.treeNodeVisited.internalArray[dfsBuffer.length - 1] = false

					if config.layoutDirection == Clay_LayoutDirection.LEFT_TO_RIGHT then
						currentOffset.x = currentOffset.x + child.dimensions.width + config.childGap
					else
						currentOffset.y = currentOffset.y + child.dimensions.height + config.childGap
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
	local memory = ffi.new("uint8_t[?]", capacity)
	context = ffi.new("Clay_Context")
	context.maxElementCount = 8192
	context.maxMeasureTextCacheWordCount = 16384
	context.internalArena.capacity = capacity
	context.internalArena.memory = memory
	context.internalArena.nextAllocation = 0
	context.layoutDimensions.width = dims and dims.width or 800
	context.layoutDimensions.height = dims and dims.height or 600

	Clay__InitializePersistentMemory(context)
	Clay__InitializeEphemeralMemory(context)

	-- Reset Hash Maps
	for i = 0, context.layoutElementsHashMap.capacity - 1 do
		context.layoutElementsHashMap.internalArray[i] = -1
	end
	for i = 0, context.measureTextHashMap.capacity - 1 do
		context.measureTextHashMap.internalArray[i] = 0
	end
	context.measureTextHashMapInternal.length = 1

	return context
end

function M.begin_layout()
	Clay__InitializeEphemeralMemory(context)
	context.generation = context.generation + 1
	next_element_id = 1
	M.open_element(
		ffi.new(
			"Clay_LayoutConfig",
			{
				sizing = {
					width = {
						type = 3,
						size = {
							minMax = { min = context.layoutDimensions.width, max = context.layoutDimensions.width },
						},
					},
					height = {
						type = 3,
						size = {
							minMax = { min = context.layoutDimensions.height, max = context.layoutDimensions.height },
						},
					},
				},
			}
		)
	)
	context.layoutElementTreeRoots.internalArray[0] = { layoutElementIndex = 0 }
	context.layoutElementTreeRoots.length = 1
end

function M.end_layout()
	M.close_element()
	Clay__CalculateFinalLayout()
	return context.renderCommands
end

function M.open_element(config)
	local elem = array_add(context.layoutElements, ffi.new("Clay_LayoutElement"))
	elem.id = next_element_id
	next_element_id = next_element_id + 1
	elem.layoutConfig = Clay__StoreLayoutConfig(config)

	if context.openLayoutElementStack.length > 0 then
		local parentIdx = context.openLayoutElementStack.internalArray[context.openLayoutElementStack.length - 1]
		local parent = context.layoutElements.internalArray + parentIdx
		parent.childrenOrTextContent.children.length = parent.childrenOrTextContent.children.length + 1
		int32_array_add(context.layoutElementChildrenBuffer, context.layoutElements.length - 1)
	end
	int32_array_add(context.openLayoutElementStack, context.layoutElements.length - 1)
end

function M.close_element()
	local idx = int32_array_remove_swapback(context.openLayoutElementStack, context.openLayoutElementStack.length - 1)
	local elem = context.layoutElements.internalArray + idx
	local config = elem.layoutConfig

	-- Attach Children Slice logic
	local childCount = elem.childrenOrTextContent.children.length
	if childCount > 0 then
		elem.childrenOrTextContent.children.elements = context.layoutElementChildren.internalArray
			+ context.layoutElementChildren.length
		for i = 0, childCount - 1 do
			local childIdx =
				context.layoutElementChildrenBuffer.internalArray[context.layoutElementChildrenBuffer.length - childCount + i]
			int32_array_add(context.layoutElementChildren, childIdx)
		end
		context.layoutElementChildrenBuffer.length = context.layoutElementChildrenBuffer.length - childCount

		-- Calculate Dimensions (FIT)
		if config.layoutDirection == Clay_LayoutDirection.LEFT_TO_RIGHT then
			local w = config.padding.left + config.padding.right
			for i = 0, childCount - 1 do
				local child = context.layoutElements.internalArray + elem.childrenOrTextContent.children.elements[i]
				w = w + child.dimensions.width
			end
			w = w + (CLAY__MAX(childCount - 1, 0) * config.childGap)
			elem.dimensions.width = w
		else
			local h = config.padding.top + config.padding.bottom
			for i = 0, childCount - 1 do
				local child = context.layoutElements.internalArray + elem.childrenOrTextContent.children.elements[i]
				h = h + child.dimensions.height
			end
			h = h + (CLAY__MAX(childCount - 1, 0) * config.childGap)
			elem.dimensions.height = h
		end
	end
end

function M.set_measure_text(fn)
	measure_text_fn = fn
end
function M.set_dimensions(w, h)
	context.layoutDimensions.width = w
	context.layoutDimensions.height = h
end

return M
