local PROTOCOL = "ChatServer"
local ui = dofile("UI.lua")

local context = {
    scenes = {},
    elements = {},
    functions = { log = function() end }
}
ui.init(context)

peripheral.find("modem", rednet.open)

local function motdParse(str)
    return (str:gsub("&([0-9a-fk-or])", "\167%1"))
end

ui.newScene("chat")

-- Forward declarations so they can reference each other
local nameField
local messageField

-- Name input field at top
nameField = ui.textfield({
    x = 1,
    y = 1,
    width = 26,
    height = 1,
    text = "",
    placeholder = "Enter your name...",
    scene = "chat",

    -- This gets *composed* with the built-in textfield onKey
    onKey = function(self, key)
        if key == keys.tab or key == keys.enter then
            ui.setFocus(messageField)
            -- return value doesn’t really matter here, built-in already ran
        end
    end,
})

-- Message input area
messageField = ui.textfield({
    x = 1,
    y = 3,
    width = 26,
    height = 1,
    text = "",
    placeholder = "Type message...",
    scene = "chat",

    onKey = function(self, key)
        if key == keys.tab then
            ui.setFocus(nameField)

        elseif key == keys.enter then
            local name = nameField.text
            local message = motdParse(self.text)

            if name ~= "" and message ~= "" then
                rednet.broadcast({
                    name = name,
                    text = message
                }, PROTOCOL)

                -- Clear message field
                self.text = ""
                self.cursorPos = 0
                ui.markDirty()
            end
        end
    end,
})

-- Send button
ui.button({
    text = "Send",
    x = 1,
    y = 5,
    width = 26,
    onclick = function()
        local name = nameField.text
        local message = motdParse(messageField.text)

        if name ~= "" and message ~= "" then
            rednet.broadcast({
                name = name,
                text = message
            }, PROTOCOL)

            messageField.text = ""
            messageField.cursorPos = 0
            ui.markDirty()
        end
        ui.setFocus(messageField)
    end,
    scene = "chat"
})

-- MOTD color/format cheatsheet labels
local function buildMotdCheatsheet()
    -- Top-left of the cheatsheet
    local baseX = 1
    local baseY = 9  -- below your status label at y=9

    -- Two-column layout to conserve vertical space
    local leftColumn = {
        "&0 Black",
        "&1 Dark Blue",
        "&2 Dark Green",
        "&3 Dark Aqua",
        "&4 Dark Red",
        "&5 Dark Purple",
        "&6 Gold",
        "&7 Gray",
        "&8 Dark Gray",
        "&9 Blue",
        "&a Green",
    }

    local rightColumn = {
        "&b Aqua",
        "&c Red",
        "&d Light Purple",
        "&e Yellow",
        "&f White",
        "&k Obfuscated",
        "&l Bold",
        "&m Strikethrough",
        "&n Underline",
        "&o Italic",
        "&r Reset",
    }

    -- Title
    ui.label({
        text  = "MOTD Codes:",
        x     = baseX,
        y     = baseY - 1,
        fg    = colors.cyan,
        scene = "chat",
    })

    -- Left column
    for i, text in ipairs(leftColumn) do
        ui.label({
            text  = text,
            x     = baseX,
            y     = baseY + (i - 1),
            fg    = colors.lightGray,
            scene = "chat",
        })
    end

    -- Right column
    local rightX = baseX + 13  -- small gap between columns
    for i, text in ipairs(rightColumn) do
        ui.label({
            text  = text,
            x     = rightX,
            y     = baseY + (i - 1),
            fg    = colors.lightGray,
            scene = "chat",
        })
    end
end

buildMotdCheatsheet()

ui.setScene("chat")
ui.setFocus(nameField)
ui.run()
