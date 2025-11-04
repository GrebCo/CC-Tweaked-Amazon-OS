--[[ ====================================================================
  Data Display Module - Extension for UI.lua
  Provides data visualization and display elements
  WITH THEME SYSTEM INTEGRATION + NEW INTERACTIVE ELEMENTS
  
  NEW in this version:
  - Slider element (horizontal/vertical with drag support)
  - ButtonGroup/RadioGroup (mutually exclusive selection)
  - Dropdown menu (expandable selection list)
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
-- SLIDER ELEMENT
-------------------------------------------------
function dataDisplay.slider(opts)
    opts = opts or {}

    -- Resolve theme colors
    local themeColors = UI.resolveTheme(opts, "slider", {
        fg = colors.white,
        bg = colors.gray,
        trackColor = colors.gray,
        fillColor = colors.blue,
        thumbColor = colors.white
    })

    local orientation = opts.orientation or "horizontal"
    local width = opts.width or (orientation == "horizontal" and 20 or 3)
    local height = opts.height or (orientation == "horizontal" and 1 or 10)

    local e = {
        type = "slider",
        value = opts.value or 0,
        min = opts.min or 0,
        max = opts.max or 100,
        step = opts.step,  -- Optional: snap to increments
        width = width,
        height = height,
        orientation = orientation,
        showValue = opts.showValue ~= false,
        valueFormat = opts.valueFormat or "%.0f",
        label = opts.label or "",

        -- Theme colors
        fg = themeColors.fg,
        bg = themeColors.bg,
        trackColor = themeColors.trackColor,
        fillColor = themeColors.fillColor,
        thumbColor = themeColors.thumbColor,

        position = opts.position,
        xOffset = opts.xOffset,
        yOffset = opts.yOffset,
        x = opts.x or 1,
        y = opts.y or 1,

        dragging = false,

        setValue = function(self, val)
            val = math.max(self.min, math.min(val, self.max))
            if self.step then
                val = math.floor((val - self.min) / self.step + 0.5) * self.step + self.min
            end
            self.value = val
            if opts.onChange then
                opts.onChange(self.value)
            end
            UI.markDirty()
        end,

        -- Convert mouse position to value
        posToValue = function(self, mx, my)
            if self.orientation == "horizontal" then
                local relX = mx - self.x
                local percent = relX / (self.width - 1)
                return self.min + percent * (self.max - self.min)
            else
                local relY = my - self.y
                -- Invert for vertical (top = max, bottom = min)
                local percent = 1 - (relY / (self.height - 1))
                return self.min + percent * (self.max - self.min)
            end
        end,

        onClick = function(self, mx, my)
            -- Jump to clicked position
            self:setValue(self:posToValue(mx, my))
            self.dragging = true
            return true
        end,

        onDrag = function(self, mx, my)
            if self.dragging then
                self:setValue(self:posToValue(mx, my))
                return true
            end
            return false
        end,

        onRelease = function(self)
            self.dragging = false
        end,

        draw = function(self)
            if self.orientation == "horizontal" then
                -- Draw label if provided
                local startY = self.y
                if self.label ~= "" then
                    UI.term.setCursorPos(self.x, self.y)
                    UI.term.setBackgroundColor(self.bg)
                    UI.term.setTextColor(self.fg)
                    UI.term.write(self.label)
                    startY = self.y + 1
                end

                -- Calculate thumb position
                local percent = (self.value - self.min) / (self.max - self.min)
                local thumbPos = math.floor(percent * (self.width - 1))

                -- Draw track
                UI.term.setCursorPos(self.x, startY)
                for i = 0, self.width - 1 do
                    if i < thumbPos then
                        UI.term.setBackgroundColor(self.fillColor)
                    else
                        UI.term.setBackgroundColor(self.trackColor)
                    end
                    UI.term.write(i == thumbPos and "\7" or " ")  -- \7 is bullet char
                end

                -- Draw value if enabled
                if self.showValue then
                    local valueText = string.format(self.valueFormat, self.value)
                    UI.term.setCursorPos(self.x + self.width + 1, startY)
                    UI.term.setBackgroundColor(self.bg)
                    UI.term.setTextColor(self.fg)
                    UI.term.write(valueText)
                end
            else
                -- Vertical slider
                -- Draw label if provided
                local startX = self.x
                if self.label ~= "" then
                    UI.term.setCursorPos(self.x, self.y - 1)
                    UI.term.setBackgroundColor(self.bg)
                    UI.term.setTextColor(self.fg)
                    UI.term.write(self.label)
                end

                -- Calculate thumb position (inverted: top = max)
                local percent = (self.value - self.min) / (self.max - self.min)
                local thumbPos = math.floor((1 - percent) * (self.height - 1))

                -- Draw vertical track
                for i = 0, self.height - 1 do
                    UI.term.setCursorPos(startX, self.y + i)
                    if i > thumbPos then
                        UI.term.setBackgroundColor(self.fillColor)
                    else
                        UI.term.setBackgroundColor(self.trackColor)
                    end
                    UI.term.setTextColor(self.thumbColor)
                    UI.term.write(i == thumbPos and "\7" or " ")
                end

                -- Draw value if enabled
                if self.showValue then
                    local valueText = string.format(self.valueFormat, self.value)
                    UI.term.setCursorPos(startX + 2, self.y + thumbPos)
                    UI.term.setBackgroundColor(self.bg)
                    UI.term.setTextColor(self.fg)
                    UI.term.write(valueText)
                end
            end
        end
    }

    return UI.addElement(opts.scene or UI.activeScene, e)
end

-------------------------------------------------
-- BUTTON GROUP / RADIO GROUP ELEMENT
-------------------------------------------------
function dataDisplay.buttonGroup(opts)
    opts = opts or {}

    -- Resolve theme colors
    local themeColors = UI.resolveTheme(opts, "buttonGroup", {
        fg = colors.white,
        bg = colors.gray,
        selectedBg = colors.blue,
        selectedFg = colors.white
    })

    local orientation = opts.orientation or "horizontal"
    local spacing = opts.spacing or 2

    -- Pre-calculate dimensions so applyPositioning works correctly
    local calculatedWidth = 0
    local calculatedHeight = 1

    if orientation == "horizontal" then
        for i, option in ipairs(opts.options) do
            local buttonWidth = #option + 4  -- " ( ) " padding
            calculatedWidth = calculatedWidth + buttonWidth
            if i < #opts.options then
                calculatedWidth = calculatedWidth + spacing
            end
        end
    else
        -- Vertical: find max width and calculate total height
        local maxWidth = 0
        for _, option in ipairs(opts.options) do
            local buttonWidth = #option + 4
            if buttonWidth > maxWidth then
                maxWidth = buttonWidth
            end
        end
        calculatedWidth = maxWidth
        calculatedHeight = #opts.options + (#opts.options - 1) * spacing
    end

    local e = {
        type = "buttonGroup",
        options = opts.options or {"Option 1", "Option 2", "Option 3"},
        selected = opts.selected or 1,
        orientation = orientation,
        spacing = spacing,

        -- Pre-calculated dimensions
        width = calculatedWidth,
        height = calculatedHeight,

        -- Theme colors
        fg = themeColors.fg,
        bg = themeColors.bg,
        selectedBg = themeColors.selectedBg,
        selectedFg = themeColors.selectedFg,

        position = opts.position,
        xOffset = opts.xOffset,
        yOffset = opts.yOffset,
        x = opts.x or 1,
        y = opts.y or 1,

        -- Calculate dimensions based on options
        buttons = {},  -- Will hold button positions

        setSelected = function(self, index)
            if index >= 1 and index <= #self.options then
                self.selected = index
                if opts.onChange then
                    opts.onChange(self.options[index], index)
                end
                UI.markDirty()
            end
        end,

        -- Calculate button positions
        layout = function(self)
            self.buttons = {}
            local currentX = self.x
            local currentY = self.y

            for i, option in ipairs(self.options) do
                local buttonWidth = #option + 4  -- Add padding for " ( ) "
                self.buttons[i] = {
                    x = currentX,
                    y = currentY,
                    width = buttonWidth,
                    height = 1,
                    index = i
                }

                if self.orientation == "horizontal" then
                    currentX = currentX + buttonWidth + self.spacing
                else
                    currentY = currentY + 1 + self.spacing
                end
            end
        end,

        onClick = function(self, mx, my)
            -- Check which button was clicked
            for i, button in ipairs(self.buttons) do
                if mx >= button.x and mx < button.x + button.width and
                        my >= button.y and my < button.y + button.height then
                    self:setSelected(i)
                    return true
                end
            end
            return false
        end,

        draw = function(self)
            -- Layout buttons if not done yet
            if #self.buttons == 0 then
                self:layout()
            end

            -- Draw each button
            for i, button in ipairs(self.buttons) do
                local isSelected = (i == self.selected)
                local bg = isSelected and self.selectedBg or self.bg
                local fg = isSelected and self.selectedFg or self.fg
                local marker = isSelected and "\7" or " "  -- Bullet or space

                UI.term.setCursorPos(button.x, button.y)
                UI.term.setBackgroundColor(bg)
                UI.term.setTextColor(fg)
                UI.term.write("(" .. marker .. ") " .. self.options[i])
            end
        end
    }

    return UI.addElement(opts.scene or UI.activeScene, e)
end

-- Alias for more semantic naming
dataDisplay.radioGroup = dataDisplay.buttonGroup

-------------------------------------------------
-- DROPDOWN MENU ELEMENT
-------------------------------------------------
function dataDisplay.dropdown(opts)
    opts = opts or {}

    -- Resolve theme colors
    local themeColors = UI.resolveTheme(opts, "dropdown", {
        fg = colors.white,
        bg = colors.gray,
        selectedBg = colors.blue,
        selectedFg = colors.white,
        border = colors.lightGray,
        scrollbar = colors.lightGray
    })

    local e = {
        type = "dropdown",
        options = opts.options or {"Option 1", "Option 2", "Option 3"},
        selected = opts.selected,  -- Can be nil (no selection)
        width = opts.width or 20,
        maxHeight = opts.maxHeight or 8,
        placeholder = opts.placeholder or "Select...",
        searchable = opts.searchable or false,

        -- State
        expanded = false,
        scrollOffset = 0,
        hoverIndex = nil,
        searchText = "",

        -- Theme colors
        fg = themeColors.fg,
        bg = themeColors.bg,
        selectedBg = themeColors.selectedBg,
        selectedFg = themeColors.selectedFg,
        border = themeColors.border,
        scrollbar = themeColors.scrollbar,

        position = opts.position,
        xOffset = opts.xOffset,
        yOffset = opts.yOffset,
        x = opts.x or 1,
        y = opts.y or 1,
        height = 1,  -- Collapsed height

        setSelected = function(self, index)
            if index >= 1 and index <= #self.options then
                self.selected = index
                self.expanded = false
                if opts.onChange then
                    opts.onChange(self.options[index], index)
                end
                UI.markDirty()
            end
        end,

        toggle = function(self)
            self.expanded = not self.expanded
            if not self.expanded then
                self.searchText = ""
                self.height = 1  -- Collapsed height
            else
                -- Calculate expanded height
                local filtered = self:getFilteredOptions()
                local visibleCount = math.min(#filtered, self.maxHeight)
                self.height = 1 + visibleCount  -- Header + menu items
                if self.searchable then
                    self.height = self.height + 1  -- Add search box line
                end
            end
            UI.markDirty()
        end,

        getFilteredOptions = function(self)
            if self.searchText == "" then
                return self.options
            end
            local filtered = {}
            for i, opt in ipairs(self.options) do
                if string.lower(opt):find(string.lower(self.searchText), 1, true) then
                    table.insert(filtered, {index = i, value = opt})
                end
            end
            return filtered
        end,

        onClick = function(self, mx, my)
            -- Click on header
            if my == self.y and mx >= self.x and mx < self.x + self.width then
                self:toggle()
                return true
            end

            -- Click in expanded menu
            if self.expanded then
                local filtered = self:getFilteredOptions()
                local visibleCount = math.min(#filtered, self.maxHeight)

                -- Calculate where the menu items start (accounting for search box)
                local menuStartY = self.y + 1
                if self.searchable then
                    menuStartY = menuStartY + 1  -- Search box takes 1 line
                end

                -- Check if click is within menu item bounds
                if my >= menuStartY and my < menuStartY + visibleCount and
                        mx >= self.x and mx < self.x + self.width then
                    -- Calculate which item was clicked (1-based)
                    local relativeY = my - menuStartY + 1
                    local clickedIndex = relativeY + self.scrollOffset

                    if clickedIndex >= 1 and clickedIndex <= #filtered then
                        if type(filtered[clickedIndex]) == "table" then
                            self:setSelected(filtered[clickedIndex].index)
                        else
                            self:setSelected(clickedIndex)
                        end
                        return true
                    end
                elseif my == self.y + 1 and self.searchable then
                    -- Clicked on search box - don't close, just focus it
                    return true
                end

                -- Click outside closes menu
                self.expanded = false
                UI.markDirty()
            end

            return false
        end,

        onScroll = function(self, direction, mx, my)
            if self.expanded then
                local filtered = self:getFilteredOptions()
                local maxScroll = math.max(0, #filtered - self.maxHeight)
                self.scrollOffset = math.max(0, math.min(maxScroll, self.scrollOffset + direction))
                UI.markDirty()
                return true
            end
            return false
        end,

        onChar = function(self, char)
            if self.expanded and self.searchable then
                self.searchText = self.searchText .. char
                self.scrollOffset = 0
                -- Update height based on filtered results
                local filtered = self:getFilteredOptions()
                local visibleCount = math.min(#filtered, self.maxHeight)
                self.height = 1 + visibleCount + 1  -- Header + items + search box
                UI.markDirty()
                return true
            end
            return false
        end,

        onKey = function(self, key)
            if self.expanded and self.searchable and key == keys.backspace then
                if #self.searchText > 0 then
                    self.searchText = self.searchText:sub(1, -2)
                    self.scrollOffset = 0
                    -- Update height based on filtered results
                    local filtered = self:getFilteredOptions()
                    local visibleCount = math.min(#filtered, self.maxHeight)
                    self.height = 1 + visibleCount + 1  -- Header + items + search box
                    UI.markDirty()
                    return true
                end
            end
            return false
        end,

        draw = function(self)
            -- Draw collapsed header
            local displayText = self.selected and self.options[self.selected] or self.placeholder
            local arrow = self.expanded and "\30" or "\31"  -- Up/down arrows

            UI.term.setCursorPos(self.x, self.y)
            UI.term.setBackgroundColor(self.bg)
            UI.term.setTextColor(self.fg)

            -- Border
            UI.term.setBackgroundColor(self.border)
            UI.term.write("\9")  -- Left border char

            -- Content
            UI.term.setBackgroundColor(self.bg)
            local contentWidth = self.width - 4
            local paddedText = displayText:sub(1, contentWidth)
            paddedText = paddedText .. string.rep(" ", contentWidth - #paddedText)
            UI.term.write(paddedText)

            -- Arrow and right border
            UI.term.write(" " .. arrow)
            UI.term.setBackgroundColor(self.border)
            UI.term.write("\9")

            -- Draw expanded menu if open
            if self.expanded then
                local filtered = self:getFilteredOptions()
                local visibleCount = math.min(#filtered, self.maxHeight)

                -- Draw search box if searchable
                local menuStartY = self.y + 1
                if self.searchable then
                    UI.term.setCursorPos(self.x, menuStartY)
                    UI.term.setBackgroundColor(colors.lightGray)
                    UI.term.setTextColor(colors.black)
                    local searchDisplay = "Search: " .. self.searchText .. "_"
                    UI.term.write(searchDisplay:sub(1, self.width))
                    menuStartY = menuStartY + 1
                end

                -- Draw options
                for i = 1, visibleCount do
                    local optIndex = i + self.scrollOffset
                    if optIndex <= #filtered then
                        local option = filtered[optIndex]
                        local optText = type(option) == "table" and option.value or option
                        local optRealIndex = type(option) == "table" and option.index or optIndex
                        local isSelected = (optRealIndex == self.selected)

                        UI.term.setCursorPos(self.x, menuStartY + i - 1)
                        UI.term.setBackgroundColor(isSelected and self.selectedBg or self.bg)
                        UI.term.setTextColor(isSelected and self.selectedFg or self.fg)

                        local optDisplay = optText:sub(1, self.width - 2)
                        optDisplay = optDisplay .. string.rep(" ", self.width - 2 - #optDisplay)
                        UI.term.write(" " .. optDisplay)

                        -- Checkmark for selected
                        if isSelected then
                            UI.term.write("\4")  -- Checkmark
                        else
                            UI.term.write(" ")
                        end
                    end
                end

                -- Draw scrollbar if needed
                if #filtered > self.maxHeight then
                    local scrollbarX = self.x + self.width - 1
                    local scrollbarHeight = visibleCount
                    local scrollPos = math.floor((self.scrollOffset / (#filtered - self.maxHeight)) * (scrollbarHeight - 1))

                    for i = 0, scrollbarHeight - 1 do
                        UI.term.setCursorPos(scrollbarX, menuStartY + i)
                        UI.term.setBackgroundColor(i == scrollPos and self.scrollbar or self.border)
                        UI.term.write(" ")
                    end
                end
            end
        end
    }

    return UI.addElement(opts.scene or UI.activeScene, e)
end

-------------------------------------------------
-- Return the module
-------------------------------------------------
return dataDisplay