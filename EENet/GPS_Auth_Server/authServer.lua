-- GPS-Based Player Authentication Server (Outside-In Design)
-- Trilaterates computer positions from trusted beacon measurements
-- Verifies positions against player detector

---------------------------------------------------------------------
-- Configuration
---------------------------------------------------------------------
local PROTOCOL = "GPSAuth"
local MIN_BEACONS = 4  -- Minimum beacons required for stable 3D trilateration
local SAMPLE_WINDOW = 1.5  -- Seconds to collect measurements after first sample
local REQUEST_EXPIRY = 8  -- Seconds before discarding stale requests
local MATCH_TOLERANCE = 4.0  -- Blocks - how close computer must be to player
local DEBUG_OUTPUT = true  -- Include position/samples in response

-- TRUSTED BEACON WHITELIST
-- Only accept measurements from these computer IDs
-- Position is trusted and OVERRIDES any position in the packet
local KNOWN_BEACONS = {
    -- [beaconComputerID] = {x = number, y = number, z = number, beacon_id = string}
    -- Example:
    -- [10] = {x = 100, y = 64, z = 200, beacon_id = "beacon_1"},
    -- [11] = {x = 150, y = 70, z = 250, beacon_id = "beacon_2"},
    -- [12] = {x = 50, y = 65, z = 180, beacon_id = "beacon_3"},
    -- [13] = {x = 120, y = 68, z = 270, beacon_id = "beacon_4"},
}

---------------------------------------------------------------------
-- Load Trilateration Module
---------------------------------------------------------------------
local trilateration = dofile("trilateration.lua")

---------------------------------------------------------------------
-- State
---------------------------------------------------------------------
-- Keyed by "(client_id)_(nonce)" to prevent collisions
local pendingRequests = {}  -- {key: {samples: [], reply_ch: number, start_time: number, timer: number}}
local sessions = {}         -- {client_id: {player: string, timestamp: number}}
local playerDetector = nil
local modem = nil
local timers = {}  -- {timerID: request_key}

---------------------------------------------------------------------
-- Initialization
---------------------------------------------------------------------
local function init()
    -- Validate beacon configuration
    local beaconCount = 0
    for _ in pairs(KNOWN_BEACONS) do
        beaconCount = beaconCount + 1
    end

    if beaconCount < MIN_BEACONS then
        print("[WARNING] Only " .. beaconCount .. " beacons configured, need " .. MIN_BEACONS .. " for reliable auth")
        print("[WARNING] Please edit authServer.lua and add beacon entries to KNOWN_BEACONS")
    end

    -- Find player detector
    playerDetector = peripheral.find("playerDetector")
    if not playerDetector then
        print("[ERROR] No playerDetector peripheral found!")
        print("Please attach an Advanced Peripherals Player Detector.")
        error("PlayerDetector required")
    end
    print("[INFO] Player Detector found: " .. peripheral.getName(playerDetector))

    -- Find and open modem
    modem = peripheral.find("modem")
    if not modem then
        error("No modem found! Please attach a wireless modem.")
    end

    -- Open rednet (NOT hosting - DNS registration required for security)
    rednet.open(peripheral.getName(modem))
    print("[INFO] Rednet opened on protocol '" .. PROTOCOL .. "'")

    print("")
    print("==============================================")
    print("  GPS Player Authentication Server")
    print("  Computer ID: " .. os.getComputerID())
    print("  Protocol: " .. PROTOCOL)
    print("  Trusted Beacons: " .. beaconCount)
    print("==============================================")
    print("")
    print("IMPORTANT: Add this server to DNS_Master.json:")
    print('  {"id": ' .. os.getComputerID() .. ', "protocol": "' .. PROTOCOL .. '", "hostname": "gps_auth_server"}')
    print("")
end

---------------------------------------------------------------------
-- Generate request key
---------------------------------------------------------------------
local function makeKey(client_id, nonce)
    return tostring(client_id) .. "_" .. tostring(nonce)
end

---------------------------------------------------------------------
-- Player Detection using getPlayer(name)
---------------------------------------------------------------------
local function findPlayerAtPosition(pos)
    -- Try to get online players list
    local success, players = pcall(function()
        return playerDetector.getOnlinePlayers()
    end)

    if not success or not players then
        print("  [ERROR] Could not get online players list")
        return nil
    end

    -- Check each player
    local closest = nil
    local closestDist = math.huge

    for _, playerName in ipairs(players) do
        local ok, playerPos = pcall(function()
            return playerDetector.getPlayer(playerName)
        end)

        if ok and playerPos and playerPos.x and playerPos.y and playerPos.z then
            local dx = playerPos.x - pos.x
            local dy = playerPos.y - pos.y
            local dz = playerPos.z - pos.z
            local dist = math.sqrt(dx*dx + dy*dy + dz*dz)

            if dist <= MATCH_TOLERANCE and dist < closestDist then
                closest = playerName
                closestDist = dist
            end
        end
    end

    if closest then
        print("  [MATCH] Player '" .. closest .. "' at distance " .. string.format("%.2f", closestDist) .. " blocks")
    end

    return closest
end

---------------------------------------------------------------------
-- Process Authentication Request
---------------------------------------------------------------------
local function processAuthRequest(key)
    local request = pendingRequests[key]
    if not request then
        return
    end

    local parts = {}
    for part in string.gmatch(key, "[^_]+") do
        table.insert(parts, part)
    end
    local client_id = tonumber(parts[1])
    local nonce = table.concat(parts, "_", 2)

    print("")
    print("[PROCESSING] Client: " .. client_id .. " | Nonce: " .. nonce:sub(1,8) .. "...")
    print("  Samples collected: " .. #request.samples)

    -- Check minimum beacons
    if #request.samples < MIN_BEACONS then
        print("  [FAILED] Insufficient beacons (" .. #request.samples .. " < " .. MIN_BEACONS .. ")")

        -- Send failure response
        modem.open(request.reply_ch)
        modem.transmit(request.reply_ch, 0, {
            p = PROTOCOL,
            t = "auth_result",
            client_id = client_id,
            nonce = nonce,
            ok = false,
            reason = "insufficient_beacons"
        })
        modem.close(request.reply_ch)

        pendingRequests[key] = nil
        return
    end

    -- Trilaterate position
    local position, status = trilateration.trilaterate(request.samples)

    if not position then
        print("  [FAILED] Trilateration failed: " .. tostring(status))

        modem.open(request.reply_ch)
        modem.transmit(request.reply_ch, 0, {
            p = PROTOCOL,
            t = "auth_result",
            client_id = client_id,
            nonce = nonce,
            ok = false,
            reason = status or "trilateration_failed"
        })
        modem.close(request.reply_ch)

        pendingRequests[key] = nil
        return
    end

    print("  Computed Position: (" .. string.format("%.1f", position.x) .. ", " .. string.format("%.1f", position.y) .. ", " .. string.format("%.1f", position.z) .. ")")

    -- Find player at position
    local player = findPlayerAtPosition(position)

    if player then
        -- Authentication successful!
        print("  [SUCCESS] Authenticated as: " .. player)

        -- Create session
        sessions[client_id] = {
            player = player,
            timestamp = os.epoch("utc")
        }

        -- Build response
        local response = {
            p = PROTOCOL,
            t = "auth_result",
            client_id = client_id,
            nonce = nonce,
            ok = true,
            player = player
        }

        if DEBUG_OUTPUT then
            response.position = position
            response.samples = #request.samples
        end

        -- Send success response
        modem.open(request.reply_ch)
        modem.transmit(request.reply_ch, 0, response)
        modem.close(request.reply_ch)

    else
        -- No player found
        print("  [FAILED] No player found within " .. MATCH_TOLERANCE .. " blocks")

        local response = {
            p = PROTOCOL,
            t = "auth_result",
            client_id = client_id,
            nonce = nonce,
            ok = false,
            reason = "no_match"
        }

        if DEBUG_OUTPUT then
            response.position = position
        end

        modem.open(request.reply_ch)
        modem.transmit(request.reply_ch, 0, response)
        modem.close(request.reply_ch)
    end

    -- Clean up
    pendingRequests[key] = nil
end

---------------------------------------------------------------------
-- Handle Beacon Sample
---------------------------------------------------------------------
local function handleBeaconSample(senderID, sample)
    -- Protocol filtering
    if type(sample) ~= "table" or sample.p ~= PROTOCOL or sample.t ~= "beacon_sample" then
        return
    end

    -- Beacon whitelist check
    local beaconInfo = KNOWN_BEACONS[senderID]
    if not beaconInfo then
        print("[REJECT] Unknown beacon (ID: " .. senderID .. ") - not in whitelist")
        return
    end

    -- Extract fields
    local client_id = sample.client_id
    local nonce = sample.nonce
    local reply_ch = sample.reply_ch
    local distance = sample.d

    if not client_id or not nonce or not reply_ch or not distance then
        print("[ERROR] Beacon sample missing required fields")
        return
    end

    local key = makeKey(client_id, nonce)

    print("[SAMPLE] Beacon: " .. beaconInfo.beacon_id .. " (ID:" .. senderID .. ") | Client: " .. client_id .. " | Distance: " .. string.format("%.2f", distance))

    -- Initialize request if new
    if not pendingRequests[key] then
        pendingRequests[key] = {
            samples = {},
            reply_ch = reply_ch,
            start_time = os.epoch("utc") / 1000,  -- Convert to seconds
            timer = nil
        }

        -- Start collection window timer
        local timer = os.startTimer(SAMPLE_WINDOW)
        pendingRequests[key].timer = timer
        timers[timer] = key

        print("  [NEW REQUEST] Started " .. SAMPLE_WINDOW .. "s collection window")
    end

    -- Add sample (use trusted beacon position, not from packet)
    local sampleData = {
        beaconPos = {
            x = beaconInfo.x,
            y = beaconInfo.y,
            z = beaconInfo.z
        },
        beaconID = beaconInfo.beacon_id,
        distance = distance
    }

    -- Avoid duplicates from same beacon
    local exists = false
    for _, existing in ipairs(pendingRequests[key].samples) do
        if existing.beaconID == beaconInfo.beacon_id then
            exists = true
            break
        end
    end

    if not exists then
        table.insert(pendingRequests[key].samples, sampleData)
        print("  [ADDED] Total samples: " .. #pendingRequests[key].samples)
    end
end

---------------------------------------------------------------------
-- Cleanup Expired Requests
---------------------------------------------------------------------
local function cleanupExpiredRequests()
    local currentTime = os.epoch("utc") / 1000
    local toRemove = {}

    for key, request in pairs(pendingRequests) do
        if (currentTime - request.start_time) > REQUEST_EXPIRY then
            table.insert(toRemove, key)
        end
    end

    for _, key in ipairs(toRemove) do
        print("[CLEANUP] Expired request: " .. key)
        if pendingRequests[key].timer then
            timers[pendingRequests[key].timer] = nil
        end
        pendingRequests[key] = nil
    end
end

---------------------------------------------------------------------
-- Main Server Loop
---------------------------------------------------------------------
local function main()
    init()

    local lastCleanup = os.epoch("utc") / 1000

    while true do
        local event, p1, p2, p3 = os.pullEvent()

        if event == "rednet_message" then
            local senderID = p1
            local message = p2
            local protocol = p3

            if protocol == PROTOCOL then
                handleBeaconSample(senderID, message)
            end

        elseif event == "timer" then
            local timerID = p1
            local key = timers[timerID]

            if key then
                timers[timerID] = nil
                processAuthRequest(key)
            end
        end

        -- Periodic cleanup
        local now = os.epoch("utc") / 1000
        if (now - lastCleanup) > 5 then
            cleanupExpiredRequests()
            lastCleanup = now
        end
    end
end

---------------------------------------------------------------------
-- Start Server
---------------------------------------------------------------------
print("Starting GPS Player Authentication Server...")
print("")
print("SETUP REQUIRED:")
print("1. Edit KNOWN_BEACONS table in authServer.lua")
print("2. Add beacon computer IDs and their exact positions")
print("3. Add this server to DNS_Master.json")
print("")

main()
