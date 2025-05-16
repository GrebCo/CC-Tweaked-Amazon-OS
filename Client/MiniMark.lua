-- MiniMark++ Page Renderer for CC:Tweaked
-- Supports headers, alignment, inline text/background colors, links, buttons, checkboxes, textboxes

-- Maps color names to their corresponding color values
local colorMap = {
  white = colors.white, gray = colors.gray, lightGray = colors.lightGray, black = colors.black,
  red = colors.red, green = colors.green, blue = colors.blue, yellow = colors.yellow, cyan = colors.cyan,
  magenta = colors.magenta, orange = colors.orange, lime = colors.lime, lightBlue = colors.lightBlue,
  pink = colors.pink, brown = colors.brown, purple = colors.purple
}

-- Stores UI metadata for the current page render
local uiRegistry = {}

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

-- Removes tags for alignment calculation and gets alignment based on leading #s
local function getAlignment(line)
  local stripped = line:gsub("%[.-%]", "")
  if line:match("^###") then return "right", line:sub(4), stripped
  elseif line:match("^##") then return "center", line:sub(3), stripped
  elseif line:match("^#") then return "left", line:sub(2), stripped
  else return "left", line, stripped end
end

-- Write text with colors and word wrapping
local function writeWrappedText(text, x, y, fg, bg)
  local termWidth = term.getSize()
  term.setTextColor(fg or colors.white)
  term.setBackgroundColor(bg or colors.black)
  
  for segment in text:gmatch("([^\n]+)") do
    for word, space in segment:gmatch("(%S+)(%s*)") do
      -- Word wrapping logic
      if x + #word > termWidth then
        y = y + 1
        x = 1
      end
      
      term.setCursorPos(x, y)
      write(word)
      x = x + #word
      
      -- Handle spaces
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
local function renderTextWithTags(rawText, y, align, stripped)
  local termWidth = term.getSize()
  local pos, x = 1, 1
  local fg, bg = colors.white, colors.black
  
  -- Set initial position based on alignment
  if align == "center" then
    x = math.floor((termWidth - #stripped) / 2) + 1
  elseif align == "right" then
    x = termWidth - #stripped + 1
  end

  while pos <= #rawText do
    local tagStart, tagEnd, tag = rawText:find("%[(.-)%]", pos)
    
    if tagStart then
      -- Write text before tag
      if tagStart > pos then
        local text = rawText:sub(pos, tagStart - 1)
        x, y = writeWrappedText(text, x, y, fg, bg)
      end

      -- Process tag
      if tag:match("^text:") then
        local col = tag:sub(6)
        fg = col == "reset" and colors.white or (colorMap[col] or colors.white)
        
      elseif tag:match("^background:") then
        local col = tag:sub(12)
        bg = col == "reset" and colors.black or (colorMap[col] or colors.black)
        
      elseif tag:match("^link:") then
        local page, label = tag:match("^link:\"(.-)\",\"(.-)\"")
        if page and label then
          -- Handle word wrap
          if x + #label > termWidth then 
            y, x = y + 1, 1 
          end
          
          local startX = x
          term.setCursorPos(x, y)
          term.setTextColor(colorMap.lightBlue)
          term.setBackgroundColor(colorMap.gray)
          write(label)
          x = x + #label
          
          table.insert(uiRegistry, {
            type = "link", text = label, page = page,
            x = startX, y = y, width = #label, height = 1
          })
        end
        
      elseif tag:match("^button:") then
        local label, bg_col, fg_col, press, action = tag:match("^button:\"(.-)\",\"(.-)\",\"(.-)\",\"(.-)\",\"(.-)\"")
        if label then
          -- Handle word wrap
          if x + #label > termWidth then 
            y, x = y + 1, 1 
          end
          
          local startX = x
          term.setCursorPos(x, y)
          term.setTextColor(colorMap[fg_col] or colors.white)
          term.setBackgroundColor(colorMap[bg_col] or colors.gray)
          write(label)
          x = x + #label
          
          table.insert(uiRegistry, {
            type = "button", text = label, x = startX, y = y,
            width = #label, height = 1,
            bg = colorMap[bg_col] or colors.gray,
            fg = colorMap[fg_col] or colors.white,
            pressed = colorMap[press] or colors.lightGray,
            action = action
          })
        end
        
      elseif tag:match("^checkbox:") then
        local label = tag:match("^checkbox:\"(.-)\"")
        if label then
          local box = "[ ] " .. label
          -- Handle word wrap
          if x + #box > termWidth then 
            y, x = y + 1, 1 
          end
          
          local startX = x
          term.setCursorPos(x, y)
          term.setTextColor(fg)
          term.setBackgroundColor(bg)
          write(box)
          x = x + #box
          
          table.insert(uiRegistry, {
            type = "checkbox", text = label, x = startX, y = y,
            width = #box, height = 1, checked = false
          })
        end
        
      elseif tag:match("^textbox:") then
        local boxWidth = tonumber(tag:match("^textbox:(%d+)")) or 10
        -- Handle word wrap
        if x + boxWidth > termWidth then 
          y, x = y + 1, 1 
        end
        
        local startX = x
        term.setCursorPos(x, y)
        term.setTextColor(fg)
        term.setBackgroundColor(bg)
        write((" "):rep(boxWidth))
        x = x + boxWidth
        
        table.insert(uiRegistry, {
          type = "textbox", x = startX, y = y, width = boxWidth, height = 1,
          text = ""
        })
      end
      
      pos = tagEnd + 1
    else
      -- Render remaining text with word wrapping
      local remainingText = rawText:sub(pos)
      writeWrappedText(remainingText, x, y, fg, bg)
      break
    end
  end
  
  return y
end

-- Saves UI metadata
local function saveLinksMetadata(path)
  local outFile = fs.open(path .. ".links", "w")
  for _, entry in ipairs(uiRegistry) do
    outFile.writeLine(textutils.serialize(entry))
  end
  outFile.close()
end

-- Full page render from file
local function renderPage(path, scroll, startY)
  term.clear()
  uiRegistry = {}
  local lines = loadLinesFromFile(path)
  local y = (startY or 1) + (scroll or 0)
  
  for _, line in ipairs(lines) do
    if line:find("^%s*$") then -- Empty line
      y = y + 1
    elseif y > 0 then -- Only render visible lines
      local align, content, stripped = getAlignment(line)
      y = renderTextWithTags(content, y, align, stripped) + 1
    else
      y = y + 1
    end
  end
  
  saveLinksMetadata(path)
  return uiRegistry
end

return {
  renderPage = renderPage,
  renderTextWithTags = renderTextWithTags,
  getAlignment = getAlignment,
  loadPage = loadLinesFromFile
}