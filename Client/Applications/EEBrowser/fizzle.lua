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
        __index = function(t, k)
            -- First check if it exists in the sandbox itself (rawget to avoid recursion)
            local val = rawget(t, k)
            if val ~= nil then
                return val
            end
            -- Only log/block if trying to access something not in sandbox
            log("[fzzl] Access to '" .. tostring(k) .. "' is not allowed in Fizzle scripts")
            return nil
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

    log("[fzzl] DEBUG: Processing " .. #lines .. " lines from cache")
    local lastEventName = nil
    for i, line in ipairs(lines) do
        local eventTag = line:match("@([%w_]+)") -- detect annotation
        if eventTag then
            lastEventName = eventTag
            cacheLua_scriptFile.writeLine(line)
            log("[fzzl] DEBUG: Line " .. i .. " - Found event annotation: @" .. eventTag)
        else
            -- detect several forms of function declaration
            -- Use simpler, more robust patterns
            local funcName = line:match("local%s+function%s+([%w_]+)%s*%(")
                    or line:match("%s*function%s+([%w_]+)%s*%(")
                    or line:match("local%s+([%w_]+)%s*=%s*function%s*%(")

            if lastEventName then
                log("[fzzl] DEBUG: Line " .. i .. " (after @" .. lastEventName .. "): '" .. line:sub(1, 50) .. "'")
                log("[fzzl] DEBUG:   Detected funcName: " .. tostring(funcName))
            end

            if funcName and lastEventName then
                functionEventMap[funcName] = lastEventName
                log("[fzzl] DEBUG: Line " .. i .. " - Mapped function '" .. funcName .. "' to event '" .. lastEventName .. "'")
                lastEventName = nil
            end
            cacheLua_scriptFile.writeLine(line)
        end
    end

    log("[fzzl] DEBUG: functionEventMap contains:")
    for fn, ev in pairs(functionEventMap) do
        log("[fzzl] DEBUG:   " .. fn .. " => " .. ev)
    end

    cacheLua_scriptFile.close()

    -- Load the script content from cache
    local scriptContent = table.concat(lines, "\n")
    log("[fzzl] DEBUG: Script content length: " .. #scriptContent .. " bytes")
    log("[fzzl] DEBUG: Creating sandbox...")

    local sandbox = createSandbox()
    log("[fzzl] DEBUG: Loading script into sandbox...")

    local scriptFunc, err = load(scriptContent, "fizzle_script", "t", sandbox)

    if not scriptFunc then
        log("[fzzl] ERROR: Failed to load script: " .. (err or "unknown error"))
        log("[fzzl] DEBUG: Script content preview (first 200 chars):")
        log(scriptContent:sub(1, 200))
        return false
    end

    log("[fzzl] DEBUG: Executing script in sandbox...")
    local execSuccess, execErr = pcall(scriptFunc)
    if not execSuccess then
        log("[fzzl] ERROR: Failed to execute script: " .. (execErr or "unknown error"))
        return false
    end
    log("[fzzl] DEBUG: Script executed successfully")

    -- Register functions
    log("[fzzl] DEBUG: functionEventMap has " .. tostring(#functionEventMap) .. " entries")
    for funcName, eventName in pairs(functionEventMap) do
        log("[fzzl] DEBUG: Looking for function '" .. funcName .. "' in sandbox for event '" .. eventName .. "'")
        local func = sandbox[funcName]
        log("[fzzl] DEBUG: sandbox[" .. funcName .. "] = " .. tostring(func) .. " (type: " .. type(func) .. ")")

        if func and type(func) == "function" then
            events.registerFunction(eventName, function(params)
                log("[fzzl] DEBUG: Executing '" .. funcName .. "' for event '" .. eventName .. "'")
                local ok, res = pcall(func, params)
                if not ok then
                    log("[fzzl] ERROR: Exception in event '" .. eventName .. "': " .. tostring(res))
                    return false
                end
                log("[fzzl] DEBUG: '" .. funcName .. "' executed successfully, result: " .. tostring(res))
                return res
            end)
            log("[fzzl] Registered '" .. funcName .. "' for event '" .. eventName .. "'")
        else
            log("[fzzl] ERROR: function '" .. funcName .. "' not found in sandbox (type was: " .. type(func) .. ")")
            -- Debug: List all keys in sandbox
            local keys = {}
            for k in pairs(sandbox) do
                if type(sandbox[k]) == "function" then
                    table.insert(keys, k)
                end
            end
            log("[fzzl] DEBUG: Available functions in sandbox: " .. table.concat(keys, ", "))
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
    log("[fzzl] Fizzle initialized!")
end



return {
    init = init,
    triggerFizzleEvent = triggerFizzleEvent,
    renew = renew
}


