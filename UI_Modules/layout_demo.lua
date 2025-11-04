-- Comprehensive Layout System Demo
-- Shows vstack, hstack, grid, and nested layouts

local ui = dofile("UI.lua")

local context = {
    scenes = {},
    elements = {},
    functions = { log = print }
}

ui.init(context)
ui.newScene("Demo")
ui.setScene("Demo")

-- Title
ui.label({
    text = "Layout System Demo",
    position = "topCenter",
    yOffset = 1,
    fg = colors.yellow
})

-- Sidebar with vertical stack
local sidebar = ui.vstack({
    position = "left",
    xOffset = 1,
    yOffset = 3,
    spacing = 0,
    padding = 1,
    width = 15,
    builder = function(container)
        container:addChild(ui.label({
            text = "Menu",
            fg = colors.cyan
        }))
        container:addChild(ui.button({
            text = "Home",
            width = 13,
            bg = colors.blue,
            colorPressed = colors.lightBlue,
            onclick = function() print("Home") end
        }))
        container:addChild(ui.button({
            text = "Settings",
            width = 13,
            bg = colors.gray,
            colorPressed = colors.lightGray,
            onclick = function() print("Settings") end
        }))
        container:addChild(ui.button({
            text = "About",
            width = 13,
            bg = colors.gray,
            colorPressed = colors.lightGray,
            onclick = function() print("About") end
        }))
    end
})

-- Main content area with grid
local content = ui.grid({
    position = "left",
    xOffset = 18,
    yOffset = 3,
    columns = 2,
    rowSpacing = 1,
    columnSpacing = 2,
    padding = 1,
    builder = function(container)
        -- Create cards
        for i = 1, 4 do
            -- Each card is a vstack
            local card = ui.vstack({
                spacing = 0,
                padding = 1,
                builder = function(cardContainer)
                    cardContainer:addChild(ui.label({
                        text = "Card " .. i,
                        fg = colors.white,
                        bg = colors.blue
                    }))
                    cardContainer:addChild(ui.label({
                        text = "Content here",
                        fg = colors.lightGray
                    }))
                end
            })
            container:addChild(card)
        end
    end
})

-- Bottom toolbar with horizontal stack
local toolbar = ui.hstack({
    position = "bottomCenter",
    yOffset = -1,
    spacing = 2,
    align = "center",
    builder = function(container)
        container:addChild(ui.button({
            text = "Save",
            bg = colors.green,
            colorPressed = colors.lime,
            onclick = function() print("Saved!") end
        }))
        container:addChild(ui.button({
            text = "Cancel",
            bg = colors.red,
            colorPressed = colors.orange,
            onclick = function() print("Cancelled") end
        }))
        container:addChild(ui.button({
            text = "Help",
            bg = colors.blue,
            colorPressed = colors.lightBlue,
            onclick = function() print("Help!") end
        }))
    end
})

print("Layout demo created!")
print("Features demonstrated:")
print("- VStack (sidebar)")
print("- Grid with nested VStacks (content cards)")
print("- HStack (bottom toolbar)")
print("")
print("Press any key to run...")
os.pullEvent("key")

ui.run({fps = 30})
