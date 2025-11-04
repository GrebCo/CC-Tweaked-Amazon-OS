-- fizzle_test.lua
-- Runs setup and then enters an interactive REPL-style shell for testing

local minimark = dofile("OSUtil/MiniMark.lua")

local fizzle = dofile("EEBrowser/fizzle.lua")

local FILE = "EEBrowser/Default.txt"

-- Context table shared across everything
local contextTable = {
    elements = {},    -- All active UI/MiniMark elements
    scenes = {},      -- All UI scenes
    functions = {},   -- Shared callable functions
    scripts = {},     -- Script-defined functions or handlers
    eventTrigger = nil, -- Fizzle event trigger function
    events = {}
}

-- Simple log function that writes to console and debug.log file
local logFile = fs.open("debug.log", "w")
local function log(msg)
    local message = "[LOG] " .. tostring(msg)
    print(message)
    if logFile then
        logFile.writeLine(message)
        logFile.flush()
    end
end

-- Ensure log file is closed when done
local function closeLog()
    if logFile then
        logFile.close()
        logFile = nil
    end
end

contextTable.functions.log = log

-- Initialize Fizzle once at boot
fizzle.init(contextTable)

-- Load MiniMark scripts if available
local mmScripts = {}
if minimark and minimark.getScripts then
    mmScripts = minimark.getScripts(FILE) or {}
    log("Loaded " .. #mmScripts .. " scripts from MiniMark")
else
    log("Warning: minimark.getScripts() not found")
end

-- Print the MiniMark scripts for debugging
log("MiniMark scripts:")
for i, entry in ipairs(mmScripts) do
    log(string.format("  [%d] Event: %s", i, tostring(entry.event)))
    log("      Code: " .. tostring(entry.code):sub(1, 60) .. (tostring(entry.code):len() > 60 and "..." or ""))
end

-- Renew with new scripts (loads, processes, and registers events)
fizzle.renew(mmScripts)
log("Fizzle renewed - scripts processed and events registered")

-- Test triggering the event
log("Testing: triggering 'ConfirmEvent' (shorthand Script)")
fizzle.triggerFizzleEvent("ConfirmEvent")

log("Testing: triggering 'ToggleSound'")
fizzle.triggerFizzleEvent("ToggleSound")

log("Testing: triggering 'secondShorthand'")
fizzle.triggerFizzleEvent("secondShorthand")

-- Close the log file
closeLog()
log = print -- Fallback to print after closing file
