local ui = require("ui")
local minimark = require("MiniMark")
local net = require("ClientNetworkHandler")
local protocol = "EENet"
local cacheDir = "/browser_cache"

fs.makeDir(cacheDir)
local screenWidth, screenHeight = term.getSize()

local function getWebsite(url, protocol)
  local baseUrl = url:match("([^/]+)")
  local response = net.query(baseUrl, url, protocol)
  if not response then
    return false, "No response from server"
  end

  local safeFilename = url:gsub("[^%w_]", "_") .. ".txt"
  local path = fs.combine(cacheDir, safeFilename)

  local file = fs.open(path, "w")
  if not file then
    return false, "Failed to open file for writing"
  end

  file.write(response)
  file.close()
  return true, path
end

-- UI elements

local renderer = ui.minimarkrenderer({
  path = "Default.txt",
  position = "center",
  renderer = minimark,
  y = 2,
  scrollOffset = -1,
  width = screenWidth,
  height = screenHeight - 2,
  scrollSpeed = 1
})

ui.createExitButton(function()
  print("Exiting browser...")
  os.reboot()
end)

local label = ui.label({
  text = "Welcome to Browser!",
  fg = colors.yellow,
  bg = colors.black,
  position = "bottomCenter",
  height = 1
})


local urlLabel = ui.label({
  text = "URL:",
  fg = colors.white,
  bg = colors.black,
  position = "topLeft",
  height = 1
})

local input = ui.textfield({
  text = "",
  width = screenWidth / 2,
  fg = colors.white,
  bg = colors.gray,
  position = "topLeft",
  height = 2,
  xOffset = #urlLabel.text
})

local submit = ui.button({
  text = "Submit",
  fg = colors.white,
  bg = colors.green,
  colorPressed = colors.lime,
  onclick = function()
    local url = input.text
    ui.updateLabel(label, "Loading: " .. url)
    local ok, result = getWebsite(url, protocol)
    if ok then
      
      ui.minimarkUpdatePath(renderer, result)


    else
      ui.updateLabel(label, "Error: " .. result)
    end
  end,
  width = 8,
  height = 1,
  x = input.width + 2
})



function run()
  function updateEvents()
    while true do
      ui.handleEvent()
    end
  end

  function renderUI()
    while true do
      ui.render()
      --ui.updateLabel(tester, tostring(math.max(0, renderer.linesCount + renderer.y - renderer.height)) .. " Scroll offset " .. tostring(renderer.scrollOffset))
      if renderer.newlink then
        local url = renderer.newlink
        renderer.newlink = nil

        ui.updateLabel(label, "Loading: " .. url)
        local ok, result = getWebsite(url, protocol)
        if ok then
          ui.minimarkUpdatePath(renderer, result)
          input.text = url
        else
          ui.updateLabel(label, "Error: " .. result)
        end
      end
      sleep(0.001)
    end
  end
  parallel.waitForAny(renderUI, updateEvents)
end

ui.init()

run()
