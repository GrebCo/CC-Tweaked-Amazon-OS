local fizzleLibraryGenerator = dofile("EEBrowser/fizzleLibraries/fizzleNetwork.lua")
local fizzleDocumentGenerator = dofile("EEBrowser/fizzleLibraries/document.lua")

local function augmentSandbox(sandbox,contextTable)

    sandbox.net = generateNetworkLibrary(contextTable)
    sandbox.document = generateDocumentLibrary(contextTable)

end

local function generateNetworkLibrary(contextTable)
    local networkLibrary = fizzleLibraryGenerator(contextTable)
    return networkLibrary
end

local function generateDocumentLibrary(contextTable)
    local documentLibrary = fizzleDocumentGenerator(contextTable)
    return documentLibrary
end

return augmentSandbox