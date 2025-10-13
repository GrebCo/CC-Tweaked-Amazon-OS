local fizzleContext

local log = function()  end

local fizzleEvents = {}

local cacheFilePath

-- Import events module
local events = require("OSUtil/events")

-- Store sandboxed functions for each event
local sandboxedFunctions = {}

-- Create a safe sandbox environment
local function createSandbox()
    local sandbox = {
        -- Safe built-ins
        pairs = pairs,
        ipairs = ipairs,
        next = next,
        type = type,
        tostring = tostring,
        tonumber = tonumber,
        string = string,
        table = table,
        math = math,
        print = print,
        error = error,
        assert = assert,
        -- Add other safe functions as needed

        -- Fizzle-specific functions can be added here
        -- triggerEvent = function(eventName, params)
        --     events.triggerEvent(eventName, params)
        -- end
    }

    -- Set up metatable to prevent access to global environment
    setmetatable(sandbox, {
        __index = function(_, k)
            log("[fzzl] Access to '" .. tostring(k) .. "' is not allowed in Fizzle scripts")
            return nil -- Return nil instead of erroring
        end,
        __newindex = function(t, k, v)
            rawset(t, k, v) -- Allow setting new variables in sandbox
        end
    })

    return sandbox
end

-- Saves the script to a cache file specific to this instance "_websiteName_fizzleCache.lua" and generate a table "vars" "_websiteName_fizzleCookies.lua"
local function saveScriptToCache()
    if not fizzleContext or not fizzleContext.scripts then
        log("[fzzl] No fizzleContext or scripts provided")
        return false
    end

    -- Create cache directory if it doesn't exist
    local cacheDir = fs.getDir(cacheFilePath)
    if not fs.exists(cacheDir) then
        fs.makeDir(cacheDir)
    end

    -- Save the script lines to cache
    local f = fs.open(cacheFilePath, "w")
    if not f then
        log("[fzzl] Could not create cache file: " .. cacheFilePath)
        return false
    end

    for _, line in ipairs(fizzleContext.scripts) do
        f.writeLine(line)
    end
    f.close()
    return true
end

-- TODO [p2] Optimize the for loops
-- Extracts from "local function foo(bar) eventName" returns bool ok
local function registerEventsFromCache()
    local lines = fizzleContext.scripts[1] -- fizzleContext.scripts should be an array of lines of the script

    -- Handle if scripts is array of arrays or single array
    if type(lines) == "string" then
        lines = fizzleContext.scripts
    end

    -- Extract the events
    fizzleEvents = {}

    for _, line in ipairs(lines) do
        -- Extract event name from function declarations like: "local function foo(params) eventName"
        local eventName = string.match(line, "function%s+%w+%s*%([^)]*%)%s+(%w+)")
        if eventName then
            log("[fzzl] Found event: " .. eventName)
            table.insert(fizzleEvents, eventName)
            events.registerEvent(eventName)
        end
    end

    return true
end

-- TODO Not tested yet
local function assignFizzleFunctionsToEventsFromCache()
    -- Generate Sandboxed Function to subscribe to events
    local f = fs.open(cacheFilePath, "r")
    if not f then
        log("[fzzl] Could not open cache file path: " .. cacheFilePath)
        return false
    end

    -- First Extract the lines
    local lines = {}
    local fileLine = f.readLine()
    while fileLine do -- TODO verify that this correctly reads all the lines
        table.insert(lines, fileLine)
        fileLine = f.readLine()
    end
    f.close()

    local cache_luaPath = fs.getDir(cacheFilePath) .. "/cache_lua/"
    local cache_LuaFile = cache_luaPath .. "script.lua" -- /cache_lua/script.lua

    -- Create directory for temporary script
    fs.makeDir(cache_luaPath)

    -- Check that there isn't a cacheLua file already
    if fs.exists(cache_LuaFile) then
        fs.delete(cache_LuaFile)
    end

    -- Create cachelua script file (contains standard lua code without event names)
    local cacheLua_scriptFile = fs.open(cache_LuaFile, "w")
    if not cacheLua_scriptFile then
        log("[fzzl] Could not create cache lua file: " .. cache_LuaFile)
        return false
    end

    -- Process each line to extract functions and their event names
    local functionEventMap = {}

    for _, scriptLine in ipairs(lines) do
        -- Detect if it is a function declaration line
        local funcName, eventName = string.match(scriptLine, "local%s+function%s+(%w+)%s*%([^)]*%)%s+(%w+)")
        if funcName and eventName then
            -- Store the mapping of function to event
            functionEventMap[funcName] = eventName
            -- Write the function without the event name
            local cleanLine = string.gsub(scriptLine, "(%s+)(%w+)$", "")
            cacheLua_scriptFile.writeLine(cleanLine)
        else
            -- Regular line, write as-is
            cacheLua_scriptFile.writeLine(scriptLine)
        end
    end
    cacheLua_scriptFile.close()

    -- Load and execute the script in sandbox
    local scriptContent = ""
    local scriptFile = fs.open(cache_LuaFile, "r")
    if scriptFile then
        local content = scriptFile.readAll()
        scriptFile.close()
        scriptContent = content
    end

    -- Create sandbox and load the script
    local sandbox = createSandbox()
    local scriptFunc, err = load(scriptContent, "fizzle_script", "t", sandbox)

    if not scriptFunc then
        log("[fzzl] Error loading script: " .. (err or "unknown error"))
        return false
    end

    -- Execute the script to define functions in sandbox
    local execSuccess, execErr = pcall(scriptFunc)
    if not execSuccess then
        log("[fzzl] Error executing script: " .. (execErr or "unknown error"))
        return false
    end

    -- Register functions with their corresponding events
    for funcName, eventName in pairs(functionEventMap) do
        local func = sandbox[funcName]
        if func and type(func) == "function" then
            -- Create a wrapper that calls the sandboxed function
            local wrappedFunc = function(params)
                local callSuccess, result = pcall(func, params)
                if not callSuccess then
                    print("[fzzl] Error in event handler '" .. funcName .. "': " .. tostring(result))
                end
                return result
            end

            events.registerFunction(eventName, wrappedFunc)
            print("[fzzl] Registered function '" .. funcName .. "' for event '" .. eventName .. "'")
        else
            print("[fzzl] Warning: Function '" .. funcName .. "' not found in sandbox")
        end
    end

    -- Clean up temporary files
    fs.delete(cache_luaPath)
    return true
end

local function triggerFizzleEvent(eventName, params)
    print("[fzzl] Triggering event: " .. eventName)
    events.triggerEvent(eventName, params or {})
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
        log = fizzleContext.functions.log or function() end
 end



return {
    init = init,
    triggerFizzleEvent = triggerFizzleEvent,
    renew = renew
}
