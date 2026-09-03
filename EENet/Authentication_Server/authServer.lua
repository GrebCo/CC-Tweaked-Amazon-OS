-- OTP Authentication Server
-- Uses chatbox to DM players their authentication codes

---------------------------------------------------------------------
-- Configuration
---------------------------------------------------------------------
local PROTOCOL = "EEAuth"
local OTP_EXPIRY = 120000  -- 2 minutes in milliseconds
local OTP_LENGTH = 6

---------------------------------------------------------------------
-- State
---------------------------------------------------------------------
local otpStore = {}    -- {username: {otp, computerID, timestamp}}
local sessions = {}    -- {computerID: {username, timestamp}}
local chatbox = nil

---------------------------------------------------------------------
-- Initialization
---------------------------------------------------------------------
local function init()
    -- Find chatbox peripheral
    chatbox = peripheral.find("chatBox")
    if not chatbox then
        print("[ERROR] No chatBox peripheral found!")
        print("Please attach a chatBox to this computer.")
        error("ChatBox required for authentication server")
    end
    print("[INFO] ChatBox found: " .. peripheral.getName(chatbox))

    -- Open rednet
    local modem = peripheral.find("modem", rednet.open)
    if not modem then
        print("[ERROR] No modem found!")
        error("Modem required for authentication server")
    end
    print("[INFO] Rednet opened")

    -- Host protocol
    rednet.host(PROTOCOL, "auth_server")
    print("[INFO] Hosting authentication server on protocol '" .. PROTOCOL .. "'")
    print("[INFO] Server ready!")
end

---------------------------------------------------------------------
-- Generate random OTP code
---------------------------------------------------------------------
local function generateOTP()
    local otp = ""
    for i = 1, OTP_LENGTH do
        otp = otp .. tostring(math.random(0, 9))
    end
    return otp
end

---------------------------------------------------------------------
-- Clean up expired OTPs
---------------------------------------------------------------------
local function cleanExpiredOTPs()
    local currentTime = os.epoch("utc")
    local expiredUsers = {}

    for username, data in pairs(otpStore) do
        if (currentTime - data.timestamp) > OTP_EXPIRY then
            table.insert(expiredUsers, username)
        end
    end

    for _, username in ipairs(expiredUsers) do
        otpStore[username] = nil
        print("[CLEANUP] Expired OTP for user: " .. username)
    end
end

---------------------------------------------------------------------
-- Parse request message (format: "action:param1:param2")
---------------------------------------------------------------------
local function parseRequest(message)
    local parts = {}
    for part in string.gmatch(message, "[^:]+") do
        table.insert(parts, part)
    end
    return parts
end

---------------------------------------------------------------------
-- Handle: request_otp:username
---------------------------------------------------------------------
local function handleRequestOTP(username, senderID)
    if not username or username == "" then
        return "error:missing_username"
    end

    -- Generate OTP
    local otp = generateOTP()
    local timestamp = os.epoch("utc")

    -- Store OTP
    otpStore[username] = {
        otp = otp,
        computerID = senderID,
        timestamp = timestamp
    }

    print("[OTP REQUEST] User: " .. username .. " | Computer ID: " .. senderID .. " | Code: " .. otp)

    -- Send DM to player via chatbox
    local success, err = pcall(function()
        chatbox.sendMessageToPlayer(username, "Your OTP code is: " .. otp .. " (expires in 2 minutes)")
    end)

    if not success then
        print("[ERROR] Failed to send chatbox message: " .. tostring(err))
        return "error:chatbox_failed"
    end

    return "OTP sent to " .. username
end

---------------------------------------------------------------------
-- Handle: verify_otp:username:code
---------------------------------------------------------------------
local function handleVerifyOTP(username, otp, senderID)
    if not username or username == "" then
        return "error:missing_username"
    end

    if not otp or otp == "" then
        return "error:missing_otp"
    end

    -- Check if OTP exists for this user
    local storedData = otpStore[username]
    if not storedData then
        print("[VERIFY FAILED] User: " .. username .. " | Reason: No OTP found")
        return "invalid_otp"
    end

    -- Check if sender computer ID matches
    if storedData.computerID ~= senderID then
        print("[VERIFY FAILED] User: " .. username .. " | Reason: Computer ID mismatch")
        return "invalid_otp"
    end

    -- Check if OTP matches
    if storedData.otp ~= otp then
        print("[VERIFY FAILED] User: " .. username .. " | Reason: Code mismatch")
        return "invalid_otp"
    end

    -- Check if OTP expired
    local currentTime = os.epoch("utc")
    if (currentTime - storedData.timestamp) > OTP_EXPIRY then
        print("[VERIFY FAILED] User: " .. username .. " | Reason: Expired")
        otpStore[username] = nil  -- Clean up expired OTP
        return "expired"
    end

    -- Success! Create session
    sessions[senderID] = {
        username = username,
        timestamp = currentTime
    }

    -- Delete used OTP
    otpStore[username] = nil

    print("[AUTHENTICATED] User: " .. username .. " | Computer ID: " .. senderID)

    -- Send confirmation to player
    pcall(function()
        chatbox.sendMessageToPlayer(username, "Authentication successful!")
    end)

    return "authenticated"
end

---------------------------------------------------------------------
-- Handle: check_session
---------------------------------------------------------------------
local function handleCheckSession(senderID)
    local session = sessions[senderID]

    if session then
        print("[SESSION CHECK] Computer ID: " .. senderID .. " | User: " .. session.username)
        return "authenticated:" .. session.username
    else
        print("[SESSION CHECK] Computer ID: " .. senderID .. " | Status: Not authenticated")
        return "not_authenticated"
    end
end

---------------------------------------------------------------------
-- Main server loop
---------------------------------------------------------------------
local function main()
    init()

    while true do
        -- Clean up expired OTPs periodically
        cleanExpiredOTPs()

        -- Listen for requests
        local senderID, message = rednet.receive(PROTOCOL, 10)

        if message then
            print("\n[REQUEST] From ID: " .. senderID .. " | Message: " .. tostring(message))

            local parts = parseRequest(message)
            local action = parts[1]
            local response = "error:unknown_action"

            if action == "request_otp" then
                local username = parts[2]
                response = handleRequestOTP(username, senderID)

            elseif action == "verify_otp" then
                local username = parts[2]
                local otp = parts[3]
                response = handleVerifyOTP(username, otp, senderID)

            elseif action == "check_session" then
                response = handleCheckSession(senderID)

            else
                print("[ERROR] Unknown action: " .. tostring(action))
            end

            -- Send response back to client
            rednet.send(senderID, response, PROTOCOL)
            print("[RESPONSE] Sent to ID: " .. senderID .. " | " .. response)
        end
    end
end

---------------------------------------------------------------------
-- Start the server
---------------------------------------------------------------------
print("==============================================")
print("  OTP Authentication Server")
print("  Protocol: " .. PROTOCOL)
print("==============================================")
print("")

main()
