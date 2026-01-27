local clay = require("init") -- Uses the public API

local layouts = {}

-- A simple row with two fixed-size rectangles
layouts.simple_row = function()
	clay.set_dimensions(800, 600)
	clay.begin_layout()

	clay.Element({
		layout = {
			sizing = { width = "GROW", height = "GROW" },
			layoutDirection = clay.LayoutDirection.LEFT_TO_RIGHT,
			padding = { 0, 0, 0, 0 },
			childGap = 0,
		},
		backgroundColor = { 255, 255, 255, 255 },
	}, function()
		clay.Element({
			layout = {
				sizing = { width = 100, height = 50 },
			},
			backgroundColor = { 255, 0, 0, 255 },
		})

		clay.Element({
			layout = {
				sizing = { width = 200, height = 50 },
			},
			backgroundColor = { 0, 255, 0, 255 },
		})
	end)

	return clay.end_layout()
end

-- Nested containers: Root > Child (padded) > Grandchild
layouts.nested_containers = function()
	clay.set_dimensions(800, 600)
	clay.begin_layout()
	clay.Element({
		layout = {
			sizing = { width = "GROW", height = "GROW" },
			layoutDirection = clay.LayoutDirection.TOP_TO_BOTTOM,
			padding = { 0, 0, 0, 0 },
		},
		backgroundColor = { 255, 255, 255, 255 },
	}, function()
		clay.Element({
			layout = {
				sizing = { width = 100, height = 100 },
				padding = { 10, 10, 10, 10 },
			},
			backgroundColor = { 255, 0, 0, 255 },
		}, function()
			clay.Element({
				layout = { sizing = { width = 50, height = 50 } },
				backgroundColor = { 0, 255, 0, 255 },
			})
		end)
	end)
	return clay.end_layout()
end

-- Alignment: Center child in 800x600 container
layouts.alignment_center = function()
	clay.set_dimensions(800, 600)
	clay.begin_layout()
	clay.Element({
		layout = {
			sizing = { width = "GROW", height = "GROW" },
			layoutDirection = clay.LayoutDirection.LEFT_TO_RIGHT,
			childAlignment = { clay.AlignX.CENTER, clay.AlignY.CENTER },
		},
		backgroundColor = { 255, 255, 255, 255 },
	}, function()
		clay.Element({
			layout = { sizing = { width = 100, height = 100 } },
			backgroundColor = { 0, 0, 255, 255 },
		})
	end)
	return clay.end_layout()
end

-- Sizing modes: FIXED, GROW, PERCENT
layouts.sizing_modes = function()
	clay.set_dimensions(800, 600)
	clay.begin_layout()
	clay.Element({
		layout = {
			sizing = { width = "GROW", height = "GROW" },
			layoutDirection = clay.LayoutDirection.LEFT_TO_RIGHT,
			padding = { 0, 0, 0, 0 },
		},
		backgroundColor = { 255, 255, 255, 255 },
	}, function()
		clay.Element({
			layout = { sizing = { width = 100, height = 100 } },
			backgroundColor = { 255, 0, 0, 255 },
		})

		clay.Element({
			layout = { sizing = { width = "GROW", height = "GROW" } },
			backgroundColor = { 0, 255, 0, 255 },
		})

		clay.Element({
			layout = {
				sizing = {
					width = { percent = 0.5 },
					height = 100,
				},
			},
			backgroundColor = { 0, 0, 255, 255 },
		})
	end)
	return clay.end_layout()
end

-- Child gap: spacing between children
layouts.child_gap = function()
	clay.set_dimensions(800, 600)
	clay.begin_layout()
	clay.Element({
		layout = {
			sizing = { width = "GROW", height = "GROW" },
			layoutDirection = clay.LayoutDirection.LEFT_TO_RIGHT,
			padding = { 0, 0, 0, 0 },
			childGap = 20,
		},
		backgroundColor = { 255, 255, 255, 255 },
	}, function()
		clay.Element({
			layout = { sizing = { width = 100, height = 100 } },
			backgroundColor = { 255, 0, 0, 255 },
		})

		clay.Element({
			layout = { sizing = { width = 150, height = 100 } },
			backgroundColor = { 0, 255, 0, 255 },
		})

		clay.Element({
			layout = { sizing = { width = 200, height = 100 } },
			backgroundColor = { 0, 0, 255, 255 },
		})
	end)
	return clay.end_layout()
end

-- Corners and borders: rounded rectangles with borders
layouts.corners_borders = function()
	clay.set_dimensions(800, 600)
	clay.begin_layout()
	clay.Element({
		layout = {
			sizing = { width = "GROW", height = "GROW" },
			layoutDirection = clay.LayoutDirection.LEFT_TO_RIGHT,
			padding = { 50, 50, 50, 50 },
		},
		backgroundColor = { 255, 255, 255, 255 },
	}, function()
		clay.Element({
			layout = { sizing = { width = 200, height = 150 } },
			backgroundColor = { 255, 0, 0, 255 },
			cornerRadius = { 20, 20, 20, 20 },
			border = {
				color = { 0, 0, 0, 255 },
				width = 5
			}
		})
	end)
	return clay.end_layout()
end

return layouts
