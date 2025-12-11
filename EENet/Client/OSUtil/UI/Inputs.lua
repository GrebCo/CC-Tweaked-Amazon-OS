--[[ ====================================================================
  Inputs Module - Extension for UI.lua
  Provides interactive input elements and data visualization
  WITH THEME SYSTEM INTEGRATION

  Elements in this module:
  - Slider element (horizontal/vertical with drag support)
  - ButtonGroup/RadioGroup (mutually exclusive selection)
  - Dropdown menu (expandable selection list with search)
  - AdvancedTextField (scrolling, masking, autocomplete)
  - TextArea (multi-line text editor with line numbers)
==================================================================== ]]--

local inputs = {}

-- Store reference to UI library (will be set on init)
local UI = nil

-------------------------------------------------
-- Initialize with UI reference
-------------------------------------------------
function inputs.init(uiLib)
    UI = uiLib
end

-------------------------------------------------
-- SLIDER ELEMENT
-------------------------------------------------
function inputs.slider(opts)
    opts = opts or {}

    -- Resolve colors from theme roles with manual overrides
    local fgColor = opts.fg or UI.resolveColor("text", colors.white)
    local bgColor = opts.bg or UI.resolveColor("surface", colors.gray)
    local trackColor = opts.trackColor or UI.resolveColor("surface", colors.gray)
    local fillColor = opts.fillColor or UI.resolveColor("interactive", colors.blue)
    local thumbColor = opts.thumbColor or UI.resolveColor("text", colors.white)

    local orientation = opts.orientation or "horizontal"
    local width = opts.width or (orientation == "horizontal" and 20 or 3)
    local height = opts.height or (orientation == "horizontal" and 1 or 10)

    local e = {
        type = "slider",
        opts = opts,
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
        fg = fgColor,
        bg = bgColor,
        trackColor = trackColor,
        fillColor = fillColor,
        thumbColor = thumbColor,

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
                -- Guard against division by zero
                if self.width <= 1 then
                    return self.min
                end
                local relX = mx - self.x
                local percent = relX / (self.width - 1)
                return self.min + percent * (self.max - self.min)
            else
                -- Guard against division by zero
                if self.height <= 1 then
                    return self.min
                end
                local relY = my - self.y
                -- Invert for vertical (top = max, bottom = min)
                local percent = 1 - (relY / (self.height - 1))
                return self.min + percent * (self.max - self.min)
            end
        end,

        onPress = function(self, x, y, button, isTouch)
            self.dragging = true
            self:setValue(self:posToValue(x, y))
            return true
        end,

        onDrag = function(self, x, y, button)
            if not self.dragging then return false end
            self:setValue(self:posToValue(x, y))
            return true
        end,

        onRelease = function(self, x, y, button, inBounds, isTouch)
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

    -- Initialize bounds (x, y, width, height, visible, focusable)
    UI.initBounds(e, opts)

    -- Initialize bounds (x, y, width, height, visible, focusable)
    UI.initBounds(e, opts)

    return UI.addElement(opts.scene or UI.activeScene, e)
end

-------------------------------------------------
-- BUTTON GROUP / RADIO GROUP ELEMENT
-------------------------------------------------
function inputs.buttonGroup(opts)
    opts = opts or {}

    -- Resolve colors from theme roles with manual overrides
    local fgColor = opts.fg or UI.resolveColor("text", colors.white)
    local bgColor = opts.bg or UI.resolveColor("surface", colors.gray)
    local selectedBgColor = opts.selectedBg or UI.resolveColor("interactive", colors.blue)
    local selectedFgColor = opts.selectedFg or UI.resolveColor("text", colors.white)

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
        opts = opts,
        options = opts.options or {"Option 1", "Option 2", "Option 3"},
        selected = opts.selected or 1,
        orientation = orientation,
        spacing = spacing,

        -- Pre-calculated dimensions
        width = calculatedWidth,
        height = calculatedHeight,

        -- Theme colors
        fg = fgColor,
        bg = bgColor,
        selectedBg = selectedBgColor,
        selectedFg = selectedFgColor,

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

        onClick = function(self, x, y, button)
            -- Check which button was clicked
            local mx, my = x, y
            for i, btn in ipairs(self.buttons) do
                if mx >= btn.x and mx < btn.x + btn.width and
                        my >= btn.y and my < btn.y + btn.height then
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

    -- Initialize bounds (x, y, width, height, visible, focusable)
    UI.initBounds(e, opts)

    return UI.addElement(opts.scene or UI.activeScene, e)
end

-- Alias for more semantic naming
inputs.radioGroup = inputs.buttonGroup

-------------------------------------------------
-- DROPDOWN MENU ELEMENT
-------------------------------------------------
function inputs.dropdown(opts)
    opts = opts or {}

    -- Resolve colors from theme roles with manual overrides
    local fgColor = opts.fg or UI.resolveColor("text", colors.white)
    local bgColor = opts.bg or UI.resolveColor("surface", colors.gray)
    local selectedBgColor = opts.selectedBg or UI.resolveColor("interactive", colors.blue)
    local selectedFgColor = opts.selectedFg or UI.resolveColor("text", colors.white)
    local borderColor = opts.border or UI.resolveColor("border", colors.lightGray)
    local scrollbarColor = opts.scrollbar or UI.resolveColor("border", colors.lightGray)

    local e = {
        type = "dropdown",
        opts = opts,
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
        fg = fgColor,
        bg = bgColor,
        selectedBg = selectedBgColor,
        selectedFg = selectedFgColor,
        border = borderColor,
        scrollbar = scrollbarColor,

        height = 1,  -- Collapsed height

        -- Focus flag (for keyboard input when expanded and searchable)
        focusable = opts.focusable ~= nil and opts.focusable or true,

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
                        local item = filtered[clickedIndex]
                        if item then  -- Guard against nil
                            if type(item) == "table" then
                                self:setSelected(item.index)
                            else
                                self:setSelected(clickedIndex)
                            end
                            return true
                        end
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

    -- Initialize bounds (x, y, width, height, visible, focusable)
    UI.initBounds(e, opts)

    return UI.addElement(opts.scene or UI.activeScene, e)
end

-------------------------------------------------
-- ADVANCED TEXTFIELD ELEMENT
-- Supports masked input OR autocomplete (mutually exclusive)
-- Uses CraftOS cursor for better autocomplete UX
-------------------------------------------------
function inputs.advancedTextField(opts)
    opts = opts or {}

    -- Resolve colors from theme roles with manual overrides
    local fgColor = opts.fg or UI.resolveColor("text", colors.white)
    local bgColor = opts.bg or UI.resolveColor("surface", colors.gray)
    local bgActiveColor = opts.bgActive or UI.resolveColor("interactive", colors.lightGray)
    local placeholderColor = opts.placeholderColor or UI.resolveColor("textDim", colors.lightGray)
    local suggestionColor = opts.suggestionColor or UI.resolveColor("textDim", colors.lightGray)
    local lineNumberFgColor = opts.lineNumberFg or UI.resolveColor("textDim", colors.lightGray)
    local lineNumberBgColor = opts.lineNumberBg or UI.resolveColor("surface", colors.gray)

    -- Detect multiline mode
    local height = opts.height or 1
    local multiline = height > 1

    -- Parse initial text into lines (for multiline mode)
    local function parseLines(text)
        if not text or text == "" then
            return {""}
        end
        local lines = {}
        for line in (text .. "\n"):gmatch("([^\n]*)\n") do
            table.insert(lines, line)
        end
        if #lines == 0 then
            lines = {""}
        end
        return lines
    end

    local e = {
        type = multiline and "textArea" or "advancedTextField",
        opts = opts,
        width = opts.width or 20,
        height = height,
        fg = fgColor,
        bg = bgColor,
        bgActive = bgActiveColor,
        placeholderColor = placeholderColor,
        suggestionColor = suggestionColor,
        lineNumberFg = lineNumberFgColor,
        lineNumberBg = lineNumberBgColor,

        -- Focus flags (for new event system)
        focusable = opts.focusable ~= nil and opts.focusable or true,
        lockFocus = opts.lockFocus or false,

        -- Multiline mode flag
        multiline = multiline,

        -- Single-line state
        text = multiline and "" or (opts.text or ""),
        cursorPos = multiline and 0 or #(opts.text or ""),
        viewOffset = 0,

        -- Multiline state
        lines = multiline and parseLines(opts.text or "") or nil,
        cursorLine = multiline and 1 or nil,
        cursorCol = multiline and 0 or nil,
        scrollLine = multiline and 0 or nil,
        lineNumbers = opts.lineNumbers or false,
        readOnly = opts.readOnly or false,

        -- Features (for single-line mode)
        masked = opts.masked or false,
        maskChar = opts.maskChar or "*",
        autocomplete = opts.autocomplete or nil,  -- Array of strings
        placeholder = opts.placeholder or "",
        currentSuggestion = nil,

        -- Callbacks
        onChange = opts.onChange,
        onSubmit = opts.onSubmit,
        onAutocomplete = opts.onAutocomplete,

        -- Update view offset for scrolling (single-line mode)
        updateViewOffset = function(self)
            if self.multiline then return end
            local visibleWidth = self.width - 1
            if self.cursorPos < self.viewOffset then
                self.viewOffset = self.cursorPos
            end
            if self.cursorPos >= self.viewOffset + visibleWidth then
                self.viewOffset = self.cursorPos - visibleWidth + 1
            end
            self.viewOffset = math.max(0, self.viewOffset)
        end,

        -- Find best autocomplete match (single-line mode)
        updateSuggestion = function(self)
            if self.multiline then return end
            self.currentSuggestion = nil
            if not self.autocomplete or #self.text == 0 then
                return
            end

            -- Find first match that starts with current text
            local searchText = self.text:lower()
            for _, suggestion in ipairs(self.autocomplete) do
                if type(suggestion) == "string" then
                    if suggestion:lower():sub(1, #searchText) == searchText and suggestion ~= self.text then
                        self.currentSuggestion = suggestion
                        return
                    end
                end
            end
        end,

        -- Multiline helpers
        getLineNumberWidth = function(self)
            if not self.multiline or not self.lineNumbers then return 0 end
            return #tostring(#self.lines) + 2
        end,

        getContentWidth = function(self)
            if not self.multiline then return self.width end
            return self.width - self:getLineNumberWidth()
        end,

        getText = function(self)
            if self.multiline then
                return table.concat(self.lines, "\n")
            else
                return self.text
            end
        end,

        setText = function(self, text)
            if self.multiline then
                self.lines = parseLines(text)
                self.cursorLine = math.min(self.cursorLine, #self.lines)
                self.cursorCol = math.min(self.cursorCol, #self.lines[self.cursorLine])
            else
                self.text = text
                self.cursorPos = #text
                self:updateViewOffset()
                self:updateSuggestion()
            end
            if self.onChange then
                self.onChange(self:getText())
            end
            UI.markDirty()
        end,

        insertChar = function(self, char)
            if self.multiline then
                if self.readOnly then return end
                local line = self.lines[self.cursorLine]
                local before = line:sub(1, self.cursorCol)
                local after = line:sub(self.cursorCol + 1)
                self.lines[self.cursorLine] = before .. char .. after
                self.cursorCol = self.cursorCol + 1
            else
                local before = self.text:sub(1, self.cursorPos)
                local after = self.text:sub(self.cursorPos + 1)
                self.text = before .. char .. after
                self.cursorPos = self.cursorPos + 1
                self:updateViewOffset()
                self:updateSuggestion()
            end
            if self.onChange then
                self.onChange(self:getText())
            end
            UI.markDirty()
        end,

        insertNewline = function(self)
            if not self.multiline or self.readOnly then return end
            local line = self.lines[self.cursorLine]
            local before = line:sub(1, self.cursorCol)
            local after = line:sub(self.cursorCol + 1)
            self.lines[self.cursorLine] = before
            table.insert(self.lines, self.cursorLine + 1, after)
            self.cursorLine = self.cursorLine + 1
            self.cursorCol = 0
            if self.cursorLine >= self.scrollLine + self.height then
                self.scrollLine = self.cursorLine - self.height + 1
            end
            if self.onChange then
                self.onChange(self:getText())
            end
            UI.markDirty()
        end,

        deleteChar = function(self)
            if self.multiline then
                if self.readOnly then return end
                if self.cursorCol > 0 then
                    local line = self.lines[self.cursorLine]
                    local before = line:sub(1, self.cursorCol - 1)
                    local after = line:sub(self.cursorCol + 1)
                    self.lines[self.cursorLine] = before .. after
                    self.cursorCol = self.cursorCol - 1
                elseif self.cursorLine > 1 then
                    local prevLine = self.lines[self.cursorLine - 1]
                    local currentLine = self.lines[self.cursorLine]
                    self.cursorCol = #prevLine
                    self.lines[self.cursorLine - 1] = prevLine .. currentLine
                    table.remove(self.lines, self.cursorLine)
                    self.cursorLine = self.cursorLine - 1
                end
            else
                if self.cursorPos > 0 then
                    local before = self.text:sub(1, self.cursorPos - 1)
                    local after = self.text:sub(self.cursorPos + 1)
                    self.text = before .. after
                    self.cursorPos = self.cursorPos - 1
                    self:updateViewOffset()
                    self:updateSuggestion()
                end
            end
            if self.onChange then
                self.onChange(self:getText())
            end
            UI.markDirty()
        end,

        deleteCharForward = function(self)
            if self.multiline then
                if self.readOnly then return end
                local line = self.lines[self.cursorLine]
                if self.cursorCol < #line then
                    local before = line:sub(1, self.cursorCol)
                    local after = line:sub(self.cursorCol + 2)
                    self.lines[self.cursorLine] = before .. after
                elseif self.cursorLine < #self.lines then
                    local nextLine = self.lines[self.cursorLine + 1]
                    self.lines[self.cursorLine] = line .. nextLine
                    table.remove(self.lines, self.cursorLine + 1)
                end
            else
                if self.cursorPos < #self.text then
                    local before = self.text:sub(1, self.cursorPos)
                    local after = self.text:sub(self.cursorPos + 2)
                    self.text = before .. after
                    self:updateSuggestion()
                end
            end
            if self.onChange then
                self.onChange(self:getText())
            end
            UI.markDirty()
        end,

        moveCursor = function(self, dLine, dCol)
            if not self.multiline then return end
            if dLine ~= 0 then
                local newLine = math.max(1, math.min(#self.lines, self.cursorLine + dLine))
                if self.lines[newLine] then
                    self.cursorLine = newLine
                    self.cursorCol = math.min(self.cursorCol, #self.lines[self.cursorLine])
                end
                if self.cursorLine < self.scrollLine + 1 then
                    self.scrollLine = self.cursorLine - 1
                elseif self.cursorLine > self.scrollLine + self.height then
                    self.scrollLine = self.cursorLine - self.height
                end
            end
            if dCol ~= 0 then
                self.cursorCol = math.max(0, math.min(#self.lines[self.cursorLine], self.cursorCol + dCol))
            end
            UI.markDirty()
        end,

        onPress = function(self, x, y, button, isTouch)
            -- Focus is handled automatically by the new event system if focusable=true
            local mx, my = x, y
            if self.multiline then
                local lineNumWidth = self:getLineNumberWidth()
                local contentX = self.x + lineNumWidth
                if mx < contentX then
                    return true
                end
                local clickedLine = (my - self.y) + self.scrollLine + 1
                clickedLine = math.max(1, math.min(#self.lines, clickedLine))
                local clickedCol = mx - contentX
                clickedCol = math.max(0, math.min(#self.lines[clickedLine], clickedCol))
                self.cursorLine = clickedLine
                self.cursorCol = clickedCol
            else
                local relX = mx - self.x
                self.cursorPos = math.min(#self.text, math.max(0, relX + self.viewOffset))
                self:updateViewOffset()
                self:updateSuggestion()
            end
            UI.markDirty()
            return true
        end,

        onChar = function(self, ch)
            if self.multiline and self.readOnly then return false end
            self:insertChar(ch)
            return true
        end,

        onKey = function(self, key)
            local name = keys.getName(key)

            if name == "backspace" then
                self:deleteChar()
                return true
            elseif name == "delete" then
                self:deleteCharForward()
                return true
            elseif name == "enter" then
                if self.multiline then
                    if self.onSubmit and keys.isKeyDown(keys.leftCtrl) then
                        self.onSubmit(self:getText())
                    else
                        self:insertNewline()
                    end
                else
                    if self.onSubmit then
                        self.onSubmit(self.text)
                    end
                end
                return true
            elseif name == "up" then
                if self.multiline then
                    self:moveCursor(-1, 0)
                    return true
                end
            elseif name == "down" then
                if self.multiline then
                    self:moveCursor(1, 0)
                    return true
                end
            elseif name == "left" then
                if self.multiline then
                    if self.cursorCol == 0 and self.cursorLine > 1 then
                        self.cursorLine = self.cursorLine - 1
                        self.cursorCol = #self.lines[self.cursorLine]
                    else
                        self:moveCursor(0, -1)
                    end
                    return true
                else
                    if self.cursorPos > 0 then
                        self.cursorPos = self.cursorPos - 1
                        self:updateViewOffset()
                        UI.markDirty()
                    end
                end
            elseif name == "right" then
                if self.multiline then
                    if self.cursorCol == #self.lines[self.cursorLine] and self.cursorLine < #self.lines then
                        self.cursorLine = self.cursorLine + 1
                        self.cursorCol = 0
                    else
                        self:moveCursor(0, 1)
                    end
                    return true
                else
                    if self.cursorPos < #self.text then
                        self.cursorPos = self.cursorPos + 1
                        self:updateViewOffset()
                        UI.markDirty()
                    end
                end
            elseif name == "home" then
                if self.multiline then
                    self.cursorCol = 0
                else
                    self.cursorPos = 0
                    self:updateViewOffset()
                end
                UI.markDirty()
                return true
            elseif name == "end" then
                if self.multiline then
                    self.cursorCol = #self.lines[self.cursorLine]
                else
                    self.cursorPos = #self.text
                    self:updateViewOffset()
                end
                UI.markDirty()
                return true
            elseif name == "pageUp" then
                if self.multiline then
                    self:moveCursor(-self.height, 0)
                    return true
                end
            elseif name == "pageDown" then
                if self.multiline then
                    self:moveCursor(self.height, 0)
                    return true
                end
            elseif name == "tab" and not self.multiline and self.currentSuggestion then
                self.text = self.currentSuggestion
                self.cursorPos = #self.text
                self.currentSuggestion = nil
                self:updateViewOffset()
                if self.onAutocomplete then self.onAutocomplete(self.text) end
                if self.onChange then self.onChange(self.text) end
                UI.markDirty()
            end
            return false
        end,

        onScroll = function(self, direction, mx, my)
            if not self.multiline then return false end
            local maxScroll = math.max(0, #self.lines - self.height)
            self.scrollLine = math.max(0, math.min(maxScroll, self.scrollLine + direction))
            UI.markDirty()
            return true
        end,

        draw = function(self)
            local isFocused = (UI.focused == self)
            local bg = isFocused and self.bgActive or self.bg

            if self.multiline then
                -- Multiline rendering
                local lineNumWidth = self:getLineNumberWidth()
                local contentWidth = self:getContentWidth()

                for screenLine = 0, self.height - 1 do
                    local lineNum = self.scrollLine + screenLine + 1
                    local y = self.y + screenLine

                    -- Draw line number if enabled
                    if self.lineNumbers then
                        UI.term.setCursorPos(self.x, y)
                        UI.term.setBackgroundColor(self.lineNumberBg)
                        UI.term.setTextColor(self.lineNumberFg)

                        if lineNum <= #self.lines then
                            local numText = tostring(lineNum)
                            local padding = lineNumWidth - #numText - 1
                            UI.term.write(string.rep(" ", padding) .. numText .. " ")
                        else
                            UI.term.write(string.rep(" ", lineNumWidth))
                        end
                    end

                    -- Draw line content
                    UI.term.setCursorPos(self.x + lineNumWidth, y)
                    UI.term.setBackgroundColor(bg)
                    UI.term.setTextColor(self.fg)

                    if lineNum <= #self.lines then
                        local lineText = self.lines[lineNum]
                        if #lineText > contentWidth then
                            lineText = lineText:sub(1, contentWidth)
                        else
                            lineText = lineText .. string.rep(" ", contentWidth - #lineText)
                        end
                        UI.term.write(lineText)
                    else
                        UI.term.write(string.rep(" ", contentWidth))
                    end
                end

                -- Position cursor at end of render if focused
                if isFocused and self.cursorLine >= self.scrollLine + 1 and
                   self.cursorLine <= self.scrollLine + self.height then
                    local cursorScreenY = self.y + (self.cursorLine - self.scrollLine - 1)
                    local cursorX = self.x + lineNumWidth + self.cursorCol

                    if cursorX < self.x + self.width then
                        UI._cursorX = cursorX
                        UI._cursorY = cursorScreenY
                        UI._cursorBlink = true
                    end
                end
            else
                -- Single-line rendering
                UI.term.setBackgroundColor(bg)
                UI.term.setCursorPos(self.x, self.y)

                local displayText
                local showPlaceholder = (#self.text == 0 and self.placeholder ~= "" and not isFocused)

                if showPlaceholder then
                    displayText = self.placeholder
                    UI.term.setTextColor(self.placeholderColor)
                else
                    if self.masked then
                        displayText = string.rep(self.maskChar, #self.text)
                    else
                        displayText = self.text
                    end
                    UI.term.setTextColor(self.fg)
                end

                -- Apply view offset for scrolling
                local visibleText
                if #displayText > self.width then
                    visibleText = displayText:sub(self.viewOffset + 1, self.viewOffset + self.width)
                    if self.viewOffset > 0 then
                        visibleText = "<" .. visibleText:sub(2)
                    end
                    if #displayText > self.viewOffset + self.width then
                        visibleText = visibleText:sub(1, -2) .. ">"
                    end
                else
                    visibleText = displayText
                end

                local textToDraw = visibleText
                if #textToDraw < self.width then
                    textToDraw = textToDraw .. string.rep(" ", self.width - #textToDraw)
                end
                UI.term.write(textToDraw)

                -- Draw autocomplete suggestion
                if isFocused and not self.masked and self.currentSuggestion and not showPlaceholder then
                    local suggestionPart = self.currentSuggestion:sub(#self.text + 1)
                    if #suggestionPart > 0 then
                        local suggestionX = self.x + (self.cursorPos - self.viewOffset)
                        if suggestionX < self.x + self.width then
                            local remainingWidth = self.x + self.width - suggestionX
                            local suggestionDisplay = suggestionPart:sub(1, remainingWidth)

                            UI.term.setCursorPos(suggestionX, self.y)
                            UI.term.setBackgroundColor(bg)
                            UI.term.setTextColor(self.suggestionColor)
                            UI.term.write(suggestionDisplay)
                        end
                    end
                end

                -- Position cursor at end of render if focused
                if isFocused then
                    local cursorX = self.x + (self.cursorPos - self.viewOffset)
                    if cursorX >= self.x and cursorX < self.x + self.width then
                        UI._cursorX = cursorX
                        UI._cursorY = self.y
                        UI._cursorBlink = true
                    end
                end
            end
        end
    }

    -- Initialize bounds (x, y, width, height, visible, focusable)
    UI.initBounds(e, opts)

    return UI.addElement(opts.scene or UI.activeScene, e)
end

-------------------------------------------------
-- TERMINAL ELEMENT (TUI Console)
-- Now implemented as a collection of elements (rectangle + textfield)
-------------------------------------------------
function inputs.terminal(opts)
    opts = opts or {}

    -- Resolve colors from theme roles with manual overrides
    local fgColor = opts.fg or UI.resolveColor("text", colors.white)
    local bgColor = opts.bg or UI.resolveColor("background", colors.black)
    local promptColor = opts.promptColor or UI.resolveColor("success", colors.lime)
    local spinnerColor = opts.spinnerColor or UI.resolveColor("info", colors.cyan)

    -- Terminal state
    local lines = opts.lines or {}
    local scrollOffset = 0
    local activePrompt = nil
    local spinner = nil
    local inputField = nil
    local promptLabel = nil
    local spinnerLabel = nil

    -- Create container rectangle
    local terminal = UI.rectangle({
        x = opts.x,
        y = opts.y,
        width = opts.width or 50,
        height = opts.height or 12,
        bg = bgColor,
        border = opts.border,
        position = opts.position,
        xOffset = opts.xOffset,
        yOffset = opts.yOffset,
        scene = opts.scene,
        visible = opts.visible
    })

    -- Store terminal-specific properties
    terminal.type = "terminal"
    terminal.fg = fgColor
    terminal.promptColor = promptColor
    terminal.spinnerColor = spinnerColor
    terminal.lines = lines
    terminal.scrollOffset = scrollOffset

    -- Custom draw to render output lines
    local originalDraw = terminal.draw
    terminal.draw = function(self)
        if self._visible == false then return end

        -- Draw the rectangle background first
        UI.term.setBackgroundColor(bgColor)
        for i = 0, self.height - 1 do
            UI.term.setCursorPos(self.x, self.y + i)
            UI.term.write(string.rep(" ", self.width))
        end

        -- Draw output lines (reserve bottom line for input)
        UI.term.setTextColor(fgColor)
        local linesAvailable = self.height - 1
        local start = math.max(1, #lines - linesAvailable - scrollOffset)
        for i = 0, linesAvailable - 1 do
            local lineIdx = start + i
            if lineIdx > 0 and lineIdx <= #lines then
                local line = lines[lineIdx] or ""
                UI.term.setCursorPos(self.x, self.y + i)
                local displayLine = line:sub(1, self.width)
                displayLine = displayLine .. string.rep(" ", self.width - #displayLine)
                UI.term.write(displayLine)
            end
        end

        -- Draw children (input field, labels, etc.)
        for _, child in ipairs(self.children) do
            if child.draw then child:draw() end
        end
    end

    -- Terminal methods
    terminal.append = function(self, text)
        table.insert(lines, text)
        if #lines > 200 then table.remove(lines, 1) end
        UI.markDirty()
    end

    terminal.clear = function(self)
        lines = {}
        UI.markDirty()
    end

    terminal.prompt = function(self, prefix, callback, opts)
        opts = opts or {}
        local history = opts.history or {}
        local autocomplete = opts.autocomplete or {}
        local historyIndex = #history + 1  -- Start after last item

        -- Ensure children array exists
        if not self.children then
            self.children = {}
        end

        -- Remove any existing input elements
        if inputField then
            inputField._visible = false
        end
        if promptLabel then
            promptLabel._visible = false
        end
        if spinnerLabel then
            spinnerLabel._visible = false
        end

        local prefixText = prefix or ">"
        local prefixLen = #prefixText + 1  -- +1 for space

        -- Create prompt label - add directly to children array without positioning
        promptLabel = {
            type = "label",
            text = prefixText .. " ",
            x = self.x,
            y = self.y + self.height - 1,
            fg = promptColor,
            bg = bgColor,
            _visible = true,
            draw = function(self)
                if self._visible == false then return end
                UI.term.setCursorPos(self.x, self.y)
                UI.term.setBackgroundColor(self.bg)
                UI.term.setTextColor(self.fg)
                UI.term.write(self.text)
            end
        }
        table.insert(self.children, promptLabel)

        -- Create input textfield - use advancedTextField if autocomplete provided
        if #autocomplete > 0 then
            inputField = inputs.advancedTextField({
                width = self.width - prefixLen,
                x = self.x + prefixLen,
                y = self.y + self.height - 1,
                bg = bgColor,
                bgActive = bgColor,
                fg = fgColor,
                autocomplete = autocomplete,
                scene = terminal.scene
            })
        else
            inputField = UI.textfield({
                width = self.width - prefixLen,
                x = self.x + prefixLen,
                y = self.y + self.height - 1,
                bg = bgColor,
                bgActive = bgColor,
                fg = fgColor,
                scene = terminal.scene
            })
        end
        table.insert(self.children, inputField)

        -- Auto-focus the input field
        UI.focused = inputField

        -- Override onKey to handle Enter and Up/Down arrow for history
        local originalOnKey = inputField.onKey
        inputField.onKey = function(field, key)
            local name = keys.getName(key)
            if name == "enter" then
                local text = field.text
                terminal:append(prefixText .. " " .. text)
                inputField._visible = false
                promptLabel._visible = false
                inputField = nil
                promptLabel = nil
                UI.focused = nil
                if callback then callback(text) end
                UI.markDirty()
                return true
            elseif name == "up" then
                -- Navigate up in history (older commands)
                if historyIndex > 1 then
                    historyIndex = historyIndex - 1
                    field.text = history[historyIndex] or ""
                    field.cursorPos = #field.text
                    field:updateViewOffset()
                    UI.markDirty()
                end
                return true
            elseif name == "down" then
                -- Navigate down in history (newer commands)
                if historyIndex < #history then
                    historyIndex = historyIndex + 1
                    field.text = history[historyIndex] or ""
                    field.cursorPos = #field.text
                    field:updateViewOffset()
                    UI.markDirty()
                elseif historyIndex == #history then
                    -- Go to empty line after last history item
                    historyIndex = #history + 1
                    field.text = ""
                    field.cursorPos = 0
                    field:updateViewOffset()
                    UI.markDirty()
                end
                return true
            else
                return originalOnKey(field, key)
            end
        end

        UI.markDirty()
    end

    terminal.startSpinner = function(self, label)
        -- Remove any existing input elements
        if inputField then inputField._visible = false end
        if promptLabel then promptLabel._visible = false end
        if spinnerLabel then spinnerLabel._visible = false end

        -- Create animated spinner label
        local chars = { "|", "/", "-", "\\" }
        local i = 1
        local timer = 0

        spinnerLabel = UI.label({
            text = chars[i] .. " " .. (label or ""),
            x = self.x,
            y = self.y + self.height - 1,
            fg = spinnerColor,
            bg = bgColor
        })
        self:addChild(spinnerLabel)

        -- Add update function to animate
        spinnerLabel.update = function(self, dt)
            timer = timer + dt
            if timer >= 0.15 then
                timer = 0
                i = (i % #chars) + 1
                self.text = chars[i] .. " " .. (label or "")
                return true
            end
            return false
        end

        UI.markDirty()
    end

    terminal.stopSpinner = function(self, finalText)
        if finalText then
            terminal:append(finalText)
        end
        if spinnerLabel then
            spinnerLabel._visible = false
            spinnerLabel = nil
        end
        UI.markDirty()
    end

    -- Handle scroll events
    terminal.onScroll = function(self, direction, mx, my)
        scrollOffset = math.max(0, math.min(scrollOffset + direction, #lines - self.height + 1))
        UI.markDirty()
        return true
    end

    -- Handle clicks - delegate to children or set focus
    terminal.onClick = function(self, mx, my)
        -- Check if clicking on input field
        if inputField and inputField._visible ~= false then
            return inputField:onClick(mx, my)
        end
        return true
    end

    return terminal
end

-------------------------------------------------
-- Return the module
-------------------------------------------------
return inputs