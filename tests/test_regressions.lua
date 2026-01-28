package.path = "./src/?.lua;" .. package.path

local ffi = require("ffi")
local llay = require("init")

local function assert_close(actual, expected, eps, label)
	eps = eps or 0.0001
	if math.abs(actual - expected) > eps then
		error(string.format("%s: expected %.4f, got %.4f", label or "value", expected, actual))
	end
end

local function find_text_cmd(commands, text)
	for i = 0, tonumber(commands.length) - 1 do
		local cmd = commands.internalArray[i]
		if cmd.commandType == llay._core.Llay_RenderCommandType.TEXT then
			local d = cmd.renderData.text
			local s = ffi.string(d.stringContents.chars, d.stringContents.length)
			if s == text then
				return cmd
			end
		end
	end
	return nil
end

local function run_text_bbox_regression()
	-- Fresh context so this test doesn't depend on earlier tests.
	llay.init(1024 * 1024 * 16)
	llay.set_dimensions(800, 600)
	llay.set_measure_text_function(function(text, config, userData)
		return { width = #text * 10, height = 20 }
	end)

	llay.begin_layout()
	llay.Element({
		layout = {
			sizing = { width = "GROW", height = "GROW" },
			layoutDirection = llay.LayoutDirection.TOP_TO_BOTTOM,
			padding = 0,
			childGap = 0,
		},
	}, function()
		llay.Text("Hello")
	end)
	local commands = llay.end_layout()

	local textCmd = find_text_cmd(commands, "Hello")
	assert(textCmd ~= nil, "expected to find TEXT render command for 'Hello'")

	-- Render command bbox is line-sized; the regression is that the *element* bbox
	-- in the hash map gets incorrectly blown up to the root layout config.
	local expectedW = 50
	local expectedH = 20
	assert_close(textCmd.boundingBox.width, expectedW, 0.001, "text render bbox width")
	assert_close(textCmd.boundingBox.height, expectedH, 0.001, "text render bbox height")

	local item = llay._core._get_hash_map_item(tonumber(textCmd.id))
	assert(item ~= nil, "expected hash map item for text element")
	assert_close(item.boundingBox.width, expectedW, 0.001, "text element bbox width")
	assert_close(item.boundingBox.height, expectedH, 0.001, "text element bbox height")
end

local function run_floating_root_offset_regression()
	llay.init(1024 * 1024 * 16)
	llay.set_dimensions(800, 600)
	llay.set_measure_text_function(function(text, config, userData)
		return { width = #text * 10, height = 20 }
	end)

	llay.begin_layout()
	llay.Element({
		layout = { sizing = { width = "GROW", height = "GROW" } },
	}, function()
		llay.Element({
			id = "FloatRoot",
			layout = { sizing = { width = 50, height = 40 } },
			backgroundColor = { 255, 0, 0, 255 },
			floating = {
				attachTo = llay.FloatingAttachToElement.ROOT,
				zIndex = 10,
				offset = { x = 123, y = 456 },
			},
		})
	end)
	local commands = llay.end_layout()

	local floatId = llay.ID("FloatRoot").id
	local item = llay._core._get_hash_map_item(floatId)
	assert(item ~= nil, "expected hash map item for FloatRoot")
	assert_close(item.boundingBox.x, 123, 0.001, "floating root bbox x")
	assert_close(item.boundingBox.y, 456, 0.001, "floating root bbox y")
end

local function run_pointer_over_bubbles_through_children_regression()
	llay.init(1024 * 1024 * 16)
	llay.set_dimensions(200, 100)
	llay.set_measure_text_function(function(text, config, userData)
		return { width = #text * 10, height = 20 }
	end)

	-- Build once to populate bounding boxes.
	llay.begin_layout()
	llay.Element({
		layout = {
			sizing = { width = "GROW", height = "GROW" },
			layoutDirection = llay.LayoutDirection.TOP_TO_BOTTOM,
			padding = 0,
		},
	}, function()
		llay.Element({
			id = "Box",
			layout = {
				sizing = { width = 100, height = 30 },
				padding = 0,
			},
		}, function()
			llay.Text("Hello")
		end)
	end)
	llay.end_layout()

	-- Pointer inside the child text should count as hovered on the parent element too.
	llay.set_pointer_state(5, 5, false)
	assert(llay.pointer_over("Box") == true, "expected pointer_over('Box') to be true when over child text")
end

local function run_scroll_offset_persists_and_moves_children_regression()
	llay.init(1024 * 1024 * 16)
	llay.set_dimensions(200, 200)
	llay.set_measure_text_function(function(text, config, userData)
		return { width = #text * 10, height = 20 }
	end)

	-- Frame 1: build a scroll container with overflowing content.
	llay.begin_layout()
	llay.Element({
		layout = {
			sizing = { width = "GROW", height = "GROW" },
			layoutDirection = llay.LayoutDirection.TOP_TO_BOTTOM,
			padding = 0,
		},
	}, function()
		llay.Element({
			id = "Scroll",
			layout = {
				sizing = { width = 100, height = 50 },
				layoutDirection = llay.LayoutDirection.TOP_TO_BOTTOM,
				padding = 0,
				childGap = 0,
			},
			clip = { vertical = true, horizontal = false },
		}, function()
			for _ = 1, 3 do
				llay.Element({
					layout = {
						sizing = { width = 100, height = 40 },
						padding = 0,
					},
					backgroundColor = { 255, 255, 255, 255 },
				})
			end
		end)
	end)
	llay.end_layout()

	-- Pointer inside the scroll container, wheel scroll down one notch.
	llay.set_pointer_state(10, 10, false)
	llay.update_scroll_containers(false, 0, -1, 1 / 60)

	-- Frame 2: query the scroll offset while the container is open.
	local observed = nil
	llay.begin_layout()
	llay.Element({
		layout = {
			sizing = { width = "GROW", height = "GROW" },
			layoutDirection = llay.LayoutDirection.TOP_TO_BOTTOM,
			padding = 0,
		},
	}, function()
		llay.Element({
			id = "Scroll",
			layout = {
				sizing = { width = 100, height = 50 },
				layoutDirection = llay.LayoutDirection.TOP_TO_BOTTOM,
				padding = 0,
				childGap = 0,
			},
			clip = { vertical = true, horizontal = false },
		}, function()
			observed = llay.get_scroll_offset()
		end)
	end)
	llay.end_layout()

	assert(observed ~= nil, "expected to read scroll offset while Scroll is open")
	assert_close(observed.y, -1, 0.001, "scroll offset y after wheel")
end

local function run_custom_element_render_callback_regression()
	llay.init(1024 * 1024 * 16)
	llay.set_dimensions(800, 600)
	llay.set_measure_text_function(function(text, config, userData)
		return { width = #text * 10, height = 20 }
	end)

	-- Track if callback was called
	local callback_called = false
	local received_rect = nil
	local received_painter = nil

	llay.begin_layout()
	llay.Element({
		layout = {
			sizing = { width = "GROW", height = "GROW" },
			padding = 0,
		},
	}, function()
		llay.Custom({
			id = "MyCustom",
			layout = { sizing = { width = 100, height = 50 } },
			backgroundColor = { 100, 150, 200, 255 },
			cornerRadius = 8,
		}, function(rect, painter)
			callback_called = true
			received_rect = rect
			received_painter = painter
		end)
	end)
	local commands = llay.end_layout()

	assert(callback_called == false, "callback should NOT be called during layout")

	-- Find the CUSTOM render command
	local customCmd = nil
	for i = 0, tonumber(commands.length) - 1 do
		local cmd = commands.internalArray[i]
		if cmd.commandType == llay._core.Llay_RenderCommandType.CUSTOM then
			customCmd = cmd
			break
		end
	end
	assert(customCmd ~= nil, "expected to find CUSTOM render command")

	-- Verify callback is retrievable
	local retrieved_callback = llay.get_render_callback(customCmd.id)
	assert(retrieved_callback ~= nil, "expected callback to be retrievable via id")

	-- Verify the callback is the one we passed
	assert(type(retrieved_callback) == "function", "retrieved callback should be a function")

	-- Verify layout dimensions
	assert_close(customCmd.boundingBox.x, 0, 0.001, "custom bbox x")
	assert_close(customCmd.boundingBox.y, 0, 0.001, "custom bbox y")
	assert_close(customCmd.boundingBox.width, 100, 0.001, "custom bbox width")
	assert_close(customCmd.boundingBox.height, 50, 0.001, "custom bbox height")

	-- Verify callbacks are cleared on next frame
	llay.begin_layout()
	llay.end_layout()
	local cleared_callback = llay.get_render_callback(customCmd.id)
	assert(cleared_callback == nil, "callback should be cleared after next begin_layout")
end

local function run_custom_element_multiple_ids_regression()
	llay.init(1024 * 1024 * 16)
	llay.set_dimensions(800, 600)
	llay.set_measure_text_function(function(text, config, userData)
		return { width = #text * 10, height = 20 }
	end)

	local callbacks = {}

	llay.begin_layout()
	llay.Element({
		layout = {
			sizing = { width = "GROW", height = "GROW" },
			padding = 0,
		},
	}, function()
		for i = 1, 3 do
			llay.Custom({
				id = "Custom_" .. i,
				layout = { sizing = { width = 30, height = 30 } },
			}, function() end)
			callbacks[i] = llay.get_render_callback(llay.ID("Custom_" .. i).id)
		end
	end)
	local commands = llay.end_layout()

	-- All callbacks should be retrievable
	for i = 1, 3 do
		assert(callbacks[i] ~= nil, "expected callback " .. i .. " to be retrievable")
	end

	-- Verify all CUSTOM commands are generated
	local customCount = 0
	for i = 0, tonumber(commands.length) - 1 do
		local cmd = commands.internalArray[i]
		if cmd.commandType == llay._core.Llay_RenderCommandType.CUSTOM then
			customCount = customCount + 1
		end
	end
	assert(customCount == 3, "expected 3 CUSTOM commands, got " .. customCount)
end

return {
	{
		name = "regression_text_element_bbox_matches_measured",
		fn = run_text_bbox_regression,
	},
	{
		name = "regression_floating_root_offset_applied",
		fn = run_floating_root_offset_regression,
	},
	{
		name = "regression_pointer_over_bubbles_through_children",
		fn = run_pointer_over_bubbles_through_children_regression,
	},
	{
		name = "regression_scroll_offset_persists_and_moves_children",
		fn = run_scroll_offset_persists_and_moves_children_regression,
	},
	{
		name = "regression_custom_element_render_callback",
		fn = run_custom_element_render_callback_regression,
	},
	{
		name = "regression_custom_element_multiple_ids",
		fn = run_custom_element_multiple_ids_regression,
	},
}
