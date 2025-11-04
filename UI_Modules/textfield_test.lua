-- TextField Test
-- Tests improved textfield with scrolling and placeholder

local ui = dofile("UI.lua")

local context = {
    scenes = {},
    elements = {},
    functions = { log = print }
}

ui.init(context)
ui.newScene("Test")
ui.setScene("Test")

-- Title
ui.label({
    text = "TextField Test",
    position = "topCenter",
    yOffset = 1,
    fg = colors.yellow
})

-- Test 1: Basic textfield
ui.label({
    text = "Basic:",
    position = "left",
    xOffset = 2,
    yOffset = 4
})

ui.textfield({
    width = 20,
    position = "left",
    xOffset = 10,
    yOffset = 4
})

-- Test 2: With placeholder
ui.label({
    text = "Placeholder:",
    position = "left",
    xOffset = 2,
    yOffset = 6
})

ui.textfield({
    width = 20,
    placeholder = "Enter your name...",
    position = "left",
    xOffset = 15,
    yOffset = 6
})

-- Test 3: Long text scrolling
ui.label({
    text = "Long text:",
    position = "left",
    xOffset = 2,
    yOffset = 8
})

ui.textfield({
    width = 15,
    text = "This is a very long text that should scroll",
    position = "left",
    xOffset = 13,
    yOffset = 8,
    onChange = function(text)
        print("Changed: " .. text)
    end
})

-- Test 4: Multiple fields
ui.label({
    text = "Form:",
    position = "left",
    xOffset = 2,
    yOffset = 11,
    fg = colors.cyan
})

ui.label({
    text = "Name:",
    position = "left",
    xOffset = 4,
    yOffset = 12
})

ui.textfield({
    width = 20,
    placeholder = "First name",
    position = "left",
    xOffset = 11,
    yOffset = 12
})

ui.label({
    text = "Email:",
    position = "left",
    xOffset = 4,
    yOffset = 14
})

ui.textfield({
    width = 25,
    placeholder = "user@example.com",
    position = "left",
    xOffset = 11,
    yOffset = 14
})

print("TextField test ready!")
print("Features:")
print("- Horizontal scrolling for long text")
print("- Placeholder text when empty")
print("- onChange callback")
print("- < and > indicators when scrolling")
print("")
print("Press any key to run...")
os.pullEvent("key")

ui.run({fps = 30})
