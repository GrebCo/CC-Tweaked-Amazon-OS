local context



local function setupLibrary(fizzleContext)
    local sanitizedLibrary = {
        send = fizzleContext.net.send,
        query = fizzleContext.net.query,
    }
    return sanitizedLibrary
end

return setupLibrary
