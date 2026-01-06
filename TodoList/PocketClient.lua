
local UI = dofile("UI.lua")
local client = dofile("EETodoCore.lua")
local registerThemes = dofile("themes.lua")




-- Initialize UI
local context = {
    scenes = {},
    elements = {},
    themes = {},
    functions = { log = function() end }
}

UI.init(context)
registerThemes(UI)
UI.setTheme("gruvbox")
-- Create main scene
UI.setScene("EETodo_Main")

-- Title at top
local titleLabel = UI.label({
    text     = "Base TODOs",
    position = "topLeft",
    xOffset  = 1,
    yOffset  = 1,
    fg       = "accent"
})

-- List container (compact, no border)
listContainer = UI.rectangle({
    width      = 24,
    height     = 13,
    position   = "topLeft",
    xOffset    = 1,
    yOffset    = 3,
    bg         = "surface",
    border     = false,
    padding    = 0
})


-- Input textfield
inputField = UI.textfield({
    width      = 17,
    position   = "bottomLeft",
    xOffset    = 1,
    yOffset    = -1,
    placeholder = "Add todo...",
    onKey = function(self, key)
        if key == keys.enter then
            client.addTodoItem({text = self.text, done = false})
            self.text = ""
            self.cursorPos = 0
            UI.markDirty()
        end
    end
})


-- Add button
local addButton = UI.button({
    text     = "Add",
    width    = 5,
    position = "bottomRight",
    xOffset  = -1,
    yOffset  = -1,
    bg       = "interactive",
    fg       = "interactiveText",
    onclick  = function()
        client.addTodoItem({text = inputField.text, done = false})
        inputField.text = ""
    end
})



-- Rebuild the todo list UI inside listContainer
local function buildTodos()
    local todos = client.getTodos() or {}

    -- 1) Clear existing children from the rectangle
    if listContainer and listContainer.children then
        for i = #listContainer.children, 1, -1 do --loop thru all the children
            UI.destroyElement(listContainer.children[i]) --murder each one
        end
        listContainer.children = {}
    end

    -- Nothing to render
    if #todos == 0 then
        UI.markDirty()
        return
    end

    -- 2) Use the layout-building flag so new elements are attached as children
    local prevBuilding = UI._buildingLayout
    local prevParent   = UI._layoutParent
    UI._buildingLayout = true
    UI._layoutParent   = listContainer

    -- Compute inner area of the rectangle
    local border   = listContainer.border and 1 or 0
    local padding  = listContainer.padding or 0
    local baseX    = listContainer.x + border + padding
    local baseY    = listContainer.y + border + padding
    local innerW   = listContainer.width
            - (border * 2)
            - (padding * 2)

    for i, item in ipairs(todos) do
        local rowY = baseY + (i - 1)

        -- Stop if we run out of vertical space in the rect
        if rowY > listContainer.y + listContainer.height - 1 then
            break
        end

        local text = item.text or ""

        -- Checkbox: [ ] text
        local checkbox = UI.checkbox({
            text    = text,
            x       = baseX,
            y       = rowY,
            initial = item.done,
            fg      = "text",
            checked = "success",
            onClick = function(self)
                client.modifyTodoItem(i, {
                    text = self.text,
                    done = self.checked
                })
            end
        })

        -- Remove button at the far right: "x"
        local removeBtnX = baseX + innerW - 1

        local removeBtn = UI.button({
            text = "x",
            width = 1,
            x = removeBtnX,
            y = rowY,
            bg = "error",
            fg = "text",
            onclick = function()
                client.removeTodoItem(i)
            end
        })

        -- Because _buildingLayout + _layoutParent are set,
        -- these will be attached as children of listContainer
        -- via UI.addElement internally.
    end

    -- Restore layout-building flags
    UI._layoutParent   = prevParent
    UI._buildingLayout = prevBuilding

    -- Let the rectangle re-run its internal layout (for child positioning hooks)
    if listContainer.layout then
        listContainer:layout()
    end

    UI.markDirty()
end

-- Subscribe to rednet messages
UI.subscribeGlobalEvent("rednet_message", function(eventName, senderId, msg, protocol)
    client.handleRednetMessage(senderId, msg, protocol)
    buildTodos()
end)

-- Run the UI
client.init()

UI.run({
    onReady = function()
        buildTodos()
    end
})
