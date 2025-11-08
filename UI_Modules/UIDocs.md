# UI.lua — CC:Tweaked Terminal UI Framework

**Version:** 2.0 (Dirty Flag Rendering)
**Last Updated:** 2025-10-28
**Description:** A lightweight, extensible terminal-based user interface library built for CC:Tweaked. Features scene management, animations, event handling, and parallel event loop with dirty-flag optimization for flicker-free rendering.

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Architecture Overview](#architecture-overview)
3. [Core Concepts](#core-concepts)
4. [Theme System](#theme-system)
5. [API Reference](#api-reference)
6. [Element Types](#element-types)
7. [Layout System](#layout-system)
8. [Advanced Usage](#advanced-usage)
9. [Best Practices](#best-practices)
10. [Examples](#examples)

---

## Quick Start

### Basic Setup

```lua
local ui = dofile("OSUtil/ui.lua")

-- Create context table
local context = {
    elements = {},
    scenes = {},
    functions = { log = print }
}

-- Initialize UI
ui.init(context)

-- Create and set a scene
ui.newScene("MainMenu")
ui.setScene("MainMenu")

-- Add a label
ui.label({
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
        print("Button clicked!")
    end
})

-- Run with parallel render loop (prevents flicker)
ui.run({fps = 30})
```

---

## Architecture Overview

### The Rendering Pipeline

```
1. ui.tick() called
   ↓
2. UI.update(dt) - Update all animations (including async work)
   ↓
3. UI.render() - Draw to screen immediately
   ↓
4. Wait for event (os.pullEvent with 0.001s timeout)
   ↓
5. Handle event (key, mouse, etc.)
   ↓
6. UI.render() - Draw changes from event (only if real event)
   ↓
7. Return to main loop
```

**Key insight:** Rendering happens AFTER updates so async work displays immediately, and AFTER events so user interactions display immediately.

### Data Flow

```
Scene Definition (ui.newScene)
   ↓
Elements Added (ui.button, ui.label, etc.)
   ↓
Scene Activated (ui.setScene)
   ↓
Scene Tree Flattened → UI.contextTable.elements
   ↓
Rendering Loop uses flattened list
Click/Event Detection uses flattened list
Animation Updates use flattened list
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
    scripts = {}      -- User-defined scripts
}
```

### 2. Scenes

**Scenes** are logical groupings of UI elements (like pages or screens):

- Each scene has its own `elements` array
- Scenes can have `children` (sub-scenes with offsets)
- Only one scene is active at a time
- The active scene's elements are "flattened" into `contextTable.elements`

### 3. Elements

**Elements** are UI components (buttons, labels, etc.):

- Stored in `scene.elements` when created
- Copied to `contextTable.elements` when scene is activated
- Each element has:
  - `type` - Element type string
  - `x, y` - Position coordinates
  - `draw()` - Method to render itself
  - Optional: `update(dt)`, `onClick()`, `onScroll()`, etc.

### 4. The Flattening Process

When `ui.setScene("MyScene")` is called:

1. Clears `contextTable.elements`
2. Copies all elements from "MyScene" into it
3. Recursively includes child scene elements with offsets
4. This flat list is used for rendering, clicks, and updates

**Why flatten?** Performance. One linear array is much faster to iterate than traversing a tree structure every frame.

### 5. Dirty Flag Rendering

The UI uses **dirty flag optimization** to skip rendering when nothing has changed:

- `UI.render()` checks `needRender` flag at the start
- If `needRender` is false, rendering is skipped (saves CPU)
- `UI.markDirty()` sets the flag to true, scheduling a render
- After rendering, the flag is automatically cleared

**When is the dirty flag set?**
- Scene changes (`setScene()`, `addChild()`, `removeChild()`)
- Event handlers (clicks, keyboard input)
- Element animations (when `update()` returns true or non-false)
- Manual calls to `ui.markDirty()`

**Example:**
```lua
-- Static scene: No renders after initial draw
ui.setScene("Menu")  -- Renders once, then stops

-- Change triggers render:
button.text = "New Text"
ui.markDirty()  -- Schedules re-render

-- Animation triggers automatic render:
element.update = function(self, dt)
    self.x = self.x + 1
    return true  -- Sets dirty flag automatically
end
```

**Performance:** Static scenes use ~0ms CPU. Animated scenes only render when animations change.

### 6. Focus System

Only one element can be focused at a time:

- Stored in `UI.focused`
- Focused element receives keyboard events
- Set via `UI.focused = element`
- Text fields and terminal prompts use this

### 7. Delta Time and Animations

All animations use delta time (`dt`) for frame-rate independent timing:

- `UI.run()` calculates `dt` automatically in the render loop
- Passes it to `UI.update(dt)`
- All element `update(dt)` methods receive the same delta time
- This ensures consistent animation speeds regardless of frame rate
- Default is 30 FPS, configurable via `ui.run({fps = 60})`

### 8. Async Work Pattern

**Important:** For background tasks or async work, create an invisible UI element with an `update(dt)` method:

```lua
local asyncWorker = {
    type = "worker",
    x = 0, y = 0,
    
    update = function(self, dt)
        -- Your async work here
        -- Uses the same delta time as all other animations
    end,
    
    draw = function(self)
        -- Empty - invisible element
    end
}

ui.addElement("MyScene", asyncWorker)
```

**Why?** This ensures your async work uses the same timing system as UI animations, preventing timing desynchronization issues.

---

## Theme System

The UI framework includes a comprehensive theme system for consistent styling across all elements.

### Overview

Themes provide:
- **Semantic colors** (primary, success, danger, warning, info)
- **Element-specific defaults** (button, label, textfield, etc.)
- **Custom theme paths** (dashboard.cpu.bar, controls.volume, etc.)
- **Color utilities** (lighten, darken)
- **Easy theme switching** (change entire app appearance instantly)

### Theme Structure

A theme is a table with nested properties:

```lua
{
    -- Semantic colors (top-level)
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

    -- Element-specific themes
    button = {
        bg = colors.blue,
        fg = colors.white,
        colorPressed = colors.lightBlue
    },

    label = {
        fg = colors.white,
        bg = colors.black
    },

    -- Custom nested paths
    dashboard = {
        cpu = {
            bar = { fillColor = colors.red }
        }
    }
}
```

### Using Themes

#### Basic Setup

```lua
-- Themes are initialized automatically on ui.init()
ui.init(context)

-- Default theme is registered automatically
-- Activate it:
ui.setTheme("default")
```

#### Registering Custom Themes

```lua
ui.registerTheme("myTheme", {
    primary = colors.orange,
    success = colors.lime,
    danger = colors.red,

    background = colors.black,
    text = colors.white,

    button = {
        bg = colors.orange,
        fg = colors.white,
        colorPressed = colors.yellow
    },

    label = {
        fg = colors.orange,
        bg = colors.black
    }
})

-- Activate your theme
ui.setTheme("myTheme")
```

#### Using Themes in Elements

Elements can use themes in three ways:

**1. Semantic colors (most common)**
```lua
ui.button({
    text = "Success",
    theme = "success",  -- Uses theme.success color
    position = "center"
})
```

**2. Element defaults**
```lua
ui.button({
    text = "Default Button",
    -- No theme specified = uses theme.button defaults
    position = "center"
})
```

**3. Custom theme paths**
```lua
ui.button({
    text = "Custom",
    theme = "dashboard.cpu.button",  -- Custom nested path
    position = "center"
})
```

**4. Manual override (highest priority)**
```lua
ui.button({
    text = "Manual",
    bg = colors.red,  -- Manual color overrides theme
    position = "center"
})
```

### Theme Resolution Priority

When an element resolves its colors, it follows this cascade:

1. **Manual colors** (highest) - `bg = colors.red`
2. **Theme parameter** - `theme = "success"`
3. **Element defaults** - `theme.button.bg`
4. **Hardcoded fallbacks** (lowest)

### Default Theme

The framework includes a built-in default theme with:

**Semantic Colors:**
- `primary` - colors.blue
- `secondary` - colors.cyan
- `success` - colors.green
- `warning` - colors.yellow
- `danger` - colors.red
- `info` - colors.lightBlue

**Element Defaults:**
- `button` - Blue background, white text, lightBlue pressed
- `label` - White text, black background
- `textfield` - Gray background, lightGray when active
- `checkbox` - White text, lime when checked
- `terminal` - Black background, white text, lime prompt
- `rectangle` - Black background

See themes.lua for additional pre-built themes (light, nordic, solarizedDark, gruvboxDark, highContrast).

---

## API Reference

### Theme System API

#### `UI.registerTheme(name, theme)`

Registers a new theme.

**Parameters:**
- `name` (string) - Unique theme name
- `theme` (table) - Theme definition table

**Example:**
```lua
ui.registerTheme("dark", {
    primary = colors.cyan,
    background = colors.black,
    button = { bg = colors.cyan, fg = colors.black }
})
```

#### `UI.setTheme(themeName)`

Activates a registered theme and triggers a re-render.

**Parameters:**
- `themeName` (string) - Name of theme to activate

**Example:**
```lua
ui.setTheme("dark")
```

**Throws:** Error if theme doesn't exist

#### `UI.getCurrentTheme()`

Returns the currently active theme object.

**Returns:** Theme table or nil

**Example:**
```lua
local theme = ui.getCurrentTheme()
print("Primary color: " .. tostring(theme.primary))
```

#### `UI.resolveThemePath(path)`

Resolves a dot-notation path to a theme value.

**Parameters:**
- `path` (string) - Dot-separated path (e.g., "dashboard.cpu.bar")

**Returns:** Value at path or nil

**Example:**
```lua
local barColor = ui.resolveThemePath("dashboard.cpu.bar.fillColor")
```

#### `UI.resolveTheme(opts, elementType, propertyMap)`

Universal theme resolution helper used internally by elements.

**Parameters:**
- `opts` (table) - Element options (may contain `theme` parameter)
- `elementType` (string) - Element type for default lookup (e.g., "button")
- `propertyMap` (table) - Map of properties to fallback values

**Returns:** Table of resolved properties

**Example (internal use):**
```lua
local colors = UI.resolveTheme(opts, "button", {
    bg = colors.gray,
    fg = colors.white,
    colorPressed = colors.lightGray
})
```

#### `UI.theme.lighten(color)`

Returns a lighter variant of a color.

**Parameters:**
- `color` (number) - CC:Tweaked color value

**Returns:** Lighter color value

**Example:**
```lua
local lightBlue = UI.theme.lighten(colors.blue)  -- returns colors.lightBlue
local lightRed = UI.theme.lighten(colors.red)    -- returns colors.orange
```

#### `UI.theme.darken(color)`

Returns a darker variant of a color.

**Parameters:**
- `color` (number) - CC:Tweaked color value

**Returns:** Darker color value

**Example:**
```lua
local darkGray = UI.theme.darken(colors.lightGray)  -- returns colors.gray
local darkBlue = UI.theme.darken(colors.lightBlue)  -- returns colors.blue
```

---

## API Reference (Elements)

### Initialization

#### `UI.init(context)`

Initializes the UI system with a context table.

**Parameters:**
- `context` (table) - Context table with scenes, elements, functions

**Example:**
```lua
local context = { 
    scenes = {}, 
    elements = {}, 
    functions = { log = print } 
}
ui.init(context)
```

---

### Scene Management

#### `UI.newScene(name)`

Creates a new empty scene.

**Parameters:**
- `name` (string) - Unique scene name

**Example:**
```lua
ui.newScene("MainMenu")
ui.newScene("Settings")
```

#### `UI.setScene(name)`

Activates a scene and flattens its element tree.

**Parameters:**
- `name` (string) - Scene to activate

**What it does:**
1. Sets `UI.activeScene = name`
2. Flattens scene tree into `contextTable.elements`

**Example:**
```lua
ui.setScene("MainMenu")
```

#### `UI.setChild(childName, xOffset, yOffset, position)`

Adds a child scene to the active scene (for layering/popups).

**Parameters:**
- `childName` (string) - Name of child scene
- `xOffset` (number) - Horizontal offset
- `yOffset` (number) - Vertical offset
- `position` (string) - Position anchor (optional)

**Example:**
```lua
-- Show a popup centered on screen
ui.setChild("ConfirmDialog", 0, 0, "center")
```

#### `UI.removeChild(target)`

Removes a child scene from the active scene.

**Parameters:**
- `target` (string or table) - Child scene name or reference

**Example:**
```lua
ui.removeChild("ConfirmDialog")
```

---

### Element Management

#### `UI.addElement(sceneName, element)`

Adds an element to a scene. **Auto-refreshes** if adding to active scene.

**Parameters:**
- `sceneName` (string) - Scene name (or `nil` for active scene)
- `element` (table) - Element to add

**Returns:** The element

**Example:**
```lua
local btn = ui.addElement("MainMenu", myButton)
-- Or let it use active scene:
local btn = ui.addElement(nil, myButton)
```

#### `UI.applyPositioning(element)`

Calculates final x,y coordinates based on position settings.

**Parameters:**
- `element` (table) - Element to position

**Supports:**
- `position` - Anchor point (center, topLeft, etc.)
- `xOffset`, `yOffset` - Offset from anchor
- `xPercent`, `yPercent` - Percentage-based positioning

**Called automatically** before rendering each frame.

---

### Rendering

#### `UI.render()`

Renders all elements in the active scene. **Always renders** (v14 change).

**Behavior:**
- Clears screen
- Applies positioning to each element
- Calls each element's `draw()` method
- Recursively renders child scenes

**You typically don't call this directly** - `ui.run()` handles it automatically.

#### `UI.markDirty()`

**Sets the dirty flag to trigger a re-render.** Called automatically by event handlers, scene changes, and element updates. You can call it manually if you modify element properties directly.

In previous versions, this marked the UI as needing a redraw. Now rendering happens every frame automatically.

---

### Animation & Updates

#### `UI.update(dt)`

Updates all element animations.

**Parameters:**
- `dt` (number) - Delta time since last frame

**What it does:**
- Loops through `contextTable.elements`
- Calls each element's `update(dt)` if it exists
- This is where all animations AND async work happen

**Called automatically** by `ui.run()` in the render loop.

---

### Event Handling

#### `UI.handleClick(x, y)`

Routes a mouse click to elements.

**Parameters:**
- `x`, `y` (number) - Click coordinates

**Behavior:**
- Iterates elements in **reverse order** (topmost first)
- Checks if click is inside element bounds
- Calls element's `onClick(x, y)`
- Stops if element returns non-false value (no pass-through)

#### `UI.handleScroll(dir, x, y)`

Routes scroll events to elements.

**Parameters:**
- `dir` (number) - Scroll direction (-1 up, 1 down)
- `x`, `y` (number) - Mouse position

---

### Main Loop

#### `UI.run(opts)`

**The parallel render loop.** Runs UI updates and event handling in separate threads for flicker-free rendering.

**Parameters:**
- `opts.fps` - Frame rate (default: 30)
- `opts.onTick` - Optional callback function called each frame (before render)

**Execution (parallel threads):**

**Thread 1 (Render Loop at fixed FPS):**
1. Call optional `onTick()` callback
2. Calculate delta time
3. **Update all element animations** (`UI.update(dt)`)
4. **Render if dirty** (`UI.render()`)
5. Sleep until next frame
6. Repeat

**Thread 2 (Event Handler):**
1. Wait for events (`os.pullEvent()`)
2. Route to appropriate handler
3. Set dirty flag if something changed
4. Repeat

**Usage:**
```lua
ui.run({
    fps = 30,
    onTick = function()
        -- Optional per-frame logic
        -- e.g., check for state changes, push logs, etc.
    end
})
```

**Why parallel?**
- **Eliminates flicker**: Fixed render rate regardless of events
- **Smooth scrolling**: Events don't interrupt rendering
- **Better performance**: Events processed asynchronously

---

## Element Types

### Button

Clickable button with visual press feedback.

**Options:**
```lua
ui.button({
    text = "Click Me",          -- Button label
    position = "center",        -- Anchor position
    xOffset = 0,               -- Horizontal offset
    yOffset = 0,               -- Vertical offset
    width = nil,               -- Auto-sizes to text if nil
    height = 1,
    fg = colors.white,         -- Text color
    bg = colors.gray,          -- Background color
    colorPressed = colors.lightGray,  -- Color when pressed
    toggle = false,            -- True for toggle button
    onclick = function(self)   -- Click handler
        print("Clicked!")
    end
})
```

**Behavior:**
- Non-toggle: Shows pressed color for 0.1s using animation system
- Toggle: Stays pressed until clicked again
- Fully non-blocking (uses `update(dt)` for timing)

---

### Label

Static text display.

**Options:**
```lua
ui.label({
    text = "Hello World",
    position = "center",
    xOffset = 0,
    yOffset = 0,
    fg = colors.white,
    bg = colors.black
})
```

---

### Checkbox

Boolean toggle with `[x]` or `[ ]` display.

**Options:**
```lua
ui.checkbox({
    text = "Enable feature",
    position = "center",
    initial = false,           -- Initial checked state
    fg = colors.white,
    bg = colors.black,
    onclick = function(self, checked)
        print("Checked: " .. tostring(checked))
    end
})
```

---

### Text Field

Single-line text input with horizontal scrolling and placeholder support.

**Options:**
```lua
local field = ui.textfield({
    text = "",                      -- Initial text (default: "")
    width = 20,                     -- Width in characters (default: 20)
    placeholder = "Type here...",   -- Placeholder text when empty (default: "")
    position = "center",
    fg = colors.white,              -- Text color
    bg = colors.gray,               -- Background color
    bgActive = colors.lightGray,    -- Background when focused (default: colors.lightGray)
    cursorColor = colors.white,     -- Blinking cursor color (default: colors.white)
    placeholderColor = colors.lightGray,  -- Placeholder text color (default: colors.lightGray)

    onChange = function(text)       -- Called when text changes
        print("Text: " .. text)
    end
})

-- Programmatically set text
field.text = "New text"
field.cursorPos = #field.text
```

**Features:**
- **Horizontal Scrolling**: Long text scrolls automatically as you type
  - Shows `<` indicator when text extends to the left
  - Shows `>` indicator when text extends to the right
  - Keeps cursor visible as you navigate
- **Placeholder Text**: Shows gray text when field is empty
- **Custom Blinking Cursor**: Visual `_` character that blinks every 0.5 seconds
- **Full Keyboard Support**:
  - Type to add characters at cursor position
  - Backspace to delete character before cursor
  - Left/Right arrows to move cursor
  - Home key to jump to start
  - End key to jump to end
- **Mouse Support**: Click to focus and position cursor
- **onChange Callback**: Notified when text changes

**Visual Format:**
```
Empty field:        [Type here...        ]  (placeholder)
With short text:    [Hello_              ]  (cursor visible)
Long text (left):   [<long text here_    ]  (scrolled right, more to left)
Long text (right):  [This is a very lo>  ]  (scrolled left, more to right)
Long text (both):   [<is a very long t>  ]  (scrolled middle, more on both sides)
```

**Behavior:**
- Click to focus (bgActive background, cursor starts blinking)
- Type adds characters at cursor position
- Backspace deletes character before cursor
- Arrow keys move cursor (view scrolls to keep cursor visible)
- Click elsewhere to unfocus (returns to normal bg, cursor hides)
- Placeholder only visible when empty and unfocused

**Scroll Indicators:**
- `<` - Appears on left edge when text extends beyond left boundary
- `>` - Appears on right edge when text extends beyond right boundary
- Both indicators can appear simultaneously for very long text

**Example: Form with Multiple Fields**

```lua
ui.label({
    text = "Name:",
    position = "left",
    xOffset = 2,
    yOffset = 4
})

local nameField = ui.textfield({
    width = 25,
    placeholder = "Enter your name...",
    position = "left",
    xOffset = 10,
    yOffset = 4,
    onChange = function(text)
        print("Name: " .. text)
    end
})

ui.label({
    text = "Email:",
    position = "left",
    xOffset = 2,
    yOffset = 6
})

local emailField = ui.textfield({
    width = 30,
    placeholder = "user@example.com",
    position = "left",
    xOffset = 10,
    yOffset = 6,
    onChange = function(text)
        print("Email: " .. text)
    end
})

ui.button({
    text = "Submit",
    bg = colors.green,
    position = "left",
    xOffset = 10,
    yOffset = 8,
    onclick = function()
        if #nameField.text > 0 and #emailField.text > 0 then
            print("Submitted: " .. nameField.text .. ", " .. emailField.text)
        else
            print("Please fill all fields!")
        end
    end
})
```

**Notes:**
- For password fields or autocomplete, use `inputs.advancedTextField()` from Inputs.lua
- For multi-line text editing, use `ui.textarea()`
- Text scrolling is automatic - no user action required
- Cursor always stays visible by adjusting viewOffset as needed
- Custom cursor replaces CraftOS cursor for this element type

---

### Text Area

Multi-line text editor with vertical scrolling, line numbers, and full navigation support. Uses CraftOS cursor for authentic editing experience.

**Options:**
```lua
local editor = ui.textarea({
    text = "Line 1\nLine 2\nLine 3",  -- Initial text (default: "")
    width = 40,                       -- Width in characters (default: 30)
    height = 10,                      -- Height in rows (default: 10)
    lineNumbers = true,               -- Show line numbers (default: false)
    position = "center",
    fg = colors.white,                -- Text color
    bg = colors.black,                -- Background color
    lineNumberFg = colors.gray,       -- Line number color (default: colors.gray)
    scrollbarColor = colors.lightGray, -- Scrollbar indicator color (default: colors.lightGray)

    onChange = function(text)         -- Called when text changes
        print("Content changed: " .. #text .. " characters")
    end
})

-- Get/set content
local content = editor:getText()      -- Returns full text with \n separators
editor:setText("New\nContent\nHere")  -- Sets text from string

-- Direct line access
editor.lines = {"Line 1", "Line 2"}   -- Array of strings
editor.cursorRow = 1                  -- Current row (1-indexed)
editor.cursorCol = 0                  -- Current column (0-indexed)
```

**Features:**
- **Multi-line Editing**: Full support for line creation, deletion, and joining
  - Enter key splits line at cursor
  - Backspace at line start joins with previous line
- **Vertical Scrolling**: Automatically scrolls to keep cursor visible
  - Scrollbar shows current position when content exceeds height
  - Mouse wheel support for scrolling
  - PageUp/PageDown for quick navigation
- **Line Numbers**: Optional line number gutter on left side
- **CraftOS Cursor**: Native cursor positioning for authentic feel
- **Full Keyboard Navigation**:
  - Arrow keys move cursor (up/down/left/right)
  - Home/End jump to line start/end
  - PageUp/PageDown scroll by page
  - Enter creates new line
  - Backspace deletes character or joins lines
- **Mouse Support**:
  - Click to position cursor
  - Mouse wheel to scroll
  - Click line numbers (if enabled)

**Visual Format:**
```
Without line numbers:
┌────────────────────────────┐
│This is line one_           │
│This is line two            │
│This is line three          │
│                            │
└────────────────────────────┘

With line numbers:
┌────────────────────────────┐
│  1 This is line one_       │
│  2 This is line two        │
│  3 This is line three      │
│  4                         │
└────────────────────────────┘

With scrollbar (more content than visible):
┌────────────────────────────┐
│  1 This is line one        │█
│  2 This is line two        │░
│  3 This is line three      │░
└────────────────────────────┘
```

**Line Storage:**
- Text stored as array of strings: `textarea.lines = {"line1", "line2"}`
- Cursor position: `cursorRow` (1-indexed), `cursorCol` (0-indexed)
- No trailing newline in array (join with "\n" to get full text)

**Scrolling Behavior:**
- `scrollOffset` tracks first visible line (0-indexed)
- Automatically adjusts when cursor moves out of view
- PageUp/PageDown moves by (height - 1) lines
- Mouse wheel moves by 3 lines per scroll
- Scrollbar shows proportional position (character `\127`)

**Keyboard Controls:**
- **Type** - Insert character at cursor
- **Enter** - Split line at cursor (create new line below)
- **Backspace** - Delete character before cursor, or join with previous line
- **Left/Right Arrow** - Move cursor horizontally (wraps to prev/next line)
- **Up/Down Arrow** - Move cursor vertically (maintains column when possible)
- **Home** - Move to start of current line
- **End** - Move to end of current line
- **PageUp** - Scroll up one page
- **PageDown** - Scroll down one page

**Mouse Controls:**
- **Click** - Focus and position cursor at click location
- **Mouse Wheel Up** - Scroll up 3 lines
- **Mouse Wheel Down** - Scroll down 3 lines

**Example: Simple Text Editor**

```lua
local ui = dofile("UI.lua")

local context = { scenes = {}, elements = {}, functions = {} }
ui.init(context)

ui.newScene("Editor")
ui.setScene("Editor")

-- Title bar
ui.label({
    text = "Text Editor - Press Ctrl+S to save",
    position = "topCenter",
    yOffset = 1,
    fg = colors.yellow
})

-- Main editor area
local editor = ui.textarea({
    width = 48,
    height = 16,
    lineNumbers = true,
    text = "-- Welcome to the editor!\n-- Type your code here\n\nfunction hello()\n    print(\"Hello, world!\")\nend",
    position = "center",
    yOffset = 1,
    fg = colors.white,
    bg = colors.black,
    onChange = function(text)
        -- Could track unsaved changes here
        print("Document modified")
    end
})

-- Status bar
local statusLabel = ui.label({
    text = "Ready",
    position = "bottomLeft",
    xOffset = 2,
    yOffset = -1,
    fg = colors.lime
})

-- Save button
ui.button({
    text = "Save",
    width = 10,
    bg = colors.green,
    position = "bottomRight",
    xOffset = -12,
    yOffset = -1,
    onclick = function()
        local content = editor:getText()
        -- Save to file here
        statusLabel.text = "Saved! (" .. #content .. " bytes)"
        print("File saved")
    end
})

-- Clear button
ui.button({
    text = "Clear",
    width = 10,
    bg = colors.red,
    position = "bottomRight",
    xOffset = -24,
    yOffset = -1,
    onclick = function()
        editor:setText("")
        statusLabel.text = "Cleared"
    end
})

ui.run({fps = 30})
```

**Example: Code Viewer with Syntax Highlighting (Basic)**

```lua
local ui = dofile("UI.lua")

ui.init(context)
ui.newScene("Viewer")
ui.setScene("Viewer")

-- Title
ui.label({
    text = "=== Code Viewer ===",
    position = "topCenter",
    yOffset = 1,
    fg = colors.cyan
})

-- Load code from file
local file = fs.open("program.lua", "r")
local code = file.readAll()
file.close()

-- Read-only viewer (would need to add read-only flag to make truly immutable)
local viewer = ui.textarea({
    text = code,
    width = 50,
    height = 18,
    lineNumbers = true,
    position = "center",
    fg = colors.white,
    bg = colors.black,
    lineNumberFg = colors.gray
})

-- File info
ui.label({
    text = "Lines: " .. #viewer.lines .. " | Chars: " .. #code,
    position = "bottomCenter",
    yOffset = -1,
    fg = colors.yellow
})

ui.run({fps = 30})
```

**Example: Multi-panel Layout with TextArea**

```lua
local ui = dofile("UI.lua")

ui.init(context)
ui.newScene("IDE")
ui.setScene("IDE")

-- Left panel: File list (simulated with labels)
ui.rectangle({
    width = 15,
    height = 18,
    position = "left",
    xOffset = 1,
    yOffset = 2,
    bg = colors.gray
})

ui.label({
    text = "Files:",
    position = "topLeft",
    xOffset = 2,
    yOffset = 2,
    fg = colors.yellow
})

ui.label({
    text = "> main.lua",
    position = "topLeft",
    xOffset = 2,
    yOffset = 4,
    fg = colors.white
})

ui.label({
    text = "  config.lua",
    position = "topLeft",
    xOffset = 2,
    yOffset = 5,
    fg = colors.lightGray
})

-- Right panel: Editor
local editor = ui.textarea({
    width = 35,
    height = 15,
    lineNumbers = true,
    text = "-- main.lua\nprint(\"Hello!\")",
    position = "topLeft",
    xOffset = 18,
    yOffset = 2,
    fg = colors.white,
    bg = colors.black
})

-- Bottom panel: Output
ui.label({
    text = "Output:",
    position = "bottomLeft",
    xOffset = 2,
    yOffset = -3,
    fg = colors.lime
})

ui.rectangle({
    width = 50,
    height = 2,
    position = "bottomLeft",
    xOffset = 1,
    yOffset = -2,
    bg = colors.black
})

ui.run({fps = 30})
```

**Performance Notes:**
- Efficiently handles hundreds of lines
- Only visible lines are rendered each frame
- Scrolling updates only visible region
- CraftOS cursor updates are batched

**Differences from TextField:**

| Feature | TextField | TextArea |
|---------|-----------|----------|
| Lines | Single line | Multiple lines |
| Scrolling | Horizontal | Vertical |
| Line Numbers | No | Optional |
| Cursor | Custom drawn `_` | CraftOS cursor |
| Enter Key | No effect | Creates new line |
| Arrow Keys | Left/Right only | All directions |
| Use Case | Forms, input fields | Editors, large text |

**When to Use:**
- **textarea**: Multi-line content, code editors, document viewers, large text input
- **textfield**: Single-line input, forms, search boxes, simple text entry
- **advancedTextField**: Password fields, autocomplete inputs (see InputsDocs.md)

**Notes:**
- Line numbers add 4 characters to effective width (format: "  1 ")
- Scrollbar adds 1 character to right edge when active
- Empty textarea starts with one empty line
- CraftOS cursor blinks at system rate (not customizable)
- Mouse wheel scrolling requires event support in UI framework

---

### Rectangle

Filled rectangular background.

**Options:**
```lua
ui.rectangle({
    width = 30,
    height = 10,
    position = "center",
    bg = colors.gray,
    filled = true              -- Always filled currently
})
```

---

### Terminal

Advanced console/terminal element with scrolling, prompts, and spinner.

**Options:**
```lua
local console = ui.terminal({
    width = 50,
    height = 12,
    position = "center",
    fg = colors.white,
    bg = colors.black
})
```

**Methods:**

#### `console:append(text)`
Adds a line to the terminal history.

```lua
console:append("[System] Starting up...")
```

#### `console:clear()`
Clears all lines.

```lua
console:clear()
```

#### `console:prompt(prefix, callback)`
Shows an input prompt and captures user input.

```lua
console:prompt(">", function(input)
    console:append("You entered: " .. input)
end)
```

#### `console:startSpinner(label)`
Shows an animated spinner on the bottom line.

```lua
console:startSpinner("Loading...")
```

#### `console:stopSpinner(finalText)`
Stops the spinner and optionally adds a final message.

```lua
console:stopSpinner("[Done]")
```

**Features:**
- Scrollable history (mouse wheel)
- Blinking cursor during prompt (0.5s period)
- Animated spinner (|, /, -, \) at 0.15s intervals
- Up to 200 lines of history
- Auto-scrolling

**Animation:** The terminal uses `update(dt)` to animate both cursor and spinner, ensuring smooth frame-rate independent animations.

---

## Layout System

The layout system provides automatic positioning and sizing of child elements using container-based layouts.

### Overview

Layouts solve the problem of manually positioning related elements by automatically calculating positions based on layout rules:

- **VStack** - Vertical stack (children arranged top-to-bottom)
- **HStack** - Horizontal stack (children arranged left-to-right)
- **Grid** - Grid layout (children arranged in rows/columns)

**Key Features:**
- Auto-sizing (containers calculate their dimensions from children)
- Alignment options (left/center/right, top/center/bottom)
- Padding and spacing
- Dynamic child management (`addChild`, `removeChild`)
- Nested layouts supported
- Builder pattern for declarative UI construction

---

### VStack (Vertical Stack)

Arranges children vertically from top to bottom.

```lua
local stack = ui.vstack({
    position = "center",
    spacing = 1,              -- Space between children (default: 0)
    align = "left",           -- "left", "center", "right" (default: "left")
    padding = 1,              -- Padding around all children (default: 0)
    width = 20,               -- Fixed width (optional, auto-calculated if omitted)
    height = 10,              -- Fixed height (optional, auto-calculated if omitted)

    builder = function(container)
        container:addChild(ui.label({ text = "Title", fg = colors.yellow }))
        container:addChild(ui.label({ text = "Subtitle", fg = colors.gray }))
        container:addChild(ui.button({
            text = "Click Me",
            bg = colors.blue,
            onclick = function() print("Clicked!") end
        }))
    end
})
```

**Options:**
- `spacing` - Vertical space between children (default: 0)
- `align` - Horizontal alignment: "left", "center", "right" (default: "left")
- `padding` - Padding around container edges (default: 0)
- `width`, `height` - Fixed dimensions (auto-calculated if omitted)
- `position`, `xOffset`, `yOffset` - Standard positioning
- `builder` - Function to add children declaratively

**Methods:**
- `stack:addChild(element)` - Add child and re-layout
- `stack:removeChild(element)` - Remove child and re-layout
- `stack:layout()` - Manually trigger layout recalculation

---

### HStack (Horizontal Stack)

Arranges children horizontally from left to right.

```lua
local hstack = ui.hstack({
    position = "center",
    spacing = 2,              -- Space between children (default: 1)
    align = "center",         -- "top", "center", "bottom" (default: "top")
    padding = 1,

    builder = function(container)
        container:addChild(ui.button({ text = "Save", bg = colors.green }))
        container:addChild(ui.button({ text = "Cancel", bg = colors.red }))
        container:addChild(ui.button({ text = "Help", bg = colors.blue }))
    end
})
```

**Options:**
- `spacing` - Horizontal space between children (default: 1)
- `align` - Vertical alignment: "top", "center", "bottom" (default: "top")
- `padding` - Padding around container edges (default: 0)
- `width`, `height` - Fixed dimensions (auto-calculated if omitted)
- `builder` - Function to add children declaratively

**Methods:**
- `hstack:addChild(element)` - Add child and re-layout
- `hstack:removeChild(element)` - Remove child and re-layout

---

### Grid

Arranges children in a grid with specified number of columns.

```lua
local grid = ui.grid({
    position = "center",
    columns = 3,              -- Number of columns (default: 2)
    spacing = 1,              -- Space between all cells (default: 1)
    rowSpacing = 1,           -- Vertical space (overrides spacing)
    columnSpacing = 2,        -- Horizontal space (overrides spacing)
    padding = 1,

    builder = function(container)
        for i = 1, 9 do
            container:addChild(ui.label({
                text = tostring(i),
                fg = colors.white,
                bg = colors.gray
            }))
        end
    end
})
```

**Options:**
- `columns` - Number of columns (default: 2)
- `spacing` - Space between rows and columns (default: 1)
- `rowSpacing` - Vertical space (overrides `spacing`)
- `columnSpacing` - Horizontal space (overrides `spacing`)
- `padding` - Padding around grid edges (default: 0)
- `builder` - Function to add children declaratively

**Methods:**
- `grid:addChild(element)` - Add child and re-layout
- `grid:removeChild(element)` - Remove child and re-layout

**Layout Algorithm:**
- Children fill columns left-to-right
- New row starts after reaching `columns` limit
- All columns in a row use the width of the widest element in that column
- All cells in a row use the height of the tallest element in that row

---

### Layout Patterns

#### Builder Pattern (Recommended)

Use the `builder` function for declarative UI construction:

```lua
ui.vstack({
    position = "center",
    spacing = 1,
    builder = function(container)
        container:addChild(ui.label({ text = "Item 1" }))
        container:addChild(ui.label({ text = "Item 2" }))
        container:addChild(ui.button({ text = "OK" }))
    end
})
```

**Benefits:**
- Cleaner, more readable code
- All children added before layout calculation
- Single render (no flicker)

#### Manual Child Management

Add children after creation:

```lua
local stack = ui.vstack({ position = "center", spacing = 1 })
stack:addChild(ui.label({ text = "Item 1" }))
stack:addChild(ui.label({ text = "Item 2" }))

-- Later: dynamically add/remove
stack:addChild(ui.label({ text = "Item 3" }))
stack:removeChild(someElement)
```

**Benefits:**
- Dynamic UI updates
- Programmatic child management
- Good for reactive/data-driven UIs

---

### Nested Layouts

Layouts can be nested to create complex UI structures:

```lua
ui.vstack({
    position = "center",
    spacing = 2,
    builder = function(mainContainer)
        -- Header
        mainContainer:addChild(ui.label({
            text = "Settings",
            fg = colors.yellow
        }))

        -- Form with grid layout
        local formGrid = ui.grid({
            columns = 2,
            spacing = 1,
            builder = function(gridContainer)
                gridContainer:addChild(ui.label({ text = "Name:" }))
                gridContainer:addChild(ui.textfield({ width = 15 }))

                gridContainer:addChild(ui.label({ text = "Email:" }))
                gridContainer:addChild(ui.textfield({ width = 15 }))
            end
        })
        mainContainer:addChild(formGrid)

        -- Buttons
        local buttonRow = ui.hstack({
            spacing = 2,
            builder = function(hContainer)
                hContainer:addChild(ui.button({ text = "Save", bg = colors.green }))
                hContainer:addChild(ui.button({ text = "Cancel", bg = colors.red }))
            end
        })
        mainContainer:addChild(buttonRow)
    end
})
```

---

### Auto-Sizing

Layouts automatically calculate their dimensions from children:

```lua
-- This vstack will auto-size to fit all children
local stack = ui.vstack({
    spacing = 1,
    padding = 1,
    builder = function(container)
        container:addChild(ui.label({ text = "Short" }))
        container:addChild(ui.label({ text = "Much longer text here" }))
        container:addChild(ui.button({ text = "OK", width = 10 }))
    end
})

-- stack.width automatically becomes: 22 (longest child + padding*2)
-- stack.height automatically becomes: 5 (3 children + 2 spacing + padding*2)
```

**Fixed Sizing:**
You can override auto-sizing by specifying `width` and/or `height`:

```lua
local stack = ui.vstack({
    width = 30,      -- Fixed width
    height = 10,     -- Fixed height
    spacing = 1,
    align = "center", -- Children centered in fixed width
    builder = function(container)
        container:addChild(ui.label({ text = "Centered" }))
    end
})
```

---

### Dynamic Updates

Layouts support dynamic child management:

```lua
local list = ui.vstack({ position = "center", spacing = 1 })

-- Add items dynamically
local items = {"Apple", "Banana", "Cherry"}
for _, item in ipairs(items) do
    list:addChild(ui.label({ text = item }))
end

-- Remove items
list:removeChild(list.children[2])  -- Remove "Banana"

-- Clear all children
for i = #list.children, 1, -1 do
    list:removeChild(list.children[i])
end
```

---

### Complete Layout Example

```lua
local ui = dofile("UI.lua")
ui.init(context)
ui.newScene("Dashboard")
ui.setScene("Dashboard")

-- Create a dashboard layout
ui.vstack({
    position = "center",
    spacing = 2,
    padding = 1,
    builder = function(main)
        -- Title
        main:addChild(ui.label({
            text = "Dashboard",
            fg = colors.yellow
        }))

        -- Stats grid
        local stats = ui.grid({
            columns = 2,
            spacing = 1,
            builder = function(grid)
                grid:addChild(ui.label({ text = "CPU: 45%", fg = colors.lime }))
                grid:addChild(ui.label({ text = "RAM: 2.1GB", fg = colors.cyan }))
                grid:addChild(ui.label({ text = "Disk: 15GB", fg = colors.orange }))
                grid:addChild(ui.label({ text = "Net: 5MB/s", fg = colors.lightBlue }))
            end
        })
        main:addChild(stats)

        -- Action buttons
        local actions = ui.hstack({
            spacing = 2,
            align = "center",
            builder = function(buttons)
                buttons:addChild(ui.button({
                    text = "Refresh",
                    bg = colors.blue,
                    onclick = function() print("Refreshing...") end
                }))
                buttons:addChild(ui.button({
                    text = "Settings",
                    bg = colors.gray,
                    onclick = function() print("Settings...") end
                }))
            end
        })
        main:addChild(actions)
    end
})

ui.run({fps = 30})
```

---

### Implementation Notes

**Building Flag:**
During layout construction with the `builder` pattern, `UI._buildingLayout` is set to `true` to prevent auto-refresh on each `addChild` call. The layout calculates positions once after all children are added.

**Element Removal:**
Use `UI.removeElement(element)` to remove standalone elements, or `layout:removeChild(element)` to remove from a layout container.

**Performance:**
Layouts call `layout()` automatically when children are added/removed. For batch operations, consider using the builder pattern to avoid multiple layout calculations.

---

## Advanced Usage

### Custom Elements

Create your own element types:

```lua
local myElement = {
    type = "custom",
    x = 1,
    y = 1,
    
    draw = function(self)
        term.setCursorPos(self.x, self.y)
        term.write("Custom element!")
    end,
    
    update = function(self, dt)
        -- Animation logic using delta time
    end,
    
    onClick = function(self, x, y)
        -- Click handler
        return true  -- Handled, don't pass through
    end
}

ui.addElement("MyScene", myElement)
```

### Async Work Element Pattern

For background tasks, create an invisible element:

```lua
local worker = {
    type = "worker",
    x = 0, y = 0,
    timer = 0,
    
    update = function(self, dt)
        self.timer = self.timer + dt
        
        if self.timer >= 1.0 then
            self.timer = 0
            -- Do periodic work
            print("Tick!")
        end
    end,
    
    draw = function(self)
        -- Invisible
    end
}

ui.addElement("MyScene", worker)
```

**Why this pattern?**
- Uses the same delta time as all other animations
- Guaranteed to run every frame
- No separate coroutine management needed
- Timing synchronized with UI updates

### Positioning System

**Anchor positions:**
- `center`
- `topLeft`, `topCenter`, `topRight`
- `left`, `leftCenter` (same as `left`)
- `right`, `rightCenter` (same as `right`)
- `bottomLeft`, `bottomCenter`, `bottomRight`

**Example:**
```lua
ui.button({
    text = "Top Right Button",
    position = "topRight",
    xOffset = -2,  -- 2 chars from right edge
    yOffset = 1    -- 1 line from top
})
```

### Child Scenes (Popups)

Layer scenes on top of each other:

```lua
-- Create popup scene
ui.newScene("Popup")
ui.setScene("Popup")

ui.rectangle({
    width = 30,
    height = 8,
    position = "center",
    bg = colors.gray
})

ui.label({
    text = "Are you sure?",
    position = "center",
    yOffset = -1
})

ui.button({
    text = "Yes",
    position = "center",
    xOffset = -6,
    yOffset = 2,
    onclick = function()
        ui.removeChild("Popup")
        -- Do action
    end
})

-- Back to main scene
ui.setScene("MainMenu")

-- Show popup when needed
ui.setChild("Popup", 0, 0, "center")
```

---

## Best Practices

### 1. Always Initialize

```lua
local context = { scenes = {}, elements = {}, functions = {} }
ui.init(context)
```

### 2. Use Scenes for Organization

```lua
ui.newScene("MainMenu")
ui.newScene("Settings")
ui.newScene("GamePlay")
```

### 3. Create Elements After Setting Scene

```lua
ui.setScene("MainMenu")
-- Now add elements to MainMenu
ui.button({ ... })
ui.label({ ... })
```

### 4. Use the Parallel Render Loop

```lua
ui.run({fps = 30})
```

**Simple as that!** Parallel event/render threads automatically prevent flicker.

### 5. Use onTick or Worker Elements for Background Tasks

**Option 1: onTick callback (for frequent work)**
```lua
ui.run({
    fps = 30,
    onTick = function()
        doWork()  -- Runs every frame
    end
})
```

**Option 2: Worker element (for throttled work)**
```lua
-- Good: worker element with accumulator
local worker = {
    type = "worker",
    x = 0, y = 0,
    timer = 0,
    update = function(self, dt)
        self.timer = self.timer + dt
        if self.timer >= 1.0 then  -- Once per second
            self.timer = 0
            doWork()
        end
        return false
    end,
    draw = function(self) end
}
ui.addElement("MyScene", worker)
ui.run({fps = 30})
```

### 6. Store Element References for Dynamic Updates

```lua
local myLabel = ui.label({ text = "Initial" })

-- Later:
myLabel.text = "Updated"
-- No need to call markDirty() - renders every frame
```

### 7. Use Callbacks for Dynamic Behavior

```lua
ui.button({
    text = "Dynamic",
    onclick = function(self)
        self.text = "Clicked!"
    end
})
```

### 8. Handle nil Safely in Custom Elements

If creating elements that might not have `text` or `width`:

```lua
local width = e.width or (e.text and #e.text) or 1
```

This ensures proper fallback to 1 if both are nil.

---

## Examples

### Simple Menu

```lua
local ui = dofile("OSUtil/ui.lua")
local context = { scenes = {}, elements = {}, functions = {} }
ui.init(context)

ui.newScene("Menu")
ui.setScene("Menu")

ui.label({
    text = "Main Menu",
    position = "topCenter",
    yOffset = 2,
    fg = colors.yellow
})

ui.button({
    text = "Start Game",
    position = "center",
    yOffset = -1,
    bg = colors.green,
    colorPressed = colors.lime,
    onclick = function()
        print("Starting game...")
    end
})

ui.button({
    text = "Quit",
    position = "center",
    yOffset = 1,
    bg = colors.red,
    colorPressed = colors.orange,
    onclick = function()
        os.shutdown()
    end
})

ui.run({fps = 30})
```

### Terminal with Async Work

```lua
local ui = dofile("OSUtil/ui.lua")
local context = { scenes = {}, elements = {}, functions = {} }
ui.init(context)

ui.newScene("Console")
ui.setScene("Console")

local console = ui.terminal({
    position = "center",
    width = 50,
    height = 15
})

console:append("System ready. Type 'work' to start task.")

-- Async work state
local work = { running = false, timer = 0, step = 0 }

local function newPrompt()
    if work.running then return end
    console:prompt(">", function(input)
        if input == "work" then
            console:append("Starting work...")
            console:startSpinner("Processing...")
            work.running = true
            work.timer = 0
            work.step = 0
        else
            console:append("Unknown command: " .. input)
            newPrompt()
        end
    end)
end

newPrompt()

-- Async worker element
local worker = {
    type = "worker",
    x = 0, y = 0,
    
    update = function(self, dt)
        if not work.running then return end
        
        work.timer = work.timer + dt
        if work.timer >= 0.5 then
            work.timer = 0
            work.step = work.step + 1
            console:append(string.format("Step %d/5", work.step))
            
            if work.step >= 5 then
                console:stopSpinner()
                console:append("Work complete!")
                work.running = false
                newPrompt()
            end
        end
    end,
    
    draw = function(self) end
}

ui.addElement("Console", worker)

ui.run({fps = 30})
```

### Settings Panel with Checkboxes

```lua
local ui = dofile("OSUtil/ui.lua")
local context = { scenes = {}, elements = {}, functions = {} }
ui.init(context)

ui.newScene("Settings")
ui.setScene("Settings")

ui.label({
    text = "=== Settings ===",
    position = "topCenter",
    yOffset = 2,
    fg = colors.yellow
})

local settings = {
    sound = true,
    particles = false,
    debug = false
}

ui.checkbox({
    text = "Enable Sound",
    position = "center",
    yOffset = -2,
    initial = settings.sound,
    onclick = function(self, checked)
        settings.sound = checked
        print("Sound: " .. tostring(checked))
    end
})

ui.checkbox({
    text = "Enable Particles",
    position = "center",
    yOffset = 0,
    initial = settings.particles,
    onclick = function(self, checked)
        settings.particles = checked
    end
})

ui.checkbox({
    text = "Debug Mode",
    position = "center",
    yOffset = 2,
    initial = settings.debug,
    onclick = function(self, checked)
        settings.debug = checked
    end
})

ui.button({
    text = "Back",
    position = "bottomCenter",
    yOffset = -2,
    bg = colors.gray,
    onclick = function()
        ui.setScene("MainMenu")
    end
})

ui.run({fps = 30})
```

---

## Troubleshooting

### Elements not appearing
- Make sure you called `ui.setScene()` after creating the scene
- Check that elements are added to the correct scene
- Verify positioning isn't placing elements off-screen

### Clicks not working
- Elements must be in `contextTable.elements` (check with `ui.setScene()`)
- Click coordinates must be within element bounds
- Check if another element is overlapping (reverse iteration = top element wins)

### Animations not running
- Element must have `update(dt)` method
- Element must be in the active scene
- Make sure main loop calls `ui.tick()`

### Messages appearing delayed
- **Fixed in v14!** Rendering now happens immediately after updates
- If still experiencing issues, ensure you're using async worker elements, not separate coroutines

### Focus not working
- Only one element can be focused at a time
- Set focus with `ui.focused = element`
- Element needs `onKey` or `onChar` handlers

### "attempt to get length of field 'text' (a nil value)"
- This happens with elements that have no `text` field
- Make sure invisible elements (like async workers) don't have click handlers
- Or ensure width is explicitly set: `width = 1`

---

## Version History

**v2.1** (Current - 2025-10-28)
- Code cleanup: Removed 73 lines of orphaned functions
  - Removed `UI.tick()` (50 lines) - superseded by `UI.run()`
  - Removed `UI.handleEvent()` (20 lines) - integrated into `UI.run()`
  - Removed legacy draw fallback (3 lines)
- All examples updated to use `ui.run()` instead of `ui.tick()`
- Documentation updated throughout

**v2.0**
- Added `UI.run()` - parallel render loop (eliminates flicker)
- Dirty flag system - only renders when changes occur
- Fixed-rate rendering at configurable FPS
- Event handling in separate thread
- Animation system with delta time (`update(dt)`)

**v1.x** (Legacy)
- Sequential tick-based loop
- Scene management system
- Element types: button, label, checkbox, textfield, terminal
- Focus system for keyboard input
- Child scene support

---

## License

MIT License - Feel free to use in your CC:Tweaked projects!
ui.setChild("ConfirmDialog", 0, 0, "center")
```

#### `UI.removeChild(target)`

Removes a child scene from the active scene.

**Parameters:**
- `target` (string or table) - Child scene name or reference

**Example:**
```lua
ui.removeChild("ConfirmDialog")
```