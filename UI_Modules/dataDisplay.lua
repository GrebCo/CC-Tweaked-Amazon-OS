--[[ ====================================================================
  Data Display Module - Extension for newui.lua
  Provides data visualization and display elements
  WITH THEME SYSTEM INTEGRATION
==================================================================== ]]--

local dataDisplay = {}

-- Store reference to UI library (will be set on init)
local UI = nil

-------------------------------------------------
-- Initialize with UI reference
-------------------------------------------------
function dataDisplay.init(uiLib)
    UI = uiLib
end

-------------------------------------------------
-- PROGRESS BAR ELEMENT
-------------------------------------------------
function dataDisplay.progressBar(opts)
    opts = opts or {}

    -- Resolve colors from theme roles with manual overrides
    local fgColor = opts.fg or UI.resolveColor("text", colors.white)
    local bgColor = opts.bg or UI.resolveColor("surface", colors.gray)
    local fillColor = opts.fillColor or UI.resolveColor("success", colors.green)

    local e = {
        type = "progressBar",
        opts = opts,
        value = opts.value or 0,
        maxValue = opts.maxValue or 100,
        width = opts.width or 20,
        height = opts.height or 1,

        -- Use resolved theme colors
        fg = fgColor,
        bg = bgColor,
        fillColor = fillColor,
        
        showPercent = opts.showPercent ~= false,

        setValue = function(self, val)
            self.value = math.max(0, math.min(val, self.maxValue))
        end,

        draw = function(self)
            local percent = (self.value / self.maxValue) * 100
            local fillWidth = math.floor((self.value / self.maxValue) * self.width)

            UI.term.setCursorPos(self.x, self.y)

            -- Draw filled portion
            UI.term.setBackgroundColor(self.fillColor)
            UI.term.setTextColor(self.fg)
            UI.term.write(string.rep(" ", fillWidth))

            -- Draw empty portion
            UI.term.setBackgroundColor(self.bg)
            UI.term.write(string.rep(" ", self.width - fillWidth))

            -- Show percentage if enabled
            if self.showPercent then
                local percentText = string.format("%d%%", percent)
                local textX = self.x + math.floor((self.width - #percentText) / 2)
                UI.term.setCursorPos(textX, self.y)
                UI.term.setTextColor(self.fg)
                UI.term.write(percentText)
            end
        end
    }
    -- Initialize bounds (x, y, width, height, visible, focusable)
    UI.initBounds(e, opts)

    return UI.addElement(opts.scene or UI.activeScene, e)
end

-------------------------------------------------
-- GAUGE ELEMENT
-------------------------------------------------
function dataDisplay.gauge(opts)
    opts = opts or {}

    -- Resolve colors from theme roles with manual overrides
    local fgColor = opts.fg or UI.resolveColor("text", colors.white)
    local bgColor = opts.bg or UI.resolveColor("background", colors.black)
    local lowColor = opts.lowColor or UI.resolveColor("error", colors.red)
    local medColor = opts.medColor or UI.resolveColor("warning", colors.yellow)
    local highColor = opts.highColor or UI.resolveColor("success", colors.green)

    local e = {
        type = "gauge",
        opts = opts,
        value = opts.value or 0,
        maxValue = opts.maxValue or 100,
        width = opts.width or 20,
        height = opts.height or 3,
        label = opts.label or "",

        -- Use resolved theme colors
        fg = fgColor,
        bg = bgColor,
        lowColor = lowColor,
        medColor = medColor,
        highColor = highColor,
        

        setValue = function(self, val)
            self.value = math.max(0, math.min(val, self.maxValue))
        end,

        draw = function(self)
            -- Determine color based on value
            local percent = (self.value / self.maxValue) * 100
            local barColor
            if percent < 33 then
                barColor = self.lowColor
            elseif percent < 66 then
                barColor = self.medColor
            else
                barColor = self.highColor
            end

            -- Draw label
            if self.label ~= "" then
                UI.term.setCursorPos(self.x, self.y)
                UI.term.setBackgroundColor(self.bg)
                UI.term.setTextColor(self.fg)
                UI.term.write(self.label)
            end

            -- Draw gauge bar
            local fillWidth = math.floor((self.value / self.maxValue) * self.width)
            local yPos = self.label ~= "" and self.y + 1 or self.y

            UI.term.setCursorPos(self.x, yPos)
            UI.term.setBackgroundColor(barColor)
            UI.term.write(string.rep(" ", fillWidth))
            UI.term.setBackgroundColor(self.bg)
            UI.term.write(string.rep(" ", self.width - fillWidth))

            -- Draw value text
            local valueText = string.format("%d/%d", self.value, self.maxValue)
            UI.term.setCursorPos(self.x, yPos + 1)
            UI.term.setBackgroundColor(self.bg)
            UI.term.setTextColor(self.fg)
            UI.term.write(valueText)
        end
    }
    -- Initialize bounds (x, y, width, height, visible, focusable)
    UI.initBounds(e, opts)

    return UI.addElement(opts.scene or UI.activeScene, e)
end

-------------------------------------------------
-- STAT PANEL ELEMENT (Key-Value Display)
-------------------------------------------------
function dataDisplay.statPanel(opts)
    opts = opts or {}

    -- Resolve colors from theme roles with manual overrides
    local fgColor = opts.fg or UI.resolveColor("text", colors.white)
    local bgColor = opts.bg or UI.resolveColor("background", colors.black)
    local labelColor = opts.labelColor or UI.resolveColor("info", colors.cyan)
    local valueColor = opts.valueColor or UI.resolveColor("text", colors.white)

    local e = {
        type = "statPanel",
        opts = opts,
        stats = opts.stats or {},
        width = opts.width or 20,
        height = opts.height or 5,

        -- Use resolved theme colors
        fg = fgColor,
        bg = bgColor,
        labelColor = labelColor,
        valueColor = valueColor,
        

        updateStat = function(self, label, value)
            for _, stat in ipairs(self.stats) do
                if stat.label == label then
                    stat.value = value
                    return
                end
            end
            -- If not found, add new stat
            table.insert(self.stats, {label = label, value = value})
        end,

        draw = function(self)
            for i, stat in ipairs(self.stats) do
                if i > self.height then break end

                local line = i - 1
                UI.term.setCursorPos(self.x, self.y + line)
                UI.term.setBackgroundColor(self.bg)

                -- Draw label
                UI.term.setTextColor(self.labelColor)
                UI.term.write(stat.label .. ": ")

                -- Draw value
                UI.term.setTextColor(self.valueColor)
                local valueStr = tostring(stat.value)
                local remaining = self.width - #stat.label - 2
                if #valueStr > remaining then
                    valueStr = valueStr:sub(1, remaining - 3) .. "..."
                end
                UI.term.write(valueStr)

                -- Pad rest of line
                local used = #stat.label + 2 + #valueStr
                if used < self.width then
                    UI.term.write(string.rep(" ", self.width - used))
                end
            end
        end
    }
    -- Initialize bounds (x, y, width, height, visible, focusable)
    UI.initBounds(e, opts)

    return UI.addElement(opts.scene or UI.activeScene, e)
end

-------------------------------------------------
-- SCROLLABLE LIST ELEMENT
-------------------------------------------------
function dataDisplay.scrollableList(opts)
    opts = opts or {}

    -- Resolve colors from theme roles with manual overrides
    local fgColor = opts.fg or UI.resolveColor("text", colors.white)
    local bgColor = opts.bg or UI.resolveColor("background", colors.black)
    local selectedBgColor = opts.selectedBg or UI.resolveColor("selection", colors.blue)

    local e = {
        type = "scrollableList",
        opts = opts,
        items = opts.items or {},
        width = opts.width or 20,
        height = opts.height or 5,

        -- Use resolved theme colors
        fg = fgColor,
        bg = bgColor,
        selectedBg = selectedBgColor,
        
        selectedIndex = 1,
        scrollOffset = 0,
        onSelect = opts.onSelect,

        setItems = function(self, newItems)
            self.items = newItems
            self.selectedIndex = math.min(self.selectedIndex, #newItems)
            self.scrollOffset = 0
        end,

        onClick = function(self, x, y)
            local relY = y - self.y
            local itemIndex = self.scrollOffset + relY + 1

            if itemIndex >= 1 and itemIndex <= #self.items then
                self.selectedIndex = itemIndex
                if self.onSelect then
                    self.onSelect(self.items[itemIndex], itemIndex)
                end
            end
            return true
        end,

        onScroll = function(self, dir, x, y)
            local ex = self.x + (self._offsetX or 0)
            local ey = self.y + (self._offsetY or 0)

            if x >= ex and x < ex + self.width and y >= ey and y < ey + self.height then
                local maxOffset = math.max(0, #self.items - self.height)
                self.scrollOffset = math.max(0, math.min(self.scrollOffset + dir, maxOffset))
            end
        end,

        draw = function(self)
            local start = self.scrollOffset + 1
            local stop = math.min(#self.items, start + self.height - 1)

            for i = start, stop do
                local line = i - start
                local item = self.items[i]
                local bg = (i == self.selectedIndex) and self.selectedBg or self.bg

                UI.term.setCursorPos(self.x, self.y + line)
                UI.term.setBackgroundColor(bg)
                UI.term.setTextColor(self.fg)

                local displayText = tostring(item)
                if #displayText > self.width then
                    displayText = displayText:sub(1, self.width - 3) .. "..."
                else
                    displayText = displayText .. string.rep(" ", self.width - #displayText)
                end

                UI.term.write(displayText)
            end

            -- Fill empty lines
            for line = stop - start + 1, self.height - 1 do
                UI.term.setCursorPos(self.x, self.y + line)
                UI.term.setBackgroundColor(self.bg)
                UI.term.write(string.rep(" ", self.width))
            end
        end
    }
    -- Initialize bounds (x, y, width, height, visible, focusable)
    UI.initBounds(e, opts)

    return UI.addElement(opts.scene or UI.activeScene, e)
end

-------------------------------------------------
-- TABLE ELEMENT
-------------------------------------------------
function dataDisplay.table(opts)
    opts = opts or {}

    -- Resolve colors from theme roles with manual overrides
    local fgColor = opts.fg or UI.resolveColor("text", colors.white)
    local bgColor = opts.bg or UI.resolveColor("background", colors.black)
    local headerBgColor = opts.headerBg or UI.resolveColor("surface", colors.gray)
    local headerFgColor = opts.headerFg or UI.resolveColor("text", colors.white)
    local borderColor = opts.border or UI.resolveColor("border", colors.gray)

    local e = {
        type = "table",
        opts = opts,
        headers = opts.headers or {},
        rows = opts.rows or {},
        columnWidths = opts.columnWidths,
        width = opts.width or 40,
        height = opts.height or 10,

        -- Use resolved theme colors
        fg = fgColor,
        bg = bgColor,
        headerBg = headerBgColor,
        headerFg = headerFgColor,
        border = borderColor,
        
        scrollOffset = 0,

        setRows = function(self, newRows)
            self.rows = newRows
            self.scrollOffset = 0
        end,

        onScroll = function(self, dir, x, y)
            local ex = self.x + (self._offsetX or 0)
            local ey = self.y + (self._offsetY or 0)

            if x >= ex and x < ex + self.width and y >= ey and y < ey + self.height then
                local maxOffset = math.max(0, #self.rows - (self.height - 2))
                self.scrollOffset = math.max(0, math.min(self.scrollOffset + dir, maxOffset))
            end
        end,

        draw = function(self)
            -- Auto-calculate column widths if not provided
            local colWidths = self.columnWidths
            if not colWidths then
                local availWidth = self.width - (#self.headers - 1) -- Subtract separators
                local colWidth = math.floor(availWidth / #self.headers)
                colWidths = {}
                for i = 1, #self.headers do
                    colWidths[i] = colWidth
                end
            end

            -- Draw headers
            UI.term.setCursorPos(self.x, self.y)
            UI.term.setBackgroundColor(self.headerBg)
            UI.term.setTextColor(self.headerFg)

            for i, header in ipairs(self.headers) do
                local text = tostring(header)
                if #text > colWidths[i] then
                    text = text:sub(1, colWidths[i])
                else
                    text = text .. string.rep(" ", colWidths[i] - #text)
                end
                UI.term.write(text)
                if i < #self.headers then
                    UI.term.write(" ")
                end
            end

            -- Draw rows
            local start = self.scrollOffset + 1
            local stop = math.min(#self.rows, start + self.height - 3)

            for i = start, stop do
                local rowLine = i - start + 1
                local row = self.rows[i]

                UI.term.setCursorPos(self.x, self.y + rowLine)
                UI.term.setBackgroundColor(self.bg)
                UI.term.setTextColor(self.fg)

                for j, cell in ipairs(row) do
                    local text = tostring(cell)
                    if #text > colWidths[j] then
                        text = text:sub(1, colWidths[j])
                    else
                        text = text .. string.rep(" ", colWidths[j] - #text)
                    end
                    UI.term.write(text)
                    if j < #row then
                        UI.term.write(" ")
                    end
                end
            end

            -- Fill empty rows
            for rowLine = stop - start + 2, self.height - 1 do
                UI.term.setCursorPos(self.x, self.y + rowLine)
                UI.term.setBackgroundColor(self.bg)
                UI.term.write(string.rep(" ", self.width))
            end
        end
    }
    -- Initialize bounds (x, y, width, height, visible, focusable)
    UI.initBounds(e, opts)

    return UI.addElement(opts.scene or UI.activeScene, e)
end

-------------------------------------------------
-- BAR CHART ELEMENT
-------------------------------------------------
function dataDisplay.barChart(opts)
    opts = opts or {}

    -- Resolve colors from theme roles with manual overrides
    local fgColor = opts.fg or UI.resolveColor("text", colors.white)
    local bgColor = opts.bg or UI.resolveColor("background", colors.black)
    local barColor = opts.barColor or UI.resolveColor("success", colors.lime)

    local e = {
        type = "barChart",
        opts = opts,
        data = opts.data or {},
        width = opts.width or 30,
        height = opts.height or 5,
        maxValue = opts.maxValue,

        -- Use resolved theme colors
        fg = fgColor,
        bg = bgColor,
        barColor = barColor,
        

        setData = function(self, newData)
            self.data = newData
        end,

        draw = function(self)
            -- Calculate max value if not provided
            local max = self.maxValue
            if not max then
                max = 0
                for _, item in ipairs(self.data) do
                    if item.value > max then
                        max = item.value
                    end
                end
            end

            if max == 0 then max = 1 end -- Avoid division by zero

            -- Draw each bar
            for i, item in ipairs(self.data) do
                if i > self.height then break end

                local barWidth = math.floor((item.value / max) * (self.width - 10))
                local y = self.y + i - 1

                UI.term.setCursorPos(self.x, y)
                UI.term.setBackgroundColor(self.bg)
                UI.term.setTextColor(self.fg)

                -- Draw label (truncated to 8 chars)
                local label = tostring(item.label)
                if #label > 8 then
                    label = label:sub(1, 8)
                else
                    label = label .. string.rep(" ", 8 - #label)
                end
                UI.term.write(label .. " ")

                -- Draw bar
                UI.term.setBackgroundColor(self.barColor)
                UI.term.write(string.rep(" ", barWidth))

                -- Clear rest of line
                UI.term.setBackgroundColor(self.bg)
                UI.term.write(string.rep(" ", self.width - 10 - barWidth))
            end

            -- Fill empty lines
            for i = #self.data + 1, self.height do
                UI.term.setCursorPos(self.x, self.y + i - 1)
                UI.term.setBackgroundColor(self.bg)
                UI.term.write(string.rep(" ", self.width))
            end
        end
    }
    -- Initialize bounds (x, y, width, height, visible, focusable)
    UI.initBounds(e, opts)

    return UI.addElement(opts.scene or UI.activeScene, e)
end

-------------------------------------------------
-- RANGE BAR ELEMENT (Vertical/Horizontal with zones)
-------------------------------------------------
function dataDisplay.rangeBar(opts)
    opts = opts or {}

    -- Resolve colors from theme roles with manual overrides
    local fgColor = opts.fg or UI.resolveColor("text", colors.white)
    local bgColor = opts.bg or UI.resolveColor("background", colors.black)
    local emptyBgColor = opts.emptyBg or UI.resolveColor("surface", colors.gray)
    local borderBgColor = opts.borderBg or UI.resolveColor("border", colors.lightGray)
    local lowColor = opts.lowColor or UI.resolveColor("error", colors.red)
    local medColor = opts.medColor or UI.resolveColor("warning", colors.yellow)
    local highColor = opts.highColor or UI.resolveColor("success", colors.green)

    local e = {
        type = "rangeBar",
        opts = opts,
        value = opts.value or 0,
        minValue = opts.minValue or 0,
        maxValue = opts.maxValue or 100,
        width = opts.width or 7,
        height = opts.height or 12,
        orientation = opts.orientation or "vertical",
        label = opts.label or "",
        showValue = opts.showValue ~= false,
        valueFormat = opts.valueFormat or "%.0f",

        -- Use resolved theme colors
        fg = fgColor,
        bg = bgColor,
        emptyBg = emptyBgColor,
        borderBg = borderBgColor,
        lowColor = lowColor,
        medColor = medColor,
        highColor = highColor,
        
        -- Thresholds (percentage based, 0-100)
        lowThreshold = opts.lowThreshold or 33,
        highThreshold = opts.highThreshold or 66,
        
        -- Custom zones (value based, overrides thresholds if provided)
        zones = opts.zones,
        
        -- Setpoint
        setpoint = opts.setpoint,
        setpointMarker = opts.setpointMarker or ">",
        setpointColor = opts.setpointColor or colors.white,
        
        fillChar = opts.fillChar or " ",

        setValue = function(self, val)
            self.value = math.max(self.minValue, math.min(val, self.maxValue))
        end,

        setSetpoint = function(self, sp)
            self.setpoint = sp
        end,

        -- Helper: Get color for a given value
        getColorForValue = function(self, val)
            -- If zones are defined, use them
            if self.zones then
                for _, zone in ipairs(self.zones) do
                    if val >= zone.min and val <= zone.max then
                        return zone.color or self.fg  -- Handle nil color
                    end
                end
                return self.emptyBg  -- Better default for "no zone"
            end

            -- Otherwise use simple 3-zone thresholds
            local percent = ((val - self.minValue) / (self.maxValue - self.minValue)) * 100
            if percent <= self.lowThreshold then
                return self.lowColor
            elseif percent <= self.highThreshold then
                return self.medColor
            else
                return self.highColor
            end
        end,

        draw = function(self)
            if self.orientation == "vertical" then
                self:drawVertical()
            else
                self:drawHorizontal()
            end
        end,

        drawVertical = function(self)
            local barHeight = self.height
            local barWidth = self.width

            -- Calculate fill percentage
            local percent = (self.value - self.minValue) / (self.maxValue - self.minValue)
            local fillHeight = math.floor(percent * barHeight)

            -- Get current color
            local fillColor = self:getColorForValue(self.value)

            -- Calculate setpoint position if exists
            local setpointRow = nil
            if self.setpoint then
                local spPercent = (self.setpoint - self.minValue) / (self.maxValue - self.minValue)
                setpointRow = barHeight - math.floor(spPercent * barHeight)
            end

            -- Draw from top to bottom
            for row = 0, barHeight - 1 do
                local y = self.y + row
                local currentHeight = barHeight - row

                UI.term.setCursorPos(self.x, y)

                -- Determine if this row should be filled
                local isFilled = currentHeight <= fillHeight

                -- Draw left border (1 char)
                if setpointRow and row == setpointRow then
                    -- Setpoint marker
                    UI.term.setBackgroundColor(self.borderBg)
                    UI.term.setTextColor(self.setpointColor)
                    UI.term.write(self.setpointMarker)
                else
                    -- Normal border (space with colored background)
                    UI.term.setBackgroundColor(self.borderBg)
                    UI.term.write(" ")
                end

                -- Draw filled area (center)
                if isFilled then
                    UI.term.setBackgroundColor(fillColor)
                else
                    UI.term.setBackgroundColor(self.emptyBg)
                end
                UI.term.write(string.rep(self.fillChar, barWidth - 2))

                -- Draw right border (1 char)
                if setpointRow and row == setpointRow then
                    -- Setpoint marker
                    UI.term.setBackgroundColor(self.borderBg)
                    UI.term.setTextColor(self.setpointColor)
                    UI.term.write(self.setpointMarker)
                else
                    -- Normal border (space with colored background)
                    UI.term.setBackgroundColor(self.borderBg)
                    UI.term.write(" ")
                end
            end

            -- Draw label above bar if provided
            if self.label ~= "" then
                UI.term.setCursorPos(self.x, self.y - 1)
                UI.term.setBackgroundColor(self.bg)
                UI.term.setTextColor(self.fg)
                local labelText = self.label:sub(1, barWidth)
                local padding = math.max(0, math.floor((barWidth - #labelText) / 2))
                UI.term.write(string.rep(" ", padding) .. labelText)
            end

            -- Draw value below bar if enabled
            if self.showValue then
                local valueText = string.format(self.valueFormat, self.value)
                UI.term.setCursorPos(self.x, self.y + barHeight)
                UI.term.setBackgroundColor(self.bg)
                UI.term.setTextColor(fillColor)
                local padding = math.max(0, math.floor((barWidth - #valueText) / 2))
                UI.term.write(string.rep(" ", padding) .. valueText)
            end
        end,

        drawHorizontal = function(self)
            local barWidth = self.width
            local barHeight = self.height

            -- Calculate fill percentage
            local percent = (self.value - self.minValue) / (self.maxValue - self.minValue)
            local fillWidth = math.floor(percent * barWidth)

            -- Get current color
            local fillColor = self:getColorForValue(self.value)

            -- Calculate setpoint position if exists
            local setpointCol = nil
            if self.setpoint then
                local spPercent = (self.setpoint - self.minValue) / (self.maxValue - self.minValue)
                setpointCol = math.floor(spPercent * barWidth)
            end

            -- Draw label on left if provided
            local startX = self.x
            if self.label ~= "" then
                UI.term.setCursorPos(self.x, self.y + math.floor(barHeight / 2))
                UI.term.setBackgroundColor(self.bg)
                UI.term.setTextColor(self.fg)
                UI.term.write(self.label .. " ")
                startX = self.x + #self.label + 1
            end

            -- Draw top border
            UI.term.setCursorPos(startX, self.y)
            for col = 0, barWidth - 1 do
                if setpointCol and col == setpointCol then
                    -- Setpoint marker
                    UI.term.setBackgroundColor(self.borderBg)
                    UI.term.setTextColor(self.setpointColor)
                    UI.term.write("v")
                else
                    -- Normal border (space with colored background)
                    UI.term.setBackgroundColor(self.borderBg)
                    UI.term.write(" ")
                end
            end

            -- Draw middle rows (filled bar)
            for row = 1, barHeight - 2 do
                UI.term.setCursorPos(startX, self.y + row)

                for col = 0, barWidth - 1 do
                    local isFilled = col < fillWidth

                    if isFilled then
                        UI.term.setBackgroundColor(fillColor)
                    else
                        UI.term.setBackgroundColor(self.emptyBg)
                    end

                    UI.term.write(self.fillChar)
                end
            end

            -- Draw bottom border
            UI.term.setCursorPos(startX, self.y + barHeight - 1)
            for col = 0, barWidth - 1 do
                if setpointCol and col == setpointCol then
                    -- Setpoint marker
                    UI.term.setBackgroundColor(self.borderBg)
                    UI.term.setTextColor(self.setpointColor)
                    UI.term.write("^")
                else
                    -- Normal border (space with colored background)
                    UI.term.setBackgroundColor(self.borderBg)
                    UI.term.write(" ")
                end
            end

            -- Draw value on right if enabled
            if self.showValue then
                local valueText = string.format(self.valueFormat, self.value)
                UI.term.setCursorPos(startX + barWidth + 1, self.y + math.floor(barHeight / 2))
                UI.term.setBackgroundColor(self.bg)
                UI.term.setTextColor(fillColor)
                UI.term.write(" " .. valueText)
            end
        end
    }

    -- Initialize bounds (x, y, width, height, visible, focusable)
    UI.initBounds(e, opts)

    return UI.addElement(opts.scene or UI.activeScene, e)
end

return dataDisplay
