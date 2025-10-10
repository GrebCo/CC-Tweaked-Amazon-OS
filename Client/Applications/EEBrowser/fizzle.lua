 local fizzleContext

local fizzleEvents

local cacheFilePath



-- Saves the script to a cache file specific to this instance "_websiteName_fizzleCache.lua" and generate a table "vars" "_websiteName_fizzleCookies.lua"
local function saveScriptToCache()

end

-- TODO [p2] Optimize the for loops
-- Extracts from "local function foo(bar) eventName" returns bool ok
local function registerEventsFromCache()
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



-- TODO Not complete
local function assignFizzleFunctionsToEventsFromCache()
    -- Generate Sandboxxed Function to subscribe to events
    local f = fs.open(cacheFilePath, "r")
    if not f then error("[fzzl] Could not open cache file path: " .. cacheFilePath) end


    -- First Extract the lines, _ means ignored variable
    local lines = {}
    for _, line in function() return f.readLine() end do
        table.insert(lines, line)
    end
    f.close()

    local cache_luaPath = cacheFilePath .. "/cache_lua/"
    local cache_LuaFile = cache_luaPath .. "script.lua" -- /cache_lua/script.lua
    -- need to create a temporary file for the actual script lua code to exist in (_cookie script cache) without the event eventName
    fs.makeDir(cache_luaPath)
    -- Check that there isnt a cacheLua file already (shouldn't be)
    if fs.exists(cache_LuaFile) then
        -- File Exists TODO Log error
        fs.delete(cache_luaPath)
    end

    -- Create cachelua script file (contains just standard running lua, no event names in front of functions
    local cacheLua_scriptFile = fs.open(cache_luaFile, "w")
    for index, line in ipairs(lines) do
        -- Detect if it is a function Declaration line, if so strip the eventName from the line

    end

    cacheLua_scriptFile.close()


end

local function triggerFizzleEvent(event, params)

end


-- Internal do not use outside of fizzle
-- Clears fizzleEvents and deletes the cache
local function reset()
    -- Nuke Everything
    fizzleEvents = {}
    if fs.exists(cacheFilePath) then
        fs.delete(cacheFilePath)
    end
    events.resetEvents()
    return true
end

-- Internal do not use function outside of fizzle
-- Loads the cache, registers events, and assigns functions to events, should only be called once per page load
local function load()
    saveScriptToCache()
    registerEventsFromCache()
    assignFizzleFunctionsToEventsFromCache()

    -- trigger onLoad Event
    triggerFizzleEvent("onLoad", {}) -- No params yet for onLoad

    return true
end

 -- External, only way to refresh fizzle
local function renew()
    reset()
    load()
    return true
end

 -- Must be called prior to any module usages
 local function init(contextTable)
     fizzleContext = contextTable
     fizzleContext.triggerEvent = triggerFizzleEvent
 end



return {
    init = init,
    triggerFizzleEvent = triggerFizzleEvent,
    renew = renew
}

