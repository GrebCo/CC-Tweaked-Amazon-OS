--[[ ====================================================================
  TextArea Demo - Demonstrates the new TextArea element

  Features demonstrated:
  - Multi-line text editing
  - Line numbers
  - Scrolling
  - Theme support
  - Read-only mode
  - onChange/onSubmit callbacks
==================================================================== ]]--

-- Load UI framework
local UI = dofile("UI.lua")
local dataDisplay = dofile("Inputs.lua")
dataDisplay.init(UI)

-- Load themes
dofile("themes.lua")(UI)

-- Create context
local context = {
    elements = {},
    scenes = {},
    functions = { log = print }
}

UI.init(context)
UI.setTheme("nordic")

-- Create main scene
UI.newScene("TextAreaDemo")
UI.setScene("TextAreaDemo")

local w, h = term.getSize()

-- Title
UI.label({
    text = "TextArea Demo - Type to edit, Ctrl+Enter to save, Esc to exit",
    position = "topCenter",
    fg = colors.yellow
})

-- Status label
local statusLabel = UI.label({
    text = "Ready",
    position = "bottom",
    fg = colors.lime
})

-- Create text area with line numbers
local editor = dataDisplay.textArea({
    text = "-- Welcome to TextArea!\n-- This is a multi-line text editor.\n\nFeatures:\n- Line numbers\n- Scrolling (mouse wheel, PageUp/Down)\n- Arrow key navigation\n- Home/End keys\n- Click to position cursor\n- Enter for new lines\n- Backspace/Delete\n\nTry typing something!",
    width = w - 4,
    height = h - 6,
    lineNumbers = true,
    position = "center",
    onChange = function(text)
        UI.updateLabel(statusLabel, "Modified - Lines: " .. select(2, text:gsub("\n", "\n")) + 1 .. " Chars: " .. #text)
    end,
    onSubmit = function(text)
        UI.updateLabel(statusLabel, "Saved! (" .. #text .. " characters)")
    end
})

-- Read-only info panel
UI.label({
    text = "Info Panel (Read-only):",
    x = 2,
    y = h - 3,
    fg = colors.orange
})

local infoArea = dataDisplay.textArea({
    text = "This is a read-only\ntext area. You can\nscroll but not edit.",
    width = 25,
    height = 3,
    x = 2,
    y = h - 2,
    lineNumbers = false,
    readOnly = true,
    theme = "info"
})

-- Exit button
UI.button({
    text = "Exit",
    width = 8,
    height = 1,
    position = "topRight",
    bg = colors.red,
    colorPressed = colors.orange,
    onclick = function()
        print("\nExiting TextArea Demo...")
        print("\nFinal text:")
        print(editor:getText())
        os.sleep(2)
        os.reboot()
    end
})

-- Clear button
UI.button({
    text = "Clear",
    width = 8,
    height = 1,
    x = w - 17,
    y = 1,
    bg = colors.orange,
    colorPressed = colors.yellow,
    onclick = function()
        editor:setText("")
        UI.updateLabel(statusLabel, "Cleared")
    end
})

-- Sample text button
UI.button({
    text = "Load Sample",
    width = 14,
    height = 1,
    x = w - 32,
    y = 1,
    bg = colors.blue,
    colorPressed = colors.lightBlue,
    onclick = function()
        editor:setText("function greet(name)\n    print(\"Hello, \" .. name .. \"!\")\nend\n\ngreet(\"World\")\n\n-- This is sample Lua code\n-- Try editing it!")
        UI.updateLabel(statusLabel, "Loaded sample code")
    end
})

-- Run the UI
print("Starting TextArea Demo...")
UI.run({fps = 30})
