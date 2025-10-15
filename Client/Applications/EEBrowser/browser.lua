-- Updated: Browser with splash screen
-- Uses scenes (Splash -> Browser)

local ui = dofile("OSUtil/ui.lua")
local minimark = dofile("OSUtil/MiniMark.lua")
local net = dofile("OSUtil/ClientNetworkHandler.lua")
local fizzle = dofile("EEBrowser/fizzle.lua")

local protocol = "EENet"
local cacheDir = "/browser_cache"

local ENABLE_LOG = true
if ENABLE_LOG then
  local logger = dofile("/OSUtil/Logger.lua")
  log = logger.log
  log("Logger initialized.")
else
  log = function() end
end

-- Context table
local contextTable = {

  elements = {},   -- all active UI / MiniMark elements live here
  scenes = {},  -- All UI scenes live here
  functions = {log = log},  -- shared callable functions (e.g. addElement, render, etc.)
  scripts  = {},    -- script-defined functions or handlers
  eventTrigger = nil, -- fizzle Events import is introduced in fizzle.lua init()
  events = {}
}

fs.makeDir(cacheDir)

-------------------------------------------------
-- Website fetching function
-------------------------------------------------
local function getWebsite(url, protocol)
  local baseUrl = url:match("([^/]+)")
  local response = net.query(baseUrl, url, protocol)
  log("Attempting to get " .. url)
  if not response then
    log("No response from " .. url)
    return false, "No response from server"
  end

  local safeFilename = url:gsub("[^%w_]", "_") .. ".txt"
  local path = fs.combine(cacheDir, safeFilename)
  local f = fs.open(path, "w")
  if not f then return false, "Failed to open file for writing" end
  f.write(response)
  f.close()
  return true, path
end

-------------------------------------------------
-- Initialize UI and Fizzle
-------------------------------------------------
ui.init(contextTable)
fizzle.init(contextTable)

-------------------------------------------------
-- Scene 0: Confirm Settings Popup
-------------------------------------------------

-------------------------------------------------
-- Scene 0: Confirm Settings Popup
-------------------------------------------------

ui.setScene("ConfirmSettingsPopup")

-- Popup background rectangle
ui.rectangle({
  width = 45,
  height = 6,
  position = "center",
  bg = colors.black,
  filled = true
})

-- Popup title text
ui.label({
  text = "Are you sure you want to open Settings?",
  position = "center",
  yOffset = -1,
  fg = colors.yellow,
  bg = colors.black
})

-- "Yes" button
ui.button({
  text = "Yes",
  position = "center",
  xOffset = -6,
  yOffset = 2,
  bg = colors.green,
  colorPressed = colors.lime,
  onclick = function()
    ui.removeChild("ConfirmSettingsPopup")
    ui.setScene("Settings")
  end
})

-- "No" button
ui.button({
  text = "No",
  position = "center",
  xOffset = 6,
  yOffset = 2,
  bg = colors.red,
  colorPressed = colors.orange,
  onclick = function()
    ui.removeChild("ConfirmSettingsPopup")
  end
})


-------------------------------------------------
-- Scene 1: Splash Screen
-------------------------------------------------
ui.setScene("Splash")

ui.label({
  text = "Welcome to EEnet Browser",
  position = "center",
  yOffset = -2,
  fg = colors.yellow
})

ui.label({
  text = "A lightweight network browser for CC:Tweaked",
  position = "center",
  yOffset = 0,
  fg = colors.lightGray
})

ui.button({
  text = "Launch Browser",
  position = "center",
  yOffset = 2,
  bg = colors.green,
  colorPressed = colors.lime,
  onclick = function()
    ui.setScene("Browser") -- transition to browser scene
  end
})

ui.button({
  text = "Settings",
  position = "center",
  yOffset = 4,
  bg = colors.cyan,
  colorPressed = colors.lightBlue,
  onclick = function()
    ui.setScene("Settings")
  end
})

-------------------------------------------------
-- Scene 2: Browser Interface
-------------------------------------------------

ui.setScene("Browser")

local screenWidth, screenHeight = term.getSize()



local function makeMiniMarkElement(opts)
  local e = {
    type = "minimarkrenderer",
    path = opts.path,
    renderer = opts.renderer, -- MiniMark module
    scrollOffset = opts.scrollOffset or 0,
    width = opts.width or select(1, term.getSize()),
    height = opts.height or select(2, term.getSize()),
    y = opts.y or 1,
    position = opts.position,
    xOffset = opts.xOffset,
    yOffset = opts.yOffset,
    newlink = nil,
    buttons = {},

    draw = function(self)
      -- Render MiniMark file directly using its internal renderer
      self.buttons, _ = self.renderer.renderPage(self.path, self.scrollOffset, self.y)
    end,

    onScroll = function(self, dir)
      -- Adjust scroll offset
      self.scrollOffset = math.max(self.scrollOffset + dir, 0)
      ui.markDirty()
    end,

    onClick = function(self, x, y)
    for _, entry in ipairs(self.buttons) do
      local b = entry.element
      if b.type == "link" and x >= b.x and x <= b.x + b.width - 1 and y == b.y then
        self.newlink = b.target
        ui.markDirty()
        break
      end
    end
  end

  }
  return ui.addElement(opts.scene or ui.activeScene, e)
end

local mmRenderer = makeMiniMarkElement({
  path = "EEBrowser/Default.txt",
  renderer = minimark,
  position = "center",
  y = 2,
  height = screenHeight - 2
})

--ui.createExitButton(function()
  --print("Exiting browser...")
  --os.reboot()
--end)

local statusLabel = ui.label({
  text = "Welcome to Browser!",
  fg = colors.yellow,
  bg = colors.black,
  position = "bottomCenter"
})

local urlLabel = ui.label({
  text = " URL:",
  fg = colors.white,
  bg = colors.gray,
  xOffset = 5,
  position = "topLeft"
})

local settings = ui.button({
  text = "set",
  fg = colors.blue,
  bg = colors.gray,
  position = "topRight",
  xOffset = -4,
  onclick = function()
    ui.setChild("ConfirmSettingsPopup", 0, 0, "center")
  end
})


local back = ui.button({
  text = "<<",
  fg = colors.blue,
  bg = colors.gray,
  colorPressed = colors.lightBlue,
  position = "topLeft",
  onclick = function()
    -- TODO: history
  end
})

ui.label({
  text = "|",
  fg = colors.white,
  bg = colors.gray,
  position = "topLeft",
  xOffset = 2,
})

local forward = ui.button({
  text = ">>",
  fg = colors.blue,
  bg = colors.gray,
  colorPressed = colors.lightBlue,
  position = "topLeft",
  xOffset = 3
})

local input = ui.textfield({
  text = "",
  width = screenWidth / 2,
  fg = colors.white,
  bg = colors.gray,
  position = "topLeft",
  xOffset = #urlLabel.text + 6
})

local submit = ui.button({
  text = "Submit",
  fg = colors.white,
  bg = colors.green,
  colorPressed = colors.lime,
  onclick = function()
    local url = input.text
    statusLabel.text = "Loading: " .. url
    os.sleep(0.25) -- allow UI to update
    local ok, result = getWebsite(url, protocol)
    if ok then
      mmRenderer.path = result
    else
      statusLabel.text = "Error: " .. result
    end
  end,
  width = 8,
  height = 1,
  xOffset = 5 + #urlLabel.text + input.width,
  position = "topLeft"
})

-------------------------------------------------
-- Scene 3: Settings Interface
-------------------------------------------------
ui.setScene("Settings")

-- Dummy Settings Screen
ui.label({
  text = "=== Settings ===",
  position = "topCenter",
  yOffset = 1,
  fg = colors.yellow
})

ui.checkbox({
  text = "Enable Developer Mode",
  position = "center",
  yOffset = -1,
  onclick = function(e, state)
    log("Developer mode: " .. tostring(state))
  end
})

ui.checkbox({
  text = "Enable Sound Effects",
  position = "center",
  yOffset = 1,
  onclick = function(e, state)
    log("Sound effects: " .. tostring(state))
  end
})

ui.button({
  text = "Clear Cache",
  position = "center",
  yOffset = 3,
  bg = colors.red,
  colorPressed = colors.orange,
  onclick = function()
    fs.delete("/browser_cache")
    fs.makeDir("/browser_cache")
    ui.label({ text = "Cache cleared!", position = "bottomCenter", fg = colors.green })
  end
})

ui.button({
  text = "Back to Browser",
  position = "bottomCenter",
  yOffset = -1,
  bg = colors.gray,
  colorPressed = colors.lightGray,
  onclick = function()
    ui.setScene("Browser")
  end
})

-------------------------------------------------
-- Main runtime loop
-------------------------------------------------
function run()
  local function updateEvents()
    while true do ui.handleEvent() end
  end

  local function renderUI()
    while true do
      ui.render()

      if ui.activeScene == "Browser" and mmRenderer.newlink then
  local url = mmRenderer.newlink
  mmRenderer.newlink = nil
  statusLabel.text = "Loading: " .. url
  local ok, result = getWebsite(url, protocol)
  if ok then
    mmRenderer.path = result
    ui.markDirty()
  else
    statusLabel.text = "Error: " .. result
  end
end

      sleep(0.001)
    end
  end

  parallel.waitForAny(renderUI, updateEvents)
end

-------------------------------------------------
-- Start on Splash
-------------------------------------------------
ui.setScene("Splash")
run()
