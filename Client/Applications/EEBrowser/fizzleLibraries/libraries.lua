local fizzleLibraryGenerator = dofile("EEBrowser/fizzleLibraries/fizzleNetwork.lua")

local function generateNetworkLibrary(contextTable)
    local networkLibrary = fizzleLibraryGenerator(contextTable)
    return networkLibrary
end


return {
    generateNetworkLibrary = generateNetworkLibrary
}