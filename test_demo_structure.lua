local ffi = require("ffi")
print("1. Loading llay...")
local llay = require("init")
print("2. llay loaded")

print("3. Initializing with 16MB...")
llay.init(1024 * 1024 * 16) -- 16MB
print("4. Initialized")

print("5. Setting dimensions...")
llay.set_dimensions(1024, 768)
print("6. Dimensions set")

print("7. Setting text measurement...")
llay.set_measure_text_function(function(text, config)
    local text_str = ffi.string(text.chars, text.length)
    return {
        width = #text_str * 10,
        height = 20
    }
end)
print("8. Text measurement set")

print("9. Beginning layout...")
llay.begin_layout()

print("10. Creating root element...")
llay.Element({
    layout = {
        sizing = { width = "GROW", height = "GROW" },
        layoutDirection = llay.LayoutDirection.LEFT_TO_RIGHT,
    },
    backgroundColor = { 18, 18, 22, 255 },
}, function()
    print("11. Creating sidebar...")
    llay.Element({
        id = "sidebar",
        layout = {
            sizing = { width = 240, height = "GROW" },
            layoutDirection = llay.LayoutDirection.TOP_TO_BOTTOM,
            padding = { 20, 20, 30, 30 },
            childGap = 20,
        },
        backgroundColor = { 26, 27, 35, 255 },
    }, function()
        print("12. Creating text in sidebar...")
        llay.Text("PROJECTS", { color = { 140, 145, 160, 255 }, fontSize = 12, fontId = 1 })
    end)
    
    print("13. Creating main content...")
    llay.Element({
        layout = {
            sizing = { width = "GROW", height = "GROW" },
            layoutDirection = llay.LayoutDirection.TOP_TO_BOTTOM,
            padding = { 40, 40, 40, 40 },
            childGap = 30,
        },
    }, function()
        print("14. Creating header...")
        llay.Element({
            layout = {
                sizing = { width = "GROW", height = "FIT" },
                layoutDirection = llay.LayoutDirection.TOP_TO_BOTTOM,
                childGap = 4,
            },
        }, function()
            llay.Text("Engineering Sprint", { color = { 220, 225, 235, 255 }, fontSize = 28, fontId = 1 })
            llay.Text("Active tasks for the current LuaJIT optimization phase.", { color = { 140, 145, 160, 255 }, fontSize = 14 })
        end)
        
        print("15. Creating scrollable task list...")
        llay.Element({
            id = "TaskListContainer",
            layout = {
                sizing = { width = "GROW", height = "GROW" },
                layoutDirection = llay.LayoutDirection.TOP_TO_BOTTOM,
                padding = { 0, 20, 0, 0 },
                childGap = 12,
            },
            clip = { vertical = true, horizontal = false, childOffset = llay.get_scroll_offset() },
        }, function()
            print("16. Creating task items...")
            for i = 1, 3 do
                llay.Element({
                    id = "task_" .. i,
                    layout = {
                        sizing = { width = "GROW", height = "FIT" },
                        padding = { 16, 16, 16, 16 },
                        layoutDirection = llay.LayoutDirection.LEFT_TO_RIGHT,
                        childGap = 16,
                        childAlignment = { nil, llay.AlignY.CENTER },
                    },
                    backgroundColor = { 34, 36, 46, 255 },
                    cornerRadius = 10,
                    border = { color = { 50, 55, 70, 255 }, width = 1 },
                }, function()
                    -- Checkbox
                    llay.Element({
                        layout = { sizing = { width = 20, height = 20 } },
                        backgroundColor = { 110, 120, 240, 255 },
                        cornerRadius = 4,
                        border = { color = { 110, 120, 240, 255 }, width = 2 },
                    })
                    
                    -- Labels
                    llay.Element({
                        layout = {
                            sizing = { width = "GROW", height = "FIT" },
                            layoutDirection = llay.LayoutDirection.TOP_TO_BOTTOM,
                            childGap = 2,
                        },
                    }, function()
                        llay.Text("Optimizing JIT Trace #" .. i, { color = { 220, 225, 235, 255 }, fontSize = 16, fontId = 1 })
                        llay.Text("Investigate the guard failure in the hot loop of the spatial partitioner.", { color = { 140, 145, 160, 255 }, fontSize = 13 })
                    end)
                end)
            end
        end)
    end)
end)

print("17. Ending layout...")
local commands = llay.end_layout()
print("18. Layout ended, commands:", commands.length)

print("SUCCESS!")