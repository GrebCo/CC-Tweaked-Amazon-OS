-- MiniMark v0.92 (Spec-Conformant) for CC:Tweaked
-- Drop-in renderer + tokenizer with UI registry output
-- Implements: line-based blocks, persistent attributes (fg/bg/id/fillBg), <hr>, <br>,
-- escape sequences (\\, \<, \>, \"), links (3 forms), buttons, checkboxes, textboxes,
-- script extraction with optional @EventName annotations or event:"Name" attribute.
--
-- This is a structural rewrite to simplify parsing and clearly separate:
--   1) Preprocess (escapes)  2) Tokenization to logical lines  3) Layout/Render  4) Script extraction
--
-- Exported API:
--   renderPage(path, scroll?, startY?) -> uiRegistry, lastY
--   getScripts(path) -> { {event?<string>, code<string>}, ... }
--   getAlignment(line) -> "left"|"center"|"right", cleanedLine
--   stripTags(line) -> line with <...> removed
--   loadPage(path) -> { lines }
--
-- Notes:
--   • Links support: <link "Target","Label">, <link "Target">, <link target:"T" label:"L" fg:color bg:color>
--   • <textbox> supports width:"N", id:"...", fg/bg, blinkChar:"_"
--   • <button> supports label:"...", fg/bg, pressFg/pressBg, id:"...", onClick:EventName
--   • <checkbox> supports label:"...", boxChecked:"[X]", boxUnchecked:"[ ]", id:"...", onClick:EventName
--   • <id:"..."> applies to subsequent text/inline elements until reset/newline
--   • <fg:color>/<bg:color> are aliases for <text:color>/<background:color>
--   • <fillBg:color> fills entire line with background color (persists across lines)
--   • <fillBg:reset> removes line fill
--   • <reset> resets fg/bg/id to defaults (but NOT fillBg)
--   • <hr:"--+"> repeats pattern across terminal width
--   • <br> inserts a blank line
--
-- Rendering: returns uiRegistry entries like { y = Y, element = {type="button"|..., x, y, width, ...} }

-- Maps color names to their corresponding color values
local colorMap = {
  white = colors.white, gray = colors.gray, lightGray = colors.lightGray, black = colors.black,
  red = colors.red, green = colors.green, blue = colors.blue, yellow = colors.yellow, cyan = colors.cyan,
  magenta = colors.magenta, orange = colors.orange, lime = colors.lime, lightBlue = colors.lightBlue,
  pink = colors.pink, brown = colors.brown, purple = colors.purple
}

---------------------------------------------------------------------
-- Utilities
---------------------------------------------------------------------

local function protectEscapes(s)
  s = s:gsub("\\\\", "__MM_BS__")
  s = s:gsub("\\<", "__MM_LT__")
  s = s:gsub("\\>", "__MM_GT__")
  s = s:gsub('\\"', "__MM_QUOTE__")
  return s
end

local function restoreEscapes(s)
  s = s:gsub("__MM_LT__", "<")
  s = s:gsub("__MM_GT__", ">")
  s = s:gsub("__MM_QUOTE__", '"')
  s = s:gsub("__MM_BS__", "\\")
  return s
end


local function loadLinesFromFile(path)
  local f = fs.open(path, "r")
  if not f then error("Could not open " .. path) end
  local lines = {}
  for line in function() return f.readLine() end do
    table.insert(lines, line)
  end
  f.close()
  return lines
end

-- Remove all <...> tags (used for text-only extractions)
local function stripTags(line)
  return (line:gsub("%<.-%>", ""))
end

-- Alignment by leading #, returns align + line with the # removed
local function getAlignment(line)
  if line:match("^###") then
    return "right", line:sub(4)
  elseif line:match("^##") then
    return "center", line:sub(3)
  elseif line:match("^#") then
    return "left", line:sub(2)
  else
    return "left", line
  end
end

-- Preprocess escapes: \\ -> \, \< -> <, \> -> >, \" -> "
-- (No \n inline-breaks per user's latest note)
-- Parse attributes in colon syntax with optional quotes:
--   key:"value"  key:value   key:"val with spaces"
-- Returns table and also the baseName (first word before any whitespace/colon chain)
local function parseTag(tagInner)
  -- normalize inner spacing
  local s = tagInner:gsub("^%s+", ""):gsub("%s+$", "")

  -- Extract tag name: first contiguous word before any space or colon
  local name = s:match("^([%w]+)")
  if not name then return nil, {} end
  local rest = s:sub(#name + 1)

  local attrs = {}

  -- Handle shorthand for <text:color>, <background:color>, <fg:color>, <bg:color>
  -- Also handle constructs like <hr:"--+"> or <link "Target","Label"> without keys.
  -- We'll tokenize positional arguments while also scanning key:value pairs.

  -- First, collect quoted positional strings: "value" or 'value'
  local posArgs = {}
  for quoted in rest:gmatch("%b\"\"") do
    table.insert(posArgs, quoted:sub(2, -2))
  end

  -- If no double-quoted, try single quotes too (rare in CC but supported)
  if #posArgs == 0 then
    for quoted in rest:gmatch("%b''") do
      table.insert(posArgs, quoted:sub(2, -2))
    end
  end

  -- Key:value or key:"value"
  for key, val in rest:gmatch("([%w]+)%s*:%s*\"([^\"]*)\"") do
    attrs[key] = val
  end
  for key, val in rest:gmatch("([%w]+)%s*:%s*([%w_%-]+)") do
    if attrs[key] == nil then
      attrs[key] = val
    end
  end

  return name, attrs, posArgs
end

-- Split visible text into runs of words/spaces for wrapping
local function splitTextRuns(text)
  local runs = {}
  local leading = text:match("^(%s+)")
  if leading then
    table.insert(runs, {type="space", text=leading, width=#leading})
    text = text:sub(#leading + 1)
  end
  for word, space in text:gmatch("(%S+)(%s*)") do
    table.insert(runs, {type="word", text=word, width=#word})
    if #space > 0 then
      table.insert(runs, {type="space", text=space, width=#space})
    end
  end
  if #runs == 0 and #text > 0 then
    table.insert(runs, {type="space", text=text, width=#text})
  end
  return runs
end

---------------------------------------------------------------------
-- Tokenization: Lines -> Logical Blocks
---------------------------------------------------------------------

-- Renderer state that persists within a single line
local function defaultState()
  return {
    fg = colors.white,
    bg = colors.black,
    id = nil,
  }
end

-- Produces a sequence of logical entries:
--   { type="line", align="left|center|right", elements={...} }
--   { type="blank" }
--   { type="hr", pattern="--+" }
-- Script regions are skipped from visual output.
local function parsePageToLogicalLines(path)
  local rawLines = loadLinesFromFile(path)
  local logical = {}

  local inScript = false
  local currentFillBg = nil  -- Persistent fill background across lines

  for _, raw in ipairs(rawLines) do
    local line = protectEscapes(raw or "")

    -- script begin / end (visual renderer skips contents)
    local startTag = line:match("<%s*script[^>]*>")
    local endTag   = line:match("</%s*script%s*>")

    if startTag then
      inScript = true
    elseif endTag then
      inScript = false
    elseif inScript then
      -- skip script content from visual rendering
    else
      if line:find("^%s*$") then
        table.insert(logical, {type="blank", fillBg=currentFillBg})
      else
        -- Check for structural single-line tags first: <hr:"..."> or <br>
        local structural = line:match("^%s*<%s*hr[^>]*>%s*$")
        if structural then
          local _, attrs, posArgs = parseTag(line:match("<(.-)>"))
          local pattern = attrs[1] or (posArgs[1] or "-")
          table.insert(logical, {type="hr", pattern = pattern ~= "" and pattern or "-", fillBg=currentFillBg})
        elseif line:match("^%s*<%s*br%s*>%s*$") then
          table.insert(logical, {type="blank", fillBg=currentFillBg})
        else
          local align, body = getAlignment(line)
          local st = defaultState()
          local elements = {}

          local pos = 1
          while pos <= #body do
            local tagStart, tagEnd, inner = body:find("<(.-)>", pos)
            if tagStart then
              -- text before this tag
              if tagStart > pos then
                local txt = body:sub(pos, tagStart - 1)
                if #txt > 0 then
                  table.insert(elements, {type="text", text=restoreEscapes(txt), fg=st.fg, bg=st.bg, id=st.id})
                end
              end

              -- process tag
              local name, attrs, posArgs = parseTag(inner or "")
              name = name or ""

              -- Aliases + reset + persistent id
              if name == "text" or name == "fg" then
                -- shorthand <text:green> OR key color:"green"
                local colorKey = attrs.color or attrs[1] or posArgs[1] or inner:match("^text:%s*([%w]+)")
                if colorKey == "reset" then
                  st.fg = colors.white
                else
                  st.fg = colorMap[colorKey] or colors.white
                end
              elseif name == "background" or name == "bg" then
                local colorKey = attrs.color or attrs[1] or posArgs[1] or inner:match("^background:%s*([%w]+)")
                if colorKey == "reset" then
                  st.bg = colors.black
                else
                  st.bg = colorMap[colorKey] or colors.black
                end
              elseif name == "fillBg" then
                local colorKey = attrs.color or attrs[1] or posArgs[1] or inner:match("^fillBg:%s*([%w]+)")
                if colorKey == "reset" then
                  currentFillBg = nil
                else
                  currentFillBg = colorMap[colorKey] or nil
                end
              elseif name == "reset" then
                st = defaultState()
              elseif name == "id" then
                local idv = attrs[1] or attrs.id or posArgs[1]
                if not idv then idv = inner:match('^id:%s*"(.-)"') end
                -- Starting a new persistent attribute mid-line => new block (spec)
                -- We'll emulate this by inserting a soft line break marker
                if #elements > 0 then
                  table.insert(elements, {type="softbreak"})
                end
                st.id = idv

              elseif name == "link" then
                -- three forms
                local target, label, lfg, lbg
                if #posArgs >= 1 then
                  target = posArgs[1]
                  label = posArgs[2] or target
                else
                  target = attrs.target or attrs[1]
                  label  = attrs.label or attrs[2] or target
                end
                lfg = attrs.fg and (colorMap[attrs.fg] or colors.lightBlue) or colors.lightBlue
                lbg = attrs.bg and (colorMap[attrs.bg] or colors.lightGray) or colors.lightGray

                table.insert(elements, {
                  type="link",
                  label=restoreEscapes(label or ""),
                  target=target or "",
                  fg=lfg, bg=lbg, id=st.id,
                })

              elseif name == "button" then
                local label = restoreEscapes(attrs.label or attrs[1] or "Button")
                local fg = attrs.fg and (colorMap[attrs.fg] or st.fg) or st.fg
                local bg = attrs.bg and (colorMap[attrs.bg] or st.bg) or st.bg

                local meta = {
                  pressFg = attrs.pressFg and colorMap[attrs.pressFg] or nil,
                  pressBg = attrs.pressBg and colorMap[attrs.pressBg] or nil,
                  id = attrs.id or st.id,
                  onClick = attrs.onClick
                }
                table.insert(elements, {
                  type="button", label=label, fg=fg, bg=bg, meta=meta, id=meta.id
                })

              elseif name == "checkbox" then
                local label = restoreEscapes(attrs.label or attrs[1] or "Checkbox")
                local fg = attrs.fg and (colorMap[attrs.fg] or st.fg) or st.fg
                local bg = attrs.bg and (colorMap[attrs.bg] or st.bg) or st.bg
                local meta = {
                  id = attrs.id or st.id,
                  onClick = attrs.onClick,
                  boxChecked = attrs.boxChecked or "[x]",
                  boxUnchecked = attrs.boxUnchecked or "[ ]",
                }
                table.insert(elements, {
                  type="checkbox", label=label, fg=fg, bg=bg, meta=meta, id=meta.id
                })

              elseif name == "textbox" then
                local width = tonumber(attrs.width or attrs[1] or posArgs[1]) or 10
                local fg = attrs.fg and (colorMap[attrs.fg] or st.fg) or st.fg
                local bg = attrs.bg and (colorMap[attrs.bg] or st.bg) or st.bg
                local meta = {
                  id = attrs.id or st.id,
                  blinkChar = attrs.blinkChar or "_",
                  onEnter = attrs.onEnter,
                }
                table.insert(elements, {
                  type="textbox", width=width, fg=fg, bg=bg, meta=meta, id=meta.id
                })
              end

              pos = tagEnd + 1
            else
              -- trailing text
              local txt = body:sub(pos)
              if #txt > 0 then
                table.insert(elements, {type="text", text=restoreEscapes(txt), fg=st.fg, bg=st.bg, id=st.id})
              end
              break
            end
          end

          -- Insert as a logical line
          table.insert(logical, {type="line", align=align, elements=elements, fillBg=currentFillBg})
        end
      end
    end
  end

  return logical
end

---------------------------------------------------------------------
-- Layout & Render (token -> terminal + UI registry)
---------------------------------------------------------------------

-- Build display fragments for a line
local function lineElementsToFragments(elements)
  local frags = {}
  for _, el in ipairs(elements) do
    if el.type == "softbreak" then
      -- represent as zero-width separator handled by wrapper (start a new physical line)
      table.insert(frags, {type="softbreak"})
    elseif el.type == "text" then
      for _, r in ipairs(splitTextRuns(el.text)) do
        table.insert(frags, {type=r.type, text=r.text, width=r.width, fg=el.fg, bg=el.bg, id=el.id})
      end
    elseif el.type == "link" then
      local disp = el.label or ""
      table.insert(frags, {type="link", text=disp, width=#disp, fg=el.fg, bg=el.bg, meta=el})
    elseif el.type == "button" then
      local disp = el.label or "Button"
      table.insert(frags, {type="button", text=disp, width=#disp, fg=el.fg, bg=el.bg, meta=el.meta})
    elseif el.type == "checkbox" then
      local box = (el.meta.boxUnchecked or "[ ]")
      local disp = box .. " " .. (el.label or "")
      table.insert(frags, {type="checkbox", text=disp, width=#disp, fg=el.fg, bg=el.bg, meta=el.meta, label=el.label})
    elseif el.type == "textbox" then
      local disp = (" "):rep(el.width or 10)
      table.insert(frags, {type="textbox", text=disp, width=(el.width or 10), fg=el.fg, bg=el.bg, meta=el.meta})
    end
  end
  return frags
end

-- NEW: Convert logical lines to physical lines (word-wrapped, aligned)
-- This is the EXPENSIVE part - do once per page, cache the result
-- Returns a flat list of physical lines ready to render
local function layoutFromTokens(logical, maxWidth)
  local termWidth = maxWidth or term.getSize()
  local physicalLines = {}

  for _, entry in ipairs(logical) do
    if entry.type == "blank" then
      table.insert(physicalLines, {type = "blank", fillBg = entry.fillBg})

    elseif entry.type == "hr" then
      local pattern = entry.pattern or "-"
      local rep = ""
      if #pattern == 0 then pattern = "-" end
      while #rep < termWidth do
        rep = rep .. pattern
      end
      rep = rep:sub(1, termWidth)
      table.insert(physicalLines, {
        type = "hr",
        text = rep,
        fg = colors.white,
        bg = colors.black,
        fillBg = entry.fillBg
      })

    elseif entry.type == "line" then
      -- Compose fragments
      local frags = lineElementsToFragments(entry.elements)

      -- Wrap into physical lines (consider softbreak markers)
      local physLines = {}
      local cur, w = {}, 0
      local function pushLine()
        if #cur > 0 then table.insert(physLines, cur) end
        cur, w = {}, 0
      end

      for _, f in ipairs(frags) do
        if f.type == "softbreak" then
          pushLine()
        else
          if (f.type == "word" or f.type == "link" or f.type == "button") and f.width > termWidth then
            -- split long segments across lines
            local t = f.text
            local i = 1
            while i <= #t do
              local chunk = t:sub(i, i + termWidth - 1)
              local cf = {type=f.type == "word" and "word" or f.type, text=chunk, width=#chunk, fg=f.fg, bg=f.bg, meta=f.meta}
              if w + cf.width <= termWidth then
                table.insert(cur, cf); w = w + cf.width
              else
                pushLine(); table.insert(cur, cf); w = cf.width
              end
              i = i + termWidth
            end
          else
            if w + (f.width or 0) <= termWidth then
              table.insert(cur, f); w = w + (f.width or 0)
            else
              pushLine(); table.insert(cur, f); w = f.width or 0
            end
          end
        end
      end
      pushLine()

      -- Calculate alignment for each physical line
      for _, pl in ipairs(physLines) do
        local total = 0
        for _, f in ipairs(pl) do total = total + (f.width or 0) end

        local baseX = 1
        if entry.align == "center" then
          baseX = math.max(1, math.floor((termWidth - total)/2) + 1)
        elseif entry.align == "right" then
          baseX = math.max(1, termWidth - total + 1)
        end

        -- Store physical line with pre-calculated positions
        table.insert(physicalLines, {
          type = "text",
          fragments = pl,
          baseX = baseX,
          align = entry.align,
          fillBg = entry.fillBg
        })
      end
    end
  end

  return physicalLines
end

-- NEW: Fast render from pre-calculated physical lines
-- This is FAST (<1ms) - just draws, no calculations
-- Respects element bounds (x, y, width, height)
local function renderFromPhysicalLines(physicalLines, scroll, startY, elemX, elemWidth, elemHeight)
  elemX = elemX or 1
  elemWidth = elemWidth or term.getSize()
  elemHeight = elemHeight or select(2, term.getSize())

  local y = (startY or 1) - (scroll or 0)
  local registry = {}
  local endY = startY + elemHeight - 1  -- Bottom boundary

  for _, pline in ipairs(physicalLines) do
    -- Skip lines above viewport
    if y < startY then
      if pline.type == "blank" or pline.type == "hr" or pline.type == "text" then
        y = y + 1
      end
      goto continue
    end

    -- Stop rendering below viewport
    if y > endY then
      break
    end

    if pline.type == "blank" then
      if pline.fillBg then
        paintutils.drawLine(elemX, y, elemX + elemWidth - 1, y, pline.fillBg)
      end
      y = y + 1

    elseif pline.type == "hr" then
      if pline.fillBg then
        paintutils.drawLine(elemX, y, elemX + elemWidth - 1, y, pline.fillBg)
      end
      term.setCursorPos(elemX, y)
      term.setTextColor(pline.fg)

      -- Use fillBg if hr bg is default black and fillBg is set
      local bgColor = pline.bg
      if pline.fillBg and bgColor == colors.black then
        bgColor = pline.fillBg
      end
      term.setBackgroundColor(bgColor)

      -- Clip to element width
      local hrText = pline.text:sub(1, elemWidth)
      write(hrText)
      y = y + 1

    elseif pline.type == "text" then
      if pline.fillBg then
        paintutils.drawLine(elemX, y, elemX + elemWidth - 1, y, pline.fillBg)
      end

      local x = pline.baseX + elemX - 1  -- Offset by element's x position
      for _, f in ipairs(pline.fragments) do
        -- Clip fragments that exceed element width
        if x - elemX + 1 > elemWidth then
          break  -- Rest of line is outside bounds
        end

        term.setCursorPos(x, y)
        term.setTextColor(f.fg or colors.white)

        -- Use fillBg if fragment bg is default black and fillBg is set
        local bgColor = f.bg or colors.black
        if pline.fillBg and bgColor == colors.black then
          bgColor = pline.fillBg
        end
        term.setBackgroundColor(bgColor)

        -- Clip text to remaining width
        local remainingWidth = elemWidth - (x - elemX)
        local text = f.text
        if #text > remainingWidth then
          text = text:sub(1, remainingWidth)
        end

        if f.type == "word" or f.type == "space" then
          write(text)

        elseif f.type == "link" then
          write(text)
          table.insert(registry, { y = y, element = {
            type="link", x=x, y=y, width=math.min(f.width, remainingWidth), target=f.meta.target, label=f.text
          }})

        elseif f.type == "button" then
          write(text)
          local meta = f.meta or {}
          table.insert(registry, { y = y, element = {
            type="button", x=x, y=y, width=math.min(f.width, remainingWidth), label=f.text,
            id=meta.id, onClick=meta.onClick, pressFg=meta.pressFg, pressBg=meta.pressBg,
            fg=f.fg, bg=f.bg
          }})

        elseif f.type == "checkbox" then
          write(text)
          local meta = f.meta or {}
          table.insert(registry, { y = y, element = {
            type="checkbox", x=x, y=y, width=math.min(f.width, remainingWidth), label=(f.label or (meta and meta.label) or ""), id=meta.id,
            checked=false, boxChecked=meta.boxChecked, boxUnchecked=meta.boxUnchecked, fg=f.fg, bg=f.bg
          }})

        elseif f.type == "textbox" then
          write(text)
          local meta = f.meta or {}
          table.insert(registry, { y = y, element = {
            type="textbox", x=x, y=y, width=math.min(f.width, remainingWidth), value="", id=meta.id,
            blinkChar=meta.blinkChar or "_", fg=f.fg, bg=f.bg, onEnter=meta.onEnter
          }})
        end

        x = x + (f.width or 0)
      end
      y = y + 1
    end

    ::continue::
  end

  return registry, y + (startY or 1)
end

---------------------------------------------------------------------
-- Script Extraction
---------------------------------------------------------------------

-- getScripts(path) -> array of { event?<string>, code<string> }
-- Accepts:
--   <script event:"ConfirmStuff"> ... </script>
--   <script> @ConfirmStuff  function ... end </script>
local function getScripts(path)
  local lines = loadLinesFromFile(path)
  local scripts = {}

  local inScript = false
  local current = {}
  local currentEvent = nil

  local function commit()
    if #current > 0 then
      local code = table.concat(current, "\n")
      table.insert(scripts, {event=currentEvent, code=code})
    end
    current = {}
    currentEvent = nil
  end

  for _, raw in ipairs(lines) do
    local line = raw

    if not inScript then
      local start = line:match("<%s*script(.-)>")
      if start then
        -- detect event:"Name" in the start tag (colon syntax or classic attr syntax)
        local _, attrs = (function()
          -- reuse parseTag on the inner of the start tag
          local inner = line:match("<(script.-)>")
          if inner then
            return parseTag(inner)
          end
          return nil, {}
        end)()

        if attrs and type(attrs) == "table" then
          currentEvent = attrs.event
        end

        inScript = true
      end
    else
      if line:match("</%s*script%s*>") then
        -- end script
        commit()
        inScript = false
      else
        -- capture, also check for @EventName line
        -- Skip @onCCEvent because fizzle handles the full syntax parsing
        local atEvent = line:match("^%s*@([%w_]+)")
        if atEvent and atEvent ~= "onCCEvent" and not currentEvent then
          currentEvent = atEvent
        end
        table.insert(current, line)
      end
    end
  end

  return scripts
end

---------------------------------------------------------------------
-- UI Element Constructor
---------------------------------------------------------------------
-- Creates a MiniMark renderer element for use with the UI framework
-- Returns an element that can be added to a scene with ui.addElement()
local function createRenderer(opts, ui)
  local self = {
    type = "minimarkrenderer",
    path = opts.path,
    scrollOffset = opts.scrollOffset or 0,
    x = opts.x or 1,
    width = opts.width or select(1, term.getSize()),
    height = opts.height or select(2, term.getSize()),
    y = opts.y or 1,
    position = opts.position,
    xOffset = opts.xOffset,
    yOffset = opts.yOffset,
    newlink = nil,
    scene = opts.scene,  -- Parent scene for MiniMark renderer
    childScene = nil,    -- Child overlay scene for interactive elements (created below)

    -- Store opts for hook API
    opts = opts,

    -- Callbacks
    onPageLoaded = opts.onPageLoaded,  -- Called after page is tokenized and laid out

    -- UI element overlays for interactive content (buttons, checkboxes, textfields)
    _uiElements = {},

    -- 3-stage cache: MMfile -> tokens -> physical lines -> render
    _cachedTokens = nil,        -- Logical lines (from parsing)
    _cachedPhysicalLines = nil, -- Physical lines (after word wrap/alignment)
    _cachedPath = nil,
    _needsTokenize = true,

    -- Helper: Create UI elements from cached physical lines
    createUIElementsFromPhysicalLines = function(self)
      if not ui then return end

      local targetScene = self.childScene or self.scene
      self._uiElements = {}

      -- Walk through physical lines to find interactive elements
      local lineIdx = 0  -- Tracks which physical line we're on
      for _, pline in ipairs(self._cachedPhysicalLines) do
        if pline.type == "text" then
          local fragX = pline.baseX + self.x - 1
          for _, f in ipairs(pline.fragments) do
            if f.type == "button" then
              local meta = f.meta or {}
              local uiElem = ui.button({
                scene = targetScene,
                text = f.text,
                x = fragX,
                y = self.y + lineIdx,  -- Initial position (will be updated by update())
                width = f.width,
                fg = f.fg or colors.white,
                bg = f.bg or colors.gray,
                colorPressed = meta.pressBg or colors.lightGray,
                visible = true,  -- Use 'visible' instead of '_visible' for new UI
                onClick = function(elem)
                  if meta.onClick and ui.contextTable.triggerEvent then
                    ui.contextTable.triggerEvent(meta.onClick)
                  end
                end
              })
              uiElem.id = meta.id  -- Assign ID for getElementById to work
              uiElem._mmLineIdx = lineIdx  -- Store which physical line this element is on
              uiElem._mmX = fragX          -- Store X position (doesn't change with scroll)
              table.insert(self._uiElements, uiElem)

            elseif f.type == "checkbox" then
              local meta = f.meta or {}
              local uiElem = ui.checkbox({
                scene = targetScene,
                text = f.label or "",
                x = fragX,
                y = self.y + lineIdx,
                initial = false,
                fg = f.fg or colors.white,
                bg = f.bg or colors.black,
                visible = true,  -- Use 'visible' instead of '_visible' for new UI
                onClick = function(elem, checked)
                  if meta.onClick and ui.contextTable.triggerEvent then
                    ui.contextTable.triggerEvent(meta.onClick, checked)
                  end
                end
              })
              uiElem.id = meta.id  -- Assign ID for getElementById to work
              uiElem._mmLineIdx = lineIdx
              uiElem._mmX = fragX
              table.insert(self._uiElements, uiElem)

            elseif f.type == "textbox" then
              local meta = f.meta or {}
              local uiElem = ui.textfield({
                scene = targetScene,
                text = "",
                x = fragX,
                y = self.y + lineIdx,
                width = f.width or 10,
                fg = f.fg or colors.white,
                bg = f.bg or colors.gray,
                visible = true,  -- Use 'visible' instead of '_visible' for new UI
                onEnter = meta.onEnter and function(elem)
                  if ui.contextTable.triggerEvent then
                    ui.contextTable.triggerEvent(meta.onEnter, elem.text)
                  end
                end or nil
              })
              uiElem.id = meta.id  -- Assign ID for getElementById to work
              uiElem._mmLineIdx = lineIdx
              uiElem._mmX = fragX
              table.insert(self._uiElements, uiElem)
            end

            fragX = fragX + (f.width or 0)
          end
          lineIdx = lineIdx + 1
        elseif pline.type == "blank" or pline.type == "hr" then
          lineIdx = lineIdx + 1
        end
      end
    end,

    -- Pre-tokenize AND layout (call BEFORE rendering to avoid flicker)
    prepareRender = function(self)
      local pathChanged = (self.path ~= self._cachedPath)

      if pathChanged or self._needsTokenize then
        -- Reset scroll position when navigating to a new page
        if pathChanged then
          self.scrollOffset = 0
        end

        -- Stage 1: Parse file -> logical lines
        self._cachedTokens = parsePageToLogicalLines(self.path)

        -- Stage 2: Layout logical -> physical lines
        self._cachedPhysicalLines = layoutFromTokens(self._cachedTokens, self.width)

        self._cachedPath = self.path
        self._needsTokenize = false

        -- Clear old UI elements from child scene before creating new ones
        if ui and self.childScene then
          ui.clearScene(self.childScene)
          self._uiElements = {}
        end

        -- Create UI elements from physical lines
        self:createUIElementsFromPhysicalLines()

        -- Refresh the active scene to rebuild flattened element list
        -- This ensures new buttons/checkboxes in the child scene are registered
        if ui and ui.activeScene then
          ui.setScene(ui.activeScene)
        end

        -- Call onPageLoaded callback if provided
        if self.onPageLoaded then
          self.onPageLoaded(self.path)
        end

        -- Mark dirty to trigger re-render
        if ui then ui.markDirty() end
      end
    end,

    -- Update UI element positions based on scroll offset (called every frame)
    -- Use onUpdate (canonical name) instead of update for new UI framework
    onUpdate = function(self, dt)
      if not ui or #self._uiElements == 0 then return false end

      local changed = false

      -- Update each UI element's position based on its physical line index and current scroll
      for _, uiElem in ipairs(self._uiElements) do
        local lineIdx = uiElem._mmLineIdx

        -- Calculate screen Y position: element Y + line index - scroll offset
        local screenY = self.y + lineIdx - self.scrollOffset

        -- Update Y position if changed
        if uiElem.y ~= screenY then
          uiElem.y = screenY
          changed = true
        end

        -- Set visibility based on viewport bounds
        local inViewport = (screenY >= self.y and screenY < self.y + self.height)
        -- Update both visible and _visible for compatibility with new and old UI
        if uiElem.visible ~= inViewport then
          uiElem.visible = inViewport
          uiElem._visible = inViewport  -- Keep for backward compatibility
          changed = true
        end
      end

      return changed  -- Tell UI framework if we changed something
    end,

    draw = function(self)
      -- Stage 3: Render physical lines (FAST: <1ms - just drawing!)
      -- Physical lines MUST be pre-cached via prepareRender()
      -- NO file I/O or calculations allowed during draw() - causes flicker!
      if not self._cachedPhysicalLines then
        error("MiniMark draw() called without cached layout! Call prepareRender() first!")
      end

      -- Render visual content only (UI elements are handled by update())
      renderFromPhysicalLines(
        self._cachedPhysicalLines,
        self.scrollOffset,
        self.y,
        self.x,
        self.width,
        self.height
      )
    end,

    onScroll = function(self, dir)
      -- Adjust scroll offset
      self.scrollOffset = math.max(self.scrollOffset + dir, 0)
      -- Mark dirty to trigger re-render
      if ui then ui.markDirty() end
    end,

    onClick = function(self, x, y)
      -- Handle link clicks by walking through physical lines
      -- (UI overlays handle buttons/checkboxes/textboxes automatically)
      local lineIdx = 0
      for _, pline in ipairs(self._cachedPhysicalLines) do
        local screenY = self.y + lineIdx - self.scrollOffset

        -- Check if this line is at the clicked Y position
        if screenY == y and pline.type == "text" then
          local fragX = pline.baseX + self.x - 1
          for _, f in ipairs(pline.fragments) do
            if f.type == "link" then
              local linkEndX = fragX + f.width - 1
              if x >= fragX and x <= linkEndX then
                self.newlink = f.meta.target
                if ui then ui.markDirty() end
                return true
              end
            end
            fragX = fragX + (f.width or 0)
          end
        end

        if pline.type == "text" or pline.type == "blank" or pline.type == "hr" then
          lineIdx = lineIdx + 1
        end
      end

      -- Return false to allow click passthrough to UI overlays
      return false
    end,

    -- Find all logical elements with matching ID from cached tokens
    -- Returns array of {tokenIdx, elemIdx, element}
    findElementsByID = function(self, id)
      if not self._cachedTokens then return {} end

      local results = {}

      for tokenIdx, token in ipairs(self._cachedTokens) do
        if token.type == "line" and token.elements then
          for elemIdx, elem in ipairs(token.elements) do
            -- Check both meta.id and direct id field
            local elemId = (elem.meta and elem.meta.id) or elem.id
            if elemId == id then
              table.insert(results, {
                tokenIdx = tokenIdx,
                elemIdx = elemIdx,
                element = elem,
                logicalLine = token
              })
            end
          end
        end
      end

      return results
    end,

    -- Modify all logical elements with matching ID
    -- modifyFunc receives element and should return modified properties table
    -- Example: modifyElementsByID("myBtn", function(elem) return {label = "New Text"} end)
    -- NOTE: After modification, physical lines are re-laid out automatically
    modifyElementsByID = function(self, id, modifyFunc)
      if not self._cachedTokens then return 0 end

      local count = 0

      for tokenIdx, token in ipairs(self._cachedTokens) do
        if token.type == "line" and token.elements then
          for elemIdx, elem in ipairs(token.elements) do
            local elemId = (elem.meta and elem.meta.id) or elem.id
            if elemId == id then
              -- Call modify function to get new properties
              local newProps = modifyFunc(elem)
              if newProps and type(newProps) == "table" then
                -- Apply new properties to element
                for key, value in pairs(newProps) do
                  elem[key] = value
                end
                count = count + 1
              end
            end
          end
        end
      end

      -- Re-layout physical lines if we modified anything
      if count > 0 then
        self._cachedPhysicalLines = layoutFromTokens(self._cachedTokens, self.width)

        -- Preserve focus before destroying elements
        local focusedId = nil
        if ui and ui.focused and ui.focused.id then
          focusedId = ui.focused.id
        end

        -- Recreate UI elements since physical lines changed
        if ui and self.childScene then
          ui.clearScene(self.childScene)
          self._uiElements = {}
          self:createUIElementsFromPhysicalLines()
        end

        -- Refresh the active scene to rebuild flattened element list
        -- This ensures modified buttons/checkboxes in the child scene are registered
        if ui and ui.activeScene then
          ui.setScene(ui.activeScene)
        end

        -- Restore focus if it was on an element with an ID
        if focusedId and ui then
          for _, elem in ipairs(self._uiElements) do
            if elem.id == focusedId and elem.focusable then
              ui.setFocus(elem)
              break
            end
          end
        end

        if ui then ui.markDirty() end
      end

      return count
    end
  }

  -- Create child overlay scene for interactive elements (buttons, checkboxes, textfields)
  -- Child scenes render after their parent, so overlays naturally draw on top
  if ui then
    local parentScene = self.scene or "Main"
    self.childScene = parentScene .. "_overlay"

    -- Create child scene if it doesn't exist
    if not ui.contextTable.scenes[self.childScene] then
      ui.newScene(self.childScene)
      ui.setChild(self.childScene, 0, 0, "center")
    end
  end

  -- Tokenize AND layout initial content immediately (prevents flicker on first render)
  self:prepareRender()

  -- Attach hook API to enable onUpdate, onDraw, and other lifecycle hooks
  if ui and ui._attachHookAPI then
    ui._attachHookAPI(self)
  end

  return self
end

----------------------------------------------------------------------
--- Backward-compatible renderPage (for testing without UI framework)
----------------------------------------------------------------------
local function renderPage(path, scroll, startY)
  local tokens = parsePageToLogicalLines(path)
  local physicalLines = layoutFromTokens(tokens)
  local registry, lastY = renderFromPhysicalLines(physicalLines, scroll, startY)
  return registry, lastY
end

----------------------------------------------------------------------
--- Module export
----------------------------------------------------------------------

return {
  renderPage = renderPage,  -- Backward-compatible standalone rendering
  tokenizePage = parsePageToLogicalLines,  -- Export tokenization for caching
  layoutFromTokens = layoutFromTokens,  -- Layout physical lines (expensive, cache this!)
  renderFromPhysicalLines = renderFromPhysicalLines,  -- Fast render from layout cache
  createRenderer = createRenderer,  -- UI element constructor (main production API)
  getScripts = getScripts,
  getAlignment = getAlignment,
  stripTags = stripTags,
  loadPage = loadLinesFromFile,
}
