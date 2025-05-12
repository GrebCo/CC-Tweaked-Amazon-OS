-- MiniMark++ Page Renderer for CC:Tweaked
-- Supports headers, alignment, inline text/background colors, links, and newlines

-- Maps color names as strings to their corresponding color values in the `colors` API
local colorMap = 
{
  white = colors.white, gray = colors.gray, lightGray = colors.lightGray, black = colors.black,
  red = colors.red, green = colors.green, blue = colors.blue, yellow = colors.yellow, cyan = colors.cyan,
  magenta = colors.magenta, orange = colors.orange, lime = colors.lime, lightBlue = colors.lightBlue,
  pink = colors.pink, brown = colors.brown, purple = colors.purple
}



-- Loads all lines from a given file and returns them as a table
local function loadLinesFromFile(path)
  local lines = {}
  local f = fs.open(path, "r") -- Open the file in read mode
  if not f then error("Could not open " .. path) end -- Abort if file couldn't be opened
  while true do
    local line = f.readLine() -- Read line-by-line
    if not line then break end -- Stop at end of file
    table.insert(lines, line) -- Store each line into the lines table
  end
  f.close() -- Close the file
  return lines
end

-- Removes all tags from a line (like [text:red] or [background:blue])
local function stripTags(text)
  return text:gsub("%[.-%]", "") -- Match any pattern inside square brackets and remove it
end

-- Determines alignment based on line prefix and strips the prefix
-- "# text" = left, "## text" = center, "### text" = right
local function getAlignment(line)
  if line:match("^###") then return "right", line:sub(4) -- Strip "###" and return "right"
  elseif line:match("^##") then return "center", line:sub(3) -- Strip "##" and return "center"
  elseif line:match("^#") then return "left", line:sub(2) -- Strip "#" and return "left"
  else return "left", line -- Default to left alignment
  end
end

-- Renders a single line of text with optional tags for color and alignment
local function renderTextWithTags(rawText, y, align)
  local width, _ = term.getSize() -- Get terminal width
  local line = stripTags(rawText) -- Remove all tags for measuring plain text length
  local x = 1 -- Default to left alignment

  -- Calculate horizontal position based on alignment
  if align == "center" then
    x = math.floor((width - #line) / 2)
  elseif align == "right" then
    x = width - #line + 1
  end

  local pos = 1 -- Current read position in the text
  local cursorX = x -- Actual cursor X position for drawing
  local currentTextColor = colors.white -- Default text color
  local currentBGColor = colors.black -- Default background color

  -- Loop through each tag or segment in the line
  while pos <= #rawText do
    local start, stop, tag = rawText:find("%[(.-)%]", pos) -- Look for the next tag
    if start then
      local text = rawText:sub(pos, start - 1) -- Get the text before the tag
      term.setCursorPos(cursorX, y)
      term.setTextColor(currentTextColor)
      term.setBackgroundColor(currentBGColor)
      write(text) -- Write the text to the terminal
      cursorX = cursorX + #text -- Move cursor forward

      -- Handle color tags
      if tag:match("^text:") then
        local col = tag:sub(6)
        if col == "reset" then
          currentTextColor = colors.white
        else
          currentTextColor = colorMap[col] or colors.white -- Fallback to white if unknown
        end
      elseif tag:match("^background:") then
        local col = tag:sub(12)
        if col == "reset" then
          currentBGColor = colors.black
        else
          currentBGColor = colorMap[col] or colors.black -- Fallback to black if unknown
        end
      end
      pos = stop + 1 -- Move past the tag
    else
      -- No more tags: render the rest of the line
      local text = rawText:sub(pos)
      term.setCursorPos(cursorX, y)
      term.setTextColor(currentTextColor)
      term.setBackgroundColor(currentBGColor)
      write(text)
      break
    end
  end
end

-- Renders a full page by reading lines from a file and drawing each line with formatting
local function renderPage(path)
    term.clear() -- Clear the terminal screen
    local lines = loadLinesFromFile(path) -- Read file contents into a table
    local y = 1 -- Initial line position (top of the terminal)
  
    for _, line in ipairs(lines) do
      if line:find("^%s*$") then -- If the line is blank or contains only whitespace
        y = y + 1 -- Skip a line to create vertical spacing
      else
        local align, content = getAlignment(line) -- Determine text alignment and clean content
        renderTextWithTags(content, y, align) -- Draw the text line with alignment and color
        y = y + 1 -- Move to the next terminal row
      end
    end
  end

-- Example usage:
-- renderPage("/pages/home.txt")
return { renderPage = renderPage } -- Return the renderPage function for external use
-- Run the page renderer on "test.txt"
--renderPage("test.txt")
