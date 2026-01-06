-- Updated: Browser with splash screen
-- Uses scenes (Splash -> Browser)

local ui = dofile("OSUtil/UI/UI.lua")
local minimark = dofile("applications/EEBrowser/MiniMark.lua")
local net = dofile("OSUtil/ClientNetworkHandler.lua")
local fizzle = dofile("applications/EEBrowser/fizzle.lua")

local protocol = "EENet"
local cacheDir = "applications/EEBrowser/cache"

local logger = dofile("/OSUtil/Logger.lua")
local log = logger.log
local logQueue = logger.queue
local logPush = logger.push

-- Context table
local contextTable = {
    mmElements = {},
    scenes = {},
    functions = { log = log, logQueue = logQueue, logPush = logPush },
    scripts = {},                                                      -- script-defined functions or handlers
    eventTrigger = nil,                                                -- fizzle Events import is introduced in fizzle.lua init()
    events = {},
    fizzleLibFunctions = {},
    net = net
}

fs.makeDir(cacheDir)

-------------------------------------------------
-- Website fetching function
-------------------------------------------------
local function getWebsite(url, protocol)
    -- Handle "home" shortcut - redirect to local/home
    if url == "home" then
        url = "local/home"
    end

    -- Handle local pages (local/pageName)
    if url:match("^local/") then
        local pageName = url:match("^local/(.+)$")
        local localPath = "applications/EEBrowser/local/" .. pageName .. ".txt"

        if fs.exists(localPath) then
            return true, localPath
        else
            return false, "Local page not found: " .. pageName
        end
    end

    -- Regular network request
    local baseUrl = url:match("([^/]+)")
    local response = net.query(baseUrl, url, protocol)
    if not response then
        return false, "No response from server"
    end

    local safeFilename = url:gsub("[^%w_]", "_") .. ".txt"
    local path = fs.combine(cacheDir, safeFilename)
    local f = fs.open(path, "w")
    if not f then
        return false, "Failed to open file for writing"
    end
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



-- Frame counter for throttling onUpdate
local updateFrameCounter = 0
local UPDATE_THROTTLE = 15  -- Trigger fizzle onUpdate every 15 frames (2 FPS)
local totalOnUpdateCalls = 0  -- Track if onUpdate is being called at all

local mmRenderer = ui.addElement(nil, minimark.createRenderer({
    path = "applications/EEBrowser/local/home.txt",
    x = 1,
    y = 2,
    height = screenHeight - 2,
    width = 45,
    scene = "Browser", -- Specify which scene to add interactive elements to
    onPageLoaded = function(pagePath)
        local scripts = minimark.getScripts(pagePath)
        if scripts and #scripts > 0 then
            fizzle.renew(scripts)
        end
    end,
    onUpdate = function(self, dt)
        -- Count total calls to verify this is running
        totalOnUpdateCalls = totalOnUpdateCalls + 1

        -- Throttle fizzle onUpdate to reduce expensive rebuilds
        updateFrameCounter = updateFrameCounter + 1
        if updateFrameCounter >= UPDATE_THROTTLE then
            updateFrameCounter = 0
            log("[browser] Triggering fizzle onUpdate event (total calls: " .. totalOnUpdateCalls .. ")")
            fizzle.triggerFizzleEvent("onUpdate", { dt = dt })
        end
        return false  -- Don't mark UI dirty
    end
}, ui))

contextTable.fizzleLibFunctions.findElementByID = mmRenderer.findElementsByID
contextTable.fizzleLibFunctions.modifyElementsByID = mmRenderer.modifyElementsByID
contextTable.fizzleLibFunctions.mmRenderer = mmRenderer
contextTable.currentUrl = "local/home" -- Set initial URL for cookie domain tracking
contextTable.debugCounters = {
    getOnUpdateCalls = function() return totalOnUpdateCalls end
}


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

-- Test button for modifyElementsByID
local testModify = ui.button({
    text = "test",
    fg = colors.lime,
    bg = colors.gray,
    position = "bottomRight",
    onclick = function()
        local count = mmRenderer:modifyElementsByID("persistTest", function(elem)
            if elem.label then
                return { label = "Modified at " .. os.clock() }
            elseif elem.text then
                return { text = "Modified at " .. os.clock() }
            end
        end)
        statusLabel.text = "Modified " .. count .. " elements"
    end
})

local back = ui.button({
    text = "<<",
    fg = colors.blue,
    bg = colors.gray,
    colorPressed = colors.lightBlue,
    position = "topLeft",
    onclick = function()
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
            contextTable.currentUrl = url
            mmRenderer.path = result
            mmRenderer:prepareRender()
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
    end
})

ui.checkbox({
    text = "Enable Sound Effects",
    position = "center",
    yOffset = 1,
    onclick = function(e, state)
    end
})

ui.button({
    text = "Clear Cache",
    position = "center",
    yOffset = 3,
    bg = colors.red,
    colorPressed = colors.orange,
    onclick = function()
        fs.delete("applications/EEBrowser/cache")
        fs.makeDir("applications/EEBrowser/cache")
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

function checkIfnewLink()
    if ui.activeScene == "Browser" and mmRenderer.newlink then
        local url = mmRenderer.newlink
        mmRenderer.newlink = nil
        statusLabel.text = "Loading: " .. url
        local ok, result = getWebsite(url, protocol)
        if ok then
            contextTable.currentUrl = url
            mmRenderer.path = result
            mmRenderer:prepareRender() -- Pre-tokenize BEFORE marking dirty
            ui.markDirty()             -- Triggers draw() which syncs UI elements
        else
            statusLabel.text = "Error: " .. result
        end
    end
end

-------------------------------------------------
-- Start on Splash and run
-------------------------------------------------


ui.setScene("Splash")
ui.run({
    fps = 30,
    onTick = function()
        checkIfnewLink()
        logPush()
    end
})
