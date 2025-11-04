-- Layout System Test
-- Tests vstack, hstack, and grid layouts

local ui = dofile("UI.lua")

local context = {
    scenes = {},
    elements = {},
    functions = { log = print }
}

ui.init(context)
ui.newScene("LayoutTest")
ui.setScene("LayoutTest")

-- Title
ui.label({
    text = "=== Layout System Test ===",
    position = "topCenter",
    yOffset = 1,
    fg = colors.yellow
})

-- Test 1: VStack with builder pattern
print("Creating vstack...")
local stack = ui.vstack({
    position = "left",
    xOffset = 2,
    yOffset = 4,
    spacing = 1,
    align = "left",
    padding = 1,
    builder = function(container)
        container:addChild(ui.label({
            text = "Item 1",
            fg = colors.lime
        }))
        container:addChild(ui.label({
            text = "Item 2",
            fg = colors.cyan
        }))
        container:addChild(ui.button({
            text = "Button",
            bg = colors.blue,
            onclick = function() print("Clicked!") end
        }))
    end
})

-- Test 2: HStack with manual child adding
print("Creating hstack...")
local hstack = ui.hstack({
    position = "center",
    yOffset = 0,
    spacing = 2,
    align = "center"
})

hstack:addChild(ui.label({ text = "A", fg = colors.red }))
hstack:addChild(ui.label({ text = "B", fg = colors.green }))
hstack:addChild(ui.label({ text = "C", fg = colors.blue }))

-- Test 3: Grid layout
print("Creating grid...")
local grid = ui.grid({
    position = "bottomLeft",
    xOffset = 2,
    yOffset = -8,
    columns = 3,
    spacing = 1,
    padding = 1,
    builder = function(container)
        for i = 1, 6 do
            container:addChild(ui.label({
                text = tostring(i),
                fg = colors.white,
                bg = colors.gray
            }))
        end
    end
})

print("Test layout created successfully!")
print("Press any key to start rendering...")
os.pullEvent("key")

-- Run the UI
ui.run({fps = 30})
