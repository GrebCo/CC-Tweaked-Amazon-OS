--[[
    Comprehensive UI Element Demo
    ==============================

    Demonstrates all available UI elements across multiple scenes
    - Main menu with pagination
    - Individual demos for each element type
    - Screen size: 54x19
]]

-- Load UI framework
local ui = dofile("UI.lua")
local inputs = dofile("Inputs.lua")
local dataDisplay = dofile("dataDisplay.lua")

-- Initialize UI
local context = {
    scenes = {},
    elements = {},
    functions = { log = function() end }
}

ui.init(context)
inputs.init(ui)
dataDisplay.init(ui)

-- Load themes
local registerThemes = dofile("themes.lua")
registerThemes(ui)
ui.setTheme("catppuccin")

-- Current menu page
local currentPage = 1
local totalPages = 3

--==============================================================================
-- MAIN MENU (Page 1)
--==============================================================================
ui.newScene("MainMenu1")
ui.setScene("MainMenu1")

ui.label({
    text = "UI Element Showcase",
    position = "topCenter",
    yOffset = 2,
    fg = colors.yellow
})

ui.label({
    text = "Page 1 of " .. totalPages,
    position = "topCenter",
    yOffset = 3,
    fg = colors.lightGray
})

-- Column 1
ui.button({
    text = "Buttons Demo",
    width = 18,
    x = 5,
    y = 6,
    onclick = function()
        ui.setScene("ButtonsDemo")
    end
})

ui.button({
    text = "Labels & Text",
    width = 18,
    x = 5,
    y = 8,
    onclick = function()
        ui.setScene("LabelsDemo")
    end
})

ui.button({
    text = "Checkboxes",
    width = 18,
    x = 5,
    y = 10,
    onclick = function()
        ui.setScene("CheckboxDemo")
    end
})

ui.button({
    text = "Text Fields",
    width = 18,
    x = 5,
    y = 12,
    onclick = function()
        ui.setScene("TextFieldDemo")
    end
})

ui.button({
    text = "Themes",
    width = 18,
    x = 5,
    y = 14,
    onclick = function()
        ui.setScene("ThemesDemo")
    end
})

-- Column 2
ui.button({
    text = "Multiline Text",
    width = 18,
    x = 27,
    y = 6,
    onclick = function()
        ui.setScene("MultilineDemo")
    end
})

ui.button({
    text = "Rectangles",
    width = 18,
    x = 27,
    y = 8,
    onclick = function()
        ui.setScene("RectangleDemo")
    end
})

ui.button({
    text = "Layouts",
    width = 18,
    x = 27,
    y = 10,
    onclick = function()
        ui.setScene("LayoutDemo")
    end
})

ui.button({
    text = "Next Page >",
    width = 18,
    x = 27,
    y = 12,
    onclick = function()
        currentPage = 2
        ui.setScene("MainMenu2")
    end
})

ui.label({
    text = "Press Ctrl+C to exit",
    position = "bottomCenter",
    yOffset = -1,
    fg = colors.lightGray
})

--==============================================================================
-- MAIN MENU (Page 2)
--==============================================================================
ui.newScene("MainMenu2")
ui.setScene("MainMenu2")

ui.label({
    text = "UI Element Showcase",
    position = "topCenter",
    yOffset = 2,
    fg = colors.yellow
})

ui.label({
    text = "Page 2 of " .. totalPages,
    position = "topCenter",
    yOffset = 3,
    fg = colors.lightGray
})

-- Column 1
ui.button({
    text = "Terminal",
    width = 18,
    x = 5,
    y = 6,
    onclick = function()
        ui.setScene("TerminalDemo")
    end
})

ui.button({
    text = "Animated Label",
    width = 18,
    x = 5,
    y = 8,
    onclick = function()
        ui.setScene("AnimatedDemo")
    end
})

ui.button({
    text = "Slider",
    width = 18,
    x = 5,
    y = 10,
    onclick = function()
        ui.setScene("SliderDemo")
    end
})

ui.button({
    text = "Dropdown",
    width = 18,
    x = 5,
    y = 12,
    onclick = function()
        ui.setScene("DropdownDemo")
    end
})

-- Column 2
ui.button({
    text = "Button Group",
    width = 18,
    x = 27,
    y = 6,
    onclick = function()
        ui.setScene("ButtonGroupDemo")
    end
})

ui.button({
    text = "Progress Bars",
    width = 18,
    x = 27,
    y = 8,
    onclick = function()
        ui.setScene("ProgressDemo")
    end
})

ui.button({
    text = "Dialog Demo",
    width = 18,
    x = 27,
    y = 10,
    onclick = function()
        ui.setScene("DialogDemo")
    end
})

ui.button({
    text = "Basic Textfield",
    width = 18,
    x = 27,
    y = 12,
    onclick = function()
        ui.setScene("BasicTextfieldDemo")
    end
})

ui.button({
    text = "< Prev Page",
    width = 18,
    x = 5,
    y = 14,
    onclick = function()
        currentPage = 1
        ui.setScene("MainMenu1")
    end
})

ui.button({
    text = "Next Page >",
    width = 18,
    x = 27,
    y = 14,
    onclick = function()
        currentPage = 3
        ui.setScene("MainMenu3")
    end
})

--==============================================================================
-- MAIN MENU (Page 3)
--==============================================================================
ui.newScene("MainMenu3")
ui.setScene("MainMenu3")

ui.label({
    text = "UI Element Showcase",
    position = "topCenter",
    yOffset = 2,
    fg = colors.yellow
})

ui.label({
    text = "Page 3 of " .. totalPages,
    position = "topCenter",
    yOffset = 3,
    fg = colors.lightGray
})

-- Column 1
ui.button({
    text = "Gauges",
    width = 18,
    x = 5,
    y = 6,
    onclick = function()
        ui.setScene("GaugeDemo")
    end
})

ui.button({
    text = "Tables",
    width = 18,
    x = 5,
    y = 8,
    onclick = function()
        ui.setScene("TableDemo")
    end
})

ui.button({
    text = "Bar Charts",
    width = 18,
    x = 5,
    y = 10,
    onclick = function()
        ui.setScene("BarChartDemo")
    end
})

ui.button({
    text = "< Prev Page",
    width = 18,
    x = 5,
    y = 14,
    onclick = function()
        currentPage = 2
        ui.setScene("MainMenu2")
    end
})

-- Column 2
ui.button({
    text = "Stat Panels",
    width = 18,
    x = 27,
    y = 6,
    onclick = function()
        ui.setScene("StatPanelDemo")
    end
})

ui.button({
    text = "Scrollable List",
    width = 18,
    x = 27,
    y = 8,
    onclick = function()
        ui.setScene("ScrollListDemo")
    end
})

--==============================================================================
-- BUTTONS DEMO
--==============================================================================
ui.newScene("ButtonsDemo")
ui.setScene("ButtonsDemo")

ui.label({
    text = "Buttons Demo",
    position = "topCenter",
    yOffset = 2,
    fg = colors.yellow
})

ui.label({
    text = "Standard Buttons:",
    x = 5,
    y = 5,
    fg = colors.white
})

ui.button({
    text = "Click Me!",
    x = 5,
    y = 7,
    onclick = function()
        print("Button clicked!")
    end
})

ui.button({
    text = "Disabled",
    x = 20,
    y = 7,
    onclick = function()
        print("This button is styled as disabled")
    end
})

ui.label({
    text = "Toggle Buttons:",
    x = 5,
    y = 9,
    fg = colors.white
})

local toggleBtn = ui.button({
    text = "OFF",
    x = 5,
    y = 11,
    toggle = true,
    onclick = function(self)
        if self.state then
            self.text = "ON"
        else
            self.text = "OFF"
        end
    end
})

ui.button({
    text = "Back to Menu",
    position = "bottomCenter",
    yOffset = -1,
    onclick = function()
        ui.setScene("MainMenu" .. currentPage)
    end
})

--==============================================================================
-- THEMES DEMO
--==============================================================================
ui.newScene("ThemesDemo")
ui.setScene("ThemesDemo")

ui.label({
    text = "Themes Demo - Click to Switch",
    position = "topCenter",
    yOffset = 2,
    fg = colors.yellow
})

local currentThemeLabel = ui.label({
    text = "Current: catppuccin",
    position = "topCenter",
    yOffset = 3,
    fg = colors.white
})

-- All available themes
local allThemes = {
    "catppuccin", "gruvbox", "nord", "dracula",
    "tokyonight", "onedark", "solarized", "monokai",
    "material", "rosepine", "everforest", "ayu", "default"
}

-- Column 1
ui.button({
    text = "Catppuccin",
    width = 16,
    x = 3,
    y = 6,
    onclick = function()
        ui.setTheme("catppuccin")
        currentThemeLabel.text = "Current: catppuccin"
    end
})

ui.button({
    text = "Gruvbox",
    width = 16,
    x = 3,
    y = 8,
    onclick = function()
        ui.setTheme("gruvbox")
        currentThemeLabel.text = "Current: gruvbox"
    end
})

ui.button({
    text = "Nord",
    width = 16,
    x = 3,
    y = 10,
    onclick = function()
        ui.setTheme("nord")
        currentThemeLabel.text = "Current: nord"
    end
})

ui.button({
    text = "Dracula",
    width = 16,
    x = 3,
    y = 12,
    onclick = function()
        ui.setTheme("dracula")
        currentThemeLabel.text = "Current: dracula"
    end
})

ui.button({
    text = "Tokyo Night",
    width = 16,
    x = 3,
    y = 14,
    onclick = function()
        ui.setTheme("tokyonight")
        currentThemeLabel.text = "Current: tokyonight"
    end
})

-- Column 2
ui.button({
    text = "One Dark",
    width = 16,
    x = 21,
    y = 6,
    onclick = function()
        ui.setTheme("onedark")
        currentThemeLabel.text = "Current: onedark"
    end
})

ui.button({
    text = "Solarized",
    width = 16,
    x = 21,
    y = 8,
    onclick = function()
        ui.setTheme("solarized")
        currentThemeLabel.text = "Current: solarized"
    end
})

ui.button({
    text = "Monokai",
    width = 16,
    x = 21,
    y = 10,
    onclick = function()
        ui.setTheme("monokai")
        currentThemeLabel.text = "Current: monokai"
    end
})

ui.button({
    text = "Material",
    width = 16,
    x = 21,
    y = 12,
    onclick = function()
        ui.setTheme("material")
        currentThemeLabel.text = "Current: material"
    end
})

ui.button({
    text = "Rose Pine",
    width = 16,
    x = 21,
    y = 14,
    onclick = function()
        ui.setTheme("rosepine")
        currentThemeLabel.text = "Current: rosepine"
    end
})

-- Column 3
ui.button({
    text = "Everforest",
    width = 16,
    x = 39,
    y = 6,
    onclick = function()
        ui.setTheme("everforest")
        currentThemeLabel.text = "Current: everforest"
    end
})

ui.button({
    text = "Ayu",
    width = 16,
    x = 39,
    y = 8,
    onclick = function()
        ui.setTheme("ayu")
        currentThemeLabel.text = "Current: ayu"
    end
})

ui.button({
    text = "Default",
    width = 16,
    x = 39,
    y = 10,
    onclick = function()
        ui.setTheme("default")
        currentThemeLabel.text = "Current: default"
    end
})

ui.button({
    text = "Paper Light",
    width = 16,
    x = 39,
    y = 12,
    onclick = function()
        ui.setTheme("paper")
        currentThemeLabel.text = "Current: paper"
    end
})

ui.button({
    text = "Solarized Light",
    width = 16,
    x = 39,
    y = 14,
    onclick = function()
        ui.setTheme("solarized_light")
        currentThemeLabel.text = "Current: solarized_light"
    end
})

ui.button({
    text = "Gruvbox Light",
    width = 16,
    x = 3,
    y = 16,
    onclick = function()
        ui.setTheme("gruvbox_light")
        currentThemeLabel.text = "Current: gruvbox_light"
    end
})

ui.button({
    text = "Back to Menu",
    position = "bottomCenter",
    yOffset = -1,
    bg = colors.gray,
    onclick = function()
        ui.setScene("MainMenu" .. currentPage)
    end
})

--==============================================================================
-- LABELS DEMO
--==============================================================================
ui.newScene("LabelsDemo")
ui.setScene("LabelsDemo")

ui.label({
    text = "Labels & Text Demo",
    position = "topCenter",
    yOffset = 2,
    fg = colors.yellow
})

ui.label({
    text = "Standard label with default colors",
    x = 5,
    y = 6
})

ui.label({
    text = "Colored label",
    x = 5,
    y = 8,
    fg = colors.lime
})

ui.label({
    text = "Label with background",
    x = 5,
    y = 10,
    fg = colors.white,
    bg = colors.blue
})

ui.animatedLabel({
    frames = {"Loading.", "Loading..", "Loading..."},
    x = 5,
    y = 12,
    fg = colors.cyan,
    frameDuration = 0.5
})

ui.button({
    text = "Back to Menu",
    position = "bottomCenter",
    yOffset = -1,
    bg = colors.gray,
    onclick = function()
        ui.setScene("MainMenu" .. currentPage)
    end
})

--==============================================================================
-- CHECKBOX DEMO
--==============================================================================
ui.newScene("CheckboxDemo")
ui.setScene("CheckboxDemo")

ui.label({
    text = "Checkboxes Demo",
    position = "topCenter",
    yOffset = 2,
    fg = colors.yellow
})

local settings = {
    option1 = false,
    option2 = true,
    option3 = false
}

ui.checkbox({
    text = "Enable notifications",
    x = 5,
    y = 6,
    initial = settings.option1,
    onclick = function(self, checked)
        settings.option1 = checked
        print("Notifications: " .. tostring(checked))
    end
})

ui.checkbox({
    text = "Auto-save (checked by default)",
    x = 5,
    y = 8,
    initial = settings.option2,
    onclick = function(self, checked)
        settings.option2 = checked
    end
})

ui.checkbox({
    text = "Dark mode",
    x = 5,
    y = 10,
    initial = settings.option3,
    onclick = function(self, checked)
        settings.option3 = checked
    end
})

ui.button({
    text = "Back to Menu",
    position = "bottomCenter",
    yOffset = -1,
    bg = colors.gray,
    onclick = function()
        ui.setScene("MainMenu" .. currentPage)
    end
})

--==============================================================================
-- TEXT FIELD DEMO
--==============================================================================
ui.newScene("TextFieldDemo")
ui.setScene("TextFieldDemo")

ui.label({
    text = "Text Fields Demo",
    position = "topCenter",
    yOffset = 2,
    fg = colors.yellow
})

ui.label({
    text = "Name:",
    x = 5,
    y = 6
})

inputs.advancedTextField({
    width = 25,
    placeholder = "Enter your name...",
    x = 12,
    y = 6,
    onChange = function(text)
        print("Name: " .. text)
    end
})

ui.label({
    text = "Email (type 'u', 'a', or 't' then press Tab):",
    x = 5,
    y = 9
})

inputs.advancedTextField({
    width = 35,
    placeholder = "user@example.com",
    autocomplete = {"user@example.com", "admin@example.com", "test@example.com"},
    x = 5,
    y = 10
})

ui.label({
    text = "Password:",
    x = 5,
    y = 13
})

inputs.advancedTextField({
    width = 25,
    placeholder = "Enter password...",
    masked = true,
    x = 15,
    y = 13
})

ui.button({
    text = "Back to Menu",
    position = "bottomCenter",
    yOffset = -1,
    bg = colors.gray,
    onclick = function()
        ui.setScene("MainMenu" .. currentPage)
    end
})

--==============================================================================
-- MULTILINE TEXT DEMO
--==============================================================================
ui.newScene("MultilineDemo")
ui.setScene("MultilineDemo")

ui.label({
    text = "Multiline TextField Demo",
    position = "topCenter",
    yOffset = 2,
    fg = colors.yellow
})

ui.label({
    text = "Set height > 1 to enable multiline mode:",
    x = 5,
    y = 4,
    fg = colors.lightGray
})

ui.label({
    text = "- Line numbers, scrolling, page up/down, Ctrl+Enter to submit",
    x = 5,
    y = 5,
    fg = colors.lightGray
})

inputs.advancedTextField({
    width = 44,
    height = 10,
    lineNumbers = true,
    text = "-- Multi-line text editor\nfunction hello()\n    print(\"Hello, world!\")\nend\n\nhello()",
    x = 5,
    y = 7
})

ui.button({
    text = "Back to Menu",
    position = "bottomCenter",
    yOffset = -1,
    bg = colors.gray,
    onclick = function()
        ui.setScene("MainMenu" .. currentPage)
    end
})

--==============================================================================
-- RECTANGLE DEMO
--==============================================================================
ui.newScene("RectangleDemo")
ui.setScene("RectangleDemo")

ui.label({
    text = "Rectangles Demo (with Child Positioning)",
    position = "topCenter",
    yOffset = 2,
    fg = colors.yellow
})

-- Simple rectangles
ui.rectangle({
    width = 20,
    height = 5,
    x = 5,
    y = 5,
    bg = colors.blue,
    border = false
})

ui.rectangle({
    width = 20,
    height = 5,
    x = 28,
    y = 5,
    bg = colors.lime,
    border = true,
    borderColor = colors.green
})

-- Rectangle with centered child
ui.rectangle({
    width = 30,
    height = 6,
    x = 5,
    y = 11,
    bg = colors.purple,
    border = true,
    borderColor = colors.magenta,
    padding = 1,
    builder = function(container)
        container:addChild(ui.label({
            text = "Centered Content",
            position = "center",
            fg = colors.yellow
        }))
    end
})

-- Draggable rectangle with positioned children
local dragRect = ui.rectangle({
    width = 32,
    height = 6,
    position = "bottomCenter",
    yOffset = -2,
    bg = colors.gray,
    border = true,
    borderColor = colors.lightBlue,
    draggable = true,
    padding = 1,
    builder = function(container)
        container:addChild(ui.label({
            text = "Drag me!",
            position = "topCenter",
            fg = colors.yellow
        }))

        container:addChild(ui.label({
            text = "With positioned children",
            position = "center",
            fg = colors.white
        }))
    end
})

ui.addShadow(dragRect, {
    fg = colors.gray,
    bg = colors.black
})

ui.button({
    text = "Back to Menu",
    position = "bottomCenter",
    yOffset = -1,
    bg = colors.gray,
    onclick = function()
        ui.setScene("MainMenu" .. currentPage)
    end
})

--==============================================================================
-- LAYOUT DEMO (VStack, HStack, Grid)
--==============================================================================
ui.newScene("LayoutDemo")
ui.setScene("LayoutDemo")

ui.label({
    text = "Layouts Demo",
    position = "topCenter",
    yOffset = 2,
    fg = colors.yellow
})

-- VStack example
ui.label({
    text = "VStack:",
    x = 3,
    y = 5,
    fg = colors.cyan
})

ui.vstack({
    x = 3,
    y = 6,
    spacing = 0,
    builder = function(stack)
        ui.label({ parent = stack, text = "Item 1", bg = colors.blue })
        ui.label({ parent = stack, text = "Item 2", bg = colors.lightBlue })
        ui.label({ parent = stack, text = "Item 3", bg = colors.cyan })
    end
})

-- HStack example
ui.label({
    text = "HStack:",
    x = 20,
    y = 5,
    fg = colors.lime
})

ui.hstack({
    x = 20,
    y = 6,
    spacing = 1,
    builder = function(stack)
        ui.button({ parent = stack, text = "A", width = 3, bg = colors.lime })
        ui.button({ parent = stack, text = "B", width = 3, bg = colors.green })
        ui.button({ parent = stack, text = "C", width = 3, bg = colors.lime })
    end
})

-- Grid example
ui.label({
    text = "Grid:",
    x = 3,
    y = 11,
    fg = colors.orange
})

ui.grid({
    x = 3,
    y = 12,
    columns = 3,
    columnSpacing = 2,
    rowSpacing = 1,
    builder = function(grid)
        for i = 1, 6 do
            ui.label({
                parent = grid,
                text = " " .. tostring(i) .. " ",  -- Add padding for visibility
                bg = colors.orange,
                fg = colors.white
            })
        end
    end
})

ui.button({
    text = "Back to Menu",
    position = "bottomCenter",
    yOffset = -1,
    bg = colors.gray,
    onclick = function()
        ui.setScene("MainMenu" .. currentPage)
    end
})

--==============================================================================
-- TERMINAL DEMO
--==============================================================================
ui.newScene("TerminalDemo")
ui.setScene("TerminalDemo")

ui.label({
    text = "Terminal Demo (Composition-based)",
    position = "topCenter",
    yOffset = 2,
    fg = colors.yellow
})

ui.label({
    text = "Uses UI.textfield internally - click to focus, position cursor!",
    position = "topCenter",
    yOffset = 3,
    fg = colors.lightGray
})

local console = inputs.terminal({
    width = 44,
    height = 11,
    x = 5,
    y = 5
})

console:append("=== System Initialized ===")
console:append("Terminal is now built from UI elements:")
console:append("  - Rectangle for container")
console:append("  - Textfield for input (with cursor!)")
console:append("  - Labels for prompts/spinners")
console:append("")
console:append("Try: help, clear, count, echo <text>")

-- Add some demo functionality
local commandCount = 0
local commandHistory = {}

local function newPrompt()
    console:prompt(">", function(input)
        commandCount = commandCount + 1

        -- Add to history (don't add empty commands)
        if input ~= "" then
            table.insert(commandHistory, input)
        end

        if input == "help" then
            console:append("Available commands:")
            console:append("  help     - Show this help")
            console:append("  clear    - Clear terminal")
            console:append("  count    - Show command count")
            console:append("  echo ... - Echo text back")
            console:append("  history  - Show command history")
            console:append("")
            console:append("TIP: Use UP/DOWN arrows for history!")
            console:append("TIP: Press TAB for autocomplete!")
        elseif input == "clear" then
            console:clear()
            console:append("Terminal cleared!")
        elseif input == "count" then
            console:append("Commands executed: " .. commandCount)
        elseif input:sub(1, 5) == "echo " then
            console:append(input:sub(6))
        elseif input == "history" then
            console:append("Command history:")
            for i, cmd in ipairs(commandHistory) do
                console:append("  " .. i .. ". " .. cmd)
            end
        elseif input ~= "" then
            console:append("Unknown command: '" .. input .. "' (try 'help')")
        end

        newPrompt()
    end, {
        history = commandHistory,
        autocomplete = {"help", "clear", "count", "echo ", "history"}
    })
end

newPrompt()

ui.button({
    text = "Back to Menu",
    position = "bottomCenter",
    yOffset = -1,
    bg = colors.gray,
    onclick = function()
        ui.setScene("MainMenu" .. currentPage)
    end
})

--==============================================================================
-- ANIMATED LABEL DEMO
--==============================================================================
ui.newScene("AnimatedDemo")
ui.setScene("AnimatedDemo")

ui.label({
    text = "Animated Label Demo",
    position = "topCenter",
    yOffset = 2,
    fg = colors.yellow
})

ui.animatedLabel({
    frames = {"[    ]", "[=   ]", "[==  ]", "[=== ]", "[====]", "[ ===]", "[  ==]", "[   =]"},
    x = 15,
    y = 7,
    fg = colors.cyan,
    frameDuration = 0.1
})

ui.animatedLabel({
    frames = {"/", "-", "\\", "|"},
    x = 25,
    y = 9,
    fg = colors.lime,
    frameDuration = 0.15
})

ui.animatedLabel({
    frames = {"Loading", "Loading.", "Loading..", "Loading..."},
    x = 15,
    y = 11,
    fg = colors.lightBlue,
    frameDuration = 0.4
})

ui.button({
    text = "Back to Menu",
    position = "bottomCenter",
    yOffset = -1,
    bg = colors.gray,
    onclick = function()
        ui.setScene("MainMenu" .. currentPage)
    end
})

--==============================================================================
-- SLIDER DEMO
--==============================================================================
ui.newScene("SliderDemo")
ui.setScene("SliderDemo")

ui.label({
    text = "Slider Demo",
    position = "topCenter",
    yOffset = 2,
    fg = colors.yellow
})

local valueLabel = ui.label({
    text = "Volume: 50%",
    x = 5,
    y = 6,
    fg = colors.white
})

inputs.slider({
    x = 5,
    y = 8,
    width = 30,
    min = 0,
    max = 100,
    value = 50,
    onChange = function(value)
        valueLabel.text = "Volume: " .. value .. "%"
    end
})

local brightnessLabel = ui.label({
    text = "Brightness: 75%",
    x = 5,
    y = 11,
    fg = colors.white
})

inputs.slider({
    x = 5,
    y = 13,
    width = 30,
    min = 0,
    max = 100,
    value = 75,
    fillColor = colors.orange,
    onChange = function(value)
        brightnessLabel.text = "Brightness: " .. value .. "%"
    end
})

ui.button({
    text = "Back to Menu",
    position = "bottomCenter",
    yOffset = -1,
    bg = colors.gray,
    onclick = function()
        ui.setScene("MainMenu" .. currentPage)
    end
})

--==============================================================================
-- DROPDOWN DEMO
--==============================================================================
ui.newScene("DropdownDemo")
ui.setScene("DropdownDemo")

ui.label({
    text = "Dropdown Demo",
    position = "topCenter",
    yOffset = 2,
    fg = colors.yellow
})

local selectionLabel = ui.label({
    text = "Selected: Apple",
    x = 5,
    y = 6,
    fg = colors.white
})

inputs.dropdown({
    x = 5,
    y = 8,
    width = 20,
    options = {"Apple", "Banana", "Cherry", "Date", "Elderberry"},
    selected = 1,
    onChange = function(index, value)
        selectionLabel.text = "Selected: " .. value
    end
})

ui.button({
    text = "Back to Menu",
    position = "bottomCenter",
    yOffset = -1,
    bg = colors.gray,
    onclick = function()
        ui.setScene("MainMenu" .. currentPage)
    end
})

--==============================================================================
-- BUTTON GROUP DEMO
--==============================================================================
ui.newScene("ButtonGroupDemo")
ui.setScene("ButtonGroupDemo")

ui.label({
    text = "Button Group Demo",
    position = "topCenter",
    yOffset = 2,
    fg = colors.yellow
})

local groupLabel = ui.label({
    text = "Selected: Option 1",
    x = 5,
    y = 6,
    fg = colors.white
})

inputs.buttonGroup({
    x = 5,
    y = 8,
    options = {"Option 1", "Option 2", "Option 3"},
    selected = 1,
    onChange = function(index, value)
        groupLabel.text = "Selected: " .. value
    end
})

ui.label({
    text = "Vertical layout:",
    x = 5,
    y = 12,
    fg = colors.lightGray
})

inputs.buttonGroup({
    x = 5,
    y = 13,
    options = {"A", "B", "C"},
    layout = "vertical",
    selected = 1
})

ui.button({
    text = "Back to Menu",
    position = "bottomCenter",
    yOffset = -1,
    bg = colors.gray,
    onclick = function()
        ui.setScene("MainMenu" .. currentPage)
    end
})

--==============================================================================
-- PROGRESS BAR DEMO
--==============================================================================
ui.newScene("ProgressDemo")
ui.setScene("ProgressDemo")

ui.label({
    text = "Progress Bars Demo",
    position = "topCenter",
    yOffset = 2,
    fg = colors.yellow
})

dataDisplay.progressBar({
    label = "CPU Usage",
    x = 5,
    y = 6,
    width = 30,
    progress = 0.65,
    fillColor = colors.lime
})

dataDisplay.progressBar({
    label = "Memory",
    x = 5,
    y = 9,
    width = 30,
    progress = 0.82,
    fillColor = colors.orange
})

dataDisplay.progressBar({
    label = "Disk",
    x = 5,
    y = 12,
    width = 30,
    progress = 0.45,
    fillColor = colors.cyan
})

ui.button({
    text = "Back to Menu",
    position = "bottomCenter",
    yOffset = -1,
    bg = colors.gray,
    onclick = function()
        ui.setScene("MainMenu" .. currentPage)
    end
})

--==============================================================================
-- DIALOG DEMO
--==============================================================================
ui.newScene("DialogDemo")
ui.setScene("DialogDemo")

ui.label({
    text = "Dialog Demo",
    position = "topCenter",
    yOffset = 2,
    fg = colors.yellow
})

local dialogStatusLabel = ui.label({
    text = "Click a button to show a dialog",
    position = "center",
    yOffset = -3,
    fg = colors.white
})

-- Simple dialog
ui.button({
    text = "Show Confirm Dialog",
    position = "center",
    yOffset = -1,
    width = 22,
    bg = colors.blue,
    onclick = function()
        local dialog = ui.dialog({
            title = "Confirm Action",
            content = "Are you sure you want to continue?",
            width = 35,
            height = 10,
            buttons = {
                {
                    text = "  OK  ",
                    onClick = function()
                        dialogStatusLabel.text = "OK was clicked!"
                        ui.markDirty()
                    end
                },
                {
                    text = "Cancel",
                    onClick = function()
                        dialogStatusLabel.text = "Cancelled"
                        ui.markDirty()
                    end
                }
            }
        })
    end
})

-- Dialog with custom content using rectangle
ui.button({
    text = "Show Custom Dialog",
    position = "center",
    yOffset = 1,
    width = 22,
    bg = colors.lime,
    onclick = function()
        -- Create overlay
        local overlay = ui.rectangle({
            width = 51,
            height = 19,
            x = 1,
            y = 1,
            bg = colors.black,
            fg = colors.gray,
            scene = "DialogDemo"
        })

        -- Create dialog with custom content
        local dialog = ui.rectangle({
            width = 38,
            height = 14,
            position = "center",
            border = true,
            bg = colors.gray,
            borderColor = colors.lightBlue,
            padding = 2,
            scene = "DialogDemo",
            builder = function(rect)
                -- Title
                rect:addChild(ui.label({
                    text = "Settings",
                    position = "topCenter",
                    fg = colors.yellow
                }))

                -- Volume label
                rect:addChild(ui.label({
                    text = "Volume:",
                    position = "topLeft",
                    xOffset = 2,
                    yOffset = 2
                }))

                -- Volume slider
                rect:addChild(inputs.slider({
                    position = "topLeft",
                    xOffset = 2,
                    yOffset = 3,
                    width = 20,
                    min = 0,
                    max = 100,
                    value = 50
                }))

                -- Checkbox
                rect:addChild(ui.checkbox({
                    text = "Enable notifications",
                    position = "topLeft",
                    xOffset = 2,
                    yOffset = 5,
                    initial = true
                }))

                -- Save button
                rect:addChild(ui.button({
                    text = "Save",
                    position = "bottomCenter",
                    onclick = function()
                        dialogStatusLabel.text = "Settings saved!"
                        ui.hide(dialog)
                        ui.hide(overlay)
                        ui.markDirty()
                    end
                }))
            end
        })
    end
})

ui.button({
    text = "Back to Menu",
    position = "bottomCenter",
    yOffset = -1,
    bg = colors.gray,
    onclick = function()
        ui.setScene("MainMenu" .. currentPage)
    end
})

--==============================================================================
-- BASIC TEXTFIELD DEMO (from UI.lua)
--==============================================================================
ui.newScene("BasicTextfieldDemo")
ui.setScene("BasicTextfieldDemo")

ui.label({
    text = "Basic Textfield Demo (UI.lua)",
    position = "topCenter",
    yOffset = 2,
    fg = colors.yellow
})

ui.label({
    text = "Single-line (height=1):",
    x = 5,
    y = 5,
    fg = colors.white
})

local singleLineStatus = ui.label({
    text = "Type something...",
    x = 5,
    y = 9,
    fg = colors.lightGray
})

ui.textfield({
    width = 35,
    placeholder = "Basic single-line input...",
    x = 5,
    y = 7,
    onChange = function(text)
        singleLineStatus.text = "You typed: " .. (text ~= "" and text or "(nothing)")
        ui.markDirty()
    end
})

ui.label({
    text = "Multi-line (height>1):",
    x = 5,
    y = 11,
    fg = colors.white
})

ui.textfield({
    width = 44,
    height = 6,
    text = "Line 1\nLine 2\nLine 3",
    x = 5,
    y = 13,
    onChange = function(text)
        -- Count lines
        local lineCount = 1
        for _ in text:gmatch("\n") do
            lineCount = lineCount + 1
        end
        singleLineStatus.text = "Lines: " .. lineCount .. " | Chars: " .. #text
        ui.markDirty()
    end
})

ui.button({
    text = "Back to Menu",
    position = "bottomCenter",
    yOffset = -1,
    bg = colors.gray,
    onclick = function()
        ui.setScene("MainMenu" .. currentPage)
    end
})

--==============================================================================
-- GAUGE DEMO
--==============================================================================
ui.newScene("GaugeDemo")
ui.setScene("GaugeDemo")

ui.label({
    text = "Gauges Demo",
    position = "topCenter",
    yOffset = 2,
    fg = colors.yellow
})

dataDisplay.gauge({
    label = "Speed",
    x = 5,
    y = 6,
    width = 15,
    height = 7,
    value = 65,
    max = 100,
    unit = "mph"
})

dataDisplay.gauge({
    label = "Power",
    x = 25,
    y = 6,
    width = 15,
    height = 7,
    value = 8500,
    max = 10000,
    unit = "W"
})

ui.button({
    text = "Back to Menu",
    position = "bottomCenter",
    yOffset = -1,
    bg = colors.gray,
    onclick = function()
        ui.setScene("MainMenu" .. currentPage)
    end
})

--==============================================================================
-- TABLE DEMO
--==============================================================================
ui.newScene("TableDemo")
ui.setScene("TableDemo")

ui.label({
    text = "Table Demo",
    position = "topCenter",
    yOffset = 2,
    fg = colors.yellow
})

dataDisplay.table({
    x = 5,
    y = 5,
    headers = {"Name", "Age", "City"},
    rows = {
        {"Alice", "25", "NYC"},
        {"Bob", "30", "LA"},
        {"Charlie", "28", "Chicago"},
        {"Diana", "32", "Boston"}
    },
    columnWidths = {12, 5, 12}
})

ui.button({
    text = "Back to Menu",
    position = "bottomCenter",
    yOffset = -1,
    bg = colors.gray,
    onclick = function()
        ui.setScene("MainMenu" .. currentPage)
    end
})

--==============================================================================
-- BAR CHART DEMO
--==============================================================================
ui.newScene("BarChartDemo")
ui.setScene("BarChartDemo")

ui.label({
    text = "Bar Chart Demo",
    position = "topCenter",
    yOffset = 2,
    fg = colors.yellow
})

dataDisplay.barChart({
    x = 8,
    y = 6,
    width = 38,
    height = 8,
    data = {
        {label = "Jan", value = 45},
        {label = "Feb", value = 62},
        {label = "Mar", value = 38},
        {label = "Apr", value = 71},
        {label = "May", value = 55}
    }
})

ui.button({
    text = "Back to Menu",
    position = "bottomCenter",
    yOffset = -1,
    bg = colors.gray,
    onclick = function()
        ui.setScene("MainMenu" .. currentPage)
    end
})

--==============================================================================
-- STAT PANEL DEMO
--==============================================================================
ui.newScene("StatPanelDemo")
ui.setScene("StatPanelDemo")

ui.label({
    text = "Stat Panels Demo",
    position = "topCenter",
    yOffset = 2,
    fg = colors.yellow
})

dataDisplay.statPanel({
    x = 5,
    y = 6,
    width = 14,
    height = 5,
    label = "Users",
    value = "1,247",
    color = colors.lime
})

dataDisplay.statPanel({
    x = 22,
    y = 6,
    width = 14,
    height = 5,
    label = "Revenue",
    value = "$8.5K",
    color = colors.orange
})

dataDisplay.statPanel({
    x = 39,
    y = 6,
    width = 14,
    height = 5,
    label = "Tasks",
    value = "42",
    color = colors.cyan
})

ui.button({
    text = "Back to Menu",
    position = "bottomCenter",
    yOffset = -1,
    bg = colors.gray,
    onclick = function()
        ui.setScene("MainMenu" .. currentPage)
    end
})

--==============================================================================
-- SCROLLABLE LIST DEMO
--==============================================================================
ui.newScene("ScrollListDemo")
ui.setScene("ScrollListDemo")

ui.label({
    text = "Scrollable List Demo",
    position = "topCenter",
    yOffset = 2,
    fg = colors.yellow
})

local items = {}
for i = 1, 20 do
    table.insert(items, "List Item #" .. i)
end

dataDisplay.scrollableList({
    x = 12,
    y = 5,
    width = 30,
    height = 10,
    items = items,
    onSelect = function(index, item)
        print("Selected: " .. item)
    end
})

ui.button({
    text = "Back to Menu",
    position = "bottomCenter",
    yOffset = -1,
    bg = colors.gray,
    onclick = function()
        ui.setScene("MainMenu" .. currentPage)
    end
})

--==============================================================================
-- START THE APPLICATION
--==============================================================================

-- Go to first menu page
ui.setScene("MainMenu1")

-- Run the UI
ui.run({fps = 30})
