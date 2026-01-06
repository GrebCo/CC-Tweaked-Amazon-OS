local fizzleLibraryGenerator = dofile("applications/EEBrowser/fizzleLibraries/fizzleNetwork.lua")
local fizzleDocumentGenerator = dofile("applications/EEBrowser/fizzleLibraries/document.lua")
local fizzleCookieGenerator = dofile("applications/EEBrowser/fizzleLibraries/fizzleCookie.lua")



local function generateNetworkLibrary(contextTable)
    local networkLibrary = fizzleLibraryGenerator(contextTable)
    return networkLibrary
end

local function generateDocumentLibrary(contextTable)
    local documentLibrary = fizzleDocumentGenerator(contextTable)
    return documentLibrary
end

local function generateCookieLibrary(contextTable)
    local cookieLibrary = fizzleCookieGenerator(contextTable)
    return cookieLibrary
end

local function augmentSandbox(sandbox, contextTable)
    sandbox.net = generateNetworkLibrary(contextTable)
    sandbox.document = generateDocumentLibrary(contextTable)
    sandbox.cookie = generateCookieLibrary(contextTable)
    sandbox.debug = {
        getOnUpdateCalls = function()
            if contextTable.debugCounters then
                return contextTable.debugCounters.getOnUpdateCalls()
            end
            return 0
        end
    }
end

return augmentSandbox
