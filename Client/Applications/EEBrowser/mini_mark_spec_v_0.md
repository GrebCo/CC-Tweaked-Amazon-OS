# MiniMark v0.91 Specification Sheet

*A lightweight markup and UI language for CC**:Tweaked**, designed for simplicity and dynamic interactivity.*

---

## Design Philosophy

MiniMark makes content creation easy for non-programmers, while retaining structure for UI rendering and Fizzle scripting.\
It is optimized for **line-based parsing** and **tokenized rendering**, not nested hierarchies.

### Core Principles

- **One line = one logical block**
- **No closing tags** for most elements
- **Attributes use colons** (`:`) instead of `=`
- **Persistent attributes** (text, background, id) until changed or reset
- **Graceful defaults**
- **Fizzle integration** for interactivity

---

## Grammar Overview

### General Tag Format

```
<tag [key:"value" key2:"value2" ...]>
```

**Single-parameter shorthand:**\
`<text:green>` is equivalent to `<text color:"green">`.

**Simple reset tags:**

```
<text:reset>     -- resets only text color
<background:reset>  -- resets only background
<reset>          -- resets all attributes
```

**Aliases:**\
`<fg:*>` ≡ `<text:*>`\
`<bg:*>` ≡ `<background:*>`

---

## Block Model

Each **logical line** forms one renderable block.\
A new block is created when:

1. A **newline** is encountered.
2. A **new persistent attribute** (like `<id:*>` or `<text:*>`) begins mid-line.
3. The renderer encounters an element (button, checkbox, textbox, etc.) that ends a block.

Blocks are tokenized before rendering. Each token stores:

```lua
{ type, text, fg, bg, id?, meta? }
```

---

## Text and Color Tags

| Tag                  | Description                | Persistence                | Example              |
| -------------------- | -------------------------- | -------------------------- | -------------------- |
| `<text:color>`       | Sets text color            | Until `<text:reset>`       | `<text:yellow>`      |
| `<background:color>` | Sets background            | Until `<background:reset>` | `<background:red>`   |
| `<fg:color>`         | Alias for `<text:*>`       | —                          | `<fg:lime>`          |
| `<bg:color>`         | Alias for `<background:*>` | —                          | `<bg:gray>`          |
| `<text:reset>`       | Resets text color          | —                          | `<text:reset>`       |
| `<background:reset>` | Resets background          | —                          | `<background:reset>` |
| `<reset>`            | Resets *all* attributes    | —                          | `<reset>`            |

---

## ID Tag

| Tag                 | Description                               | Persists Until                      | Example        |
| ------------------- | ----------------------------------------- | ----------------------------------- | -------------- |
| `<id:"identifier">` | Assigns unique ID to following text block | New `<id:*>`, `<reset>`, or newline | `<id:"title">` |

Used for dynamic lookups and Fizzle control.

---

## Alignment System

Alignment is determined by leading `#` marks on each line:

| Prefix | Alignment    | Example                  |
| ------ | ------------ | ------------------------ |
| `#`    | Left align   | `# Left aligned text`    |
| `##`   | Center align | `## Center aligned text` |
| `###`  | Right align  | `### Right aligned text` |

---

## Link Tag

Three equivalent forms:

```
<link "TargetPage","Display Label">
<link target:"TargetPage" label:"Display Label">
<link "TargetPage">
```

**Behavior:**

- Renders as clickable label.
- `target` defines navigation target.
- If only one argument is provided, the label will default to the target page string.
- Supports `fg` and `bg` attributes for color customization.

---

## Interactive Elements

### 1. `<button>`

```
<button label:"Confirm" fg:white bg:gray pressBg:lime id:"confirm" onClick:ConfirmEvent>
```

| Key                  | Description           | Default        |
| -------------------- | --------------------- | -------------- |
| `label`              | Button text           | `"Button"`     |
| `fg`, `bg`           | Colors                | white / gray   |
| `pressFg`, `pressBg` | Pressed state colors  | inherited      |
| `id`                 | Identifier            | auto-generated |
| `onClick`            | Event name for Fizzle | none           |

---

### 2. `<checkbox>`

```
<checkbox label:"Enable Sound" boxChecked:"[X]" boxUnchecked:"[ ]" fg:green bg:black id:"soundBox" onClick:ToggleSound>
```

| Key            | Description               | Default        |
| -------------- | ------------------------- | -------------- |
| `label`        | Display text              | `"Checkbox"`   |
| `boxChecked`   | Checked state             | `[x]`          |
| `boxUnchecked` | Unchecked state           | `[ ]`          |
| `fg`, `bg`     | Colors                    | white / black  |
| `id`           | Identifier                | auto-generated |
| `onClick`      | Event triggered on toggle | none           |

---

### 3. `<textbox>`

```
<textbox width:"12" id:"nameField">
```

| Key         | Description                | Default        |
|-------------| -------------------------- |----------------|
| `width`     | Character width of box     | `10`           |
| `fg`, `bg`  | Text and background colors | white / gray   |
| `id`        | Unique identifier          | auto-generated |
| `blinkChar` | Character used for cursor  | `_`            |
| `onEnter`   | Event for value changes    | none           |

Displays a fixed-width blank text area for input.\
Internally represented as:

## Script Tags

```
<script event:"ConfirmStuff">
  print("Button clicked!")
</script>

-- or --

<script>
  @ConfirmStuff
  function sayHello()
    print("Hello!")
  end
</script>
```

Scripts are sandboxed and registered to **Fizzle** by event name.\
Multiple handlers per event are allowed.

---

## Structural Tags

| Tag       | Description                                                        | Example     |
| --------- | ------------------------------------------------------------------ | ----------- |
| `<hr:"">` | Draws a horizontal line across the terminal using repeated pattern | `<hr:"-=">` |
| `<br>`    | Adds a blank line                                                  | `<br>`      |

`<hr>` characters repeat until terminal width is filled.\
Escape sequences like `\\ ` and `\\<` are supported (see below).

---

## Escape Characters

MiniMark supports escaping to allow literal `<`, `>`, and quotes:

| Sequence | Output                                         |
| -------- | ---------------------------------------------- |
| `\\`     | Backslash                                      |
| `\<`     | Literal `<`                                    |
| `\>`     | Literal `>`                                    |
| `\"`     | Literal `"`                                    |
| `\n`     | Newline within same block (optional extension) |

Escapes are interpreted *before* tokenization.

---

## Tokenization and UI Communication

During parsing, MiniMark converts each line into **logical tokens**, which are then enriched with positional and visual metadata for the UI layer. This process allows the renderer to communicate interactive regions to the UI library for event handling.

Each rendered line is decomposed into fragments representing text runs, links, buttons, checkboxes, and textboxes. Each fragment stores its **screen-space coordinates** so the UI library can process clicks or hovers accurately.

### Example token structure:

```lua
{
  type = "button",
  width = 7, -- number of characters occupied
  label = "Confirm",
  id = "confirmBtn",
  onClick = "ConfirmEvent",
  fg = colors.white,
  bg = colors.gray
}
```

The MiniMark renderer collects all such elements and returns a registry table:

```lua
uiRegistry = {
  { y = 8, element = { type = "button", x = 12, ... } },
  { y = 10, element = { type = "checkbox", x = 5, ... } }
}
```

This registry is passed to the UI system, which handles:

- Click detection (`x`, `y`, `width`)
- Hover effects (`hoverFg`, `hoverBg`)
- Textbox input focus and cursor rendering
- Event routing through Fizzle.

The separation between **MiniMark (layout)** and **UI (interaction)** ensures modularity and keeps the markup language simple while allowing advanced interaction through Fizzle or higher-level scripts.

---

## Renderer State Example

```lua
state = {
  textColor = colors.white,
  bgColor = colors.black,
  id = nil
}
```

---

## Example Page

```
# <text:cyan>System UI + Tag Parsing Test

<text:green><id:"greenText">This page tests colors and elements.
<hr:"-=">

## <text:yellow>Section 1

<button label:"Confirm" fg:white bg:green pressBg:lime onClick:ConfirmStuff>
<checkbox label:"Enable feature" onClick:BoxClicked id:"chk1">
<textbox width:"12" id:"userInput">

<link target:"Home" label:"Go Back">

<script event:"ConfirmStuff">
  print("Confirmed!")
</script>
```

## Fizzle Scripting Integration

### Overview
Fizzle is the embedded scripting engine for MiniMark documents. It enables interactivity, dynamic element updates, and network communication within a secure sandbox. Scripts execute in a restricted environment with explicit API access.

### Core Capabilities
| Capability | Description |
|-------------|--------------|
| **Network Access** | `fizzle.network.send()` and `fizzle.network.query()` — communicate with other computers through a sanitized `ClientNetworkHandler.lua` wrapper. All data is validated and size-limited. |
| **Document Access** | Read or modify the active MiniMark file from cache: `fizzle.getDocument()` and `fizzle.setLine()`. |
| **Cookies** | Persistent, origin-scoped data storage via `fizzle.cookies.get()` and `fizzle.cookies.set()`. |
| **Element Control** | Direct interaction with MiniMark-generated UI elements (buttons, checkboxes, textfields, etc.) using:  |
|  | `fizzle.getElementById(id)` → returns an element proxy (supports `.fg`, `.bg`, `.text`, `.checked`, etc.). |
|  | Example: `fizzle.getElementById("greenText").fg = colors.red` |
| **OS Events** | Listen for keyboard and mouse inputs with `fizzle.on("keydown", handler)` or `fizzle.on("mouse", handler)`. |
| **Downloads** | `fizzle.requestDownload(url)` — initiate computer-to-computer transfers or wget downloads after a user confirmation prompt. |
| **UI / Popups** | Create new windows or overlays through `fizzle.popup({title, body, buttons})`, rendered using the UI library. |

---

### API Reference (Summary)
```lua
-- Elements
fizzle.getElementById(id)               -- returns proxy object with .fg, .bg, .text, etc.
fizzle.getDocument(path)                -- returns raw cached text
fizzle.getTokens(path)                  -- read-only token view
fizzle.setLine(path, lineIndex, text)   -- updates specific line and re-renders

-- Networking
fizzle.network.send(channel, data)
fizzle.network.query(address, data, timeout)

-- Cookies
fizzle.cookies.get(name)
fizzle.cookies.set(name, value, opts)

-- OS Events
fizzle.on(eventName, handler)
fizzle.off(eventName, handler)
fizzle.getMousePos()

-- Downloads
fizzle.requestDownload(url, opts)

-- UI Popups
fizzle.popup(spec)
fizzle.closePopup(id)
```

---

### Security and Permissions
- Fizzle operates in a sandbox; global OS access is disabled (`os`, `io`, and `fs` restricted).
- Network and download actions require user permission prompts.
- Each page origin maintains separate cookie and permission scopes.
- All network payloads are sanitized and logged.
- Mutations only apply to MiniMark-derived UI elements, not arbitrary UI objects.

---

### Implementation Notes
- MiniMark should export an `elementRegistry` that maps element IDs to token and layout data.
- `fizzle.getElementById()` proxies this table to support live mutation and incremental re-rendering.
- Each mutation triggers a partial re-render of affected tokens rather than a full redraw.
- The Fizzle environment should be created with a restricted `_ENV` table containing only approved libraries.

---

### Example Script
```lua
-- @helloevent
function sayHello()
  local el = fizzle.getElementById("greenText")
  if el then
    el.fg = colors.yellow
    el.text = "Hello, World!"
  end
  fizzle.network.send(1, "Ping from Hello Event")
end
```


