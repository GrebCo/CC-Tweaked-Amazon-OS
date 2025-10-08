-- MiniMark++ Page Renderer for CC:Tweaked
-- Supports headers, alignment, inline text/background colors, links, buttons, checkboxes, textboxes, and script tags

-- Maps color names to their corresponding color values
local colorMap = {
  white = colors.white, gray = colors.gray, lightGray = colors.lightGray, black = colors.black,
  red = colors.red, green = colors.green, blue = colors.blue, yellow = colors.yellow, cyan = colors.cyan,
  magenta = colors.magenta, orange = colors.orange, lime = colors.lime, lightBlue = colors.lightBlue,
  pink = colors.pink, brown = colors.brown, purple = colors.purple
}

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

-- Write text with colors and word wrapping
local function writeWrappedText(text, x, y, fg, bg)
  local termWidth = term.getSize()
  term.setTextColor(fg or colors.white)
  term.setBackgroundColor(bg or colors.black)

  for segment in text:gmatch("([^\n]+)") do
    for word, space in segment:gmatch("(%S+)(%s*)") do
      if x + #word > termWidth then
        y = y + 1
        x = 1
      end

      term.setCursorPos(x, y)
      write(word)
      x = x + #word

      if #space > 0 then
        if x + #space > termWidth then
          y = y + 1
          x = 1
        else
          term.setCursorPos(x, y)
          write(space)
          x = x + #space
        end
      end
    end
  end

  return x, y
end

-- Main render function for a line of MiniMark text
local function renderTextWithTags(rawText, y)
  local termWidth = term.getSize()
  local align, line = getAlignment(rawText)
  local stripped = stripTags(line)
  local pos, x = 1, 1
  local fg, bg = colors.white, colors.black
  local uiPositions = {}

  if align == "center" then
    x = math.max(1, math.floor((termWidth - #stripped) / 2) + 1)
  elseif align == "right" then
    x = math.max(1, termWidth - #stripped)
  else
    x = 1 -- Default for left alignment
  end

  while pos <= #line do
    local tagStart, tagEnd, tag = line:find("%<(.-)%>", pos)

    if tagStart then
      -- write text before the tag
      if tagStart > pos then
        local text = line:sub(pos, tagStart - 1)
        x, y = writeWrappedText(text, x, y, fg, bg)
      end

      -- Process tag
      if tag:match("^text:") then
        local col = tag:match("^text:(.+)")
        fg = col == "reset" and colors.white or (colorMap[col] or colors.white)

      elseif tag:match("^background:") then
        local col = tag:match("^background:(.+)")
        bg = col == "reset" and colors.black or (colorMap[col] or colors.black)

      elseif tag:match("^link:") then
        local page, label = tag:match("^link:\"(.-)\",\"(.-)\"")
        if page and label then
          if x + #label > termWidth then
            y, x = y + 1, 1
          end
          local startX = x
          term.setCursorPos(x, y)
          term.setTextColor(colorMap.lightBlue)
          term.setBackgroundColor(colorMap.gray)
          write(label)
          table.insert(uiPositions, {
            type = "link", x = startX, y = y, width = #label, page = page
          })
          x = x + #label
        end

      elseif tag:match("^button:") then
        local label, bg_col, fg_col, action = tag:match("^button:\"(.-)\",\"(.-)\",\"(.-)\",\"(.-)\"")
        if label then
          if x + #label > termWidth then
            y, x = y + 1, 1
          end

          local startX = x
          term.setCursorPos(x, y)
          term.setTextColor(colorMap[fg_col] or colors.white)
          term.setBackgroundColor(colorMap[bg_col] or colors.gray)
          write(label)
          table.insert(uiPositions, {
            type = "button", x = startX, y = y, width = #label, action = action
          })
          x = x + #label
        end

      elseif tag:match("^checkbox:") then
        local label = tag:match("^checkbox:\"(.-)\"")
        if label then
          local box = "[ ] " .. label
          if x + #box > termWidth then
            y, x = y + 1, 1
          end
          local startX = x
          term.setCursorPos(x, y)
          term.setTextColor(fg)
          term.setBackgroundColor(bg)
          write(box)
          table.insert(uiPositions, {
            type = "checkbox", x = startX, y = y, width = #box, label = label
          })
          x = x + #box
        end

      elseif tag:match("^textbox:") then
        local boxWidth = tonumber(tag:match("^textbox:(%d+)")) or 10
        if x + boxWidth > termWidth then
          y, x = y + 1, 1
        end
        local startX = x
        term.setCursorPos(x, y)
        term.setTextColor(fg)
        term.setBackgroundColor(bg)
        write((" "):rep(boxWidth))
        table.insert(uiPositions, {
          type = "textbox", x = startX, y = y, width = boxWidth
        })
        x = x + boxWidth

      end

      pos = tagEnd + 1  -- advance past the tag
    else
      -- no more tags, print the rest
      local text = line:sub(pos)
      x, y = writeWrappedText(text, x, y, fg, bg)
      break
    end
  end

  return y, uiPositions
end

-- Full page render from file
local function renderPage(path, scroll, startY)
  term.clear()
  local uiRegistry = {}
  local lines = loadLinesFromFile(path)
  local y = (startY or 1) - (scroll or 0)

  for _, line in ipairs(lines) do

    if line:find("^%s*$") then
      -- Empty line (spacing)
      y = y + 1

    elseif y > 0 then
      -- Normal MiniMark line
      local newY, uiPositions = renderTextWithTags(line, y)
      if uiPositions then
        for _, uiElement in ipairs(uiPositions) do
          table.insert(uiRegistry, {y = uiElement.y or y, element = uiElement})
        end
      end
      y = newY + 1
    end
  end

  -- Return both UI elements and collected scripts
  return uiRegistry, y + startY
end

-- TODO Implement getting scripts and remove from renderPage
local function getScripts(path)
  local lines = loadLinesFromFile(path)
  local scriptRegistry = {}

  local currentScript = nil
  local currentName = nil

  for _, line in ipairs(lines) do
    local startTag = line:match('<script:"(.-)">')
    local endTag = line:match("</script>")

    if startTag then
      currentName = startTag
      currentScript = {}
    elseif endTag and currentScript then
      scriptRegistry[currentName] = table.concat(currentScript, "\n")
      currentScript = nil
      currentName = nil
    elseif currentScript then
      table.insert(currentScript, line)
    end
  end

  -- Dump registry to log once per call
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
  renderPage = renderPage,
  renderTextWithTags = renderTextWithTags,
  getAlignment = getAlignment,
  stripTags = stripTags,
  loadPage = loadLinesFromFile
}
