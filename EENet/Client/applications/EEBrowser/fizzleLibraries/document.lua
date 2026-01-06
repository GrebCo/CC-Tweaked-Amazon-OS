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
    local mmRenderer = contextTable.fizzleLibFunctions.mmRenderer

    -- First check UI elements (textboxes, etc.) for live data
    -- These have the actual user input in the .text property
    if mmRenderer._uiElements then
        for _, uiElem in ipairs(mmRenderer._uiElements) do
            if uiElem.id == id then
                return uiElem  -- Returns textfield with .text property containing live input
            end
        end
    end

    -- Fallback to MiniMark elements for non-UI elements (buttons, text, etc.)
    local results = mmRenderer:findElementsByID(id)
    if results and results[1] then
        return results[1].element
    end

    return nil
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
