
local ENABLE_LOG = false
local ENABLE_PRINT = false
local LOG_FILE = "/log/log.txt"
local needRender = true

local UI = {
    elements = {},
    term = term,
    focused = nil
  }

  local function log(msg)
    -- Write to log file if enabled
    if ENABLE_LOG then
        local file = fs.open(LOG_FILE, "a") -- Open file in append mode
        if file then
            file.writeLine("[" .. os.time() .. "] " .. msg) -- Timestamped log line
            file.close()
        end
    end

    -- Print to screen if enabled
    if ENABLE_PRINT then
        print(msg)
    end
  end

  
  function UI.init()
    UI.term.setBackgroundColor(colors.black)
    UI.term.clear()
    UI.term.setCursorPos(1, 1)
  end

  -- function UI.update()
  --   UI.render()
  --   UI.handleEvent()
  -- end

  function UI.run()
    function updateEvents()
      while true do
        UI.handleEvent()
      end
    end

    function renderUI()
      while true do
        UI.render()
        sleep(0.001)
      end
    end
    parallel.waitForAny(renderUI, updateEvents)
  end


  function UI.handleEvent()
    local event, a, b, c = os.pullEvent()
    log("Event1 " .. event)
    if event == "mouse_click" then
      UI.handleClick(b, c)
    elseif event == "mouse_scroll" then
      
      UI.handleScroll(a,b,c)
    elseif event == "key" or "char" then
      
      
      if UI.focused and UI.focused.type == "textfield" then
        log("handling text stuff")
        UI.handleInput(event, a, b)
        
      end
  end

  end
  
  function UI.applyPositioning(e)
    local w, h = UI.term.getSize()
    local width = e.width or (#e.text or 1)
    local height = e.height or 1

    local xOffset = e.xOffset or 0
    local yOffset = e.yOffset or 0
  
    if e.position then
      local pos = e.position
  
      if pos == "center" then
        e.x = math.floor((w - width) / 2) + 1 + xOffset
        e.y = math.floor((h - height) / 2) + 1 + yOffset
  
      elseif pos == "topLeft" then
        e.x = 1 + xOffset
        e.y = 1 + yOffset
  
      elseif pos == "topCenter" or pos == "top" then
        e.x = math.floor((w - width) / 2) + 1 + xOffset
        e.y = 1 + yOffset
  
      elseif pos == "topRight" then
        e.x = w - width + 1 + xOffset
        e.y = 1 + yOffset
  
      elseif pos == "centerLeft" or pos == "left" then
        e.x = 1 + xOffset
        e.y = math.floor((h - height) / 2) + 1 + yOffset
  
      elseif pos == "centerRight" or pos == "right" then
        e.x = w - width + 1 + xOffset
        e.y = math.floor((h - height) / 2) + 1 + yOffset
  
      elseif pos == "bottomLeft" then
        e.x = 1 + xOffset
        e.y = h - height + 1 + yOffset
  
      elseif pos == "bottomCenter" or pos == "bottom" then
        e.x = math.floor((w - width) / 2) + 1 + xOffset
        e.y = h - height + 1 + yOffset
  
      elseif pos == "bottomRight" then
        e.x = w - width + 1 + xOffset
        e.y = h - height + 1 + yOffset
      end
    end
  
    if e.xPercent then e.x = math.floor(w * e.xPercent) end
    if e.yPercent then e.y = math.floor(h * e.yPercent) end
  
    if e.x < 1 then e.x = 1 end
    if e.y < 1 then e.y = 1 end
  end

  function UI.render()
    if not needRender then return end
    local w, h = UI.term.getSize()
    UI.term.setBackgroundColor(colors.black)
    UI.term.clear()
    for _, e in ipairs(UI.elements) do
      UI.applyPositioning(e)
      if e.type == "button" then
        UI.drawButton(e)
      elseif e.type == "label" then
        UI.drawLabel(e)
      elseif e.type == "checkbox" then
        UI.drawCheckbox(e)
      elseif e.type == "minimarkrenderer" then
        UI.drawMinimarkRenderer(e)
      elseif e.type == "textfield" then
        UI.drawTextfield(e)
      end

    end
    needRender = false
  end
  
  function UI.handleClick(x, y)
    log("Handling click")
    for _, e in ipairs(UI.elements) do
      local width = e.width or #e.text
      local height = e.height or 1
      if x >= e.x and x <= e.x + width - 1 and y >= e.y and y < e.y + height then
        if e.type == "textfield" then
          log("clicked textfield")
          UI.focused = e
          log("Focusing" .. textutils.serialise(UI.focused))
          needRender = true
        elseif e.type == "checkbox" then
          log("clicked checkbox")
          e.checked = not e.checked
          e.onclick(e, e.checked)
          needRender = true
        elseif e.type == "button" then
          log("clicked button")
          if e.toggle then e.state = not e.state else e.pressed = true end
          needRender = true
          if not e.toggle then sleep(0.1) end
          e.onclick(e)
          if not e.toggle then e.pressed = false end
          needRender = true
        end
      end
    end
  end

  function UI.handleScroll(scroll, x, y)
    log("Handling Scroll X:" .. x .. " Y:" .. y .. "Scroll: " .. scroll)
    for _, e in ipairs(UI.elements) do
      local width = e.width or #e.text
      local height = e.height or 1
      
      if x >= e.x and x <= e.x + width - 1 and y >= e.y and y < e.y + height then
        if e.type == "minimarkrenderer" then

          tempScroll = 0 + e.scrollOffset

          -- Safe fallback for missing linesCount or scrollSpeed
          e.scrollSpeed = e.scrollSpeed or 1
          e.linesCount = e.linesCount or 0
          e.scrollOffset = e.scrollOffset or 0
  
          -- Apply scroll
          e.scrollOffset = e.scrollOffset + (scroll * e.scrollSpeed)
          needRender = true
          -- Clamp scroll range
          if e.scrollOffset < 0 - e.y then
            e.scrollOffset = 0 - e.y
            needRender = false
          else
            local maxScroll = math.max(0, e.linesCount + e.y - e.height)
            if e.scrollOffset > maxScroll then
              e.scrollOffset = maxScroll
              needRender = false
            end
          end

          
          
          return true
        end
      end
    end
  
    -- If not handled, optional: implement global scroll here
  
    return false
  end
  
  
  function UI.handleInput(event, a, b)
    log("Event in handle input: " .. event .. "A: " .. a)

    if event == "char" then
      log("char event")
      
      
      UI.focused.text = UI.focused.text .. a
      needRender = true
    elseif event == "key" and a == keys.backspace then
      log("key event backspace")
      if(UI.focused.text ~= "") then
        UI.focused.text = UI.focused.text:sub(1, -2)
        needRender = true
      end
    end
    
  end
  
  function UI.drawButton(e)
    local displayText = e.text
    local width = e.width or #e.text
    local height = e.height or 1
    local pad = math.max(0, math.floor((width - #displayText) / 2))
    local line = string.rep(" ", pad) .. displayText .. string.rep(" ", width - pad - #displayText)
  
    local verticalCenter = e.y + math.floor((height - 1) / 2)
    local bgColor = colors.black
    if e.toggle and e.state and e.colorPressed then
      bgColor = e.colorPressed
    elseif not e.toggle and e.pressed and e.colorPressed then
      bgColor = e.colorPressed
    elseif e.bg then
      bgColor = e.bg
    end
  
    for i = 0, height - 1 do
      UI.term.setCursorPos(e.x, e.y + i)
      UI.term.setBackgroundColor(bgColor)
      UI.term.setTextColor(e.fg or colors.white)
      UI.term.write((e.y + i == verticalCenter) and line or string.rep(" ", width))
    end
  end
  
  function UI.drawLabel(e)
    UI.term.setCursorPos(e.x, e.y)
    UI.term.setBackgroundColor(e.bg or colors.black)
    UI.term.setTextColor(e.fg or colors.white)
    UI.term.write(e.text)
  end
  
  function UI.drawCheckbox(e)
    UI.term.setCursorPos(e.x, e.y)
    UI.term.setBackgroundColor(e.bg or colors.black)
    UI.term.setTextColor(e.fg or colors.white)
    local box = e.checked and "[x] " or "[ ] "
    UI.term.write(box .. e.text)
  end
  
  function UI.drawTextfield(e)
    UI.term.setCursorPos(e.x, e.y)
    local bg = (UI.focused == e and e.bgActive) or e.bg or colors.gray
    local fg = e.fg or colors.black
    UI.term.setBackgroundColor(bg)
    UI.term.setTextColor(fg)
    local display = e.text .. string.rep(" ", (e.width or 10) - #e.text)
    UI.term.write(display:sub(1, e.width or 10))
  end
  
  function UI.button(opts)
    local e = {
      type = "button",
      x = opts.x or 1, y = opts.y or 1,
      text = opts.text or "Button",
      fg = opts.fg, bg = opts.bg,
      colorPressed = opts.colorPressed,
      toggle = opts.toggle,
      state = false,
      pressed = false,
      xOffset = opts.xOffset,
      yOffset = opts.yOffset,
      width = opts.width, height = opts.height,
      onclick = opts.onclick or function() end,
      xPercent = opts.xPercent, yPercent = opts.yPercent,
      position = opts.position
    }
    table.insert(UI.elements, e)
    return e
  end
  
  function UI.label(opts)
    local e = {
      type = "label",
      x = opts.x or 1, y = opts.y or 1,
      text = opts.text or "",
      fg = opts.fg, bg = opts.bg,
      xPercent = opts.xPercent, yPercent = opts.yPercent,
      position = opts.position,
      xOffset = opts.xOffset,
      yOffset = opts.yOffset
    }
    table.insert(UI.elements, e)
    return e
  end
  
  function UI.checkbox(opts)
    local e = {
      type = "checkbox",
      x = opts.x or 1, y = opts.y or 1,
      text = opts.text or "",
      fg = opts.fg, bg = opts.bg,
      checked = opts.initial or false,
      onclick = opts.onclick or function() end,
      xPercent = opts.xPercent, yPercent = opts.yPercent,
      position = opts.position,
      xOffset = opts.xOffset,
      yOffset = opts.yOffset
    }
    table.insert(UI.elements, e)
    return e
  end
  
  function UI.textfield(opts)
    local e = {
      type = "textfield",
      x = opts.x or 1, y = opts.y or 1,
      text = opts.text or "",
      width = opts.width or 10,
      fg = opts.fg, bg = opts.bg, bgActive = opts.bgActive,
      xPercent = opts.xPercent, yPercent = opts.yPercent,
      position = opts.position,
      xOffset = opts.xOffset,
      yOffset = opts.yOffset
    }
    table.insert(UI.elements, e)
    return e
  end
  
  function UI.updateLabel(labelObj, newText)
    labelObj.text = newText
    needRender = true
  end
  
  function UI.updateButton(buttonObj, newText)
    buttonObj.text = newText
    needRender = true
  end
  
  function UI.updateCheckbox(checkboxObj, newText)
    checkboxObj.text = newText
    needRender = true
  end
  
  function UI.createExitButton(onClick)
    UI.button({
      text = "X",
      width = 3,
      height = 1,
      fg = colors.white,
      bg = colors.red,
      colorPressed = colors.orange,
      position = "topRight",
      onclick = onClick or function()
        UI.term.setBackgroundColor(colors.black)
        UI.term.clear()
        UI.term.setCursorPos(1, 1)
        error("[UI] Exited via exit button")
      end
    })
  end

  function UI.minimarkrenderer(opts)
    local e = {
      type = "minimarkrenderer",
      x = opts.x or 1, 
      y = opts.y or 1,
      path = opts.path,
      renderer = opts.renderer, -- require("MiniMark")
      linesCount = #opts.renderer.loadPage(opts.path),
      xPercent = opts.xPercent, yPercent = opts.yPercent,
      position = opts.position,
      xOffset = opts.xOffset,
      yOffset = opts.yOffset,
      width = opts.width,
      height = opts.height,
      scrollOffset = opts.scrollOffset or opts.y,
      scrollSpeed = opts.scrollSpeed or 1
      
      --term = term.create
    }
  table.insert(UI.elements, e)
  return e
  end

  function UI.minimarkUpdatePath(e, newPath)
    e.path = newPath
    e.linesCount = #e.renderer.loadPage(e.path)
    e.scrollOffset = -1
    return true
  end

  function UI.drawMinimarkRenderer(e)
      if not e.path then return end
      local lines = e.renderer.loadPage(e.path)
      local y = e.y

      -- for _, line in ipairs(lines) do
      --   if line:find("^%s*$") then
      --     y = y + 1
      --   else
      --     local align, content = e.renderer.getAlignment(line)
      --     term.setCursorPos(e.x, e.y)
      --     --term.redirect(e.term or term.current())
      --     --e.renderer.renderTextWithTags(content, y, align)
      --     --y = y + 1
      --     e.renderer.renderPage(e.path, e.scrollOffset) -- Needs to change to only be called once 
      --   end
      -- end


      e.renderer.renderPage(e.path, -e.scrollOffset, e.y) -- Needs to change to only be called once 
  end

  



  
  return UI