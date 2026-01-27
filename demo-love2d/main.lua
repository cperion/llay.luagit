-- Love2D Demo for Llay Layout Engine
-- Interactive UI demonstration with real text rendering

package.path = "../src/?.lua;" .. package.path
local ffi = require("ffi")
local llay = require("init")

local WIDTH = 900
local HEIGHT = 650

local commands = nil
local hovered_element = nil
local click_count = 0
local element_ids = {}
local fonts = {}

-- Helper: round to integer pixels for crisp text
local function round(x)
    return math.floor(x + 0.5)
end

-- Text measurement using Love2D's font system
local function love_measure_text(text, config)
    local font = fonts.default
    if config.fontSize >= 20 then
        font = fonts.large
    elseif config.fontSize <= 14 then
        font = fonts.small
    end
    
    local text_str = ffi.string(text.chars, text.length)
    return {
        width = font:getWidth(text_str),
        height = font:getHeight()
    }
end

function love.load()
    -- Set up fonts
    fonts.small = love.graphics.newFont(12)
    fonts.default = love.graphics.newFont(16)
    fonts.large = love.graphics.newFont(24)
    fonts.title = love.graphics.newFont(28)
    
    -- Initialize Llay
    llay.init(1024 * 1024 * 16)
    llay.set_dimensions(WIDTH, HEIGHT)
    llay.set_measure_text_function(love_measure_text)
    
    -- Set up Love2D window
    love.window.setMode(WIDTH, HEIGHT, {
        resizable = false,
        vsync = true,
        centered = true
    })
    
    love.window.setTitle("Llay - LuaJIT Layout Engine Demo")
    
    -- Generate initial layout
    generate_layout()
end

function generate_layout()
    llay.begin_layout()
    
    -- Root container
    llay.Element({
        layout = {
            sizing = { width = "GROW", height = "GROW" },
            layoutDirection = llay.LayoutDirection.TOP_TO_BOTTOM,
            padding = {16, 16, 16, 16},
            childGap = 12
        },
        backgroundColor = {30, 32, 40, 255}
    }, function()
        
        -- Header bar
        llay.Element({
            id = "header",
            layout = {
                sizing = { width = "GROW", height = 56 },
                layoutDirection = llay.LayoutDirection.LEFT_TO_RIGHT,
                padding = {16, 16, 12, 12},
                childAlignment = {llay.AlignX.LEFT, llay.AlignY.CENTER}
            },
            backgroundColor = {45, 48, 58, 255},
            cornerRadius = {8, 8, 8, 8}
        })
        
        -- Main content area
        llay.Element({
            layout = {
                sizing = { width = "GROW", height = "GROW" },
                layoutDirection = llay.LayoutDirection.LEFT_TO_RIGHT,
                childGap = 12
            }
        }, function()
            
            -- Sidebar
            llay.Element({
                id = "sidebar",
                layout = {
                    sizing = { width = 220, height = "GROW" },
                    layoutDirection = llay.LayoutDirection.TOP_TO_BOTTOM,
                    padding = {12, 12, 12, 12},
                    childGap = 8
                },
                backgroundColor = {45, 48, 58, 255},
                cornerRadius = {8, 8, 8, 8}
            }, function()
                
                -- Menu buttons
                local buttons = {
                    { id = "btn_dashboard", color = {99, 102, 241, 255}, label = "Dashboard" },
                    { id = "btn_projects", color = {59, 130, 246, 255}, label = "Projects" },
                    { id = "btn_tasks", color = {16, 185, 129, 255}, label = "Tasks" },
                    { id = "btn_calendar", color = {245, 158, 11, 255}, label = "Calendar" },
                    { id = "btn_settings", color = {107, 114, 128, 255}, label = "Settings" },
                }
                
                for _, btn in ipairs(buttons) do
                    llay.Element({
                        id = btn.id,
                        layout = {
                            sizing = { width = "GROW", height = 44 },
                            childAlignment = {llay.AlignX.CENTER, llay.AlignY.CENTER}
                        },
                        backgroundColor = btn.color,
                        cornerRadius = {6, 6, 6, 6}
                    })
                end
                
            end)
            
            -- Main panel
            llay.Element({
                id = "main_panel",
                layout = {
                    sizing = { width = "GROW", height = "GROW" },
                    layoutDirection = llay.LayoutDirection.TOP_TO_BOTTOM,
                    padding = {16, 16, 16, 16},
                    childGap = 16
                },
                backgroundColor = {45, 48, 58, 255},
                cornerRadius = {8, 8, 8, 8}
            }, function()
                
                -- Stats row
                llay.Element({
                    layout = {
                        sizing = { width = "GROW", height = 100 },
                        layoutDirection = llay.LayoutDirection.LEFT_TO_RIGHT,
                        childGap = 12
                    }
                }, function()
                    
                    local stats = {
                        { id = "stat1", color = {99, 102, 241, 255} },
                        { id = "stat2", color = {16, 185, 129, 255} },
                        { id = "stat3", color = {245, 158, 11, 255} },
                        { id = "stat4", color = {239, 68, 68, 255} },
                    }
                    
                    for _, stat in ipairs(stats) do
                        llay.Element({
                            id = stat.id,
                            layout = {
                                sizing = { width = "GROW", height = "GROW" }
                            },
                            backgroundColor = stat.color,
                            cornerRadius = {8, 8, 8, 8}
                        })
                    end
                    
                end)
                
                -- Content grid
                llay.Element({
                    layout = {
                        sizing = { width = "GROW", height = "GROW" },
                        layoutDirection = llay.LayoutDirection.LEFT_TO_RIGHT,
                        childGap = 12
                    }
                }, function()
                    
                    -- Left column
                    llay.Element({
                        id = "chart_area",
                        layout = {
                            sizing = { width = "GROW", height = "GROW" }
                        },
                        backgroundColor = {55, 58, 70, 255},
                        cornerRadius = {8, 8, 8, 8}
                    })
                    
                    -- Right column
                    llay.Element({
                        layout = {
                            sizing = { width = 280, height = "GROW" },
                            layoutDirection = llay.LayoutDirection.TOP_TO_BOTTOM,
                            childGap = 12
                        }
                    }, function()
                        
                        llay.Element({
                            id = "activity",
                            layout = {
                                sizing = { width = "GROW", height = "GROW" }
                            },
                            backgroundColor = {55, 58, 70, 255},
                            cornerRadius = {8, 8, 8, 8}
                        })
                        
                        llay.Element({
                            id = "notifications",
                            layout = {
                                sizing = { width = "GROW", height = 140 }
                            },
                            backgroundColor = {55, 58, 70, 255},
                            cornerRadius = {8, 8, 8, 8}
                        })
                        
                    end)
                    
                end)
                
            end)
            
        end)
        
        -- Footer
        llay.Element({
            id = "footer",
            layout = {
                sizing = { width = "GROW", height = 36 },
                childAlignment = {llay.AlignX.CENTER, llay.AlignY.CENTER}
            },
            backgroundColor = {45, 48, 58, 255},
            cornerRadius = {6, 6, 6, 6}
        })
        
    end)
    
    commands = llay.end_layout()
    
    -- Store element IDs
    element_ids = {}
    local ids_to_track = {
        "header", "sidebar", "main_panel", "footer",
        "btn_dashboard", "btn_projects", "btn_tasks", "btn_calendar", "btn_settings",
        "stat1", "stat2", "stat3", "stat4",
        "chart_area", "activity", "notifications"
    }
    for _, name in ipairs(ids_to_track) do
        element_ids[name] = llay.ID(name).id
    end
end

function love.update(dt)
    local x, y = love.mouse.getPosition()
    llay.set_pointer_state(x, y, love.mouse.isDown(1))
    
    hovered_element = nil
    for name, _ in pairs(element_ids) do
        if llay.pointer_over(name) then
            hovered_element = name
            break
        end
    end
end

function love.draw()
    love.graphics.clear(0.12, 0.13, 0.16, 1)
    
    if commands then
        for i = 0, commands.length - 1 do
            local cmd = commands.internalArray[i]
            local bbox = cmd.boundingBox
            
            if cmd.commandType == 1 then  -- RECTANGLE
                local color = cmd.renderData.rectangle.backgroundColor
                local r = cmd.renderData.rectangle.cornerRadius
                
                -- Hover effect: lighten color
                local hover_boost = 0
                if hovered_element and element_ids[hovered_element] == cmd.id then
                    hover_boost = 0.1
                end
                
                love.graphics.setColor(
                    math.min(color.r/255 + hover_boost, 1),
                    math.min(color.g/255 + hover_boost, 1),
                    math.min(color.b/255 + hover_boost, 1),
                    color.a/255
                )
                
                local radius = math.max(r.topLeft, r.topRight, r.bottomLeft, r.bottomRight)
                love.graphics.rectangle("fill", round(bbox.x), round(bbox.y), round(bbox.width), round(bbox.height), radius)
            end
        end
        
        -- Draw labels on elements
        love.graphics.setFont(fonts.default)
        love.graphics.setColor(1, 1, 1, 0.9)
        
        -- Header title
        love.graphics.setFont(fonts.title)
        love.graphics.print("Llay Dashboard", round(32), round(26))
        
        -- Button labels
        love.graphics.setFont(fonts.default)
        local button_labels = {
            btn_dashboard = "Dashboard",
            btn_projects = "Projects", 
            btn_tasks = "Tasks",
            btn_calendar = "Calendar",
            btn_settings = "Settings"
        }
        
        for i = 0, commands.length - 1 do
            local cmd = commands.internalArray[i]
            local bbox = cmd.boundingBox
            
            for name, label in pairs(button_labels) do
                if element_ids[name] == cmd.id then
                    local tw = fonts.default:getWidth(label)
                    local th = fonts.default:getHeight()
                    love.graphics.print(label, 
                        round(bbox.x + (bbox.width - tw) / 2),
                        round(bbox.y + (bbox.height - th) / 2))
                end
            end
            
            -- Stat labels
            if element_ids.stat1 == cmd.id then
                love.graphics.print("Users: 1,234", round(bbox.x + 12), round(bbox.y + 12))
                love.graphics.setFont(fonts.large)
                love.graphics.print("+12%", round(bbox.x + 12), round(bbox.y + 40))
                love.graphics.setFont(fonts.default)
            elseif element_ids.stat2 == cmd.id then
                love.graphics.print("Revenue: $45k", round(bbox.x + 12), round(bbox.y + 12))
                love.graphics.setFont(fonts.large)
                love.graphics.print("+8%", round(bbox.x + 12), round(bbox.y + 40))
                love.graphics.setFont(fonts.default)
            elseif element_ids.stat3 == cmd.id then
                love.graphics.print("Orders: 892", round(bbox.x + 12), round(bbox.y + 12))
                love.graphics.setFont(fonts.large)
                love.graphics.print("+24%", round(bbox.x + 12), round(bbox.y + 40))
                love.graphics.setFont(fonts.default)
            elseif element_ids.stat4 == cmd.id then
                love.graphics.print("Bounce: 32%", round(bbox.x + 12), round(bbox.y + 12))
                love.graphics.setFont(fonts.large)
                love.graphics.print("-5%", round(bbox.x + 12), round(bbox.y + 40))
                love.graphics.setFont(fonts.default)
            elseif element_ids.chart_area == cmd.id then
                love.graphics.print("Chart Area", round(bbox.x + 16), round(bbox.y + 16))
            elseif element_ids.activity == cmd.id then
                love.graphics.print("Recent Activity", round(bbox.x + 16), round(bbox.y + 16))
            elseif element_ids.notifications == cmd.id then
                love.graphics.print("Notifications", round(bbox.x + 16), round(bbox.y + 16))
            end
        end
        
        -- Footer text
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(0.6, 0.6, 0.65, 1)
        local footer_text = string.format("Llay Layout Engine | %d elements | Hover: %s | Clicks: %d", 
            commands.length, hovered_element or "none", click_count)
        love.graphics.print(footer_text, round(20), round(HEIGHT - 28))
    end
end

function love.mousepressed(x, y, button)
    if button == 1 and hovered_element then
        click_count = click_count + 1
        print("Clicked: " .. hovered_element)
    end
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "r" then
        generate_layout()
    end
end