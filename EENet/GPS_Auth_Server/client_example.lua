-- GPS Authentication Client Example
-- Demonstrates proper auth request with nonce and protocol filtering

local PROTOCOL = "GPSAuth"
local BROADCAST_CHANNEL = 1000
local REPLY_CHANNEL = 1001  -- Could be dynamic per client
local AUTH_TIMEOUT = 5  -- Seconds

---------------------------------------------------------------------
-- Generate nonce
---------------------------------------------------------------------
local function generateNonce()
    local time = os.epoch("utc")
    local random = math.random(1000000, 9999999)
    local client_id = os.getComputerID()
    return string.format("%d:%d:%d", time, random, client_id)
end

---------------------------------------------------------------------
-- Authenticate
---------------------------------------------------------------------
local function authenticate()
    local modem = peripheral.find("modem")
    if not modem then
        print("Error: No modem found!")
        return false, "no_modem"
    end

    -- Open reply channel
    modem.open(REPLY_CHANNEL)
    print("Opened reply channel: " .. REPLY_CHANNEL)

    -- Generate nonce
    local nonce = generateNonce()
    local client_id = os.getComputerID()

    print("Client ID: " .. client_id)
    print("Nonce: " .. nonce:sub(1, 20) .. "...")

    -- Build auth request
    local request = {
        p = PROTOCOL,
        t = "auth_request",
        client_id = client_id,
        nonce = nonce,
        reply_ch = REPLY_CHANNEL
    }

    -- Broadcast auth request
    print("")
    print("Broadcasting auth request...")
    modem.transmit(BROADCAST_CHANNEL, REPLY_CHANNEL, request)

    -- Wait for response
    local timer = os.startTimer(AUTH_TIMEOUT)
    local authenticated = false
    local player = nil

    print("Waiting for response (timeout: " .. AUTH_TIMEOUT .. "s)...")

    while true do
        local event, p1, p2, p3, p4, p5 = os.pullEvent()

        if event == "modem_message" then
            local side = p1
            local channel = p2
            local replyChannel = p3
            local message = p4
            local distance = p5

            -- Check if it's on our reply channel
            if channel == REPLY_CHANNEL and type(message) == "table" then
                -- Protocol filtering
                if message.p == PROTOCOL and message.t == "auth_result" then
                    -- Nonce validation
                    if message.nonce == nonce and message.client_id == client_id then
                        print("")
                        print("=== AUTH RESULT ===")

                        if message.ok then
                            print("Status: SUCCESS")
                            print("Authenticated as: " .. message.player)

                            if message.position then
                                print(string.format("Computed Position: (%.1f, %.1f, %.1f)",
                                    message.position.x, message.position.y, message.position.z))
                            end

                            if message.samples then
                                print("Beacon Samples: " .. message.samples)
                            end

                            authenticated = true
                            player = message.player
                        else
                            print("Status: FAILED")
                            print("Reason: " .. (message.reason or "unknown"))

                            if message.position then
                                print(string.format("Computed Position: (%.1f, %.1f, %.1f)",
                                    message.position.x, message.position.y, message.position.z))
                            end
                        end

                        break
                    else
                        print("[WARNING] Received auth result with wrong nonce or client_id (ignoring)")
                    end
                end
            end

        elseif event == "timer" and p1 == timer then
            print("")
            print("Authentication timeout - no response received")
            break
        end
    end

    modem.close(REPLY_CHANNEL)

    return authenticated, player
end

---------------------------------------------------------------------
-- Main
---------------------------------------------------------------------
print("==============================================")
print("  GPS Authentication Client Example")
print("==============================================")
print("")

local success, player = authenticate()

print("")
if success then
    print("Authentication successful!")
    print("You are: " .. player)
    print("")
    print("Session active - you can now access protected resources")
else
    print("Authentication failed")
    if player then
        print("Reason: " .. player)
    end
end
