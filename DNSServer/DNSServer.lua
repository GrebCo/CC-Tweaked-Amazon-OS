local PROTOCOL = "DNS"
local DNS_FILE = "DNS_Master.json"

-- Open modem and host rednet
peripheral.find("modem", rednet.open)
rednet.host(PROTOCOL, "dns_server_spawn")

print("DNS server listening on protocol '" .. PROTOCOL .. "'")

while true do
    local senderID, message = rednet.receive(PROTOCOL, 15)

    if message == "get" then
        print("Received DNS request from ID: " .. tostring(senderID))

        if not fs.exists(DNS_FILE) then
            print("Error: DNS file not found.")
        else
            local file = fs.open(DNS_FILE, "r")
            local content = file.readAll()
            file.close()

            -- Optional: Validate JSON
            local ok, data = pcall(textutils.unserializeJSON, content)
            if not ok or type(data) ~= "table" then
                print("Error: Invalid JSON data in file.")
            else
                rednet.send(senderID, content, PROTOCOL)
                print("Sent DNS data to client " .. tostring(senderID))
            end
        end
    end
end