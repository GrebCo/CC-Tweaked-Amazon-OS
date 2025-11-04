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
