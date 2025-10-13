
local ENABLE_LOG = true
local ENABLE_PRINT = false
local LOG_FILE = "/log/log.txt"
local needRender = true
log = function()  end

local UI = {
    contextTable = {},
    term = term,
    focused = nil
}


function UI.init(context)
    UI.contextTable = context
    UI.contextTable.scenes = UI.contextTable.scenes or {}
    UI.term.setBackgroundColor(colors.black)
    UI.term.clear()
    UI.term.setCursorPos(1, 1)
    log = UI.contextTable.functions.log or log
    log("UI.init called.")
end

function UI.run()
    function updateEvents()
        while true do
            UI.handleEvent()
        end
    end

    function renderUI()
        while true do
            UI.render()
            sleep(0.001)
        end
    end
    parallel.waitForAny(renderUI, updateEvents)
end

function UI.newScene(name)
    if not name then error("UI.newScene: name required") end
    UI.contextTable.scenes[name] = UI.contextTable.scenes[name] or { elements = {}, scripts = {} }
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

function UI.removeChild(target)
    local parentScene = UI.activeScene
    local targetName = nil

    -- Case 1: Explicit scene name passed
    if type(target) == "string" then
        targetName = target

        -- Case 2: Element table passed (find which scene it belongs to)
    elseif type(target) == "table" and target.type then
        for sceneName, sceneData in pairs(UI.contextTable.scenes) do
            for _, e in ipairs(sceneData.elements or {}) do
                if e == target then
                    targetName = sceneName
                    break
                end
            end
            if targetName then break end
        end
    end

    if not targetName then
        error("UI.removeChild: could not determine child scene to remove.")
    end

    -- Find parent and remove child reference
    local parent = UI.contextTable.scenes[parentScene]
    if not parent or not parent.children then return end

    for i, child in ipairs(parent.children) do
        if child.name == targetName then
            table.remove(parent.children, i)
            break
        end
    end

    UI.setScene(parentScene)
end

function UI.setChild(childName, xOffset, yOffset, position)
    if not UI.activeScene then
        error("UI.setChild: no active scene to attach to.")
    end
    if not UI.contextTable.scenes[childName] then
        error("UI.setChild: child scene '" .. childName .. "' does not exist.")
    end

    local parent = UI.contextTable.scenes[UI.activeScene]
    parent.children = parent.children or {}

    table.insert(parent.children, {
        name = childName,
        xOffset = xOffset or 0,
        yOffset = yOffset or 0,
        position = position or "center"
    })

    -- rebuild scene with new hierarchy
    UI.setScene(UI.activeScene)
end

function UI._addElementToActive(e)
    if UI.activeScene then
        table.insert(contextTable.scenes[UI.activeScene].elements, e)
    else
        table.insert(contextTable.elements, e) -- fallback if no scene active
    end
end

function UI.handleEvent()
    local event, a, b, c = os.pullEvent()

    if event == "mouse_click" then
        UI.handleClick(b, c)
    elseif event == "mouse_scroll" then

        UI.handleScroll(a,b,c)
    elseif event == "key" or event == "char" then


        if UI.focused and UI.focused.type == "textfield" then

            UI.handleInput(event, a, b)

        end
    end

end

function UI.applyPositioning(e)
    local w, h = UI.term.getSize()
    local width = e.width or (#e.text or 1)
    local height = e.height or 1

    local xOffset = e.xOffset or 0
    local yOffset = e.yOffset or 0

    if e.position then
        local pos = e.position

        if pos == "center" then
            e.x = math.floor((w - width) / 2) + 1 + xOffset
            e.y = math.floor((h - height) / 2) + 1 + yOffset

        elseif pos == "topLeft" then
            e.x = 1 + xOffset
            e.y = 1 + yOffset

        elseif pos == "topCenter" or pos == "top" then
            e.x = math.floor((w - width) / 2) + 1 + xOffset
            e.y = 1 + yOffset

        elseif pos == "topRight" then
            e.x = w - width + 1 + xOffset
            e.y = 1 + yOffset

        elseif pos == "centerLeft" or pos == "left" then
            e.x = 1 + xOffset
            e.y = math.floor((h - height) / 2) + 1 + yOffset

        elseif pos == "centerRight" or pos == "right" then
            e.x = w - width + 1 + xOffset
            e.y = math.floor((h - height) / 2) + 1 + yOffset

        elseif pos == "bottomLeft" then
            e.x = 1 + xOffset
            e.y = h - height + 1 + yOffset

        elseif pos == "bottomCenter" or pos == "bottom" then
            e.x = math.floor((w - width) / 2) + 1 + xOffset
            e.y = h - height + 1 + yOffset

        elseif pos == "bottomRight" then
            e.x = w - width + 1 + xOffset
            e.y = h - height + 1 + yOffset
        end
    end

    if e.xPercent then e.x = math.floor(w * e.xPercent) end
    if e.yPercent then e.y = math.floor(h * e.yPercent) end

    if e.x < 1 then e.x = 1 end
    if e.y < 1 then e.y = 1 end
end

function UI.drawElement(e, offsetX, offsetY)
    offsetX = offsetX or 0
    offsetY = offsetY or 0

    -- Apply global positioning offset (for child scenes)
    e.x = (e.x or 1) + (e._offsetX or 0) + offsetX
    e.y = (e.y or 1) + (e._offsetY or 0) + offsetY

    -- Positioning logic for anchors / percentages
    UI.applyPositioning(e)

    if e.type == "button" then
        UI.drawButton(e)
    elseif e.type == "label" then
        UI.drawLabel(e)
    elseif e.type == "checkbox" then
        UI.drawCheckbox(e)
    elseif e.type == "textfield" then
        UI.drawTextfield(e)
    elseif e.type == "minimarkrenderer" then
        UI.drawMinimarkRenderer(e)
    elseif e.type == "rectangle" then
        UI.drawRectangle(e)
    else
        -- Unknown element type
        UI.term.setCursorPos(1, 1)
        UI.term.setTextColor(colors.red)
        UI.term.write("[WARN] Unknown element type: " .. tostring(e.type))
    end
end

function UI.render()
    if not needRender then return end
    UI.term.setBackgroundColor(colors.black)
    UI.term.clear()

    local function renderScene(scene, offsetX, offsetY)
        offsetX = offsetX or 0
        offsetY = offsetY or 0

        -- Draw all elements in this scene
        for _, e in ipairs(scene.elements or {}) do
            if UI.drawElement then
                UI.drawElement(e, offsetX, offsetY)
            else
                error("UI.drawElement not defined or nil")
            end
        end

        -- Recursively draw child scenes
        if scene.children then
            for _, child in ipairs(scene.children) do
                local childScene = UI.contextTable.scenes[child.name]
                if childScene then
                    renderScene(
                            childScene,
                            offsetX + (child.xOffset or 0),
                            offsetY + (child.yOffset or 0)
                    )
                end
            end
        end
    end

    local activeScene = UI.contextTable.scenes[UI.activeScene]
    if activeScene then
        renderScene(activeScene)
    else
        error("UI.render: No active scene set.")
    end

    needRender = false
end

function UI.handleClick(x, y)

    for _, e in ipairs(UI.contextTable.elements) do
        local width = e.width or #e.text
        local height = e.height or 1
        if x >= e.x and x <= e.x + width - 1 and y >= e.y and y < e.y + height then
            if e.type == "minimarkrenderer" then
                -- Handle minimarkrenderer click events here

                if e.buttons then
                    for _, buttonWrapper in ipairs(e.buttons) do
                        local button = buttonWrapper.element

                        if button.type == "link" then

                            if x >= button.x and x <= button.x + button.width - 1 and y == button.y then
                                needRender = true
                                log(string.format("Link clicked x=%d y=%d width=%d", button.x or -1, button.y or -1, button.width or -1))
                                e.newlink = button.page
                            end
                        end

                    end
                end
            elseif e.type == "textfield" then
                UI.focused = e
                needRender = true
            elseif e.type == "checkbox" then
                e.checked = not e.checked
                e.onclick(e, e.checked)
                needRender = true
            elseif e.type == "button" then
                if e.toggle then e.state = not e.state else e.pressed = true end
                needRender = true
                if not e.toggle then sleep(0.1) end
                e.onclick(e)
                if not e.toggle then e.pressed = false end
                needRender = true
            end
        end
    end
end

function UI.handleScroll(scroll, x, y)

    for _, e in ipairs(UI.contextTable.elements) do
        local width = e.width or #e.text
        local height = e.height or 1

        if x >= e.x and x <= e.x + width - 1 and y >= e.y and y < e.y + height then
            if e.type == "minimarkrenderer" then
                -- Safe fallback for missing linesCount or scrollSpeed
                e.scrollSpeed = e.scrollSpeed or 1
                e.linesCount = e.linesCount or 0
                e.scrollOffset = e.scrollOffset or 0

                -- Apply scroll
                e.scrollOffset = e.scrollOffset + (scroll * e.scrollSpeed)
                needRender = true
                -- Clamp scroll range
                if e.scrollOffset < 0 - e.y then
                    e.scrollOffset = 0 - e.y
                    needRender = false
                else
                    local maxScroll = math.ceil(math.max(0, e.linesCount - e.height))
                    if e.scrollOffset > maxScroll then
                        e.scrollOffset = maxScroll
                        needRender = false
                    end

                end



                return true
            end
        end
    end

    -- If not handled, optional: implement global scroll here

    return false
end

function UI.handleInput(event, a, b)


    if event == "char" then



        UI.focused.text = UI.focused.text .. a
        needRender = true
    elseif event == "key" and a == keys.backspace then

        if(UI.focused.text ~= "") then
            UI.focused.text = UI.focused.text:sub(1, -2)
            needRender = true
        end
    end

end

function UI.drawButton(e)
    local displayText = e.text
    local width = e.width or #e.text
    local height = e.height or 1
    local pad = math.max(0, math.floor((width - #displayText) / 2))
    local line = string.rep(" ", pad) .. displayText .. string.rep(" ", width - pad - #displayText)

    local verticalCenter = e.y + math.floor((height - 1) / 2)
    local bgColor = colors.black
    if e.toggle and e.state and e.colorPressed then
        bgColor = e.colorPressed
    elseif not e.toggle and e.pressed and e.colorPressed then
        bgColor = e.colorPressed
    elseif e.bg then
        bgColor = e.bg
    end

    for i = 0, height - 1 do
        UI.term.setCursorPos(e.x, e.y + i)
        UI.term.setBackgroundColor(bgColor)
        UI.term.setTextColor(e.fg or colors.white)
        UI.term.write((e.y + i == verticalCenter) and line or string.rep(" ", width))
    end
end

function UI.drawLabel(e)
    UI.term.setCursorPos(e.x, e.y)
    UI.term.setBackgroundColor(e.bg or colors.black)
    UI.term.setTextColor(e.fg or colors.white)
    UI.term.write(e.text)
end

function UI.drawCheckbox(e)
    UI.term.setCursorPos(e.x, e.y)
    UI.term.setBackgroundColor(e.bg or colors.black)
    UI.term.setTextColor(e.fg or colors.white)
    local box = e.checked and "[x] " or "[ ] "
    UI.term.write(box .. e.text)
end

function UI.drawTextfield(e)
    UI.term.setCursorPos(e.x, e.y)
    local bg = (UI.focused == e and e.bgActive) or e.bg or colors.gray
    local fg = e.fg or colors.black
    UI.term.setBackgroundColor(bg)
    UI.term.setTextColor(fg)
    local display = e.text .. string.rep(" ", (e.width or 10) - #e.text)
    UI.term.write(display:sub(1, e.width or 10))
end

function UI.drawRectangle(e)
    local x, y, w, h = e.x, e.y, e.width, e.height
    local color = e.bg or colors.white
    local filled = e.filled ~= false
    local oldBg = UI.term.getBackgroundColor()
    UI.term.setBackgroundColor(color)

    if filled then
        for i = 0, h - 1 do
            UI.term.setCursorPos(x, y + i)
            UI.term.write(string.rep(" ", w))
        end
    else
        UI.term.setCursorPos(x, y)
        UI.term.write(string.rep(" ", w))
        UI.term.setCursorPos(x, y + h - 1)
        UI.term.write(string.rep(" ", w))
        for i = 1, h - 2 do
            UI.term.setCursorPos(x, y + i)
            UI.term.write(" ")
            UI.term.setCursorPos(x + w - 1, y + i)
            UI.term.write(" ")
        end
    end

    UI.term.setBackgroundColor(oldBg)
end

function UI.button(opts)
    local e = {
        type = "button",
        x = opts.x or 1, y = opts.y or 1,
        text = opts.text or "Button",
        fg = opts.fg, bg = opts.bg,
        colorPressed = opts.colorPressed,
        toggle = opts.toggle,
        state = false,
        pressed = false,
        xOffset = opts.xOffset,
        yOffset = opts.yOffset,
        width = opts.width, height = opts.height,
        onclick = opts.onclick or function() end,
        xPercent = opts.xPercent, yPercent = opts.yPercent,
        position = opts.position
    }
    local target = (UI.contextTable.scenes and UI.activeScene and UI.contextTable.scenes[UI.activeScene])
            and UI.contextTable.scenes[UI.activeScene].elements
            or UI.contextTable.elements
    table.insert(target, e)

    return e
end

function UI.label(opts)
    local e = {
        type = "label",
        x = opts.x or 1, y = opts.y or 1,
        text = opts.text or "",
        fg = opts.fg, bg = opts.bg,
        xPercent = opts.xPercent, yPercent = opts.yPercent,
        position = opts.position,
        xOffset = opts.xOffset,
        yOffset = opts.yOffset
    }
    local target = (UI.contextTable.scenes and UI.activeScene and UI.contextTable.scenes[UI.activeScene])
            and UI.contextTable.scenes[UI.activeScene].elements
            or UI.contextTable.elements
    table.insert(target, e)

    return e
end

function UI.checkbox(opts)
    local e = {
        type = "checkbox",
        x = opts.x or 1, y = opts.y or 1,
        text = opts.text or "",
        fg = opts.fg, bg = opts.bg,
        checked = opts.initial or false,
        onclick = opts.onclick or function() end,
        xPercent = opts.xPercent, yPercent = opts.yPercent,
        position = opts.position,
        xOffset = opts.xOffset,
        yOffset = opts.yOffset
    }
    local target = (UI.contextTable.scenes and UI.activeScene and UI.contextTable.scenes[UI.activeScene])
            and UI.contextTable.scenes[UI.activeScene].elements
            or UI.contextTable.elements
    table.insert(target, e)

    return e
end

function UI.textfield(opts)
    local e = {
        type = "textfield",
        x = opts.x or 1, y = opts.y or 1,
        text = opts.text or "",
        width = opts.width or 10,
        fg = opts.fg, bg = opts.bg, bgActive = opts.bgActive,
        xPercent = opts.xPercent, yPercent = opts.yPercent,
        position = opts.position,
        xOffset = opts.xOffset,
        yOffset = opts.yOffset
    }
    local target = (UI.contextTable.scenes and UI.activeScene and UI.contextTable.scenes[UI.activeScene])
            and UI.contextTable.scenes[UI.activeScene].elements
            or UI.contextTable.elements
    table.insert(target, e)

    return e
end

function UI.rectangle(opts)
    local e = {
        type = "rectangle",
        x = opts.x or 1,
        y = opts.y or 1,
        width = opts.width or 5,
        height = opts.height or 3,
        fg = opts.fg or colors.gray,
        bg = opts.bg or colors.black,
        filled = opts.filled ~= false, -- default true
        xOffset = opts.xOffset,
        yOffset = opts.yOffset,
        position = opts.position,
        xPercent = opts.xPercent,
        yPercent = opts.yPercent,
    }

    local target = (UI.contextTable.scenes and UI.activeScene and UI.contextTable.scenes[UI.activeScene])
            and UI.contextTable.scenes[UI.activeScene].elements
            or UI.contextTable.elements
    table.insert(target, e)
    return e
end

function UI.updateLabel(labelObj, newText)
    labelObj.text = newText
    needRender = true
end

function UI.updateButton(buttonObj, newText)
    buttonObj.text = newText
    needRender = true
end

function UI.updateCheckbox(checkboxObj, newText)
    checkboxObj.text = newText
    needRender = true
end

function UI.createExitButton(onClick)
    UI.button({
        text = "X",
        width = 3,
        height = 1,
        fg = colors.white,
        bg = colors.red,
        colorPressed = colors.orange,
        position = "topRight",
        onclick = onClick or function()
            UI.term.setBackgroundColor(colors.black)
            UI.term.clear()
            UI.term.setCursorPos(1, 1)
            error("[UI] Exited via exit button")
        end


    })
end

function UI.minimarkrenderer(opts)
    local e = {
        type = "minimarkrenderer",
        x = opts.x or 1,
        y = opts.y or 1,
        path = opts.path,
        renderer = opts.renderer, -- require("MiniMark")
        linesCount = #opts.renderer.loadPage(opts.path),
        xPercent = opts.xPercent, yPercent = opts.yPercent,
        position = opts.position,
        xOffset = opts.xOffset,
        yOffset = opts.yOffset,
        width = opts.width,
        height = opts.height,
        scrollOffset = opts.scrollOffset or opts.y,
        scrollSpeed = opts.scrollSpeed or 1,
        newlink = nil,
        buttons = {
            --Shit into that will live update when hyperlinks are visible
        },
        scriptString = nil
        --term = term.create
    }
    local target = (UI.contextTable.scenes and UI.activeScene and UI.contextTable.scenes[UI.activeScene])
            and UI.contextTable.scenes[UI.activeScene].elements
            or UI.contextTable.elements
    table.insert(target, e)

    return e
end

function UI.minimarkUpdatePath(e, newPath)
    e.path = newPath
    e.linesCount = #e.renderer.loadPage(e.path)
    e.scrollOffset = -1

    -- Load Scripting as well
    UI.contextTable.scripts = e.renderer.getScripts(newPath)

    for name, code in pairs(UI.contextTable.scripts) do
        log(string.format("[Script Loaded] %s:\n%s", name, code))
    end

    return true
end

function UI.drawMinimarkRenderer(e)
    if not e.path then return end
    local lines = e.renderer.loadPage(e.path)
    local endY = nil

    e.buttons , endY  = e.renderer.renderPage(e.path, e.scrollOffset, e.y)

    --e.linesCount = endY - e.y
    for i, entry in ipairs(e.buttons) do
        local el = entry.element
        log(string.format("UI[%d] type=%s x=%d y=%d width=%d", i, el.type or "nil", el.x or -1, el.y or -1, el.width or -1))
    end

end

return UI
