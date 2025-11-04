-- UI.lua v2.0 — Dirty Flag Rendering
-- CC:Tweaked UI Framework with parallel render loop and dirty flag optimization
-- Features: element-level draw(), scene management, animations, event handling
-- Compatible with browser.lua and MiniMark renderer

local ENABLE_LOG = false  -- Set to true for debugging
local LOG_FILE = "debug.log"

-- Debug logging function
local function debugLog(...)
    if not ENABLE_LOG then return end
    local args = {...}
    local msg = ""
    for i, v in ipairs(args) do
        msg = msg .. tostring(v)
        if i < #args then msg = msg .. " " end
    end
    local timestamp = string.format("[%.3f]", os.clock())
    local line = timestamp .. " " .. msg .. "\n"

    -- Append to file
    local mode = fs.exists(LOG_FILE) and "a" or "w"
    local f = fs.open(LOG_FILE, mode)
    if f then
        f.write(line)
        f.close()
    end
end

-- Clear log at startup
if fs.exists(LOG_FILE) then fs.delete(LOG_FILE) end
debugLog("=== UI Framework Debug Log Started ===")

local UI = {
    contextTable = {},
    term = term,
    focused = nil,
    scenes = {},
    elements = {}
}

-------------------------------------------------
-- Core Initialization
-------------------------------------------------
function UI.init(context)
    UI.contextTable = context
    UI.contextTable.scenes = UI.contextTable.scenes or {}
    UI.contextTable.elements = UI.contextTable.elements or {}
    UI.term.setBackgroundColor(colors.black)
    UI.term.clear()
    UI.term.setCursorPos(1, 1)
    log = UI.contextTable.functions.log or log
    log("[UI] Initialized")
    
    -- Initialize theme system
    UI.initThemes()
    UI.registerDefaultTheme()
    -- Re-apply background with current theme and clear once in the right color
    local theme = UI.getCurrentTheme and UI.getCurrentTheme()
            or (UI.contextTable.themes and UI.contextTable.themes[UI.contextTable.currentTheme]) or {}
    UI.term.setBackgroundColor((theme and theme.background) or colors.black)
    UI.term.clear()
    UI.term.setCursorPos(1,1)
end



-------------------------------------------------
-- Theme System
-------------------------------------------------

-- Initialize theme storage in context
function UI.initThemes()
    UI.contextTable.themes = UI.contextTable.themes or {}
    UI.contextTable.currentTheme = UI.contextTable.currentTheme or nil
end

-- Color utility functions
UI.theme = UI.theme or {}

-- Lighten a color (move to lighter variant)
function UI.theme.lighten(color)
    local lightMap = {
        -- Grayscale
        [colors.black] = colors.gray,
        [colors.gray] = colors.lightGray,
        [colors.lightGray] = colors.white,
        [colors.white] = colors.white,
        
        -- Primary colors
        [colors.red] = colors.orange,
        [colors.orange] = colors.yellow,
        [colors.yellow] = colors.yellow,
        
        [colors.green] = colors.lime,
        [colors.lime] = colors.lime,
        
        [colors.blue] = colors.lightBlue,
        [colors.lightBlue] = colors.cyan,
        [colors.cyan] = colors.cyan,
        
        -- Special colors
        [colors.purple] = colors.pink,
        [colors.pink] = colors.pink,
        
        [colors.magenta] = colors.pink,
        [colors.brown] = colors.orange
    }
    
    return lightMap[color] or color
end

-- Darken a color (move to darker variant)
function UI.theme.darken(color)
    local darkMap = {
        -- Grayscale
        [colors.white] = colors.lightGray,
        [colors.lightGray] = colors.gray,
        [colors.gray] = colors.black,
        [colors.black] = colors.black,
        
        -- Primary colors
        [colors.yellow] = colors.orange,
        [colors.orange] = colors.red,
        [colors.red] = colors.red,
        
        [colors.lime] = colors.green,
        [colors.green] = colors.green,
        
        [colors.cyan] = colors.lightBlue,
        [colors.lightBlue] = colors.blue,
        [colors.blue] = colors.blue,
        
        -- Special colors
        [colors.pink] = colors.magenta,
        [colors.magenta] = colors.purple,
        [colors.purple] = colors.purple
    }
    
    return darkMap[color] or color
end

-- Register a theme
function UI.registerTheme(name, theme)
    if not UI.contextTable.themes then
        UI.initThemes()
    end
    UI.contextTable.themes[name] = theme
end

-- Set active theme
function UI.setTheme(themeName)
    if not UI.contextTable.themes then
        UI.initThemes()
    end
    
    if UI.contextTable.themes[themeName] then
        UI.contextTable.currentTheme = themeName
        UI.markDirty()
    else
        error("Theme '" .. tostring(themeName) .. "' not found")
    end
end

-- Get current theme object
function UI.getCurrentTheme()
    if not UI.contextTable.currentTheme then
        return nil
    end
    return UI.contextTable.themes[UI.contextTable.currentTheme]
end

-- Resolve theme path like "danger" or "button.danger" or "dashboard.stat.label"
function UI.resolveThemePath(path)
    local theme = UI.getCurrentTheme()
    if not theme then return nil end
    
    -- Split path by dots
    local keys = {}
    for key in path:gmatch("[^.]+") do
        table.insert(keys, key)
    end
    
    -- Traverse theme object
    local value = theme
    for _, key in ipairs(keys) do
        value = value[key]
        if not value then return nil end
    end
    
    return value
end

-- Universal theme resolution helper
function UI.resolveTheme(opts, elementType, propertyMap)
    local theme = UI.getCurrentTheme()
    local resolved = {}
    
    -- Layer 1: Hardcoded fallbacks
    for prop, fallback in pairs(propertyMap) do
        resolved[prop] = fallback
    end
    
    -- Layer 2: Default element theme
    if theme and theme[elementType] then
        for prop in pairs(propertyMap) do
            if theme[elementType][prop] then
                resolved[prop] = theme[elementType][prop]
            end
        end
    end
    
    -- Layer 3: Theme parameter
    if opts.theme and theme then
        local themeValue = UI.resolveThemePath(opts.theme)
        
        if themeValue then
            if type(themeValue) == "number" then
                -- Single color: use for bg, compute pressed/active if needed
                if resolved.bg ~= nil then
                    resolved.bg = themeValue
                end
                if resolved.colorPressed ~= nil then
                    resolved.colorPressed = UI.theme.lighten(themeValue)
                end
                if resolved.bgPressed ~= nil then
                    resolved.bgPressed = UI.theme.lighten(themeValue)
                end
                if resolved.bgActive ~= nil then
                    resolved.bgActive = UI.theme.lighten(themeValue)
                end
                if resolved.fillColor ~= nil then
                    resolved.fillColor = themeValue
                end
            elseif type(themeValue) == "table" then
                -- Object with properties: use what's defined
                for prop in pairs(propertyMap) do
                    if themeValue[prop] then
                        resolved[prop] = themeValue[prop]
                    end
                end
            end
        end
    end
    
    -- Layer 4: Manual override (highest priority)
    for prop in pairs(propertyMap) do
        if opts[prop] ~= nil then
            resolved[prop] = opts[prop]
        end
    end
    
    return resolved
end

-- Register default theme
function UI.registerDefaultTheme()
    UI.registerTheme("default", {
        -- Semantic colors
        primary = colors.blue,
        secondary = colors.cyan,
        success = colors.green,
        warning = colors.yellow,
        danger = colors.red,
        info = colors.lightBlue,
        
        -- Base colors
        background = colors.black,
        surface = colors.gray,
        text = colors.white,
        textSecondary = colors.lightGray,
        border = colors.gray,
        
        -- Button
        button = {
            bg = colors.blue,
            fg = colors.white,
            colorPressed = colors.lightBlue,
            bgDisabled = colors.gray
        },
        
        -- Label
        label = {
            fg = colors.white,
            bg = colors.black
        },
        
        -- TextField
        textfield = {
            bg = colors.gray,
            fg = colors.white,
            bgActive = colors.lightGray
        },
        
        -- Checkbox
        checkbox = {
            fg = colors.white,
            bg = colors.black,
            checked = colors.lime
        },
        
        -- Terminal
        terminal = {
            bg = colors.black,
            fg = colors.white,
            prompt = colors.lime,
            spinner = colors.cyan
        },
        
        -- Rectangle
        rectangle = {
            bg = colors.black,
            fg = colors.white
        },
        
        -- Animated Label
        animatedLabel = {
            fg = colors.white,
            bg = colors.black
        }
    })
    
    -- Set default theme as active
    UI.setTheme("default")
end


--------------------------------------------------------------
-- Update animation and cursor/spinner elements each frame
--------------------------------------------------------------
function UI.update(dt)
    -- Update all elements and mark dirty if any changed
    -- For backward compat: if update() returns nothing/nil, assume it changed
    local anyChanged = false
    for _, e in ipairs(UI.contextTable.elements) do
        if e.update then
            local changed = e:update(dt)
            -- If update returns nil/nothing (old style), assume it changed
            -- If update returns true, it changed
            -- If update returns false, it didn't change
            if changed ~= false then
                anyChanged = true
            end
        end
    end
    if anyChanged then
        UI.markDirty()
    end
end





-------------------------------------------------
-------------------------------------------------
-- Scene Management
-------------------------------------------------
function UI.newScene(name)
    if not name then error("UI.newScene: name required") end
    UI.contextTable.scenes[name] = UI.contextTable.scenes[name] or { elements = {}, children = {} }
end

-- Clears all elements and children from a scene.
-- Useful for removing interactive overlays when changing pages/content.
-- Note: Child scenes are rendered after their parent scene, so overlays placed
-- in a child scene naturally draw on top of parent content.
function UI.clearScene(name)
    local scene = UI.contextTable.scenes[name]
    if scene then
        scene.elements = {}
        scene.children = {}
    end
end

function UI.setScene(name)
    if not UI.contextTable.scenes[name] then
        UI.contextTable.scenes[name] = { elements = {}, children = {} }
    end
    UI.activeScene = name
    UI.contextTable.elements = {}

    -- Clear focus when switching scenes (especially important for textfields)
    if UI.focused and UI.focused.type == "textfield" then
        debugLog("SCENE: Clearing textfield focus on scene change")
        UI.focused = nil
    end

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
    UI.markDirty()
end

-- Attaches a child scene to the currently active parent scene.
-- Child scenes render after their parent, so elements in child scenes naturally
-- draw on top of parent elements (useful for overlays, buttons, tooltips).
--
-- Parameters:
--   childName: Name of the child scene to attach
--   xOffset, yOffset: Optional position offsets
--   position: Optional positioning (e.g., "center")
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
    
    -- Auto-refresh: If adding to the active scene, refresh the flattened elements list
    if sceneName == UI.activeScene then
        UI.setScene(UI.activeScene)
    end
    
    return element
end

-------------------------------------------------
-- Positioning
-------------------------------------------------
function UI.applyPositioning(e)
    local w, h = UI.term.getSize()
    local width = e.width or (e.text and #e.text) or 1
    local height = e.height or 1
    local xOffset = e.xOffset or 0
    local yOffset = e.yOffset or 0

    if e.position then
        local pos = e.position --Anchor position
        local cx = math.floor((w - width) / 2) + 1 + xOffset -- center of screen x
        local cy = math.floor((h - height) / 2) + 1 + yOffset -- center of screen y
        local lookup = {
            center = {cx, cy},
            topLeft = {1 + xOffset, 1 + yOffset},
            topCenter = {cx, 1 + yOffset},
            topRight = {w - width + 1 + xOffset, 1 + yOffset},
            left = {1 + xOffset, cy},
            leftCenter = {1 + xOffset, cy},
            right = {w - width + 1 + xOffset, cy},
            rightCenter = {w - width + 1 + xOffset, cy},
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
local needRender = true

function UI.render()
    if not needRender then return end
    local theme = UI.getCurrentTheme and UI.getCurrentTheme()
            or (UI.contextTable.themes and UI.contextTable.themes[UI.contextTable.currentTheme]) or {}
    UI.term.setBackgroundColor((theme and theme.background) or colors.black)
    UI.term.clear()

    local function drawScene(scene, offsetX, offsetY)
        for _, e in ipairs(scene.elements or {}) do
            UI.applyPositioning(e) --Recalculate positioning each render in case of element changing size/position
            if e.draw then e:draw(offsetX or 0, offsetY or 0) end
        end
        for _, c in ipairs(scene.children or {}) do
            local child = UI.contextTable.scenes[c.name]
            if child then drawScene(child, (offsetX or 0) + (c.xOffset or 0), (offsetY or 0) + (c.yOffset or 0)) end
        end
    end

    local active = UI.contextTable.scenes[UI.activeScene]
    if active then
        drawScene(active)
    else
        error("UI.render: no active scene")
    end
    needRender = false
end

-- Marks the UI as dirty, scheduling a re-render on the next frame.
-- The UI uses a dirty flag optimization: UI.render() checks needRender at the start
-- and skips rendering if nothing has changed, saving CPU cycles.
--
-- Call UI.markDirty() after:
-- - Changing element properties (text, color, visibility, etc.)
-- - Updating application state that affects visual appearance
-- - Receiving events that require visual updates
-- - Calling prepareRender() on a MiniMark page element
--
-- NOTE: You DON'T need to call this after:
-- - Element onclick/onkey/onchar handlers (automatically sets dirty)
-- - Scene changes with setScene() (automatically sets dirty)
-- - Element updates that return true from update(dt) (automatically sets dirty)
function UI.markDirty()
    needRender = true
end


-------------------------------------------------
-- Input Handling
-------------------------------------------------
function UI.handleClick(x, y)
    local clickHandled = false

    -- Process elements in reverse order so topmost elements get priority
    for i = #UI.contextTable.elements, 1, -1 do
        local e = UI.contextTable.elements[i]

        -- Skip invisible elements
        if e._visible == false then
            goto continue
        end

        local ex = (e.x or 0) + (e._offsetX or 0)
        local ey = (e.y or 0) + (e._offsetY or 0)
        local width = e.width or (e.text and #e.text) or 1
        local height = e.height or 1

        if e.onClick then
            if x >= ex and x <= ex + width - 1 and y >= ey and y < ey + height then
                debugLog(string.format("Click (%d,%d) HIT element type=%s at (%d,%d) size=(%d,%d) visible=%s",
                    x, y, e.type or "?", ex, ey, width, height, tostring(e._visible)))
                local handled = e:onClick(x, y)
                -- If element returns false, continue to next element (click pass-through)
                if handled ~= false then
                    clickHandled = true
                    break
                end
            end
        end

        ::continue::
    end

    -- If click wasn't handled and we have a focused textfield, unfocus it
    if not clickHandled and UI.focused and UI.focused.type == "textfield" then
        debugLog("CLICK: Unfocusing textfield - click on empty space")
        UI.focused = nil
        UI.markDirty()
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
    opts = opts or {}
    
    -- Resolve theme colors
    local resolvedColors = UI.resolveTheme(opts, "button", {
        bg = colors.gray,
        fg = colors.white,
        colorPressed = colors.lightGray
    })
    
    local e = {
        type = "button",
        text = opts.text or "Button",
        x = opts.x or 1, y = opts.y or 1,
        width = opts.width or #(opts.text or "Button"), height = opts.height or 1,
        fg = resolvedColors.fg,
        bg = resolvedColors.bg,
        colorPressed = resolvedColors.colorPressed,
        toggle = opts.toggle,
        state = false,
        pressed = false,
        pressTimer = 0,
        pressDuration = 0.1,
        position = opts.position, xOffset = opts.xOffset, yOffset = opts.yOffset,
        _visible = opts.visible ~= nil and opts.visible or true,

        onClick = function(self, x, y)
            if self.toggle then
                self.state = not self.state
                UI.markDirty()
            else
                self.pressed = true
                self.pressTimer = 0
                UI.markDirty()
            end

            if opts.onclick then
                opts.onclick(self, x, y)
            end

            return true  -- Always mark button clicks as handled
        end,

        update = function(self, dt)
            if self.pressed and not self.toggle then
                self.pressTimer = self.pressTimer + dt
                if self.pressTimer >= self.pressDuration then
                    self.pressed = false
                    self.pressTimer = 0
                end
                return true  -- Animating press effect
            end
            return false  -- Not animating
        end,

        draw = function(self)
            if self._visible == false then return end

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
    opts = opts or {}
    
    -- Resolve theme colors
    local resolvedColors = UI.resolveTheme(opts, "label", {
        fg = colors.white,
        bg = colors.black
    })
    
    local e = {
        type = "label",
        text = opts.text or "",
        fg = resolvedColors.fg,
        bg = resolvedColors.bg,
        x = opts.x or 1, y = opts.y or 1,
        position = opts.position, xOffset = opts.xOffset, yOffset = opts.yOffset,
        _visible = opts.visible ~= nil and opts.visible or true,
        draw = function(self)
            if self._visible == false then return end

            UI.term.setTextColor(self.fg)
            UI.term.setBackgroundColor(self.bg)
            UI.term.setCursorPos(self.x, self.y)
            UI.term.write(self.text)
        end
    }
    return UI.addElement(defaultScene(opts), e)
end

function UI.checkbox(opts)
    opts = opts or {}
    
    -- Resolve theme colors
    local resolvedColors = UI.resolveTheme(opts, "checkbox", {
        fg = colors.white,
        bg = colors.black,
        checked = colors.lime
    })
    
    local e = {
        type = "checkbox",
        text = opts.text or "",
        checked = opts.initial or false,
        x = opts.x or 1, y = opts.y or 1,
        width = #("[X] " .. (opts.text or "")), height = 1,
        fg = resolvedColors.fg,
        bg = resolvedColors.bg,
        checkedColor = resolvedColors.checked,
        position = opts.position, xOffset = opts.xOffset, yOffset = opts.yOffset,
        _visible = opts.visible ~= nil and opts.visible or true,
        onClick = function(self)
            self.checked = not self.checked
            UI.markDirty()
            if opts.onclick then opts.onclick(self, self.checked) end
            return true  -- Mark as handled
        end,
        draw = function(self)
            if self._visible == false then return end

            local box = self.checked and "[x] " or "[ ] "
            UI.term.setTextColor(self.fg)
            UI.term.setBackgroundColor(self.bg)

            -- DEBUG: Validate position before drawing
            if type(self.x) ~= "number" or type(self.y) ~= "number" then
                if UI.contextTable.functions and UI.contextTable.functions.log then
                    UI.contextTable.functions.log(string.format(
                        "ERROR in checkbox draw: x=%s, y=%s, text=%s, type(x)=%s, type(y)=%s",
                        tostring(self.x), tostring(self.y), tostring(self.text),
                        type(self.x), type(self.y)
                    ))
                end
                return -- Skip drawing this element
            end

            UI.term.setCursorPos(self.x, self.y)
            UI.term.write(box)
            
            -- Color the X if checked
            if self.checked then
                UI.term.setCursorPos(self.x + 1, self.y)
                UI.term.setTextColor(self.checkedColor)
                UI.term.write("x")
                UI.term.setTextColor(self.fg)
                UI.term.setCursorPos(self.x + 3, self.y)
            end
            
            UI.term.write(self.text)
        end
    }
    return UI.addElement(defaultScene(opts), e)
end

function UI.textfield(opts)
    opts = opts or {}
    
    -- Resolve theme colors
    local resolvedColors = UI.resolveTheme(opts, "textfield", {
        fg = colors.white,
        bg = colors.gray,
        bgActive = colors.lightGray
    })
    
    local e = {
        type = "textfield",
        text = opts.text or "",
        width = opts.width or 10,
        fg = resolvedColors.fg,
        bg = resolvedColors.bg,
        bgActive = resolvedColors.bgActive,
        position = opts.position,
        xOffset = opts.xOffset,
        yOffset = opts.yOffset,
        x = opts.x or 1,
        y = opts.y or 1,
        _visible = opts.visible ~= nil and opts.visible or true,

        -- Cursor position and animation
        cursorPos = #(opts.text or ""),  -- Cursor position in text (0 = before first char)
        cursorVisible = true,
        cursorTimer = 0,
        cursorBlinkPeriod = 0.5,

        -- Event handlers
        onChar = function(self, ch)
            debugLog("TEXTFIELD:onChar() called with ch:", ch, "cursorPos:", self.cursorPos)
            -- Insert character at cursor position
            local before = self.text:sub(1, self.cursorPos)
            local after = self.text:sub(self.cursorPos + 1)
            self.text = before .. ch .. after
            self.cursorPos = self.cursorPos + 1
            self.cursorVisible = true  -- Reset cursor visibility on input
            self.cursorTimer = 0
            UI.markDirty()
        end,

        onKey = function(self, key)
            debugLog("TEXTFIELD:onKey() called with key:", key)
            local name = keys.getName(key)

            if name == "backspace" then
                if self.cursorPos > 0 then
                    -- Delete character before cursor
                    local before = self.text:sub(1, self.cursorPos - 1)
                    local after = self.text:sub(self.cursorPos + 1)
                    self.text = before .. after
                    self.cursorPos = self.cursorPos - 1
                    self.cursorVisible = true
                    self.cursorTimer = 0
                    UI.markDirty()
                end
            elseif name == "delete" then
                if self.cursorPos < #self.text then
                    -- Delete character after cursor
                    local before = self.text:sub(1, self.cursorPos)
                    local after = self.text:sub(self.cursorPos + 2)
                    self.text = before .. after
                    self.cursorVisible = true
                    self.cursorTimer = 0
                    UI.markDirty()
                end
            elseif name == "left" then
                -- Move cursor left
                if self.cursorPos > 0 then
                    self.cursorPos = self.cursorPos - 1
                    self.cursorVisible = true
                    self.cursorTimer = 0
                    UI.markDirty()
                end
            elseif name == "right" then
                -- Move cursor right
                if self.cursorPos < #self.text then
                    self.cursorPos = self.cursorPos + 1
                    self.cursorVisible = true
                    self.cursorTimer = 0
                    UI.markDirty()
                end
            elseif name == "home" then
                -- Move to start
                self.cursorPos = 0
                self.cursorVisible = true
                self.cursorTimer = 0
                UI.markDirty()
            elseif name == "end" then
                -- Move to end
                self.cursorPos = #self.text
                self.cursorVisible = true
                self.cursorTimer = 0
                UI.markDirty()
            end
        end,

        onClick = function(self)
            debugLog("TEXTFIELD:onClick() setting focus")
            UI.focused = self
            -- Reset cursor to end when clicking
            self.cursorPos = #self.text
            self.cursorVisible = true
            self.cursorTimer = 0
            UI.markDirty()
            return true  -- Mark as handled
        end,

        -- Animation update for cursor blink
        update = function(self, dt)
            if UI.focused ~= self then return false end

            self.cursorTimer = self.cursorTimer + dt
            if self.cursorTimer >= self.cursorBlinkPeriod then
                self.cursorVisible = not self.cursorVisible
                self.cursorTimer = 0
                return true  -- Cursor blinked
            end
            return false  -- Still waiting for blink
        end,

        draw = function(self)
            if self._visible == false then return end

            local bg = (UI.focused == self) and self.bgActive or self.bg
            UI.term.setBackgroundColor(bg)
            UI.term.setTextColor(self.fg)
            UI.term.setCursorPos(self.x, self.y)

            -- Build display text with cursor at position
            local displayText
            if UI.focused == self and self.cursorVisible then
                -- Insert cursor at cursorPos
                local before = self.text:sub(1, self.cursorPos)
                local after = self.text:sub(self.cursorPos + 1)
                displayText = before .. "_" .. after
            else
                displayText = self.text
            end

            -- Pad or truncate to width
            if #displayText < self.width then
                displayText = displayText .. string.rep(" ", self.width - #displayText)
            else
                displayText = displayText:sub(1, self.width)
            end

            UI.term.write(displayText)
        end
    }
    return UI.addElement(defaultScene(opts), e)
end

function UI.rectangle(opts)
    opts = opts or {}
    
    -- Resolve theme colors
    local resolvedColors = UI.resolveTheme(opts, "rectangle", {
        fg = colors.white,
        bg = colors.black
    })
    
    local e = {
        type = "rectangle",
        width = opts.width or 5,
        height = opts.height or 3,
        fg = resolvedColors.fg,
        bg = resolvedColors.bg,
        filled = opts.filled ~= false,
        position = opts.position,
        xOffset = opts.xOffset,
        yOffset = opts.yOffset,
        x = opts.x or 1,
        y = opts.y or 1,
        _visible = opts.visible ~= nil and opts.visible or true,
        draw = function(self)
            if self._visible == false then return end

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

------------------------------------------------------------------
-- ANIMATED LABEL ELEMENT
------------------------------------------------------------------
function UI.animatedLabel(opts)
    opts = opts or {}
    
    -- Resolve theme colors
    local resolvedColors = UI.resolveTheme(opts, "animatedLabel", {
        fg = colors.white,
        bg = colors.black
    })
    
    local e = {
        type = "animatedLabel",
        frames = opts.frames or { "..." },  -- List of strings to cycle through
        currentFrame = 1,
        frameDuration = opts.frameDuration or 0.5,  -- Time between frames
        frameTimer = 0,
        animating = opts.animating ~= false,  -- Default to animating
        fg = resolvedColors.fg,
        bg = resolvedColors.bg,
        x = opts.x or 1,
        y = opts.y or 1,
        position = opts.position,
        xOffset = opts.xOffset,
        yOffset = opts.yOffset,
        _visible = opts.visible ~= nil and opts.visible or true,

        -- Methods to control animation
        start = function(self)
            self.animating = true
            UI.markDirty()
        end,

        stop = function(self)
            self.animating = false
            UI.markDirty()
        end,

        toggle = function(self)
            self.animating = not self.animating
            UI.markDirty()
        end,

        setFrames = function(self, newFrames)
            self.frames = newFrames
            self.currentFrame = 1
            UI.markDirty()
        end,

        -- Update function for animation
        update = function(self, dt)
            if not self.animating then return false end

            self.frameTimer = self.frameTimer + dt
            if self.frameTimer >= self.frameDuration then
                self.frameTimer = 0
                self.currentFrame = (self.currentFrame % #self.frames) + 1
                return true  -- Frame changed
            end
            return false  -- Still waiting for next frame
        end,

        -- Draw function
        draw = function(self)
            if self._visible == false then return end

            local text = self.frames[self.currentFrame] or ""
            UI.term.setTextColor(self.fg)
            UI.term.setBackgroundColor(self.bg)
            UI.term.setCursorPos(self.x, self.y)
            UI.term.write(text)
        end
    }

    return UI.addElement(defaultScene(opts), e)
end

------------------------------------------------------------------
-- TERMINAL ELEMENT (TUI Console)
------------------------------------------------------------------
function UI.terminal(opts)
    opts = opts or {}
    
    -- Resolve theme colors
    local resolvedColors = UI.resolveTheme(opts, "terminal", {
        fg = colors.white,
        bg = colors.black,
        prompt = colors.lime,
        spinner = colors.cyan
    })
    
    local e = {
        type = "terminal",
        x = 1, y = 1,
        width = opts.width or 50,
        height = opts.height or 12,
        fg = resolvedColors.fg,
        bg = resolvedColors.bg,
        promptColor = resolvedColors.prompt,
        spinnerColor = resolvedColors.spinner,
        position = opts.position or "topLeft",
        xOffset = opts.xOffset or 0,
        yOffset = opts.yOffset or 0,
        lines = opts.lines or {},
        scrollOffset = 0,
        cursorBlink = true,
        cursorTimer = 0,
        cursorVisible = true,
        activePrompt = nil,    -- {prefix, callback, buffer}
        spinner = nil,         -- {chars, i, label, timer}
        blinkPeriod = 0.5,
        _visible = opts.visible ~= nil and opts.visible or true
    }

    --------------------------------------------------------------
    -- DRAW
    --------------------------------------------------------------
    e.draw = function(self)
        if self._visible == false then return end

        UI.term.setBackgroundColor(self.bg)
        UI.term.setTextColor(self.fg)

        -- Clear the entire terminal area first
        for i = 0, self.height - 1 do
            UI.term.setCursorPos(self.x, self.y + i)
            UI.term.write(string.rep(" ", self.width))
        end
        
        -- visible lines (reserve 1 line for bottom prompt/spinner)
        local start = math.max(1, #self.lines - self.height + 2 - self.scrollOffset)
        local linesAvailable = self.height - 1  -- Reserve bottom line for prompt/spinner
        for i = start, math.min(#self.lines, start + linesAvailable - 1) do
            local line = self.lines[i] or ""
            local yPos = self.y + (i - start)
            UI.term.setCursorPos(self.x, yPos)
            local displayLine = line:sub(1, self.width)
            displayLine = displayLine .. string.rep(" ", self.width - #displayLine)
            UI.term.write(displayLine)
        end

        -- bottom line: prompt or spinner
        local bottomY = self.y + self.height - 1
        UI.term.setCursorPos(self.x, bottomY)

        if self.activePrompt then
            local prefix = self.activePrompt.prefix or ">"
            local text = self.activePrompt.buffer or ""
            local cursor = (self.cursorVisible and self.cursorBlink) and "_" or " "
            local display = prefix .. " " .. text .. cursor
            display = display .. string.rep(" ", self.width - #display)
            UI.term.write(display:sub(1, self.width))
        elseif self.spinner then
            local char = self.spinner.chars[self.spinner.i]
            local text = string.format("%s %s", char, self.spinner.label or "")
            text = text .. string.rep(" ", self.width - #text)
            UI.term.write(text:sub(1, self.width))  
        else
            UI.term.write(string.rep(" ", self.width))
        end
    end

    --------------------------------------------------------------
    -- METHODS
    --------------------------------------------------------------
    function e:append(text)
        debugLog("TERMINAL:append() called with text:", text)
        table.insert(self.lines, text)
        if #self.lines > 200 then table.remove(self.lines, 1) end
        debugLog("TERMINAL:append() lines count now:", #self.lines)
        UI.markDirty()
    end

    function e:clear()
        debugLog("TERMINAL:clear() called")
        self.lines = {}
        UI.markDirty()
    end

    function e:prompt(prefix, callback)
        debugLog("TERMINAL:prompt() called with prefix:", prefix)
        debugLog("TERMINAL:prompt() activePrompt was:", self.activePrompt and "active" or "nil")
        self.activePrompt = { prefix = prefix or ">", callback = callback, buffer = "" }
        UI.focused = self  -- Set focus when prompting
        debugLog("TERMINAL:prompt() set new activePrompt, focused=self")
        UI.markDirty()
    end

    function e:startSpinner(label)
        debugLog("TERMINAL:startSpinner() called with label:", label)
        debugLog("TERMINAL:startSpinner() activePrompt is:", self.activePrompt and "active" or "nil")
        self.spinner = { chars = { "|", "/", "-", "\\" }, i = 1, label = label or "", timer = 0 }
        UI.markDirty()
    end

    function e:stopSpinner(finalText)
        debugLog("TERMINAL:stopSpinner() called with finalText:", finalText)
        if finalText then
            table.insert(self.lines, finalText)
            if #self.lines > 200 then table.remove(self.lines, 1) end
        end
        self.spinner = nil
        debugLog("TERMINAL:stopSpinner() spinner cleared")
        UI.markDirty()
    end

    --------------------------------------------------------------
    -- EVENT HANDLERS
    --------------------------------------------------------------
    e.onKey = function(self, key)
        debugLog("TERMINAL:onKey() called, key:", key, "name:", keys.getName(key))
        debugLog("TERMINAL:onKey() activePrompt:", self.activePrompt and "active" or "nil")
        if not self.activePrompt then
            debugLog("TERMINAL:onKey() no activePrompt, returning")
            return
        end
        local name = keys.getName(key)
        if name == "enter" then
            local txt = self.activePrompt.buffer
            local cb = self.activePrompt.callback
            debugLog("TERMINAL:onKey(enter) buffer:", txt)
            debugLog("TERMINAL:onKey(enter) appending to lines...")
            self:append(self.activePrompt.prefix .. " " .. txt)
            debugLog("TERMINAL:onKey(enter) clearing activePrompt and focus")
            self.activePrompt = nil
            UI.focused = nil
            debugLog("TERMINAL:onKey(enter) calling callback with txt:", txt)
            if cb then cb(txt) end
            debugLog("TERMINAL:onKey(enter) callback completed")
        elseif name == "backspace" then
            local buf = self.activePrompt.buffer
            self.activePrompt.buffer = buf:sub(1, #buf - 1)
            debugLog("TERMINAL:onKey(backspace) new buffer:", self.activePrompt.buffer)
        end
        UI.markDirty()
    end

    e.onChar = function(self, ch)
        debugLog("TERMINAL:onChar() called with ch:", ch)
        debugLog("TERMINAL:onChar() activePrompt:", self.activePrompt and "active" or "nil")
        if self.activePrompt then
            self.activePrompt.buffer = (self.activePrompt.buffer or "") .. ch
            debugLog("TERMINAL:onChar() new buffer:", self.activePrompt.buffer)
            UI.markDirty()
        end
    end

    e.onScroll = function(self, dir)
        self.scrollOffset = math.max(0, math.min(self.scrollOffset + dir, #self.lines - self.height + 1))
        UI.markDirty()
    end

    --------------------------------------------------------------
    -- ANIMATION UPDATE (called every frame)
    --------------------------------------------------------------
    e.update = function(self, dt)
        local changed = false

        self.cursorTimer = self.cursorTimer + dt
        if self.cursorTimer >= self.blinkPeriod then
            self.cursorVisible = not self.cursorVisible
            self.cursorTimer = 0
            changed = true
        end

        if self.spinner then
            self.spinner.timer = self.spinner.timer + dt
            if self.spinner.timer >= 0.15 then
                self.spinner.timer = 0
                self.spinner.i = (self.spinner.i % #self.spinner.chars) + 1
                changed = true
            end
        end

        return changed  -- Return whether anything changed
    end

    return UI.addElement(defaultScene(opts), e)
end

-------------------------------------------------
-- Main Tick Function (non-blocking, call each frame)
-------------------------------------------------
local lastTickTime = nil
local tickTimer = nil

-------------------------------------------------
-- Parallel Run Loop (recommended approach)
-------------------------------------------------
-- Runs render loop at fixed FPS in parallel with event handling
-- This prevents flicker from rapid events
function UI.run(opts)
    opts = opts or {}
    local fps = opts.fps or 30
    local onTick = opts.onTick  -- Optional callback called each render frame

    local function updateEvents()
        while true do
            local event, p1, p2, p3 = os.pullEvent()

            if event == "char" then
                if UI.focused and UI.focused.onChar then
                    UI.focused:onChar(p1)
                end
            elseif event == "key" then
                if UI.focused and UI.focused.onKey then
                    UI.focused:onKey(p1)
                end
            elseif event == "mouse_click" then
                UI.handleClick(p2, p3)
            elseif event == "monitor_touch" then
                -- p1 = side, p2 = x, p3 = y
                UI.handleClick(p2, p3)
            elseif event == "mouse_scroll" then
                UI.handleScroll(p1, p2, p3)
            end
        end
    end

    local function renderUI()
        local lastTickTime = os.clock()
        while true do
            -- Optional per-frame callback
            if onTick then onTick() end

            -- Calculate delta time for animations
            local now = os.clock()
            local dt = now - lastTickTime
            lastTickTime = now

            -- Update animations
            UI.update(dt)

            -- Render (dirty flag prevents unnecessary renders)
            UI.render()

            sleep(.001)
        end
    end

    parallel.waitForAny(renderUI, updateEvents)
end

return UI