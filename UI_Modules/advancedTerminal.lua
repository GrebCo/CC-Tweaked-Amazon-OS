
-- Advanced Terminal v4
-- Self-contained terminal element for newui.lua
--
-- Features:
--  * Rich color spans with inline tags: <fg:color>, </fg>, <bg:color>, </bg>, <id:name>, </id>, <reset>
--  * Word wrapping to width
--  * Prompt + input buffer with LEFT/RIGHT cursor movement, mid-line edits
--  * History on UP/DOWN
--  * Line-by-line scrollback via mouse wheel and PageUp/PageDown
--  * Bottom-up rendering (newest content at the bottom); prompt fixed at bottom
--  * Scrolling disables autoScroll until user types or presses Enter
--  * Click to focus for keyboard input
--
-- Usage:
--   local ui = dofile("newui.lua")
--   local advterm = dofile("advancedTerminal.lua")
--
--   ui.init({functions = {log = print}, scenes = {}})
--   ui.newScene("main")
--   ui.setScene("main")
--
--   local term = advterm.create({
--     ui = ui,  -- Required for click-to-focus
--     position = "center",
--     width = 50,
--     height = 16,
--     fg = colors.white,
--     bg = colors.black,
--     wrap = true,
--     prompt = "> ",
--     onCommand = function(self, input)
--       if input == "hello" then
--         self:printLine("<fg:cyan>Hello, world!</fg>")
--       end
--     end
--   })
--
--   ui.addElement("main", term)
--   term:printLine("<fg:yellow>Welcome!</fg>")
--
--   while true do ui.tick() end
--
-- API Methods:
--   term:printLine(markup)  - Print line with color tags
--   term:append(markup)     - Append text with wrapping (no newline)
--   term:newline()          - Start new line
--   term:clear()            - Clear all content
--   term:set(id, patch)     - Update text/colors by ID
--   term:get(id)            - Get segment reference by ID
--   term:setScroll(offset)  - Manually set scroll position
--
-- Markup Tags:
--   <fg:red>text</fg>       - Colored text (supports all CC colors)
--   <bg:blue>text</bg>      - Background color
--   <id:name>text</id>      - ID for dynamic updates
--   <reset>                 - Reset all formatting
--
-- Differences from newui.lua's default terminal:
--   - Always shows prompt (no prompt()/callback pattern)
--   - Uses onCommand callback instead
--   - Supports rich text markup
--   - Has command history
--   - Bottom-up rendering vs top-down

local advterm = {}

local C = colors
local COLOR_MAP = {
  black=C.black, white=C.white,
  red=C.red, orange=C.orange, yellow=C.yellow,
  green=C.green, lime=C.lime or C.green,
  cyan=C.cyan, blue=C.blue, lightBlue=C.lightBlue or C.blue,
  purple=C.purple, magenta=C.magenta or C.purple, pink=C.pink or C.magenta or C.purple,
  brown=C.brown or C.orange,
  gray=C.gray, lightGray=C.lightGray or C.gray,
}

local function color_from_name(name, fallback)
  return COLOR_MAP[name] or fallback
end

local function clamp(v,a,b) if v<a then return a elseif v>b then return b end; return v end

-- Create terminal element
function advterm.create(opts)
  opts = opts or {}
  local self = {
    type = "advterm",
    -- layout (newui will place x,y)
    position = opts.position or "topleft",
    xOffset = opts.xOffset or 0, yOffset = opts.yOffset or 0,
    width = opts.width or 50, height = opts.height or 16,

    -- colors & wrapping
    defaultFG = opts.fg or C.white, defaultBG = opts.bg or C.black,
    wrap = (opts.wrap ~= false),

    -- prompt + input
    prompt = opts.prompt or "> ",
    buffer = "",
    cursorPos = 0, -- number of chars to the LEFT of the cursor (0..#buffer)
    cursorVisible = true, cursorTimer = 0,

    -- history
    history = {}, historyIndex = 0,

    -- content lines (each line = array of segments: {text, fg, bg, id?})
    lines = {{}}, idIndex = {},

    -- scrollback
    scroll = 0, autoScroll = true,  -- scroll = how many lines from the bottom (0 = bottom)

    -- command callback
    onCommand = opts.onCommand or function() end,

    -- ui reference (for focus management)
    _ui = opts.ui,
  }

  -- ---------- helpers ----------
  function self:_lineLen(i)
    local l = self.lines[i] or {}; local n = 0
    for _,s in ipairs(l) do n = n + #s.text end
    return n
  end

  function self:_contentHeight()
    return math.max(1, self.height - 1) -- last line reserved for prompt
  end

  function self:_maxScroll()
    local total = #self.lines
    local vis = self:_contentHeight()
    local extra = total - vis
    if extra < 0 then extra = 0 end
    return extra
  end

  function self:_scrollToBottomIfAuto()
    if self.autoScroll then self.scroll = 0 end
  end

  function self:clear()
    self.lines = {{}}
    self.idIndex = {}
    self.scroll = 0
  end

  function self:newline()
    table.insert(self.lines, {})
    self:_scrollToBottomIfAuto()
  end

  function self:get(id) return self.idIndex[id] end

  function self:set(id, patch)
    local ref = self.idIndex[id]; if not ref then return false end
    local seg = ref.data
    if type(patch)=="string" then seg.text = patch
    else for k,v in pairs(patch) do seg[k]=v end end
    return true
  end

  function self:setScroll(off)
    self.autoScroll = false
    local m = self:_maxScroll()
    self.scroll = clamp(math.floor(off or 0), 0, m)
  end

  -- emit a single colored span segment to current (last) line
  local function emit_segment(self, text, fg, bg, id)
    if text == "" then return end
    local line = self.lines[#self.lines]
    table.insert(line, { text=text, fg=fg, bg=bg, id=id })
    if id then
      self.idIndex[id] = { line = #self.lines, seg = #line, data = line[#line] }
    end
  end

  -- push text with wrapping and embedded \n
  local function push_wrapped(self, text, fg, bg, id)
    local start = 1
    while true do
      local ni = string.find(text, "\n", start, true)
      local chunk
      if ni then chunk = string.sub(text, start, ni-1) else chunk = string.sub(text, start) end

      if self.wrap then
        local remaining = chunk
        while #remaining > 0 do
          local spaceLeft = self.width - self:_lineLen(#self.lines)
          if spaceLeft <= 0 then
            self:newline()
            spaceLeft = self.width
          end
          if #remaining <= spaceLeft then
            emit_segment(self, remaining, fg, bg, id); id=nil; break
          end
          local slice = string.sub(remaining, 1, spaceLeft)
          local breakPos = string.match(slice, ".*()%s")
          if breakPos and breakPos > 0 then
            local first = string.sub(remaining, 1, breakPos)
            emit_segment(self, first, fg, bg, id); id=nil
            remaining = string.sub(remaining, breakPos+1)
          else
            local first = string.sub(remaining, 1, spaceLeft)
            emit_segment(self, first, fg, bg, id); id=nil
            remaining = string.sub(remaining, spaceLeft+1)
          end
        end
      else
        emit_segment(self, chunk, fg, bg, id); id=nil
      end

      if not ni then break else self:newline(); start = ni + 1 end
    end
    self:_scrollToBottomIfAuto()
  end

  -- tokenizer with nesting: <fg:color>, </fg>, <bg:color>, </bg>, <id:name>, </id>, <reset>
  function self:append(markup)
    local i, len = 1, #markup
    local currFG, currBG = self.defaultFG, self.defaultBG
    local fgStack, bgStack = {}, {}
    local idCurrent = nil
    local function pushFG(v) table.insert(fgStack, currFG); currFG=v end
    local function popFG() currFG = table.remove(fgStack) or self.defaultFG end
    local function pushBG(v) table.insert(bgStack, currBG); currBG=v end
    local function popBG() currBG = table.remove(bgStack) or self.defaultBG end

    while i <= len do
      local lt = string.find(markup, "<", i, true)
      if not lt then
        push_wrapped(self, string.sub(markup, i), currFG, currBG, idCurrent)
        break
      end
      if lt > i then
        push_wrapped(self, string.sub(markup, i, lt-1), currFG, currBG, idCurrent)
      end
      local gt = string.find(markup, ">", lt+1, true)
      if not gt then
        push_wrapped(self, string.sub(markup, lt), currFG, currBG, idCurrent)
        break
      end
      local tag = string.sub(markup, lt+1, gt-1)
      tag = tag:gsub("^%s+",""):gsub("%s+$","")
      local lower = string.lower(tag)

      if lower == "reset" then
        currFG, currBG = self.defaultFG, self.defaultBG
        fgStack, bgStack = {}, {}
      elseif lower:sub(1,1) == "/" then
        local tname = lower:sub(2)
        if tname == "fg" then popFG()
        elseif tname == "bg" then popBG()
        elseif tname == "id" then idCurrent = nil
        end
      else
        local key, val = lower:match("^([^:]+)%s*:%s*(.+)$")
        if key == "fg" and val then
          pushFG(color_from_name(val, currFG))
        elseif key == "bg" and val then
          pushBG(color_from_name(val, currBG))
        elseif key == "id" and val then
          idCurrent = val
        else
          -- unknown tag, ignore
        end
      end
      i = gt + 1
    end
  end

  function self:printLine(markup)
    self:append(markup)
    -- No implicit extra blank line: do NOT add another newline here.
    -- Just start a fresh line for subsequent output.
    self:newline()
  end

  -- ---------- input handling ----------
  function self:update(dt)
    self.cursorTimer = self.cursorTimer + dt
    if self.cursorTimer >= 0.5 then
      self.cursorVisible = not self.cursorVisible
      self.cursorTimer = 0
    end
  end

  function self:focus()
    -- when user starts typing, snap back to bottom
    self.autoScroll = true
    self.scroll = 0
  end

  function self:onChar(ch)
    -- typing re-enables auto scroll
    self.autoScroll = true; self.scroll = 0
    -- insert at cursor
    local left = self.buffer:sub(1, self.cursorPos)
    local right = self.buffer:sub(self.cursorPos+1)
    self.buffer = left .. ch .. right
    self.cursorPos = self.cursorPos + #ch
  end

  function self:onKey(key)
    local name = keys.getName(key)
    if name == "left" then
      if self.cursorPos > 0 then self.cursorPos = self.cursorPos - 1 end
    elseif name == "right" then
      if self.cursorPos < #self.buffer then self.cursorPos = self.cursorPos + 1 end
    elseif name == "home" then
      self.cursorPos = 0
    elseif name == "end" then
      self.cursorPos = #self.buffer
    elseif name == "backspace" then
      if self.cursorPos > 0 then
        local left = self.buffer:sub(1, self.cursorPos-1)
        local right = self.buffer:sub(self.cursorPos+1)
        self.buffer = left .. right
        self.cursorPos = self.cursorPos - 1
      end
    elseif name == "delete" then
      if self.cursorPos < #self.buffer then
        local left = self.buffer:sub(1, self.cursorPos)
        local right = self.buffer:sub(self.cursorPos+2)
        self.buffer = left .. right
      end
    elseif name == "enter" then
      local input = self.buffer
      if input ~= "" then
        table.insert(self.history, input)
      end
      self.historyIndex = #self.history + 1
      self:printLine(self.prompt .. input)
      self.buffer = ""
      self.cursorPos = 0
      -- submitting re-enables autoScroll
      self.autoScroll = true; self.scroll = 0
      self:onCommand(input)
      -- NOTE: no extra blank line after command output
    elseif name == "up" then
      if #self.history > 0 then
        if self.historyIndex <= 1 then
          self.historyIndex = 1
        else
          self.historyIndex = self.historyIndex - 1
        end
        self.buffer = self.history[self.historyIndex] or ""
        self.cursorPos = #self.buffer
      end
    elseif name == "down" then
      if #self.history > 0 then
        if self.historyIndex >= #self.history then
          self.historyIndex = #self.history + 1
          self.buffer = ""
        else
          self.historyIndex = self.historyIndex + 1
          self.buffer = self.history[self.historyIndex] or ""
        end
        self.cursorPos = #self.buffer
      end
    elseif name == "pageUp" then
      -- Scroll up by one page (show older content)
      local pageSize = math.max(1, self:_contentHeight())
      self:setScroll(self.scroll + pageSize)
    elseif name == "pageDown" then
      -- Scroll down by one page (show newer content)
      local pageSize = math.max(1, self:_contentHeight())
      self:setScroll(self.scroll - pageSize)
    end
  end

  -- mouse wheel support (dir: -1=up in history, 1=down toward bottom)
  -- Note: scroll UP (dir=-1) shows OLDER content (increase scroll offset)
  --       scroll DOWN (dir=1) shows NEWER content (decrease scroll offset)
  function self:onScroll(dir, x, y)
    if dir == -1 then
      -- Scroll wheel UP = see older content
      self:setScroll(self.scroll + 1)
    elseif dir == 1 then
      -- Scroll wheel DOWN = see newer content
      self:setScroll(self.scroll - 1)
    end
  end

  -- click to focus (for keyboard input)
  function self:onClick(x, y)
    -- Set focus to this terminal when clicked (requires ui reference)
    -- Will be set by the framework when element is added
    if self._ui then
      self._ui.focused = self
    end
    return true  -- Mark click as handled
  end

  -- ---------- draw (bottom-up) ----------
  function self:draw()
    local ox, oy = self.x or 1, self.y or 1
    local w, h = self.width, self.height
    local contentH = self:_contentHeight()

    -- clear region
    term.setBackgroundColor(self.defaultBG)
    term.setTextColor(self.defaultFG)
    for yy=0,h-1 do
      term.setCursorPos(ox, oy + yy)
      term.write(string.rep(" ", w))
    end

    -- determine visible content range (bottom-up)
    local total = #self.lines
    local startIndex = math.max(1, total - self.scroll - contentH + 1)
    local endIndex = math.max(1, math.min(total, total - self.scroll))

    -- render from bottom row upward
    local row = contentH
    for li = endIndex, startIndex, -1 do
      local x = 0
      local line = self.lines[li]
      if row <= 0 then break end
      -- render spans left-to-right on this terminal row
      for _, seg in ipairs(line) do
        local text = seg.text
        local remain = w - x
        if remain <= 0 then break end
        if #text > remain then text = text:sub(1, remain) end
        term.setTextColor(seg.fg or self.defaultFG)
        term.setBackgroundColor(seg.bg or self.defaultBG)
        term.setCursorPos(ox + x, oy + row - 1)
        term.write(text)
        x = x + #text
        if x >= w then break end
      end
      row = row - 1
    end

    -- draw prompt on last line
    local promptStr = self.prompt .. self.buffer
    -- ensure cursor is visible: we don't horizontally scroll for now, we clip end
    local display = promptStr
    if #display > w then
      -- show tail so typing feels natural
      display = display:sub(#display - w + 1)
    end
    term.setBackgroundColor(self.defaultBG)
    term.setTextColor(self.defaultFG)
    term.setCursorPos(ox, oy + h - 1)
    term.write(display:sub(1, w))

    -- draw cursor at correct screen position (relative to clipped display)
    local cursorChar = self.cursorVisible and "_" or " "
    local cursorIndex = #self.prompt + self.cursorPos
    local screenX = cursorIndex - math.max(0, #promptStr - w)
    if screenX < 0 then screenX = 0 end
    if screenX >= w then screenX = w - 1 end
    term.setCursorPos(ox + math.max(0, screenX), oy + h - 1)
    term.write(cursorChar)
  end

  if #self.lines == 0 then table.insert(self.lines, {}) end
  return self
end

return advterm
