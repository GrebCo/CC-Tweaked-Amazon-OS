-- GPS Authentication Beacon
-- Measures distance to clients and forwards measurements to auth server

---------------------------------------------------------------------
-- Configuration
---------------------------------------------------------------------
local config
if fs.exists("beacon_config.lua") then
    config = dofile("beacon_config.lua")
else
    print("[ERROR] beacon_config.lua not found!")
    print("Please create beacon_config.lua with beacon position and settings.")
    error("Configuration required")
end

-- Validate configuration
if not config.position or not config.position.x or not config.position.y or not config.position.z then
    error("Invalid config: position {x, y, z} required")
end
if not config.beaconID then
    error("Invalid config: beaconID required")
end

local BEACON_POS = config.position
local BEACON_ID = config.beaconID
local AUTH_SERVER_HOSTNAME = config.authServerHostname or "gps_auth_server"
local AUTH_PROTOCOL = config.authProtocol or "GPSAuth"
local LISTEN_CHANNEL = config.listenChannel or 1000
local DNS_PROTOCOL = config.dnsProtocol or "DNS"

---------------------------------------------------------------------
-- State
---------------------------------------------------------------------
local authServerID = nil
local modem = nil

---------------------------------------------------------------------
-- DNS Lookup
---------------------------------------------------------------------
local function resolveAuthServer()
    print("[DNS] Looking up '" .. AUTH_SERVER_HOSTNAME .. "'...")

    -- Find DNS server
    local dnsServerID = rednet.lookup(DNS_PROTOCOL)
    if not dnsServerID then
        print("[ERROR] DNS server not found on protocol '" .. DNS_PROTOCOL .. "'")
        return nil
    end

    if type(dnsServerID) == "table" then
        dnsServerID = dnsServerID[1]  -- Take first DNS server
    end

    print("[DNS] Querying DNS server ID: " .. dnsServerID)

    -- Request DNS data
    rednet.send(dnsServerID, "get", DNS_PROTOCOL)
    local senderID, response = rednet.receive(DNS_PROTOCOL, 5)

    if not response then
        print("[ERROR] No response from DNS server")
        return nil
    end

    -- Parse JSON
    local success, dnsData = pcall(textutils.unserializeJSON, response)
    if not success or type(dnsData) ~= "table" then
        print("[ERROR] Invalid DNS response")
        return nil
    end

    -- Search for auth server hostname
    for _, entry in ipairs(dnsData) do
        if entry.hostname == AUTH_SERVER_HOSTNAME and entry.protocol == AUTH_PROTOCOL then
            print("[DNS] Resolved '" .. AUTH_SERVER_HOSTNAME .. "' to ID: " .. entry.id)
            return entry.id
        end
    end

    print("[ERROR] Auth server not found in DNS")
    return nil
end

---------------------------------------------------------------------
-- Initialization
---------------------------------------------------------------------
local function init()
    -- Find and open modem
    modem = peripheral.find("modem")
    if not modem then
        error("No modem found! Please attach a wireless modem.")
    end

    -- Open rednet
    rednet.open(peripheral.getName(modem))
    print("[INFO] Rednet opened")

    -- Open listen channel
    modem.open(LISTEN_CHANNEL)
    print("[INFO] Listening on modem channel " .. LISTEN_CHANNEL)

    -- Resolve auth server via DNS
    authServerID = resolveAuthServer()
    if not authServerID then
        error("Failed to resolve auth server via DNS")
    end

    print("")
    print("==============================================")
    print("  GPS Authentication Beacon #" .. BEACON_ID)
    print("  Position: (" .. BEACON_POS.x .. ", " .. BEACON_POS.y .. ", " .. BEACON_POS.z .. ")")
    print("  Auth Server ID: " .. authServerID)
    print("  Listening on channel: " .. LISTEN_CHANNEL)
    print("==============================================")
    print("")
end

---------------------------------------------------------------------
-- Handle Authentication Request
---------------------------------------------------------------------
local function handleAuthRequest(message, distance, replyChannel)
    -- Validate message structure
    if type(message) ~= "table" then
        return
    end

    -- Protocol filtering
    if message.p ~= AUTH_PROTOCOL or message.t ~= "auth_request" then
        return
    end

    local clientID = message.client_id
    local nonce = message.nonce

    if not clientID then
        print("[ERROR] Auth request missing client_id")
        return
    end

    if not nonce then
        print("[ERROR] Auth request missing nonce")
        return
    end

    -- Check if distance is available
    if not distance then
        print("[WARN] Client ID " .. clientID .. " is in different dimension or out of range")
        return
    end

    print("[REQUEST] Client: " .. clientID .. " | Nonce: " .. nonce:sub(1,8) .. "... | Distance: " .. string.format("%.2f", distance) .. " blocks")

    -- Build measurement message (DO NOT include beacon position - server provides it)
    local measurement = {
        p = AUTH_PROTOCOL,
        t = "beacon_sample",
        client_id = clientID,
        nonce = nonce,
        reply_ch = replyChannel,
        beacon_id = BEACON_ID,
        d = distance,
        timestamp = os.epoch("utc")
    }

    -- Forward to auth server via rednet (provides senderID for whitelisting)
    rednet.send(authServerID, measurement, AUTH_PROTOCOL)
    print("[SENT] Measurement forwarded to auth server (ID: " .. authServerID .. ")")
end

---------------------------------------------------------------------
-- Main Loop
---------------------------------------------------------------------
local function main()
    init()

    local lastDNSRefresh = os.epoch("utc")
    local DNS_REFRESH_INTERVAL = 300000  -- 5 minutes

    while true do
        -- Refresh DNS periodically
        local now = os.epoch("utc")
        if (now - lastDNSRefresh) > DNS_REFRESH_INTERVAL then
            print("[DNS] Refreshing auth server ID...")
            local newID = resolveAuthServer()
            if newID then
                authServerID = newID
                lastDNSRefresh = now
            end
        end

        -- Wait for events
        local event, side, channel, replyChannel, message, distance = os.pullEvent()

        if event == "modem_message" and channel == LISTEN_CHANNEL then
            handleAuthRequest(message, distance, replyChannel)
        end
    end
end

---------------------------------------------------------------------
-- Start Beacon
---------------------------------------------------------------------
print("Starting GPS Authentication Beacon...")
print("")

main()
