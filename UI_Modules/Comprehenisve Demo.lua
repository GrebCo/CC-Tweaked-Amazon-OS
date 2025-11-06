
--[[
    Comprehensive UI Framework Demo
    ================================

    A complete demonstration of all UI components with a navigable menu system.
    Screen size: 54x19

    Component Categories:
    1. Basic UI Elements (button, label, checkbox, textfield, rectangle)
    2. Input Components (slider, buttonGroup, dropdown, advancedTextField)
    3. Data Display (progressBar, gauge, statPanel, rangeBar, barChart)
    4. Advanced Components (textArea, terminal, scrollableList, table)
    5. Layout System (vstack, hstack, grid, nested layouts)

    Navigation: Each scene has a "Back to Menu" button
    Note: No print statements in onclick handlers to keep rendering clean
]]

-- Load framework components
local ui = dofile("UI.lua")
local inputs = dofile("Inputs.lua")
local dataDisplay = dofile("dataDisplay.lua")
local registerThemes = dofile("themes.lua")

-- Initialize UI
local context = {
    scenes = {},
    elements = {},
    functions = { log = function() end }  -- Silent logging
}

ui.init(context)
inputs.init(ui)
dataDisplay.init(ui)
registerThemes(ui)
ui.setTheme("nordic")  -- Use Nordic theme

-- Global state for demo
local demoState = {
    statusMessage = "Welcome to the UI Framework Demo",
    currentScene = "MainMenu"
}

-- Helper function to update status (used instead of print)
local function setStatus(message)
    demoState.statusMessage = message
    ui.markDirty()
end

-- Helper function to navigate to a scene
local function navigateTo(sceneName)
    demoState.currentScene = sceneName
    ui.setScene(sceneName)
    setStatus("Viewing: " .. sceneName)
end

--==============================================================================
-- MAIN MENU SCENE
--==============================================================================
ui.newScene("MainMenu")
ui.setScene("MainMenu")

-- Title
ui.label({
    text = "UI Framework - Comprehensive Demo",
    position = "topCenter",
    yOffset = 2,
    fg = colors.yellow
})

-- Status display
local statusLabel = ui.label({
    text = demoState.statusMessage,
    position = "topCenter",
    yOffset = 3,
    fg = colors.lime
})

-- Update status label helper
local function updateStatus()
    statusLabel.text = demoState.statusMessage
end

-- Menu options in a vertical stack
local menuButtons = {
    {text = "1. Basic UI Elements", scene = "BasicUI"},
    {text = "2. Input Components", scene = "InputComponents"},
    {text = "3. Data Display", scene = "DataDisplay"},
    {text = "4. Advanced Components", scene = "AdvancedComponents"},
    {text = "5. Layout System", scene = "LayoutSystem"},
    {text = "Exit Demo", scene = "Exit"}
}

for i, btn in ipairs(menuButtons) do
    ui.button({
        text = btn.text,
        width = 30,
        position = "center",
        yOffset = -4 + (i * 2),
        bg = btn.scene == "Exit" and colors.red or colors.blue,
        colorPressed = btn.scene == "Exit" and colors.orange or colors.lightBlue,
        onclick = function()
            if btn.scene == "Exit" then
                term.clear()
                term.setCursorPos(1, 1)
                print("Demo exited. Thanks for exploring!")
                error("", 0)  -- Clean exit
            else
                navigateTo(btn.scene)
                updateStatus()
            end
        end
    })
end

-- Credits
ui.label({
    text = "Use buttons to navigate | 54x19 screen",
    position = "bottomCenter",
    yOffset = -1,
    fg = colors.gray
})

--==============================================================================
-- SCENE 1: BASIC UI ELEMENTS
--==============================================================================
ui.newScene("BasicUI")
ui.setScene("BasicUI")

-- Title
ui.label({
    text = "=== Basic UI Elements ===",
    position = "topCenter",
    yOffset = 1,
    fg = colors.yellow
})

-- Section 1: Buttons
ui.label({
    text = "Buttons:",
    position = "topLeft",
    xOffset = 2,
    yOffset = 3,
    fg = colors.cyan
})

ui.button({
    text = "Standard Button",
    width = 18,
    position = "topLeft",
    xOffset = 2,
    yOffset = 4,
    bg = colors.blue,
    colorPressed = colors.lightBlue,
    onclick = function()
        setStatus("Standard button clicked")
        updateStatus()
    end
})

ui.button({
    text = "Toggle Button",
    width = 18,
    position = "topLeft",
    xOffset = 2,
    yOffset = 5,
    bg = colors.green,
    colorPressed = colors.lime,
    toggle = true,
    onclick = function(self)
        setStatus("Toggle: " .. (self.pressed and "ON" or "OFF"))
        updateStatus()
    end
})

-- Section 2: Labels and Rectangles
ui.label({
    text = "Labels & Rectangles:",
    position = "topLeft",
    xOffset = 28,
    yOffset = 3,
    fg = colors.cyan
})

ui.rectangle({
    width = 20,
    height = 4,
    position = "topLeft",
    xOffset = 28,
    yOffset = 4,
    bg = colors.gray
})

ui.label({
    text = "Label on Rectangle",
    position = "topLeft",
    xOffset = 31,
    yOffset = 5,
    fg = colors.white
})

-- Section 3: Checkboxes
ui.label({
    text = "Checkboxes:",
    position = "topLeft",
    xOffset = 2,
    yOffset = 8,
    fg = colors.cyan
})

local checkState = {sound = true, music = false}

ui.checkbox({
    text = "Enable Sound Effects",
    position = "topLeft",
    xOffset = 2,
    yOffset = 9,
    initial = checkState.sound,
    onclick = function(self, checked)
        checkState.sound = checked
        setStatus("Sound: " .. (checked and "ON" or "OFF"))
        updateStatus()
    end
})

ui.checkbox({
    text = "Enable Music",
    position = "topLeft",
    xOffset = 2,
    yOffset = 10,
    initial = checkState.music,
    onclick = function(self, checked)
        checkState.music = checked
        setStatus("Music: " .. (checked and "ON" or "OFF"))
        updateStatus()
    end
})

-- Section 4: Text Field
ui.label({
    text = "Text Field:",
    position = "topLeft",
    xOffset = 2,
    yOffset = 12,
    fg = colors.cyan
})

local nameField = ui.textfield({
    text = "",
    width = 25,
    placeholder = "Enter your name...",
    position = "topLeft",
    xOffset = 2,
    yOffset = 13,
    onChange = function(text)
        if #text > 0 then
            setStatus("Name: " .. text)
        else
            setStatus("Name field cleared")
        end
        updateStatus()
    end
})

-- Back button
ui.button({
    text = "< Back to Menu",
    width = 16,
    position = "bottomCenter",
    yOffset = -1,
    bg = colors.gray,
    colorPressed = colors.lightGray,
    onclick = function()
        navigateTo("MainMenu")
        updateStatus()
    end
})

--==============================================================================
-- SCENE 2: INPUT COMPONENTS
--==============================================================================
ui.newScene("InputComponents")
ui.setScene("InputComponents")

-- Title
ui.label({
    text = "=== Input Components ===",
    position = "topCenter",
    yOffset = 1,
    fg = colors.yellow
})

-- Horizontal Slider
ui.label({
    text = "Volume Slider:",
    position = "topLeft",
    xOffset = 2,
    yOffset = 3,
    fg = colors.cyan
})

local volumeSlider = inputs.slider({
    min = 0,
    max = 100,
    value = 75,
    width = 25,
    showValue = true,
    valueFormat = "%.0f%%",
    position = "topLeft",
    xOffset = 2,
    yOffset = 4,
    theme = "success",
    onChange = function(value)
        setStatus("Volume: " .. value .. "%")
        updateStatus()
    end
})

-- Vertical Slider
ui.label({
    text = "Brightness",
    position = "topRight",
    xOffset = -8,
    yOffset = 3,
    fg = colors.cyan
})

local brightnessSlider = inputs.slider({
    min = 0,
    max = 100,
    value = 60,
    width = 3,
    height = 10,
    orientation = "vertical",
    showValue = true,
    position = "topRight",
    xOffset = -6,
    yOffset = 4,
    theme = "info",
    onChange = function(value)
        setStatus("Brightness: " .. value)
        updateStatus()
    end
})

-- Button Group
ui.label({
    text = "Difficulty:",
    position = "topLeft",
    xOffset = 2,
    yOffset = 7,
    fg = colors.cyan
})

local difficultyGroup = inputs.buttonGroup({
    options = {"Easy", "Normal", "Hard"},
    selected = 2,
    orientation = "horizontal",
    spacing = 2,
    position = "topLeft",
    xOffset = 2,
    yOffset = 8,
    theme = "primary",
    onChange = function(selected, index)
        setStatus("Difficulty: " .. selected)
        updateStatus()
    end
})

-- Dropdown
ui.label({
    text = "Language:",
    position = "topLeft",
    xOffset = 2,
    yOffset = 11,
    fg = colors.cyan
})

local languageDropdown = inputs.dropdown({
    options = {"English", "Spanish", "French", "German", "Japanese"},
    selected = 1,
    width = 20,
    maxHeight = 4,
    position = "topLeft",
    xOffset = 2,
    yOffset = 12,
    theme = "primary",
    onChange = function(selected, index)
        setStatus("Language: " .. selected)
        updateStatus()
    end
})

-- Back button
ui.button({
    text = "< Back to Menu",
    width = 16,
    position = "bottomCenter",
    yOffset = -1,
    bg = colors.gray,
    colorPressed = colors.lightGray,
    onclick = function()
        navigateTo("MainMenu")
        updateStatus()
    end
})

--==============================================================================
-- SCENE 3: DATA DISPLAY
--==============================================================================
ui.newScene("DataDisplay")
ui.setScene("DataDisplay")

-- Title
ui.label({
    text = "=== Data Display Components ===",
    position = "topCenter",
    yOffset = 1,
    fg = colors.yellow
})

-- Progress Bar
ui.label({
    text = "Progress Bar:",
    position = "topLeft",
    xOffset = 2,
    yOffset = 3,
    fg = colors.cyan
})

local progressBar = dataDisplay.progressBar({
    value = 65,
    maxValue = 100,
    width = 25,
    showPercent = true,
    position = "topLeft",
    xOffset = 2,
    yOffset = 4,
    theme = "success"
})

-- Animate progress
local progressWorker = {
    type = "worker",
    x = 0, y = 0,
    timer = 0,
    direction = 1,
    update = function(self, dt)
        self.timer = self.timer + dt
        if self.timer >= 0.1 then
            self.timer = 0
            local newVal = progressBar.value + (self.direction * 2)
            if newVal >= 100 then
                newVal = 100
                self.direction = -1
            elseif newVal <= 0 then
                newVal = 0
                self.direction = 1
            end
            progressBar:setValue(newVal)
        end
    end,
    draw = function() end
}
ui.addElement("DataDisplay", progressWorker)

-- Gauge
ui.label({
    text = "Gauge:",
    position = "topLeft",
    xOffset = 2,
    yOffset = 6,
    fg = colors.cyan
})

local gauge = dataDisplay.gauge({
    value = 45,
    maxValue = 100,
    width = 20,
    height = 3,
    label = "System Load",
    position = "topLeft",
    xOffset = 2,
    yOffset = 7
})

-- Range Bar (vertical)
ui.label({
    text = "Temperature",
    position = "topRight",
    xOffset = -10,
    yOffset = 3,
    fg = colors.cyan
})

local tempBar = dataDisplay.rangeBar({
    value = 72,
    minValue = 0,
    maxValue = 100,
    width = 5,
    height = 10,
    orientation = "vertical",
    showValue = true,
    valueFormat = "%.0f°",
    position = "topRight",
    xOffset = -8,
    yOffset = 4,
    theme = "rangeBar"
})

-- Stat Panel
ui.label({
    text = "Stats:",
    position = "topLeft",
    xOffset = 2,
    yOffset = 11,
    fg = colors.cyan
})

local statsPanel = dataDisplay.statPanel({
    stats = {
        {label = "CPU", value = "45%"},
        {label = "RAM", value = "2.1GB"},
        {label = "Disk", value = "15GB"}
    },
    width = 25,
    height = 4,
    position = "topLeft",
    xOffset = 2,
    yOffset = 12
})

-- Back button
ui.button({
    text = "< Back to Menu",
    width = 16,
    position = "bottomCenter",
    yOffset = -1,
    bg = colors.gray,
    colorPressed = colors.lightGray,
    onclick = function()
        navigateTo("MainMenu")
        updateStatus()
    end
})

--==============================================================================
-- SCENE 4: ADVANCED COMPONENTS
--==============================================================================
ui.newScene("AdvancedComponents")
ui.setScene("AdvancedComponents")

-- Title
ui.label({
    text = "=== Advanced Components ===",
    position = "topCenter",
    yOffset = 1,
    fg = colors.yellow
})

-- TextArea
ui.label({
    text = "Text Area (multi-line editor):",
    position = "topLeft",
    xOffset = 2,
    yOffset = 3,
    fg = colors.cyan
})

local editor = inputs.textArea({
    text = "Line 1: Hello World\nLine 2: This is a multi-line editor\nLine 3: Try editing!",
    width = 30,
    height = 6,
    lineNumbers = true,
    position = "topLeft",
    xOffset = 2,
    yOffset = 4,
    onChange = function(text)
        local lineCount = select(2, text:gsub("\n", "\n")) + 1
        setStatus("Editor: " .. lineCount .. " lines, " .. #text .. " chars")
        updateStatus()
    end
})

-- Scrollable List
ui.label({
    text = "Scrollable List:",
    position = "topRight",
    xOffset = -18,
    yOffset = 3,
    fg = colors.cyan
})

local itemList = dataDisplay.scrollableList({
    items = {"Item 1", "Item 2", "Item 3", "Item 4", "Item 5", "Item 6"},
    width = 16,
    height = 6,
    position = "topRight",
    xOffset = -18,
    yOffset = 4,
    onSelect = function(item, index)
        setStatus("Selected: " .. item)
        updateStatus()
    end
})

-- Terminal
ui.label({
    text = "Terminal:",
    position = "topLeft",
    xOffset = 2,
    yOffset = 11,
    fg = colors.cyan
})

local terminalBox = ui.terminal({
    width = 48,
    height = 5,
    position = "topLeft",
    xOffset = 2,
    yOffset = 12
})

terminalBox:append("Welcome to the terminal")
terminalBox:append("Type commands here")
terminalBox:prompt(">", function(input)
    terminalBox:append("You typed: " .. input)
    setStatus("Terminal input: " .. input)
    updateStatus()
end)

-- Back button
ui.button({
    text = "< Back to Menu",
    width = 16,
    position = "bottomCenter",
    yOffset = -1,
    bg = colors.gray,
    colorPressed = colors.lightGray,
    onclick = function()
        navigateTo("MainMenu")
        updateStatus()
    end
})

--==============================================================================
-- SCENE 5: LAYOUT SYSTEM
--==============================================================================
ui.newScene("LayoutSystem")
ui.setScene("LayoutSystem")

-- Title
ui.label({
    text = "=== Layout System ===",
    position = "topCenter",
    yOffset = 1,
    fg = colors.yellow
})

-- VStack example
ui.label({
    text = "VStack (Vertical):",
    position = "topLeft",
    xOffset = 2,
    yOffset = 3,
    fg = colors.cyan
})

local vstack = ui.vstack({
    position = "topLeft",
    xOffset = 2,
    yOffset = 4,
    spacing = 1,
    padding = 1,
    builder = function(container)
        container:addChild(ui.label({text = "Item 1", fg = colors.white, bg = colors.blue}))
        container:addChild(ui.label({text = "Item 2", fg = colors.white, bg = colors.blue}))
        container:addChild(ui.label({text = "Item 3", fg = colors.white, bg = colors.blue}))
    end
})

-- HStack example
ui.label({
    text = "HStack (Horizontal):",
    position = "topLeft",
    xOffset = 2,
    yOffset = 10,
    fg = colors.cyan
})

local hstack = ui.hstack({
    position = "topLeft",
    xOffset = 2,
    yOffset = 11,
    spacing = 2,
    builder = function(container)
        container:addChild(ui.button({
            text = "Btn1",
            width = 6,
            bg = colors.green,
            onclick = function()
                setStatus("Button 1 clicked")
                updateStatus()
            end
        }))
        container:addChild(ui.button({
            text = "Btn2",
            width = 6,
            bg = colors.green,
            onclick = function()
                setStatus("Button 2 clicked")
                updateStatus()
            end
        }))
        container:addChild(ui.button({
            text = "Btn3",
            width = 6,
            bg = colors.green,
            onclick = function()
                setStatus("Button 3 clicked")
                updateStatus()
            end
        }))
    end
})

-- Grid example
ui.label({
    text = "Grid (2 columns):",
    position = "topRight",
    xOffset = -22,
    yOffset = 3,
    fg = colors.cyan
})

local grid = ui.grid({
    position = "topRight",
    xOffset = -22,
    yOffset = 4,
    columns = 2,
    spacing = 1,
    padding = 1,
    builder = function(container)
        for i = 1, 6 do
            container:addChild(ui.label({
                text = "Cell " .. i,
                fg = colors.white,
                bg = colors.gray
            }))
        end
    end
})

-- Nested layout example
ui.label({
    text = "Nested Layout:",
    position = "topLeft",
    xOffset = 2,
    yOffset = 14,
    fg = colors.cyan
})

local nestedStack = ui.vstack({
    position = "topLeft",
    xOffset = 2,
    yOffset = 15,
    spacing = 0,
    padding = 1,
    builder = function(outer)
        outer:addChild(ui.label({text = "Header", fg = colors.yellow}))
        local innerHStack = ui.hstack({
            spacing = 1,
            builder = function(inner)
                inner:addChild(ui.label({text = "Left", bg = colors.blue}))
                inner:addChild(ui.label({text = "Right", bg = colors.red}))
            end
        })
        outer:addChild(innerHStack)
    end
})

-- Back button
ui.button({
    text = "< Back to Menu",
    width = 16,
    position = "bottomCenter",
    yOffset = -1,
    bg = colors.gray,
    colorPressed = colors.lightGray,
    onclick = function()
        navigateTo("MainMenu")
        updateStatus()
    end
})

--==============================================================================
-- START DEMO
--==============================================================================

-- Return to main menu and start
ui.setScene("MainMenu")
print("Starting Comprehensive UI Demo...")
print("Screen size: 54x19")
print("Navigate using buttons")
print("")

ui.run({fps = 30})