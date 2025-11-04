local contextTable = nil
local mmRenderer = nil
local logger = nil


-- This can be used to get and set properties of elements in the MMRenderer by their ID.
-- Example:
-- local myElement = document.getElementById("myElementID")
-- if myElement then
--     print("Element found: " .. myElement.text)
--     -- Modify properties
--     myElement.text = "New Text"
-- end
local function getElementById(id)
    local element = contextTable.fizzleLibFunctions.mmRenderer:findElementsByID(id)[1].element
    return element
end

local function setElementBodyById(id, text)
    contextTable.fizzleLibFunctions.mmRenderer:modifyElementsByID(id, function(elem)
        -- Change the label/text of the element
        if elem.label then
            return { label = text }
        elseif elem.text then
            return { text = text }
        end
    end)
end


local function setupDocument(context)
    context.functions.log("Cows")
    local elementLibrary = {
        getElementById = getElementById,
        setElementBodyById = setElementBodyById
    }
    contextTable = context
    mmRenderer = context.fizzleLibFunctions.mmRenderer
    return elementLibrary
end

return setupDocument
