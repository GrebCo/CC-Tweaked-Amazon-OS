-- Updated: 5/20/2025
-- A simple web browser for CC:Tweaked using a custom UI library and MiniMark renderer.
-- It fetches pages over a network protocol, caches them locally, and renders formatted text.

-- Import custom utility modules
local ui = dofile("OSUtil/ui.lua")                 -- Custom UI framework for buttons, labels, etc.
local minimark = dofile("OSUtil/MiniMark.lua")     -- Renderer for MiniMark markup files (simple HTML-like format)
local net = dofile("OSUtil/ClientNetworkHandler.lua") -- Handles client-side network communication
local fizzle = dofile("EEBrowser/fizzle.lua") -- Handles all fizzle scripts

local protocol = "EENet"                           -- Network protocol used for fetching pages
local cacheDir = "/browser_cache"                  -- Directory to store cached website files

local ENABLE_LOG = true
if ENABLE_LOG then
  local logger = dofile("/OSUtil/Logger.lua")
  log = logger.log
  log("Logger initialized.")
else
  log = function()  end
end


-- Browser cache of elements
local contextTable = {
  elements = {},   -- all UI / MiniMark elements live here
  functions = {},  -- shared callable functions (e.g. addElement, render, etc.)
  scripts  = {},    -- script-defined functions or handlers
  eventTrigger = nil,
  -- fizzle Events import is introduced in fizzle.lua init()
  scripts  = {},    -- script-defined functions or handler
  events = {}
}

contextTable.functions.log = log

-- Ensure cache directory exists
fs.makeDir(cacheDir)


-- Get terminal dimensions for layout
local screenWidth, screenHeight = term.getSize()

-- Function: Fetches website content via the network and saves it to cache
local function getWebsite(url, protocol)
  local baseUrl = url:match("([^/]+)")                 -- Extract domain or base address
  local response = net.query(baseUrl, url, protocol)   -- Send a query using the network handler
  log("Attempting to get " .. url)
  if not response then
    return false, "No response from server"            -- Handle failed network response
  end

  -- Sanitize the URL into a safe filename for caching
  local safeFilename = url:gsub("[^%w_]", "_") .. ".txt"
  local path = fs.combine(cacheDir, safeFilename)

  -- Try to write the response to a file
  local file = fs.open(path, "w")
  if not file then
    return false, "Failed to open file for writing"
  end

  file.write(response)
  file.close()
  return true, path                                    -- Return success and the cached file path
end

--=========================================
-- UI ELEMENTS
--=========================================

-- Initialize UI system (sets up elements, screen, etc.)

ui.init(contextTable)
log("UI initialized.")
fizzle.init(contextTable)
log("Fizzle initialized.")

-- MiniMark renderer setup
local renderer = ui.minimarkrenderer({
  path = "EEBrowser/Default.txt",          -- Default file to render on startup
  position = "center",           -- Centered on screen
  renderer = minimark,           -- Use MiniMark renderer
  y = 2,                         -- Vertical offset (to leave space for UI at top)
  scrollOffset = -1,             -- Initial scroll offset
  width = screenWidth,           -- Match screen width
  height = screenHeight - 2,     -- Leave room for top/bottom labels
  scrollSpeed = 1                -- How fast it scrolls

})

-- Exit button that reboots the system
ui.createExitButton(function()
  print("Exiting browser...")
  os.reboot()
end)

-- Label at the bottom showing current status
local label = ui.label({
  text = "Welcome to Browser!",
  fg = colors.yellow,
  bg = colors.black,
  position = "bottomCenter",
  height = 1
})

-- "URL:" label at the top-left
local urlLabel = ui.label({
  text = "URL:",
  fg = colors.white,
  bg = colors.black,
  position = "topLeft",
  height = 1
})

-- Text input field for user to enter a URL
local input = ui.textfield({
  text = "",
  width = screenWidth / 2,     -- Half the screen width
  fg = colors.white,
  bg = colors.gray,
  position = "topLeft",
  height = 2,
  xOffset = #urlLabel.text     -- Position next to the "URL:" label
})

-- Submit button that fetches and displays the requested URL
local submit = ui.button({
  text = "Submit",
  fg = colors.white,
  bg = colors.green,
  colorPressed = colors.lime,  -- Lighter color when pressed
  onclick = function()
    local url = input.text
    ui.updateLabel(label, "Loading: " .. url)

    local ok, result = getWebsite(url, protocol)
    if ok then
      ui.minimarkUpdatePath(renderer, result)   -- Update renderer with new cached file
    else
      ui.updateLabel(label, "Error: " .. result)
    end
  end,
  width = 8,
  height = 1,
  x = input.width + 2           -- Position just after the text field
})

--=========================================
-- MAIN RUNTIME LOOP
--=========================================

function run()
  -- Thread: listens for and handles UI events
  function updateEvents()
    while true do
      ui.handleEvent()          -- Pass events (clicks, keypresses, etc.) to UI system
    end
  end

  -- Thread: renders the UI and handles hyperlink clicks from MiniMark
  function renderUI()
    while true do
      ui.render()               -- Redraw all UI elements

      -- Detect if MiniMark renderer set a new link (clicked)
      if renderer.newlink then
        local url = renderer.newlink
        renderer.newlink = nil  -- Clear link flag

        ui.updateLabel(label, "Loading: " .. url)
        local ok, result = getWebsite(url, protocol)
        if ok then
          ui.minimarkUpdatePath(renderer, result)  -- Display linked page
          input.text = url                         -- Update URL field
        else
          ui.updateLabel(label, "Error: " .. result)
        end
      end

      sleep(0.001)              -- Small delay to reduce CPU usage
    end
  end

  -- Run both loops in parallel: UI event handling and rendering
  parallel.waitForAny(renderUI, updateEvents)
end



-- Start the main browser loop
log("Starting browser main loop.")
ui.minimarkUpdatePath(renderer, "EEBrowser/Default.txt") -- Load default page
run()
