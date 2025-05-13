local PROTOCOL = "DNS"
local DNS_FILE = "DNS Master.txt"

peripheral.find("modem", rednet.open)
rednet.host(PROTOCOL, "dns_server_spawn")

print("DNS server listening on protocol '" .. PROTOCOL .. "'")

while true do
    local senderID, message = rednet.receive(PROTOCOL, 15)

    if message == "get" then
        print("Received request from ID: " .. tostring(senderID))

        local file = fs.open(DNS_FILE, "r")
        if file then
            local content = file.readAll()
            file.close()
            rednet.send(senderID, content, PROTOCOL)
            print("DNS data sent to client " .. tostring(senderID))
        else
            print("Error: Unable to open DNS file.")
        end
    end
end