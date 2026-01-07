local events = {}

function registerEvent(eventName)
    events[eventName] = {}  -- create a table for handlers
end

function registerFunction(eventName, func)
    if not events[eventName] then
        events[eventName] = {}
    end
    table.insert(events[eventName], func)
end

-- TODO: launch as a coroutine to prevent blocking the thread. !Possible race condition!
function triggerEvent(eventName, params)
    local funcs = events[eventName]
    if not funcs then return end
    for _, func in ipairs(funcs) do
        func(params)
    end
end

function resetEvents()
    -- Nukes events
    events = {}
    return true
end

return {
    registerEvent = registerEvent,
    registerFunction = registerFunction,
    triggerEvent = triggerEvent,
    resetEvents = resetEvents,
}