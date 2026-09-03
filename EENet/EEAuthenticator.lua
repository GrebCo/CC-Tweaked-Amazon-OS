-- EEAuthenticator - GPS + OTP Authentication Client
-- Can be used as a library (require) or run standalone

local PROTOCOL = "EEAuth"
local BEACON_CHANNEL = 1000
local AUTH_TIMEOUT = 5

local EEAuthenticator = {}

local modem = nil
local authResult = nil  -- Cached last auth result

---------------------------------------------------------------------
-- Initialize modem
---------------------------------------------------------------------
function EEAuthenticator.init()
    modem = peripheral.find("modem")
    if not modem then
        return false, "No modem found"
    end
    rednet.open(peripheral.getName(modem))
    return true
end

---------------------------------------------------------------------
-- Generate unique nonce
---------------------------------------------------------------------
local function generateNonce()
    return tostring(os.epoch("utc")) .. "_" .. tostring(math.random(1000, 9999))
end

---------------------------------------------------------------------
-- GPS Authentication (broadcasts to beacons)
---------------------------------------------------------------------
function EEAuthenticator.authenticate()
    if not modem then
        local ok, err = EEAuthenticator.init()
        if not ok then
            return {ok = false, error = err}
        end
    end

    local clientID = os.getComputerID()
    local nonce = generateNonce()
    local replyChannel = 2000 + (clientID % 1000)  -- Unique reply channel

    -- Open reply channel
    modem.open(replyChannel)

    -- Broadcast auth request to beacons
    local request = {
        p = PROTOCOL,
        t = "auth_request",
        client_id = clientID,
        nonce = nonce,
        reply_ch = replyChannel
    }

    modem.transmit(BEACON_CHANNEL, replyChannel, request)

    -- Wait for response
    local timer = os.startTimer(AUTH_TIMEOUT)
    while true do
        local event, p1, p2, p3, p4, p5 = os.pullEvent()

        if event == "modem_message" then
            local channel, replyTo, msg = p2, p3, p4
            if channel == replyChannel and type(msg) == "table" then
                if msg.p == PROTOCOL and msg.t == "auth_result" then
                    if msg.nonce == nonce then
                        modem.close(replyChannel)
                        authResult = msg
                        return msg
                    end
                end
            end

        elseif event == "timer" and p1 == timer then
            modem.close(replyChannel)
            return {ok = false, error = "timeout", status = "timeout"}
        end
    end
end

---------------------------------------------------------------------
-- Request OTP (via rednet to auth server)
---------------------------------------------------------------------
function EEAuthenticator.requestOTP(username)
    if not username or username == "" then
        return {ok = false, error = "missing_username"}
    end

    if not modem then
        local ok, err = EEAuthenticator.init()
        if not ok then
            return {ok = false, error = err}
        end
    end

    -- Find auth server
    local serverID = rednet.lookup(PROTOCOL, "auth_server")
    if not serverID then
        return {ok = false, error = "server_not_found"}
    end

    -- Send OTP request
    rednet.send(serverID, {
        p = PROTOCOL,
        t = "otp_request",
        username = username
    }, PROTOCOL)

    -- Wait for response
    local senderID, response = rednet.receive(PROTOCOL, 5)
    if response and type(response) == "table" and response.t == "otp_response" then
        return response
    end

    return {ok = false, error = "no_response"}
end

---------------------------------------------------------------------
-- Verify OTP (via rednet to auth server)
---------------------------------------------------------------------
function EEAuthenticator.verifyOTP(username, code)
    if not username or username == "" then
        return {ok = false, error = "missing_username"}
    end
    if not code or code == "" then
        return {ok = false, error = "missing_code"}
    end

    if not modem then
        local ok, err = EEAuthenticator.init()
        if not ok then
            return {ok = false, error = err}
        end
    end

    -- Find auth server
    local serverID = rednet.lookup(PROTOCOL, "auth_server")
    if not serverID then
        return {ok = false, error = "server_not_found"}
    end

    -- Send OTP verification
    rednet.send(serverID, {
        p = PROTOCOL,
        t = "otp_verify",
        username = username,
        code = code
    }, PROTOCOL)

    -- Wait for response
    local senderID, response = rednet.receive(PROTOCOL, 5)
    if response and type(response) == "table" and response.t == "otp_result" then
        return response
    end

    return {ok = false, error = "no_response"}
end

---------------------------------------------------------------------
-- Check session (via rednet to auth server)
---------------------------------------------------------------------
function EEAuthenticator.getSession()
    if not modem then
        local ok, err = EEAuthenticator.init()
        if not ok then
            return {ok = false, error = err}
        end
    end

    -- Find auth server
    local serverID = rednet.lookup(PROTOCOL, "auth_server")
    if not serverID then
        return {ok = false, error = "server_not_found"}
    end

    -- Send session check
    rednet.send(serverID, {
        p = PROTOCOL,
        t = "check_session"
    }, PROTOCOL)

    -- Wait for response
    local senderID, response = rednet.receive(PROTOCOL, 5)
    if response and type(response) == "table" and response.t == "session_info" then
        return response
    end

    return {ok = false, error = "no_response"}
end

---------------------------------------------------------------------
-- Get cached auth result (from last authenticate() call)
---------------------------------------------------------------------
function EEAuthenticator.getCachedAuth()
    return authResult
end

---------------------------------------------------------------------
-- Interactive CLI
---------------------------------------------------------------------
local function printResult(result)
    if result.ok then
        print("  Status: SUCCESS")
        if result.player then print("  Player: " .. result.player) end
        if result.playerName then print("  Player: " .. result.playerName) end
        if result.status then print("  Auth Status: " .. result.status) end
        if result.lastGPSAuth then print("  Last GPS: " .. os.date("%H:%M:%S", result.lastGPSAuth / 1000)) end
        if result.lastOTPAuth then print("  Last OTP: " .. os.date("%H:%M:%S", result.lastOTPAuth / 1000)) end
        if result.message then print("  Message: " .. result.message) end
    else
        print("  Status: FAILED")
        if result.error then print("  Error: " .. result.error) end
        if result.status then print("  Reason: " .. result.status) end
    end
end

local function showMenu()
    term.clear()
    term.setCursorPos(1, 1)
    print("========================================")
    print("  EE Authenticator - Interactive Mode")
    print("  Computer ID: " .. os.getComputerID())
    print("========================================")
    print("")
    print("  1. GPS Authenticate")
    print("  2. Request OTP")
    print("  3. Verify OTP")
    print("  4. Check Session")
    print("  5. Exit")
    print("")
    write("Select option: ")
end

local function main()
    local ok, err = EEAuthenticator.init()
    if not ok then
        print("Failed to initialize: " .. tostring(err))
        return
    end

    while true do
        showMenu()
        local choice = read()

        print("")

        if choice == "1" then
            print("Authenticating via GPS...")
            print("(Stand near this computer)")
            print("")
            local result = EEAuthenticator.authenticate()
            printResult(result)

        elseif choice == "2" then
            write("Enter username: ")
            local username = read()
            print("")
            print("Requesting OTP for " .. username .. "...")
            local result = EEAuthenticator.requestOTP(username)
            printResult(result)
            if result.ok then
                print("")
                print("Check your in-game chat for the code!")
            end

        elseif choice == "3" then
            write("Enter username: ")
            local username = read()
            write("Enter OTP code: ")
            local code = read()
            print("")
            print("Verifying OTP...")
            local result = EEAuthenticator.verifyOTP(username, code)
            printResult(result)

        elseif choice == "4" then
            print("Checking session...")
            local result = EEAuthenticator.getSession()
            printResult(result)

        elseif choice == "5" then
            print("Goodbye!")
            break

        else
            print("Invalid option")
        end

        print("")
        print("Press any key to continue...")
        os.pullEvent("key")
    end
end

---------------------------------------------------------------------
-- Run as standalone or return as library
---------------------------------------------------------------------
if shell then
    -- Running as a program
    local args = {...}
    if #args > 0 then
        -- Command line mode
        local cmd = args[1]
        EEAuthenticator.init()

        if cmd == "auth" or cmd == "gps" then
            print("GPS Authenticating...")
            local result = EEAuthenticator.authenticate()
            printResult(result)

        elseif cmd == "otp" and args[2] then
            print("Requesting OTP for " .. args[2] .. "...")
            local result = EEAuthenticator.requestOTP(args[2])
            printResult(result)

        elseif cmd == "verify" and args[2] and args[3] then
            print("Verifying OTP...")
            local result = EEAuthenticator.verifyOTP(args[2], args[3])
            printResult(result)

        elseif cmd == "session" then
            print("Checking session...")
            local result = EEAuthenticator.getSession()
            printResult(result)

        else
            print("Usage:")
            print("  EEAuthenticator auth          - GPS authenticate")
            print("  EEAuthenticator otp <user>    - Request OTP")
            print("  EEAuthenticator verify <user> <code> - Verify OTP")
            print("  EEAuthenticator session       - Check session")
            print("  EEAuthenticator               - Interactive mode")
        end
    else
        -- Interactive mode
        main()
    end
else
    -- Being required as a library
    return EEAuthenticator
end
