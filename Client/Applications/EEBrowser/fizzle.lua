local fizzleContext

local log = function()  end

local fizzleEvents = {}

local cacheFilePath = "/cache/"

-- Import events module
local events = dofile("OSUtil/events.lua")

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
        print = log,
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


    -- TODO Implement (fizzleContext.scripts is a table of eventName -> {code lines})
    for _, line in ipairs(fizzleContext.scripts) do
        f.writeLine(line)
    end
    f.close()
    return true
end

-- Helper function to read lines from cache file
local function getLinesFromCache()
    if not fs.exists(cacheFilePath) then
        log("[fzzl] Cache file does not exist: " .. cacheFilePath)
        return {}
    end

    local lines = {}
    local f = fs.open(cacheFilePath, "r")
    if not f then
        log("[fzzl] Could not read cache file: " .. cacheFilePath)
        return {}
    end

    local line = f.readLine()
    while line do
        table.insert(lines, line)
        line = f.readLine()
    end
    f.close()

    return lines
end

-- TODO [p2] Optimize the for loops
-- Extracts from "local function foo(bar) eventName" returns bool ok
local function registerEventsFromCache()
    local lines = getLinesFromCache()
    if #lines == 0 then
        log("[fzzl] No lines found in cache")
        return false
    end

    fizzleEvents = {}
    local lastEventName = nil

    for _, line in ipairs(lines) do
        -- Detect annotation first
        local eventTag = line:match("@([%w_]+)")
        if eventTag then
            lastEventName = eventTag
            log("[fzzl] Found event annotation @" .. eventTag)
        end

        -- Detect function declaration right after
        -- Support multiple declaration styles:
        --   local function name(...)
        --   function name(...)
        --   local name = function(...)
        local funcName = line:match("local%s+function%s+(%w+)%s*%(")
                or line:match("function%s+(%w+)%s*%(")
                or line:match("local%s+(%w+)%s*=%s*function%s*%(")
        if funcName and lastEventName then
            events.registerEvent(lastEventName)
            log(string.format("[fzzl] Registered event '%s' for function '%s'", lastEventName, funcName))
            lastEventName = nil -- reset for next pair
        end
    end

    return true
end


-- TODO Not tested yet
local function assignFizzleFunctionsToEventsFromCache()
    local cache_luaPath = fs.getDir(cacheFilePath) .. "/cache_lua/"
    local cache_LuaFile = cache_luaPath .. "script.lua"
    fs.makeDir(cache_luaPath)

    local cacheLua_scriptFile = fs.open(cache_LuaFile, "w")
    if not cacheLua_scriptFile then
        log("[fzzl] Could not create cache lua file: " .. cache_LuaFile)
        return false
    end

    -- Build function→event mapping from annotations
    local functionEventMap = {}
    local lines = getLinesFromCache()
    if #lines == 0 then
        log("[fzzl] No lines found in cache")
        cacheLua_scriptFile.close()
        return false
    end

    local lastEventName = nil
    for _, line in ipairs(lines) do
        local eventTag = line:match("@([%w_]+)")
        if eventTag then
            lastEventName = eventTag
            cacheLua_scriptFile.writeLine(line)
        else
            -- detect several forms of function declaration
            local funcName = line:match("local%s+function%s+(%w+)%s*%(")
                    or line:match("function%s+(%w+)%s*%(")
                    or line:match("local%s+(%w+)%s*=%s*function%s*%(")
            if funcName and lastEventName then
                functionEventMap[funcName] = lastEventName
                lastEventName = nil
            end
            cacheLua_scriptFile.writeLine(line)
        end
    end

    cacheLua_scriptFile.close()

    -- Load the script content from cache
    local scriptContent = table.concat(lines, "\n")
    local sandbox = createSandbox()
    local scriptFunc, err = load(scriptContent, "fizzle_script", "t", sandbox)

    if not scriptFunc then
        log("[fzzl] Error loading script: " .. (err or "unknown error"))
        return false
    end

    local execSuccess, execErr = pcall(scriptFunc)
    if not execSuccess then
        log("[fzzl] Error executing script: " .. (execErr or "unknown error"))
        return false
    end

    -- Register functions
    for funcName, eventName in pairs(functionEventMap) do
        local func = sandbox[funcName]
        if func and type(func) == "function" then
            events.registerFunction(eventName, function(params)
                local ok, res = pcall(func, params)
                if not ok then
                    log("[fzzl] Error in event '" .. eventName .. "': " .. tostring(res))
                    return false
                end
                return res
            end)
            log("[fzzl] Registered '" .. funcName .. "' for event '" .. eventName .. "'")
        else
            log("[fzzl] Warning: function '" .. funcName .. "' not found in sandbox")
        end
    end

    --fs.delete(cache_luaPath)
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
    log("Fizzle initialized!")
end



return {
    init = init,
    triggerFizzleEvent = triggerFizzleEvent,
    renew = renew
}
