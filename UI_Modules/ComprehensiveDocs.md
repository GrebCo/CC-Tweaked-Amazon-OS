# CC:Tweaked UI Framework — Comprehensive Documentation

**Version:** 3.1 (Documentation Update)
**Last Updated:** 2025-11-25
**Description:** Complete documentation for the CC:Tweaked Terminal UI Framework including UI.lua (core framework), Inputs.lua (interactive elements), and DataDisplay.lua (data visualization). Features unified event system, focus model, container architecture, event subscriptions, scene management, animations, parallel rendering, and comprehensive theming.

## Recent Updates (v3.1)

### 📚 Documentation Enhancements

- **Visibility System**: Comprehensive documentation for `UI.isVisible()`, `UI.show()`, `UI.hide()`
  - How visibility affects rendering, hit-testing, and events
  - Visibility propagation through containers
  - Examples of dynamic show/hide patterns

- **Positioning System**: Expanded with complete coverage of all positioning modes
  - Absolute positioning (`x`, `y`, `xOffset`, `yOffset`)
  - Percentage positioning (`xPercent`, `yPercent`) with examples
  - Anchor-based positioning with all available anchors
  - Positioning precedence rules (base → percentage → anchor → offset)
  - Root vs child positioning explained
  - Draggable element behavior

- **Theme System**: Added `UI.resolveOptColor()` documentation
  - Three-layer color resolution (literal, role string, theme default)
  - How elements apply themes with `applyTheme()` method
  - Integration with element constructors

- **Event System**: Enhanced event subscription documentation
  - `element:subscribeEvent()` - Element-local subscriptions
  - `element:unsubscribeEvent()` - Cleanup pattern
  - `UI.subscribeGlobalEvent()` - Global subscriptions
  - Event broadcast behavior and dispatch order
  - Custom event examples

- **Event Handlers**: Updated signatures for all pointer events
  - Added `isTouch` parameter to `onPress`, `onClick`, `onRelease`
  - Documented `onTouch` event for touch screens
  - Added `dx`, `dy` parameters to `onDrag`
  - Documented `onDragEnd` event

- **Container System**: Three methods for adding children documented
  - `opts.parent` parameter for imperative child attachment
  - `container:addChild()` method
  - `builder` function pattern (recommended)
  - When to use each method

- **Element Construction**: Added `opts.init` callback documentation
  - Initialization order in element construction
  - Use cases (event subscriptions, state setup, validation)
  - Examples of complex initialization

- **API Reference**: Added `UI.applyChildPositioning()` documentation
  - Difference from `UI.applyPositioning()`
  - Content area calculation
  - Parent border and padding handling
  - Comparison table

- **API Reference**: Added `UI.initBounds()` documentation
  - Properties initialized (position, size, visibility, focus)
  - Precedence rules for property resolution
  - Why and when to use it
  - Common constructor pattern example

- **Custom Elements**: Complete guide for creating custom UI elements
  - Minimum element format (type + draw method)
  - Recommended constructor pattern with 7-step process
  - Element with update loop for animations
  - Custom container implementation
  - Full framework integration checklist

## Previous Updates (v3.0)

### 🎉 Major Event System Rework

- **Unified Event Entry Point**: `UI.handleEvent(ev, p1, p2, p3, p4)` processes all ComputerCraft events
- **Universal Click Detection**: All elements receive clicks automatically - no `onPress` required
- **Event Bubbling**: Pointer events bubble up through container parent chains
- **Hit-Testing System**: Recursive child detection for proper container interaction
- **Focus Model**: `focusable`, `lockFocus` flags with `UI.setFocus()` / `UI.clearFocus()` API
- **Event Subscriptions**: Elements can subscribe to arbitrary events (`"redstone"`, `"tick"`, `"key"`, etc.)
- **Container Architecture**: Only root elements in scene, children live in `container.children`

### New Event Handler Signatures

All event handlers now follow consistent signatures:
- `onPress(self, x, y, button)` - Called when mouse/touch down on element
- `onRelease(self, x, y, button, inBounds)` - Called when mouse up
- `onClick(self, x, y, button)` - Semantic click (press + release in bounds)
- `onDrag(self, x, y, button)` - Called during mouse drag
- `onScroll(self, dir, x, y)` - Called on scroll wheel
- `onChar(self, ch)` - Character input (focused elements only)
- `onKey(self, key, isHeld, ev)` - Key events (focused elements only)
- `onFocus(self)` - When element gains focus
- `onBlur(self)` - When element loses focus

### Bug Fixes
- Fixed checkbox/button groups not clickable (pressedElement always set now)
- Fixed slider dragging broken (moved drag init from onClick to onPress)
- Fixed dropdown not receiving keyboard input (added focusable flag)
- Fixed textfields backspacing twice (key_up events now ignored)
- Fixed grid layout checkerboard pattern (spacing only between columns)
- Fixed dialog scene name crash (DialogsDemo → DialogDemo)

### Breaking Changes
- Event handlers must use new signatures (old `mx, my` parameters renamed to `x, y`)
- Dragging state must be set in `onPress`, not `onClick` (onClick now fires on release)
- Direct `UI.focused` assignment deprecated - use `UI.setFocus()` instead
- Elements needing keyboard must set `focusable = true`

### Deprecated/Removed (from v2.2)
- `ui.textarea()` - Use `ui.textfield()` with height > 1 instead
- `inputs.textArea()` - Use `inputs.advancedTextField()` with height > 1 instead
- `ui.alert()`, `ui.confirm()`, `ui.prompt()` - Use `ui.dialog()` instead

---

## Documentation Structure

This comprehensive document combines three modules:
- **Part I: Core Framework (UI.lua)** - Foundation, elements, layouts, containers, dialogs
- **Part II: Interactive Inputs (Inputs.lua)** - Sliders, dropdowns, button groups, text areas
- **Part III: Data Visualization (DataDisplay.lua)** - Charts, gauges, tables, progress bars

---

## Table of Contents

### Part I: Core Framework (UI.lua)

1. [Quick Start](#quick-start)
2. [Architecture Overview](#architecture-overview)
3. [Core Concepts](#core-concepts)
4. [Event System](#event-system) ⭐ NEW
   - [Event Handlers](#event-handlers)
   - [Focus Model](#focus-model)
   - [Event Subscriptions](#event-subscriptions)
   - [Container & Hit-Testing](#container--hit-testing)
5. [Theme System](#theme-system)
6. [API Reference](#api-reference)
7. [Element Types](#element-types)
8. [Layout System](#layout-system)
9. [Container System](#container-system)
10. [Dialog & Modal System](#dialog--modal-system)
11. [Advanced Usage](#advanced-usage)
12. [Best Practices](#best-practices)
13. [Examples](#examples)

### Part II: Interactive Inputs

13. [Interactive Inputs Overview](#inputs-module-documentation-interactive-elements)
14. [Slider](#slider)
15. [Button Group / Radio Buttons](#button-group--radio-buttons)
16. [Dropdown Menu](#dropdown-menu)
17. [Advanced Text Field](#advanced-text-field)
18. [Terminal (Composition-based)](#terminal)

### Part III: Data Visualization

19. [Data Display Overview](#data-display-module-documentation-theme-system-edition)
20. [Progress Bar](#progress-bar)
21. [Gauge](#gauge)
22. [Stat Panel](#stat-panel)
23. [Scrollable List](#scrollable-list)
24. [Table](#table)
25. [Bar Chart](#bar-chart)
26. [Range Bar](#range-bar)

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

**Why?** This ensures your async work uses the same timing system as UI animations, preventing timing desynchronization issues.

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
   ```lua
   local hit = hitTest(rootElement, x, y)
   ```
2. **Focus**: Update focus if element is `focusable`
   ```lua
   if hit and hit.focusable then
       UI.setFocus(hit)
   end
   ```
3. **Bubble onPress**: Call `onPress` up the parent chain until claimed
   ```lua
   -- Bubbles up: child → parent → grandparent
   local claimed = bubblePointerDown(hit, x, y, button)
   ```
4. **Track Press**: **Always** set `UI.pressedElement` (even if no `onPress` exists)
   ```lua
   UI.pressedElement = claimed or hit  -- Fallback to hit!
   ```

**On Mouse Up:**

1. **Bounds Check**: Was release over the same element?
   ```lua
   local inBounds = (x >= ex and x < ex + w and y >= ey and y < ey + h)
   ```
2. **onRelease**: Notify element of mouse-up
3. **onClick**: If `inBounds`, call semantic click handler

**On Mouse Drag:**

- Calls `onDrag` on `UI.pressedElement` (the element under original press)

### Event Handlers

All elements support these optional hooks:

#### Pointer Handlers

```lua
onPress = function(self, x, y, button, isTouch)
    -- Called when mouse/touch presses on this element
    -- x, y: cursor position
    -- button: 1=left, 2=right, 3=middle
    -- isTouch: true if from monitor_touch, false if from mouse_click
    -- Return true to "claim" the press (prevents parent handling)
    -- Return false/nil to let parent handle it
end

onClick = function(self, x, y, button, isTouch)
    -- Semantic click: press + release on the same element
    -- Called AFTER onRelease, only if mouse is still in bounds
    -- This is the primary "action" handler for most elements
    -- isTouch: true if from touch screen, false if from mouse
end

onTouch = function(self, x, y)
    -- Touch screen instant tap (monitor_touch event)
    -- Called IMMEDIATELY on touch - no wait for release
    -- Only fires for touch screens, not mouse clicks
    -- Fires before onPress and onClick
    -- x, y: touch coordinates
end

onRelease = function(self, x, y, button, inBounds, isTouch)
    -- Called when mouse button is released
    -- inBounds: true if cursor is still over this element
    -- isTouch: true if from touch screen, false if from mouse
end

onDrag = function(self, x, y, button, dx, dy)
    -- Called during mouse drag (only if this element was pressed)
    -- x, y: current cursor position
    -- button: mouse button being held
    -- dx, dy: delta movement since last drag event
    -- Typically check self.dragging flag set in onPress
end

onDragEnd = function(self, x, y, button)
    -- Called when drag ends (mouse button released during drag)
    -- x, y: final cursor position
    -- button: mouse button that was released
end

onScroll = function(self, dir, x, y)
    -- Called on scroll wheel
    -- dir: -1 (up) or 1 (down)
    -- Can bubble: return false to pass to parent
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
    -- ev: "key" (not "key_up" - those are filtered out)
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

**Example: Locked Terminal**
```lua
local terminal = inputs.terminal({
    focusable = true,
    lockFocus = true,  -- User can't click away from terminal
    -- ...
})

-- Only way to unfocus:
UI.clearFocus({force = true})
```

### Event Subscriptions

Elements can subscribe to arbitrary events beyond pointer/keyboard using two subscription APIs:

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

        -- Subscribe to tick events
        self:subscribeEvent("tick", function(self, eventName, dt)
            self._time = (self._time or 0) + dt
            -- Animate something...
        end)
    end
})
```

**Storage:** Subscriptions are stored in `element._subscriptions[eventName]` as an array.

**Visibility Check:** Hidden elements don't receive events:
```lua
if UI.isVisible(element) then
    -- dispatch event to element's subscriptions
end
```

---

#### `element:unsubscribeEvent(eventName, callback)`

Removes a specific subscription from an element.

**Parameters:**
- `eventName` (string) - Event name to unsubscribe from
- `callback` (function) - The exact function reference to remove

**Example:**
```lua
local handler = function(self, eventName)
    print("Timer fired!")
end

-- Subscribe
element:subscribeEvent("timer", handler)

-- Later: unsubscribe
element:unsubscribeEvent("timer", handler)
```

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

---

#### `UI.subscribeGlobalEvent(eventName, callback)`

Subscribe to an event **globally**, bypassing visibility and scene checks.

**Parameters:**
- `eventName` (string) - Event name to listen for
- `callback` (function) - Handler function with signature `function(eventName, ...)`

**Differences from element-local subscriptions:**
1. **Always fires** - Not affected by element visibility or active scene
2. **No element context** - Callback receives `eventName` first, no `self` parameter
3. **Global storage** - Stored in `UI._globalEventRegistry[eventName]`

**Example:**
```lua
-- Monitor all redstone events globally
UI.subscribeGlobalEvent("redstone", function(eventName, side)
    print("Redstone change on " .. side)
    -- No element context - this is global
end)

-- Monitor HTTP responses globally
UI.subscribeGlobalEvent("http_success", function(eventName, url, responseHandle)
    print("HTTP request completed: " .. url)
    responseHandle.close()
end)

-- Custom event handling
UI.subscribeGlobalEvent("custom_data_update", function(eventName, data)
    -- Update multiple parts of UI based on data change
    updateDashboard(data)
    updateSidebar(data)
end)
```

**Use Cases:**
- Background monitoring (network, redstone, sensors)
- Global state updates that affect multiple UI elements
- Debugging/logging (capture all events of a type)
- System-level event handling independent of UI state

**Warning:** Global subscriptions persist across scene changes and are not automatically cleaned up. Manage them carefully to avoid memory leaks.

---

#### Event Broadcast Behavior

**Broadcast Nature**: Events are dispatched to **all matching subscribers** - subscriptions don't swallow events.

**Dispatch Order:**
1. Element-local subscriptions (in active scene, visible elements only)
2. Global subscriptions (always)

Both happen in parallel when `UI.handleEvent()` is called.

**Available Events**:
- Standard CC events: `"redstone"`, `"timer"`, `"alarm"`, `"http_success"`, `"http_failure"`, `"disk"`, `"peripheral"`, etc.
- Mouse/keyboard events: `"mouse_click"`, `"mouse_up"`, `"mouse_drag"`, `"mouse_scroll"`, `"char"`, `"key"`, `"key_up"`, `"monitor_touch"`
- Custom events: Any event you pass to `UI.handleEvent()` or `UI.emitEvent()`

**Example - Custom Events:**
```lua
-- Emit custom event
UI.emitEvent("data_loaded", {users = 100, items = 500})

-- Subscribers receive it
element:subscribeEvent("data_loaded", function(self, eventName, data)
    self.text = "Users: " .. data.users
end)
```

### Container & Hit-Testing

The v3.0 container architecture uses parent-child relationships:

#### Container Pattern

```lua
local panel = ui.rectangle({
    width = 30,
    height = 10,
    children = {},  -- Children live here, not in scene
    builder = function(container)
        -- Elements added inside builder become children
        ui.label({ text = "I'm a child!" })
        ui.button({ text = "Me too!" })
    end
})
```

**Layout Building**: When `builder` function runs, `UI._layoutParent` is set to the container, so any `ui.*` calls add children to it automatically.

#### Parent References

All children have `_parent` reference:

```lua
child._parent  -- → container element
```

This enables **event bubbling** - events can propagate up the tree.

#### Hit-Testing

The framework recursively searches children:

```lua
function hitTest(element, x, y)
    -- Check if x, y is inside element bounds
    if not inBounds(element, x, y) then
        return nil
    end

    -- Check children (deepest first)
    if element.children then
        for i = #element.children, 1, -1 do
            local hit = hitTest(element.children[i], x, y)
            if hit then return hit end  -- Return deepest hit
        end
    end

    -- No child hit, this element is the hit
    return element
end
```

**Result**: Clicks always hit the "top-most" visual element, even if deeply nested.

### Migration Guide

#### Old Way (Pre-v3.0)
```lua
-- BROKEN: onClick never fired without onPress
checkbox = {
    checked = false,
    onClick = function(self)
        self.checked = not self.checked
    end
}

-- BROKEN: Dragging set in onClick (fires on release now!)
slider = {
    onPress = function(self, mx, my)  -- Wrong parameters
        -- ...
    end,
    onClick = function(self, mx, my)  -- Wrong parameters
        self.dragging = true  -- TOO LATE!
    end
}

-- BROKEN: Direct focus assignment
textfield = {
    onClick = function(self)
        UI.focused = self  -- Bypasses lockFocus checks
    end
}
```

#### New Way (v3.0)
```lua
-- ✅ Works with just onClick!
checkbox = {
    checked = false,
    onClick = function(self, x, y, button)  -- Correct params
        self.checked = not self.checked
    end
}

-- ✅ Dragging state set in onPress
slider = {
    dragging = false,
    onPress = function(self, x, y, button)  -- Correct params
        self.dragging = true  -- Set BEFORE drag events
        self:setValue(self:posToValue(x, y))
        return true
    end,
    onDrag = function(self, x, y, button)
        if self.dragging then
            self:setValue(self:posToValue(x, y))
        end
    end,
    onRelease = function(self, x, y, button, inBounds)
        self.dragging = false
    end
}

-- ✅ Use focusable flag + requestFocus
textfield = {
    focusable = true,  -- Framework handles click-to-focus
    lockFocus = false,
    onFocus = function(self)
        self.showCursor = true
    end,
    onBlur = function(self)
        self.showCursor = false
    end
}
```

### Best Practices

1. **Simple Clicks**: Most elements only need `onClick` - framework handles the rest
2. **Dragging**: Set dragging state in `onPress`, check it in `onDrag`
3. **Focus**: Use `focusable` flag, not direct assignment
4. **Bubbling**: Return `true` from `onPress` to claim events (prevent parent handling)
5. **Parameters**: Use consistent `x, y, button` names (not `mx, my`)
6. **Keyboard**: Only focused elements receive `onChar`/`onKey`
7. **Subscriptions**: Use `init` hook to subscribe to custom events

---

## Overview

The UI.lua theme system provides a powerful, palette-based theming solution for ComputerCraft applications. It enables:

- **Semantic role-based colors** - Use meaningful names like `interactive`, `error`, `success` instead of hardcoded colors
- **Palette remapping** - Redefine the 16 ComputerCraft colors to match any RGB color scheme
- **13 built-in themes** - Professional themes including Catppuccin, Gruvbox, Nord, Dracula, and more
- **Easy theme switching** - Change your entire app's appearance with a single function call
- **Automatic element theming** - All UI elements automatically respect the active theme
- **Custom themes** - Create and register your own themes with full palette control

### How It Works

1. **Roles System**: Instead of hardcoding `colors.blue` in elements, they use semantic roles like `interactive`
2. **Palette Remapping**: Each theme can redefine what `colors.blue` actually looks like (e.g., Catppuccin's #89B4FA)
3. **Automatic Application**: When you call `UI.setTheme()`, the palette is updated and the screen redraws

---

## Quick Start

### Basic Usage

```lua
-- Load the UI library
local ui = dofile("UI.lua")

-- Initialize with a context
local context = {
    term = term.current(),
    elements = {},
    dirty = true
}
ui.init(context)

-- Load built-in themes (optional, adds 15 themes)
local registerThemes = dofile("themes.lua")
registerThemes(ui)

-- Activate a theme
ui.setTheme("catppuccin")

-- Create elements - they automatically use theme colors
ui.button({
    text = "Click Me",
    position = "center",
    onClick = function() print("Clicked!") end
    -- bg automatically uses theme.roles.interactive
})

-- Switch themes at runtime
ui.setTheme("gruvbox")  -- Instantly changes entire UI appearance
```

### Without Built-in Themes

If you don't load `themes.lua`, the "default" theme is automatically active:

```lua
local ui = dofile("UI.lua")
ui.init(context)
-- "default" theme is now active with standard CC colors
```

---

## Theme Architecture

### Theme Structure

A theme consists of two main parts:

1. **Roles** (required) - Semantic color mappings
2. **Palette** (optional) - RGB remapping of ComputerCraft's 16 colors

```lua
{
    -- ROLES: Semantic color assignments (REQUIRED)
    roles = {
        background = colors.black,        -- Main background
        text = colors.white,              -- Primary text
        textDim = colors.lightGray,       -- Secondary/muted text
        surface = colors.gray,            -- UI surface/panel background
        border = colors.gray,             -- Borders and dividers

        -- Interactive states
        interactive = colors.blue,        -- Default interactive elements
        interactiveHover = colors.lightBlue,    -- Hover state
        interactiveActive = colors.cyan,        -- Active/pressed state
        interactiveDisabled = colors.gray,      -- Disabled state
        interactiveText = colors.white,         -- Text color on interactive elements

        -- Status colors
        success = colors.lime,            -- Success messages, checkmarks
        error = colors.red,               -- Errors, warnings
        warning = colors.yellow,          -- Caution states
        info = colors.lightBlue,          -- Informational messages
        selection = colors.blue           -- Selected items
    },

    -- PALETTE: RGB remapping (OPTIONAL)
    -- Redefines what each ComputerCraft color looks like
    palette = {
        [colors.black] = 0x1E1E2E,       -- Hex RGB value
        [colors.white] = 0xCDD6F4,
        [colors.gray] = 0x313244,
        [colors.blue] = 0x89B4FA,
        -- ... all 16 colors can be remapped
    }
}
```

### Roles vs Palette

**Roles** define *which* ComputerCraft color is used for each semantic purpose:
- "Use `colors.blue` for interactive elements"
- "Use `colors.red` for errors"

**Palette** defines *what that color looks like*:
- "`colors.blue` should render as #89B4FA (Catppuccin blue)"
- "`colors.red` should render as #F38BA8 (Catppuccin red)"

This two-layer system enables themes to:
1. Maintain consistent semantic meanings across themes (roles)
2. Apply visual styling through RGB customization (palette)

---

## Built-in Themes

The `themes.lua` file provides 15 professionally-designed themes:

| Theme Name | Description | Style |
|------------|-------------|-------|
| `catppuccin` | Catppuccin Mocha | Pastel, soothing colors |
| `gruvbox` | Gruvbox Dark | Retro, warm earth tones |
| `nord` | Nord | Cool, arctic-inspired palette |
| `dracula` | Dracula | Dark, high-contrast purple accent |
| `tokyonight` | Tokyo Night | Dark blue with neon accents |
| `onedark` | One Dark | Atom's iconic dark theme |
| `solarized` | Solarized Dark | Scientific precision palette |
| `monokai` | Monokai | Sublime Text's classic theme |
| `material` | Material Dark | Google Material Design |
| `rosepine` | Rosé Pine | Muted, elegant rose tones |
| `everforest` | Everforest | Natural, forest-inspired |
| `ayu` | Ayu Dark | Modern, refined minimalism |
| `paper` | Paper Light | Clean, minimal light theme |
| `solarized_light` | Solarized Light | Scientific precision, light variant |
| `gruvbox_light` | Gruvbox Light | Warm earth tones, light variant |
| `default` | Default | Standard CC colors (built into UI.lua, not themes.lua) |

**Note:** The `default` theme is built into UI.lua and is active automatically. The 15 themes listed above (excluding `default`) are provided by `themes.lua`.

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
ui.setTheme("solarized_light")  -- Light theme
```

### Theme Preview

Each built-in theme:
- Uses the same role structure for consistency
- Provides complete palette remapping
- Includes carefully chosen accent colors for interactive elements
- Maintains good contrast for readability

---

## Creating Custom Themes

### Minimal Theme (No Palette)

A basic theme with just roles, using standard ComputerCraft colors:

```lua
ui.registerTheme("minimal", {
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
    -- No palette - uses ComputerCraft default colors
})

ui.setTheme("minimal")
```

### Complete Theme with Palette

A full theme with custom RGB colors:

```lua
ui.registerTheme("ocean", {
    roles = {
        background = colors.black,
        text = colors.white,
        textDim = colors.lightGray,
        surface = colors.gray,
        border = colors.blue,
        interactive = colors.cyan,
        interactiveHover = colors.lightBlue,
        interactiveActive = colors.blue,
        interactiveDisabled = colors.gray,
        interactiveText = colors.white,
        success = colors.lime,
        error = colors.red,
        warning = colors.yellow,
        info = colors.lightBlue,
        selection = colors.cyan
    },
    palette = {
        -- Deep ocean theme
        [colors.black] = 0x0A1929,      -- Deep navy background
        [colors.gray] = 0x1E3A5F,       -- Dark blue-gray surface
        [colors.white] = 0xE0F4FF,      -- Light cyan text
        [colors.lightGray] = 0x90CAF9,  -- Muted cyan

        -- Ocean blues
        [colors.blue] = 0x1976D2,       -- Ocean blue
        [colors.lightBlue] = 0x42A5F5,  -- Sky blue
        [colors.cyan] = 0x00ACC1,       -- Teal

        -- Accent colors
        [colors.lime] = 0x66BB6A,       -- Sea green
        [colors.green] = 0x2E7D32,      -- Dark green
        [colors.red] = 0xEF5350,        -- Coral red
        [colors.orange] = 0xFF7043,     -- Sunset orange
        [colors.yellow] = 0xFFEE58,     -- Sandy yellow

        -- Purples/pinks
        [colors.purple] = 0x7E57C2,     -- Deep purple
        [colors.magenta] = 0xAB47BC,    -- Purple
        [colors.pink] = 0xEC407A,       -- Pink coral

        [colors.brown] = 0x5D4037       -- Dark brown (kelp)
    }
})

ui.setTheme("ocean")
```

### Theme Validation

When registering a theme, the system validates:

1. **Roles table exists**: `if not theme.roles then error(...)`
2. **Palette values are numbers**: All palette entries must be hex numbers like `0x1E1E2E`

```lua
-- This will throw an error
ui.registerTheme("broken", {
    roles = {
        background = colors.black
        -- Missing required roles - will work but elements may not look right
    },
    palette = {
        [colors.blue] = "0x5555FF"  -- ERROR: Must be number, not string!
    }
})
```

---

## Theme Resolution

### How Elements Use Themes

UI elements automatically resolve colors from the active theme using a priority system:

**Resolution Priority (highest to lowest):**

1. **Manual override** - Colors explicitly passed to the element
2. **Theme roles** - Resolved from `theme.roles[roleName]`
3. **Hardcoded fallbacks** - Default values when no theme is active

### Element Color Resolution

Each element type maps properties to theme roles:

#### Button
```lua
-- Resolution: interactive → colors.blue
ui.button({
    text = "Click Me",
    position = "center"
    -- bg = theme.roles.interactive (automatically)
    -- colorPressed = theme.roles.interactiveActive (automatically)
})

-- Manual override (highest priority)
ui.button({
    text = "Custom Button",
    bg = colors.red,           -- Overrides theme.roles.interactive
    colorPressed = colors.pink -- Overrides theme.roles.interactiveActive
})
```

#### Label
```lua
-- Resolution: text → colors.white, background → colors.black
ui.label({
    text = "Hello World",
    position = "center"
    -- fg = theme.roles.text (automatically)
    -- bg = theme.roles.background (automatically)
})
```

#### Text Field
```lua
-- Resolution: surface, text, interactive
ui.textfield({
    label = "Name:",
    position = "center"
    -- bg = theme.roles.surface
    -- fg = theme.roles.text
    -- activeBorder = theme.roles.interactive
})
```

#### Checkbox
```lua
-- Resolution: text, success
ui.checkbox({
    label = "Agree",
    position = "center"
    -- fg = theme.roles.text
    -- checkedColor = theme.roles.success
})
```

### Internal Resolution Function

Elements use `UI.resolveColor()` internally:

```lua
-- Inside UI.button() implementation:
local bg = UI.resolveColor("interactive", colors.blue)
-- Returns theme.roles.interactive if available, otherwise colors.blue
```

---

## API Reference

### Theme Management

#### `UI.registerTheme(name, theme)`

Registers a new theme with the system.

**Parameters:**
- `name` (string) - Unique identifier for the theme
- `theme` (table) - Theme definition with `roles` and optional `palette`

**Example:**
```lua
ui.registerTheme("myTheme", {
    roles = {
        background = colors.black,
        text = colors.white,
        interactive = colors.blue,
        -- ... other required roles
    },
    palette = {
        [colors.blue] = 0x5555FF
    }
})
```

**Throws:** Error if `roles` table is missing or palette values are invalid

---

#### `UI.setTheme(themeName)`

Activates a registered theme and applies its palette.

**Parameters:**
- `themeName` (string) - Name of the theme to activate

**Behavior:**
1. Looks up theme in `UI.contextTable.themes`
2. If theme has `palette`, calls `term.setPaletteColor()` for each entry
3. If theme has no `palette`, calls `UI.resetPalette()` to restore CC defaults
4. Sets `UI.contextTable.currentTheme = themeName`
5. Clears screen with `theme.roles.background` color
6. Calls `UI.markDirty()` to trigger a re-render

**Example:**
```lua
ui.setTheme("catppuccin")
-- Terminal palette is now Catppuccin colors
-- Screen clears with new background
-- All elements re-render with new colors
```

**Throws:** Error if theme not found: `"Theme 'xyz' not found"`

---

#### `UI.getCurrentTheme()`

Returns the currently active theme object.

**Returns:**
- Theme table with `roles` and optional `palette`
- `nil` if no theme is active (shouldn't happen after `UI.init()`)

**Example:**
```lua
local theme = ui.getCurrentTheme()
if theme then
    print("Active theme has " .. #theme.palette .. " palette entries")
    print("Interactive color: " .. tostring(theme.roles.interactive))
end
```

---

#### `UI.initThemes()`

Initializes the theme storage system. Called automatically by `UI.init()`.

**Behavior:**
- Creates `UI.contextTable.themes = {}`
- Sets `UI.contextTable.currentTheme = nil`

**Note:** You typically don't need to call this directly.

---

### Color Resolution

#### `UI.resolveColor(roleName, fallback)`

Resolves a color from the active theme's roles.

**Parameters:**
- `roleName` (string) - Name of the role (e.g., `"interactive"`, `"error"`)
- `fallback` (number) - ComputerCraft color to use if role not found

**Returns:** Number (ComputerCraft color value)

**Example:**
```lua
local buttonBg = ui.resolveColor("interactive", colors.blue)
-- If theme exists and has roles.interactive, returns that
-- Otherwise returns colors.blue

local errorText = ui.resolveColor("error", colors.red)
```

**Used by:** All element constructors internally

---

#### `UI.resolveThemePath(path)`

Resolves a nested path in the theme object (advanced usage).

**Parameters:**
- `path` (string) - Dot-separated path like `"button.danger"` or `"dashboard.cpu.bar"`

**Returns:** Value at that path, or `nil` if not found

**Example:**
```lua
-- If theme has: { button = { danger = { bg = colors.red } } }
local dangerBg = ui.resolveThemePath("button.danger.bg")  -- colors.red

-- Custom nested theming
local cpuBarColor = ui.resolveThemePath("dashboard.cpu.bar.fillColor")
```

---

#### `UI.resolveOptColor(optValue, defaultRole, defaultFallback)`

Resolves a color from options with support for literal colors, theme roles, or defaults.

**Parameters:**
- `optValue` (number|string|nil) - User-provided color value
- `defaultRole` (string) - Theme role name to use if `optValue` is nil
- `defaultFallback` (number) - CC color to use if theme doesn't define the role

**Returns:** Number (ComputerCraft color value)

**Resolution Logic:**
1. If `optValue` is a **number**: Return it directly (literal color bypasses theme)
2. If `optValue` is a **string**: Treat as role name, resolve from theme
3. If `optValue` is **nil**: Use `defaultRole` from theme
4. If theme doesn't define role: Return `defaultFallback`

**Example:**
```lua
-- In element constructor
function UI.customButton(opts)
    -- User passes literal color - bypasses theme
    local bg1 = UI.resolveOptColor(colors.red, "interactive", colors.blue)
    -- bg1 = colors.red (literal value used)

    -- User passes role name as string
    local bg2 = UI.resolveOptColor("danger", "interactive", colors.blue)
    -- bg2 = theme.roles.danger (looks up "danger" role in theme)

    -- User doesn't specify - use default theme role
    local bg3 = UI.resolveOptColor(nil, "interactive", colors.blue)
    -- bg3 = theme.roles.interactive (uses defaultRole)

    -- Theme doesn't have role - use fallback
    local bg4 = UI.resolveOptColor(nil, "nonexistent", colors.blue)
    -- bg4 = colors.blue (theme has no "nonexistent" role)
end
```

**Common Usage in Element Constructors:**
```lua
-- Inside UI.button() implementation
function e:applyTheme()
    local o = self.opts or {}
    self.bg = UI.resolveOptColor(o.bg, "interactive", colors.blue)
    self.fg = UI.resolveOptColor(o.fg, "interactiveText", colors.white)
    self.colorHover = UI.resolveOptColor(o.colorHover, "interactiveHover", colors.lightBlue)
end

-- User can now do any of:
ui.button({ bg = colors.red })              -- Literal color
ui.button({ bg = "danger" })                -- Theme role name
ui.button({})                               -- Uses theme's "interactive" role
```

**Design Philosophy:**

This three-layer system allows:
1. **Theme consistency** by default (nil → uses theme role)
2. **Semantic overrides** (string → custom theme role)
3. **Absolute control** (number → exact color)

**Used by:** All element `applyTheme()` methods internally

---

#### `UI.resolveTheme(opts, elementType, propertyMap)`

Universal theme resolution for element constructors (internal use).

**Parameters:**
- `opts` (table) - Element options passed by user
- `elementType` (string) - Type of element (e.g., `"button"`, `"label"`)
- `propertyMap` (table) - Map of properties to fallback values

**Returns:** Table with resolved property values

**Resolution layers (in order):**
1. Hardcoded fallbacks from `propertyMap`
2. Element-specific theme defaults (e.g., `theme.button`)
3. Theme parameter (e.g., `opts.theme = "danger"`)
4. Manual overrides (e.g., `opts.bg = colors.red`)

**Example (internal usage in UI elements):**
```lua
-- Inside UI.button() implementation:
local resolved = UI.resolveTheme(opts, "button", {
    bg = colors.blue,           -- Fallback
    fg = colors.white,          -- Fallback
    colorPressed = colors.lightBlue
})
-- resolved.bg now contains the final color to use
```

---

### Palette Management

#### `UI.resetPalette()`

Resets the terminal palette to ComputerCraft default RGB values.

**Behavior:** Calls `term.setPaletteColor()` for all 16 colors with CC defaults

**Example:**
```lua
ui.setTheme("catppuccin")  -- Palette now has Catppuccin colors
-- ... later ...
ui.resetPalette()  -- Back to standard CC colors
```

**Note:** This is called automatically when activating a theme without a palette

---

## Color Utilities

### `UI.theme.lighten(color)`

Returns a lighter variant of a ComputerCraft color.

**Parameters:**
- `color` (number) - ComputerCraft color value (e.g., `colors.blue`)

**Returns:** Number (lighter color)

**Lightening Map:**
```lua
colors.black → colors.gray → colors.lightGray → colors.white
colors.red → colors.orange → colors.yellow
colors.green → colors.lime
colors.blue → colors.lightBlue → colors.cyan
colors.purple → colors.pink
colors.magenta → colors.pink
colors.brown → colors.orange
```

**Example:**
```lua
local lightBlue = UI.theme.lighten(colors.blue)       -- colors.lightBlue
local lighterBlue = UI.theme.lighten(colors.lightBlue) -- colors.cyan
local lightGray = UI.theme.lighten(colors.black)      -- colors.gray
```

**Use cases:**
- Hover states: `bgHover = UI.theme.lighten(bg)`
- Pressed states: `bgPressed = UI.theme.lighten(bg)`
- Highlighting: `highlighted = UI.theme.lighten(baseColor)`

---

### `UI.theme.darken(color)`

Returns a darker variant of a ComputerCraft color.

**Parameters:**
- `color` (number) - ComputerCraft color value

**Returns:** Number (darker color)

**Darkening Map:**
```lua
colors.white → colors.lightGray → colors.gray → colors.black
colors.yellow → colors.orange → colors.red
colors.lime → colors.green
colors.cyan → colors.lightBlue → colors.blue
colors.pink → colors.magenta → colors.purple
```

**Example:**
```lua
local darkBlue = UI.theme.darken(colors.lightBlue)  -- colors.blue
local darkerBlue = UI.theme.darken(colors.blue)     -- colors.blue (already darkest)
local darkGray = UI.theme.darken(colors.white)      -- colors.lightGray
```

**Use cases:**
- Shadows: `shadowColor = UI.theme.darken(baseColor)`
- Pressed states: `bgPressed = UI.theme.darken(bg)`
- Borders: `borderColor = UI.theme.darken(surfaceColor)`

---

## Advanced Usage

### Dynamic Theme Switching

Create a theme selector menu:

```lua
local themes = {"default", "catppuccin", "gruvbox", "nord", "dracula"}
local currentIndex = 1

ui.button({
    text = "Next Theme",
    position = "center",
    onClick = function()
        currentIndex = (currentIndex % #themes) + 1
        ui.setTheme(themes[currentIndex])
        -- Entire UI updates automatically
    end
})
```

### Creating Custom Elements

You can create custom UI elements that integrate fully with the framework's positioning, theming, events, and visibility systems.

#### Minimum Element Format

Every element must have at minimum:

1. **`type`** (string) - Element type identifier
2. **`draw()`** method - Rendering function

**Bare Minimum Example:**
```lua
local customElement = {
    type = "custom",
    draw = function(self)
        -- Draw implementation
        term.setCursorPos(self.x, self.y)
        term.write("Custom")
    end
}

-- Add to scene
ui.addElement("MyScene", customElement)
```

**Important:** You don't need to manually set `x`, `y`, `width`, `height`, `visible`, or `focusable` - these are handled by `UI.initBounds()` if you use a proper constructor pattern.

---

#### Recommended Constructor Pattern

For full framework integration, follow this pattern:

```lua
function UI.customElement(opts)
    opts = opts or {}

    -- 1. Create element table with type, opts, and methods
    local e = {
        type = "customElement",
        opts = opts,
        customData = opts.customData or "default",
        -- Don't set x/y/width/height/visible/focusable here

        draw = function(self)
            if not UI.isVisible(self) then return end

            UI.term.setTextColor(self.fg)
            UI.term.setBackgroundColor(self.bg)
            UI.term.setCursorPos(self.x, self.y)
            UI.term.write(self.customData)
        end
    }

    -- 2. Initialize bounds (x, y, width, height, visible, focusable)
    UI.initBounds(e, opts)

    -- 3. Define applyTheme method
    function e:applyTheme()
        local o = self.opts or {}
        self.bg = UI.resolveOptColor(o.bg, "surface", colors.gray)
        self.fg = UI.resolveOptColor(o.fg, "text", colors.white)
    end

    -- 4. Apply theme initially
    e:applyTheme()

    -- 5. Attach framework APIs
    UI._attachSubscriptionAPI(e)   -- Adds subscribeEvent/unsubscribeEvent
    UI._attachFocusAPI(e)          -- Adds requestFocus/releaseFocus
    UI._attachHookAPI(e)           -- Wraps event handlers

    -- 6. Call init callback if provided
    if opts.init then opts.init(e) end

    -- 7. Add to scene
    UI.addElement(opts.scene or UI.activeScene, e)

    return e
end

-- Usage
local custom = UI.customElement({
    customData = "Hello",
    position = "center",
    bg = colors.blue,
    onClick = function(self)
        self.customData = "Clicked!"
    end,
    init = function(self)
        self:subscribeEvent("timer", function(self, ev, id)
            print("Timer event")
        end)
    end
})
```

**What you get:**
- ✅ Automatic positioning (x, y, position, xOffset, yOffset, xPercent, yPercent)
- ✅ Visibility control (UI.show, UI.hide, UI.isVisible)
- ✅ Theme integration (applyTheme called on theme changes)
- ✅ Event subscriptions (subscribeEvent, unsubscribeEvent)
- ✅ Focus management (requestFocus, releaseFocus, focusable flag)
- ✅ Event handlers (onClick, onPress, onRelease, onDrag, onChar, onKey, etc.)
- ✅ Parent/child support (can be added to containers)
- ✅ Scene management (added to active scene automatically)
- ✅ Init callback (for custom initialization)

---

#### Element with Update Loop

For animated or stateful elements, add an `update()` method:

```lua
function UI.animatedElement(opts)
    opts = opts or {}

    local e = {
        type = "animated",
        opts = opts,
        frame = 0,

        update = function(self, dt)
            -- dt = delta time since last frame
            self.frame = (self.frame + dt * 10) % 360
            -- Return true to mark dirty (trigger re-render)
            return true
        end,

        draw = function(self)
            if not UI.isVisible(self) then return end

            local char = self.frame < 180 and "O" or "X"
            UI.term.setCursorPos(self.x, self.y)
            UI.term.write(char)
        end
    }

    UI.initBounds(e, opts)

    function e:applyTheme()
        self.fg = UI.resolveOptColor(opts.fg, "text", colors.white)
        self.bg = UI.resolveOptColor(opts.bg, "background", colors.black)
    end
    e:applyTheme()

    UI._attachSubscriptionAPI(e)
    UI._attachFocusAPI(e)
    UI._attachHookAPI(e)

    if opts.init then opts.init(e) end

    UI.addElement(opts.scene or UI.activeScene, e)

    return e
end
```

**Update Method Contract:**
- Called every frame with `dt` (delta time in seconds)
- Return `true` or non-false to mark UI dirty (trigger re-render)
- Return `false` or nil to skip re-render (optimization for static frames)

---

#### Container Elements

To create a custom container that holds children:

```lua
function UI.customContainer(opts)
    opts = opts or {}

    local e = {
        type = "customContainer",
        opts = opts,
        children = {},

        addChild = function(self, child)
            table.insert(self.children, child)
            child._parent = self
            self:layout()
            UI.markDirty()
        end,

        removeChild = function(self, child)
            for i, c in ipairs(self.children) do
                if c == child then
                    table.remove(self.children, i)
                    child._parent = nil
                    self:layout()
                    UI.markDirty()
                    break
                end
            end
        end,

        layout = function(self)
            -- Position children relative to this container
            for i, child in ipairs(self.children) do
                UI.applyChildPositioning(self, child)
            end
        end,

        draw = function(self)
            if not UI.isVisible(self) then return end

            -- Draw container background
            UI.term.setBackgroundColor(self.bg)
            for dy = 0, self.height - 1 do
                UI.term.setCursorPos(self.x, self.y + dy)
                UI.term.write(string.rep(" ", self.width))
            end

            -- Layout and draw children
            self:layout()
            for _, child in ipairs(self.children) do
                if UI.isVisible(child) and child.draw then
                    child:draw()
                end
            end
        end
    }

    UI.initBounds(e, opts)

    function e:applyTheme()
        self.bg = UI.resolveOptColor(opts.bg, "surface", colors.gray)
    end
    e:applyTheme()

    UI._attachSubscriptionAPI(e)
    UI._attachFocusAPI(e)
    UI._attachHookAPI(e)

    -- Builder pattern support
    if opts.builder then
        local prevParent = UI._layoutParent
        local prevBuilding = UI._buildingLayout

        UI._buildingLayout = true
        UI._layoutParent = e

        opts.builder(e)

        UI._layoutParent = prevParent
        UI._buildingLayout = prevBuilding

        e:layout()
    end

    if opts.init then opts.init(e) end

    UI.addElement(opts.scene or UI.activeScene, e)

    return e
end
```

**Container Requirements:**
- `children` array to store child elements
- `addChild()` method that sets `child._parent = self`
- `removeChild()` method that clears `_parent`
- `layout()` method that calls `UI.applyChildPositioning()`
- `draw()` must draw children after drawing container
- Builder pattern support (optional but recommended)

---

### Theme-Aware Custom Elements

When creating custom elements, use `UI.resolveOptColor()` for proper theme integration:

```lua
function UI.themedElement(opts)
    opts = opts or {}

    local e = {
        type = "themed",
        opts = opts,

        draw = function(self)
            if not UI.isVisible(self) then return end

            UI.term.setTextColor(self.fg)
            UI.term.setBackgroundColor(self.bg)
            UI.term.setCursorPos(self.x, self.y)
            UI.term.write("Themed")
        end
    }

    UI.initBounds(e, opts)

    -- applyTheme is called during construction and when theme changes
    function e:applyTheme()
        local o = self.opts or {}

        -- Three-layer resolution:
        -- 1. If opts.bg is a number: use literal color
        -- 2. If opts.bg is a string: look up theme role
        -- 3. If opts.bg is nil: use "surface" role with gray fallback
        self.bg = UI.resolveOptColor(o.bg, "surface", colors.gray)
        self.fg = UI.resolveOptColor(o.fg, "text", colors.white)
        self.accentColor = UI.resolveOptColor(o.accentColor, "interactive", colors.blue)
    end

    e:applyTheme()

    UI._attachSubscriptionAPI(e)
    UI._attachFocusAPI(e)
    UI._attachHookAPI(e)

    if opts.init then opts.init(e) end

    UI.addElement(opts.scene or UI.activeScene, e)

    return e
end

-- Usage examples:
UI.themedElement({})                           -- Uses theme defaults
UI.themedElement({ bg = "danger" })            -- Uses theme's danger role
UI.themedElement({ bg = colors.red })          -- Literal color (bypasses theme)
```

### Conditional Palette Remapping

Only remap specific colors:

```lua
ui.registerTheme("partialRemap", {
    roles = {
        background = colors.black,
        text = colors.white,
        interactive = colors.blue,
        -- ... standard roles ...
    },
    palette = {
        -- Only remap blue shades, leave others as CC defaults
        [colors.blue] = 0x5588FF,
        [colors.lightBlue] = 0x88AAFF,
        [colors.cyan] = 0xAADDFF
    }
})
```

### Persistent Theme Settings

Save/load user's theme preference:

```lua
-- Save theme preference
local function saveTheme(themeName)
    local file = fs.open("theme.cfg", "w")
    file.write(themeName)
    file.close()
end

-- Load theme preference
local function loadTheme()
    if fs.exists("theme.cfg") then
        local file = fs.open("theme.cfg", "r")
        local themeName = file.readAll()
        file.close()

        -- Validate theme exists
        if ui.contextTable.themes[themeName] then
            ui.setTheme(themeName)
        else
            ui.setTheme("default")
        end
    else
        ui.setTheme("default")
    end
end

-- Usage
loadTheme()  -- On app startup

-- When user changes theme
ui.setTheme("catppuccin")
saveTheme("catppuccin")
```

### Theme-Based Component Variants

Create element variations based on roles:

```lua
-- Success button (green)
ui.button({
    text = "Confirm",
    bg = UI.resolveColor("success", colors.green),
    colorPressed = UI.theme.lighten(UI.resolveColor("success", colors.green))
})

-- Error button (red)
ui.button({
    text = "Delete",
    bg = UI.resolveColor("error", colors.red),
    colorPressed = UI.theme.lighten(UI.resolveColor("error", colors.red))
})

-- Warning button (yellow)
ui.button({
    text = "Caution",
    bg = UI.resolveColor("warning", colors.yellow),
    fg = colors.black  -- Dark text for yellow background
})
```

### Nested Theme Paths (Custom Theming)

Create deeply nested theme structures for complex apps:

```lua
ui.registerTheme("dashboard", {
    roles = { /* standard roles */ },

    -- Custom nested theme paths
    dashboard = {
        cpu = {
            bar = {
                fillColor = colors.red,
                bgColor = colors.gray
            },
            label = {
                fg = colors.white,
                bg = colors.black
            }
        },
        memory = {
            bar = {
                fillColor = colors.blue,
                bgColor = colors.gray
            }
        }
    }
})

-- Use in elements (if element supports theme parameter)
ui.progressbar({
    progress = cpuUsage,
    theme = "dashboard.cpu.bar"  -- Uses nested theme colors
})
```

---

## Examples

### Example 1: Basic Theme Usage

```lua
local ui = dofile("UI.lua")
local context = {
    term = term.current(),
    elements = {},
    dirty = true
}

ui.init(context)

-- Load built-in themes
dofile("themes.lua")(ui)

-- Activate Catppuccin theme
ui.setTheme("catppuccin")

-- Create UI elements
ui.label({
    text = "Welcome to My App",
    position = "top-center",
    -- Automatically uses theme.roles.text for fg
})

ui.button({
    text = "Click Me",
    position = "center",
    onClick = function()
        print("Button clicked!")
    end
    -- Automatically uses theme.roles.interactive for bg
})

ui.button({
    text = "Exit",
    position = "bottom-center",
    bg = UI.resolveColor("error", colors.red),  -- Red exit button
    onClick = function()
        ui.cleanup()
        os.shutdown()
    end
})

ui.run()
```

### Example 2: Custom Ocean Theme

```lua
local ui = dofile("UI.lua")
ui.init(context)

-- Register custom ocean theme
ui.registerTheme("ocean", {
    roles = {
        background = colors.black,
        text = colors.white,
        textDim = colors.lightGray,
        surface = colors.gray,
        border = colors.blue,
        interactive = colors.cyan,
        interactiveHover = colors.lightBlue,
        interactiveActive = colors.blue,
        interactiveDisabled = colors.gray,
        success = colors.lime,
        error = colors.red,
        warning = colors.yellow,
        info = colors.lightBlue,
        selection = colors.cyan
    },
    palette = {
        [colors.black] = 0x001F3F,      -- Navy
        [colors.gray] = 0x003D5C,       -- Dark blue-gray
        [colors.white] = 0xE0F4FF,      -- Light cyan
        [colors.lightGray] = 0x7FCDFF,  -- Sky blue
        [colors.blue] = 0x0074D9,       -- Blue
        [colors.lightBlue] = 0x39CCCC,  -- Teal
        [colors.cyan] = 0x7FDBFF,       -- Aqua
        [colors.lime] = 0x2ECC40,       -- Green
        [colors.green] = 0x01A049,      -- Dark green
        [colors.red] = 0xFF4136,        -- Red
        [colors.orange] = 0xFF851B,     -- Orange
        [colors.yellow] = 0xFFDC00,     -- Yellow
        [colors.purple] = 0xB10DC9,     -- Purple
        [colors.magenta] = 0xF012BE,    -- Magenta
        [colors.pink] = 0xFF69B4,       -- Pink
        [colors.brown] = 0x663300       -- Brown
    }
})

ui.setTheme("ocean")

-- Create ocean-themed dashboard
ui.label({
    text = "Ocean Dashboard",
    position = "top-center"
})

ui.progressbar({
    label = "Water Level",
    progress = 0.75,
    position = { x = 3, y = 5 }
})

ui.button({
    text = "Dive",
    position = "center",
    onClick = function() print("Diving!") end
})

ui.run()
```

### Example 3: Theme Switcher

```lua
local ui = dofile("UI.lua")
ui.init(context)
dofile("themes.lua")(ui)

-- Start with default theme
ui.setTheme("default")

-- Theme selector
local themes = {
    "default", "catppuccin", "gruvbox", "nord",
    "dracula", "tokyonight", "onedark", "monokai"
}
local currentTheme = 1

-- Title
ui.label({
    text = "Theme Selector",
    position = "top-center"
})

-- Current theme display
local themeLabel = ui.label({
    text = "Current: default",
    position = { x = "center", y = 5 }
})

-- Previous button
ui.button({
    text = "<",
    position = { x = 10, y = 10 },
    onClick = function()
        currentTheme = currentTheme - 1
        if currentTheme < 1 then currentTheme = #themes end

        ui.setTheme(themes[currentTheme])
        themeLabel.text = "Current: " .. themes[currentTheme]
        ui.markDirty()
    end
})

-- Next button
ui.button({
    text = ">",
    position = { x = 30, y = 10 },
    onClick = function()
        currentTheme = currentTheme + 1
        if currentTheme > #themes then currentTheme = 1 end

        ui.setTheme(themes[currentTheme])
        themeLabel.text = "Current: " .. themes[currentTheme]
        ui.markDirty()
    end
})

-- Sample elements to see theme changes
ui.button({
    text = "Sample Button",
    position = { x = "center", y = 13 }
})

ui.checkbox({
    label = "Sample Checkbox",
    position = { x = "center", y = 15 },
    checked = true
})

ui.progressbar({
    label = "Sample Progress",
    progress = 0.66,
    position = { x = 3, y = 17 }
})

ui.run()
```

### Example 4: Status-Aware Buttons

```lua
local ui = dofile("UI.lua")
ui.init(context)
ui.setTheme("catppuccin")

-- Function to create status button
local function statusButton(text, status, onClick)
    local roleMap = {
        success = "success",
        error = "error",
        warning = "warning",
        info = "info"
    }

    local role = roleMap[status] or "interactive"
    local bg = UI.resolveColor(role, colors.blue)

    return ui.button({
        text = text,
        bg = bg,
        colorPressed = UI.theme.lighten(bg),
        onClick = onClick
    })
end

-- Create status buttons
statusButton("Success Action", "success", function()
    print("Success!")
end).position = { x = 5, y = 5 }

statusButton("Error Action", "error", function()
    print("Error!")
end).position = { x = 5, y = 8 }

statusButton("Warning Action", "warning", function()
    print("Warning!")
end).position = { x = 5, y = 11 }

statusButton("Info Action", "info", function()
    print("Info!")
end).position = { x = 5, y = 14 }

ui.run()
```

### Example 5: Theme-Aware Custom Renderer

```lua
local ui = dofile("UI.lua")
ui.init(context)
ui.setTheme("nord")

-- Custom themed box renderer
local function drawThemedBox(x, y, width, height, title)
    local theme = ui.getCurrentTheme()
    local bg = theme.roles.surface
    local border = theme.roles.border
    local text = theme.roles.text

    -- Draw box background
    term.setBackgroundColor(bg)
    for dy = 0, height - 1 do
        term.setCursorPos(x, y + dy)
        term.write(string.rep(" ", width))
    end

    -- Draw border
    term.setBackgroundColor(border)
    term.setCursorPos(x, y)
    term.write(string.rep(" ", width))
    term.setCursorPos(x, y + height - 1)
    term.write(string.rep(" ", width))

    -- Draw title
    term.setBackgroundColor(border)
    term.setTextColor(text)
    term.setCursorPos(x + 2, y)
    term.write(" " .. title .. " ")
end

-- Usage
drawThemedBox(5, 5, 30, 10, "Custom Box")

-- This box automatically uses theme colors!
```

---

## Best Practices

1. **Always use roles for semantic colors**: Prefer `UI.resolveColor("interactive", fallback)` over hardcoded colors
2. **Provide fallbacks**: Always include fallback colors for when themes aren't available
3. **Complete palettes**: If using palette remapping, remap all 16 colors for consistency
4. **Test themes**: Check your UI with multiple themes to ensure good contrast and readability
5. **Manual overrides for exceptions**: Use direct color values (`bg = colors.red`) when you specifically need a color regardless of theme
6. **Document custom roles**: If extending the role system, document custom roles for other developers

---

## Troubleshooting

### Theme not applying
```lua
-- Ensure theme is registered before setting
ui.registerTheme("myTheme", {...})
ui.setTheme("myTheme")  -- Now works
```

### Colors look wrong
```lua
-- Check if palette is complete (all 16 colors)
local theme = ui.getCurrentTheme()
for color, rgb in pairs(theme.palette) do
    print(color, rgb)
end
```

### Element ignoring theme
```lua
-- Elements may have manual color overrides
ui.button({
    text = "Button",
    bg = colors.red,  -- This overrides theme.roles.interactive
})

-- Remove manual override to use theme
ui.button({
    text = "Button"  -- Now uses theme.roles.interactive
})
```

### Palette not resetting
```lua
-- Manually reset palette to CC defaults
ui.resetPalette()
```

---

## Summary

The UI.lua theme system provides:

- **13 built-in professional themes** ready to use
- **Role-based color system** for semantic theming
- **Palette remapping** to customize ComputerCraft's 16 colors
- **Automatic element theming** with manual override support
- **Easy theme creation** with full control over colors
- **Runtime theme switching** for dynamic UIs
- **Color utilities** (lighten/darken) for hover/pressed states

This enables creating beautiful, consistent, and customizable UIs in ComputerCraft with minimal effort.

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

---

#### `UI.initBounds(element, opts)`

Initializes standard position, size, and visibility properties on an element. Called by all element constructors.

**Parameters:**
- `element` (table) - Element to initialize
- `opts` (table) - Options table from element constructor

**Returns:** The element (for chaining)

**Properties Initialized:**

1. **Position Properties:**
   - `element.x` - X coordinate (from `opts.x` or existing `element.x` or default `1`)
   - `element.y` - Y coordinate (from `opts.y` or existing `element.y` or default `1`)
   - `element.position` - Anchor point (from `opts.position` or existing)
   - `element.xOffset` - X offset (from `opts.xOffset` or existing)
   - `element.yOffset` - Y offset (from `opts.yOffset` or existing)

2. **Size Properties:**
   - `element.width` - Width (precedence: existing → `opts.width` → text length → `0`)
   - `element.height` - Height (precedence: existing → `opts.height` → `1`)

3. **Visibility:**
   - `element.visible` - Visibility flag (from `opts.visible` or existing or default `true`)
   - `element._visible` - Legacy visibility (kept in sync for backwards compatibility)

4. **Focus:**
   - `element.focusable` - Can receive keyboard focus (from `opts.focusable` or existing or default `false`)

**Precedence Rules:**

- **Position/Size**: Constructor-provided values → opts values → defaults
- **Visibility**: `opts.visible` → existing flags → `true`
- **Focusable**: `opts.focusable` → existing value → `false`

**Example (internal use in element constructors):**
```lua
function UI.customElement(opts)
    opts = opts or {}

    local e = {
        type = "custom",
        text = opts.text or "Default",
        -- Don't set x/y/width/height/visible/focusable here
        -- initBounds handles all of these

        draw = function(self)
            -- Draw implementation
        end
    }

    -- Initialize standard properties
    UI.initBounds(e, opts)

    -- Now e.x, e.y, e.width, e.height, e.visible, e.focusable are all set

    return e
end
```

**Why use `initBounds()`:**

1. **Consistency** - All elements have the same positioning/visibility behavior
2. **Less boilerplate** - Don't repeat initialization logic in every constructor
3. **Precedence handling** - Correctly merges opts with existing values
4. **Backwards compatibility** - Syncs `visible` and `_visible` flags
5. **Smart defaults** - Text-based width, reasonable fallbacks

**Common Pattern:**
```lua
function UI.myElement(opts)
    opts = opts or {}

    -- 1. Create element table with type and methods
    local e = {
        type = "myElement",
        opts = opts,
        draw = function(self) end
    }

    -- 2. Initialize bounds BEFORE applyTheme
    UI.initBounds(e, opts)

    -- 3. Define and call applyTheme
    function e:applyTheme()
        -- Theme resolution
    end
    e:applyTheme()

    -- 4. Attach APIs
    UI._attachSubscriptionAPI(e)
    UI._attachFocusAPI(e)
    UI._attachHookAPI(e)

    -- 5. Call init callback
    if opts.init then opts.init(e) end

    -- 6. Add to scene
    UI.addElement(opts.scene or UI.activeScene, e)

    return e
end
```

#### `UI.applyPositioning(element)`

Calculates final x,y coordinates for **root elements** (elements without a parent) based on position settings.

**Parameters:**
- `element` (table) - Root element to position

**Supports:**
- `position` - Anchor point (center, topLeft, etc.)
- `xOffset`, `yOffset` - Offset from anchor
- `xPercent`, `yPercent` - Percentage-based positioning
- `x`, `y` - Absolute coordinates

**Behavior:**
- Only applies to elements without `_parent` (root elements)
- Skips draggable elements that have been dragged (`_hasBeenDragged` flag)
- Calculates position relative to screen dimensions
- Called automatically before rendering each frame

**Example:**
```lua
-- Root element - uses applyPositioning
local button = ui.button({
    text = "Root Button",
    position = "center"  -- Positioned relative to screen
})

-- Called automatically during render:
UI.applyPositioning(button)
-- button.x and button.y now set based on screen center
```

---

#### `UI.applyChildPositioning(parent, child)`

Calculates final x,y coordinates for **child elements** relative to their parent's content area.

**Parameters:**
- `parent` (table) - Parent container element
- `child` (table) - Child element to position

**Behavior:**
- Positions child relative to parent's **content area** (accounting for border and padding)
- Called by parent's `layout()` method automatically
- Supports same positioning modes as root elements (position, xPercent, x, xOffset, etc.)
- Coordinates are relative to parent, not screen

**Content Area Calculation:**
```lua
borderSize = parent.border and 1 or 0
contentX = parent.x + borderSize + (parent.padding or 0)
contentY = parent.y + borderSize + (parent.padding or 0)
contentWidth = parent.width - (2 * (borderSize + (parent.padding or 0)))
contentHeight = parent.height - (2 * (borderSize + (parent.padding or 0)))
```

**Example:**
```lua
-- Parent container
local container = ui.rectangle({
    x = 10,
    y = 5,
    width = 30,
    height = 10,
    border = true,
    padding = 1
})

-- Child element
local child = ui.button({
    text = "Child",
    position = "center",  -- Centered in parent's content area
    parent = container
})

-- Called automatically by container:layout():
UI.applyChildPositioning(container, child)
-- child.x = container.x + 1 (border) + 1 (padding) + (center offset)
-- child.y = container.y + 1 (border) + 1 (padding) + (center offset)
```

**Difference from `applyPositioning()`:**

| Feature | `applyPositioning()` | `applyChildPositioning()` |
|---------|---------------------|---------------------------|
| Target | Root elements (no parent) | Child elements (has parent) |
| Relative to | Screen dimensions | Parent content area |
| Called by | Render loop | Parent's `layout()` method |
| Accounts for | Screen size | Parent border + padding |

---

### Visibility Control

#### `UI.isVisible(element)`

Checks if an element is visible.

**Parameters:**
- `element` (table) - Element to check

**Returns:** Boolean (`true` if visible, `false` if hidden or nil)

**Behavior:**
- Returns `false` if element is `nil`
- Returns `false` if `element.visible == false`
- Returns `false` if `element._visible == false` (legacy compatibility)
- Otherwise returns `true` (default visibility is `true`)

**Example:**
```lua
if UI.isVisible(myButton) then
    print("Button is visible")
end

-- Common pattern: conditional rendering
if UI.isVisible(container) and container.draw then
    container:draw()
end
```

**Note:** Both `visible` and `_visible` flags are kept in sync for backwards compatibility.

---

#### `UI.show(element)`

Makes an element visible.

**Parameters:**
- `element` (table) - Element to show

**Behavior:**
- Sets `element.visible = true`
- Sets `element._visible = true` (legacy compatibility)
- Calls `UI.markDirty()` to trigger re-render

**Example:**
```lua
-- Initially hidden dialog
local dialog = ui.dialog({
    title = "Warning",
    message = "Are you sure?",
    visible = false
})

-- Show when needed
ui.button({
    text = "Show Dialog",
    onClick = function()
        UI.show(dialog)
    end
})
```

---

#### `UI.hide(element)`

Hides an element from view.

**Parameters:**
- `element` (table) - Element to hide

**Behavior:**
- Sets `element.visible = false`
- Sets `element._visible = false` (legacy compatibility)
- Calls `UI.markDirty()` to trigger re-render

**Example:**
```lua
-- Hide element after timeout
ui.button({
    text = "Temporary Message",
    onClick = function(self)
        ui.label({ text = "Processing...", id = "status" })
        -- Hide after 3 seconds
        setTimeout(function()
            local statusLabel = findElementById("status")
            if statusLabel then
                UI.hide(statusLabel)
            end
        end, 3)
    end
})
```

**Visibility Propagation:**

Visibility affects multiple systems:

1. **Rendering**: Hidden elements are not drawn
   ```lua
   -- In render loop
   if UI.isVisible(e) and e.draw then
       e:draw()
   end
   ```

2. **Hit-Testing**: Hidden elements don't receive pointer events
   ```lua
   -- Click events skip hidden elements
   if not UI.isVisible(element) then return nil end
   ```

3. **Event Subscriptions**: Hidden elements don't receive broadcasted events
   ```lua
   -- Subscription events only fire for visible elements
   if UI.isVisible(element) then
       -- dispatch event
   end
   ```

4. **Container Children**: Containers check their own visibility before drawing children
   ```lua
   function container:draw()
       if not UI.isVisible(self) then return end
       for _, child in ipairs(self.children) do
           if UI.isVisible(child) then
               child:draw()
           end
       end
   end
   ```

**Note:** Child elements maintain their own visibility flags independently. Hiding a parent container prevents its children from being drawn, but doesn't automatically set their `visible` flags to `false`.

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

**Unified text input component** that automatically handles both single-line and multi-line editing based on the `height` parameter.

**Mode Detection:**
- `height = 1` (or unspecified) → **Single-line mode** with horizontal scrolling
- `height > 1` → **Multi-line mode** with vertical scrolling

**Single-Line Options:**
```lua
local field = ui.textfield({
    text = "",                      -- Initial text (default: "")
    width = 20,                     -- Width in characters (default: 20)
    height = 1,                     -- Single-line mode (default: 1)
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

**Multi-Line Options:**
```lua
local editor = ui.textfield({
    text = "Line 1\nLine 2\nLine 3", -- Initial text with newlines
    width = 40,
    height = 10,                     -- Multi-line mode (height > 1)
    position = "center",
    fg = colors.white,
    bg = colors.black,

    onChange = function(text)
        print("Content changed: " .. #text .. " characters")
    end
})
```

**Single-Line Features:**
- **Click to Position Cursor**: Click anywhere in the field to position cursor at that location
- **Horizontal Scrolling**: Long text scrolls automatically as you type
  - Shows `<` indicator when text extends to the left
  - Shows `>` indicator when text extends to the right
  - Keeps cursor visible as you navigate
- **Placeholder Text**: Shows gray text when field is empty
- **Blinking Cursor**: CC cursor positioned at end of render when focused
- **Full Keyboard Support**:
  - Type to add characters at cursor position
  - Backspace to delete character before cursor
  - Left/Right arrows to move cursor
  - Home key to jump to start
  - End key to jump to end
- **onChange Callback**: Notified when text changes

**Multi-Line Features:**
- **Click to Position Cursor**: Click anywhere to position cursor (row and column)
- **Vertical Scrolling**: Automatically scrolls as you edit beyond visible area
- **Line Wrapping**: Text wraps at field boundaries
- **Navigation**:
  - Arrow keys to move cursor
  - Enter creates new lines
  - Backspace handles line merging
  - Home/End for line start/end
- **CC Cursor**: Uses authentic CraftOS cursor for editing

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
- For multi-line text editing, use `ui.textfield()` with `height > 1`
- Text scrolling is automatic - no user action required
- Cursor always stays visible by adjusting viewOffset as needed
- Uses CC cursor positioned at end of render when focused

---

### Text Area (DEPRECATED - Use ui.textfield with height > 1)

⚠️ **DEPRECATED:** This element has been removed. Use `ui.textfield({height = 10})` instead for multi-line editing.

The unified `ui.textfield()` component now handles both single-line and multi-line editing automatically based on the `height` parameter.

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

Filled rectangular background with support for borders, children, and dragging.

**Options:**
```lua
ui.rectangle({
    width = 30,
    height = 10,
    position = "center",
    bg = colors.gray,
    border = true,             -- Show border (default: false)
    borderColor = colors.lightGray,
    draggable = true,          -- Enable drag support (default: false)

    -- Container support: add children declaratively
    builder = function(container)
        container:addChild(ui.label({ text = "Inside!", xOffset = 2, yOffset = 1 }))
        container:addChild(ui.button({
            text = "Click",
            xOffset = 2,
            yOffset = 3,
            onclick = function() print("Clicked!") end
        }))
    end
})
```

**Container Features:**
- Children are positioned relative to the rectangle using `xOffset` and `yOffset`
- Children automatically inherit the rectangle's background color (unless explicitly set)
- Children are drawn on top of the rectangle
- Dragging the rectangle moves all children with it

**Methods:**
- `rect:addChild(element)` - Add a child element
- `rect:removeChild(element)` - Remove a child element
- `rect:clearChildren()` - Remove all children

**Drag Support:**
When `draggable = true`, users can click and drag the rectangle (and its children) around the screen.

See [Container System](#container-system) for more details on using rectangles as containers.

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
Layouts calculate positions dynamically during `draw()`, making it efficient to move parent containers and have all children follow automatically.

---

## Container System

The container system provides a unified API for managing child elements across all container types (Rectangle, VStack, HStack, Grid).

### Overview

All containers support:
- **Children array** - Store child elements
- **addChild/removeChild** - Dynamic child management
- **Builder pattern** - Declarative UI construction
- **Background inheritance** - Children inherit parent background color
- **Click delegation** - Parent forwards clicks to children
- **Draw delegation** - Parent draws children

### Container Types

1. **Rectangle** - Visual container with background, border, optional dragging
2. **VStack** - Layout container (vertical arrangement)
3. **HStack** - Layout container (horizontal arrangement)
4. **Grid** - Layout container (grid arrangement)

### Common Container API

All containers share these methods:

```lua
-- Add a child element
container:addChild(element)

-- Remove a child element
container:removeChild(element)

-- Remove all children (Rectangle and some containers)
container:clearChildren()
```

### Using Containers

#### Rectangle as Container

```lua
local dialog = ui.rectangle({
    x = 10, y = 5,
    width = 30,
    height = 12,
    bg = colors.gray,
    border = true,
    draggable = true,

    builder = function(container)
        -- Title
        container:addChild(ui.label({
            text = "Dialog Box",
            xOffset = 10,
            yOffset = 1,
            fg = colors.white
        }))

        -- Buttons
        container:addChild(ui.button({
            text = "OK",
            xOffset = 5,
            yOffset = 8,
            width = 8,
            onclick = function() print("OK") end
        }))
    end
})
```

**Key Features:**
- Children use `xOffset` and `yOffset` for relative positioning
- Children inherit parent's background color automatically
- Dragging moves entire container with all children
- Click handling checks children before parent

#### Layout Containers

```lua
local panel = ui.rectangle({
    width = 40, height = 15,
    bg = colors.gray,
    border = true,

    builder = function(container)
        -- Nest an hstack inside the rectangle
        local buttonRow = ui.hstack({
            xOffset = 2,
            yOffset = 10,
            spacing = 1,
            builder = function(stack)
                stack:addChild(ui.button({ text = "Save", bg = colors.green }))
                stack:addChild(ui.button({ text = "Cancel", bg = colors.red }))
                stack:addChild(ui.button({ text = "Help", bg = colors.blue }))
            end
        })
        container:addChild(buttonRow)
    end
})
```

### Adding Children: Three Methods

There are three ways to attach children to containers:

#### 1. Using `opts.parent` Parameter

Pass `parent` option during element construction to automatically attach to a container:

```lua
-- Create container first
local container = ui.rectangle({
    width = 30,
    height = 10,
    bg = colors.gray
})

-- Add children using parent parameter
local label = ui.label({
    text = "I'm a child",
    parent = container,  -- Automatically attached
    xOffset = 2,
    yOffset = 2
})

local button = ui.button({
    text = "Click Me",
    parent = container,  -- Also attached
    xOffset = 2,
    yOffset = 4
})
```

**Behavior:**
- Calls `container:addChild(element)` if the container has an `addChild` method
- Falls back to manual attachment (`element._parent = container`)
- Automatically calls `container:layout()` if available
- Element is added to the container, not the scene

**When to use:** Imperative UI construction, dynamic child addition, programmatic UI generation

---

#### 2. Using `container:addChild()` Method

Manually call `addChild()` after element creation:

```lua
local container = ui.rectangle({ width = 30, height = 10 })

-- Create elements first
local label = ui.label({ text = "Label" })
local button = ui.button({ text = "Button" })

-- Add to container manually
container:addChild(label)
container:addChild(button)
```

**Behavior:**
- Sets `element._parent = container`
- Calls `container:layout()` to recalculate positions
- Calls `UI.markDirty()` to trigger re-render

**When to use:** Same as `opts.parent`, just different syntax preference

---

#### 3. Using `builder` Function (Recommended)

Use the declarative builder pattern for cleaner code:

```lua
ui.rectangle({
    width = 30,
    height = 10,
    builder = function(container)
        -- Elements created here are auto-attached
        ui.label({ text = "Auto-attached" })
        ui.button({ text = "Me too!" })
    end
})
```

**How it works:**
1. Framework sets `UI._buildingLayout = true`
2. Stores current container in `UI._layoutParent`
3. Calls `opts.builder(container)`
4. Any elements created inside builder are automatically attached to `UI._layoutParent`
5. Restores previous state
6. Calls `container:layout()` once after all children added

**Benefits:**
- Cleaner, more readable code
- No need to explicitly call `addChild()` or pass `parent` parameter
- All children added before layout calculation (more efficient)
- Single render pass (no flicker)

**When to use:** Preferred method for static container hierarchies

---

### Element Initialization: `opts.init` Callback

All element constructors support an `init` callback for custom initialization logic:

```lua
local element = ui.button({
    text = "Button",

    init = function(self)
        -- Called after element is fully constructed
        -- but before it's added to the scene

        -- Subscribe to events
        self:subscribeEvent("timer", function(self, eventName, timerId)
            self.text = "Timer " .. timerId
        end)

        -- Set up custom state
        self._clickCount = 0
        self._lastClickTime = 0

        -- Store references
        self._relatedElements = {}
    end,

    onClick = function(self)
        self._clickCount = self._clickCount + 1
    end
})
```

**Initialization Order:**

Element construction happens in this order:

1. Element table created with type, properties, methods
2. `UI.initBounds(e, opts)` sets x/y/width/height/visible/focusable
3. `e:applyTheme()` applies theme colors
4. `UI._attachSubscriptionAPI(e)` adds `subscribeEvent()` method
5. `UI._attachFocusAPI(e)` adds focus methods
6. `UI._attachHookAPI(e)` wraps event handlers
7. **`opts.init(e)` called** ← Your custom initialization here
8. `UI.addElement(opts.scene, e)` adds to scene

**Use Cases:**

- **Event subscriptions**: Subscribe to custom events or CC events
- **State initialization**: Set up private state variables
- **References**: Store references to related elements
- **Computed properties**: Calculate derived values from opts
- **Validation**: Validate options before element is used

**Example - Complex Initialization:**

```lua
local dashboard = ui.rectangle({
    width = 40,
    height = 20,

    init = function(self)
        -- Set up refresh timer
        self._timerId = os.startTimer(1)
        self:subscribeEvent("timer", function(self, eventName, id)
            if id == self._timerId then
                self:refreshData()
                self._timerId = os.startTimer(1)  -- Reset timer
            end
        end)

        -- Initialize data
        self._data = {}
        self:refreshData()
    end,

    refreshData = function(self)
        -- Custom method to fetch data
        self._data = fetchDashboardData()
        UI.markDirty()
    end,

    onDestroy = function(self)
        -- Clean up timer
        os.cancelTimer(self._timerId)
    end
})
```

**Note:** The `init` callback is called **after** theme application and API attachment, so you have access to `self:subscribeEvent()`, `self:requestFocus()`, and other methods.

---

### Background Inheritance

Children automatically inherit their parent's background color unless explicitly overridden:

```lua
ui.rectangle({
    bg = colors.blue,  -- Parent background
    builder = function(container)
        -- This label will have blue background (inherited)
        container:addChild(ui.label({ text = "Blue BG" }))

        -- This label will have red background (explicit)
        container:addChild(ui.label({ text = "Red BG", bg = colors.red }))
    end
})
```

### Dynamic Child Management

Add and remove children at runtime:

```lua
local container = ui.rectangle({ width = 20, height = 10, bg = colors.gray })

-- Add children dynamically
local label1 = ui.label({ text = "Child 1", xOffset = 2, yOffset = 2 })
container:addChild(label1)

-- Remove child later
container:removeChild(label1)

-- Clear all children
container:clearChildren()
```

### Nested Containers

Containers can be nested arbitrarily deep:

```lua
ui.rectangle({  -- Level 1: Visual container
    builder = function(rect)
        rect:addChild(ui.vstack({  -- Level 2: Layout container
            builder = function(vstack)
                vstack:addChild(ui.hstack({  -- Level 3: Layout container
                    builder = function(hstack)
                        -- Level 4: UI elements
                        hstack:addChild(ui.button({ text = "A" }))
                        hstack:addChild(ui.button({ text = "B" }))
                    end
                }))
            end
        }))
    end
})
```

Click events properly propagate through all levels.

---

## Dialog & Modal System

The dialog system provides easy-to-use modal dialogs for user interaction.

### Overview

Four dialog types available:
- **UI.alert()** - Simple message with OK button
- **UI.confirm()** - Yes/No question dialog
- **UI.prompt()** - Text input dialog
- **UI.dialog()** - Custom dialog with any buttons/content

All dialogs:
- Display as modal overlays (dim background)
- Block interaction with content behind them
- Support click-outside-to-close (configurable)
- Automatically center on screen
- Support theme colors

### UI.alert()

Simple alert message:

```lua
ui.alert("Operation completed successfully!", "Success", function()
    print("User dismissed alert")
end)
```

**Parameters:**
- `message` (string) - The alert message
- `title` (string, optional) - Dialog title (default: "Alert")
- `callback` (function, optional) - Called when dismissed

### UI.confirm()

Yes/No confirmation dialog:

```lua
ui.confirm("Are you sure you want to delete this file?", "Confirm Delete", function(yes)
    if yes then
        print("User confirmed deletion")
    else
        print("User cancelled")
    end
end)
```

**Parameters:**
- `message` (string) - The confirmation question
- `title` (string, optional) - Dialog title (default: "Confirm")
- `callback` (function, optional) - Called with boolean result (true = Yes, false = No)

### UI.prompt()

Text input dialog:

```lua
ui.prompt("Enter your name:", "John Doe", "User Input", function(text)
    if text then
        print("User entered: " .. text)
    else
        print("User cancelled")
    end
end)
```

**Parameters:**
- `message` (string) - The input prompt
- `defaultValue` (string, optional) - Initial text value
- `title` (string, optional) - Dialog title (default: "Input")
- `callback` (function, optional) - Called with string result (nil = cancelled)

### UI.dialog()

Custom dialog with full control:

```lua
local dialog = ui.dialog({
    title = "Choose Action",
    content = "What would you like to do?",
    width = 35,
    height = 12,

    buttons = {
        {
            text = "Save",
            bg = colors.lime,
            onClick = function(dialog)
                print("Save clicked")
                -- Dialog auto-closes
            end
        },
        {
            text = "Discard",
            bg = colors.red,
            onClick = function(dialog)
                print("Discard clicked")
            end
        },
        {
            text = "Cancel",
            bg = colors.gray,
            onClick = function(dialog)
                print("Cancelled")
            end
        }
    },

    closeOnOverlay = true,   -- Click outside to close (default: true)
    showCloseButton = true   -- Show X button in corner (default: false)
})
```

**Options:**
- `title` (string) - Dialog title
- `content` (string) - Message text (auto-wraps)
- `width` (number, optional) - Dialog width (default: 30)
- `height` (number, optional) - Dialog height (default: 10)
- `buttons` (table) - Array of button definitions
  - `text` (string) - Button label
  - `bg` (color) - Button background color
  - `onClick` (function) - Click handler, receives dialog object
- `closeOnOverlay` (boolean) - Close when clicking outside (default: true)
- `showCloseButton` (boolean) - Show X button (default: false)
- `bg`, `fg`, `titleBg` - Color overrides (uses theme by default)
- `overlayColor` - Overlay background (default: colors.black)

### Dialog Patterns

#### Confirmation Before Action

```lua
ui.button({
    text = "Delete All",
    bg = colors.red,
    onclick = function()
        ui.confirm("Delete all files? This cannot be undone!", "Warning", function(yes)
            if yes then
                deleteAllFiles()
                ui.alert("All files deleted", "Complete")
            end
        end)
    end
})
```

#### Multi-Step Dialog

```lua
ui.button({
    text = "Setup",
    onclick = function()
        ui.prompt("Enter server name:", "", "Setup (1/2)", function(name)
            if name then
                ui.prompt("Enter server IP:", "192.168.1.1", "Setup (2/2)", function(ip)
                    if ip then
                        ui.alert("Server configured: " .. name .. " at " .. ip, "Complete")
                    end
                end)
            end
        end)
    end
})
```

#### Custom Form Dialog

```lua
local nameField, emailField

ui.dialog({
    title = "Register",
    content = "Fill in your details:",
    width = 40,
    height = 15,

    buttons = {
        {
            text = "Submit",
            bg = colors.green,
            onClick = function(dialog)
                local name = nameField:getText()
                local email = emailField:getText()
                print("Submitted: " .. name .. ", " .. email)
            end
        }
    }

    -- Note: For complex forms, consider building custom dialogs
    -- with ui.rectangle + nested layout containers
})
```

### Dialog Lifecycle

Dialogs are automatically:
1. **Created** - Added to active scene as overlay
2. **Displayed** - Rendered on top of existing UI
3. **Closed** - Removed when button clicked or overlay clicked
4. **Cleaned up** - All resources freed

You don't need to manually manage dialog elements.

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

The UI framework provides three positioning modes for flexible element placement.

#### 1. Absolute Positioning

Position elements using exact coordinates.

**Properties:**
- `x` (number) - X coordinate (default: 1)
- `y` (number) - Y coordinate (default: 1)
- `xOffset` (number) - Additional X offset applied after positioning
- `yOffset` (number) - Additional Y offset applied after positioning

**Example:**
```lua
-- Place button at exact coordinates
ui.button({
    text = "Fixed Button",
    x = 10,
    y = 5
})

-- With additional offset
ui.label({
    text = "Label",
    x = 10,
    y = 5,
    xOffset = 2,  -- Final x = 12
    yOffset = 1   -- Final y = 6
})
```

**Note:** Absolute positioning is applied **before** percentage and anchor-based positioning in the calculation order.

---

#### 2. Percentage-Based Positioning

Position elements as a fraction of screen/parent dimensions.

**Properties:**
- `xPercent` (number) - X position as fraction (0.0 to 1.0)
- `yPercent` (number) - Y position as fraction (0.0 to 1.0)

**Calculation:**
- `finalX = xPercent * screenWidth`
- `finalY = yPercent * screenHeight`

**Example:**
```lua
-- Center at 50% horizontally, 25% vertically
ui.button({
    text = "Centered Top",
    xPercent = 0.5,
    yPercent = 0.25
})

-- Position at 75% from left, 90% from top
ui.label({
    text = "Bottom Right Area",
    xPercent = 0.75,
    yPercent = 0.9
})

-- With offset adjustment
ui.button({
    text = "Adjusted",
    xPercent = 0.5,
    yPercent = 0.5,
    xOffset = -5,  -- Shift left 5 chars
    yOffset = 2    -- Shift down 2 lines
})
```

**Use Cases:**
- Responsive layouts that adapt to different screen sizes
- Relative positioning without hardcoded coordinates
- Combining percentage base with pixel-perfect offset adjustments

---

#### 3. Anchor-Based Positioning

Position elements using named anchor points.

**Property:**
- `position` (string) - Named anchor point

**Available Anchors:**
- `"center"` - Center of screen/parent
- `"topLeft"`, `"topCenter"`, `"topRight"` - Top edge positions
- `"left"`, `"leftCenter"`, `"centerLeft"` (aliases) - Left middle
- `"right"`, `"rightCenter"`, `"centerRight"` (aliases) - Right middle
- `"bottomLeft"`, `"bottomCenter"`, `"bottomRight"` - Bottom edge positions

**Example:**
```lua
-- Center button
ui.button({
    text = "Centered",
    position = "center"
})

-- Top right corner with offset
ui.button({
    text = "Top Right Button",
    position = "topRight",
    xOffset = -2,  -- 2 chars from right edge
    yOffset = 1    -- 1 line from top
})

-- Bottom center
ui.label({
    text = "Status Bar",
    position = "bottomCenter",
    yOffset = -1  -- One line up from bottom
})
```

**Anchor Calculation:**

Each anchor calculates position based on screen dimensions:

```lua
-- For "center"
x = (screenWidth / 2) - (elementWidth / 2)
y = (screenHeight / 2) - (elementHeight / 2)

-- For "topRight"
x = screenWidth - elementWidth
y = 1

-- For "bottomCenter"
x = (screenWidth / 2) - (elementWidth / 2)
y = screenHeight - elementHeight
```

---

#### Positioning Precedence

When multiple positioning properties are set, they are applied in this order:

1. **Base position** - Starts with `x`, `y` (or default 1, 1)
2. **Percentage** - If `xPercent` or `yPercent` set, overrides base
3. **Anchor** - If `position` set, overrides percentage
4. **Offset** - `xOffset`, `yOffset` added last (never overridden)

**Example - Multiple properties:**
```lua
ui.button({
    text = "Complex",
    x = 10,            -- [1] Base: x=10, y=5
    y = 5,
    xPercent = 0.5,    -- [2] Overrides: x=50% of screen
    position = "center", -- [3] Overrides: x,y=center
    xOffset = -3,      -- [4] Final adjustment: x-=3, y+=2
    yOffset = 2
})
-- Final position: center + xOffset(-3) + yOffset(2)
```

**Rule of thumb:** Only use **one** positioning mode per element. Mixing modes follows precedence rules but can be confusing.

---

#### Root vs Child Positioning

**Root Elements** (no parent):
- Positioned via `UI.applyPositioning(element)`
- Calculated relative to screen dimensions
- Called automatically before each render

**Child Elements** (inside containers):
- Positioned via `UI.applyChildPositioning(parent, child)`
- Calculated relative to parent's **content area** (accounting for border + padding)
- Called by parent's `layout()` method
- Coordinates are relative to parent, not screen

**Example:**
```lua
-- Root element: positioned relative to screen
ui.button({
    position = "center"  -- Center of screen
})

-- Child element: positioned relative to parent container
ui.rectangle({
    position = "center",
    width = 30,
    height = 10,
    border = true,
    builder = function(rect)
        -- This button is centered within the rectangle's content area
        ui.button({
            position = "center",  -- Center of parent, not screen
            text = "Child Button"
        })
    end
})
```

**Content Area Calculation:**
```lua
contentX = parentX + borderSize + padding
contentY = parentY + borderSize + padding
contentWidth = parentWidth - (2 * (borderSize + padding))
contentHeight = parentHeight - (2 * (borderSize + padding))
```

**Note:** `borderSize` is 1 if `border = true`, otherwise 0.

---

#### Draggable Elements

Elements with `draggable = true` that have been dragged retain their manual position and **skip automatic positioning**.

**Example:**
```lua
ui.rectangle({
    draggable = true,
    position = "center",  -- Initial position only

    onDrag = function(self, x, y, button, dx, dy)
        self.x = self.x + dx
        self.y = self.y + dy
    end
})
-- After user drags, position anchors are ignored
```

**Internal flag:** `element._hasBeenDragged` prevents `applyPositioning()` from overriding manual position.

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

**v3.0** (Current – 2025-11-15)
- Unified pointer event system:
  - `UI.handleEvent(ev, p1, p2, p3, p4)` as the single entry point.
  - Hit-testing and bubbling for nested containers.
  - Pointer lifecycle callbacks: `onPress`, `onRelease`, `onClick`, `onDrag`, `onScroll`.
- Focus model rewrite:
  - `focusable`, `lockFocus`, `UI.setFocus`, `UI.clearFocus`, `element:requestFocus()`.
- Container and hit-testing rework:
  - Parent/child hierarchy with `children` and `_parent`.
  - Deeper-first hit-testing so topmost child receives pointer events.
- Event subscription helpers on elements:
  - `element:subscribeEvent(...)`, `element:unsubscribeEvent(...)`.
- Theme system enhancements:
  - Added `interactiveText` role for text color on interactive elements.
  - Added 3 new light themes: `paper`, `solarized_light`, `gruvbox_light`.
  - Theme documentation and integration updated to match the palette-based theme system.

**v2.1** (2025-10-28)
- Removed legacy `UI.tick()` helper in favor of `UI.run()`.
- Removed the old inlined event handler logic from `UI.run()` in preparation for the standalone `UI.handleEvent` entry point.
- Cleaned up unused / orphaned code paths.
- Updated all examples to the `UI.run()` pattern.

**v2.0**
- Introduced `UI.run()` with a separate render loop and configurable FPS.
- Added dirty-flag rendering and `UI.markDirty()` for efficient redraws.
- Formalized the `update(dt)` pattern for animations and async work.

**v1.x** (Legacy)
- Sequential `ui.tick()`-based loop.
- Basic scene management.
- Initial element set: button, label, checkbox, textfield, terminal.
- Simple focus system and child scene support.

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
---

# Part II: Interactive Inputs (Inputs.lua)

---

# Inputs Module Documentation (Interactive Elements)

Extension module for `UI.lua` that provides interactive input elements with full theme system integration.

**Version:** 1.1
**Last Updated:** November 6, 2025

## Setup

```lua
local ui = dofile("UI.lua")
local inputs = dofile("Inputs.lua")

-- Initialize
ui.init(context)
inputs.init(ui)
```

## Table of Contents

1. [Theme System Integration](#theme-system-integration)
2. [Elements](#elements)
   - [Slider](#slider)
   - [Button Group (Radio Buttons)](#button-group-radio-buttons)
   - [Dropdown Menu](#dropdown-menu)
   - [Advanced Text Field](#advanced-text-field)
   - [Text Area](#text-area) **NEW**
3. [Common Options](#common-options)
4. [Theme Examples](#theme-examples)
5. [Complete Examples](#complete-examples)

---

## Theme System Integration

All input elements support the theme system with the `theme` parameter:

```lua
-- Use semantic theme colors
local slider = inputs.slider({
    value = 50,
    min = 0,
    max = 100,
    theme = "primary",
    position = "center"
})

-- Use element-specific theme defaults
local radioGroup = inputs.buttonGroup({
    options = {"Easy", "Medium", "Hard"},
    theme = "buttonGroup",
    position = "center"
})

-- Manual override still works
local customSlider = inputs.slider({
    value = 75,
    fillColor = colors.lime,  -- Manual override
    position = "center"
})
```

### Color Resolution Priority

All elements follow this priority cascade:

1. **Manual colors** (highest priority) - `fillColor = colors.orange`
2. **Theme parameter** - `theme = "primary"`
3. **Default element theme** - `theme.slider.fillColor`
4. **Hardcoded fallbacks** (lowest priority)

---

## Elements

### Slider

Interactive value selector with horizontal or vertical orientation, drag support, and optional step snapping.

```lua
local slider = inputs.slider({
    value = 50,                   -- Current value (default: 0)
    min = 0,                      -- Minimum value (default: 0)
    max = 100,                    -- Maximum value (default: 100)
    step = 5,                     -- Optional: snap to increments (default: nil)
    orientation = "horizontal",   -- "horizontal" or "vertical" (default: "horizontal")
    width = 20,                   -- Width in characters (default: 20 for horizontal, 3 for vertical)
    height = 1,                   -- Height in rows (default: 1 for horizontal, 10 for vertical)
    showValue = true,             -- Display numeric value (default: true)
    valueFormat = "%.0f",         -- Printf format string (default: "%.0f")
    label = "Volume",             -- Optional label text (default: "")
    position = "center",          -- Anchor position

    -- Theme options:
    theme = "primary",            -- Use semantic color
    -- OR manual colors:
    fg = colors.white,            -- Text color
    bg = colors.gray,             -- Background color
    trackColor = colors.gray,     -- Empty track color
    fillColor = colors.blue,      -- Filled track color
    thumbColor = colors.white,    -- Thumb marker color

    onChange = function(value)    -- Called when value changes
        print("New value: " .. value)
    end
})

-- Update value programmatically
slider:setValue(75)
```

**Theme Properties:**
- `fg` - Text color (label and value)
- `bg` - Background color
- `trackColor` - Unfilled portion of track
- `fillColor` - Filled portion of track
- `thumbColor` - Color of the thumb marker

**Default Theme Values:**
```lua
theme.slider = {
    fg = colors.white,
    bg = colors.gray,
    trackColor = colors.gray,
    fillColor = colors.blue,
    thumbColor = colors.white
}
```

**Behavior:**
- **Click** - Jump to clicked position
- **Drag** - Drag thumb to adjust value continuously
- **Step snapping** - When `step` is set, value snaps to nearest increment
- **Orientation** - Horizontal sliders go left-to-right, vertical sliders go bottom-to-top (inverted Y)
- **Label** - Displayed above horizontal sliders, above vertical sliders
- **Value display** - Shows to the right of horizontal sliders, to the right of vertical thumb position

**Visual Characters:**
- `\7` - Bullet character used as thumb marker
- Filled track uses `fillColor`, empty track uses `trackColor`

---

### Button Group (Radio Buttons)

Mutually exclusive selection from multiple options, with horizontal or vertical layout.

```lua
local radioGroup = inputs.buttonGroup({
    options = {"Easy", "Medium", "Hard"},     -- Array of option labels
    selected = 2,                             -- Initially selected index (default: 1)
    orientation = "horizontal",               -- "horizontal" or "vertical" (default: "horizontal")
    spacing = 2,                              -- Space between buttons (default: 2)
    position = "center",

    -- Theme options:
    theme = "primary",                        -- Use semantic color
    -- OR manual colors:
    fg = colors.white,                        -- Unselected text color
    bg = colors.gray,                         -- Unselected background
    selectedBg = colors.blue,                 -- Selected button background
    selectedFg = colors.white,                -- Selected button text color

    onChange = function(selected, index)     -- Called when selection changes
        print(string.format("Selected: %s (index %d)", selected, index))
    end
})

-- Update selection programmatically
radioGroup:setSelected(3)

-- Alias: radioGroup() is identical to buttonGroup()
local radios = inputs.radioGroup({...})
```

**Theme Properties:**
- `fg` - Unselected button text color
- `bg` - Unselected button background
- `selectedBg` - Selected button background
- `selectedFg` - Selected button text color

**Default Theme Values:**
```lua
theme.buttonGroup = {
    fg = colors.white,
    bg = colors.gray,
    selectedBg = colors.blue,
    selectedFg = colors.white
}
```

**Behavior:**
- **Single selection** - Only one option can be selected at a time
- **Auto-layout** - Buttons are automatically positioned based on orientation and spacing
- **Width calculation** - Horizontal groups calculate total width, vertical groups use max button width
- **Visual indicator** - Selected button shows bullet (`\7`), unselected shows space

**Format:**
- Horizontal: `( ) Option1   ( ) Option2   (●) Option3`
- Vertical: Each option on its own line

**Alias:** `inputs.radioGroup()` is an alias for `inputs.buttonGroup()` for semantic clarity.

---

### Dropdown Menu

Expandable selection list with optional search/filter, scrolling for long lists, and click-outside-to-close behavior.

```lua
local dropdown = inputs.dropdown({
    options = {"Apple", "Banana", "Cherry", "Date", "Elderberry"},
    selected = 1,                             -- Initially selected index (default: nil)
    width = 20,                               -- Width of dropdown (default: 20)
    maxHeight = 8,                            -- Max visible options when expanded (default: 8)
    placeholder = "Select fruit...",          -- Text when nothing selected (default: "Select...")
    searchable = true,                        -- Enable search/filter (default: false)
    position = "center",

    -- Theme options:
    theme = "primary",                        -- Use semantic color
    -- OR manual colors:
    fg = colors.white,                        -- Text color
    bg = colors.gray,                         -- Background color
    selectedBg = colors.blue,                 -- Selected item highlight
    selectedFg = colors.white,                -- Selected item text
    border = colors.lightGray,                -- Border color
    scrollbar = colors.lightGray,             -- Scrollbar indicator color

    onChange = function(selected, index)     -- Called when selection changes
        print(string.format("Selected: %s (index %d)", selected, index))
    end
})

-- Update selection programmatically
dropdown:setSelected(3)

-- Toggle expanded/collapsed state
dropdown:toggle()
```

**Theme Properties:**
- `fg` - Text color
- `bg` - Background color
- `selectedBg` - Highlighted item background
- `selectedFg` - Highlighted item text color
- `border` - Border character color
- `scrollbar` - Scrollbar indicator color

**Default Theme Values:**
```lua
theme.dropdown = {
    fg = colors.white,
    bg = colors.gray,
    selectedBg = colors.blue,
    selectedFg = colors.white,
    border = colors.lightGray,
    scrollbar = colors.lightGray
}
```

**Behavior:**
- **Click header** - Toggles expanded/collapsed state
- **Click option** - Selects option and collapses menu
- **Click outside** - Collapses menu without changing selection
- **Search** - Type to filter options (when `searchable = true`)
- **Scroll** - Mouse wheel scrolls through long lists
- **Visual indicators**:
  - Arrow: `\31` (down) when collapsed, `\30` (up) when expanded
  - Checkmark: `\4` next to currently selected item
  - Border: `\9` characters on left and right edges

**Search Functionality:**
When `searchable = true`:
- Search box appears below header when expanded
- Type to filter options (case-insensitive substring match)
- Backspace to delete search characters
- Filtered results update in real-time
- Search text shows with cursor: `Search: text_`

**Scrolling:**
- Scrollbar appears on right side when options exceed `maxHeight`
- Scrollbar position indicates current scroll offset
- Mouse wheel scrolls up/down through list

**Height Calculation:**
- **Collapsed**: 1 row (header only)
- **Expanded (no search)**: 1 + min(#options, maxHeight)
- **Expanded (with search)**: 1 + 1 + min(#filtered, maxHeight)

---

### Advanced Text Field

Enhanced text input field with optional password masking or CraftOS-style autocomplete suggestions. Uses native CraftOS cursor for authentic feel.

```lua
-- Password field (masked input)
local passwordField = inputs.advancedTextField({
    width = 25,                              -- Width in characters (default: 20)
    placeholder = "Enter password...",       -- Placeholder text when empty (default: "")
    masked = true,                           -- Enable password masking (default: false)
    maskChar = "*",                          -- Character to display instead of text (default: "*")
    position = "center",

    -- Theme options:
    theme = "primary",                       -- Use semantic color
    -- OR manual colors:
    fg = colors.white,                       -- Text color
    bg = colors.gray,                        -- Background color
    placeholderColor = colors.lightGray,     -- Placeholder text color
    borderColor = colors.lightGray,          -- Border color

    onChange = function(text)                -- Called when text changes
        print("Text changed: " .. #text .. " characters")
    end,

    onSubmit = function(text)                -- Called when Enter is pressed
        print("Submitted: " .. text)
    end
})

-- Autocomplete field
local commandField = inputs.advancedTextField({
    width = 30,
    placeholder = "Type a command...",
    autocomplete = {                         -- Array of suggestion strings
        "help", "list", "edit", "delete",
        "copy", "move", "mkdir"
    },
    suggestionColor = colors.gray,           -- Color of gray suggestion text (default: colors.gray)
    position = "center",

    onChange = function(text)
        print("Command: " .. text)
    end,

    onAutocomplete = function(text)          -- Called when Tab accepts suggestion
        print("Autocompleted: " .. text)
    end,

    onSubmit = function(text)
        print("Execute: " .. text)
    end
})

-- Basic text field (no special features)
local basicField = inputs.advancedTextField({
    width = 20,
    placeholder = "Enter text...",
    position = "center",
    onChange = function(text)
        print("Text: " .. text)
    end
})
```

**Options:**
- `width` - Width in characters (default: 20)
- `placeholder` - Placeholder text when field is empty (default: "")
- `text` - Initial text value (default: "")
- `masked` - Enable password masking (default: false)
- `maskChar` - Character to show instead of actual text (default: "*")
- `autocomplete` - Array of suggestion strings (default: nil)
- `suggestionColor` - Color of autocomplete suggestion text (default: colors.gray)

**Callbacks:**
- `onChange(text)` - Called when text changes (any character added/removed)
- `onSubmit(text)` - Called when Enter key is pressed
- `onAutocomplete(text)` - Called when Tab key accepts a suggestion

**Theme Properties:**
- `fg` - Text color
- `bg` - Background color
- `placeholderColor` - Placeholder text color
- `borderColor` - Border character color (`[` and `]`)

**Default Theme Values:**
```lua
theme.advancedTextField = {
    fg = colors.white,
    bg = colors.gray,
    placeholderColor = colors.lightGray,
    borderColor = colors.lightGray
}
```

**Important Constraints:**
- **Mutually Exclusive**: `masked` and `autocomplete` cannot both be enabled
  - If both are set, `masked` takes priority and `autocomplete` is ignored
  - Masked fields cannot show suggestions (security concern)

**CraftOS Cursor Behavior:**
- Uses native CraftOS cursor (`term.setCursorPos()` and `term.setCursorBlink()`)
- Cursor appears at text insertion point when field is focused
- Cursor automatically hides when field loses focus
- Blinking rate controlled by CraftOS (not customizable)

**Autocomplete Features:**
When `autocomplete` array is provided:
- **Suggestion Display**: Gray text appears to the right of cursor showing completion
- **Matching**: Finds first suggestion that starts with current text (case-insensitive)
- **Tab to Accept**: Press Tab key to fill in the suggested completion
- **Visual Style**: CraftOS-style gray suggestion text (like native shell autocomplete)
- **Real-time Updates**: Suggestion updates as you type
- **Exact Match Hiding**: If text exactly matches a suggestion, no gray text shown

**Format:**
```
Basic field:        [text here_           ]
Masked field:       [*********_           ]
With autocomplete:  [hel_p                ]
                         ^^^ gray suggestion
With placeholder:   [Enter text...        ]  (when empty)
```

**Visual Indicators:**
- Border: `[` and `]` characters on left and right edges
- Cursor: Native blinking CraftOS cursor at insertion point
- Suggestion: Gray text extending to the right from cursor
- Placeholder: Light gray text when field is empty and unfocused

**Keyboard Controls:**
- **Type** - Add characters at cursor position
- **Backspace** - Delete character before cursor
- **Delete** - Delete character at cursor (not implemented in basic version)
- **Left/Right Arrow** - Move cursor
- **Home** - Move cursor to start
- **End** - Move cursor to end
- **Tab** - Accept autocomplete suggestion (when available)
- **Enter** - Submit text (calls `onSubmit` callback)

**Mouse Controls:**
- **Click** - Focus field and position cursor near click location

**Example: Login Form**

```lua
local ui = dofile("UI.lua")
local inputs = dofile("Inputs.lua")

ui.init(context)
inputs.init(ui)

ui.newScene("Login")
ui.setScene("Login")

-- Username field with autocomplete (remembered usernames)
ui.label({
    text = "Username:",
    position = "center",
    yOffset = -4
})

local usernameField = inputs.advancedTextField({
    width = 25,
    placeholder = "Enter username...",
    autocomplete = {"admin", "user", "guest", "developer"},
    position = "center",
    yOffset = -3,
    theme = "primary",
    onAutocomplete = function(text)
        print("Selected username: " .. text)
    end
})

-- Password field with masking
ui.label({
    text = "Password:",
    position = "center",
    yOffset = 0
})

local passwordField = inputs.advancedTextField({
    width = 25,
    placeholder = "Enter password...",
    masked = true,
    maskChar = "*",
    position = "center",
    yOffset = 1,
    theme = "primary",
    onChange = function(text)
        -- Could check password strength here
        print("Password length: " .. #text)
    end
})

-- Login button
ui.button({
    text = "Login",
    width = 12,
    bg = colors.green,
    position = "center",
    yOffset = 4,
    onclick = function()
        local username = usernameField.text
        local password = passwordField.text

        if #username == 0 or #password == 0 then
            print("Please fill all fields!")
        else
            print("Logging in as: " .. username)
            -- Password stays masked, never printed
        end
    end
})

ui.run({fps = 30})
```

**Example: Command Shell with Autocomplete**

```lua
local ui = dofile("UI.lua")
local inputs = dofile("Inputs.lua")

ui.init(context)
inputs.init(ui)

ui.newScene("Shell")
ui.setScene("Shell")

-- Title
ui.label({
    text = "Command Shell",
    position = "topCenter",
    yOffset = 1,
    fg = colors.lime
})

-- Command input with CraftOS-style autocomplete
ui.label({
    text = ">",
    position = "left",
    xOffset = 1,
    yOffset = 3,
    fg = colors.white
})

local commandHistory = {}

local commandField = inputs.advancedTextField({
    width = 48,
    placeholder = "Type a command (Tab to complete)...",
    autocomplete = {
        "help", "list", "cd", "edit", "delete", "copy", "move",
        "mkdir", "rm", "cat", "download", "reboot", "shutdown"
    },
    position = "left",
    xOffset = 3,
    yOffset = 3,
    suggestionColor = colors.gray,
    theme = "primary",

    onAutocomplete = function(text)
        print("Completed: " .. text)
    end,

    onSubmit = function(text)
        if #text > 0 then
            -- Add to history
            table.insert(commandHistory, text)
            print("> " .. text)

            -- Execute command (placeholder)
            print("Executing: " .. text)

            -- Clear field for next command
            commandField.text = ""
            commandField.cursorPos = 0
        end
    end
})

-- Output area
ui.label({
    text = "Press Tab to accept suggestions",
    position = "left",
    xOffset = 3,
    yOffset = 5,
    fg = colors.yellow
})

ui.label({
    text = "Press Enter to execute",
    position = "left",
    xOffset = 3,
    yOffset = 6,
    fg = colors.yellow
})

ui.run({fps = 30})
```

**Differences from Basic TextField:**

| Feature | Basic TextField | Advanced TextField |
|---------|----------------|-------------------|
| Cursor Style | Custom drawn character | Native CraftOS cursor |
| Password Masking | Not available | Optional with `masked` |
| Autocomplete | Not available | Optional with `autocomplete` |
| Suggestion Display | N/A | Gray text to right of cursor |
| Tab Key | Cycles through elements | Accepts autocomplete |
| Enter Key | No special behavior | Triggers `onSubmit` |
| Visual | Custom blinking cursor | System cursor blink |

**When to Use:**
- **advancedTextField**: For password fields, command inputs, search boxes with autocomplete, or multi-line editing with advanced features (line numbers, read-only mode)
- **Basic textfield (ui.textfield)**: For simple text input (both single-line and multi-line)

**Multi-line Support:**

The `advancedTextField` now supports multi-line editing just like the basic `ui.textfield()`:

```lua
-- Multi-line advanced text field with line numbers
local editor = inputs.advancedTextField({
    text = "Line 1\nLine 2\nLine 3",
    width = 40,
    height = 10,                     -- Multi-line mode (height > 1)
    lineNumbers = true,              -- Show line numbers
    readOnly = false,                -- Allow editing
    position = "center",

    onChange = function(text)
        print("Content changed")
    end,

    onSubmit = function(text)        -- Ctrl+Enter to submit in multiline mode
        print("Submitted")
    end
})
```

**Multi-line Features (height > 1):**
- Line numbers (optional with `lineNumbers = true`)
- Read-only mode (optional with `readOnly = true`)
- Page Up/Down navigation
- Ctrl+Enter to submit (if `onSubmit` callback provided)
- Click to position cursor at any row/column
- Arrow keys for navigation
- Enter creates new lines

---

### Text Area (DEPRECATED - Use inputs.advancedTextField with height > 1)

⚠️ **DEPRECATED:** This element has been removed. Use `inputs.advancedTextField({height = 10})` instead for multi-line editing with advanced features.

The unified `advancedTextField` component now handles both single-line and multi-line editing automatically based on the `height` parameter.

```lua
local editor = inputs.textArea({
    text = "Line 1\nLine 2\nLine 3",  -- Initial text (default: "")
    width = 40,                        -- Width in characters (default: 40)
    height = 10,                       -- Height in rows (default: 10)
    lineNumbers = true,                -- Show line numbers (default: false)
    wrap = false,                      -- Line wrapping (default: false, NOT YET IMPLEMENTED)
    readOnly = false,                  -- Prevent editing (default: false)
    position = "center",               -- Anchor position

    -- Theme options:
    theme = "textArea",                -- Use theme colors
    -- OR manual colors:
    fg = colors.white,                 -- Text color
    bg = colors.gray,                  -- Background color
    bgActive = colors.lightGray,       -- Background when focused
    lineNumberFg = colors.lightGray,   -- Line number text color
    lineNumberBg = colors.gray,        -- Line number background
    selectionBg = colors.blue,         -- Selection highlight (NOT YET IMPLEMENTED)
    cursorColor = colors.white,        -- Cursor color

    -- Callbacks:
    onChange = function(text)
        print("Text changed: " .. #text .. " characters")
    end,
    onSubmit = function(text)
        print("Submitted (Ctrl+Enter): " .. text)
    end
})
```

**Key Features:**
- **Multi-line editing**: Full text editor with line-based storage
- **Line numbers**: Optional, dynamically sized based on line count
- **Cursor navigation**: Arrow keys, Home, End, PageUp, PageDown
- **Text operations**: Insert, delete, backspace, enter for new lines
- **Mouse support**: Click to position cursor, scroll wheel for scrolling
- **Auto-scroll**: Cursor stays visible when navigating
- **Read-only mode**: Display text without allowing edits
- **Callbacks**: onChange fires on every edit, onSubmit on Ctrl+Enter

**API Methods:**

```lua
-- Get text as string (with newlines)
local text = editor:getText()

-- Set text (replaces all content)
editor:setText("New text\nWith multiple lines")

-- Get content width (accounting for line numbers)
local width = editor:getContentWidth()

-- Get line number width
local lnWidth = editor:getLineNumberWidth()
```

**Keyboard Controls:**

| Key | Action |
|-----|--------|
| Arrow Keys | Move cursor |
| Home | Move to start of line |
| End | Move to end of line |
| PageUp/PageDown | Scroll by page |
| Enter | Insert new line |
| Backspace | Delete character before cursor |
| Delete | Delete character at cursor |
| Ctrl+Enter | Submit (calls onSubmit) |
| Type | Insert character at cursor |

**Mouse Controls:**

| Action | Effect |
|--------|--------|
| Click | Position cursor at click location |
| Scroll Wheel | Scroll view up/down |
| Click Line Numbers | No action (ignored) |

**Internal Structure:**

```lua
{
    type = "textArea",
    lines = {"Line 1", "Line 2", "Line 3"},  -- Array of strings
    cursorLine = 1,                           -- Current line (1-indexed)
    cursorCol = 0,                            -- Column in line (0-indexed)
    scrollLine = 0,                           -- First visible line (0-indexed)
    width = 40,
    height = 10,
    lineNumbers = true,
    readOnly = false
}
```

**Example: Code Editor**

```lua
local codeEditor = inputs.textArea({
    text = "function greet(name)\n    print(\"Hello, \" .. name .. \"!\")\nend",
    width = 50,
    height = 15,
    lineNumbers = true,
    position = "center",
    theme = "textArea",
    onChange = function(text)
        statusLabel.text = "Lines: " .. select(2, text:gsub("\n", "\n")) + 1
    end,
    onSubmit = function(text)
        -- Execute or save code
        local func, err = load(text)
        if func then
            func()
        else
            print("Error: " .. err)
        end
    end
})
```

**Example: Read-only Log Viewer**

```lua
local logViewer = inputs.textArea({
    text = "System started\nLoading modules...\nReady",
    width = 40,
    height = 10,
    lineNumbers = false,
    readOnly = true,
    theme = "info",
    position = "center"
})

-- Add new log entries
local function addLog(message)
    local currentText = logViewer:getText()
    logViewer:setText(currentText .. "\n" .. message)
end
```

**Example: Note Taking App**

```lua
local noteArea = inputs.textArea({
    text = "",
    width = 45,
    height = 12,
    lineNumbers = false,
    position = "center",
    onChange = function(text)
        characterCount.text = "Characters: " .. #text
        wordCount.text = "Words: " .. select(2, text:gsub("%S+", ""))
    end
})

ui.button({
    text = "Save Note",
    position = "bottomCenter",
    onclick = function()
        local file = fs.open("note.txt", "w")
        file.write(noteArea:getText())
        file.close()
        print("Note saved!")
    end
})
```

**Limitations (Current Version):**
- Line wrapping is not yet implemented (lines truncate at width)
- Text selection is not yet implemented
- Copy/paste is not yet implemented
- Syntax highlighting is not yet implemented
- Undo/redo is not yet implemented
- Find/replace is not yet implemented

**Performance Notes:**
- Efficient for typical use (100s of lines)
- Very long lines (>1000 chars) may cause slowdown
- Scrolling is optimized (only draws visible lines)
- Cursor blinking uses system cursor (no custom animation)

**Comparison with advancedTextField:**

| Feature | advancedTextField | textArea |
|---------|-------------------|----------|
| Lines | Single line | Multiple lines |
| Scrolling | Horizontal (auto) | Vertical (mouse wheel) |
| Line Numbers | No | Optional |
| Height | 1 row | Configurable |
| Masking | Yes (password) | No |
| Autocomplete | Yes | No |
| Best For | Single-line inputs | Multi-line documents |

---

### Terminal

**Composition-based interactive terminal** built from existing UI elements (rectangle + textfield + labels). The terminal architecture demonstrates the power of component reuse - input handling, cursor management, and focus are all provided automatically by the textfield component.

**Architecture:**
- **Container**: `UI.rectangle` with dynamic children
- **Input**: Switches between `UI.textfield` and `inputs.advancedTextField` based on autocomplete needs
- **Prompts**: Custom labels for prompt prefix (">") and spinners
- **Benefits**: Reuses textfield features (cursor, click, focus, autocomplete) without reimplementation

```lua
local ui = dofile("UI.lua")
local inputs = dofile("Inputs.lua")

ui.init(context)
inputs.init(ui)

ui.newScene("TerminalDemo")
ui.setScene("TerminalDemo")

-- Create terminal
local console = inputs.terminal({
    width = 44,
    height = 11,
    x = 5,
    y = 5,
    -- Optional:
    border = true,
    position = "center",
    fg = colors.white,        -- Text color
    bg = colors.black,        -- Background color
    promptColor = colors.lime -- Prompt ">" color
})

-- Add initial output
console:append("=== System Initialized ===")
console:append("Type 'help' for commands")
console:append("")

-- Command history for up/down arrow navigation
local commandHistory = {}

-- Prompt for input with callback
local function newPrompt()
    console:prompt(">", function(input)
        -- Handle command
        if input == "help" then
            console:append("Available commands:")
            console:append("  help - Show this help")
            console:append("  clear - Clear terminal")
            console:append("  echo <text> - Echo text back")
        elseif input == "clear" then
            console:clear()
            console:append("Terminal cleared")
        elseif input:sub(1, 5) == "echo " then
            console:append(input:sub(6))
        elseif input ~= "" then
            console:append("Unknown command: " .. input)
        end

        -- Add to history
        if input ~= "" then
            table.insert(commandHistory, input)
        end

        -- Show next prompt
        newPrompt()
    end, {
        history = commandHistory,                                    -- UP/DOWN arrow navigation
        autocomplete = {"help", "clear", "echo ", "history"}       -- TAB to complete
    })
end

newPrompt()

ui.run({fps = 30})
```

**Constructor Options:**
- `width` - Terminal width in characters (default: 50)
- `height` - Terminal height in rows (default: 12)
- `x`, `y` - Position (or use `position`/`xOffset`/`yOffset`)
- `border` - Show border around terminal (default: false)
- `fg` - Text color (default: colors.white)
- `bg` - Background color (default: colors.black)
- `promptColor` - Prompt ">" color (default: colors.lime)
- `spinnerColor` - Spinner animation color (default: colors.yellow)
- `position`, `xOffset`, `yOffset` - Positioning options
- `scene` - Scene to add to (default: active scene)

**Methods:**

**`terminal:append(text)`**
Add a line of text to the terminal output.

```lua
console:append("System ready")
console:append("Server started on port 8080")
```

**`terminal:clear()`**
Clear all output lines from the terminal.

```lua
console:clear()
```

**`terminal:prompt(prefix, callback, opts)`**
Show an input prompt and wait for user input.

Parameters:
- `prefix` (string) - Prompt string (default: ">")
- `callback` (function) - Called with input text when Enter is pressed
- `opts` (table, optional) - Options table:
  - `history` (array) - Command history for UP/DOWN arrow navigation
  - `autocomplete` (array) - Autocomplete suggestions for TAB completion

```lua
-- Simple prompt
console:prompt(">", function(input)
    print("You entered: " .. input)
end)

-- With history and autocomplete
local history = {}
console:prompt(">", function(input)
    if input ~= "" then
        table.insert(history, input)
    end
    print("Command: " .. input)
end, {
    history = history,
    autocomplete = {"help", "clear", "exit"}
})
```

**`terminal:startSpinner(label)`**
Show an animated spinner with optional label (for loading states).

```lua
console:startSpinner("Loading...")
-- Do work...
console:stopSpinner()
```

**`terminal:stopSpinner()`**
Stop and hide the spinner.

```lua
console:stopSpinner()
```

**Features:**

**Automatic Focus**
- Input field is auto-focused when prompt appears
- Click anywhere in terminal to focus input
- Click input field to position cursor

**Command History**
- Pass `history` array in `opts` parameter to `prompt()`
- UP arrow navigates to older commands
- DOWN arrow navigates to newer commands
- After last history item, DOWN clears to empty line
- History index persists across prompts

**Autocomplete**
- Pass `autocomplete` array in `opts` parameter to `prompt()`
- Terminal automatically uses `inputs.advancedTextField` when autocomplete is provided
- Press TAB to accept suggestion
- Falls back to basic `ui.textfield` when no autocomplete needed
- Intelligent switching for optimal performance

**Scrolling**
- Output automatically scrolls as new lines are added
- Keeps most recent lines visible
- Older lines scroll out of view

**Visual Feedback**
- Spinner animation for async operations
- Customizable prompt prefix
- Color-coded prompts and spinners

**Example: File Manager Shell**

```lua
local fileShell = inputs.terminal({
    width = 50,
    height = 15,
    position = "center",
    border = true
})

fileShell:append("File Manager v1.0")
fileShell:append("Type 'help' for commands")
fileShell:append("")

local history = {}
local currentPath = "/"

local function showPrompt()
    fileShell:prompt(currentPath .. " >", function(input)
        if input ~= "" then
            table.insert(history, input)
        end

        if input == "help" then
            fileShell:append("Commands:")
            fileShell:append("  ls - List files")
            fileShell:append("  cd <dir> - Change directory")
            fileShell:append("  cat <file> - Show file contents")
            fileShell:append("  rm <file> - Delete file")
        elseif input == "ls" then
            local files = fs.list(currentPath)
            for _, file in ipairs(files) do
                fileShell:append("  " .. file)
            end
        elseif input:sub(1, 3) == "cd " then
            local newPath = input:sub(4)
            if fs.isDir(newPath) then
                currentPath = newPath
                fileShell:append("Changed to " .. currentPath)
            else
                fileShell:append("Error: Not a directory")
            end
        elseif input == "clear" then
            fileShell:clear()
        elseif input ~= "" then
            fileShell:append("Unknown command: " .. input)
        end

        showPrompt()
    end, {
        history = history,
        autocomplete = {"help", "ls", "cd ", "cat ", "rm ", "clear"}
    })
end

showPrompt()
```

**Example: Async Operation with Spinner**

```lua
local terminal = inputs.terminal({
    width = 40,
    height = 10,
    position = "center"
})

terminal:append("Starting download...")
terminal:startSpinner("Downloading")

-- Simulate async work
local function download()
    sleep(2)
    terminal:stopSpinner()
    terminal:append("Download complete!")
    terminal:prompt(">", function(input)
        terminal:append("You entered: " .. input)
    end)
end

parallel.waitForAny(download, function() ui.run({fps = 30}) end)
```

**Implementation Notes:**

The terminal uses direct children insertion (`table.insert(self.children, ...)`) instead of `addChild()` to bypass automatic positioning. This allows precise control over element placement at the bottom line.

```lua
-- Direct insertion (used by terminal)
table.insert(self.children, promptLabel)
table.insert(self.children, inputField)

-- vs. addChild (applies automatic positioning)
self:addChild(promptLabel)  -- Would apply semantic positioning
```

This pattern is useful when you need manual positioning control within a container.

**Cursor Behavior:**

The terminal benefits from the unified textfield cursor system:
- Single-line mode: Uses `UI._cursorX/Y/Blink` set at end of render
- Click positioning: Inherited from textfield
- Focus management: Automatic via textfield
- No custom cursor code needed in terminal

**When to Use:**
- **Terminal/Console interfaces**: Command-line style applications
- **Chat systems**: Message history with input at bottom
- **Log viewers with input**: Monitoring tools with command input
- **Interactive shells**: File managers, REPLs, admin tools

---

## Common Options

All elements support:

### Positioning
- `position` - Anchor position (center, topLeft, etc.)
- `xOffset`, `yOffset` - Offset from anchor point
- `x`, `y` - Absolute position (overrides position/offset)

### Theming
- `theme` - Theme path (e.g., "primary", "slider", "success")
- `fg`, `bg` - Manual color overrides (highest priority)
- Element-specific colors (vary by element type)

### Scene Management
- `scene` - Scene to add element to (default: active scene)

---

## Theme Examples

### Using Semantic Colors

```lua
-- Success-themed slider
local successSlider = inputs.slider({
    value = 90,
    theme = "success",  -- Green from theme
    position = "center"
})

-- Primary-themed button group
local primaryGroup = inputs.buttonGroup({
    options = {"Low", "Medium", "High"},
    theme = "primary",  -- Primary color from theme
    position = "center"
})

-- Danger-themed dropdown
local dangerDropdown = inputs.dropdown({
    options = {"Delete", "Cancel"},
    theme = "danger",  -- Red from theme
    position = "center"
})
```

### Using Element Defaults

```lua
-- Uses theme.slider defaults
local slider1 = inputs.slider({
    value = 50,
    position = "center"
})

-- Uses theme.buttonGroup defaults
local group1 = inputs.buttonGroup({
    options = {"A", "B", "C"},
    position = "center"
})

-- Uses theme.dropdown defaults
local dropdown1 = inputs.dropdown({
    options = {"Option 1", "Option 2"},
    position = "center"
})
```

### Custom Theme Properties

```lua
-- In theme definition:
ui.registerTheme("myTheme", {
    primary = colors.blue,

    -- Custom input properties
    controls = {
        volume = {
            fillColor = colors.lime,
            trackColor = colors.gray
        },
        difficulty = {
            selectedBg = colors.orange,
            bg = colors.brown
        }
    }
})

ui.setTheme("myTheme")

-- Use custom theme paths:
local volumeSlider = inputs.slider({
    value = 70,
    theme = "controls.volume",
    position = "topLeft"
})

local difficultyRadios = inputs.buttonGroup({
    options = {"Easy", "Normal", "Hard"},
    theme = "controls.difficulty",
    position = "center"
})
```

---

## Complete Examples

### Settings Panel with All Input Types

```lua
local ui = dofile("UI.lua")
local inputs = dofile("Inputs.lua")

local context = { scenes = {}, elements = {}, functions = {} }
ui.init(context)
inputs.init(ui)

ui.newScene("Settings")
ui.setScene("Settings")

-- Title
ui.label({
    text = "=== Game Settings ===",
    position = "topCenter",
    yOffset = 1,
    fg = colors.yellow
})

-- Volume slider
ui.label({
    text = "Volume:",
    position = "left",
    xOffset = 2,
    yOffset = 4
})

local volumeSlider = inputs.slider({
    value = 70,
    min = 0,
    max = 100,
    step = 5,
    width = 20,
    label = "",
    showValue = true,
    valueFormat = "%.0f%%",
    position = "left",
    xOffset = 12,
    yOffset = 4,
    theme = "success",
    onChange = function(val)
        print("Volume: " .. val)
    end
})

-- Difficulty radio buttons
ui.label({
    text = "Difficulty:",
    position = "left",
    xOffset = 2,
    yOffset = 7
})

local difficulty = inputs.buttonGroup({
    options = {"Easy", "Normal", "Hard"},
    selected = 2,
    orientation = "horizontal",
    spacing = 2,
    position = "left",
    xOffset = 15,
    yOffset = 7,
    theme = "primary",
    onChange = function(selected, index)
        print("Difficulty: " .. selected)
    end
})

-- Graphics quality dropdown
ui.label({
    text = "Graphics:",
    position = "left",
    xOffset = 2,
    yOffset = 10
})

local graphics = inputs.dropdown({
    options = {"Low", "Medium", "High", "Ultra"},
    selected = 2,
    width = 15,
    maxHeight = 4,
    position = "left",
    xOffset = 14,
    yOffset = 10,
    theme = "primary",
    onChange = function(selected, index)
        print("Graphics: " .. selected)
    end
})

-- Character selection with search
ui.label({
    text = "Character:",
    position = "left",
    xOffset = 2,
    yOffset = 13
})

local character = inputs.dropdown({
    options = {
        "Warrior", "Mage", "Rogue", "Paladin",
        "Ranger", "Druid", "Bard", "Monk"
    },
    selected = 1,
    width = 20,
    maxHeight = 5,
    searchable = true,
    placeholder = "Choose character...",
    position = "left",
    xOffset = 14,
    yOffset = 13,
    theme = "success",
    onChange = function(selected, index)
        print("Character: " .. selected)
    end
})

-- Back button
ui.button({
    text = "Save & Exit",
    width = 15,
    bg = colors.green,
    colorPressed = colors.lime,
    position = "bottomCenter",
    yOffset = -2,
    onclick = function()
        print("Settings saved!")
        print(string.format(
            "Volume: %d, Difficulty: %s, Graphics: %s, Character: %s",
            volumeSlider.value,
            difficulty.options[difficulty.selected],
            graphics.options[graphics.selected],
            character.options[character.selected]
        ))
    end
})

ui.run({fps = 30})
```

---

### Audio Mixer with Vertical Sliders

```lua
local ui = dofile("UI.lua")
local inputs = dofile("Inputs.lua")

ui.init(context)
inputs.init(ui)

ui.newScene("Mixer")
ui.setScene("Mixer")

-- Title
ui.label({
    text = "Audio Mixer",
    position = "topCenter",
    yOffset = 1,
    fg = colors.cyan
})

-- Create vertical sliders for different channels
local channels = {
    {name = "Master", value = 80, color = colors.lime},
    {name = "Music", value = 60, color = colors.blue},
    {name = "SFX", value = 70, color = colors.yellow},
    {name = "Voice", value = 90, color = colors.orange}
}

local sliders = {}
for i, channel in ipairs(channels) do
    -- Channel label
    ui.label({
        text = channel.name,
        position = "topLeft",
        xOffset = 10 + (i - 1) * 10,
        yOffset = 3,
        fg = colors.white
    })

    -- Vertical slider
    sliders[i] = inputs.slider({
        value = channel.value,
        min = 0,
        max = 100,
        orientation = "vertical",
        width = 3,
        height = 12,
        showValue = true,
        valueFormat = "%.0f",
        fillColor = channel.color,
        trackColor = colors.gray,
        position = "topLeft",
        xOffset = 9 + (i - 1) * 10,
        yOffset = 5,
        onChange = function(val)
            print(channel.name .. ": " .. val)
        end
    })
end

-- Preset dropdown
ui.label({
    text = "Preset:",
    position = "bottomLeft",
    xOffset = 2,
    yOffset = -4
})

local preset = inputs.dropdown({
    options = {"Balanced", "Music Focus", "Game Focus", "Quiet"},
    width = 15,
    maxHeight = 4,
    placeholder = "Load preset...",
    position = "bottomLeft",
    xOffset = 11,
    yOffset = -4,
    onChange = function(selected, index)
        -- Apply preset values
        if index == 1 then  -- Balanced
            sliders[1]:setValue(80)
            sliders[2]:setValue(60)
            sliders[3]:setValue(60)
            sliders[4]:setValue(80)
        elseif index == 2 then  -- Music Focus
            sliders[1]:setValue(90)
            sliders[2]:setValue(100)
            sliders[3]:setValue(30)
            sliders[4]:setValue(50)
        elseif index == 3 then  -- Game Focus
            sliders[1]:setValue(80)
            sliders[2]:setValue(40)
            sliders[3]:setValue(90)
            sliders[4]:setValue(100)
        elseif index == 4 then  -- Quiet
            sliders[1]:setValue(30)
            sliders[2]:setValue(20)
            sliders[3]:setValue(20)
            sliders[4]:setValue(40)
        end
    end
})

ui.run({fps = 30})
```

---

### Form with Validation

```lua
local ui = dofile("UI.lua")
local inputs = dofile("Inputs.lua")

ui.init(context)
inputs.init(ui)

ui.newScene("Form")
ui.setScene("Form")

-- Title
ui.label({
    text = "New Account",
    position = "topCenter",
    yOffset = 2,
    fg = colors.lime
})

-- Age slider
ui.label({
    text = "Age:",
    position = "left",
    xOffset = 5,
    yOffset = 5
})

local ageSlider = inputs.slider({
    value = 18,
    min = 13,
    max = 100,
    step = 1,
    width = 25,
    showValue = true,
    valueFormat = "%.0f years",
    position = "left",
    xOffset = 11,
    yOffset = 5,
    theme = "primary"
})

-- Account type
ui.label({
    text = "Type:",
    position = "left",
    xOffset = 5,
    yOffset = 8
})

local accountType = inputs.buttonGroup({
    options = {"Free", "Premium", "Enterprise"},
    selected = 1,
    orientation = "horizontal",
    position = "left",
    xOffset = 12,
    yOffset = 8,
    theme = "success"
})

-- Country dropdown with search
ui.label({
    text = "Country:",
    position = "left",
    xOffset = 5,
    yOffset = 11
})

local country = inputs.dropdown({
    options = {
        "USA", "Canada", "Mexico", "UK", "Germany",
        "France", "Spain", "Italy", "Japan", "China",
        "Australia", "Brazil", "India", "Russia"
    },
    width = 25,
    maxHeight = 6,
    searchable = true,
    placeholder = "Select country...",
    position = "left",
    xOffset = 15,
    yOffset = 11,
    theme = "primary"
})

-- Status label
local statusLabel = ui.label({
    text = "",
    position = "center",
    yOffset = 7,
    fg = colors.yellow
})

-- Submit button with validation
ui.button({
    text = "Create Account",
    width = 18,
    bg = colors.green,
    colorPressed = colors.lime,
    position = "bottomCenter",
    yOffset = -2,
    onclick = function()
        -- Validation
        if ageSlider.value < 18 then
            statusLabel.text = "Must be 18 or older!"
            statusLabel.fg = colors.red
        elseif not country.selected then
            statusLabel.text = "Please select a country"
            statusLabel.fg = colors.red
        else
            statusLabel.text = string.format(
                "Account created! Age: %d, Type: %s, Country: %s",
                ageSlider.value,
                accountType.options[accountType.selected],
                country.options[country.selected]
            )
            statusLabel.fg = colors.lime
        end
    end
})

ui.run({fps = 30})
```

---

## Migration from Non-Interactive Elements

These new input elements complement the basic UI elements:

```lua
-- Old: Basic checkbox for boolean toggle
ui.checkbox({
    text = "Enable feature",
    initial = false,
    onclick = function(self, checked)
        print("Checked: " .. tostring(checked))
    end
})

-- New: Button group for multiple choices
inputs.buttonGroup({
    options = {"Off", "Low", "High"},
    selected = 1,
    onChange = function(selected, index)
        print("Setting: " .. selected)
    end
})

-- New: Slider for numeric values
inputs.slider({
    value = 50,
    min = 0,
    max = 100,
    onChange = function(value)
        print("Value: " .. value)
    end
})

-- New: Dropdown for many options
inputs.dropdown({
    options = {"Option 1", "Option 2", "Option 3", "Option 4"},
    onChange = function(selected, index)
        print("Selected: " .. selected)
    end
})
```

---

## Notes

- Theme system is fully backward compatible
- Manual colors always override theme colors
- All elements use `UI.resolveTheme()` internally for color resolution
- Slider drag events use `onDrag()` method for smooth interaction
- Dropdown click-outside-to-close uses onClick return values
- Button group auto-calculates dimensions for positioning system
- All elements automatically call `UI.markDirty()` when state changes

---

## Troubleshooting

### Slider not responding to drag
- Ensure you are using `ui.run()` **or** routing `mouse_click`, `mouse_drag`, and `mouse_up` events into `UI.handleEvent(ev, ...)`.
- Verify the slider is visible and in the active scene.
- Make sure the slider's `onPress` / `onDrag` handlers are intact (see the example).
- Check that no full-screen overlay or dialog is sitting on top and absorbing pointer events.

### Button group buttons overlapping
- Increase `spacing` parameter
- Check that options aren't too long for available width
- Use vertical orientation for long option labels

### Dropdown not closing on click outside
- Ensure onClick returns false when clicking outside dropdown area
- Check that the dropdown is topmost element (added last to scene)
- Verify event handling order (reverse iteration)

### Search not working in dropdown
- Set `searchable = true`
- Make sure keyboard events are being captured
- Check that `onChar` and `onKey` handlers are called

---

## License

MIT License - Feel free to use in your CC:Tweaked projects!

**Version:** 1.1
**Last Updated:** November 6, 2025

**Changelog:**
- v1.1 (Nov 6, 2025): Added TextArea element with multi-line editing, line numbers, and scrolling
- v1.0 (Nov 4, 2025): Initial release with Slider, ButtonGroup, Dropdown, and AdvancedTextField

---

# Part III: Data Visualization (DataDisplay.lua)

---

# Data Display Module Documentation (Theme System Edition)

Extension module for `UI.lua` that provides data visualization elements with full theme system integration.

## Setup

```lua
local ui = dofile("UI.lua")
local dataDisplay = dofile("dataDisplay.lua")

-- Initialize
ui.init(context)
dataDisplay.init(ui)
```

## Theme System Integration

All data display elements now support the theme system with the `theme` parameter:

```lua
-- Use semantic theme colors
local bar = dataDisplay.progressBar({
    value = 75,
    maxValue = 100,
    width = 20,
    theme = "success",  -- Uses theme's success color
    position = "center"
})

-- Use element-specific theme defaults
local gauge = dataDisplay.gauge({
    value = 45,
    maxValue = 100,
    theme = "gauge",  -- Uses theme.gauge colors
    position = "center"
})

-- Manual override still works
local customBar = dataDisplay.progressBar({
    value = 50,
    fillColor = colors.orange,  -- Manual override
    position = "center"
})
```

### Color Resolution Priority

All elements follow this priority cascade:

1. **Manual colors** (highest priority) - `fillColor = colors.orange`
2. **Theme parameter** - `theme = "danger"`
3. **Default element theme** - `theme.progressBar.fillColor`
4. **Hardcoded fallbacks** (lowest priority)

## Elements

### Progress Bar

Displays a percentage-based progress indicator.

```lua
local bar = dataDisplay.progressBar({
    value = 75,
    maxValue = 100,
    width = 20,
    showPercent = true,
    position = "center",
    
    -- Theme options:
    theme = "success",        -- Use semantic color
    -- OR manual colors:
    fillColor = colors.green, -- Manual override
    bg = colors.gray,
    fg = colors.white
})

-- Update value
bar:setValue(90)
```

**Theme Properties:**
- `fg` - Text color
- `bg` - Empty bar background
- `fillColor` - Filled bar color

**Default Theme Values:**
```lua
theme.progressBar = {
    fg = colors.white,
    bg = colors.gray,
    fillColor = colors.green
}
```

### Gauge

Visual meter with color-coded ranges.

```lua
local gauge = dataDisplay.gauge({
    value = 45,
    maxValue = 100,
    width = 20,
    height = 3,
    label = "System Load",
    position = "center",
    
    -- Theme options:
    theme = "gauge",  -- Uses theme defaults
    -- OR manual colors:
    lowColor = colors.red,
    medColor = colors.yellow,
    highColor = colors.green
})

-- Update value
gauge:setValue(75)
```

**Theme Properties:**
- `fg` - Text color
- `bg` - Background color
- `lowColor` - Color for 0-33%
- `medColor` - Color for 33-66%
- `highColor` - Color for 66-100%

**Default Theme Values:**
```lua
theme.gauge = {
    fg = colors.white,
    bg = colors.black,
    lowColor = colors.red,
    medColor = colors.yellow,
    highColor = colors.green
}
```

### Stat Panel

Displays key-value pairs.

```lua
local stats = dataDisplay.statPanel({
    stats = {
        {label = "CPU", value = "45%"},
        {label = "RAM", value = "2.1GB"}
    },
    width = 20,
    height = 4,
    position = "topLeft",
    
    -- Theme options:
    theme = "statPanel",
    -- OR manual colors:
    labelColor = colors.cyan,
    valueColor = colors.white
})

-- Update specific stat
stats:updateStat("CPU", "67%")
```

**Theme Properties:**
- `fg` - General text color
- `bg` - Background color
- `labelColor` - Label text color
- `valueColor` - Value text color

**Default Theme Values:**
```lua
theme.statPanel = {
    fg = colors.white,
    bg = colors.black,
    labelColor = colors.cyan,
    valueColor = colors.white
}
```

### Scrollable List

Interactive list with mouse selection and scrolling.

```lua
local list = dataDisplay.scrollableList({
    items = {"Item 1", "Item 2", "Item 3"},
    width = 20,
    height = 5,
    onSelect = function(item, index)
        print("Selected: " .. item)
    end,
    position = "center",
    
    -- Theme options:
    theme = "primary",  -- Use primary color for selection
    -- OR manual colors:
    selectedBg = colors.blue
})

-- Update items
list:setItems({"New 1", "New 2"})
```

**Theme Properties:**
- `fg` - Text color
- `bg` - Background color
- `selectedBg` - Selected item background

**Default Theme Values:**
```lua
theme.scrollableList = {
    fg = colors.white,
    bg = colors.black,
    selectedBg = colors.blue
}
```

### Table

Grid display with headers and scrolling.

```lua
local table = dataDisplay.table({
    headers = {"Name", "Age", "Score"},
    rows = {
        {"Alice", "25", "100"},
        {"Bob", "30", "95"}
    },
    columnWidths = {10, 5, 8},
    width = 40,
    height = 10,
    position = "center",
    
    -- Theme options:
    theme = "table",
    -- OR manual colors:
    headerBg = colors.gray,
    headerFg = colors.white,
    border = colors.gray
})

-- Update rows
table:setRows(newRows)
```

**Theme Properties:**
- `fg` - Row text color
- `bg` - Row background
- `headerBg` - Header background
- `headerFg` - Header text color
- `border` - Border color

**Default Theme Values:**
```lua
theme.table = {
    fg = colors.white,
    bg = colors.black,
    headerBg = colors.gray,
    headerFg = colors.white,
    border = colors.gray
}
```

### Bar Chart

Horizontal bar chart.

```lua
local chart = dataDisplay.barChart({
    data = {
        {label = "Mon", value = 45},
        {label = "Tue", value = 78}
    },
    width = 30,
    height = 5,
    maxValue = 100,
    position = "center",
    
    -- Theme options:
    theme = "success",  -- Use success color for bars
    -- OR manual colors:
    barColor = colors.lime
})

-- Update data
chart:setData(newData)
```

**Theme Properties:**
- `fg` - Text color
- `bg` - Background color
- `barColor` - Bar fill color

**Default Theme Values:**
```lua
theme.barChart = {
    fg = colors.white,
    bg = colors.black,
    barColor = colors.lime
}
```

### Range Bar

Vertical or horizontal bar graph with color zones, setpoints, and range indicators.

```lua
-- Vertical battery bar with theme
local batteryBar = dataDisplay.rangeBar({
    value = 75,
    minValue = 0,
    maxValue = 100,
    width = 7,
    height = 12,
    orientation = "vertical",
    label = "Battery",
    showValue = true,
    valueFormat = "%.0f%%",
    position = "left",
    xOffset = 5,
    yOffset = 3,
    
    -- Theme options:
    theme = "rangeBar",  -- Use default theme
    -- OR use semantic color:
    theme = "success",   -- Single color with auto-computed zones
    -- OR manual colors:
    lowColor = colors.red,
    medColor = colors.yellow,
    highColor = colors.lime
})

-- Temperature bar with custom zones and setpoint
local tempBar = dataDisplay.rangeBar({
    value = 3200,
    minValue = 0,
    maxValue = 5000,
    width = 7,
    height = 12,
    orientation = "vertical",
    label = "Temp",
    showValue = true,
    valueFormat = "%.0fK",
    
    setpoint = 3500,
    setpointMarker = ">",
    setpointColor = colors.cyan,
    
    -- Custom zones override theme colors
    zones = {
        {min = 0,    max = 2000, color = colors.blue},
        {min = 2000, max = 3500, color = colors.lime},
        {min = 3500, max = 4500, color = colors.yellow},
        {min = 4500, max = 5000, color = colors.red}
    },
    
    position = "center"
})

-- Update dynamically
batteryBar:setValue(90)
tempBar:setSetpoint(4000)
```

**Theme Properties:**
- `fg` - Text color
- `bg` - Background outside bar
- `emptyBg` - Unfilled portion of bar
- `borderBg` - Border background
- `lowColor` - Color for low zone (0-33%)
- `medColor` - Color for medium zone (33-66%)
- `highColor` - Color for high zone (66-100%)

**Default Theme Values:**
```lua
theme.rangeBar = {
    fg = colors.white,
    bg = colors.black,
    emptyBg = colors.gray,
    borderBg = colors.lightGray,
    lowColor = colors.red,
    medColor = colors.yellow,
    highColor = colors.green
}
```

**Options:**
- `value` - Current value
- `minValue` - Minimum value (default: 0)
- `maxValue` - Maximum value (default: 100)
- `width` - Width of bar (characters)
- `height` - Height of bar (rows)
- `orientation` - "vertical" (default) or "horizontal"
- `label` - Label text
- `showValue` - Show numeric value (default: true)
- `valueFormat` - Printf format string (default: "%.0f")
- `setpoint` - Value to mark with indicator
- `setpointMarker` - Character for marker (default: ">")
- `setpointColor` - Color of marker (default: white)
- `lowThreshold` - Percentage for low/med boundary (default: 33)
- `highThreshold` - Percentage for med/high boundary (default: 66)
- `zones` - Custom zones: `{{min, max, color}, ...}`

## Common Options

All elements support:
- `theme` - Theme path (e.g., "primary", "gauge", "success")
- `position` - Anchor position
- `xOffset`, `yOffset` - Offset from anchor
- `x`, `y` - Absolute position
- `fg`, `bg` - Manual color overrides (highest priority)
- `scene` - Scene to add to

## Theme Examples

### Using Semantic Colors

```lua
-- Success-themed progress bar
local successBar = dataDisplay.progressBar({
    value = 90,
    theme = "success",  -- Green from theme
    position = "center"
})

-- Danger-themed gauge
local dangerGauge = dataDisplay.gauge({
    value = 15,
    theme = "danger",  -- Red from theme
    position = "center"
})

-- Warning-themed chart
local warningChart = dataDisplay.barChart({
    data = {{label = "Alert", value = 75}},
    theme = "warning",  -- Yellow from theme
    position = "center"
})
```

### Using Element Defaults

```lua
-- Uses theme.progressBar defaults
local bar1 = dataDisplay.progressBar({
    value = 50,
    position = "center"
})

-- Uses theme.gauge defaults
local gauge1 = dataDisplay.gauge({
    value = 60,
    position = "center"
})
```

### Custom Theme Properties

You can define custom theme paths:

```lua
-- In theme definition:
ui.registerTheme("myTheme", {
    -- Standard properties...
    primary = colors.blue,
    
    -- Custom data display properties
    dashboard = {
        cpuBar = {
            fillColor = colors.red,
            bg = colors.gray
        },
        memBar = {
            fillColor = colors.yellow,
            bg = colors.gray
        }
    }
})

ui.setTheme("myTheme")

-- Use custom theme paths:
local cpuBar = dataDisplay.progressBar({
    value = 45,
    theme = "dashboard.cpuBar",  -- Custom path
    position = "topLeft"
})

local memBar = dataDisplay.progressBar({
    value = 70,
    theme = "dashboard.memBar",  -- Different custom path
    position = "topLeft",
    yOffset = 2
})
```

## Migration from Non-Themed Version

Existing code continues to work without changes:

```lua
-- Old code (still works)
local bar = dataDisplay.progressBar({
    value = 50,
    fillColor = colors.green,  -- Manual colors
    bg = colors.gray
})

-- New code (uses theme)
local bar = dataDisplay.progressBar({
    value = 50,
    theme = "success"  -- Semantic color
})

-- Or use defaults
local bar = dataDisplay.progressBar({
    value = 50  -- Uses theme.progressBar defaults
})
```

## Example: Themed Dashboard

```lua
local ui = dofile("UI.lua")
local dataDisplay = dofile("dataDisplay.lua")

ui.init(context)
dataDisplay.init(ui)
ui.setTheme("default")  -- Or your custom theme

ui.createScene("dashboard")

-- All elements automatically use theme colors
local cpuGauge = dataDisplay.gauge({
    value = 45,
    label = "CPU",
    position = "topLeft",
    xOffset = 2,
    yOffset = 2
})

local memBar = dataDisplay.progressBar({
    value = 70,
    position = "topLeft",
    xOffset = 2,
    yOffset = 6
})

local tempBar = dataDisplay.rangeBar({
    value = 3200,
    minValue = 0,
    maxValue = 5000,
    orientation = "vertical",
    label = "Temp",
    setpoint = 3500,
    position = "topRight",
    xOffset = -10,
    yOffset = 2
})

-- Update in main loop
local updater = {
    type = "updater",
    x = 0, y = 0,
    update = function(self, dt)
        cpuGauge:setValue(getCPU())
        memBar:setValue(getMem())
        tempBar:setValue(getTemp())
    end,
    draw = function(self) end
}
ui.addElement("dashboard", updater)

ui.show("dashboard")
ui.run()
```

## Notes

- Theme system is fully backward compatible
- Manual colors always override theme colors
- Elements use `UI.resolveTheme()` internally for color resolution
- All theme paths support dot notation (e.g., "dashboard.stat.label")
- Single color themes automatically compute lighter variants for pressed/active states
