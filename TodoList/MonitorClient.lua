local UI = dofile("UI.lua")
local client = dofile("EETodoCore.lua")
local registerThemes = dofile("themes.lua")

-- Find and wrap to monitor
local monitor = peripheral.find("monitor")
if not monitor then
    error("No monitor found! Please attach a monitor to this computer.")
end

term.redirect(monitor)
monitor.setTextScale(1)

-- Get monitor dimensions
local monitorWidth, monitorHeight = monitor.getSize()

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
UI.setScene("EETodo_Monitor")

-- Title
local titleLabel = UI.label({
    text     = "Base TODOs",
    position = "topCenter",
    yOffset  = 1,
    fg       = "accent"
})

-- Status label
local statusLabel = UI.label({
    text     = "Connecting...",
    position = "topCenter",
    yOffset  = 2,
    fg       = "textMuted"
})

-- List container
local containerWidth = math.min(monitorWidth - 4, 80)
local containerHeight = math.max(monitorHeight - 5, 15)

local listContainer = UI.rectangle({
    width      = containerWidth,
    height     = containerHeight,
    position   = "topCenter",
    yOffset    = 4,
    bg         = "surface",
    border     = false,
    padding    = 0
})

-- Rebuild the todo list with active/inactive sections
local function buildTodos()
    local todos = client.getTodos() or {}

    -- Partition into active and done
    local activeItems = {}
    local doneItems = {}

    for i, item in ipairs(todos) do
        item.index = i  -- Store original index
        if item.done then
            table.insert(doneItems, item)
        else
            table.insert(activeItems, item)
        end
    end

    -- Update status label
    local activeCount = #activeItems
    local doneCount = #doneItems
    statusLabel.text = string.format("%d active, %d done", activeCount, doneCount)

    if activeCount == 0 and doneCount > 0 then
        statusLabel.fg = UI.resolveColor("accent", colors.orange)
    elseif activeCount > 0 then
        statusLabel.fg = UI.resolveColor("textMuted", colors.lightGray)
    else
        statusLabel.fg = UI.resolveColor("textMuted", colors.lightGray)
    end

    -- Clear existing children
    if listContainer and listContainer.children then
        for i = #listContainer.children, 1, -1 do
            UI.destroyElement(listContainer.children[i])
        end
        listContainer.children = {}
    end

    if #todos == 0 then
        UI.markDirty()
        return
    end

    -- Build layout
    local prevBuilding = UI._buildingLayout
    local prevParent   = UI._layoutParent
    UI._buildingLayout = true
    UI._layoutParent   = listContainer

    -- Compute inner area
    local border   = listContainer.border and 1 or 0
    local padding  = listContainer.padding or 0
    local baseX    = listContainer.x + border + padding
    local baseY    = listContainer.y + border + padding
    local innerW   = listContainer.width - (border * 2) - (padding * 2)

    local currentY = 0
    local maxRows = containerHeight - 2

    -- Active section header
    if #activeItems > 0 then
        UI.label({
            text = "Active",
            x = baseX,
            y = baseY + currentY,
            fg = "headerText"
        })
        currentY = currentY + 1
    end

    -- Render active items
    for _, item in ipairs(activeItems) do
        if currentY >= maxRows then break end

        local rowY = baseY + currentY
        local text = item.text or ""

        -- Checkbox
        local checkbox = UI.checkbox({
            text    = text,
            x       = baseX,
            y       = rowY,
            initial = item.done,
            fg      = "text",
            checked = "success",
            onClick = function(self)
                client.modifyTodoItem(item.index, {
                    text = self.text,
                    done = self.checked
                })
            end
        })

        currentY = currentY + 1
    end

    -- Separator before done section
    if #doneItems > 0 and currentY < maxRows then
        currentY = currentY + 1

        UI.label({
            text = string.rep("-", math.min(innerW, 40)),
            x = baseX,
            y = baseY + currentY,
            fg = "textDim"
        })
        currentY = currentY + 1

        -- Done section header
        UI.label({
            text = "Done",
            x = baseX,
            y = baseY + currentY,
            fg = "headerText"
        })
        currentY = currentY + 1
    end

    -- Render done items
    for _, item in ipairs(doneItems) do
        if currentY >= maxRows then break end

        local rowY = baseY + currentY
        local text = item.text or ""

        -- Checkbox
        local checkbox = UI.checkbox({
            text    = text,
            x       = baseX,
            y       = rowY,
            initial = item.done,
            fg      = "textDim",
            checked = "success",
            onClick = function(self)
                client.modifyTodoItem(item.index, {
                    text = self.text,
                    done = self.checked
                })
            end
        })

        currentY = currentY + 1
    end

    -- Restore layout flags
    UI._layoutParent   = prevParent
    UI._buildingLayout = prevBuilding

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
