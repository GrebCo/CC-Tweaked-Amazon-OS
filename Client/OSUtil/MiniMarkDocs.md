# MiniMark Documentation

**Complete Reference for OSUtil/MiniMark.lua**

MiniMark is a lightweight markup language for CC:Tweaked that renders styled text, links, buttons, and interactive elements.

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Basic Syntax](#basic-syntax)
3. [Text Formatting](#text-formatting)
4. [Interactive Elements](#interactive-elements)
5. [Layout](#layout)
6. [Scripts](#scripts)
7. [API Reference](#api-reference)
8. [Performance](#performance)

---

## Quick Start

### Creating a MiniMark Page

**mypage.txt:**
```
# <fg:yellow>Welcome to MiniMark

This is regular text. <fg:lime>This is lime text.<reset>

<link "home","Go Home">

<button label:"Click Me" fg:white bg:blue onClick:MyEvent>

<hr:"=">
```

### Rendering in UI

```lua
local ui = dofile("OSUtil/UI.lua")
local minimark = dofile("OSUtil/MiniMark.lua")

ui.init({functions = {log = print}, scenes = {}})
ui.newScene("page")
ui.setScene("page")

-- Create renderer
local page = ui.addElement(nil, minimark.createRenderer({
    path = "mypage.txt",
    y = 1,
    height = 19
}, ui))

-- Run
ui.run({fps = 30})
```

---

## Basic Syntax

### Headers and Alignment

```
# Left-aligned header
## Center-aligned header
### Right-aligned header
```

**Number of # symbols determines alignment:**
- `#` = Left
- `##` = Center
- `###` = Right

### Line Breaks

```
<br>           # Blank line
<hr>           # Horizontal rule (default: dashes)
<hr:"-=">      # Custom pattern repeats across width
<hr:"*">       # Single character repeated
```

### Escape Sequences

```
\<escaped\>    # Shows literal < and >
\"quote\"      # Shows literal quotes
\\             # Shows literal backslash
```

---

## Text Formatting

### Foreground Color

**Syntax:** `<fg:colorName>` or `<text:colorName>`

**No closing tag!** Color persists until reset or newline.

```
<fg:red>This is red text<fg:blue> now blue<reset>
<text:lime>Lime text<text:reset> back to white
```

**Available colors:**
- white, orange, magenta, lightBlue
- yellow, lime, pink, gray
- lightGray, cyan, purple, blue
- brown, green, red, black

### Background Color

**Syntax:** `<bg:colorName>` or `<background:colorName>`

**No closing tag!** Persists until reset or newline.

```
<bg:gray>Gray background<bg:black> black background<background:reset>
```

### Reset Colors

```
<fg:reset>              # Reset foreground to white
<bg:reset>              # Reset background to black
<text:reset>            # Reset foreground
<background:reset>      # Reset background
<reset>                 # Reset EVERYTHING (color + ID)
```

### Persistent ID

```
<id:"myId">This text is tagged with ID "myId"<reset>
```

IDs persist until `<reset>` or newline. Useful for scripting/targeting specific elements.

---

## Interactive Elements

### Links

**Three syntaxes:**

**1. Short form:**
```
<link "targetUrl">              # Label = URL
<link "targetUrl","Label">      # Custom label
```

**2. Long form:**
```
<link target:"home" label:"Go Home">
<link target:"about" label:"About" fg:yellow bg:blue>
```

**Clicking a link:**
```lua
-- In your onTick callback:
if page.newlink then
    local url = page.newlink
    page.newlink = nil
    -- Load new page...
    page.path = url
    page:prepareRender()
    ui.markDirty()
end
```

### Buttons

**Syntax:**
```
<button label:"Click Me">
<button label:"OK" fg:white bg:green pressBg:lime id:"okBtn" onClick:OkEvent>
```

**Attributes:**
- `label` - Button text (required)
- `fg` - Text color
- `bg` - Background color
- `pressFg` - Text color when pressed
- `pressBg` - Background color when pressed
- `id` - Identifier for scripting
- `onClick` - Event name to trigger (see Scripts)

### Checkboxes

**Syntax:**
```
<checkbox label:"Enable Sound">
<checkbox label:"Hard Mode" boxChecked:"[X]" boxUnchecked:"[ ]" fg:green id:"hard" onClick:ToggleEvent>
```

**Attributes:**
- `label` - Checkbox label (required)
- `boxChecked` - Character/string when checked (default: "[X]")
- `boxUnchecked` - Character/string when unchecked (default: "[ ]")
- `fg`, `bg` - Colors
- `id` - Identifier
- `onClick` - Event name to trigger

### Textboxes

**Syntax:**
```
<textbox>
<textbox width:"15" id:"nameInput" fg:yellow bg:gray blinkChar:"_" onEnter:SubmitEvent>
```

**Attributes:**
- `width` - Width in characters (default: 10)
- `fg`, `bg` - Colors
- `blinkChar` - Cursor character (default: "_")
- `id` - Identifier
- `onEnter` - Event triggered when Enter pressed

---

## Layout

### Word Wrapping

Text automatically wraps to terminal width. No manual line breaks needed.

### Alignment Persistence

Headers set alignment for that line only:
```
## This line is centered
This line is left-aligned (default)
```

To center multiple lines, use multiple `##` headers or structure your content accordingly.

---

## Scripts

MiniMark supports embedded Lua scripts via **Fizzle** (sandboxed execution).

### Script Tag

```
<script event:"EventName">
  print("This runs when EventName is triggered!")
</script>

<script>
  @EventName
  function handler()
    print("Alternate syntax")
  end
</script>
```

### Triggering Scripts

Scripts are triggered by interactive element events:

```
<button label:"Click" onClick:MyEvent>

<script event:"MyEvent">
  print("Button was clicked!")
</script>
```

### Script System

Scripts are extracted via:
```lua
local scripts = minimark.getScripts(path)
-- Returns: {{event = "EventName", code = "..."}, ...}
```

Execute with Fizzle:
```lua
local fizzle = dofile("EEBrowser/fizzle.lua")
fizzle.init(contextTable)  -- Provides event system
-- Scripts auto-register with event system
```

---

## API Reference

### Main Production API

**createRenderer(opts, ui)** - Recommended
```lua
local minimark = dofile("OSUtil/MiniMark.lua")
local ui = dofile("OSUtil/UI.lua")

local page = minimark.createRenderer({
    path = "page.txt",
    x = 1,
    y = 2,
    width = 45,
    height = 17,
    scene = "main"  -- Optional: which scene to add button overlays to
}, ui)

ui.addElement(nil, page)
```
- Returns a UI element with built-in 3-stage caching
- Automatically creates interactive button/checkbox/textfield overlays
- Handles scrolling, clicking, animations
- **This is the main API - use this for production!**

### Low-Level Caching Functions

**tokenizePage(path)** - Stage 1
```lua
local tokens = minimark.tokenizePage("page.txt")
```
- Parses file into logical lines
- Expensive (50-100ms)
- Cache this result!

**layoutFromTokens(tokens)** - Stage 2
```lua
local physicalLines = minimark.layoutFromTokens(tokens)
```
- Converts logical lines to physical lines
- Does word wrapping, alignment calculations
- Expensive (2-5ms)
- Cache this result!

**renderFromPhysicalLines(physicalLines, scroll, startY)** - Stage 3
```lua
local registry, lastY = minimark.renderFromPhysicalLines(physicalLines, 0, 1)
```
- Renders pre-calculated physical lines
- Fast (<1ms)
- Call this every frame for scrolling

### Element Constructor

**createRenderer(opts, ui)**
```lua
local renderer = minimark.createRenderer({
    path = "file.txt",
    x = 1,
    y = 2,
    width = 50,  -- Optional, defaults to term width
    height = 18, -- Optional, defaults to term height
    scrollOffset = 0,  -- Optional, defaults to 0
    position = "center",  -- Optional
    xOffset = 0,  -- Optional
    yOffset = 0   -- Optional
}, ui)

-- Add to UI
ui.addElement(nil, renderer)
```

**Properties:**
- `renderer.newlink` - Set when user clicks a link
- `renderer.buttons` - Registry of clickable elements
- `renderer.scrollOffset` - Current scroll position

**Methods:**
- `renderer:prepareRender()` - Pre-cache tokens and layout
- `renderer:draw()` - Render (called by UI automatically)
- `renderer:onScroll(dir)` - Handle scroll event
- `renderer:onClick(x, y)` - Handle click event

### Other Functions

**getScripts(path)**
```lua
local scripts = minimark.getScripts("page.txt")
-- Returns: {{event = "EventName", code = "Lua code"}, ...}
```

**getAlignment(line)**
```lua
local align = minimark.getAlignment("## Centered")
-- Returns: "center", "left", or "right"
```

**stripTags(text)**
```lua
local plain = minimark.stripTags("<fg:red>Hello</reset>")
-- Returns: "Hello"
```

---

## Performance

### 3-Stage Caching Pipeline

**Optimal pattern for flicker-free page changes:**

```lua
-- Stage 1 & 2: Pre-cache (expensive, but screen still shows old content)
page.path = "newpage.txt"
page:prepareRender()  -- Tokenize + layout (52-105ms, but no flicker!)

-- Stage 3: Fast render (happens next frame)
ui.markDirty()  -- Render on next frame (<1ms)
```

**Performance breakdown:**
- **First render:** 52-105ms total
  - Tokenize: 50-100ms
  - Layout: 2-5ms
  - Render: <1ms
- **Scrolling:** <1ms (just offset render)
- **Idle:** 0ms (dirty flag skips render)

⚠️ **Implementation Note:**
The UI uses a **dirty-flag redraw model**. Call `ui.markDirty()` after:
- `prepareRender()` - When changing pages
- `onScroll()` - When scrolling (MiniMark does this automatically)
- Link clicks - When navigation occurs (MiniMark does this automatically)

Without calling `ui.markDirty()`, the screen won't update even though the data changed.

### Best Practices

✅ **Do:**
```lua
-- Pre-cache before marking dirty
page.path = newPath
page:prepareRender()  -- Expensive work BEFORE render
ui.markDirty()        -- Fast render
```

✅ **Do:**
```lua
-- Cache page elements
local renderer = minimark.createRenderer({path = "page.txt"}, ui)
-- Automatically uses 3-stage caching
```

❌ **Don't:**
```lua
-- Parse during draw
draw = function()
    local tokens = minimark.tokenizePage(path)  -- Re-parses every frame!
    local lines = minimark.layoutFromTokens(tokens)
    minimark.renderFromPhysicalLines(lines, scroll, y)
end
```

❌ **Don't:**
```lua
-- File I/O in draw
draw = function()
    local file = fs.open(path, "r")  -- SLOW! Causes flicker!
    -- ...
end
```

---

## Example Pages

### Simple Page

**simple.txt:**
```
# <fg:yellow>My Page

<fg:white>This is a simple page with <fg:lime>colored text<reset>.

<link "home","Go Home">

<button label:"Click Me" fg:white bg:blue>

<hr:"=">
```

### Interactive Form

**form.txt:**
```
## <fg:cyan>User Registration

<fg:white>Please enter your name:
<textbox width:"20" id:"username" onEnter:Submit>

<checkbox label:"I agree to terms" id:"agree">

<button label:"Submit" fg:white bg:green pressBg:lime onClick:Submit>
<button label:"Cancel" fg:white bg:red pressBg:orange onClick:Cancel>

<script event:"Submit">
  print("Form submitted!")
</script>

<script event:"Cancel">
  print("Form cancelled")
</script>
```

### Styled Document

**doc.txt:**
```
# <fg:yellow>Documentation

## <fg:cyan>Introduction

<fg:white>This is the introduction text.

<bg:gray> Important Note: <bg:reset> Pay attention to this.

## <fg:cyan>Features

<fg:lime>• Feature 1
<fg:lime>• Feature 2
<fg:lime>• Feature 3

<hr:"=-">

<fg:gray>Footer text
```

---

## Troubleshooting

### Colors not working?
- Check color name spelling (case-sensitive: `lime` not `Lime`)
- Remember: **NO closing tags**! Use `<reset>` or `<fg:reset>`

### Links not clickable?
- Check that `newlink` property is being monitored
- Verify link syntax: `<link "target","label">` or `<link target:"url">`

### Scripts not running?
- Ensure Fizzle is initialized: `fizzle.init(contextTable)`
- Check event names match: `onClick:MyEvent` and `<script event:"MyEvent">`
- Scripts need the event system in contextTable

### Page flickering on scroll?
- Use `createRenderer()` - has automatic 3-stage caching
- Call `prepareRender()` before changing paths
- Make sure using `ui.run()` parallel loop

---

**End of MiniMark Documentation**
