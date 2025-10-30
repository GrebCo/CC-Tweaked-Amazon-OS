contextTable = nil

local function getElementById(id)

end

local function setElementBodyById(id)

end

local function setupDocument(context)
    local elementLibrary = {
        getElementById = getElementById,
        setElementBodyById = setElementBodyById,
    }
    contextTable = context

    return elementLibrary
end

return setupDocument