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

-- Extracts from "local function foo(bar) eventName"
local function extractEventsFromCache()

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

}