-- Complete Text Inputs Test
-- Tests TextField, AdvancedTextField, and TextArea

local ui = dofile("UI.lua")
local inputs = dofile("Inputs.lua")

local context = {
    scenes = {},
    elements = {},
    functions = { log = print }
}

ui.init(context)
inputs.init(ui)

ui.newScene("TextInputsTest")
ui.setScene("TextInputsTest")

-- Title
ui.label({
    text = "=== Text Inputs Test ===",
    position = "topCenter",
    yOffset = 1,
    fg = colors.yellow
})

-- Basic TextField
ui.label({
    text = "Basic TextField:",
    position = "left",
    xOffset = 2,
    yOffset = 4,
    fg = colors.lime
})

ui.textfield({
    width = 25,
    placeholder = "Type here (scrolls when long)...",
    position = "left",
    xOffset = 2,
    yOffset = 5,
    onChange = function(text)
        print("Basic: " .. text)
    end
})

-- Password Field (Masked)
ui.label({
    text = "Password (Masked):",
    position = "left",
    xOffset = 2,
    yOffset = 7,
    fg = colors.orange
})

inputs.advancedTextField({
    width = 25,
    placeholder = "Enter password...",
    masked = true,
    maskChar = "*",
    position = "left",
    xOffset = 2,
    yOffset = 8,
    onChange = function(text)
        print("Password length: " .. #text)
    end,
    onSubmit = function(text)
        print("Password submitted: " .. string.rep("*", #text))
    end
})

-- Autocomplete Field
ui.label({
    text = "Autocomplete (Tab to accept):",
    position = "left",
    xOffset = 2,
    yOffset = 10,
    fg = colors.cyan
})

inputs.advancedTextField({
    width = 30,
    placeholder = "Start typing a command...",
    autocomplete = {
        "help", "list", "edit", "delete", "copy",
        "move", "mkdir", "cd", "cat", "rm"
    },
    position = "left",
    xOffset = 2,
    yOffset = 11,
    onChange = function(text)
        print("Command: " .. text)
    end,
    onAutocomplete = function(text)
        print("Autocompleted: " .. text)
    end,
    onSubmit = function(text)
        print("Execute: " .. text)
    end
})

-- TextArea
ui.label({
    text = "TextArea (multiline):",
    position = "topRight",
    xOffset = -32,
    yOffset = 4,
    fg = colors.pink
})

local textarea = ui.textarea({
    width = 30,
    height = 10,
    lineNumbers = true,
    text = "Welcome to TextArea!\n\nFeatures:\n- Multi-line editing\n- Line numbers\n- Vertical scrolling\n- Arrow key navigation",
    position = "topRight",
    xOffset = -32,
    yOffset = 5,
    onChange = function(text)
        print("TextArea changed (" .. #text .. " chars)")
    end
})

-- Instructions
ui.label({
    text = "Instructions:",
    position = "bottomLeft",
    xOffset = 2,
    yOffset = -7,
    fg = colors.yellow
})

ui.label({
    text = "- Click fields to focus",
    position = "bottomLeft",
    xOffset = 2,
    yOffset = -6
})

ui.label({
    text = "- Tab = Accept suggestion",
    position = "bottomLeft",
    xOffset = 2,
    yOffset = -5
})

ui.label({
    text = "- Enter = Submit (advanced)",
    position = "bottomLeft",
    xOffset = 2,
    yOffset = -4
})

ui.label({
    text = "- Arrow keys = Navigate",
    position = "bottomLeft",
    xOffset = 2,
    yOffset = -3
})

ui.label({
    text = "- PageUp/PageDown = Scroll (textarea)",
    position = "bottomLeft",
    xOffset = 2,
    yOffset = -2
})

print("Text Inputs Test Ready!")
print("")
print("Features demonstrated:")
print("  1. Basic TextField - with scrolling and placeholder")
print("  2. Masked TextField - password field with * characters")
print("  3. Autocomplete TextField - CraftOS-style gray suggestions")
print("  4. TextArea - multi-line editor with line numbers")
print("")
print("Press any key to run...")
os.pullEvent("key")

ui.run({fps = 30})
