local context



local function setupLibrary(fizzleContext)
    local sanitizedLibrary = {
        send = fizzleContext.net.send,
        query = fizzleContext.net.query,
        sendByLookup = fizzleContext.net.sendByLookup,
    }
    return sanitizedLibrary
end

return setupLibrary
