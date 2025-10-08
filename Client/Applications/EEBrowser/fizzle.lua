 local fizzleElements

local fizzleEvents

local cacheFilePath


-- Must be called prior to any module usages
local function init(uiElements)
    fizzleElements = uiElements
end

-- Saves the script to a cache file specific to this instance "_websiteName_fizzleCache.lua" and generate a table "vars" "_websiteName_fizzleCookies.lua"
local function saveScriptToCache()

end

-- TODO [p2] Optimize the for loops
-- Extracts from "local function foo(bar) eventName" returns bool ok
local function extractEventsFromCache()
    local f = fs.open(cacheFilePath, "r")
    if not f then error("[fzzl] Could not open cache file path: " .. cacheFilePath) end


    -- First Extract the lines, _ means ignored variable
    local lines = {}
    for _, line in function() return f.readLine() end do
        table.insert(lines, line)
    end
    f.close()


    -- Extract the events
    local fizzleEvents = {}

    for _, line in ipairs(lines) do
        -- extract valuable Data using lua regex (no idea how what the regex string actually means)
        local eventName = string.match(line, "%)%s*(%w+)")
        print(eventName) -- Output: myEvent
        table.insert(fizzleEvents, eventName)
    end

    for _, event in ipairs(fizzleEvents) do
        events.registerEvent(event)
    end

    return true
end

local function assignFizzleFunctionsToEventsFromCache()
    -- Generate Sandboxxed Function to subscribe to events
end

local function triggerFizzleEvent(event, params)

end


-- Clears fizzleEvents and deletes the cache
local function reset()

end

return {
    init = init,
    saveScriptToCache = saveScriptToCache,
    extractEventsFromCache = extractEventsFromCache,
    assignFizzleFunctionsToEventsFromCache = assignFizzleFunctionsToEventsFromCache,
    triggerFizzleEvent = triggerFizzleEvent,
    reset = reset
}

