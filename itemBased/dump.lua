local config = require("config")

local imEfraim = peripheral.wrap(config.efraimIMDirection)
local imEasease = peripheral.wrap(config.easeaseIMDirection)
if imEfraim == nil then error("Efraim's inventory manager not found") end
if imEasease == nil then error("Easease's inventory manager not found") end

efraimID = 234
easeaseID = 235

-- Open any wireless modem
local modem = peripheral.find("modem")
if modem == nil then error("no modem found") end
rednet.open("front")

local PROTOCOL = "EEdump"

print("Wireless dumper running on protocol:", PROTOCOL)

while true do
  local sender, msg, protocol = rednet.receive(PROTOCOL)
    if sender == config.efraimID then
        print("Detecting Efraim wants to do something")
        im = imEfraim
    end
    if sender == config.easeaseID then
        print("Detecting Easease wants to do something")
        im = imEasease
    end
    
    local dump = (msg.command == config.dumpKeword)
    local getItem = (msg.command == config.getKeword)

    if dump then
        print("Dumping slots 9 through 35")
        local myInv = im.getItems()
        local count = 0
        for k, v in pairs(myInv) do
            if v.slot > 8 and v.slot < 36 then
            print("attempting to remove",v.name,"from slot",v.slot,"count",v.count)
            im.removeItemFromPlayer("up", {fromSlot = v.slot})
            count = count + 1
            end
        end
        print("Detected",count,"slots to be dumped")
        print("Dumping Items to ME System")
        shell.run("meDump.lua")
        rednet.send(sender, {status = "done"}, PROTOCOL)
    end

    if getItem then
        print("Getting item:",msg.itemName,"count:",msg.count)
        -- Determine which user is requesting and pass the IM direction
        local imDirection = ""
        if sender == config.efraimID then
            imDirection = config.efraimIMDirection
        elseif sender == config.easeaseID then
            imDirection = config.easeaseIMDirection
        end
        
        -- Use shell.run with a properly constructed command string
        local command = string.format("meGet.lua %q %s %q", msg.itemName, tostring(msg.count), imDirection)
        shell.run(command)
        
        rednet.send(sender, {status = "done"}, PROTOCOL)
    end
end
