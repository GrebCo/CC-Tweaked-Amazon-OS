-- MiniMark++ Page Renderer for CC:Tweaked
-- Supports headers, alignment, inline text/background colors, links, buttons, checkboxes, textboxes, and script tags

-- Maps color names to their corresponding color values
local colorMap = {
  white = colors.white, gray = colors.gray, lightGray = colors.lightGray, black = colors.black,
  red = colors.red, green = colors.green, blue = colors.blue, yellow = colors.yellow, cyan = colors.cyan,
  magenta = colors.magenta, orange = colors.orange, lime = colors.lime, lightBlue = colors.lightBlue,
  pink = colors.pink, brown = colors.brown, purple = colors.purple
}

-- Dumps a tokenized MiniMark page to a file
-- pageTokens: output of parsePageToLogicalLines(path)
-- filename: where to write the dump
local function dumpTokensToFile(pageTokens, filename)
  local f = fs.open(filename, "w")
  if not f then error("Could not open " .. filename .. " for writing") end

  local function dumpTable(tbl, indent)
    indent = indent or ""
    for k, v in pairs(tbl) do
      if type(v) == "table" then
        f.writeLine(indent .. k .. ":")
        dumpTable(v, indent .. "  ")
      else
        f.writeLine(indent .. k .. ": " .. tostring(v))
      end
    end
  end

  for i, logical in ipairs(pageTokens) do
    f.writeLine("Logical Line " .. i .. " (" .. logical.type .. ")")
    if logical.type == "line" then
      f.writeLine("  Alignment: " .. logical.align)
      for j, el in ipairs(logical.elements) do
        f.writeLine("  Element " .. j .. " (" .. el.type .. ")")
        dumpTable(el, "    ")
      end
    end
    f.writeLine(("="):rep(40))
  end

  f.close()
end

-- Example usage:
-- local tokens = parsePageToLogicalLines("test.mm")
-- dumpTokensToFile(tokens, "token_dump.txt")

-- Loads all lines from a given file
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

-- Removes all formatting tags (e.g., <text:red>, <link:"page","text">, etc.)
local function stripTags(line)
  return line:gsub("%<.-%>", "")
end

-- Determines alignment based on leading #s and returns the alignment and cleaned line
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

-- Utility: parse key="value" pairs from the tag
local function parseAttributes(tag)
  local attrs = {}
  -- allow optional spaces around = and after commas
  for key, val in tag:gmatch("(%w+)%s*=%s*\"(.-)\"") do
    attrs[key] = val
  end
  return attrs
end

-- Helper: split text into leading spaces + sequence of (word,space) pairs
local function splitTextIntoWordSpaceRuns(text)
  local runs = {}

  -- Leading spaces
  local leading = text:match("^(%s+)")
  if leading then
    table.insert(runs, {type="space", text=leading, width = #leading})
    text = text:sub(#leading + 1)
  end

  -- Words with their trailing spaces
  for word, space in text:gmatch("(%S+)(%s*)") do
    table.insert(runs, {type="word", text=word, width = #word})
    if #space > 0 then
      table.insert(runs, {type="space", text=space, width = #space})
    end
  end

  -- If text was entirely spaces (no matches), handle (rare) case
  if #runs == 0 and #text > 0 then
    table.insert(runs, {type="space", text=text, width = #text})
  end

  return runs
end

-- Convert a raw line (already stripped of leading header markers) into element tokens
local function parseLineToElements(line)
  local tokens = {}
  local pos = 1
  local fg, bg = colors.white, colors.black

  while pos <= #line do
    local tagStart, tagEnd, tag = line:find("%<(.-)%>", pos)
    if tagStart then
      -- text before tag
      if tagStart > pos then
        local txt = line:sub(pos, tagStart - 1)
        table.insert(tokens, { type = "text", text = txt, fg = fg, bg = bg })
      end

      -- process tag (update fg/bg or add element token)
      if tag:match("^text:") then
        local col = tag:match("^text:(.+)")
        fg = (col == "reset") and colors.white or (colorMap[col] or colors.white)

      elseif tag:match("^background:") then
        local col = tag:match("^background:(.+)")
        bg = (col == "reset") and colors.black or (colorMap[col] or colors.black)

      elseif tag:match("^link:") then
        local page, label = tag:match("^link:\"(.-)\",\"(.-)\"")
        if page and label then
          table.insert(tokens, {
            type = "link",
            label = label,
            page = page,
            fg = colorMap.lightBlue, bg = colorMap.gray
          })
        end

      elseif tag:match("^button:") then
        local label = tag:match("^button:\"(.-)\"")
        local attrs = parseAttributes(tag)
        if label then
          table.insert(tokens, {
            type = "button",
            label = label,
            attrs = attrs,
            fg = colorMap[attrs.fg] or colors.white,
            bg = colorMap[attrs.bg] or colors.gray,
            hoverFg = colorMap[attrs.hoverFg],
            hoverBg = colorMap[attrs.hoverBg],
            pressFg = colorMap[attrs.pressFg],
            pressBg = colorMap[attrs.pressBg],
            id = attrs.id,
            onClick = attrs.onClick,
            onHover = attrs.onHover
          })
        end

      elseif tag:match("^checkbox:") then
        local label = tag:match("^checkbox:\"(.-)\"")
        local attrs = parseAttributes(tag)
        if label then
          table.insert(tokens, {
            type = "checkbox",
            label = label,
            attrs = attrs,
            fg = colorMap[attrs.fg] or colors.white,
            bg = colorMap[attrs.bg] or colors.black,
            boxChecked = attrs.box or "[x]",
            boxUnchecked = attrs.emptyBox or "[ ]",
            id = attrs.id,
            onClick = attrs.onClick
          })
        end

      elseif tag:match("^textbox:") then
        local width = tonumber(tag:match("^textbox:(%d+)")) or 10
        table.insert(tokens, {
          type = "textbox",
          width = width,
          fg = fg, bg = bg
        })
      end

      pos = tagEnd + 1
    else
      -- remaining text
      if pos <= #line then
        local txt = line:sub(pos)
        table.insert(tokens, { type = "text", text = txt, fg = fg, bg = bg })
      end
      break
    end
  end

  return tokens
end

-- Parse whole page into logical lines (skip script content)
local function parsePageToLogicalLines(path)
  local rawLines = loadLinesFromFile(path)
  local logicalLines = {}
  local inScript = false
  for _, raw in ipairs(rawLines) do
    -- script handling: skip script contents entirely from rendering
    local startTag = raw:match('<script%s*:%s*".-">')
    local endTag   = raw:match('</script>')
    if startTag then
      inScript = true
    elseif endTag then
      inScript = false
    elseif inScript then
      -- ignore
    else
      if raw:find("^%s*$") then
        table.insert(logicalLines, { type = "blank" })
      else
        local align, cleaned = getAlignment(raw)
        local elements = parseLineToElements(cleaned)
        table.insert(logicalLines, { type = "line", align = align, elements = elements })
      end
    end
  end
  return logicalLines
end

-- Main improved renderPage: uses token model, wraps, aligns, and registers UI elements
local function renderPageTokenized(path, scroll, startY)
  term.clear()
  local uiRegistry = {}
  local logicalLines = parsePageToLogicalLines(path)
  dumpTokensToFile(logicalLines, "TokenDump.txt")
  local termWidth = term.getSize()
  local y = (startY or 1) - (scroll or 0)

  for _, logical in ipairs(logicalLines) do
    if logical.type == "blank" then
      y = y + 1

    else -- logical.type == "line"
      -- Build fragments for this logical line (words/spaces/buttons/etc.)
      local fragments = {} -- each: {type, text, width, fg, bg, meta = {..}}
      for _, el in ipairs(logical.elements) do
        if el.type == "text" then
          -- split text into leading spaces + word/space runs
          local runs = splitTextIntoWordSpaceRuns(el.text)
          for _, r in ipairs(runs) do
            table.insert(fragments, {
              type = r.type,           -- "word" or "space"
              text = r.text,
              width = r.width,
              fg = el.fg, bg = el.bg
            })
          end

        elseif el.type == "button" then
          local label = el.label
          local disp = label
          table.insert(fragments, {
            type = "button",
            text = disp,
            width = #disp,
            fg = el.fg, bg = el.bg,
            meta = el
          })

        elseif el.type == "link" then
          local disp = el.label
          table.insert(fragments, {
            type = "link",
            text = disp,
            width = #disp,
            fg = el.fg, bg = el.bg,
            meta = el
          })

        elseif el.type == "checkbox" then
          local boxText = (el.boxUnchecked or "[ ]") .. " " .. (el.label or "")
          table.insert(fragments, {
            type = "checkbox",
            text = boxText,
            width = #boxText,
            fg = el.fg, bg = el.bg,
            meta = el
          })

        elseif el.type == "textbox" then
          local disp = (" "):rep(el.width or 10)
          table.insert(fragments, {
            type = "textbox",
            text = disp,
            width = el.width or 10,
            fg = el.fg, bg = el.bg,
            meta = el
          })
        end
      end

      -- Wrap fragments into physical lines (lists of fragments)
      local physLines = {}
      local curLine = {}
      local curWidth = 0

      for _, frag in ipairs(fragments) do
        -- If frag is a long word longer than terminal width, split it into chunks
        if (frag.type == "word" or frag.type == "button" or frag.type == "link") and frag.width > termWidth then
          -- split text into chunks of termWidth
          local t = frag.text
          local i = 1
          while i <= #t do
            local chunk = t:sub(i, i + termWidth - 1)
            local chunkFrag = {
              type = (frag.type == "word") and "word" or frag.type,
              text = chunk,
              width = #chunk,
              fg = frag.fg, bg = frag.bg,
              meta = frag.meta
            }
            -- place chunk
            if curWidth + chunkFrag.width <= termWidth then
              table.insert(curLine, chunkFrag)
              curWidth = curWidth + chunkFrag.width
            else
              table.insert(physLines, curLine)
              curLine = { chunkFrag }
              curWidth = chunkFrag.width
            end
            i = i + termWidth
          end

        else
          -- Normal placement decision
          if curWidth + frag.width <= termWidth then
            table.insert(curLine, frag)
            curWidth = curWidth + frag.width
          else
            -- push current and start new line
            table.insert(physLines, curLine)
            curLine = { frag }
            curWidth = frag.width
          end
        end
      end

      -- push last physical line
      if #curLine > 0 then table.insert(physLines, curLine) end
      if #physLines == 0 then
        y = y + 1
      else
        -- Render each physical line with alignment
        for _, pl in ipairs(physLines) do
          -- compute total width of this physical line
          local total = 0
          for _, f in ipairs(pl) do total = total + (f.width or 0) end

          local baseX = 1
          if logical.align == "center" then
            baseX = math.max(1, math.floor((termWidth - total) / 2) + 1)
          elseif logical.align == "right" then
            baseX = math.max(1, termWidth - total + 1)
          else
            baseX = 1
          end

          -- Write fragments in this physical line
          local x = baseX
          for _, f in ipairs(pl) do
            term.setCursorPos(x, y)
            term.setTextColor(f.fg or colors.white)
            term.setBackgroundColor(f.bg or colors.black)

            -- write and register interactive elements
            if f.type == "word" or f.type == "space" then
              write(f.text)
            elseif f.type == "button" then
              write(f.text)
              -- register button
              local element = {
                type = "button",
                x = x,
                y = y,
                width = f.width,
                label = f.text,
                id = f.meta.id,
                onClick = f.meta.onClick,
                onHover = f.meta.onHover,
                fg = f.fg, bg = f.bg,
                hoverFg = f.meta.hoverFg, hoverBg = f.meta.hoverBg,
                pressFg = f.meta.pressFg, pressBg = f.meta.pressBg
              }
              table.insert(uiRegistry, { y = y, element = element })

            elseif f.type == "link" then
              write(f.text)
              local element = {
                type = "link",
                x = x,
                y = y,
                width = f.width,
                page = f.meta.page,
                label = f.text
              }
              table.insert(uiRegistry, { y = y, element = element })

            elseif f.type == "checkbox" then
              write(f.text)
              local element = {
                type = "checkbox",
                x = x,
                y = y,
                width = f.width,
                label = f.meta.label,
                id = f.meta.id,
                checked = false,
                boxChecked = f.meta.boxChecked,
                boxUnchecked = f.meta.boxUnchecked,
                fg = f.fg, bg = f.bg
              }
              table.insert(uiRegistry, { y = y, element = element })

            elseif f.type == "textbox" then
              write(f.text)
              local element = {
                type = "textbox",
                x = x,
                y = y,
                width = f.width,
                value = "",
                fg = f.fg, bg = f.bg
              }
              table.insert(uiRegistry, { y = y, element = element })
            end

            x = x + (f.width or 0)
          end

          y = y + 1
        end
      end
    end
  end

  return uiRegistry, y + (startY or 1)
end

-- TODO Implement getting scripts and remove from renderPage
local function getScripts(path)
  local lines = loadLinesFromFile(path)
  local scriptRegistry = {}

  local currentScript = nil
  local currentName = nil

  for _, line in ipairs(lines) do
    -- Try to find a <script:"name"> anywhere in the line
    local startTag = line:match('<script%s*:%s*"(.-)">')
    local endTag   = line:match('</script>')

    if startTag then
      currentName = startTag
      currentScript = {}
    elseif endTag and currentScript then
      -- Save the script
      scriptRegistry[currentName] = table.concat(currentScript, "\n")
      currentScript = nil
      currentName = nil
    elseif currentScript then
      -- Keep collecting lines for this script
      table.insert(currentScript, line)
    end
  end

  -- Optional: dump to log for debugging
  local logFile = fs.open("scripts.log", "w")
  if logFile then
    for name, code in pairs(scriptRegistry) do
      logFile.writeLine("[" .. name .. "]")
      logFile.writeLine(code)
      logFile.writeLine(("="):rep(20))
    end
    logFile.close()
  end

  return scriptRegistry
end






return {
  getScripts = getScripts,
  renderPage = renderPageTokenized,
  getAlignment = getAlignment,
  stripTags = stripTags,
  loadPage = loadLinesFromFile
}
