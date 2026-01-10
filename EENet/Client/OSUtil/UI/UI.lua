-- UI.lua v2.0 — Dirty Flag Rendering
-- CC:Tweaked UI Framework with parallel render loop and dirty flag optimization
-- Features: element-level draw(), scene management, animations, event handling
-- Compatible with browser.lua and MiniMark renderer

local ENABLE_LOG = false  -- Set to true for debugging
local LOG_FILE = "applications/EEBrowser/logs/ui_debug.log"

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

    local mode = fs.exists(LOG_FILE) and "a" or "w"
    local f = fs.open(LOG_FILE, mode)
    if f then
        f.write(line)
        f.close()
    end
end

local UI = {
    contextTable = {},
    term = term,
    focused = nil,
    scenes = {},
    elements = {},
    -- Global event registry (for true global listeners that ignore scenes)
    _globalEventRegistry = {},  -- [eventName] = { fn1, fn2, ... }
    -- Layout building state
    _buildingLayout = false,
    _layoutParent = nil,
    -- Pointer state for event routing
    lastPointerX = nil,
    lastPointerY = nil
}

-------------------------------------------------
-- Event Subscription System
-------------------------------------------------

-- Dispatch an event to all element-local subscribers in the active scene tree
local function _emitToElements(eventName, ...)
    local elements = UI.contextTable.elements
    if not elements then return end

    for i = 1, #elements do
        local e = elements[i]
        if UI.isVisible(e) and e._subscriptions then
            local list = e._subscriptions[eventName]
            if list then
                for j = 1, #list do
                    list[j](e, eventName, ...)
                end
            end
        end
    end
end

-- Dispatch to global listeners (always fire, regardless of scene)
local function _emitToGlobals(eventName, ...)
    local reg = UI._globalEventRegistry
    if not reg then return end
    local list = reg[eventName]
    if not list then return end
    for i = 1, #list do
        list[i](eventName, ...)
    end
end

-- Public event broadcast
function UI.emitEvent(eventName, ...)
    _emitToElements(eventName, ...)
    _emitToGlobals(eventName, ...)
end

-- Subscribe a global event listener (non-element, always active)
-- Returns an unsubscribe function that can be called to remove the listener
function UI.subscribeGlobalEvent(eventName, fn)
    local reg = UI._globalEventRegistry
    local list = reg[eventName]
    if not list then
        list = {}
        reg[eventName] = list
    end
    table.insert(list, fn)

    -- Return unsubscribe function
    return function()
        for i = #list, 1, -1 do
            if list[i] == fn then
                table.remove(list, i)
                break
            end
        end
    end
end

-- Attach subscription API to an element (element-local subscriptions)
function UI._attachSubscriptionAPI(e)
    -- Element-local subscriptions: self._subscriptions[eventName] = { fn1, fn2, ... }
    function e:subscribeEvent(eventName, fn)
        if not self._subscriptions then
            self._subscriptions = {}
        end
        local list = self._subscriptions[eventName]
        if not list then
            list = {}
            self._subscriptions[eventName] = list
        end
        table.insert(list, fn)
    end

    -- Optional helper for manual unsubscription
    function e:unsubscribeEvent(eventName, fn)
        if not self._subscriptions then return end
        local list = self._subscriptions[eventName]
        if not list then return end
        for i = #list, 1, -1 do
            if list[i] == fn then
                table.remove(list, i)
            end
        end
        if #list == 0 then
            self._subscriptions[eventName] = nil
        end
    end
end

-------------------------------------------------
-- Hook Normalization System
-------------------------------------------------

-- Event style hooks
local EVENT_HOOK_NAMES = {
    "onClick",
    "onPress",
    "onRelease",
    "onTouch",
    "onDrag",
    "onDragEnd",
    "onScroll",
    "onChar",
    "onKey",
    "onFocus",
    "onBlur",
    "onDestroy",
}

-- Lifecycle hooks
local LIFECYCLE_HOOK_NAMES = {
    "onUpdate",
    "onDraw",   -- used as a hook that wraps draw
}

-- Normalize legacy hook names in opts to canonical names
local function normalizeHookOpts(opts)
    if not opts then return end

    -- Pointer hooks
    if opts.onclick  and not opts.onClick  then opts.onClick  = opts.onclick  end
    if opts.onpress  and not opts.onPress  then opts.onPress  = opts.onpress  end
    if opts.onrelease and not opts.onRelease then opts.onRelease = opts.onrelease end
    if opts.ontouch  and not opts.onTouch  then opts.onTouch  = opts.ontouch  end

    -- Keyboard hooks
    if opts.onchar   and not opts.onChar   then opts.onChar   = opts.onchar   end
    if opts.onkey    and not opts.onKey    then opts.onKey    = opts.onkey    end

    -- Lifecycle hook aliases in opts
    if opts.update   and not opts.onUpdate then opts.onUpdate = opts.update   end
    if opts.draw     and not opts.onDraw   then opts.onDraw   = opts.draw     end
end

-- Attach hook API to element - wraps built-in handlers with user hooks
function UI._attachHookAPI(e)
    local opts = e.opts
    if not opts then return end

    normalizeHookOpts(opts)

    -- 1. Event hooks: wrap built in behaviour with user hooks
    for _, name in ipairs(EVENT_HOOK_NAMES) do
        local userFn = opts[name]
        if userFn then
            if e[name] then
                -- Element already has a built in handler, wrap it
                local base = e[name]
                e[name] = function(self, ...)
                    local r1 = base(self, ...)
                    local r2 = userFn(self, ...)
                    -- For events we do not care about the return value
                    return r2 ~= nil and r2 or r1
                end
            else
                -- No built in handler, just attach user hook directly
                e[name] = userFn
            end
        end
    end

    -- 2. Lifecycle: onUpdate
    if opts.onUpdate then
        local userFn = opts.onUpdate

        if e.onUpdate then
            local base = e.onUpdate
            e.onUpdate = function(self, dt)
                local r1 = base(self, dt)
                local r2 = userFn(self, dt)
                -- Match UI.update expectations: anything not false means changed
                if r1 == false and r2 == false then
                    return false
                end
                return true
            end
        else
            e.onUpdate = function(self, dt)
                return userFn(self, dt)
            end
        end
    end

    -- 3. Lifecycle: onDraw hook that wraps draw
    if opts.onDraw then
        local userFn = opts.onDraw

        if e.draw then
            local base = e.draw
            e.draw = function(self, offsetX, offsetY)
                base(self, offsetX, offsetY)
                userFn(self, offsetX, offsetY)
            end
        else
            e.draw = function(self, offsetX, offsetY)
                userFn(self, offsetX, offsetY)
            end
        end
    end
end

-------------------------------------------------
-- Visibility Helpers
-------------------------------------------------
function UI.isVisible(e)
    if not e then return false end

    -- New canonical flag
    if e.visible == false then
        return false
    end

    -- Backwards compatibility for older elements using _visible
    if e._visible == false then
        return false
    end

    return true
end

function UI.show(e)
    if not e then return end
    e.visible = true
    e._visible = true -- keep in sync for back-compat
    UI.markDirty()
end

function UI.hide(e)
    if not e then return end
    e.visible = false
    e._visible = false -- keep in sync for back-compat
    UI.markDirty()
end

-------------------------------------------------
-- Focus Model
-------------------------------------------------
function UI.setFocus(e, opts)
    opts = opts or {}

    -- If something is focused and has lockFocus, do not change focus
    -- unless we explicitly force it.
    if UI.focused and UI.focused.lockFocus and not opts.force then
        return
    end

    if UI.focused == e then return end

    if UI.focused and UI.focused.onBlur then
        UI.focused:onBlur()
    end

    UI.focused = e

    if e and e.onFocus then
        e:onFocus()
    end

    UI.markDirty()
end

function UI.clearFocus(opts)
    UI.setFocus(nil, opts)
end

function UI._attachFocusAPI(e)
    function e:requestFocus(opts)
        UI.setFocus(self, opts)
    end
end

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

-- Register a theme (palette-based system)
-- Theme structure: {roles = {...}, palette = {...}}
function UI.registerTheme(name, theme)
    if not UI.contextTable.themes then
        UI.initThemes()
    end

    -- Validate theme structure
    if not theme.roles then
        error("Theme '" .. name .. "' missing 'roles' table")
    end

    -- Palette is optional (for themes that don't remap colors)
    if theme.palette then
        -- Validate palette entries are numbers
        for color, rgb in pairs(theme.palette) do
            if type(rgb) ~= "number" then
                error("Theme '" .. name .. "' palette entry must be hex number (e.g., 0x1E1E2E)")
            end
        end
    end

    UI.contextTable.themes[name] = theme
end

-- Recursive helper to apply theme to element tree
local function applyThemeRecursive(e)
    if e.applyTheme then
        e:applyTheme()
    end
    if e.children then
        for i = 1, #e.children do
            applyThemeRecursive(e.children[i])
        end
    end
end

-- Apply theme to all existing elements in all scenes
function UI.applyThemeToAll()
    local scenes = UI.contextTable.scenes
    if not scenes then return end

    for _, scene in pairs(scenes) do
        local roots = scene.elements
        if roots then
            for i = 1, #roots do
                applyThemeRecursive(roots[i])
            end
        end
    end
end

-- Set active theme and apply palette remapping
function UI.setTheme(themeName)
    if not UI.contextTable.themes then
        UI.initThemes()
    end

    local theme = UI.contextTable.themes[themeName]
    if not theme then
        error("Theme '" .. tostring(themeName) .. "' not found")
    end

    -- Apply palette remapping if present, otherwise reset to CC defaults
    if theme.palette then
        for color, rgb in pairs(theme.palette) do
            term.setPaletteColor(color, rgb)
        end
    else
        -- No palette specified - reset to ComputerCraft defaults
        UI.resetPalette()
    end

    UI.contextTable.currentTheme = themeName

    -- Re-apply theme to all existing elements
    UI.applyThemeToAll()

    -- Clear screen with new background color
    if theme.roles and theme.roles.background then
        term.setBackgroundColor(theme.roles.background)
        term.clear()
        term.setCursorPos(1, 1)
    end

    UI.markDirty()
end

-- Get current theme object
function UI.getCurrentTheme()
    if not UI.contextTable.currentTheme then
        return nil
    end
    return UI.contextTable.themes[UI.contextTable.currentTheme]
end

-- Reset palette to ComputerCraft defaults
function UI.resetPalette()
    -- CC default palette values
    local defaults = {
        [colors.white] = 0xF0F0F0,
        [colors.orange] = 0xF2B233,
        [colors.magenta] = 0xE57FD8,
        [colors.lightBlue] = 0x99B2F2,
        [colors.yellow] = 0xDEDE6C,
        [colors.lime] = 0x7FCC19,
        [colors.pink] = 0xF2B2CC,
        [colors.gray] = 0x4C4C4C,
        [colors.lightGray] = 0x999999,
        [colors.cyan] = 0x4C99B2,
        [colors.purple] = 0xB266E5,
        [colors.blue] = 0x3366CC,
        [colors.brown] = 0x7F664C,
        [colors.green] = 0x57A64E,
        [colors.red] = 0xCC4C4C,
        [colors.black] = 0x191919
    }

    for color, rgb in pairs(defaults) do
        term.setPaletteColor(color, rgb)
    end
end

-- Resolve color from theme role with fallback
-- Usage: UI.resolveColor("interactive", colors.blue)
function UI.resolveColor(roleName, fallback)
    local theme = UI.getCurrentTheme()
    if theme and theme.roles and theme.roles[roleName] then
        return theme.roles[roleName]
    end
    return fallback
end

--- Resolve a color from an element opt value + theme role.
-- @param optValue        Any: nil, number (literal color), or string (role name)
-- @param defaultRole     String: role name to use when optValue is nil
-- @param defaultFallback Number: fallback CC color index if theme doesn't define the role
function UI.resolveOptColor(optValue, defaultRole, defaultFallback)
    -- Explicit override present in opts
    if optValue ~= nil then
        local t = type(optValue)
        if t == "number" then
            -- Literal CC color index (colors.red, etc.) – theme will NOT change this
            return optValue
        elseif t == "string" then
            -- Treat as theme role / key: "danger", "border", "button.primary", etc.
            return UI.resolveColor(optValue, defaultFallback)
        else
            -- Unsupported type – fall back
            return defaultFallback
        end
    end

    -- No explicit opt override → use default role from current theme
    return UI.resolveColor(defaultRole, defaultFallback)
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

-- Register default theme (roles-based system, no palette remapping)
function UI.registerDefaultTheme()
    UI.registerTheme("default", {
        -- Semantic role mappings
        roles = {
            background = colors.black,
            text = colors.white,
            textDim = colors.lightGray,
            textMuted = colors.lightGray,

            surface = colors.gray,
            surfaceAlt = colors.black,
            surfaceAlt2 = colors.black,
            border = colors.gray,

            headerBg = colors.gray,
            headerText = colors.white,

            accent = colors.orange,
            accentText = colors.black,

            interactive = colors.blue,
            interactiveHover = colors.lightBlue,
            interactiveActive = colors.cyan,
            interactiveDisabled = colors.gray,
            interactiveText = colors.white,

            success = colors.green,
            error = colors.red,
            warning = colors.yellow,
            info = colors.lightBlue,
            selection = colors.blue
        }

        -- No palette remapping - use ComputerCraft defaults
    })

    -- Set default theme as active
    UI.setTheme("default")
end


--------------------------------------------------------------
-- Update animation and cursor/spinner elements each frame
--------------------------------------------------------------
local function updateElement(e, dt)
    local changed = false

    -- Prefer canonical onUpdate, but fall back to legacy update
    local updater = e.onUpdate or e.update
    if updater then
        local result = updater(e, dt)
        if result ~= false then
            changed = true
        end
    end

    -- Recursively update children
    if e.children then
        for _, child in ipairs(e.children) do
            if updateElement(child, dt) then
                changed = true
            end
        end
    end

    return changed
end

function UI.update(dt)
    -- Update all elements and mark dirty if any changed
    local anyChanged = false
    for _, e in ipairs(UI.contextTable.elements) do
        if updateElement(e, dt) then
            anyChanged = true
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

-- Clears all elements and children from a scene with proper cleanup.
-- Useful for removing interactive overlays when changing pages/content.
-- Note: Child scenes are rendered after their parent scene, so overlays placed
-- in a child scene naturally draw on top of parent content.
function UI.clearScene(sceneName)
    sceneName = sceneName or UI.activeScene
    if not sceneName then return end

    local scene = UI.contextTable.scenes[sceneName]
    if not scene or not scene.elements then return end

    -- Destroy all root elements (recursively cleans up children too)
    for i = #scene.elements, 1, -1 do
        UI.destroyElement(scene.elements[i], sceneName)
    end

    scene.elements = {}
    scene.children = {}

    if sceneName == UI.activeScene then
        UI.setScene(UI.activeScene)
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
    -- 1) If this element declares a parent in its opts, attach to that parent
    local opts = element.opts
    if opts and opts.parent then
        local parent = opts.parent

        -- Prefer the parent's addChild method if it exists,
        -- so containers can handle layout/markDirty however they want.
        if type(parent.addChild) == "function" then
            return parent:addChild(element)
        else
            -- Fallback: attach manually
            parent.children = parent.children or {}
            table.insert(parent.children, element)
            element._parent = parent

            if type(parent.layout) == "function" then
                parent:layout()
            end
            if UI.markDirty then
                UI.markDirty()
            end

            return element
        end
    end

    -- 2) Legacy layout-building magic (optional; can be removed later)
    if UI._buildingLayout and UI._layoutParent then
        UI._layoutParent.children = UI._layoutParent.children or {}
        table.insert(UI._layoutParent.children, element)
        element._parent = UI._layoutParent
        return element
    end

    -- 3) Normal scene-root registration
    if not sceneName then sceneName = UI.activeScene end
    if not sceneName then
        error("UI.addElement: No active scene")
    end

    local scene = UI.contextTable.scenes[sceneName]
    if not scene then
        error("UI.addElement: Scene '" .. tostring(sceneName) .. "' not found")
    end

    scene.elements = scene.elements or {}
    table.insert(scene.elements, element)
    element._sceneName = sceneName

    -- If this is the active scene, refresh the flattened element list
    if sceneName == UI.activeScene and not UI._buildingLayout then
        UI.setScene(UI.activeScene)
    end

    return element
end

--- Remove an element from a scene
function UI.removeElement(element, sceneName)
    if not sceneName then sceneName = UI.activeScene end
    if not sceneName then error("UI.removeElement: No active scene or target scene") end

    local scene = UI.contextTable.scenes[sceneName]
    if not scene then error("UI.removeElement: Scene '" .. sceneName .. "' not found") end

    -- Find and remove the element
    for i, e in ipairs(scene.elements) do
        if e == element then
            table.remove(scene.elements, i)

            -- Auto-refresh if removing from active scene
            if sceneName == UI.activeScene then
                UI.setScene(UI.activeScene)
            end

            return true
        end
    end

    return false  -- Element not found
end

--- Recursively destroy an element and remove it from its scene / parent
function UI.destroyElement(element, sceneName)
    if not element then return end

    -- 1) Recursively destroy children
    if element.children then
        -- Copy the list to avoid modification while iterating
        local children = element.children
        for i = #children, 1, -1 do
            UI.destroyElement(children[i], sceneName)
        end
        element.children = nil
    end

    -- 2) Clear any element-local subscriptions
    element._subscriptions = nil

    -- 3) Fix global pointers
    if UI.focused == element then
        UI.focused = nil
    end
    if UI.pressedElement == element then
        UI.pressedElement = nil
    end
    if UI.draggedElement == element then
        UI.draggedElement = nil
    end

    -- 4) Call onDestroy hook if present
    if element.onDestroy then
        pcall(element.onDestroy, element)
    end

    -- 5) Remove from parent or scene roots
    local parent = element._parent
    if parent and parent.children then
        for i = #parent.children, 1, -1 do
            if parent.children[i] == element then
                table.remove(parent.children, i)
                break
            end
        end
    else
        -- Remove from scene root list
        if not sceneName then sceneName = UI.activeScene end
        if sceneName then
            local scene = UI.contextTable.scenes[sceneName]
            if scene and scene.elements then
                for i = #scene.elements, 1, -1 do
                    if scene.elements[i] == element then
                        table.remove(scene.elements, i)
                        break
                    end
                end
            end
        end
    end

    -- 6) Trigger layout refresh if destroying from active scene
    if sceneName == UI.activeScene then
        UI.setScene(UI.activeScene)
    end
end

--TODO add UI.ClearChildren
-------------------------------------------------
-- Element Bounds Initialization
-------------------------------------------------
function UI.initBounds(e, opts)
    opts = opts or {}

    -- Position within parent/screen
    e.x        = opts.x or e.x or 1
    e.y        = opts.y or e.y or 1
    e.position = opts.position or e.position
    e.xOffset  = opts.xOffset or e.xOffset
    e.yOffset  = opts.yOffset or e.yOffset

    -- Size: constructor-provided width/height take precedence,
    -- then opts, then fall back to text length/1.
    local text = opts.text or e.text

    e.width  = e.width  or opts.width  or (text and #text) or 0
    e.height = e.height or opts.height or 1

    -- Visibility: prefer opts.visible, then existing flags, default true
    if opts.visible ~= nil then
        e.visible  = opts.visible
        e._visible = opts.visible  -- keep in sync for back-compat
    else
        if e.visible == nil and e._visible == nil then
            e.visible  = true
            e._visible = true
        elseif e.visible ~= nil then
            e._visible = e.visible
        elseif e._visible ~= nil then
            e.visible = e._visible
        end
    end

    -- Focusable: prefer opts.focusable, else keep existing or default false
    if opts.focusable ~= nil then
        e.focusable = opts.focusable
    elseif e.focusable == nil then
        e.focusable = false
    end

    return e
end

-------------------------------------------------
-- Positioning: Root Elements
-------------------------------------------------
function UI.applyPositioning(e)
    if not e then return end

    -- Never override dragged elements; their x/y is set by drag logic
    if e.draggable and e._hasBeenDragged then
        return
    end

    -- Only apply to root elements (those without a parent)
    if e._parent then
        return
    end

    local term = UI.term
    local scrW, scrH = term.getSize()

    local w = e.width  or (e.text and #e.text) or 1
    local h = e.height or 1

    -- Default: leave x/y as-is if no anchoring/percent is specified
    local x = e.x or 1
    local y = e.y or 1

    -- Percent-based positioning (relative to screen)
    if e.xPercent then
        x = math.floor(scrW * e.xPercent)
    end
    if e.yPercent then
        y = math.floor(scrH * e.yPercent)
    end

    -- Anchor-based positioning (relative to screen)
    if e.position == "center" then
        x = math.floor((scrW - w) / 2) + 1
        y = math.floor((scrH - h) / 2) + 1
    elseif e.position == "topLeft" then
        x = 1
        y = 1
    elseif e.position == "topRight" then
        x = scrW - w + 1
        y = 1
    elseif e.position == "bottomLeft" then
        x = 1
        y = scrH - h + 1
    elseif e.position == "bottomRight" then
        x = scrW - w + 1
        y = scrH - h + 1
    elseif e.position == "topCenter" then
        x = math.floor((scrW - w) / 2) + 1
        y = 1
    elseif e.position == "bottomCenter" then
        x = math.floor((scrW - w) / 2) + 1
        y = scrH - h + 1
    elseif e.position == "centerLeft" or e.position == "left" or e.position == "leftCenter" then
        x = 1
        y = math.floor((scrH - h) / 2) + 1
    elseif e.position == "centerRight" or e.position == "right" or e.position == "rightCenter" then
        x = scrW - w + 1
        y = math.floor((scrH - h) / 2) + 1
    end

    -- Apply offsets (if provided)
    if e.xOffset then
        x = x + e.xOffset
    end
    if e.yOffset then
        y = y + e.yOffset
    end

    e.x = x
    e.y = y
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

    -- Reset cursor state
    UI._cursorX = nil
    UI._cursorY = nil
    UI._cursorBlink = false

    local function drawScene(scene, offsetX, offsetY)
        for _, e in ipairs(scene.elements or {}) do
            UI.applyPositioning(e) -- Recalculate positioning each render in case of element changing size/position
            if UI.isVisible(e) and e.draw then
                e:draw(offsetX or 0, offsetY or 0)
            end
        end
        for _, c in ipairs(scene.children or {}) do
            local child = UI.contextTable.scenes[c.name]
            if child then
                drawScene(child, (offsetX or 0) + (c.xOffset or 0), (offsetY or 0) + (c.yOffset or 0))
            end
        end
    end

    local active = UI.contextTable.scenes[UI.activeScene]
    if active then
        drawScene(active)
    else
        error("UI.render: no active scene")
    end

    -- Position CC cursor at end of render if textfield set it
    if UI._cursorX and UI._cursorY then
        UI.term.setCursorPos(UI._cursorX, UI._cursorY)
        UI.term.setCursorBlink(UI._cursorBlink)
    else
        UI.term.setCursorBlink(false)
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
-- Positioning: Child Elements (inside parent)
-------------------------------------------------
function UI.applyChildPositioning(parent, child)
    if not parent or not child then return end

    -- Base box = parent's content area
    local px = parent.x or 1
    local py = parent.y or 1
    local pw = parent.width  or 1
    local ph = parent.height or 1

    -- Border is a boolean, convert to numeric size
    local borderSize = (parent.border and 1) or 0
    local padding = parent.padding or 0

    -- Content area (inside border + padding)
    px = px + borderSize + padding
    py = py + borderSize + padding
    pw = pw - 2 * (borderSize + padding)
    ph = ph - 2 * (borderSize + padding)

    if pw < 1 then pw = 1 end
    if ph < 1 then ph = 1 end

    local w = child.width  or (child.text and #child.text) or 1
    local h = child.height or 1

    -- Default: keep existing child.x/child.y if no position/percent is set
    local cx = child.x or px
    local cy = child.y or py

    -- Percent-based positioning (relative to parent content box)
    if child.xPercent then
        cx = px + math.floor(pw * child.xPercent)
    end
    if child.yPercent then
        cy = py + math.floor(ph * child.yPercent)
    end

    -- Anchor-based positioning inside parent content box
    if child.position == "center" then
        cx = px + math.floor((pw - w) / 2)
        cy = py + math.floor((ph - h) / 2)
    elseif child.position == "topLeft" then
        cx = px
        cy = py
    elseif child.position == "topRight" then
        cx = px + pw - w
        cy = py
    elseif child.position == "bottomLeft" then
        cx = px
        cy = py + ph - h
    elseif child.position == "bottomRight" then
        cx = px + pw - w
        cy = py + ph - h
    elseif child.position == "topCenter" then
        cx = px + math.floor((pw - w) / 2)
        cy = py
    elseif child.position == "bottomCenter" then
        cx = px + math.floor((pw - w) / 2)
        cy = py + ph - h
    elseif child.position == "centerLeft" or child.position == "left" or child.position == "leftCenter" then
        cx = px
        cy = py + math.floor((ph - h) / 2)
    elseif child.position == "centerRight" or child.position == "right" or child.position == "rightCenter" then
        cx = px + pw - w
        cy = py + math.floor((ph - h) / 2)
    end

    -- Apply offsets (local to parent)
    if child.xOffset then
        cx = cx + child.xOffset
    end
    if child.yOffset then
        cy = cy + child.yOffset
    end

    child.x = cx
    child.y = cy
end

-------------------------------------------------
-- Hit Testing and Event Bubbling
-------------------------------------------------
local function hitTest(e, x, y)
    if not UI.isVisible(e) then return nil end

    local ex = (e.x or 0) + (e._offsetX or 0)
    local ey = (e.y or 0) + (e._offsetY or 0)
    local w  = e.width  or (e.text and #e.text) or 1
    local h  = e.height or 1

    if not (x >= ex and x < ex + w and y >= ey and y < ey + h) then
        return nil
    end

    if e.children and #e.children > 0 then
        for i = #e.children, 1, -1 do
            local hit = hitTest(e.children[i], x, y)
            if hit then return hit end
        end
    end

    return e
end

local function bubblePointerDown(e, x, y, button, isTouch)
    -- Let ancestors react, but DO NOT decide pressedElement here.
    local current = e
    local claimed = nil

    while current do
        if UI.isVisible(current) and current.onPress then
            local handled = current:onPress(x, y, button, isTouch)
            if handled ~= false then
                claimed = current
                break
            end
        end
        current = current._parent
    end

    return claimed   -- may be nil
end

-------------------------------------------------
-- Input Handling
-------------------------------------------------
-- Track pressed element for click-on-release behavior
UI.pressedElement = nil
UI.pressX = nil
UI.pressY = nil
UI.draggedElement = nil

function UI._handlePointerDown(isTouch, x, y, button)
    local hit = nil

    -- 1) Find deepest hit element among roots
    for i = #UI.contextTable.elements, 1, -1 do
        local root = UI.contextTable.elements[i]
        if UI.isVisible(root) then
            local h = hitTest(root, x, y)
            if h then
                hit = h
                break
            end
        end
    end

    -- 2) Focus logic (click-to-focus)
    if hit and hit.focusable then
        UI.setFocus(hit)       -- respects lockFocus
    else
        UI.clearFocus()
    end

    -- 3) Touch special case: monitor_touch acts like instant click AND press
    if isTouch and hit then
        -- First, try onTouch if it exists
        if hit.onTouch then
            hit:onTouch(x, y)
        end

        -- Also trigger onPress if it exists
        if hit.onPress then
            hit:onPress(x, y, button)
        end

        -- And trigger onClick if it exists (for full compatibility)
        if hit.onClick then
            hit:onClick(x, y, button)
        end

        UI.markDirty()
        return
    end

    -- 4) Press (for mouse events)
    if hit then
        local claimed = bubblePointerDown(hit, x, y, button, isTouch)

        -- IMPORTANT:
        -- pressedElement is either the claimant (container, special handler)
        -- or the raw hit element as a fallback.
        UI.pressedElement = claimed or hit
        UI.pressX, UI.pressY = x, y
    end
end

-- Legacy wrapper
function UI.handleMouseDown(x, y, button, isTouch)
    UI._handlePointerDown(isTouch or false, x, y, button)
end

function UI._handlePointerUp(isTouch, x, y, button)
    -- Dragged element release logic if you support panel dragging, etc.
    if UI.draggedElement then
        local draggedElem = UI.draggedElement
        UI.draggedElement = nil
        if draggedElem.onDragEnd then
            draggedElem:onDragEnd(x, y, button)
        end
    end

    local e = UI.pressedElement
    UI.pressedElement = nil
    UI.pressX, UI.pressY = nil, nil

    if not e then return end

    -- Compute bounds for pressed element
    local ex = (e.x or 0) + (e._offsetX or 0)
    local ey = (e.y or 0) + (e._offsetY or 0)
    local w  = e.width  or (e.text and #e.text) or 1
    local h  = e.height or 1

    local inBounds = (x >= ex and x < ex + w and y >= ey and y < ey + h)

    -- Let element react to release
    if e.onRelease then
        e:onRelease(x, y, button, inBounds, isTouch)
    end

    -- Semantic click: press+release on the same element
    if inBounds and e.onClick then
        e:onClick(x, y, button, isTouch)
    end
end

-- Legacy wrapper
function UI.handleMouseUp(x, y, button)
    UI._handlePointerUp(false, x, y, button)
end

function UI._handlePointerDrag(isTouch, x, y, button)
    local e = UI.pressedElement
    if not e then return end

    local lastX, lastY = UI.lastPointerX or x, UI.lastPointerY or y
    local dx, dy = x - lastX, y - lastY
    UI.lastPointerX, UI.lastPointerY = x, y

    if e.onDrag then
        e:onDrag(x, y, button, dx, dy)
    end
end

function UI._handleScroll(dir, x, y)
    -- Find deepest hit element
    local hit = nil
    for i = #UI.contextTable.elements, 1, -1 do
        local root = UI.contextTable.elements[i]
        if UI.isVisible(root) then
            local h = hitTest(root, x, y)
            if h then
                hit = h
                break
            end
        end
    end

    local current = hit
    while current do
        if UI.isVisible(current) and current.onScroll then
            local handled = current:onScroll(dir, x, y)
            if handled ~= false then
                break
            end
        end
        current = current._parent
    end
end

-- Legacy function for backwards compatibility
function UI.handleClick(x, y, button)
    UI.handleMouseDown(x, y, button or 1, false)
end

function UI.handleScroll(dir, x, y)
    UI._handleScroll(dir, x, y)
end

-------------------------------------------------
-- Keyboard Routing
-------------------------------------------------
function UI._handleChar(ch)
    local e = UI.focused
    if e and e.onChar then
        e:onChar(ch)
    end
end

function UI._handleKey(ev, key, isHeld)
    local e = UI.focused
    if e and e.onKey then
        -- Only process key down events, not key_up (to prevent double processing)
        if ev == "key" then
            e:onKey(key, isHeld, ev)
        end
    end
end

-------------------------------------------------
-- Main Event Entry Point
-------------------------------------------------
function UI.handleEvent(ev, p1, p2, p3, p4)
    -- 1) Pointer + keyboard routing
    if ev == "mouse_click" then
        UI._handlePointerDown(false, p2, p3, p1)   -- isTouch=false, x, y, button
    elseif ev == "mouse_up" then
        UI._handlePointerUp(false, p2, p3, p1)
    elseif ev == "mouse_drag" then
        UI._handlePointerDrag(false, p2, p3, p1)
    elseif ev == "monitor_touch" then
        UI._handlePointerDown(true, p2, p3, 1)     -- isTouch=true, synthetic button=1
    elseif ev == "mouse_scroll" then
        UI._handleScroll(p1, p2, p3)               -- dir, x, y
    elseif ev == "char" then
        UI._handleChar(p1)
    elseif ev == "key" or ev == "key_up" then
        UI._handleKey(ev, p1, p2)
    end

    -- 2) Broadcast this event to subscribers (scene-local + global)
    UI.emitEvent(ev, p1, p2, p3, p4)
end

-------------------------------------------------
-- Layout System
-------------------------------------------------

-- Layout building flag (prevents auto-refresh during layout construction)
UI._buildingLayout = false

--- Vertical Stack Layout
-- Stacks children vertically with optional spacing and alignment
function UI.vstack(opts)
    opts = opts or {}

    local container = {
        type = "vstack",
        children = {},
        spacing = opts.spacing or 0,
        align = opts.align or "left",  -- "left", "center", "right"
        padding = opts.padding or 0,
        position = opts.position,
        xOffset = opts.xOffset or 0,
        yOffset = opts.yOffset or 0,
        x = opts.x or 1,
        y = opts.y or 1,
        width = opts.width,
        height = opts.height,

        -- Methods
        addChild = function(self, element)
            table.insert(self.children, element)
            element._parent = self
            self:layout()
            UI.markDirty()
            return element
        end,

        removeChild = function(self, element)
            for i, child in ipairs(self.children) do
                if child == element then
                    table.remove(self.children, i)
                    self:layout()
                    UI.markDirty()
                    return true
                end
            end
            return false
        end,

        layout = function(self)
            local currentY = self.y + self.padding
            local maxWidth = 0

            for _, child in ipairs(self.children) do
                -- Use child width/height directly (no applyPositioning for children)
                local childWidth = child.width or (child.text and #child.text) or 1
                local childHeight = child.height or 1

                -- Calculate X position based on alignment
                if self.align == "center" and self.width then
                    child.x = self.x + math.floor((self.width - childWidth) / 2)
                elseif self.align == "right" and self.width then
                    child.x = self.x + self.width - childWidth
                else  -- left
                    child.x = self.x + self.padding
                end

                child.y = currentY
                currentY = currentY + childHeight + self.spacing

                if childWidth > maxWidth then
                    maxWidth = childWidth
                end
            end

            -- Auto-calculate container dimensions if not specified
            if not self.width then
                self.width = maxWidth + (self.padding * 2)
            end
            if not self.height then
                self.height = (currentY - self.y) + self.padding - self.spacing
            end
        end,

        draw = function(self)
            if not UI.isVisible(self) then return end

            -- Keep children aligned with parent x/y (in case container was moved/anchored)
            if #self.children > 0 then
                self:layout()
            end

            for _, child in ipairs(self.children) do
                if UI.isVisible(child) and child.draw then
                    child:draw()
                end
            end
        end
    }

    UI._attachSubscriptionAPI(container)
    UI._attachFocusAPI(container)
    UI._attachHookAPI(container)
    if opts.init then opts.init(container) end

    -- If a builder function is provided, use it to add children
    if opts.builder then
        opts.builder(container)
        container:layout()
    end

    return UI.addElement(opts.scene or UI.activeScene, container)
end

--- Horizontal Stack Layout
-- Stacks children horizontally with optional spacing and alignment
function UI.hstack(opts)
    opts = opts or {}

    local container = {
        type = "hstack",
        children = {},
        spacing = opts.spacing or 1,
        align = opts.align or "top",  -- "top", "center", "bottom"
        padding = opts.padding or 0,
        position = opts.position,
        xOffset = opts.xOffset or 0,
        yOffset = opts.yOffset or 0,
        x = opts.x or 1,
        y = opts.y or 1,
        width = opts.width,
        height = opts.height,

        -- Methods
        addChild = function(self, element)
            table.insert(self.children, element)
            element._parent = self
            self:layout()
            UI.markDirty()
            return element
        end,

        removeChild = function(self, element)
            for i, child in ipairs(self.children) do
                if child == element then
                    table.remove(self.children, i)
                    self:layout()
                    UI.markDirty()
                    return true
                end
            end
            return false
        end,

        layout = function(self)
            local currentX = self.x + self.padding
            local maxHeight = 0

            for _, child in ipairs(self.children) do
                -- Use child width/height directly (no applyPositioning for children)
                local childWidth = child.width or (child.text and #child.text) or 1
                local childHeight = child.height or 1

                -- Calculate Y position based on alignment
                if self.align == "center" and self.height then
                    child.y = self.y + math.floor((self.height - childHeight) / 2)
                elseif self.align == "bottom" and self.height then
                    child.y = self.y + self.height - childHeight
                else  -- top
                    child.y = self.y + self.padding
                end

                child.x = currentX
                currentX = currentX + childWidth + self.spacing

                if childHeight > maxHeight then
                    maxHeight = childHeight
                end
            end

            -- Auto-calculate container dimensions if not specified
            if not self.width then
                self.width = (currentX - self.x) + self.padding - self.spacing
            end
            if not self.height then
                self.height = maxHeight + (self.padding * 2)
            end
        end,

        draw = function(self)
            if not UI.isVisible(self) then return end

            -- Keep children aligned with parent x/y (in case container was moved/anchored)
            if #self.children > 0 then
                self:layout()
            end

            for _, child in ipairs(self.children) do
                if UI.isVisible(child) and child.draw then
                    child:draw()
                end
            end
        end
    }

    UI._attachSubscriptionAPI(container)
    UI._attachFocusAPI(container)
    UI._attachHookAPI(container)
    if opts.init then opts.init(container) end

    -- If a builder function is provided, use it to add children
    if opts.builder then
        opts.builder(container)
        container:layout()
    end

    return UI.addElement(opts.scene or UI.activeScene, container)
end

--- Grid Layout
-- Arranges children in a grid with specified columns
function UI.grid(opts)
    opts = opts or {}

    local container = {
        type = "grid",
        children = {},
        columns = opts.columns or 2,
        spacing = opts.spacing or 1,
        rowSpacing = opts.rowSpacing or opts.spacing or 1,
        columnSpacing = opts.columnSpacing or opts.spacing or 1,
        padding = opts.padding or 0,
        position = opts.position,
        xOffset = opts.xOffset or 0,
        yOffset = opts.yOffset or 0,
        x = opts.x or 1,
        y = opts.y or 1,
        width = opts.width,
        height = opts.height,

        -- Methods
        addChild = function(self, element)
            table.insert(self.children, element)
            element._parent = self
            self:layout()
            UI.markDirty()
            return element
        end,

        removeChild = function(self, element)
            for i, child in ipairs(self.children) do
                if child == element then
                    table.remove(self.children, i)
                    self:layout()
                    UI.markDirty()
                    return true
                end
            end
            return false
        end,

        layout = function(self)
            local currentX = self.x + self.padding
            local currentY = self.y + self.padding
            local rowMaxHeight = 0
            local columnWidths = {}

            -- First pass: calculate column widths (no applyPositioning for children)
            for i, child in ipairs(self.children) do
                local childWidth = child.width or (child.text and #child.text) or 1
                local col = (i - 1) % self.columns + 1
                columnWidths[col] = math.max(columnWidths[col] or 0, childWidth)
            end

            -- Second pass: position children
            for i, child in ipairs(self.children) do
                local childWidth = child.width or (child.text and #child.text) or 1
                local childHeight = child.height or 1
                local col = (i - 1) % self.columns + 1

                -- Place child at current position
                child.x = currentX
                child.y = currentY

                -- Track max height in this row
                if childHeight > rowMaxHeight then
                    rowMaxHeight = childHeight
                end

                -- Determine if we need to move to the next row
                -- col goes from 1 to self.columns, so check if we just placed the last column
                if col == self.columns then
                    -- Just placed last item in row, move to next row
                    currentX = self.x + self.padding
                    currentY = currentY + rowMaxHeight + self.rowSpacing
                    rowMaxHeight = 0
                else
                    -- More columns in this row, advance X and add spacing
                    currentX = currentX + columnWidths[col] + self.columnSpacing
                end
            end

            -- Auto-calculate container dimensions if not specified
            if not self.width then
                local totalWidth = self.padding
                for _, w in ipairs(columnWidths) do
                    totalWidth = totalWidth + w + self.columnSpacing
                end
                self.width = totalWidth - self.columnSpacing + self.padding
            end
            if not self.height then
                self.height = (currentY - self.y) + rowMaxHeight + self.padding
            end
        end,

        draw = function(self)
            if not UI.isVisible(self) then return end

            -- Keep children aligned with parent x/y (in case container was moved/anchored)
            if #self.children > 0 then
                self:layout()
            end

            for _, child in ipairs(self.children) do
                if UI.isVisible(child) and child.draw then
                    child:draw()
                end
            end
        end
    }

    UI._attachSubscriptionAPI(container)
    UI._attachFocusAPI(container)
    UI._attachHookAPI(container)
    if opts.init then opts.init(container) end

    -- If a builder function is provided, use it to add children
    if opts.builder then
        opts.builder(container)
        container:layout()
    end

    return UI.addElement(opts.scene or UI.activeScene, container)
end

-------------------------------------------------
-- Element Constructors (each defines its own draw)
-------------------------------------------------
local function defaultScene(opts)
    return opts.scene or UI.activeScene or error("No active scene for element")
end

function UI._drawShadowForElement(e, opts, offsetX, offsetY)
    opts = opts or {}
    offsetX = offsetX or 0
    offsetY = offsetY or 0

    local term = UI.term
    local scrW, scrH = term.getSize()

    local x = (e.x or 1) + offsetX
    local y = (e.y or 1) + offsetY
    local w = e.width or (e.text and #e.text) or 1
    local h = e.height or 1

    local fg = opts.fg or colors.black
    local bg = opts.bg or (UI.resolveColor and UI.resolveColor("background", colors.black)) or colors.black

    -- right side: one char for the very top, another for the rest
    local rightTopChar    = opts.rightTopChar    or "\148" -- top-right corner
    local rightChar       = opts.rightChar       or "\149" -- rest of right side
    local bottomChar      = opts.bottomChar      or "\131" -- bottom strip fill
    local bottomRightChar = opts.bottomRightChar or "\129" -- bottom-right cap
    local bottomLeftChar  = opts.bottomLeftChar  or "\130" -- bottom-left cap

    local bottomY   = y + h - 1
    local rightX    = x + w
    local shadowRow = bottomY + 1

    term.setTextColor(fg)
    term.setBackgroundColor(bg)

    -- Right-side shadow column:
    --   row == y       -> rightTopChar (\148)
    --   row >  y       -> rightChar    (\149)
    if rightX >= 1 and rightX <= scrW then
        for row = y, bottomY do
            if row >= 1 and row <= scrH then
                term.setCursorPos(rightX, row)
                if row == y then
                    term.write(rightTopChar)
                else
                    term.write(rightChar)
                end
            end
        end
    end

    -- Bottom row (one below the element)
    if shadowRow >= 1 and shadowRow <= scrH then
        -- bottom-left
        if x >= 1 and x <= scrW then
            term.setCursorPos(x, shadowRow)
            term.write(bottomLeftChar)
        end

        -- bottom strip: x+1 .. x+w-1
        local stripStart = x + 1
        local stripEnd   = x + w - 1
        if stripStart <= stripEnd and stripStart <= scrW then
            local maxEnd = math.min(stripEnd, scrW)
            if maxEnd >= stripStart then
                term.setCursorPos(stripStart, shadowRow)
                term.write(string.rep(bottomChar, maxEnd - stripStart + 1))
            end
        end

        -- bottom-right at x+w
        local brX = x + w
        if brX >= 1 and brX <= scrW then
            term.setCursorPos(brX, shadowRow)
            term.write(bottomRightChar)
        end
    end
end





function UI.addShadow(element, opts)
    opts = opts or {}
    element._shadowOpts = {
        fg = opts.fg,
        bg = opts.bg,
        rightChar = opts.rightChar,
        bottomChar = opts.bottomChar,
        bottomRightChar = opts.bottomRightChar,
        bottomLeftChar = opts.bottomLeftChar,
    }

    element._baseDraw = element.draw or function() end

    element.draw = function(self, offsetX, offsetY)
        self:_baseDraw(offsetX, offsetY)
        UI._drawShadowForElement(self, self._shadowOpts, offsetX, offsetY)
    end

    return element
end



function UI.button(opts)
    opts = opts or {}

    local text = opts.text or "Button"

    local e = {
        type = "button",
        text = text,
        opts = opts,
        toggle = opts.toggle,
        state = false,
        pressed = false,
        pressedByTouch = false,  -- Track if this was a touch event
        pressTimer = 0,
        pressDuration = 0.1,
        -- no x/y/width/height/visible/position/xOffset/yOffset here

        onPress = function(self, x, y, button)
            -- Set visual pressed state (from mouse click, not touch)
            self.pressed = true
            self.pressedByTouch = false
            self.pressTimer = 0
            UI.markDirty()
            return true  -- Mark as handled
        end,

        onRelease = function(self, x, y, button, inBounds)
            -- Clear visual pressed state
            self.pressed = false
            UI.markDirty()

            -- Only fire onclick if released within bounds
            if inBounds and self.toggle then
                self.state = not self.state
                UI.markDirty()
            end
        end,

        onClick = function(self, x, y, button, isTouch)
            -- Semantic click handler (press + release in bounds)
            -- User hooks will be called via _attachHookAPI
            return true
        end,

        onTouch = function(self, x, y)
            -- Touch screens activate instantly with timer feedback
            if self.toggle then
                self.state = not self.state
            else
                self.pressed = true
                self.pressedByTouch = true  -- Mark as touch event
                self.pressTimer = 0
            end

            UI.markDirty()
        end,

        onUpdate = function(self, dt)
            -- Only auto-clear pressed state for touch events (no release event)
            if self.pressed and self.pressedByTouch and not self.toggle then
                self.pressTimer = self.pressTimer + dt
                if self.pressTimer >= self.pressDuration then
                    self.pressed = false
                    self.pressedByTouch = false
                    self.pressTimer = 0
                    return true
                end
                return true  -- Still animating
            end
            return false
        end,

        draw = function(self)
            if not UI.isVisible(self) then return end

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

    -- Initialize bounds (x, y, width, height, visible, focusable)
    UI.initBounds(e, opts)

    function e:applyTheme()
        local o = self.opts or {}

        self.bg = UI.resolveOptColor(o.bg, "interactive", colors.blue)
        self.fg = UI.resolveOptColor(o.fg, "interactiveText",
                                       UI.resolveColor("text", colors.white))
        self.colorHover = UI.resolveOptColor(o.colorHover, "interactiveHover", colors.lightBlue)
        self.colorPressed = UI.resolveOptColor(o.colorPressed, "interactiveActive", colors.cyan)
        self.bgDisabled = UI.resolveOptColor(o.bgDisabled, "interactiveDisabled", colors.gray)
    end

    -- Initial theming
    e:applyTheme()

    UI._attachSubscriptionAPI(e)
    UI._attachFocusAPI(e)
    UI._attachHookAPI(e)
    if opts.init then opts.init(e) end

    return UI.addElement(opts.scene or UI.activeScene, e)
end


function UI.label(opts)
    opts = opts or {}

    local e = {
        type = "label",
        text = opts.text or "",
        opts = opts,
        -- Note: no x/y/width/height/visible/focusable here;
        -- those are handled by UI.initBounds
        draw = function(self)
            if not UI.isVisible(self) then return end

            -- Use parent's background if we don't have an explicit bg and have a parent
            local bgToUse = self.bg
            if self.opts.bg == nil and self._parent and self._parent.bg then
                bgToUse = self._parent.bg
            end

            UI.term.setTextColor(self.fg)
            UI.term.setBackgroundColor(bgToUse)
            UI.term.setCursorPos(self.x, self.y)
            UI.term.write(self.text)
        end
    }

    -- Initialize bounds (x, y, width, height, visible, focusable)
    UI.initBounds(e, opts)

    function e:applyTheme()
        local o = self.opts or {}

        self.fg = UI.resolveOptColor(o.fg, "text", colors.white)

        -- Optional background for labels
        if o.bg ~= nil then
            -- explicit override; can be role or literal
            self.bg = UI.resolveOptColor(o.bg, "surface", UI.resolveColor("background", colors.black))
        else
            -- no bg specified; use theme background as default
            self.bg = UI.resolveColor("background", colors.black)
        end
    end

    e:applyTheme()

    UI._attachSubscriptionAPI(e)
    UI._attachFocusAPI(e)
    UI._attachHookAPI(e)
    if opts.init then opts.init(e) end

    return UI.addElement(defaultScene(opts), e)
end

function UI.checkbox(opts)
    opts = opts or {}

    local text = opts.text or ""

    local e = {
        type = "checkbox",
        text = text,
        checked = opts.initial or false,
        width = #("[X] " .. text),
        height = 1,
        opts = opts,
        -- no x/y/position/xOffset/yOffset/_visible here
        onClick = function(self, x, y, button, isTouch)
            self.checked = not self.checked
            UI.markDirty()
            return true  -- Mark as handled
        end,
        onTouch = function(self, x, y)
            -- Touch handler is light. Pointer routing calls onClick for touch.
            return true
        end,
        draw = function(self)
            if not UI.isVisible(self) then return end

            local box = self.checked and "[x] " or "[ ] "

            -- Use parent's background if we don't have an explicit bg and have a parent
            local bgToUse = self.bg
            if self.opts.bg == nil and self._parent and self._parent.bg then
                bgToUse = self._parent.bg
            end

            UI.term.setTextColor(self.fg)
            UI.term.setBackgroundColor(bgToUse)

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

    -- Initialize bounds (x, y, width, height, visible, focusable)
    UI.initBounds(e, opts)

    function e:applyTheme()
        local o = self.opts or {}

        self.fg = UI.resolveOptColor(o.fg, "text", colors.white)
        self.bg = UI.resolveOptColor(o.bg, "background", colors.black)
        self.checkedColor = UI.resolveOptColor(o.checked, "success", colors.lime)
    end

    e:applyTheme()

    UI._attachSubscriptionAPI(e)
    UI._attachFocusAPI(e)
    UI._attachHookAPI(e)
    if opts.init then opts.init(e) end

    return UI.addElement(defaultScene(opts), e)
end

function UI.textfield(opts)
    opts = opts or {}

    -- Store opts for theming

    local height = opts.height or 1
    local multiline = height > 1

    -- Initialize text structure
    local initialText = opts.text or ""
    local lines = {}
    if multiline then
        -- Split initial text into lines
        for line in (initialText .. "\n"):gmatch("([^\n]*)\n") do
            table.insert(lines, line)
        end
        if #lines == 0 then lines = {""} end
    end

    local e = {
        type = "textfield",
        text = multiline and "" or initialText,  -- For single-line
        lines = lines,  -- For multi-line
        width = opts.width or 10,
        height = height,
        multiline = multiline,
        opts = opts,
        -- position/xOffset/yOffset/x/y/visible handled by UI.initBounds
        -- focusable is set explicitly here (defaults to true for textfields)
        focusable = opts.focusable ~= nil and opts.focusable or true,
        lockFocus = opts.lockFocus or false,

        -- Features
        placeholder = opts.placeholder or "",
        onChange = opts.onChange or nil,
        onEnter = opts.onEnter or nil,

        -- Single-line cursor
        cursorPos = multiline and 0 or #initialText,
        viewOffset = 0,

        -- Multi-line cursor
        cursorRow = 1,
        cursorCol = multiline and #lines[1] or 0,
        scrollOffset = 0,

        -- Scroll management for multiline
        updateScroll = function(self)
            if not self.multiline then return end
            -- Keep cursor row visible
            if self.cursorRow < self.scrollOffset + 1 then
                self.scrollOffset = math.max(0, self.cursorRow - 1)
            elseif self.cursorRow > self.scrollOffset + self.height then
                self.scrollOffset = self.cursorRow - self.height
            end
        end,

        -- View offset for single-line
        updateViewOffset = function(self)
            if self.multiline then return end
            local visibleWidth = self.width
            if self.cursorPos < self.viewOffset then
                self.viewOffset = self.cursorPos
            end
            if self.cursorPos > self.viewOffset + visibleWidth then
                self.viewOffset = self.cursorPos - visibleWidth
            end
            self.viewOffset = math.max(0, self.viewOffset)
        end,

        -- Event handlers
        onChar = function(self, ch)
            if self.multiline then
                local line = self.lines[self.cursorRow]
                local before = line:sub(1, self.cursorCol)
                local after = line:sub(self.cursorCol + 1)
                self.lines[self.cursorRow] = before .. ch .. after
                self.cursorCol = self.cursorCol + 1
            else
                local before = self.text:sub(1, self.cursorPos)
                local after = self.text:sub(self.cursorPos + 1)
                self.text = before .. ch .. after
                self.cursorPos = self.cursorPos + 1
                self:updateViewOffset()
            end
            if self.onChange then
                local fullText = self.multiline and table.concat(self.lines, "\n") or self.text
                self.onChange(fullText)
            end
            UI.markDirty()
        end,

        onKey = function(self, key)
            local name = keys.getName(key)

            if self.multiline then
                -- Multi-line mode
                if name == "enter" then
                    local line = self.lines[self.cursorRow]
                    local before = line:sub(1, self.cursorCol)
                    local after = line:sub(self.cursorCol + 1)
                    self.lines[self.cursorRow] = before
                    table.insert(self.lines, self.cursorRow + 1, after)
                    self.cursorRow = self.cursorRow + 1
                    self.cursorCol = 0
                    self:updateScroll()
                elseif name == "backspace" then
                    if self.cursorCol > 0 then
                        local line = self.lines[self.cursorRow]
                        self.lines[self.cursorRow] = line:sub(1, self.cursorCol - 1) .. line:sub(self.cursorCol + 1)
                        self.cursorCol = self.cursorCol - 1
                    elseif self.cursorRow > 1 then
                        local currentLine = self.lines[self.cursorRow]
                        table.remove(self.lines, self.cursorRow)
                        self.cursorRow = self.cursorRow - 1
                        self.cursorCol = #self.lines[self.cursorRow]
                        self.lines[self.cursorRow] = self.lines[self.cursorRow] .. currentLine
                        self:updateScroll()
                    end
                elseif name == "up" and self.cursorRow > 1 then
                    self.cursorRow = self.cursorRow - 1
                    self.cursorCol = math.min(self.cursorCol, #self.lines[self.cursorRow])
                    self:updateScroll()
                elseif name == "down" and self.cursorRow < #self.lines then
                    self.cursorRow = self.cursorRow + 1
                    self.cursorCol = math.min(self.cursorCol, #self.lines[self.cursorRow])
                    self:updateScroll()
                elseif name == "left" and self.cursorCol > 0 then
                    self.cursorCol = self.cursorCol - 1
                elseif name == "right" and self.cursorCol < #self.lines[self.cursorRow] then
                    self.cursorCol = self.cursorCol + 1
                elseif name == "home" then
                    self.cursorCol = 0
                elseif name == "end" then
                    self.cursorCol = #self.lines[self.cursorRow]
                end
            else
                -- Single-line mode
                if name == "enter" then
                    -- Call onEnter callback if defined
                    if self.onEnter then
                        self.onEnter(self)
                    end
                elseif name == "backspace" and self.cursorPos > 0 then
                    self.text = self.text:sub(1, self.cursorPos - 1) .. self.text:sub(self.cursorPos + 1)
                    self.cursorPos = self.cursorPos - 1
                    self:updateViewOffset()
                elseif name == "delete" and self.cursorPos < #self.text then
                    self.text = self.text:sub(1, self.cursorPos) .. self.text:sub(self.cursorPos + 2)
                elseif name == "left" and self.cursorPos > 0 then
                    self.cursorPos = self.cursorPos - 1
                    self:updateViewOffset()
                elseif name == "right" and self.cursorPos < #self.text then
                    self.cursorPos = self.cursorPos + 1
                    self:updateViewOffset()
                elseif name == "home" then
                    self.cursorPos = 0
                    self:updateViewOffset()
                elseif name == "end" then
                    self.cursorPos = #self.text
                    self:updateViewOffset()
                end
            end

            if self.onChange then
                local fullText = self.multiline and table.concat(self.lines, "\n") or self.text
                self.onChange(fullText)
            end
            UI.markDirty()
        end,

        onPress = function(self, mx, my)
            -- Focus is now handled automatically by _handlePointerDown if focusable=true
            if self.multiline then
                local relY = my - self.y
                local relX = mx - self.x
                self.cursorRow = math.min(#self.lines, math.max(1, relY + self.scrollOffset + 1))
                self.cursorCol = math.max(0, math.min(#self.lines[self.cursorRow], relX))
                self:updateScroll()
            else
                local relX = mx - self.x
                self.cursorPos = math.min(#self.text, math.max(0, relX + self.viewOffset))
                self:updateViewOffset()
            end
            UI.markDirty()
            return true
        end,

        draw = function(self)
            if not UI.isVisible(self) then return end

            local isFocused = (UI.focused == self)
            local bg = isFocused and self.bgActive or self.bg

            if self.multiline then
                -- Multi-line mode
                UI.term.setBackgroundColor(bg)
                UI.term.setTextColor(self.fg)

                for i = 0, self.height - 1 do
                    local lineIdx = self.scrollOffset + i + 1
                    UI.term.setCursorPos(self.x, self.y + i)
                    if lineIdx <= #self.lines then
                        local line = self.lines[lineIdx]
                        local displayLine = line:sub(1, self.width)
                        displayLine = displayLine .. string.rep(" ", self.width - #displayLine)
                        UI.term.write(displayLine)
                    else
                        UI.term.write(string.rep(" ", self.width))
                    end
                end

                -- Set CC cursor position
                if isFocused then
                    local cursorScreenY = self.y + (self.cursorRow - self.scrollOffset - 1)
                    if cursorScreenY >= self.y and cursorScreenY < self.y + self.height then
                        UI._cursorX = self.x + self.cursorCol
                        UI._cursorY = cursorScreenY
                        UI._cursorBlink = true
                    end
                end
            else
                -- Single-line mode
                UI.term.setBackgroundColor(bg)
                UI.term.setCursorPos(self.x, self.y)

                local displayText = self.text
                local textColor = self.fg

                if #self.text == 0 and self.placeholder ~= "" and not isFocused then
                    displayText = self.placeholder
                    textColor = self.placeholderColor
                end

                local visibleText = displayText:sub(self.viewOffset + 1, self.viewOffset + self.width)
                if #visibleText < self.width then
                    visibleText = visibleText .. string.rep(" ", self.width - #visibleText)
                end

                UI.term.setTextColor(textColor)
                UI.term.write(visibleText)

                -- Set CC cursor position
                if isFocused then
                    local cursorX = self.x + (self.cursorPos - self.viewOffset)
                    if cursorX >= self.x and cursorX < self.x + self.width then
                        UI._cursorX = cursorX
                        UI._cursorY = self.y
                        UI._cursorBlink = true
                    end
                end
            end
        end
    }

    -- Initialize bounds (x, y, width, height, visible, focusable)
    UI.initBounds(e, opts)

    function e:applyTheme()
        local o = self.opts or {}

        self.fg = UI.resolveOptColor(o.fg, "text", colors.white)
        self.bg = UI.resolveOptColor(o.bg, "surface", colors.gray)
        self.bgActive = UI.resolveOptColor(o.bgActive, "interactive", colors.lightGray)
        self.placeholderColor = UI.resolveOptColor(o.placeholderColor, "textDim", colors.lightGray)
    end

    e:applyTheme()

    UI._attachSubscriptionAPI(e)
    UI._attachFocusAPI(e)
    UI._attachHookAPI(e)
    if opts.init then opts.init(e) end

    return UI.addElement(defaultScene(opts), e)
end

function UI.rectangle(opts)
    opts = opts or {}

    local e = {
        type = "rectangle",
        width = opts.width or 5,
        height = opts.height or 3,
        opts = opts,
        border = opts.border or false,
        padding = opts.padding or 0,
        filled = opts.filled ~= false,
        draggable = opts.draggable or false,
        -- position/xOffset/yOffset/x/y/_visible handled by UI.initBounds
        children = {},

        -- Dragging state
        isDragging = false,
        dragOffsetX = 0,
        dragOffsetY = 0,

        addChild = function(self, element)
            table.insert(self.children, element)
            element._parent = self  -- Set parent reference for event propagation and bg inheritance
            self:layout()
            UI.markDirty()
            return element
        end,

        removeChild = function(self, element)
            for i, child in ipairs(self.children) do
                if child == element then
                    table.remove(self.children, i)
                    self:layout()
                    UI.markDirty()
                    return true
                end
            end
            return false
        end,

        layout = function(self)
            -- Recalculate all children positions
            UI._inLayout = true
            for _, child in ipairs(self.children) do
                UI.applyChildPositioning(self, child)
            end
            UI._inLayout = false
        end,

        onPress = function(self, mx, my, button)
            if self.draggable and button == 1 then
                self.isDragging = true
                self.dragOffsetX = mx - self.x
                self.dragOffsetY = my - self.y
                self._hasBeenDragged = true  -- Mark as manually positioned
                UI.draggedElement = self  -- Optional: global reference
                return true
            end
            return false
        end,

        onDrag = function(self, x, y, button, dx, dy)
            if not self.isDragging then return false end
            self.x = x - (self.dragOffsetX or 0)
            self.y = y - (self.dragOffsetY or 0)

            -- If this element is a container with a layout() method, recompute
            if self.layout then
                self:layout()
            end

            UI.markDirty()
            return true
        end,

        onRelease = function(self, mx, my, button, inBounds)
            if self.isDragging then
                self.isDragging = false
                if UI.draggedElement == self then
                    UI.draggedElement = nil
                end
            end
        end,

        draw = function(self)
            if not UI.isVisible(self) then return end

            local hasBorder = self.border and self.width >= 3 and self.height >= 3

            -- Draw filled background
            UI.term.setBackgroundColor(self.bg)
            UI.term.setTextColor(self.fg)
            for i = 0, self.height - 1 do
                UI.term.setCursorPos(self.x, self.y + i)
                UI.term.write(string.rep(" ", self.width))
            end

            -- Draw solid border if enabled
            if hasBorder then
                UI.term.setBackgroundColor(self.borderColor)
                -- Top border
                UI.term.setCursorPos(self.x, self.y)
                UI.term.write(string.rep(" ", self.width))
                -- Bottom border
                UI.term.setCursorPos(self.x, self.y + self.height - 1)
                UI.term.write(string.rep(" ", self.width))
                -- Left and right borders
                for i = 1, self.height - 2 do
                    UI.term.setCursorPos(self.x, self.y + i)
                    UI.term.write(" ")
                    UI.term.setCursorPos(self.x + self.width - 1, self.y + i)
                    UI.term.write(" ")
                end
            end

            -- Update children positions (parent x/y may have changed via applyPositioning)
            if #self.children > 0 then
                self:layout()
            end

            -- Draw children
            for _, child in ipairs(self.children) do
                if child.draw and UI.isVisible(child) then
                    child:draw()
                end
            end
        end
    }

    -- Initialize bounds (x, y, width, height, visible, focusable)
    UI.initBounds(e, opts)

    function e:applyTheme()
        local o = self.opts or {}

        self.bg = UI.resolveOptColor(o.bg, "surface", colors.gray)
        self.fg = UI.resolveOptColor(o.fg, "text", colors.white)
        self.borderColor = UI.resolveOptColor(o.borderColor, "border", colors.lightGray)
    end

    e:applyTheme()

    UI._attachSubscriptionAPI(e)
    UI._attachFocusAPI(e)
    UI._attachHookAPI(e)
    if opts.init then opts.init(e) end

    -- Call builder function if provided
    if opts.builder then
        UI._buildingLayout = true
        local prevParent = UI._layoutParent
        UI._layoutParent = e

        opts.builder(e)

        UI._layoutParent = prevParent
        UI._buildingLayout = false
        e:layout()
    end

    return UI.addElement(defaultScene(opts), e)
end

------------------------------------------------------------------
-- ANIMATED LABEL ELEMENT
------------------------------------------------------------------
function UI.animatedLabel(opts)
    opts = opts or {}

    local e = {
        type = "animatedLabel",
        frames = opts.frames or { "..." },  -- List of strings to cycle through
        currentFrame = 1,
        frameDuration = opts.frameDuration or 0.5,  -- Time between frames
        frameTimer = 0,
        animating = opts.animating ~= false,  -- Default to animating
        opts = opts,
        -- x/y/position/xOffset/yOffset/_visible handled by UI.initBounds

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
        onUpdate = function(self, dt)
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
            if not UI.isVisible(self) then return end

            local text = self.frames[self.currentFrame] or ""
            UI.term.setTextColor(self.fg)
            UI.term.setBackgroundColor(self.bg)
            UI.term.setCursorPos(self.x, self.y)
            UI.term.write(text)
        end
    }

    -- Initialize bounds (x, y, width, height, visible, focusable)
    UI.initBounds(e, opts)

    function e:applyTheme()
        local o = self.opts or {}

        self.fg = UI.resolveOptColor(o.fg, "text", colors.white)
        self.bg = UI.resolveOptColor(o.bg, "background", colors.black)
    end

    e:applyTheme()

    UI._attachSubscriptionAPI(e)
    UI._attachFocusAPI(e)
    UI._attachHookAPI(e)
    if opts.init then opts.init(e) end

    return UI.addElement(defaultScene(opts), e)
end

-------------------------------------------------
-- DIALOG / MODAL ELEMENT
-------------------------------------------------
-------------------------------------------------
-- Dialog Helper (Composition-based)
-- Creates a rectangle with overlay, title, message, and buttons
-------------------------------------------------
function UI.dialog(opts)
    opts = opts or {}

    local termW, termH = UI.term.getSize()
    local width = opts.width or 30
    local height = opts.height or 10
    local title = opts.title or ""
    local message = opts.message or opts.content or ""
    local buttons = opts.buttons or {{text = "OK"}}
    local closeOnOverlay = opts.closeOnOverlay ~= false
    local modal = opts.modal ~= false
    local padding = opts.padding or 2

    -- Declare rect first for closure
    local rect = nil
    local overlay = nil

    -- Create overlay (if modal)
    if modal then
        overlay = UI.rectangle({
            width = termW,
            height = termH,
            x = 1,
            y = 1,
            bg = opts.overlayColor or colors.black,
            scene = opts.scene,
            onPress = function(self, x, y, button)
                if closeOnOverlay then
                    -- Close both dialog and overlay
                    UI.hide(rect)
                    UI.hide(self)
                    UI.markDirty()
                end
                return true  -- Consume clicks
            end
        })
    end

    -- Create dialog rectangle
    rect = UI.rectangle({
        width = width,
        height = height,
        position = "center",
        border = true,
        bg = opts.bg or UI.resolveColor("surface", colors.gray),
        borderColor = opts.borderColor or UI.resolveColor("border", colors.lightGray),
        padding = padding,
        scene = opts.scene,
        builder = function(r)
            -- Add title if provided
            if title and #title > 0 then
                r:addChild(UI.label({
                    text = title,
                    position = "topCenter",
                    fg = opts.titleFg or colors.yellow
                }))
            end

            -- Add message/content if provided
            if message and #message > 0 then
                r:addChild(UI.label({
                    text = message,
                    position = "center",
                    yOffset = title and #title > 0 and -1 or 0
                }))
            end

            -- Call custom builder if provided
            if opts.builder then
                opts.builder(r)
            end

            -- Add buttons
            if #buttons == 1 then
                -- Single button - centered
                local btn = buttons[1]
                r:addChild(UI.button({
                    text = btn.text,
                    position = "bottomCenter",
                    onclick = function()
                        if btn.onClick or btn.onclick then
                            (btn.onClick or btn.onclick)()
                        end
                        if btn.close ~= false then
                            UI.hide(rect)
                            if overlay then UI.hide(overlay) end
                            UI.markDirty()
                        end
                    end
                }))
            elseif #buttons == 2 then
                -- Two buttons - left and right
                for i, btn in ipairs(buttons) do
                    r:addChild(UI.button({
                        text = btn.text,
                        position = i == 1 and "bottomLeft" or "bottomRight",
                        xOffset = i == 1 and 3 or -3,
                        onclick = function()
                            if btn.onClick or btn.onclick then
                                (btn.onClick or btn.onclick)()
                            end
                            if btn.close ~= false then
                                rect._visible = false
                                if overlay then overlay._visible = false end
                                UI.markDirty()
                            end
                        end
                    }))
                end
            else
                -- Multiple buttons - spaced evenly at bottom
                for i, btn in ipairs(buttons) do
                    r:addChild(UI.button({
                        text = btn.text,
                        position = "bottomLeft",
                        xOffset = 2 + (i - 1) * 10,
                        onclick = function()
                            if btn.onClick or btn.onclick then
                                (btn.onClick or btn.onclick)()
                            end
                            if btn.close ~= false then
                                rect._visible = false
                                if overlay then overlay._visible = false end
                                UI.markDirty()
                            end
                        end
                    }))
                end
            end
        end
    })

    -- Store reference to overlay for external access
    rect._overlay = overlay

    return rect
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
    local onReady = opts.onReady  -- Optional callback called after first render
    local readyCalled = false
    local parallelThread = opts.parallel
    

    local function updateEvents()
        while true do
            local event, p1, p2, p3, p4 = os.pullEvent()

            -- Use the unified event handler
            UI.handleEvent(event, p1, p2, p3, p4)
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

            -- Call onReady after first render
            if onReady and not readyCalled then
                readyCalled = true
                onReady()
            end

            sleep(.001)
        end
    end


    if parallelThread then -- If a parallel thread is provided, run it too
        parallel.waitForAny(renderUI, updateEvents, parallelThread)
    else
        parallel.waitForAny(renderUI, updateEvents)
    end
end

return UI