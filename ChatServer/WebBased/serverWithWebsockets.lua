-- Chat Server - broadcasts messages from clients to chatbox using WebSockets
local PROTOCOL   = "ChatServer"
local SERVER_NAME = "CraftoriaNA"          -- must match what you use in FastAPI

-- Try different localhost addresses - CC:Tweaked might need the actual host IP
-- Change this to your computer's IP if 127.0.0.1 doesn't work
local WS_URL      = "ws://127.0.0.1:8000/ws/" .. SERVER_NAME

local chatbox = peripheral.find("chat_box")
local modem   = peripheral.find("modem")

if not chatbox then
    error("No chatbox found! Please connect a chatbox.")
end

if not modem then
    error("No modem found! Please connect a wireless modem.")
end

-- Optional: sanity check that HTTP API is enabled
if not http then
    error("HTTP API is disabled. Enable it in the config to use the web bridge.")
end

-- Open rednet
rednet.open(peripheral.getName(modem))
rednet.host(PROTOCOL, "ChatServer")

print("Chat Server Running")
print("Rednet opened on: " .. peripheral.getName(modem))
print("Connecting to WebSocket: " .. WS_URL)

local function motdParse(str)
    return (str:gsub("&([0-9a-fk-or])", "\167%1"))
end

-------------------------------------------------
-- WebSocket connection and message handling
-------------------------------------------------

local ws = nil
local wsConnected = false

local function connectWebSocket()
    print("Attempting WebSocket connection to: " .. WS_URL)

    -- Check if http.websocket is available
    if not http.websocket then
        print("ERROR: http.websocket is not available!")
        print("Make sure websockets are enabled in CC:Tweaked config")
        return false
    end

    local success, handle = pcall(http.websocket, WS_URL)

    if success and handle then
        ws = handle
        wsConnected = true
        print("WebSocket connected successfully!")
        return true
    else
        print("WebSocket connection failed!")
        print("Error:", tostring(handle))
        print("")
        print("Troubleshooting:")
        print("1. Is the Python server running?")
        print("2. Try changing WS_URL to your PC's IP")
        print("3. Check CC:Tweaked config allows websockets")
        wsConnected = false
        return false
    end
end

local function sendAck(id)
    if ws and wsConnected then
        local ackMsg = textutils.serializeJSON({
            type = "ack",
            id = id
        })
        ws.send(ackMsg)
    end
end

local function handleWebSocketMessage(msgData)
    local ok, data = pcall(textutils.unserializeJSON, msgData)
    if not ok then
        print("Bad JSON from WebSocket:", msgData)
        return
    end

    -- Handle different message types
    if data.type == "new_message" then
        local msg = data.data
        if msg.message and msg.name and msg.id then
            chatbox.sendMessage(motdParse(msg.message), msg.name, "<>")
            print("[WEB] <" .. msg.name .. "> " .. msg.message .. " (id " .. msg.id .. ")")
            sendAck(msg.id)
            os.sleep(0.2)
        end
    elseif data.type == "queued_messages" then
        -- Handle multiple queued messages on initial connection
        local messages = data.data
        if type(messages) == "table" then
            for _, msg in ipairs(messages) do
                if msg.message and msg.name and msg.id then
                    chatbox.sendMessage(motdParse(msg.message), msg.name, "<>")
                    print("[WEB] <" .. msg.name .. "> " .. msg.message .. " (id " .. msg.id .. ")")
                    sendAck(msg.id)
                    os.sleep(0.2)
                end
            end
        end
    elseif data.type == "ack_confirmed" then
        -- Server confirmed our ack
        -- print("Ack confirmed for id:", data.id)
    end
end

-----------------
-- Main runtime
-----------------

-- Initial connection
if not connectWebSocket() then
    print("Failed to connect. Retrying in 5 seconds...")
    os.sleep(5)
    if not connectWebSocket() then
        error("Could not establish WebSocket connection")
    end
end

while true do
    -- Use parallel to handle both rednet and websocket events
    parallel.waitForAny(
        -- Handle rednet messages
        function()
            while true do
                local senderID, message = rednet.receive(PROTOCOL)
                if senderID then
                    print("got message from " .. senderID)

                    if type(message) == "table" and message.name and message.text then
                        chatbox.sendMessage(message.text, message.name, "<>")
                        print("<" .. message.name .. "> " .. message.text)
                        os.sleep(0.5)
                    end
                end
            end
        end,

        -- Handle WebSocket messages
        function()
            while true do
                if ws and wsConnected then
                    local msg = ws.receive(0.5)  -- 0.5 second timeout
                    if msg then
                        handleWebSocketMessage(msg)
                    end
                else
                    -- Try to reconnect if disconnected
                    print("WebSocket disconnected, attempting to reconnect...")
                    os.sleep(5)
                    connectWebSocket()
                end
            end
        end,

        -- Monitor WebSocket connection health
        function()
            while true do
                os.sleep(30)  -- Check every 30 seconds
                if ws and wsConnected then
                    -- Try to ping by sending a small message
                    local success = pcall(function()
                        ws.send(textutils.serializeJSON({type = "ping"}))
                    end)
                    if not success then
                        print("WebSocket connection lost")
                        wsConnected = false
                        if ws then
                            pcall(ws.close)
                        end
                    end
                end
            end
        end
    )

    -- If we get here, something broke - try to restart
    print("Main loop exited unexpectedly, restarting...")
    os.sleep(2)
    if ws then
        pcall(ws.close)
    end
    connectWebSocket()
end
