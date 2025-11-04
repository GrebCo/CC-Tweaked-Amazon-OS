# UI.lua — CC:Tweaked Terminal UI Framework

**Version:** 2.0 (Dirty Flag Rendering)
**Last Updated:** 2025-10-28
**Description:** A lightweight, extensible terminal-based user interface library built for CC:Tweaked. Features scene management, animations, event handling, and parallel event loop with dirty-flag optimization for flicker-free rendering.

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Architecture Overview](#architecture-overview)
3. [Core Concepts](#core-concepts)
4. [API Reference](#api-reference)
5. [Element Types](#element-types)
6. [Advanced Usage](#advanced-usage)
7. [Best Practices](#best-practices)
8. [Examples](#examples)

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

## API Reference

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

Single-line text input.

**Options:**
```lua
ui.textfield({
    text = "",                 -- Initial text
    width = 20,
    position = "center",
    fg = colors.white,
    bg = colors.gray,
    bgActive = colors.lightGray  -- Color when focused
})
```

**Behavior:**
- Click to focus
- Type to add text
- Backspace to delete
- Auto-focused when clicked

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