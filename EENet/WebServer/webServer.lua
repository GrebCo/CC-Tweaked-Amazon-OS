local PROTOCOL = "EENet"
local WEBSITE_NAME = "Demo"
local WEBSITE_FILE = WEBSITE_NAME .. ".txt" -- Default index file

-- Open modem and host the protocol
peripheral.find("modem", rednet.open)
rednet.host(PROTOCOL, "web_server_" .. WEBSITE_NAME)

print("Web server listening on protocol '" .. PROTOCOL .. "' for site '" .. WEBSITE_NAME .. "'")

while true do
    local senderID, message = rednet.receive(PROTOCOL, 10)
    
    if message then
        print("{DEBUG} Received message: " .. tostring(message) .. " from ID: " .. tostring(senderID))
        local requestedFile
        if message == WEBSITE_NAME then
            requestedFile = WEBSITE_FILE
        elseif message:sub(1, #WEBSITE_NAME + 1) == WEBSITE_NAME .. "/" then
            local subPath = message:sub(#WEBSITE_NAME + 2)
            requestedFile = subPath .. ".txt"
        else
            requestedFile = WEBSITE_FILE
        end

        print("Received request for '" .. tostring(message) .. "' from ID: " .. tostring(senderID))

        if not fs.exists(requestedFile) then
            print("Error: Website file '" .. requestedFile .. "' not found.")
        else
            local file = fs.open(requestedFile, "r")
            local content = file.readAll()
            file.close()

            rednet.send(senderID, content, PROTOCOL)
            print("Sent website content to ID: " .. tostring(senderID))
        end
        senderID, message = nil, nil
    end
end
