# Project Reference - EEBrowser (Computer 26)

**Last Updated**: 2026-01-10
**Purpose**: Quick reference to minimize token usage for future development

---

## Project Overview

ComputerCraft browser application that renders MiniMark documents with Fizzle scripting support.

**Key Components**:
- **MiniMark**: Markup language for UI (like HTML)
- **Fizzle**: Sandboxed Lua scripting for interactivity (like JavaScript)
- **UI Framework**: Custom UI library for rendering
- **Events System**: Pub/sub event handling

---

## Directory Structure

```
applications/EEBrowser/
├── browser.lua               # Main application entry point
├── MiniMark.lua             # Markup parser & renderer
├── fizzle.lua               # Script execution engine
├── config/
│   └── fizzle_config.lua    # Fizzle timeout & CC event settings
├── fizzleLibraries/
│   ├── libraries.lua        # Library loader
│   ├── document.lua         # DOM manipulation (getElementById, etc.)
│   ├── fizzleNetwork.lua    # Network functions (net.send, net.query)
│   └── fizzleCookie.lua     # Cookie storage
└── local/                   # Local pages (.txt files)
    ├── home.txt
    ├── cceventdemo.txt      # CC event demo page
    └── portal.txt

OSUtil/
├── events.lua               # Simple pub/sub event system
└── UI/
    └── UI.lua               # UI framework

cache/scripts/
└── script.lua               # Compiled fizzle scripts
```

---

## Architecture Flow

### Page Load Sequence

1. **Browser.lua** loads a .txt file
2. **MiniMark.lua** parses markup and extracts `<script>` blocks
3. **Fizzle.lua** compiles scripts, registers events, loads into sandbox
4. **UI Framework** renders elements and subscribes to events
5. Event handlers execute when triggered

### Event Routing

```
ComputerCraft Event (key, mouse_click, etc.)
    ↓
UI.handleEvent() [UI.lua:1475]
    ↓
UI.emitEvent() [broadcasts to subscribers]
    ↓
Browser's global listeners [browser.lua:93]
    ↓
fizzle.routeCCEvent() [fizzle.lua:380]
    ↓
events.triggerEvent() [events.lua:14]
    ↓
Wrapped handler function [with 10ms timeout]
    ↓
User's script executes
```

---

## MiniMark Syntax (Brief)

- **Headings**: `# Title`, `## Subtitle`
- **Text**: `<text:color>content`
- **Links**: `<link "path","Label" fg:color bg:color>`
- **Buttons**: `<button label:"Text" onClick:EventName>`
- **Inputs**: `<textbox id:"name" width:"20">`
- **IDs**: `<id:"elementId">initial text` (for DOM updates)
- **Scripts**: `<script>...</script>` blocks

**Important**: MiniMark elements are **single-line only**. No `\n` in text.

---

## Fizzle Scripting

### Event Decorators

**Regular Fizzle Events** (triggered by UI or code):
```lua
<script>
@onLoad
function initialize()
  -- Runs when page loads
end

@onClick  -- Triggered by <button onClick:MyEvent>
function myHandler()
  -- Custom event
end

@onUpdate  -- Runs every frame (throttled to 2 FPS)
function update()
  -- Update loop
end
</script>
```

**ComputerCraft Events** (NEW - added 2026-01-10):
```lua
<script>
@onCCEvent "mouse_click"
function handleClick(button, x, y)
  -- Direct CC event parameters
end

@onCCEvent "key"
function handleKey(keyCode, isHeld)
  -- keyCode from keys API
end

@onCCEvent "redstone"
function handleRedstone()
  -- No parameters for redstone
end
</script>
```

**Helper Functions** (no decorator):
```lua
<script>
function myHelper()
  -- Available to all scripts in sandbox
end
</script>
```

### Available APIs in Sandbox

**Standard Lua**:
- `pairs`, `ipairs`, `type`, `tostring`, `tonumber`
- `string`, `table`, `math`
- `print` (logs to console)

**ComputerCraft**:
- `keys` - Key constants (keys.w, keys.a, etc.)
- `rs` / `redstone` - Redstone API
- `os.clock`, `os.time`, `os.date`, `os.startTimer`, `os.setAlarm`

**Fizzle Libraries**:
- `document.getElementById(id)` - Get element
- `document.setElementBodyById(id, text)` - Update element text
- `net.send(target, message, protocol)` - Send network message
- `net.query(target, message, protocol)` - Query with response
- `cookie.set(key, value)`, `cookie.get(key)` - Persistent storage

**Not Available** (sandboxed):
- File system (`fs`)
- Most `os` functions
- Raw `_G` access

---

## CC Event System (@onCCEvent)

### Configuration

**File**: `applications/EEBrowser/config/fizzle_config.lua`

```lua
ALLOWED_CC_EVENTS = {
    -- Mouse events
    "mouse_click", "mouse_up", "mouse_drag", "mouse_scroll",

    -- Keyboard events
    "key", "key_up", "char",

    -- Peripheral events
    "monitor_touch", "monitor_resize",
    "peripheral", "peripheral_detach",

    -- Other events
    "redstone", "timer", "alarm",

    -- Blocked by default (security):
    -- "rednet_message", "modem_message",
    -- "http_success", "http_failure"
}
```

### How It Works

1. **Browser.lua** subscribes to all allowed CC events at startup (line 91)
2. When event fires, browser calls `fizzle.routeCCEvent(eventName, p1, p2, p3, p4)`
3. Fizzle prefixes event name with `"cc:"` → `"cc:mouse_click"`
4. `events.triggerEvent()` calls all registered handlers with direct parameters
5. Timeout wrapper passes parameters as `...` (varargs) for CC events

**Key Difference**:
- CC events: `func(p1, p2, p3, p4)` - direct parameters
- Fizzle events: `func(params)` - table wrapper

### Parameter Formats

| Event | Parameters |
|-------|-----------|
| `mouse_click` | `button, x, y` |
| `mouse_drag` | `button, x, y` |
| `mouse_scroll` | `direction, x, y` |
| `key` | `keyCode, isHeld` |
| `key_up` | `keyCode` |
| `char` | `character` |
| `redstone` | _(none)_ |
| `timer` | `timerID` |
| `alarm` | `alarmID` |

---

## Key Files & Functions

### browser.lua
- **Line 74**: `ui.init(contextTable)` - Initialize UI
- **Line 75**: `fizzle.init(contextTable)` - Initialize Fizzle
- **Line 91**: CC event subscription setup

### fizzle.lua
- **Line 9**: `sandbox` - Defines safe execution environment
- **Line 76**: `isCCEventAllowed()` - Validates CC events against allowlist
- **Line 101**: `createTimeoutWrapper()` - Wraps functions with 10ms timeout
- **Line 224**: `registerEventsFromCache()` - Parses decorators, registers events
- **Line 285**: `assignFizzleFunctionsToEvetsFromCache()` - Maps functions to events
- **Line 380**: `routeCCEvent()` - Routes CC events to handlers
- **Line 399**: `renew()` - Main entry point for loading scripts
- **Line 520**: Module exports

### MiniMark.lua
- **Line 608**: `getScripts()` - Extracts `<script>` blocks from markup
- **Line 654**: Skips `@onCCEvent` to let fizzle handle full syntax
- **Line 671**: `createRenderer()` - Creates UI element for rendering

### events.lua
- **Line 3**: `registerEvent(name)` - Create event slot
- **Line 7**: `registerFunction(name, func)` - Attach handler
- **Line 14**: `triggerEvent(name, ...)` - Call all handlers (varargs)

### UI.lua
- **Line 84**: `subscribeGlobalEvent()` - Global event listener (returns unsubscribe function)
- **Line 1475**: `handleEvent()` - Routes CC events
- **Line 2890**: Event loop (`os.pullEvent()`)

---

## Common Patterns

### DOM Manipulation
```lua
@onCCEvent "mouse_click"
function handleClick(button, x, y)
  local elem = document.getElementById("output")
  elem.text = "Clicked at " .. x .. "," .. y

  -- Or directly:
  document.setElementBodyById("output", "Clicked!")
end
```

### Multi-line Text (Split into separate IDs)
```markdown
<id:"row0">Line 1
<id:"row1">Line 2
<id:"row2">Line 3
```
```lua
function updateDisplay()
  document.setElementBodyById("row0", "Updated line 1")
  document.setElementBodyById("row1", "Updated line 2")
end
```

### Network Communication
```lua
@onLoad
function init()
  net.send("server", "Hello", "chat")
  local response = net.query("server", "ping", "api")
end
```

---

## Security & Sandboxing

**Timeout Protection**:
- All event handlers have 10ms execution limit
- Configured in `config/fizzle_config.lua`
- Uses `debug.sethook()` to check time every N instructions

**CC Event Allowlist**:
- Only events in `ALLOWED_CC_EVENTS` can be hooked
- Prevents network sniffing (`rednet_message`) by default
- Prevents HTTP interception by default

**Sandbox Restrictions**:
- No file system access
- No dangerous `os` functions
- No access to global `_G`
- Scripts can't escape sandbox

---

## Debugging Tips

1. **Check logs**: `log()` function outputs to console
2. **Cache file**: `/cache/scripts/script.lua` shows compiled scripts
3. **Function map**: Logs show which functions map to which events
4. **Event registration**: Logs show `"cc:eventName"` format
5. **Timeout errors**: Check if script exceeds 10ms

---

## Important Notes

- **Single-line elements**: MiniMark elements can't contain `\n`
- **Helper functions**: Scripts without decorators load as global helpers
- **Event prefix**: CC events use `"cc:"` prefix internally
- **Parameter passing**: CC events get direct params, Fizzle events get table
- **Case sensitive**: Event names are case-sensitive
- **Subscription timing**: CC events subscribed at browser init, persist across pages
- **Page reload**: Fizzle scripts reload, event handlers re-register

---

## Recent Changes (2026-01-10)

Added `@onCCEvent` decorator system:
- Modified `fizzle.lua` to parse `@onCCEvent "eventName"` syntax
- Added `ALLOWED_CC_EVENTS` to config
- Modified `browser.lua` to subscribe to CC events
- Modified `events.lua` to support varargs parameters
- Added `keys`, `rs` APIs to sandbox
- Updated `MiniMark.lua` to skip `@onCCEvent` extraction
- Created test page at `local/cceventdemo.txt`

---

## File Paths

**Base**: `C:\Users\ellio\curseforge\minecraft\Instances\Simplicity SMP\saves\MinimarkV2\computercraft\computer\26\`

All paths relative to this base directory.
