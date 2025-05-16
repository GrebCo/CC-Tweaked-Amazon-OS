local PROTOCOL = "AmazonInternet"
local WEBSITE_NAME = "COWZ"
local WEBSITE_FILE = WEBSITE_NAME .. ".txt"

-- Open modem and host the protocol
peripheral.find("modem", rednet.open)
rednet.host(PROTOCOL, "web_server_" .. WEBSITE_NAME)

print("Web server listening on protocol '" .. PROTOCOL .. "' for site '" .. WEBSITE_NAME .. "'")

while true do
    local senderID, message = rednet.receive(PROTOCOL, 10)

    if message == WEBSITE_NAME then
        print("Received request for '" .. WEBSITE_NAME .. "' from ID: " .. tostring(senderID))

        if not fs.exists(WEBSITE_FILE) then
            print("Error: Website file '" .. WEBSITE_FILE .. "' not found.")
        else
            local file = fs.open(WEBSITE_FILE, "r")
            local content = file.readAll()
            file.close()

            rednet.send(senderID, content, PROTOCOL)
            print("Sent website content to ID: " .. tostring(senderID))
        end
    end
end
