-- Refactored UI Framework for CC:Tweaked
-- Drop-in replacement for previous UI.lua
-- Adds: element-level draw(), addElement(scene, element), scene argument for constructors
-- Maintains compatibility with browser.lua and MiniMark renderer

local ENABLE_LOG = true
local LOG_FILE = "/log/log.txt"
local needRender = true
log = function() end

local UI = {
    contextTable = {},
    term = term,
    focused = nil
}

-------------------------------------------------
-- Core Initialization
-------------------------------------------------
function UI.init(context)
    UI.contextTable = context
    UI.contextTable.scenes = UI.contextTable.scenes or {}
    UI.term.setBackgroundColor(colors.black)
    UI.term.clear()
    UI.term.setCursorPos(1, 1)
    log = UI.contextTable.functions.log or log
    log("[UI] Initialized")
end

-------------------------------------------------
-- Scene Management
-------------------------------------------------
function UI.newScene(name)
    if not name then error("UI.newScene: name required") end
    UI.contextTable.scenes[name] = UI.contextTable.scenes[name] or { elements = {}, children = {} }
end

function UI.setScene(name)
    if not UI.contextTable.scenes[name] then
        UI.contextTable.scenes[name] = { elements = {}, children = {} }
    end
    UI.activeScene = name
    UI.contextTable.elements = {}

    local function attachScene(sceneName, offsetX, offsetY)
        local scene = UI.contextTable.scenes[sceneName]
        if not scene then return end

        for _, e in ipairs(scene.elements) do
            e._offsetX = offsetX or 0
            e._offsetY = offsetY or 0
            table.insert(UI.contextTable.elements, e)
        end

        for _, child in ipairs(scene.children or {}) do
            attachScene(child.name, (offsetX or 0) + (child.xOffset or 0), (offsetY or 0) + (child.yOffset or 0))
        end
    end

    attachScene(name, 0, 0)
    needRender = true
end

function UI.setChild(childName, xOffset, yOffset, position)
    if not UI.activeScene then error("UI.setChild: no active scene") end
    if not UI.contextTable.scenes[childName] then error("UI.setChild: unknown child scene") end

    local parent = UI.contextTable.scenes[UI.activeScene]
    parent.children = parent.children or {}
    table.insert(parent.children, { name = childName, xOffset = xOffset or 0, yOffset = yOffset or 0, position = position or "center" })
    UI.setScene(UI.activeScene)
end

function UI.removeChild(target)
    local parentScene = UI.activeScene
    local parent = UI.contextTable.scenes[parentScene]
    if not parent or not parent.children then return end

    for i, child in ipairs(parent.children) do
        if child.name == target or child == target then table.remove(parent.children, i) break end
    end
    UI.setScene(parentScene)
end

-------------------------------------------------
-- Generic Element Registration
-------------------------------------------------
function UI.addElement(sceneName, element)
    if not sceneName then sceneName = UI.activeScene end
    if not sceneName then error("UI.addElement: No active scene or target scene") end

    local scene = UI.contextTable.scenes[sceneName]
    if not scene then error("UI.addElement: Scene '" .. sceneName .. "' not found") end

    table.insert(scene.elements, element)
    needRender = true
    return element
end

-------------------------------------------------
-- Positioning
-------------------------------------------------
function UI.applyPositioning(e)
    local w, h = UI.term.getSize()
    local width = e.width or (#e.text or 1)
    local height = e.height or 1
    local xOffset = e.xOffset or 0
    local yOffset = e.yOffset or 0

    if e.position then
        local pos = e.position
        local cx = math.floor((w - width) / 2) + 1 + xOffset
        local cy = math.floor((h - height) / 2) + 1 + yOffset
        local lookup = {
            center = {cx, cy}, topLeft = {1 + xOffset, 1 + yOffset},
            topCenter = {cx, 1 + yOffset}, topRight = {w - width + 1 + xOffset, 1 + yOffset},
            left = {1 + xOffset, cy}, right = {w - width + 1 + xOffset, cy},
            bottomLeft = {1 + xOffset, h - height + 1 + yOffset},
            bottomCenter = {cx, h - height + 1 + yOffset}, bottomRight = {w - width + 1 + xOffset, h - height + 1 + yOffset}
        }
        if lookup[pos] then e.x, e.y = table.unpack(lookup[pos]) end
    end

    if e.xPercent then e.x = math.floor(w * e.xPercent) end
    if e.yPercent then e.y = math.floor(h * e.yPercent) end
end

-------------------------------------------------
-- Rendering
-------------------------------------------------
function UI.render()
    if not needRender then return end
    UI.term.setBackgroundColor(colors.black)
    UI.term.clear()

    local function drawScene(scene, offsetX, offsetY)
        for _, e in ipairs(scene.elements or {}) do
            UI.applyPositioning(e)
            if e.draw then e:draw(offsetX or 0, offsetY or 0)
            elseif UI["draw" .. e.type:sub(1, 1):upper() .. e.type:sub(2)] then
                UI["draw" .. e.type:sub(1, 1):upper() .. e.type:sub(2)](e)
            end
        end
        for _, c in ipairs(scene.children or {}) do
            local child = UI.contextTable.scenes[c.name]
            if child then drawScene(child, (offsetX or 0) + (c.xOffset or 0), (offsetY or 0) + (c.yOffset or 0)) end
        end
    end

    local active = UI.contextTable.scenes[UI.activeScene]
    if active then drawScene(active) else error("UI.render: no active scene") end
    needRender = false
end

function UI.markDirty()
    needRender = true
end


-------------------------------------------------
-- Input Handling
-------------------------------------------------
function UI.handleEvent()
    local event, a, b, c = os.pullEvent()
    if event == "mouse_click" then UI.handleClick(b, c)
    elseif event == "mouse_scroll" then UI.handleScroll(a, b, c)
    elseif event == "key" or event == "char" then if UI.focused and UI.focused.onInput then UI.focused:onInput(event, a, b) end end
end

function UI.handleClick(x, y)
    for _, e in ipairs(UI.contextTable.elements) do
        if e.onClick and x >= e.x and x <= e.x + (e.width or #e.text) - 1 and y >= e.y and y < e.y + (e.height or 1) then
            e:onClick(x, y)
            needRender = true
        end
    end
end

function UI.handleScroll(dir, x, y)
    for _, e in ipairs(UI.contextTable.elements) do if e.onScroll then e:onScroll(dir, x, y) end end
end

-------------------------------------------------
-- Element Constructors (each defines its own draw)
-------------------------------------------------
local function defaultScene(opts)
    return opts.scene or UI.activeScene or error("No active scene for element")
end

function UI.button(opts)
    local e = {
        type = "button",
        text = opts.text or "Button",
        x = opts.x or 1, y = opts.y or 1,
        width = opts.width or #opts.text, height = opts.height or 1,
        fg = opts.fg or colors.white, bg = opts.bg or colors.gray,
        colorPressed = opts.colorPressed or colors.lightGray,
        toggle = opts.toggle,
        state = false,
        pressed = false,
        position = opts.position, xOffset = opts.xOffset, yOffset = opts.yOffset,

        onClick = function(self)
            if self.toggle then
                self.state = not self.state
                UI.markDirty()
            else
                self.pressed = true
                UI.markDirty()
                sleep(0.1)               -- brief visual feedback
                self.pressed = false
                UI.markDirty()
            end

            if opts.onclick then opts.onclick(self) end
        end,

        draw = function(self)
            local bg = self.bg
            if self.toggle and self.state then
                bg = self.colorPressed or self.bg
            elseif not self.toggle and self.pressed then
                bg = self.colorPressed or self.bg
            end

            UI.term.setTextColor(self.fg)
            UI.term.setBackgroundColor(bg)
            UI.term.setCursorPos(self.x, self.y)
            local pad = math.max(0, math.floor((self.width - #self.text) / 2))
            local line = string.rep(" ", pad) .. self.text .. string.rep(" ", self.width - pad - #self.text)
            UI.term.write(line:sub(1, self.width))
        end
    }

    return UI.addElement(opts.scene or UI.activeScene, e)
end


function UI.label(opts)
    local e = {
        type = "label", text = opts.text or "", fg = opts.fg or colors.white, bg = opts.bg or colors.black,
        x = opts.x or 1, y = opts.y or 1, position = opts.position, xOffset = opts.xOffset, yOffset = opts.yOffset,
        draw = function(self)
            UI.term.setTextColor(self.fg)
            UI.term.setBackgroundColor(self.bg)
            UI.term.setCursorPos(self.x, self.y)
            UI.term.write(self.text)
        end
    }
    return UI.addElement(defaultScene(opts), e)
end

function UI.checkbox(opts)
    local e = {
        type = "checkbox", text = opts.text or "", checked = opts.initial or false,
        fg = opts.fg or colors.white, bg = opts.bg or colors.black,
        position = opts.position, xOffset = opts.xOffset, yOffset = opts.yOffset,
        onClick = function(self) self.checked = not self.checked if opts.onclick then opts.onclick(self, self.checked) end end,
        draw = function(self)
            local box = self.checked and "[x] " or "[ ] "
            UI.term.setTextColor(self.fg)
            UI.term.setBackgroundColor(self.bg)
            UI.term.setCursorPos(self.x, self.y)
            UI.term.write(box .. self.text)
        end
    }
    return UI.addElement(defaultScene(opts), e)
end

function UI.textfield(opts)
    local e = {
        type = "textfield", text = opts.text or "", width = opts.width or 10,
        fg = opts.fg or colors.white, bg = opts.bg or colors.gray, bgActive = opts.bgActive or colors.lightGray,
        position = opts.position, xOffset = opts.xOffset, yOffset = opts.yOffset,
        onInput = function(self, event, key)
            if event == "char" then self.text = self.text .. key elseif event == "key" and key == keys.backspace then self.text = self.text:sub(1, -2) end
            UI.markDirty()
        end,
        onClick = function(self) UI.focused = self end,
        draw = function(self)
            local bg = (UI.focused == self) and self.bgActive or self.bg
            UI.term.setBackgroundColor(bg)
            UI.term.setTextColor(self.fg)
            UI.term.setCursorPos(self.x, self.y)
            local text = self.text .. string.rep(" ", self.width - #self.text)
            UI.term.write(text:sub(1, self.width))
        end
    }
    return UI.addElement(defaultScene(opts), e)
end

function UI.rectangle(opts)
    local e = {
        type = "rectangle", width = opts.width or 5, height = opts.height or 3,
        fg = opts.fg or colors.white, bg = opts.bg or colors.black, filled = opts.filled ~= false,
        position = opts.position, xOffset = opts.xOffset, yOffset = opts.yOffset,
        draw = function(self)
            local oldBg = UI.term.getBackgroundColor()
            UI.term.setBackgroundColor(self.bg)
            for i = 0, self.height - 1 do
                UI.term.setCursorPos(self.x, self.y + i)
                UI.term.write(string.rep(" ", self.width))
            end
            UI.term.setBackgroundColor(oldBg)
        end
    }
    return UI.addElement(defaultScene(opts), e)
end

return UI
