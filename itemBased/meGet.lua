-- meGet.lua - Get items from ME system and transfer to player inventory
-- Usage: meGet.lua <itemName> <count> <imDirection>

local config = require("itemDump/config")

-- Get command line arguments
local args = {...}
if #args < 3 then
    print("Usage: meGet.lua <itemName> <count> <imDirection>")
    return
end

local itemName = args[1]
local count = tonumber(args[2])
local imDirection = args[3]

if count == nil or count <= 0 then
    error("Invalid count: " .. tostring(args[2]))
end

print("Getting", count, "of", itemName, "from ME system")
print("Using inventory manager at:", imDirection)

-- Find ME Bridge peripheral
local meBridge = peripheral.find("meBridge")
if meBridge == nil then
    error("ME Bridge not found! Make sure an ME Bridge is connected.")
end

-- Wrap the inventory manager for the specified user
local inventoryManager = peripheral.wrap(imDirection)
if inventoryManager == nil then
    error("Inventory manager not found at direction: " .. imDirection)
end

-- Get the item from ME system
local success, result = pcall(function()
    -- Export item from ME system to a buffer/chest
    -- First, try to export the item directly to the player
    local exported = meBridge.exportItem({name = itemName, count = count}, imDirection)
    
    if exported == nil or exported == 0 then
        print("Could not export item. Checking if item exists in ME system...")
        
        -- Check if item exists in ME system
        local items = meBridge.listItems()
        local found = false
        for _, item in pairs(items) do
            if item.name == itemName then
                found = true
                print("Found", item.amount, "of", itemName, "in ME system")
                if item.amount < count then
                    print("Warning: Only", item.amount, "available, requested", count)
                end
                break
            end
        end
        
        if not found then
            error("Item not found in ME system: " .. itemName)
        else
            error("Failed to export item (might be full or item cannot be exported)")
        end
    else
        print("Successfully exported", exported, "of", itemName)
        
        -- Try to add the item to the player's inventory
        -- Wait a moment for the item to appear in the buffer
        sleep(0.5)
        
        -- Add items to player inventory (slots 9-35 are typically inventory slots)
        local added = inventoryManager.addItemToPlayer("up", {})
        if added then
            print("Successfully added items to player inventory")
        else
            print("Warning: Could not add items to player. Items may be in buffer chest.")
        end
    end
end)

if not success then
    print("Error:", result)
    error(result)
end

print("meGet completed successfully!")
