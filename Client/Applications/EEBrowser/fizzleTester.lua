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

-- Simple log function
local function log(msg)
    print("[LOG] " .. tostring(msg))
end

contextTable.functions.log = log

-- Load MiniMark scripts if available
if minimark and minimark.getScripts then
    contextTable.scripts = minimark.getScripts(FILE) or {}
else
    log("Warning: minimark.getScripts() not found")
end

print("Loaded " .. tostring(#contextTable.scripts) .. " scripts from " .. FILE)


-- for loop and print the scripts loaded
log("Loaded scripts:")
-- Simplify the scripts table into an array of {eventName, code} pairs
for eventName, code in pairs(contextTable.scripts) do
    print("Event: " .. eventName)
    for _,line in pairs(code) do
        print("  " .. line)
    end
end


-- Initialize Fizzle with this context
-- fizzle.init(contextTable)
-- log("Fizzle initialized with context")
--
-- fizzle.renew()
-- log("Fizzle renewed")
--
-- fizzle.triggerFizzleEvent("helloevent")
-- log("Triggered 'helloevent'")


