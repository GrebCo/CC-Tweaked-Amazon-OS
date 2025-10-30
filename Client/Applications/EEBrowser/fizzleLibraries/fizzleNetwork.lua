local context

local function setupLibrary(fizzleContext)
    context = fizzleContext
    local sanitizedLibrary = {
        send = context.net.send,
        query = context.net.query,
    }
    return sanitizedLibrary
end

return setupLibrary