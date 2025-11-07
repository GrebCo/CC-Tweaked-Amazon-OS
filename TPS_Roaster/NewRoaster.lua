-- TPS Roaster - Roasts players based on their lag contribution when TPS is low
-- Requires: tps_roast_pack.lua for roast messages and personas

local ROAST_PACK = require("tps_roast_pack")
local LAG_STATS_API = "http://efraim.a.pinggy.link/api/data/"
local TPS_PROTOCOL = "TPS_Tracker"

-- Configuration
local CONFIG = {
    tps_gate_enabled = true,       -- TPS gate disabled by default
    tps_threshold = 16.0,           -- Only roast if TPS < this (when enabled)
    player_cooldown_minutes = 60,   -- Can only roast same player once per hour
    join_grace_seconds = 10,       -- Wait time after join before checking
    command_rate_limit_max = 3,     -- Max command tokens per player
    command_refill_minutes = 2      -- Minutes per token refill
}

-- State
local lagStats = {}
local currentTPS = 20.0
local playerCooldowns = {}
local joinTimes = {}
local mutedPlayers = {}
local availablePersonas = {"demon", "god", "auditor"}
local playerCommandTokens = {}  -- Rate limiting: {username = {tokens = 3, lastRefill = timestamp}}

-- Peripherals
local chatbox = nil
local modem = nil

-- Initialize peripherals
local function initializePeripherals()
    chatbox = peripheral.find("chat_box")
    if not chatbox then
        error("ChatBox peripheral not found!")
    end
    print("[OK] ChatBox found")
    
    modem = peripheral.find("modem")
    if modem then
        rednet.open(peripheral.getName(modem))
        print("[OK] Modem found - listening for TPS updates")
    else
        print("[WARN] Modem not found - TPS will not update")
    end
end

-- Fetch lag statistics from HTTP API
function getOnlineLagScores()
    print("Fetching lag stats from API...")

    local response = http.get(LAG_STATS_API)
    if not response then
        print("Failed to fetch lag stats from server")
        return false
    end

    local content = response.readAll()
    response.close()

    lagStats = textutils.unserializeJSON(content)
    if not lagStats then
        print("Failed to parse lag stats JSON")
        return false
    end

    -- Save to local file for caching
    local file = fs.open("lag_stats.json", "w")
    if file then
        file.write(content)
        file.close()
        print("Lag stats saved to local cache")
    end

    -- Count players in the key-value table
    local count = 0
    for _ in pairs(lagStats) do count = count + 1 end
    print("Loaded lag stats for " .. count .. " players")
    return true
end

-- Load lag statistics from local cache
function updateLagScoreFromLocal()
    if not fs.exists("lag_stats.json") then
        print("[Warn] Local stats does not exist")
        return false
    end
    
    local file = fs.open("lag_stats.json", "r")
    if not file then
        print("[warn]could not open lag stats")
        return false
    end
    
    local content = file.readAll()
    file.close()
    
    lagStats = textutils.unserializeJSON(content)
    return lagStats ~= nil
end

-- Load muted players list
local function loadMutedPlayers()
    if not fs.exists("roast_mutes.json") then
        return
    end

    local file = fs.open("roast_mutes.json", "r")
    if file then
        local content = file.readAll()
        file.close()
        mutedPlayers = textutils.unserializeJSON(content) or {}
    end
end

-- Rate limiting: refill tokens based on time elapsed
local function refillCommandTokens(username)
    local currentTime = os.epoch("utc") / 1000  -- seconds

    -- Initialize if new player
    if not playerCommandTokens[username] then
        playerCommandTokens[username] = {
            tokens = CONFIG.command_rate_limit_max,
            lastRefill = currentTime
        }
        return
    end

    local data = playerCommandTokens[username]
    local timeSinceRefill = currentTime - data.lastRefill
    local refillSeconds = CONFIG.command_refill_minutes * 60

    -- Calculate how many tokens to add
    local tokensToAdd = math.floor(timeSinceRefill / refillSeconds)

    if tokensToAdd > 0 then
        data.tokens = math.min(data.tokens + tokensToAdd, CONFIG.command_rate_limit_max)
        data.lastRefill = data.lastRefill + (tokensToAdd * refillSeconds)
    end
end

-- Rate limiting: check if player can execute command
local function checkCommandRateLimit(username)
    refillCommandTokens(username)

    local data = playerCommandTokens[username]

    if data.tokens > 0 then
        data.tokens = data.tokens - 1
        return true
    else
        -- Calculate time until next token
        local currentTime = os.epoch("utc") / 1000
        local refillSeconds = CONFIG.command_refill_minutes * 60
        local timeSinceRefill = currentTime - data.lastRefill
        local timeUntilNext = refillSeconds - timeSinceRefill
        local minutesUntilNext = math.ceil(timeUntilNext / 60)

        -- Send rate limit message directly to the player from [LagBot]
        chatbox.sendMessageToPlayer(string.format(
            "\167cRate limit reached!\167r You have 0/%d commands available. Next token in ~%d minute%s.",
            CONFIG.command_rate_limit_max,
            minutesUntilNext,
            minutesUntilNext == 1 and "" or "s"
        ), username, "LagBot")
        return false
    end
end

-- Get player's lag statistics
local function getPlayerStats(playerName)
    -- lagStats is a key-value table: {playerName: {coef, rank, samples}}
    return lagStats[playerName]
end

-- Determine tier based on lag score using roast pack thresholds
local function getTier(score)
    -- Tiers are at top level of roast pack, not per-persona
    local tiers = ROAST_PACK.tiers
    if not tiers then
        -- Fallback if tier data is missing (only 4 tiers: praise, medium, spicy, ultra)
        if score < 0.50 then return "praise"
        elseif score < 1.0 then return "medium"
        elseif score < 1.5 then return "spicy"
        else return "ultra"
        end
    end

    -- Check each tier (tiers is a key-value table, not array)
    if score >= tiers.praise.min and score < tiers.praise.max then return "praise" end
    if score >= tiers.medium.min and score < tiers.medium.max then return "medium" end
    if score >= tiers.spicy.min and score < tiers.spicy.max then return "spicy" end
    if score >= tiers.ultra.min then return "ultra" end

    -- Default fallback
    return "medium"
end

-- Check gating conditions (simplified)
function checkGates(playerName)
    -- Gate 1: Player must not be muted
    if mutedPlayers[playerName] then
        print("Gate failed: " .. playerName .. " is muted")
        return false, "muted"
    end
    
    -- Gate 2: TPS must be below threshold (if enabled)
    if CONFIG.tps_gate_enabled and currentTPS >= CONFIG.tps_threshold then
        print("Gate failed: TPS too high (" .. currentTPS .. " >= " .. CONFIG.tps_threshold .. ")")
        return false, "tps_high"
    end
    
    -- Gate 3: Must have stats for player
    local stats = getPlayerStats(playerName)
    if not stats then
        print("Gate failed: No stats for " .. playerName)
        return false, "no_stats"
    end
    
    -- Gate 4: Check player-specific cooldown
    local currentTime = os.epoch("utc") / 1000
    local playerLastRoast = playerCooldowns[playerName] or 0
    local playerCooldownSeconds = CONFIG.player_cooldown_minutes * 60
    if currentTime - playerLastRoast < playerCooldownSeconds then
        local remaining = math.ceil((playerCooldownSeconds - (currentTime - playerLastRoast)) / 60)
        print("Gate failed: Player cooldown active (" .. remaining .. " minutes remaining)")
        return false, "player_cooldown"
    end
    
    print("[OK] All gates passed for " .. playerName .. " (score: " .. stats.coef .. ")")
    return true, stats
end

-- Select a roast line from the pack
local function selectRoast(tier, persona)
    local personaRoasts = ROAST_PACK.personas[persona]
    if not personaRoasts then
        persona = "demon"
        personaRoasts = ROAST_PACK.personas[persona]
    end

    local tierRoasts = personaRoasts[tier]
    if not tierRoasts or #tierRoasts == 0 then
        return nil
    end

    return tierRoasts[math.random(1, #tierRoasts)]
end

-- Roast a player when they join
function roastPlayer(playerName, bypassGates)
    print("Attempting to roast: " .. playerName)
    if not bypassGates then
        local passed, statsOrReason = checkGates(playerName)
        if not passed then
            return
        end
    end
    
    -- Get stats (even if bypassing gates, we need stats to roast)
    local stats = getPlayerStats(playerName)
    if not stats then
        print("Cannot roast " .. playerName .. " - no stats available")
        if bypassGates then
            chatbox.sendMessageToPlayer("No lag data available for " .. playerName, playerName, "LagBot")
        end
        return
    end
    
    -- Randomly select a persona
    local selectedPersona = availablePersonas[math.random(1, #availablePersonas)]

    local tier = getTier(stats.coef)
    local roastLine = selectRoast(tier, selectedPersona)

    if not roastLine then
        print("No roast available for tier: " .. tier)
        return
    end

    -- Color code score based on severity/tier
    local scoreColor = "\167b"  -- Default blue
    if tier == "ultra" then scoreColor = "\167c"      -- Red
    elseif tier == "spicy" then scoreColor = "\1676"  -- Gold/Orange
    elseif tier == "medium" then scoreColor = "\167e" -- Yellow
    elseif tier == "praise" then scoreColor = "\167a" -- Green
    end

    -- Replace placeholders with \167 color codes (works in message content)
    roastLine = roastLine:gsub("{player}", "\167e\167l" .. playerName .. "\167r")
    roastLine = roastLine:gsub("{score}", scoreColor .. string.format("%.2f", stats.coef) .. "\167r")

    -- Get persona data
    local personaData = ROAST_PACK.personas[selectedPersona]
    local personaName = personaData and personaData.name or "\1678TPS Roaster\167r"

    -- Convert \167 to & for the prefix (brackets use MOTD codes)
    local bracketName = personaName:gsub("\167", "&")

    -- Send message with colored persona name as prefix (appears in brackets)
    chatbox.sendMessage(roastLine, bracketName)
    
    -- Update cooldown (only if not bypassing gates)
    if not bypassGates then
        local currentTime = os.epoch("utc") / 1000
        playerCooldowns[playerName] = currentTime
    end
    
    print("[ROAST] Roasted " .. playerName .. " (" .. tier .. " tier)")
end

-- Parse and handle !lag commands
function parseCommand(username, message)
    local args = {}
    for word in message:gmatch("%S+") do
        table.insert(args, word)
    end

    if #args < 2 then
        args[2] = "help"
    end

    local command = args[2]:lower()

    -- Rate limit check (help has its own cooldown, info/worst/tps are read-only)
    local exemptCommands = {help = true, info = true, worst = true, tps = true}
    if not exemptCommands[command] then
        if not checkCommandRateLimit(username) then
            return  -- Rate limited, error message already sent
        end
    end

    if command == "help" then
        chatbox.sendMessageToPlayer("--- Lag Roaster Commands ---", username, "LagBot")
        chatbox.sendMessageToPlayer("!lag tps - Show current server TPS", username, "LagBot")
        chatbox.sendMessageToPlayer("!lag score <name> - Show player's lag score", username, "LagBot")
        chatbox.sendMessageToPlayer("!lag info - Explain how lag scores work", username, "LagBot")
        chatbox.sendMessageToPlayer("!lag worst - Show top 5 laggiest players", username, "LagBot")
        chatbox.sendMessageToPlayer("!lag roastme - Roast yourself (bypasses gates)", username, "LagBot")
        chatbox.sendMessageToPlayer("!lag help - Show this help", username, "LagBot")
        chatbox.sendMessageToPlayer("\1677Note: score/roastme are rate limited (3 max, refills 1 per 2min)\167r", username, "LagBot")

    elseif command == "info" then
        chatbox.sendMessageToPlayer("\1676Lag Score\167r is a coefficient measuring your correlation with TPS drops. Higher = more lag.", username, "LagBot")
        chatbox.sendMessageToPlayer("\1676Calculated via regression analysis of TPS vs player presence.\167r", username, "LagBot")

    elseif command == "score" then
        local targetPlayer = args[3] or username
        local stats = getPlayerStats(targetPlayer)

        if stats then
            local tier = getTier(stats.coef)

            -- Color code score based on tier
            local scoreColor = "\167b"
            if tier == "ultra" then scoreColor = "\167c"
            elseif tier == "spicy" then scoreColor = "\1676"
            elseif tier == "medium" then scoreColor = "\167e"
            elseif tier == "praise" then scoreColor = "\167a"
            end

            chatbox.sendMessageToPlayer(string.format(
                "%s - Score: %s%.2f\167r | Samples: %d | Tier: %s",
                targetPlayer,
                scoreColor,
                stats.coef,
                stats.samples,
                tier
            ), username, "LagBot")
        else
            chatbox.sendMessageToPlayer(string.format("No lag data for %s", targetPlayer), username, "LagBot")
        end

    elseif command == "worst" then
        -- Build sorted list of players by lag score (descending)
        local playerList = {}
        for name, data in pairs(lagStats) do
            table.insert(playerList, {name = name, coef = data.coef, samples = data.samples})
        end

        -- Sort by coefficient (highest first)
        table.sort(playerList, function(a, b) return a.coef > b.coef end)

        chatbox.sendMessageToPlayer("\167c\167lTop 5 Laggiest Players:\167r", username, "LagBot")
        for i = 1, math.min(5, #playerList) do
            local player = playerList[i]
            local tier = getTier(player.coef)

            -- Color code score based on tier
            local scoreColor = "\167c"  -- Default red for worst list
            if tier == "spicy" then scoreColor = "\1676"
            elseif tier == "medium" then scoreColor = "\167e"
            elseif tier == "praise" then scoreColor = "\167a"
            end

            chatbox.sendMessageToPlayer(string.format(
                "%d. %s - %s%.2f\167r (%d samples)",
                i,
                player.name,
                scoreColor,
                player.coef,
                player.samples
            ), username, "LagBot")
        end

    elseif command == "tps" then
        -- Color code TPS based on value
        local tpsColor = "\167a"  -- Green (good)
        if currentTPS < 10 then tpsColor = "\167c"      -- Red (terrible)
        elseif currentTPS < 15 then tpsColor = "\1676"  -- Gold (bad)
        elseif currentTPS < 18 then tpsColor = "\167e"  -- Yellow (okay)
        end

        chatbox.sendMessageToPlayer(string.format(
            "Current TPS: %s%.2f\167r / 20.0",
            tpsColor,
            currentTPS
        ), username, "LagBot")
        
    -- Test command disabled per TODO #3
    --[[
    elseif command == "test" then
        local targetPlayer = args[3]
        local testScore = tonumber(args[4])

        if not targetPlayer or not testScore then
            chatbox.sendMessageToPlayer("Usage: !lag test <name> <score>", username, "LagBot")
            return
        end

        local selectedPersona = availablePersonas[math.random(1, #availablePersonas)]
        local tier = getTier(testScore)
        local roastLine = selectRoast(tier, selectedPersona)

        if roastLine then
            -- Color code score based on severity/tier
            local scoreColor = "\167b"  -- Default blue
            if tier == "ultra" then scoreColor = "\167c"      -- Red
            elseif tier == "spicy" then scoreColor = "\1676"  -- Gold/Orange
            elseif tier == "medium" then scoreColor = "\167e" -- Yellow
            elseif tier == "praise" then scoreColor = "\167a" -- Green
            end

            roastLine = roastLine:gsub("{player}", "\167e\167l" .. targetPlayer .. "\167r")
            roastLine = roastLine:gsub("{score}", scoreColor .. string.format("%.2f", testScore) .. "\167r")

            -- Get persona data and convert for bracket
            local personaData = ROAST_PACK.personas[selectedPersona]
            local personaName = personaData and personaData.name or "\1678TPS Roaster\167r"
            local bracketName = personaName:gsub("\167", "&")

            chatbox.sendMessage("[TEST] " .. roastLine, bracketName)
        else
            chatbox.sendMessageToPlayer("No roast available for tier: " .. tier, username, "LagBot")
        end
    ]]
        
    elseif command == "roastme" then
        print(username .. " requested self-roast")
        roastPlayer(username, true)  -- Bypass all gates

    else
        chatbox.sendMessageToPlayer("Unknown command. Use !lag help for help.", username, "LagBot")
    end
end

-- Main runtime
local function main()
    print("================================")
    print("   TPS Roaster v2.0")
    print("================================")
    
    -- Initialize
    initializePeripherals()
    loadMutedPlayers()
    
    -- Fetch initial lag stats
    if not getOnlineLagScores() then
        print("[WARN] Failed to fetch lag stats")
        print("  Attempting to load from cache...")
        if not updateLagScoreFromLocal() then
            print("  No cached stats available!")
        end
    end
    
    print("")
    print("[OK] Roaster is now active!")
    local tpsStatus = CONFIG.tps_gate_enabled and "Enabled" or "Disabled"
    print("  TPS Gate: " .. tpsStatus)
    print("  Player Cooldown: " .. CONFIG.player_cooldown_minutes .. " minutes")
    print("  Personas: Random (demon, god, auditor)")
    print("")
    
    -- Main event loop
    while true do
        local event = {os.pullEvent()}
        
        if event[1] == "playerJoin" then
            local playerName = event[2]
            local currentTime = os.epoch("utc") / 1000
            joinTimes[playerName] = currentTime
            
            print("Player joined: " .. playerName)
            
            -- Wait for grace period, then roast
            sleep(CONFIG.join_grace_seconds)
            roastPlayer(playerName, false)
            
        elseif event[1] == "chat" then
            local username = event[2]
            local message = event[3]
            
            if message:match("^!lag") then
                print(username .. " used !lag command: " .. message)
                parseCommand(username, message)
            end
            
        elseif event[1] == "rednet_message" then
            local senderId = event[2]
            local message = event[3]
            local protocol = event[4]

            -- Handle TPS updates from both formats:
            -- 1. Protocol-based: {tps = X, ...} with protocol "TPS_Tracker"
            -- 2. Broadcast: {type = "tps_update", tps = X, players = [...]}
            if type(message) == "table" then
                if (protocol == TPS_PROTOCOL and message.tps) or (message.type == "tps_update" and message.tps) then
                    currentTPS = message.tps
                    print(string.format("TPS updated: %.2f", currentTPS))
                end
            end
        end
    end
end

-- Run with error handling
local success, error = pcall(main)
if not success then
    print("[ERROR] Fatal Error: " .. tostring(error))
end