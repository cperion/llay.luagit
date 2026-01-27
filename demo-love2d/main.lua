-- Love2D Demo for Llay Layout Engine
-- Simple demonstration of Llay's layout capabilities

package.path = "../src/?.lua;" .. package.path
local llay = require("init")

local WIDTH = 800
local HEIGHT = 600

local commands = nil
local hovered_element = nil
local click_count = 0

-- Mock text measurement function
local ffi = require("ffi")
local function mock_measure_text(text, config)
    -- Simple deterministic measurement for demo
    -- 10px per character, 20px height
    local text_str = ffi.string(text.chars, text.length)
    return {
        width = (#text_str) * 10,
        height = 20
    }
end

function love.load()
    -- Initialize Llay
    llay.init(1024 * 1024 * 16)
    llay.set_dimensions(WIDTH, HEIGHT)
    llay.set_measure_text_function(mock_measure_text)
    
    -- Set up Love2D window
    love.window.setMode(WIDTH, HEIGHT, {
        resizable = false,
        vsync = true,
        centered = true
    })
    
    love.window.setTitle("Llay Love2D Demo - LuaJIT Layout Engine")
    
    -- Generate initial layout
    generate_layout()
end

function generate_layout()
    llay.begin_layout()
    
    -- Root container - fills entire window
    llay.Element({
        layout = {
            sizing = { width = "GROW", height = "GROW" },
            layoutDirection = llay.LayoutDirection.TOP_TO_BOTTOM,
            padding = {20, 20, 20, 20},
            childGap = 15
        },
        backgroundColor = {240, 240, 245, 255}  -- Light gray background
    }, function()
        
        -- Header
        llay.Element({
            id = "header",
            layout = {
                sizing = { width = "GROW", height = 80 }
            },
            backgroundColor = {50, 100, 200, 255},  -- Blue header
            cornerRadius = {10, 10, 10, 10}
        })
        
        -- Main content area (row with two columns)
        llay.Element({
            layout = {
                sizing = { width = "GROW", height = "GROW" },
                layoutDirection = llay.LayoutDirection.LEFT_TO_RIGHT,
                childGap = 20
            }
        }, function()
            
            -- Left panel
            llay.Element({
                id = "left_panel",
                layout = {
                    sizing = { width = 250, height = "GROW" }
                },
                backgroundColor = {255, 255, 255, 255},  -- White panel
                cornerRadius = {8, 8, 8, 8},
                border = {
                    color = {200, 200, 210, 255},
                    width = 2
                }
            }, function()
                -- Column of buttons inside left panel
                llay.Element({
                    layout = {
                        sizing = { width = "GROW", height = "GROW" },
                        layoutDirection = llay.LayoutDirection.TOP_TO_BOTTOM,
                        padding = {15, 15, 15, 15},
                        childGap = 10
                    }
                }, function()
                    
                    -- Button 1
                    llay.Element({
                        id = "button1",
                        layout = {
                            sizing = { width = "GROW", height = 50 }
                        },
                        backgroundColor = {70, 130, 230, 255},  -- Blue button
                        cornerRadius = {6, 6, 6, 6}
                    })
                    
                    -- Button 2  
                    llay.Element({
                        id = "button2",
                        layout = {
                            sizing = { width = "GROW", height = 50 }
                        },
                        backgroundColor = {230, 100, 100, 255},  -- Red button
                        cornerRadius = {6, 6, 6, 6}
                    })
                    
                    -- Button 3
                    llay.Element({
                        id = "button3",
                        layout = {
                            sizing = { width = "GROW", height = 50 }
                        },
                        backgroundColor = {100, 200, 100, 255},  -- Green button
                        cornerRadius = {6, 6, 6, 6}
                    })
                    
                    -- Button 4
                    llay.Element({
                        id = "button4",
                        layout = {
                            sizing = { width = "GROW", height = 50 }
                        },
                        backgroundColor = {200, 150, 50, 255},  -- Orange button
                        cornerRadius = {6, 6, 6, 6}
                    })
                    
                end)
            end)
            
            -- Right panel (main content)
            llay.Element({
                id = "right_panel",
                layout = {
                    sizing = { width = "GROW", height = "GROW" }
                },
                backgroundColor = {255, 255, 255, 255},  -- White panel
                cornerRadius = {8, 8, 8, 8},
                border = {
                    color = {200, 200, 210, 255},
                    width = 2
                }
            }, function()
                -- Grid of content boxes
                llay.Element({
                    layout = {
                        sizing = { width = "GROW", height = "GROW" },
                        layoutDirection = llay.LayoutDirection.TOP_TO_BOTTOM,
                        padding = {20, 20, 20, 20},
                        childGap = 15
                    }
                }, function()
                    
                    -- First row of boxes
                    llay.Element({
                        layout = {
                            sizing = { width = "GROW", height = 100 },
                            layoutDirection = llay.LayoutDirection.LEFT_TO_RIGHT,
                            childGap = 15
                        }
                    }, function()
                        
                        for i = 1, 3 do
                            llay.Element({
                                id = "content_box_" .. i,
                                layout = {
                                    sizing = { width = "GROW", height = "GROW" }
                                },
                                backgroundColor = {
                                    math.min(180 + i * 20, 255),
                                    math.min(180 + i * 10, 255),
                                    math.min(220 + i * 5, 255),
                                    255
                                },
                                cornerRadius = {8, 8, 8, 8}
                            })
                        end
                        
                    end)
                    
                    -- Second row of boxes
                    llay.Element({
                        layout = {
                            sizing = { width = "GROW", height = 150 },
                            layoutDirection = llay.LayoutDirection.LEFT_TO_RIGHT,
                            childGap = 15
                        }
                    }, function()
                        
                        for i = 4, 6 do
                            llay.Element({
                                id = "content_box_" .. i,
                                layout = {
                                    sizing = { width = "GROW", height = "GROW" }
                                },
                                backgroundColor = {
                                    math.min(150 + i * 15, 255),
                                    math.min(200 + i * 5, 255),
                                    math.min(180 + i * 10, 255),
                                    255
                                },
                                cornerRadius = {8, 8, 8, 8}
                            })
                        end
                        
                    end)
                    
                    -- Aspect ratio demo box
                    llay.Element({
                        id = "aspect_demo",
                        layout = {
                            sizing = {
                                width = "GROW",
                                height = { min = 100, max = 200 }
                            },
                            aspectRatio = 1.5  -- 3:2 aspect ratio
                        },
                        backgroundColor = {180, 180, 220, 255},
                        cornerRadius = {8, 8, 8, 8}
                    })
                    
                end)
            end)
            
        end)
        
        -- Footer
        llay.Element({
            id = "footer",
            layout = {
                sizing = { width = "GROW", height = 60 }
            },
            backgroundColor = {50, 50, 60, 255},  -- Dark footer
            cornerRadius = {0, 0, 10, 10}
        })
        
    end)
    
    commands = llay.end_layout()
    print("Generated " .. commands.length .. " render commands")
end

function love.update(dt)
    -- Update pointer state
    local x, y = love.mouse.getPosition()
    local is_down = love.mouse.isDown(1)
    llay.set_pointer_state(x, y, is_down)
    
    -- Check what element is hovered
    hovered_element = nil
    local elements_to_check = {
        "button1", "button2", "button3", "button4",
        "left_panel", "right_panel", "header", "footer"
    }
    
    for _, id in ipairs(elements_to_check) do
        if llay.pointer_over(id) then
            hovered_element = id
            break
        end
    end
    
    -- Also check content boxes
    if not hovered_element then
        for i = 1, 6 do
            if llay.pointer_over("content_box_" .. i) then
                hovered_element = "content_box_" .. i
                break
            end
        end
    end
    
    if not hovered_element then
        if llay.pointer_over("aspect_demo") then
            hovered_element = "aspect_demo"
        end
    end
end

function love.draw()
    -- Clear with light background
    love.graphics.clear(0.95, 0.95, 0.96, 1)
    
    if commands then
        -- Draw all render commands from Llay
        for i = 0, commands.length - 1 do
            local cmd = commands.internalArray[i]
            local bbox = cmd.boundingBox
            
            -- Draw rectangles (commandType 1 is RECTANGLE)
            if cmd.commandType == 1 then
                local color = cmd.renderData.rectangle.backgroundColor
                
                -- Set color (convert from 0-255 to 0-1)
                love.graphics.setColor(color.r/255, color.g/255, color.b/255, color.a/255)
                
                -- Draw with rounded corners if cornerRadius > 0
                local radius = cmd.renderData.rectangle.cornerRadius
                if radius.topLeft > 0 or radius.topRight > 0 or 
                   radius.bottomLeft > 0 or radius.bottomRight > 0 then
                    -- Use simple rounded rectangle
                    love.graphics.rectangle("fill", bbox.x, bbox.y, bbox.width, bbox.height, 5)
                else
                    love.graphics.rectangle("fill", bbox.x, bbox.y, bbox.width, bbox.height)
                end
            end
            
            -- Draw borders (commandType 2 is BORDER)
            if cmd.commandType == 2 then
                local border_color = cmd.renderData.border.color
                local border_width = cmd.renderData.border.width
                
                love.graphics.setColor(border_color.r/255, border_color.g/255, 
                                      border_color.b/255, border_color.a/255)
                love.graphics.setLineWidth(border_width.left or 2)
                love.graphics.rectangle("line", bbox.x, bbox.y, bbox.width, bbox.height)
            end
        end
        
        -- Draw hover highlight
        if hovered_element then
            love.graphics.setColor(1, 1, 1, 0.3)
            love.graphics.setLineWidth(3)
            
            -- Find and highlight the hovered element
            for i = 0, commands.length - 1 do
                local cmd = commands.internalArray[i]
                if cmd.id and tostring(cmd.id):find(hovered_element, 1, true) then
                    local bbox = cmd.boundingBox
                    love.graphics.rectangle("line", bbox.x - 2, bbox.y - 2, 
                                          bbox.width + 4, bbox.height + 4)
                    break
                end
            end
        end
        
        -- Draw UI info
        love.graphics.setColor(0.2, 0.2, 0.2, 1)
        love.graphics.print("Llay Love2D Demo - Interactive UI Layout", 20, 20)
        love.graphics.print("Hovered: " .. (hovered_element or "none"), 20, 45)
        love.graphics.print("Clicks: " .. click_count, 20, 70)
        love.graphics.print("Commands: " .. commands.length, 20, 95)
        love.graphics.print("Press R to regenerate, ESC to quit", 20, HEIGHT - 40)
    end
end

function love.mousepressed(x, y, button, istouch, presses)
    if button == 1 then  -- Left click
        click_count = click_count + 1
        
        if hovered_element then
            print("Clicked on: " .. hovered_element)
            
            -- Simple interaction: regenerate layout with different colors
            if hovered_element:find("button") then
                generate_layout()
                print("Layout regenerated after button click")
            end
        end
    end
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "r" then
        -- Regenerate layout
        generate_layout()
        print("Layout regenerated")
    elseif key == "f1" then
        -- Print debug info
        print("=== Llay Debug Info ===")
        print("Commands: " .. commands.length)
        print("Hovered: " .. (hovered_element or "none"))
        print("Click count: " .. click_count)
    end
end