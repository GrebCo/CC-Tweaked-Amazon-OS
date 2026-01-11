# CC:Tweaked UI Framework — Practical User Guide

A complete guide to building interactive UIs in ComputerCraft with themes, events, and components.

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Core Concepts](#core-concepts)
3. [Event System & Event Hooks](#event-system--event-hooks)
4. [Lifecycle Hooks](#lifecycle-hooks)
5. [Containers & Layouts](#containers--layouts)
6. [UI Elements](#ui-elements)
7. [Themes](#themes)
8. [Examples & Recipes](#examples--recipes)
9. [Troubleshooting](#troubleshooting)

---

## Quick Start

### Basic Setup

```lua
local ui = dofile("OSUtil/ui.lua")

-- Create context table
local context = {
    elements = {},
    scenes = {},
    functions = { log = function()  end }
}

-- Initialize UI
ui.init(context)

-- Create and set a scene
ui.newScene("MainMenu")
ui.setScene("MainMenu")

-- Add a label
centerLabel = ui.label({
    text = "Hello World!",
    position = "center",
    fg = colors.yellow
})

-- Add a button
ui.button({
    text = "Click Me",
    position = "center",
    yOffset = 2,
    bg = colors.blue,
    colorPressed = colors.lightBlue,
    onclick = function()
        centerLabel.text = "Button Clicked!"
    end
})

-- Run with parallel render loop (prevents flicker)
ui.run()
```

---

## Core Concepts

### 1. Context Table

The context table is the central data store for the UI system:

```lua
{
    scenes = {},      -- All scene definitions
    elements = {},    -- Flattened element list for active scene
    functions = {},   -- Shared functions (log, etc.)
}
```

### 2. Scenes

**Scenes** are logical groupings of UI elements (like pages or screens):

- Each scene has its own `elements` array
- Scenes can have `children` (sub-scenes with offsets)
- Only one scene is active at a time
- The active scene's elements are flattened into `contextTable.elements`

### 3. Elements

**Elements** are UI components (buttons, labels, etc.):

- Stored in `scene.elements` when created
- Copied to `contextTable.elements` when scene is activated
- Each element has `type`, `x, y`, and `draw()` method
- Optional: `update(dt)`, `onClick()`, `onScroll()`, etc.

### 4. Dirty Flag Rendering (Optimization)

The UI uses **dirty flag optimization** to skip rendering when nothing has changed:

- `UI.render()` checks `needRender` flag at the start
- If false, rendering is skipped (saves CPU)
- `UI.markDirty()` sets the flag to true, scheduling a render
- After rendering, the flag is automatically cleared

**When is the dirty flag set?**
- Scene changes (`setScene()`, `addChild()`, `removeChild()`)
- Event handlers (clicks, keyboard input)
- Element animations (when `update()` returns true)
- Manual calls to `ui.markDirty()`

### 5. Delta Time and Animations

All animations use delta time (`dt`) for frame-rate independent timing:

- `UI.run()` calculates `dt` automatically in the render loop
- Passes it to `UI.update(dt)`
- All element `update(dt)` methods receive the same delta time
- Default is 30 FPS, configurable via `ui.run({fps = 60})`

### 6. Async Work Pattern

For background tasks or async work, create an invisible UI element with an `update(dt)` method:

```lua
local asyncWorker = {
    type = "worker",
    x = 0, y = 0,

    update = function(self, dt)
        -- Your async work here
    end,

    draw = function(self)
        -- Empty - invisible element
    end
}

ui.addElement("MyScene", asyncWorker)
```

---

## Event System & Event Hooks

### How Events Work

The UI framework handles all events automatically:

- Mouse clicks (`mouse_click`, `mouse_up`, `mouse_drag`)
- Touch events (`monitor_touch`)
- Scrolling (`mouse_scroll`)
- Keyboard input (`char`, `key`)
- Custom events (broadcast to subscribers)

**Key principle:** The framework decides when clicks happen. Elements just react.

### Event Handlers (Hooks)

All elements support these optional event handlers:

#### Pointer Handlers

```lua
onclick = function(self, x, y, button, isTouch)
    -- Semantic click: press + release on the same element
    -- button: 1=left, 2=right, 3=middle
    -- isTouch: true if from touch screen
    -- This is the primary "action" handler for most elements
end

onPress = function(self, x, y, button, isTouch)
    -- Called when mouse/touch presses on this element
    -- Return true to "claim" the press (prevents parent handling)
    -- Return false/nil to let parent handle it
end

onRelease = function(self, x, y, button, inBounds, isTouch)
    -- Called when mouse button is released
    -- inBounds: true if cursor is still over this element
end

onDrag = function(self, x, y, button, dx, dy)
    -- Called during mouse drag (only if this element was pressed)
    -- dx, dy: delta movement since last drag event
end

onDragEnd = function(self, x, y, button)
    -- Called when drag ends (mouse button released during drag)
    -- x, y: final cursor position
    -- button: mouse button that was released
end

onScroll = function(self, dir, x, y)
    -- Called on scroll wheel
    -- dir: -1 (up) or 1 (down)
    -- Return false to pass to parent
end

onTouch = function(self, x, y)
    -- Touch screen instant tap (fires before onPress)
    -- Only fires for touch screens, not mouse clicks
end
```

#### Keyboard Handlers

```lua
onChar = function(self, ch)
    -- Character input (typing)
    -- Only called if element is focused
    -- ch: the character string
end

onKey = function(self, key, isHeld, ev)
    -- Key events (arrow keys, backspace, enter, etc.)
    -- Only called if element is focused
    -- key: keys.* constant
    -- isHeld: true if key is being held down
end
```

#### Focus Lifecycle

```lua
onFocus = function(self)
    -- Called when this element gains focus
    -- Good for showing cursor, highlighting, etc.
end

onBlur = function(self)
    -- Called when this element loses focus
    -- Good for hiding cursor, validation, etc.
end
```

### Focus System

**Focus Flags:**

```lua
local textfield = ui.textfield({
    text = "Type here",
    focusable = true,   -- Allow click-to-focus
    lockFocus = true    -- Prevent losing focus on outside clicks
})
```

**Focus API:**

```lua
-- Set focus to an element
UI.setFocus(element)           -- Respects lockFocus
UI.setFocus(element, {force = true})  -- Overrides lockFocus

-- Clear focus
UI.clearFocus()                -- Respects lockFocus
UI.clearFocus({force = true})  -- Overrides lockFocus

-- Check current focus
if UI.focused == myElement then
    -- This element is focused
end

-- Element API
element:requestFocus()         -- Calls UI.setFocus(self)
```

### Event Subscriptions

Subscribe elements or the UI globally to arbitrary events:

```lua
-- Element-local subscription (only fires if element is visible)
element:subscribeEvent("redstone", function(self, eventName, side)
    self.text = "Redstone pulse on " .. side
    UI.markDirty()
end)

-- Global subscription (fires regardless of visibility)
UI.subscribeGlobalEvent("timer", function(eventName, timerId)
    print("Timer fired: " .. timerId)
end)

-- Unsubscribe
element:unsubscribeEvent("redstone", handlerFunction)
```

---

## Lifecycle Hooks

Lifecycle hooks let elements respond to their own lifecycle events, not user input.

```lua
onUpdate = function(self, dt)
    -- Called every frame with delta time (dt)
    -- Use for animations, timers, async work
    -- Return true if UI changed, false otherwise
    self.angle = (self.angle or 0) + 180 * dt
    return true  -- Mark as changed to trigger redraw
end

onDraw = function(self, offsetX, offsetY)
    -- Called after element is drawn (wraps the draw function)
    -- Use for post-processing, overlays, custom drawing
    -- offsetX, offsetY: scroll offsets for containers
end

onDestroy = function(self)
    -- Called when element is removed from a scene
    -- Use for cleanup: unsubscribe events, close files, etc.
    self:unsubscribeEvent("timer", self._timerHandler)
end
```

**Example: Animated spinner with auto-cleanup:**

```lua
local spinner = ui.animatedLabel({
    frames = {"⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"},
    frameDuration = 0.1,
    position = "center",

    onUpdate = function(self, dt)
        -- Animation is handled automatically by animatedLabel
        return true
    end,

    onDestroy = function(self)
        -- Clean up when removed
        print("Spinner destroyed")
    end
})
```

---

## Containers & Layouts

Containers organize child elements and handle layout automatically.

### VStack (Vertical Stack)

Arranges children vertically, top-to-bottom:

```lua
ui.vstack({
    spacing = 1,              -- Space between items
    align = "left",           -- "left", "center", "right"
    padding = 1,              -- Padding around children
    position = "center",

    builder = function(container)
        container:addChild(ui.label({text = "Item 1"}))
        container:addChild(ui.button({text = "Click me"}))
        container:addChild(ui.checkbox({text = "Enabled"}))
    end
})
```

**Common options:**
- `spacing` - Vertical distance between children (default: 0)
- `align` - Horizontal alignment of children
- `padding` - Space around the entire stack
- `position, xOffset, yOffset` - Stack positioning on screen
- `builder` - Function called with container to add children

---

### HStack (Horizontal Stack)

Arranges children horizontally, left-to-right:

```lua
ui.hstack({
    spacing = 2,              -- Space between items
    align = "top",            -- "top", "center", "bottom"
    padding = 1,
    position = "center",

    builder = function(container)
        container:addChild(ui.button({text = "Left"}))
        container:addChild(ui.button({text = "Middle"}))
        container:addChild(ui.button({text = "Right"}))
    end
})
```

**Common options:**
- `spacing` - Horizontal distance between children
- `align` - Vertical alignment of children
- `padding` - Space around the entire stack
- `position, xOffset, yOffset` - Stack positioning

---

### Grid

Arranges children in a grid pattern:

```lua
ui.grid({
    columns = 3,              -- Number of columns
    spacing = 1,              -- Space between items
    padding = 1,
    position = "center",

    builder = function(container)
        for row = 1, 3 do
            for col = 1, 3 do
                container:addChild(ui.button({
                    text = tostring(row * col)
                }))
            end
        end
    end
})
```

**Common options:**
- `columns` - Number of columns (required)
- `spacing` - Space between items (all directions)
- `rowSpacing` - Override spacing for rows
- `columnSpacing` - Override spacing for columns
- `padding` - Space around the entire grid

---

### Rectangle Container

A colored rectangular box that can contain other elements and be dragged:

```lua
local panel = ui.rectangle({
    width = 30,
    height = 10,
    bg = colors.gray,
    border = true,
    borderColor = colors.black,
    padding = 1,

    draggable = true,         -- Allow mouse dragging!

    position = "center",

    init = function(self)
        -- Add children after creation
        self:addChild(ui.label({text = "Draggable Panel"}))
        self:addChild(ui.button({
            text = "Click me",
            onclick = function() print("Clicked!") end
        }))
    end
})
```

**Container options:**
- `width, height` - Size of container
- `bg` - Background color
- `filled` - Draw background (default: true)
- `border` - Draw border (default: false)
- `borderColor` - Border color (if border=true)
- `padding` - Space inside before children
- `draggable` - Allow mouse dragging (default: false)

**Dragging behavior:**
- Click and drag the rectangle to move it
- Position is updated automatically
- Children move with their parent
- Works anywhere on screen

---

### Adding Children to Containers

**Method 1: Builder function (recommended)**

```lua
local stack = ui.vstack({
    builder = function(container)
        container:addChild(ui.label({text = "Item 1"}))
        container:addChild(ui.button({text = "Item 2"}))
    end
})
```

**Method 2: Manual addChild**

```lua
local stack = ui.vstack({})
stack:addChild(ui.label({text = "Item 1"}))
stack:addChild(ui.button({text = "Item 2"}))
stack:layout()  -- Recalculate positions after adding
```

**Method 3: Parent reference**

```lua
local container = ui.rectangle({width = 20, height = 10})
ui.label({
    text = "I'm inside!",
    parent = container  -- Auto-added to container
})
```

---

## UI Elements

### Button

Clickable button with visual press feedback.

**Basic usage:**

```lua
ui.button({
    text = "Click Me",
    position = "center",
    bg = colors.blue,
    colorPressed = colors.lightBlue,
    onclick = function()
        print("Clicked!")
    end
})
```

**Common options:**
- `text` - Button label
- `position` - Anchor: "center", "top", "left", "topLeft", etc.
- `xOffset, yOffset` - Offsets from anchor
- `fg, bg` - Text and background colors
- `colorPressed` - Color when pressed
- `toggle` - True for toggle button (stays pressed)
- `onclick` - Click handler function

**Gotchas:**
- Non-toggle buttons show pressed color for 0.1s only
- Toggle buttons stay pressed until clicked again

---

### Label

Static text display.

**Basic usage:**

```lua
ui.label({
    text = "Hello World",
    position = "center",
    fg = colors.white,
    bg = colors.black
})
```

**Common options:**
- `text` - Display text
- `position` - Anchor position
- `fg, bg` - Colors

---

### Checkbox

Boolean toggle with `[x]` or `[ ]` display.

**Basic usage:**

```lua
ui.checkbox({
    text = "Enable feature",
    initial = false,
    onclick = function(self, checked)
        print("Checked: " .. tostring(checked))
    end
})
```

**Common options:**
- `text` - Label text
- `initial` - Initial checked state (default: false)
- `onclick` - Called with checked state
- `fg, bg` - Colors

---

### Text Field

Unified text input for single-line and multi-line editing.

**Single-line mode** (height = 1):

```lua
local field = ui.textfield({
    text = "",
    width = 20,
    placeholder = "Type here...",
    fg = colors.white,
    bg = colors.gray,
    onChange = function(text)
        print("Text: " .. text)
    end
})
```

**Multi-line mode** (height > 1):

```lua
local editor = ui.textfield({
    text = "Line 1\nLine 2",
    width = 40,
    height = 10,
    onChange = function(text)
        print("Content: " .. #text .. " chars")
    end
})
```

**Common options:**
- `text` - Initial text
- `width, height` - Size (height > 1 = multi-line)
- `placeholder` - Placeholder text (single-line only)
- `onChange` - Called when text changes

**Features:**
- **Single-line:** Horizontal scrolling with `<` and `>` indicators
- **Multi-line:** Vertical scrolling, arrow keys for navigation
- **Click to position** cursor
- **Full keyboard support** (Backspace, Home, End, arrows)
- **Blinking cursor** when focused

---

### Rectangle

Simple colored rectangle.

**Basic usage:**

```lua
ui.rectangle({
    width = 20,
    height = 5,
    position = "center",
    bg = colors.blue
})
```

**Common options:**
- `width, height` - Dimensions
- `bg` - Background color
- `position, xOffset, yOffset` - Positioning

---

### Terminal

Terminal emulator that accepts ANSI-like drawing commands.

**Basic usage:**

```lua
local term = ui.terminal({
    width = 40,
    height = 10,
    position = "center"
})

-- Write to terminal
term:write("Hello World")
term:setTextColor(colors.red)
term:write("\nRed text here")
```

---

## Themes

### Built-in Themes

The framework includes 15 professionally-designed themes:

| Theme | Style |
|-------|-------|
| `catppuccin` | Pastel, soothing colors |
| `gruvbox` | Retro, warm earth tones |
| `nord` | Cool, arctic-inspired palette |
| `dracula` | Dark, high-contrast purple accent |
| `tokyonight` | Dark blue with neon accents |
| `onedark` | Atom's iconic dark theme |
| `solarized` | Scientific precision palette |
| `monokai` | Sublime Text's classic theme |
| `material` | Google Material Design |
| `rosepine` | Muted, elegant rose tones |
| `everforest` | Natural, forest-inspired |
| `ayu` | Modern, refined minimalism |
| `paper` | Clean, minimal light theme |
| `solarized_light` | Scientific precision, light variant |
| `gruvbox_light` | Warm earth tones, light variant |
| `default` | Standard CC colors |

### Loading Themes

```lua
local ui = dofile("UI.lua")
ui.init(context)

-- Load all built-in themes
local registerThemes = dofile("themes.lua")
registerThemes(ui)

-- Switch to a theme
ui.setTheme("catppuccin")
ui.setTheme("nord")
ui.setTheme("dracula")
ui.setTheme("paper")  -- Light theme
```

### Creating Custom Themes

**Simple theme** (using CC colors):

```lua
ui.registerTheme("myTheme", {
    roles = {
        background = colors.black,
        text = colors.white,
        textDim = colors.lightGray,
        surface = colors.gray,
        border = colors.gray,
        interactive = colors.blue,
        interactiveHover = colors.lightBlue,
        interactiveActive = colors.cyan,
        interactiveDisabled = colors.gray,
        interactiveText = colors.white,
        success = colors.lime,
        error = colors.red,
        warning = colors.yellow,
        info = colors.lightBlue,
        selection = colors.blue
    }
})

ui.setTheme("myTheme")
```

**Theme with custom RGB palette:**

```lua
ui.registerTheme("ocean", {
    roles = {
        background = colors.black,
        text = colors.white,
        -- ... other roles ...
    },
    palette = {
        [colors.black] = 0x0A1929,
        [colors.white] = 0xE0F4FF,
        [colors.blue] = 0x1976D2,
        [colors.cyan] = 0x00ACC1,
        -- ... other color mappings ...
    }
})
```

### Using Theme Roles in Elements

Every element can use theme roles for colors. Instead of hardcoding `colors.red`, use role names like `"error"`:

```lua
-- Use literal colors (theme-independent)
ui.button({
    text = "Delete",
    bg = colors.red,      -- Always red, ignores theme
    fg = colors.white
})

-- Use theme roles (changes with theme)
ui.button({
    text = "Delete",
    bg = "error",         -- Uses theme's error role
    fg = "interactiveText"  -- Uses theme's interactive text role
})

-- Mix literal and theme roles
ui.button({
    text = "Success",
    bg = "success",       -- Uses theme role
    fg = colors.white     -- Literal color
})
```

**Common Theme Roles:**
- `background`, `text`, `textDim` - General UI colors
- `interactive`, `interactiveHover`, `interactiveActive` - Button states
- `success`, `error`, `warning`, `info` - Status colors
- `selection`, `surface`, `border` - Container colors

**How it works:**
1. When you use `fg = "error"`, the framework looks up `error` in the current theme
2. When you switch themes, all elements using role names automatically update colors
3. Literal numbers like `colors.red` are never changed by theme switching

---

## Examples & Recipes

### Recipe: Simple Login Form

```lua
local ui = dofile("OSUtil/ui.lua")
local context = { scenes = {}, elements = {}, functions = {} }
ui.init(context)
ui.newScene("Login")
ui.setScene("Login")

ui.label({
    text = "Login",
    position = "topCenter",
    yOffset = 2,
    fg = colors.yellow
})

local usernameField = ui.textfield({
    width = 25,
    placeholder = "Username",
    position = "center",
    yOffset = 5
})

local passwordField = ui.textfield({
    width = 25,
    placeholder = "Password",
    position = "center",
    yOffset = 7
})

local statusLabel = ui.label({
    text = "",
    position = "center",
    yOffset = 9,
    fg = colors.red
})

ui.button({
    text = "Login",
    bg = colors.green,
    position = "center",
    yOffset = 11,
    onclick = function()
        if #usernameField.text > 0 and #passwordField.text > 0 then
            statusLabel.text = "Logging in..."
            statusLabel.fg = colors.yellow
            UI.markDirty()
            -- Verify credentials here
        else
            statusLabel.text = "Please fill all fields"
            statusLabel.fg = colors.red
            UI.markDirty()
        end
    end
})

ui.run()
```

### Recipe: Dynamic Theming UI

```lua
local ui = dofile("OSUtil/ui.lua")
local registerThemes = dofile("themes.lua")

local context = { scenes = {}, elements = {}, functions = {} }
ui.init(context)
registerThemes(ui)

ui.newScene("Settings")
ui.setScene("Settings")

local currentTheme = "default"

ui.label({
    text = "Theme: " .. currentTheme,
    position = "topCenter",
    yOffset = 2,
    fg = colors.yellow
})

local themes = {"catppuccin", "nord", "dracula", "paper", "gruvbox"}

for i, themeName in ipairs(themes) do
    ui.button({
        text = themeName,
        position = "left",
        xOffset = 2,
        yOffset = 4 + (i - 1) * 2,
        onclick = function()
            currentTheme = themeName
            ui.setTheme(themeName)
        end
    })
end

ui.run()
```

### Recipe: Simple Data Display

```lua
-- Create a status panel
local statusPanel = ui.rectangle({
    width = 30,
    height = 8,
    position = "topRight",
    xOffset = -2,
    yOffset = 2,
    bg = colors.gray
})

local statusText = ui.label({
    text = "Status: OK",
    position = "topRight",
    xOffset = -4,
    yOffset = 3,
    fg = colors.lime
})

local updateButton = ui.button({
    text = "Refresh",
    position = "topRight",
    xOffset = -4,
    yOffset = 9,
    onclick = function()
        statusText.text = "Status: Updating..."
        statusText.fg = colors.yellow
        UI.markDirty()

        -- Simulate fetching data
        local status = checkSystem()
        statusText.text = "Status: " .. status
        statusText.fg = status == "OK" and colors.lime or colors.red
        UI.markDirty()
    end
})
```

---

## Troubleshooting

### "Elements not displaying"

- **Check:** Is the scene set? `ui.setScene("SceneName")`
- **Check:** Is the element added to the scene? Elements are added automatically when created after `setScene()`
- **Check:** Is the position within screen bounds?
- **Fix:** Call `ui.markDirty()` to force a render

### "Button not responding to clicks"

- **Check:** Is the element's position correct?
- **Check:** Is the button covered by another element?
- **Check:** Did you call `ui.run()` to start the event loop?
- **Fix:** Verify with a simpler element (label) at the same position

### "Text field not accepting input"

- **Check:** Is the text field focused? (Click it first)
- **Check:** Is it `focusable = true`?
- **Check:** Is keyboard input reaching the UI? Test with `onChar` handler
- **Fix:** Call `UI.setFocus(textfield)` to focus it programmatically

### "Animations look choppy"

- **Check:** Are you modifying too many elements per frame?
- **Check:** Is your `update(dt)` handler doing heavy computation?
- **Fix:** Use `os.time()` or timers instead of per-frame updates for long operations
- **Fix:** Increase FPS: `ui.run({fps = 60})`

### "Theme colors not applying"

- **Check:** Did you load themes? `registerThemes(ui)` after `themes.lua` dofile
- **Check:** Is the theme registered? `ui.registerTheme()` before `ui.setTheme()`
- **Check:** Are elements created before or after `ui.setTheme()`?
- **Fix:** Set theme before creating elements

### "Performance issues with many elements"

- **Check:** How many elements are in the active scene?
- **Fix:** Use dirty flag optimization - only mark dirty when needed
- **Fix:** Hide invisible elements: `element.visible = false`
- **Fix:** Split into multiple scenes and switch between them
- **Fix:** Reduce animation update frequency

---

## Quick API Reference

### Scene Management

```lua
ui.newScene(name)          -- Create new scene
ui.setScene(name)          -- Activate scene
ui.getScene(name)          -- Get scene table
ui.addChild(sceneName, child, xOffset, yOffset)  -- Add child scene
```

### Element Creation

**Basic Elements:**
```lua
ui.button(options)
ui.label(options)
ui.checkbox(options)
ui.textfield(options)
ui.rectangle(options)
ui.terminal(options)
```

**Containers & Layouts:**
```lua
ui.vstack(options)         -- Vertical stack
ui.hstack(options)         -- Horizontal stack
ui.grid(options)           -- Grid layout
```

**Container Methods:**
```lua
container:addChild(element)
container:removeChild(element)
container:layout()         -- Recalculate positions
```

### Focus Control

```lua
UI.setFocus(element)
UI.clearFocus()
UI.focused                 -- Get currently focused element
element:requestFocus()
```

### Rendering

```lua
UI.markDirty()             -- Force re-render
UI.render()                -- Render current scene
UI.update(dt)              -- Update all elements
```

### Theme System

```lua
ui.registerTheme(name, definition)
ui.setTheme(name)
ui.getTheme(name)
```

### Event System

```lua
element:subscribeEvent(eventName, callback)
element:unsubscribeEvent(eventName, callback)
UI.subscribeGlobalEvent(eventName, callback)
```

### Main Loop

```lua
ui.run()                   -- Start render + event loop
ui.run({fps = 60})         -- Specify FPS
```
