local fizzleLibraryGenerator = dofile("/Client/Applications/EEBrowser/fizzleLibraries/fizzleNetwork.lua")

local function generateNetworkLibrary(contextTable)
    local networkLibrary = fizzleLibraryGenerator(contextTable)
    return networkLibrary
end


return {
    generateNetworkLibrary = generateNetworkLibrary
}