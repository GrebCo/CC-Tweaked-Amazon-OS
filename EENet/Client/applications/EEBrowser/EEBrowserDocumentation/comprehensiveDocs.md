# CC:Tweaked UI Framework — Complete Reference

A complete ComputerCraft UI framework with **15 themes**, **full event system**, and **layout components**.

## 🚀 Start Here: UI_GUIDE.md

For practical usage and recipes, start with **[UI_GUIDE.md](./UI_GUIDE.md)** which covers:

- **Quick Start** - 5-minute setup to your first UI
- **Core Concepts** - Scenes, elements, dirty flag rendering
- **Event System & Hooks** - Mouse, keyboard, focus, custom events
- **UI Elements** - Button, Label, Checkbox, TextField, Rectangle, Terminal
- **Themes** - 15 built-in themes + how to create custom themes
- **Examples & Recipes** - Login form, dynamic theming, data display
- **Troubleshooting** - Common issues and fixes

---

## This Document

This comprehensive reference contains additional details for advanced use:

- **Architecture Overview** - Rendering pipeline, data flow, flattening process
- **Extended Event System** - Focus model, event subscriptions, container hit-testing
- **Layout System** - VStack, HStack, Grid patterns
- **Container System** - Dynamic child management, background inheritance
- **Dialog & Modal System** - Alert, confirm, prompt dialogs
- **Advanced Inputs** - Slider, button groups, dropdowns, advanced text fields
- **Data Visualization** - Progress bars, gauges, tables, charts

---

## Table of Contents

### Core Framework (UI.lua)

1. **[Quick Start](#quick-start)** ⭐ Start here
2. **[Architecture Overview](#architecture-overview)** - Internal design
3. **[Core Concepts](#core-concepts)** - Key ideas
4. **[Event System](#event-system)** - How events work
5. **[Theme System](#theme-system)** - Colors, themes, custom themes
6. **[API Reference](#api-reference)** - Complete function list
7. **[Element Types](#element-types)** - All core elements
8. **[Layout System](#layout-system)** - Organizing elements
9. **[Container System](#container-system)** - Grouping and child management
10. **[Dialog & Modal System](#dialog--modal-system)** - Dialogs and alerts
11. **[Advanced Usage](#advanced-usage)** - Custom elements, async work
12. **[Best Practices](#best-practices)** - Performance and patterns
13. **[Examples](#examples)** - Working code samples
14. **[Troubleshooting](#troubleshooting)** - Common issues

### Interactive Inputs (Inputs.lua)

15. **[Inputs Module](#inputs-module-documentation-interactive-elements)** - Advanced inputs
    - Slider
    - Button Group / Radio Buttons
    - Dropdown Menu
    - Advanced Text Field
    - Terminal (Composition)

### Data Visualization (DataDisplay.lua)

16. **[Data Display Module](#data-display-module-documentation-theme-system-edition)** - Visualization components
    - Progress Bar
    - Gauge
    - Stat Panel
    - Scrollable List
    - Table
    - Bar Chart
    - Range Bar

---

# Part I: Core Framework (UI.lua)

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

**See [UI_GUIDE.md](./UI_GUIDE.md) for more examples.**

---

## Architecture Overview

### The Rendering Pipeline

UI.run starts two parallel loops:

**Render loop:** Computes dt, calls UI.update(dt), calls UI.render(), sleeps briefly.

**Event loop:** Blocks on os.pullEvent(), forwards to UI.handleEvent(...).

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
Rendering walks the scene tree (scene.elements and child scenes)
Flattened list is used for input hit testing and UI.update(dt)
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

### 6. Delta Time and Animations

All animations use delta time (`dt`) for frame-rate independent timing:

- `UI.run()` calculates `dt` automatically in the render loop
- Passes it to `UI.update(dt)`
- All element `update(dt)` methods receive the same delta time
- This ensures consistent animation speeds regardless of frame rate
- Default is 30 FPS, configurable via `ui.run({fps = 60})`

### 7. Async Work Pattern

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

---

## Event System

The v3.0 event system provides unified, predictable event handling across all UI elements.

### Core Principle

> **The UI framework decides when clicks happen. Elements just react.**

Elements no longer control whether they receive clicks - the framework's hit-testing and pointer tracking ensures **all elements receive appropriate events automatically**.

### Event Flow

#### 1. Entry Point: `UI.handleEvent(ev, p1, p2, p3, p4)`

All ComputerCraft events are routed through this single function:

```lua
-- In UI.run() event loop:
local ev, p1, p2, p3, p4 = os.pullEvent()
UI.handleEvent(ev, p1, p2, p3, p4)
```

The framework automatically handles:
- Mouse clicks (`mouse_click`, `mouse_up`, `mouse_drag`)
- Touch events (`monitor_touch`)
- Scrolling (`mouse_scroll`)
- Keyboard input (`char`, `key`, `key_up`)
- Custom events (broadcast to subscribers)

#### 2. Pointer Events: Hit-Testing & Bubbling

**On Mouse Down:**

1. **Hit-Test**: Find the deepest visible element under cursor
2. **Focus**: Update focus if element is `focusable`
3. **Bubble onPress**: Call `onPress` up the parent chain until claimed
4. **Track Press**: **Always** set `UI.pressedElement` (even if no `onPress` exists)

**On Mouse Up:**

1. **Bounds Check**: Was release over the same element?
2. **onRelease**: Notify element of mouse-up
3. **onClick**: If `inBounds`, call semantic click handler

**On Mouse Drag:**

- Calls `onDrag` on `UI.pressedElement` (the element under original press)

### Event Handlers

All elements support these optional hooks. **See [UI_GUIDE.md](./UI_GUIDE.md#event-system--event-hooks) for the complete event handler reference.**

### Focus Model

The focus system determines which element receives keyboard input.

#### Focus Flags

```lua
local textfield = ui.textfield({
    text = "Type here",
    focusable = true,   -- Allow click-to-focus
    lockFocus = true    -- Prevent losing focus on outside clicks
})
```

- **`focusable`**: If `true`, clicking this element focuses it
- **`lockFocus`**: If `true`, clicking elsewhere cannot steal focus (command prompts, locked input)

#### Focus API

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

#### Focus Rules

1. **Click-to-focus**: Clicking a `focusable` element focuses it automatically
2. **lockFocus Protection**: Current element's `lockFocus` prevents focus changes
3. **Click-away unfocus**: Clicking non-focusable areas clears focus (unless locked)
4. **Force Override**: `{force = true}` bypasses `lockFocus`

### Event Subscriptions

Elements can subscribe to arbitrary events beyond pointer/keyboard:

#### `element:subscribeEvent(eventName, callback)`

Subscribe an element to a specific event. **Element-local subscriptions** only fire when:
- The element is visible (`UI.isVisible(element)`)
- The element is in the active scene

**Parameters:**
- `eventName` (string) - Event name to listen for
- `callback` (function) - Handler function with signature `function(element, eventName, ...)`

**Example:**
```lua
local redstoneMonitor = ui.label({
    text = "Waiting...",
    init = function(self)
        -- Subscribe to redstone events
        self:subscribeEvent("redstone", function(self, eventName, side)
            self.text = "Redstone pulse on " .. side
            UI.markDirty()
        end)
    end
})
```

**Storage:** Subscriptions are stored in `element._subscriptions[eventName]` as an array.

**Visibility Check:** Hidden elements don't receive events.

#### `element:unsubscribeEvent(eventName, callback)`

Removes a specific subscription from an element.

**Note:** You must pass the **same function reference** used in `subscribeEvent()`. Anonymous functions cannot be unsubscribed.

**Common Pattern - Cleanup:**
```lua
local element = ui.label({
    text = "Monitor",
    init = function(self)
        -- Store handler reference for cleanup
        self._timerHandler = function(self, eventName, timerId)
            self.text = "Timer " .. timerId .. " fired"
        end
        self:subscribeEvent("timer", self._timerHandler)
    end,

    onDestroy = function(self)
        -- Clean up subscription when element destroyed
        self:unsubscribeEvent("timer", self._timerHandler)
    end
})
```

#### `UI.subscribeGlobalEvent(eventName, callback)`

Subscribe to an event **globally**, bypassing visibility and scene checks.

**Parameters:**
- `eventName` (string) - Event name to listen for
- `callback` (function) - Handler function with signature `function(eventName, ...)`

**Differences from element-local subscriptions:**
- Always fires, regardless of visibility or scene
- No element reference in callback
- Fires even if no UI is initialized
- Use for global system events (redstone, timers, etc.)

**Example:**
```lua
UI.subscribeGlobalEvent("timer", function(eventName, timerId)
    print("Global timer: " .. timerId)
end)
```

### Container & Hit-Testing

Containers (rectangles, dialogs, scenes with children) use hit-testing to determine which element receives mouse events.

**Container Pattern:**
- Containers have a list of children
- Hit-test walks the tree depth-first
- Deepest visible child under cursor receives the event
- Events bubble up to parents if child doesn't claim them

**Parent References:**
- Each element stores `parent` reference
- `element.parent` - Direct parent container
- Used for hit-testing and event bubbling

**Hit-Testing:**
```lua
-- Automatic: framework does this for you
local hit = hitTest(rootElement, x, y)
-- Returns the deepest visible child element at (x, y)
```

---

## Theme System

### Overview

The theme system provides a centralized way to manage colors and visual styles across all UI elements.

#### How It Works

1. **Themes are registered** with `ui.registerTheme(name, definition)`
2. **Active theme is set** with `ui.setTheme(name)`
3. **Elements automatically use** the active theme for colors
4. **Color resolution** follows: element property → role → palette → CC default

#### Roles

Every theme has a `roles` table mapping semantic meanings to colors:

```lua
roles = {
    background = colors.black,              -- Screen background
    text = colors.white,                    -- Normal text
    textDim = colors.lightGray,             -- Dim/disabled text
    surface = colors.gray,                  -- Containers, panels
    border = colors.gray,                   -- Borders, dividers
    interactive = colors.blue,              -- Buttons, inputs (normal)
    interactiveHover = colors.lightBlue,    -- Buttons on hover
    interactiveActive = colors.cyan,        -- Buttons when active/pressed
    interactiveDisabled = colors.gray,      -- Disabled buttons
    interactiveText = colors.white,         -- Text on interactive elements
    success = colors.lime,                  -- Success messages
    error = colors.red,                     -- Errors, warnings
    warning = colors.yellow,                -- Warnings
    info = colors.lightBlue,                -- Info messages
    selection = colors.blue                 -- Selected items
}
```

#### Palette

Optional color remapping for rich RGB colors (requires CC RGB support):

```lua
palette = {
    [colors.black] = 0x0A1929,      -- Remap CC black to deep navy
    [colors.white] = 0xE0F4FF,      -- Remap CC white to light cyan
    -- ... etc for all 16 colors
}
```

### Color Resolution in Elements

When an element needs a color, it resolves in this order:

```lua
-- Method 1: Literal color (always this color, never changes with theme)
ui.button({
    fg = colors.red,        -- Literal: always red
    bg = 32                  -- Literal: always color 32
})

-- Method 2: Theme role string (changes when theme changes)
ui.button({
    fg = "error",           -- Role: resolves to theme.roles.error
    bg = "interactive"      -- Role: resolves to theme.roles.interactive
})

-- Method 3: Mix both
ui.button({
    fg = "error",           -- From current theme
    bg = colors.black       -- Always black
})

-- Method 4: Nil (uses default role for element type)
ui.button({
    -- fg not specified: will use theme's "interactiveText" by default
    -- bg not specified: will use theme's "interactive" by default
})
```

**Resolution algorithm:**
1. If property is a **number** → use that literal color (theme-independent)
2. If property is a **string** → look up as role in `theme.roles[string]`
3. If property is **nil** → use the element's default role for that property
4. If theme doesn't have that role → use hardcoded fallback color

**Example:**
```lua
local btn = ui.button({
    fg = "error",           -- String → look up theme.roles.error
    bg = colors.blue        -- Number → use literal colors.blue
    -- No colorPressed specified → use default role
})

ui.setTheme("dark")         -- Switch themes
-- fg changes to theme.dark.roles.error
-- bg stays colors.blue (literal)
-- colorPressed uses default role (probably theme.dark.roles.interactiveHover)
```

### Built-in Themes

The `themes.lua` file provides 15 professionally-designed themes. See [UI_GUIDE.md](./UI_GUIDE.md#themes) for the complete list.

### Loading Built-in Themes

```lua
local ui = dofile("UI.lua")
ui.init(context)

-- Load all 15 themes
local registerThemes = dofile("themes.lua")
registerThemes(ui)

-- Now you can use any theme
ui.setTheme("catppuccin")
ui.setTheme("nord")
ui.setTheme("dracula")
ui.setTheme("paper")  -- Light theme
```

### Creating Custom Themes

**Simple theme** (using CC colors only):

```lua
ui.registerTheme("minimal", {
    roles = {
        background = colors.black,
        text = colors.white,
        -- ... define all 16 roles ...
    }
})

ui.setTheme("minimal")
```

**Complete theme** with custom RGB palette:

```lua
ui.registerTheme("ocean", {
    roles = {
        background = colors.black,
        text = colors.white,
        -- ... define all 16 roles ...
    },
    palette = {
        [colors.black] = 0x0A1929,
        [colors.white] = 0xE0F4FF,
        -- ... map all 16 colors to hex values ...
    }
})
```

**See [UI_GUIDE.md](./UI_GUIDE.md#themes) for complete examples.**

### Theme Validation

When registering a theme, the system validates:

1. **Roles table exists**: Must include all required roles
2. **Palette values are valid**: Must be numbers (hex format: `0xRRGGBB`)

---

## API Reference

This section provides a complete function reference. For practical usage, see [UI_GUIDE.md](./UI_GUIDE.md).

### Initialization

```lua
ui.init(contextTable)
-- Initialize the UI framework with a context table
-- context.scenes, context.elements, context.functions

ui.run(options)
-- Start the render + event loop
-- options: {fps = 30, ...}
```

### Scene Management

```lua
ui.newScene(name)
-- Create a new scene

ui.setScene(name)
-- Activate a scene (flattens its elements into contextTable.elements)

ui.getScene(name)
-- Get a scene table by name

ui.addChild(sceneName, childScene, xOffset, yOffset)
-- Add a child scene to a parent scene

ui.removeChild(sceneName, childScene)
-- Remove a child scene
```

### Element Management

```lua
ui.addElement(sceneName, element)
-- Add an element to a scene

ui.removeElement(sceneName, element)
-- Remove an element from a scene
```

### Rendering & Updates

```lua
UI.render()
-- Render the active scene to the terminal

UI.update(dt)
-- Update all elements with delta time

UI.markDirty()
-- Force a re-render on the next cycle

UI.needRender
-- Boolean flag: true if render is scheduled
```

### Focus Control

```lua
UI.setFocus(element, options)
-- Set focus to an element
-- options: {force = true}  -- bypass lockFocus

UI.clearFocus(options)
-- Clear focus
-- options: {force = true}

UI.focused
-- Get the currently focused element (nil if none)
```

### Theme System

```lua
ui.registerTheme(name, definition)
-- Register a new theme

ui.setTheme(name)
-- Activate a theme

ui.getTheme(name)
-- Get a theme definition

ui.getActiveTheme()
-- Get the name of the active theme
```

### Event Handling

```lua
UI.handleEvent(eventName, p1, p2, p3, p4)
-- Dispatch an event to elements

element:subscribeEvent(eventName, callback)
-- Subscribe element to event

element:unsubscribeEvent(eventName, callback)
-- Unsubscribe element from event

UI.subscribeGlobalEvent(eventName, callback)
-- Subscribe globally to event

UI.unsubscribeGlobalEvent(eventName, callback)
-- Unsubscribe globally
```

### Visibility & Queries

```lua
UI.isVisible(element)
-- Check if element is visible

element.visible = true/false
-- Set element visibility
```

---

## Element Types

### Button

Clickable button with visual press feedback.

```lua
ui.button({
    text = "Click Me",
    position = "center",
    xOffset = 0,
    yOffset = 0,
    fg = colors.white,
    bg = colors.gray,
    colorPressed = colors.lightGray,
    toggle = false,
    onclick = function(self, x, y, button, isTouch)
        print("Button clicked!")
    end
})
```

**Behavior:**
- Non-toggle: Shows pressed color for 0.1s using animation system
- Toggle: Stays pressed until clicked again
- Fully non-blocking (uses `update(dt)` for timing)

**See [UI_GUIDE.md](./UI_GUIDE.md#button) for more.**

---

### Label

Static text display.

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

**See [UI_GUIDE.md](./UI_GUIDE.md#label) for more.**

---

### Checkbox

Boolean toggle with `[x]` or `[ ]` display.

```lua
ui.checkbox({
    text = "Enable feature",
    initial = false,
    fg = colors.white,
    bg = colors.black,
    onclick = function(self, checked)
        print("Checked: " .. tostring(checked))
    end
})
```

**See [UI_GUIDE.md](./UI_GUIDE.md#checkbox) for more.**

---

### Text Field

Unified text input for single-line and multi-line editing.

```lua
-- Single-line
ui.textfield({
    text = "",
    width = 20,
    height = 1,
    placeholder = "Type here...",
    fg = colors.white,
    bg = colors.gray,
    onChange = function(text)
        print("Text: " .. text)
    end
})

-- Multi-line
ui.textfield({
    text = "Line 1\nLine 2",
    width = 40,
    height = 10,
    onChange = function(text)
        print("Content: " .. #text .. " chars")
    end
})
```

**Features:**
- **Single-line:** Horizontal scrolling with `<` and `>` indicators
- **Multi-line:** Vertical scrolling, arrow keys, Enter for new lines
- **Click to position** cursor
- **Full keyboard support**

**See [UI_GUIDE.md](./UI_GUIDE.md#text-field) for complete documentation.**

---

### Rectangle

Simple colored rectangle.

```lua
ui.rectangle({
    width = 20,
    height = 5,
    position = "center",
    bg = colors.blue
})
```

---

### Terminal

Terminal emulator accepting drawing commands.

```lua
ui.terminal({
    width = 40,
    height = 10,
    position = "center"
})
```

**See [UI_GUIDE.md](./UI_GUIDE.md#terminal) for more.**

---

## Layout System

### Overview

The layout system helps organize elements in patterns (VStack, HStack, Grid).

### VStack (Vertical Stack)

Arranges elements vertically:

```lua
ui.vstack({
    position = "center",
    children = {
        ui.label({text = "Title"}),
        ui.button({text = "Button 1"}),
        ui.button({text = "Button 2"}),
        ui.button({text = "Button 3"})
    }
})
```

### HStack (Horizontal Stack)

Arranges elements horizontally:

```lua
ui.hstack({
    position = "center",
    children = {
        ui.button({text = "Left"}),
        ui.button({text = "Center"}),
        ui.button({text = "Right"})
    }
})
```

### Grid

Arranges elements in a grid:

```lua
ui.grid({
    cols = 3,
    rows = 2,
    position = "center",
    children = {
        {ui.label({text = "1,1"}), ui.label({text = "1,2"}), ui.label({text = "1,3"})},
        {ui.label({text = "2,1"}), ui.label({text = "2,2"}), ui.label({text = "2,3"})}
    }
})
```

---

## Container System

### Overview

Containers group related elements and handle layout, background inheritance, child management, and dragging.

### Container Types

**Layout Containers** (auto-organize children):
- **VStack** - Arranges children vertically (top-to-bottom)
- **HStack** - Arranges children horizontally (left-to-right)
- **Grid** - Arranges children in a grid

**Generic Container**:
- **Rectangle** - Colored box with optional border, manual child positioning, draggable

**Other**:
- **Dialog** - Modal dialog box
- **Scene** - Logical grouping of elements

### VStack (Vertical Stack)

```lua
local stack = ui.vstack({
    spacing = 1,              -- Space between children
    align = "center",         -- "left", "center", "right"
    padding = 1,              -- Padding inside container
    position = "center",

    builder = function(container)
        container:addChild(ui.label({text = "Item 1"}))
        container:addChild(ui.button({text = "Click"}))
        container:addChild(ui.checkbox({text = "Check"}))
    end
})

-- Methods:
stack:addChild(element)
stack:removeChild(element)
stack:layout()              -- Recalculate positions
```

### HStack (Horizontal Stack)

```lua
local stack = ui.hstack({
    spacing = 2,              -- Space between children
    align = "top",            -- "top", "center", "bottom"
    padding = 1,
    position = "center",

    builder = function(container)
        container:addChild(ui.button({text = "Left"}))
        container:addChild(ui.button({text = "Right"}))
    end
})

-- Same methods as VStack
```

### Grid Layout

```lua
local grid = ui.grid({
    columns = 3,              -- Number of columns
    spacing = 1,              -- Space between items
    padding = 1,
    position = "center",

    builder = function(container)
        for i = 1, 9 do
            container:addChild(ui.button({text = tostring(i)}))
        end
    end
})

-- Same methods as VStack
```

### Rectangle Container

A colored box that can contain other elements, with optional dragging:

```lua
local panel = ui.rectangle({
    width = 30,
    height = 10,
    bg = colors.gray,
    border = true,
    borderColor = colors.black,
    padding = 1,

    draggable = true,         -- ENABLE DRAGGING!

    init = function(self)
        self:addChild(ui.label({text = "Draggable Panel"}))
        self:addChild(ui.button({text = "Click me"}))
    end
})

-- Methods:
panel:addChild(element)
panel:removeChild(element)
panel:layout()              -- Recalculate child positions

-- Properties:
panel.isDragging            -- Currently being dragged
panel._hasBeenDragged       -- Has been manually moved
```

**Dragging behavior (when draggable=true):**
- Click and drag the rectangle to move it on screen
- Position updates automatically
- Children move with their parent
- Works anywhere in bounds
- Calls layout() when drag ends

### Dynamic Child Management

**Method 1: Builder function (recommended)**

```lua
local container = ui.rectangle({
    width = 20,
    height = 10,
    builder = function(self)
        self:addChild(ui.button({text = "New Button"}))
        self:addChild(ui.label({text = "Another item"}))
    end
})
```

**Method 2: Manual addChild**

```lua
local container = ui.rectangle({width = 20, height = 10})
container:addChild(ui.button({text = "New Button"}))
container:addChild(ui.label({text = "Item"}))
container:layout()  -- Recalculate positions
```

**Method 3: Direct children table manipulation**

```lua
local container = ui.rectangle({width = 20, height = 10})
table.insert(container.children, ui.button({text = "Button"}))
table.remove(container.children, 1)
container:layout()  -- Recalculate after manual changes
```

**Method 4: Parent reference in element**

```lua
local container = ui.rectangle({width = 20, height = 10})
ui.button({
    text = "I'm inside",
    parent = container  -- Auto-added to container's children
})
```

---

## Dialog & Modal System

### Overview

Dialogs provide modal interactions (alerts, confirmations, text input).

### UI.alert(message)

Show an alert message:

```lua
UI.alert({
    title = "Warning",
    message = "Something went wrong!",
    buttonText = "OK"
})
```

### UI.confirm(question)

Ask a yes/no question:

```lua
UI.confirm({
    title = "Confirm",
    message = "Are you sure?",
    yesText = "Yes",
    noText = "No",
    callback = function(confirmed)
        if confirmed then
            print("User clicked Yes")
        end
    end
})
```

### UI.prompt(label)

Get text input:

```lua
UI.prompt({
    title = "Enter Name",
    label = "Your name:",
    callback = function(text)
        print("User entered: " .. text)
    end
})
```

---

## Advanced Usage

### Creating Custom Elements

Custom elements are tables with `type`, `x`, `y`, and `draw()` method:

```lua
local customElement = {
    type = "customWidget",
    x = 1, y = 1,
    width = 10, height = 5,
    text = "Custom",

    draw = function(self)
        term.setCursorPos(self.x, self.y)
        term.write(self.text)
    end,

    update = function(self, dt)
        -- Optional: animation logic
        return true  -- Trigger redraw if changed
    end,

    onClick = function(self, x, y, button)
        print("Clicked custom element")
    end
}

ui.addElement("MyScene", customElement)
```

### Async Work Element Pattern

For background tasks:

```lua
local asyncWorker = {
    type = "worker",
    x = 0, y = 0,

    update = function(self, dt)
        -- Do work here
        -- This is called every frame with dt (delta time)

        -- Return true if UI needs to be redrawn
        return false
    end,

    draw = function(self)
        -- Empty: invisible element
    end
}

ui.addElement("MyScene", asyncWorker)
```

---

## Best Practices

1. **Use dirty flag optimization** - Only mark dirty when UI actually changes
2. **Organize with scenes** - Use scenes to manage complex UIs
3. **Subscribe to events** - Don't poll; use event subscriptions
4. **Keep update() lightweight** - Move heavy work outside the render loop
5. **Cache theme lookups** - Store color values instead of looking them up every frame
6. **Use positioning wisely** - Anchor positions (center, top, left, etc.) for responsive layouts

---

## Examples

### Example: Login Form

**See [UI_GUIDE.md](./UI_GUIDE.md#recipe-simple-login-form) for working code.**

### Example: Dynamic Theming

**See [UI_GUIDE.md](./UI_GUIDE.md#recipe-dynamic-theming-ui) for working code.**

### Example: Data Display

**See [UI_GUIDE.md](./UI_GUIDE.md#recipe-simple-data-display) for working code.**

---

## Troubleshooting

**"Elements not displaying?"** - See [UI_GUIDE.md](./UI_GUIDE.md#troubleshooting)

**"Button not responding?"** - See [UI_GUIDE.md](./UI_GUIDE.md#troubleshooting)

**"Text field not accepting input?"** - See [UI_GUIDE.md](./UI_GUIDE.md#troubleshooting)

**"Animations choppy?"** - See [UI_GUIDE.md](./UI_GUIDE.md#troubleshooting)

**"Theme colors not applying?"** - See [UI_GUIDE.md](./UI_GUIDE.md#troubleshooting)

---

# Part II: Interactive Inputs (Inputs.lua)

*Advanced input components: Slider, Button Group, Dropdown, Advanced Text Field*

For practical usage, see [UI_GUIDE.md](./UI_GUIDE.md).

---

# Part III: Data Visualization (DataDisplay.lua)

*Visualization components: Progress Bar, Gauge, Table, Chart, etc.*

For practical usage, see [UI_GUIDE.md](./UI_GUIDE.md).

---

## Summary

This framework provides:

- **15 built-in themes** - Professional color schemes ready to use
- **Complete event system** - Mouse, keyboard, focus, subscriptions
- **Layout components** - VStack, HStack, Grid for organizing UIs
- **Dialog system** - Alert, confirm, prompt modals
- **Advanced inputs** - Sliders, dropdowns, button groups
- **Data visualization** - Charts, tables, gauges, progress bars
- **Custom elements** - Full API for creating your own components

**Start with [UI_GUIDE.md](./UI_GUIDE.md) for practical recipes and examples.**
