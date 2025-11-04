-- new_elements_demo.lua
-- Comprehensive demo of new interactive elements: Slider, ButtonGroup, Dropdown
-- This demonstrates all the features and use cases

local ui = dofile("UI.lua")
local dataDisplay = dofile("inputs.lua") -- renamed from dataDisplay_enhanced.lua
local registerThemes = dofile("themes.lua")

-- Initialize
local context = {
    scenes = {},
    elements = {},
    functions = { log = function(msg) end }
}

ui.init(context)
dataDisplay.init(ui)
registerThemes(ui)
ui.setTheme("nordic")  -- Use the Nordic theme

-------------------------------------------------
-- DEMO 1: Slider Showcase
-------------------------------------------------
ui.setScene("sliderDemo")

-- Title
ui.label({
    text = "=== Slider Demo ===",
    position = "topCenter",
    yOffset = 1,
    theme = "primary"
})

-- Horizontal volume slider
local volumeValue = 75
ui.label({
    text = "Volume Control:",
    position = "topLeft",
    xOffset = 2,
    yOffset = 4
})

local volumeSlider = dataDisplay.slider({
    min = 0,
    max = 100,
    value = volumeValue,
    width = 30,
    orientation = "horizontal",
    showValue = true,
    valueFormat = "%.0f",
    theme = "success",
    position = "topLeft",
    xOffset = 2,
    yOffset = 5,
    onChange = function(value)
        volumeValue = value
       
    end
})

-- Temperature slider with steps
ui.label({
    text = "Temperature (°F):",
    position = "topLeft",
    xOffset = 2,
    yOffset = 8
})

local tempSlider = dataDisplay.slider({
    min = 60,
    max = 85,
    value = 72,
    step = 0.5,  -- Half-degree steps
    width = 25,
    orientation = "horizontal",
    showValue = true,
    valueFormat = "%.1f°F",
    theme = "warning",
    position = "topLeft",
    xOffset = 2,
    yOffset = 9,
    onChange = function(value)
       
    end
})

-- Vertical brightness slider
ui.label({
    text = "Brightness",
    position = "topRight",
    xOffset = -10,
    yOffset = 3
})

local brightnessSlider = dataDisplay.slider({
    min = 0,
    max = 100,
    value = 50,
    width = 3,
    height = 12,
    orientation = "vertical",
    showValue = true,
    theme = "info",
    position = "topRight",
    xOffset = -8,
    yOffset = 4,
    onChange = function(value)
       
    end
})

-- Navigation button
ui.button({
    text = "Next: Button Groups",
    theme = "primary",
    position = "bottomCenter",
    yOffset = -2,
    onclick = function()
        ui.setScene("buttonGroupDemo")
    end
})

-------------------------------------------------
-- DEMO 2: Button Group / Radio Group Showcase
-------------------------------------------------
ui.setScene("buttonGroupDemo")

ui.label({
    text = "=== Button Group Demo ===",
    position = "topCenter",
    yOffset = 1,
    theme = "primary"
})

-- Horizontal difficulty selector
ui.label({
    text = "Game Difficulty:",
    position = "topLeft",
    xOffset = 2,
    yOffset = 4
})

local difficultyGroup = dataDisplay.buttonGroup({
    options = {"Easy", "Normal", "Hard", "Expert"},
    selected = 2,
    orientation = "horizontal",
    spacing = 2,
    theme = "success",
    position = "topLeft",
    xOffset = 2,
    yOffset = 5,
    
})

-- Vertical quality settings
ui.label({
    text = "Graphics Quality:",
    position = "topLeft",
    xOffset = 2,
    yOffset = 9
})

local qualityGroup = dataDisplay.buttonGroup({
    options = {"Low", "Medium", "High", "Ultra"},
    selected = 3,
    orientation = "vertical",
    spacing = 1,
    theme = "warning",
    position = "topLeft",
    xOffset = 2,
    yOffset = 10,
   
})

-- Yes/No confirmation
ui.label({
    text = "Save changes?",
    position = "topRight",
    xOffset = -20,
    yOffset = 9
})

local confirmGroup = dataDisplay.buttonGroup({
    options = {"Yes", "No"},
    selected = 2,  -- Default to No
    orientation = "horizontal",
    spacing = 3,
    theme = "danger",
    position = "topRight",
    xOffset = -20,
    yOffset = 10,
   
})

-- Navigation buttons
ui.button({
    text = "< Previous",
    position = "bottomLeft",
    xOffset = 2,
    yOffset = -2,
    onclick = function()
        ui.setScene("sliderDemo")
    end
})

ui.button({
    text = "Next: Dropdowns >",
    theme = "primary",
    position = "bottomCenter",
    yOffset = -2,
    onclick = function()
        ui.setScene("dropdownDemo")
    end
})

-------------------------------------------------
-- DEMO 3: Dropdown Menu Showcase
-------------------------------------------------
ui.setScene("dropdownDemo")

ui.label({
    text = "=== Dropdown Menu Demo ===",
    position = "topCenter",
    yOffset = 1,
    theme = "primary"
})

-- Simple country selector (no search)
ui.label({
    text = "Country:",
    position = "topLeft",
    xOffset = 2,
    yOffset = 4
})

local countryDropdown = dataDisplay.dropdown({
    options = {
        "United States",
        "Canada",
        "United Kingdom",
        "Australia",
        "Germany",
        "France",
        "Japan",
        "China",
        "Brazil",
        "India"
    },
    selected = nil,
    placeholder = "Select country...",
    width = 25,
    maxHeight = 6,
    searchable = false,
    theme = "primary",
    position = "topLeft",
    xOffset = 2,
    yOffset = 5,
})

-- Searchable items list
ui.label({
    text = "Item (searchable):",
    position = "topLeft",
    xOffset = 2,
    yOffset = 13
})

local itemDropdown = dataDisplay.dropdown({
    options = {
        "Wooden Sword",
        "Iron Sword",
        "Diamond Sword",
        "Wooden Pickaxe",
        "Iron Pickaxe",
        "Diamond Pickaxe",
        "Leather Armor",
        "Iron Armor",
        "Diamond Armor",
        "Health Potion",
        "Mana Potion",
        "Strength Potion"
    },
    selected = 1,
    placeholder = "Choose item...",
    width = 25,
    maxHeight = 5,
    searchable = true,  -- Enable search
    theme = "success",
    position = "topLeft",
    xOffset = 2,
    yOffset = 14,
   
})

-- Compact resolution selector
ui.label({
    text = "Resolution:",
    position = "topRight",
    xOffset = -28,
    yOffset = 4
})

local resolutionDropdown = dataDisplay.dropdown({
    options = {
        "1920x1080",
        "1680x1050",
        "1600x900",
        "1366x768",
        "1280x720",
        "1024x768"
    },
    selected = 1,
    width = 15,
    maxHeight = 4,
    theme = "info",
    position = "topRight",
    xOffset = -28,
    yOffset = 5,
})

-- Navigation buttons
ui.button({
    text = "< Previous",
    position = "bottomLeft",
    xOffset = 2,
    yOffset = -2,
    onclick = function()
        ui.setScene("buttonGroupDemo")
    end
})

ui.button({
    text = "Complete Demo >",
    theme = "primary",
    position = "bottomCenter",
    yOffset = -2,
    onclick = function()
        ui.setScene("completeDemo")
    end
})

-------------------------------------------------
-- DEMO 4: Complete Integration Demo
-------------------------------------------------
ui.setScene("completeDemo")

ui.label({
    text = "=== Complete Settings Panel ===",
    position = "topCenter",
    yOffset = 1,
    theme = "primary"
})

-- Status message
local statusLabel = ui.label({
    text = "Adjust settings below",
    position = "topCenter",
    yOffset = 2,
    theme = "info"
})

-- Volume slider
ui.label({
    text = "Master Volume:",
    position = "topLeft",
    xOffset = 2,
    yOffset = 5
})

local masterVolume = 80
local masterVolumeSlider = dataDisplay.slider({
    min = 0,
    max = 100,
    value = masterVolume,
    width = 20,
    showValue = true,
    theme = "success",
    position = "topLeft",
    xOffset = 18,
    yOffset = 5,
    onChange = function(value)
        masterVolume = value
        statusLabel.text = "Volume set to " .. value
        ui.markDirty()
    end
})

-- Difficulty selection
ui.label({
    text = "Difficulty:",
    position = "topLeft",
    xOffset = 2,
    yOffset = 8
})

local selectedDifficulty = "Normal"
local finalDifficultyGroup = dataDisplay.buttonGroup({
    options = {"Easy", "Normal", "Hard"},
    selected = 2,
    orientation = "horizontal",
    spacing = 2,
    position = "topLeft",
    xOffset = 18,
    yOffset = 8,
    onChange = function(diff, index)
        selectedDifficulty = diff
        statusLabel.text = "Difficulty: " .. diff
        ui.markDirty()
    end
})

-- Language dropdown
ui.label({
    text = "Language:",
    position = "topLeft",
    xOffset = 2,
    yOffset = 11
})

local selectedLanguage = "English"
local languageDropdown = dataDisplay.dropdown({
    options = {
        "English",
        "Spanish",
        "French",
        "German",
        "Japanese",
        "Chinese"
    },
    selected = 1,
    width = 20,
    maxHeight = 4,
    position = "topLeft",
    xOffset = 18,
    yOffset = 11,
    onChange = function(lang, index)
        selectedLanguage = lang
        statusLabel.text = "Language: " .. lang
        ui.markDirty()
    end
})

-- Theme selector
ui.label({
    text = "Theme:",
    position = "topLeft",
    xOffset = 2,
    yOffset = 14
})

local themeDropdown = dataDisplay.dropdown({
    options = {
        "default",
        "nordic",
        "light",
        "solarizedDark",
        "gruvboxDark",
        "highContrast"
    },
    selected = 2,  -- Nordic
    width = 20,
    maxHeight = 5,
    position = "topLeft",
    xOffset = 18,
    yOffset = 14,
    onChange = function(theme, index)
        ui.setTheme(theme)
        statusLabel.text = "Theme: " .. theme
        ui.markDirty()
    end
})

-- Save button
ui.button({
    text = "Save Settings",
    theme = "success",
    position = "bottomLeft",
    xOffset = 2,
    yOffset = -2,
    onclick = function()
        statusLabel.text = "Settings saved successfully!"
        ui.markDirty()
        print("=== Saved Settings ===")
        print("Volume: " .. masterVolume)
        print("Difficulty: " .. selectedDifficulty)
        print("Language: " .. selectedLanguage)
    end
})

-- Reset button
ui.button({
    text = "Reset to Defaults",
    theme = "warning",
    position = "bottomCenter",
    yOffset = -2,
    onclick = function()
        masterVolumeSlider:setValue(80)
        finalDifficultyGroup:setSelected(2)
        languageDropdown:setSelected(1)
        themeDropdown:setSelected(2)
        statusLabel.text = "Reset to defaults"
        ui.markDirty()
    end
})

-- Back to start
ui.button({
    text = "< Back to Start",
    position = "bottomRight",
    xOffset = -15,
    yOffset = -2,
    onclick = function()
        ui.setScene("sliderDemo")
    end
})

-------------------------------------------------
-- Start the demo
-------------------------------------------------
ui.setScene("sliderDemo")

ui.run()
