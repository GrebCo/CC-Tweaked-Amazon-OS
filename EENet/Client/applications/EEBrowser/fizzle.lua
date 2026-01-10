local fizzleContext

local log = function() end

local fizzleEvents = {}
local cacheFilePath = "/cache/scripts/"

-- sandbox
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
    -- Safe os functions (time-related only, no file system access)
    os = {
        clock = os.clock,
        time = os.time,
        date = os.date,
        difftime = os.difftime
    },
    -- Add other safe functions as needed

    -- Fizzle-specific functions can be added here
    -- triggerEvent = function(eventName, params)
    --     events.triggerEvent(eventName, params)
    -- end
}

-- Fizzle Libraries
local libraries = nil


-- Import events module
local events = dofile("OSUtil/events.lua")

-- ============================================================================
-- FIZZLE TIMEOUT CONFIGURATION
-- ============================================================================
-- Default configuration (can be overridden by config/fizzle_config.lua)
local FIZZLE_CONFIG = {
    MAX_INSTRUCTIONS = 100000,
    TIMEOUT_ENABLED = true,
    LOG_TIMEOUTS = true,
    EXEMPT_EVENTS = {}
}

-- Load user configuration if it exists
local configPath = "applications/EEBrowser/config/fizzle_config.lua"
if fs.exists(configPath) then
    local userConfig = dofile(configPath)
    if userConfig and type(userConfig) == "table" then
        -- Merge user config with defaults
        for key, value in pairs(userConfig) do
            FIZZLE_CONFIG[key] = value
        end
        -- Log successful config load (will use log function when available)
        print("[fzzl] Loaded custom configuration from " .. configPath)
    end
else
    print("[fzzl] Using default timeout configuration (no custom config found)")
end

-- Timeout wrapper function using time-based watchdog
-- Wraps a function to enforce 10ms execution time limit
local function createTimeoutWrapper(func, eventName)
    -- If timeout is disabled, return function as-is
    if not FIZZLE_CONFIG.TIMEOUT_ENABLED then
        return func
    end

    -- If event is exempt from timeout, return function as-is
    if FIZZLE_CONFIG.EXEMPT_EVENTS[eventName] then
        return func
    end

    return function(params)
        local startTime = os.clock()
        local timedOut = false
        local MAX_TIME = 0.01  -- 10ms max execution time

        -- Set debug hook to check time periodically (every 1000 instructions for lower overhead)
        debug.sethook(function()
            if (os.clock() - startTime) > MAX_TIME then
                timedOut = true
                error("TIMEOUT: Script exceeded 10ms execution time")
            end
        end, "", 1000) -- Check every 1000 instructions instead of every instruction

        -- Execute the function with error handling
        local ok, res = pcall(func, params)

        -- ALWAYS remove the hook, even if function errored
        debug.sethook()

        -- Handle errors
        if not ok then
            if timedOut then
                if FIZZLE_CONFIG.LOG_TIMEOUTS then
                    log("[fzzl] TIMEOUT: Script in event '" .. eventName .. "' exceeded 10ms execution time")
                end
            else
                log("[fzzl] ERROR: Exception in event '" .. eventName .. "': " .. tostring(res))
            end
            return false
        end

        return res
    end
end

-- ============================================================================

-- Create a safe sandbox environment
local function createSandbox()
    -- Set up metatable to prevent access to global environment
    setmetatable(sandbox, {
        __index = function(t, k)
            local val = rawget(t, k)
            if val ~= nil then
                return val
            end
            return nil
        end,
        __newindex = function(t, k, v)
            rawset(t, k, v) -- Allow setting new variables in sandbox
        end
    })

    return sandbox
end

local function saveScriptToCache()
    if not fizzleContext or not fizzleContext.scripts then
        return false
    end

    local cacheDir = fs.getDir(cacheFilePath)
    if not fs.exists(cacheDir) then
        fs.makeDir(cacheDir)
    end

    local f = fs.open(cacheFilePath .. "script.lua", "w")
    if not f then
        return false
    end

    for _, line in ipairs(fizzleContext.scripts) do
        f.writeLine(line)
    end
    f.close()
    return true
end

local function getLinesFromCache()
    if not fs.exists(cacheFilePath .. "script.lua") then
        return {}
    end

    local lines = {}
    local f = fs.open(cacheFilePath .. "script.lua", "r")
    if not f then
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

local function registerEventsFromCache()
    local lines = getLinesFromCache()
    if #lines == 0 then
        return false
    end

    fizzleEvents = {}
    local lastEventName = nil
    local registeredEvents = {}

    for _, line in ipairs(lines) do
        local eventTag = line:match("@([%w_]+)")
        if eventTag then
            lastEventName = eventTag
            log("[fzzl] Found event tag: " .. eventTag)
        end

        local funcName = line:match("local%s+function%s+(%w+)%s*%(")
                or line:match("function%s+(%w+)%s*%(")
                or line:match("local%s+(%w+)%s*=%s*function%s*%(")
        if funcName and lastEventName then
            events.registerEvent(lastEventName)
            table.insert(registeredEvents, lastEventName)
            log("[fzzl] Registered event: " .. lastEventName .. " for function: " .. funcName)
            lastEventName = nil
        end
    end

    log("[fzzl] Total events registered: " .. textutils.serialize(registeredEvents))
    return true
end



local function assignFizzleFunctionsToEventsFromCache()
    local functionEventMap = {}
    local lines = getLinesFromCache()
    if #lines == 0 then
        return false
    end

    local lastEventName = nil
    for i, line in ipairs(lines) do
        local eventTag = line:match("@([%w_]+)")
        if eventTag then
            lastEventName = eventTag
        else
            local funcName = line:match("local%s+function%s+([%w_]+)%s*%(")
                    or line:match("%s*function%s+([%w_]+)%s*%(")
                    or line:match("local%s+([%w_]+)%s*=%s*function%s*%(")

            if funcName and lastEventName then
                functionEventMap[funcName] = lastEventName
                lastEventName = nil
            end
        end
    end

    local scriptContent = table.concat(lines, "\n")
    local sandbox = createSandbox()
    local scriptFunc, err = load(scriptContent, "fizzle_script", "t", sandbox)

    if not scriptFunc then
        log("[fzzl] ERROR: Failed to load script: " .. (err or "unknown error"))
        return false
    end

    local execSuccess, execErr = pcall(scriptFunc)
    if not execSuccess then
        log("[fzzl] ERROR: Failed to execute script: " .. (execErr or "unknown error"))
        return false
    end

    log("[fzzl] Function-Event Map: " .. textutils.serialize(functionEventMap))

    for funcName, eventName in pairs(functionEventMap) do
        local func = sandbox[funcName]

        if func and type(func) == "function" then
            -- Wrap function with timeout protection
            local wrappedFunc = createTimeoutWrapper(func, eventName)
            events.registerFunction(eventName, wrappedFunc)
            log("[fzzl] Registered '" .. funcName .. "' for event '" .. eventName .. "' (with timeout protection)")
        else
            log("[fzzl] ERROR: function '" .. funcName .. "' not found in sandbox")
        end
    end

    return true
end


local function triggerFizzleEvent(eventName, params)
    log("[fzzl] triggerFizzleEvent called: " .. eventName)
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
-- Pass MiniMark scripts array to process them
local function renew(mmScripts)
    reset()

    -- If mmScripts provided, load them into fizzleContext.scripts
    if mmScripts and type(mmScripts) == "table" and #mmScripts > 0 then
        if not fizzleContext then
            log("[fzzl] fizzleContext not initialized. Call init() first.")
            return false
        end

        local lines = {}
        local tempIndex = 1

        for _, entry in ipairs(mmScripts) do
            local eventName = entry.event
            local code = entry.code

            if not code then
                log("[fzzl] Warning: skipping script entry with missing code")
            else
                -- Parse @eventName from code if not provided in tag
                local codeLines = {}
                for codeLine in (code .. "\n"):gmatch("([^\n]*)\n") do
                    table.insert(codeLines, codeLine)
                end

                -- Check first non-empty line for @eventName annotation
                for i, line in ipairs(codeLines) do
                    local trimmed = line:match("^%s*(.-)%s*$")
                    if trimmed ~= "" then
                        local atEvent = trimmed:match("^%-%-@([%w_]+)") or trimmed:match("^@([%w_]+)")
                        if atEvent then
                            eventName = atEvent
                            -- Remove this line from codeLines
                            table.remove(codeLines, i)
                            break
                        else
                            break -- first non-empty line isn't an annotation
                        end
                    end
                end

                if not eventName then
                    log("[fzzl] Warning: skipping script entry with missing event name")
                else
                    -- Add @event annotation as a comment (required for registerEventsFromCache)
                    table.insert(lines, "--@" .. eventName)

                    -- Detect if this is a shorthand script (no function declaration)
                    local hasFunction = false
                    for _, line in ipairs(codeLines) do
                        local trimmed = line:match("^%s*(.-)%s*$")
                        if trimmed:match("^function%s+") or trimmed:match("^local%s+function%s+") or trimmed:match("^local%s+%w+%s*=%s*function") then
                            hasFunction = true
                            break
                        end
                    end

                    if hasFunction then
                        -- Regular script with function declaration - add as-is
                        for _, codeLine in ipairs(codeLines) do
                            table.insert(lines, codeLine)
                        end
                        log(string.format("[fzzl] Added script for event '%s'", eventName))
                    else
                        -- Shorthand script - wrap in temp_N function
                        local funcName = "temp_" .. tempIndex
                        table.insert(lines, "function " .. funcName .. "()")
                        for _, codeLine in ipairs(codeLines) do
                            table.insert(lines, codeLine)
                        end
                        table.insert(lines, "end")
                        log(string.format("[fzzl] Wrapped shorthand script for event '%s' as '%s'", eventName, funcName))
                        tempIndex = tempIndex + 1
                    end

                    table.insert(lines, "") -- blank line for readability
                end
            end
        end

        -- Store in fizzleContext.scripts as expected by saveScriptToCache
        fizzleContext.scripts = lines
        log("[fzzl] Loaded " .. #mmScripts .. " MiniMark scripts into fizzle")
    end

    load()
    return true
end

-- Deep copy utility (not currently used) May be useful for future enhancements
-- Cannot copy tables, table = tableOriginal simply references the original table, that's why we need deep copy
local function deepCopy(original)
    local copy = {}
    for key, value in pairs(original) do
        if type(value) == "table" then
            copy[key] = deepCopy(value) -- Recursively copy nested tables
        else
            copy[key] = value
        end
    end
    return copy
end

-- Must be called prior to any module usages
-- contextTable should have: functions.log (optional)
local function init(contextTable)
    fizzleContext = contextTable or {}
    fizzleContext.scripts = fizzleContext.scripts or {}
    fizzleContext.triggerEvent = triggerFizzleEvent
    log = (fizzleContext.functions and fizzleContext.functions.log) or function() end

    -- setup libraries
    libraries = dofile("applications/EEBrowser/fizzleLibraries/libraries.lua")
    libraries(sandbox, fizzleContext)

    log("[fzzl] Fizzle initialized!")
end



return {
    init = init,
    triggerFizzleEvent = triggerFizzleEvent,
    renew = renew
}
