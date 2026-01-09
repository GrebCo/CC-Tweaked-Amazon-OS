local context


local function queryForcedTimeout(target, message, timeout)
    if timout > 2 then
        timeout = 2
    end
    context.net.query(target, message, timeout)
end

local function setupLibrary(fizzleContext)
    context = fizzleContext
    local sanitizedLibrary = {
        send = fizzleContext.net.send,
        query = queryForcedTimeout,
        sendByLookup = fizzleContext.net.sendByLookup,
    }
    return sanitizedLibrary
end

return setupLibrary
