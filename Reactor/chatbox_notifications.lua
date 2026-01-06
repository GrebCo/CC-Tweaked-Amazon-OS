-- chatbox_notifications.lua
-- Safe chatbox notification wrapper
-- All chatbox operations are wrapped in pcalls to prevent crashes

local notifications = {}

local chatbox = nil
local config = nil

function notifications.init(loadedConfig)
    config = loadedConfig
    chatbox = peripheral.find("chat_box")

    if chatbox then
        print("Chatbox notifications enabled")
        return true
    else
        print("No chatbox found - notifications disabled")
        return false
    end
end

function notifications.sendToast(message, isError)
    if not chatbox or not config then return end

    local success, err = pcall(function()
        local players = config.NOTIFY_PLAYERS
        if #players == 0 then
            -- Get all online players if list is empty
            players = chatbox.getPlayersInRange and chatbox.getPlayersInRange(100000) or {}
        end

        for _, player in ipairs(players) do
            chatbox.sendToastToPlayer(
                message,
                config.TOAST_TITLE,
                player,
                "ReactorController"
            )
        end
    end)

    if not success then
        print("Chatbox error (non-fatal): " .. tostring(err))
    end
end

return notifications
