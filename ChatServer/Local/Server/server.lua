-- Chat Server - broadcasts messages from clients to chatbox
local PROTOCOL = "ChatServer"

local chatbox = peripheral.find("chat_box")
local modem = peripheral.find("modem")

if not chatbox then
    error("No chatbox found! Please connect a chatbox.")
end

if not modem then
    error("No modem found! Please connect a wireless modem.")
end

-- Open rednet
rednet.open(peripheral.getName(modem))
rednet.host(PROTOCOL, "ChatServer")

print("Chat Server Running")
print("Rednet opened on: " .. peripheral.getName(modem))

-- Main loop: receive and broadcast messages
while true do
    local senderID, message = rednet.receive(PROTOCOL)
    print("got message from " .. senderID)

    if type(message) == "table" and message.name and message.text then
        -- Use the name as the prefix parameter with <> brackets
        chatbox.sendMessage(message.text, message.name, "<>")
        print("<" .. message.name .. "> " .. message.text)

        -- Sleep for cooldown to avoid rate limiting
        os.sleep(0.5)
    end
end
