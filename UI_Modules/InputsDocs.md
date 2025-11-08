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
- **advancedTextField**: For password fields, command inputs, search boxes with autocomplete
- **Basic textfield**: For simple text input without special features
- **textArea**: For multi-line text editing (see below)

---

### Text Area

Multi-line text editor with support for line numbers, scrolling, cursor navigation, and full text editing capabilities.

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
- Make sure `UI.handleDrag()` is implemented in your UI.lua version
- Check that the slider is in the active scene
- Verify mouse events are being captured

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
