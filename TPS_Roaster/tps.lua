
--[[
===============================================================================
  TPS Logger — Clock-Controlled Version
  CC:Tweaked + Advanced Peripherals
-------------------------------------------------------------------------------
  Controls a redstone clock to measure TPS accuracy.
  Every 2 minutes:
    • Turns on redstone clock (left side)
    • Counts pulses received (back side)
    • Calculates TPS from pulse count
    • Sends via rednet to wired modem on top
    • Posts to HTTP server
    • Logs locally to CSV
===============================================================================
]]

-- ===== NETWORKING ===========================================================
local url = "https://efraim.a.pinggy.link/api/submit"
local header = { ["Content-Type"] = "application/json" }

local function sendToServer(tps, players, time)
    local data = { 
        timestamp = time,
        tps = tps, 
        players = players 
    }
    local formattedData = textutils.serializeJSON(data)
    
    local success, response = pcall(function()
        return http.post(url, formattedData, header)
    end)
    
    if success and response then
        local responseCode = response.getResponseCode()
        response.close()
        if responseCode == 201 then
            print("Successfully posted to server!")
        else
            print("Server returned code: " .. responseCode)
        end
    else
        print("Error posting to server")
    end
end

-- ===== CONFIG ===============================================================
local CLOCK_SIDE      = "left"   -- Controls the clock (output)
local PULSE_SIDE      = "back"   -- Receives pulses (input)
local MODEM_SIDE      = "top"    -- Wired modem for rednet
local LOG_DIR         = "logs"
local SAMPLE_DURATION = 15      -- seconds (2 minutes)

-- ===== SETUP ================================================================
if not fs.exists(LOG_DIR) then fs.makeDir(LOG_DIR) end

-- Find player detector on wired modem network
local detector = peripheral.find("player_detector")
if not detector then 
    error("No playerDetector found on wired modem network!") 
end
print("Player detector found: " .. peripheral.getName(detector))

-- Setup rednet on wired modem
local modem = peripheral.wrap(MODEM_SIDE)
if modem and modem.isWireless and not modem.isWireless() then
    rednet.open(MODEM_SIDE)
    print("Rednet opened on wired modem: " .. MODEM_SIDE)
else
    print("Warning: No wired modem found on " .. MODEM_SIDE)
end

-- ===== UTILS ================================================================
local function getLogFile()
    local dateStr = os.date("%Y-%m-%d")
    return fs.combine(LOG_DIR, "tps_" .. dateStr .. ".csv")
end

local function appendLog(tps, players, time)
    local path = getLogFile()
    local newFile = not fs.exists(path)

    local f = fs.open(path, "a")
    if newFile then f.writeLine("timestamp,tps,players") end

    
    local playerList = #players > 0 and table.concat(players, ";") or "none"
    f.writeLine(string.format("%s,%.2f,%s", time, tps, playerList))
    f.close()

    print(string.format("[%s] TPS %.2f (%d players)", time, tps, #players))
end

-- ===== TPS SAMPLER ==========================================================
local function measureTPS()
    print("Starting TPS measurement...")
    
    -- Turn on the clock
    rs.setOutput(CLOCK_SIDE, true)
    print("Clock enabled on " .. CLOCK_SIDE)
    
    -- Wait for first pulse to start counting
    repeat
        os.pullEvent("redstone")
    until rs.getInput(PULSE_SIDE)
    
    local pulseCount = 0
    local startTime = os.epoch("utc")
    local endTime = startTime + (SAMPLE_DURATION * 1000) -- Convert to milliseconds
    
    -- Count pulses for the sample duration
    while os.epoch("utc") < endTime do
        local event = os.pullEvent("redstone")
        if rs.getInput(PULSE_SIDE) then
            pulseCount = pulseCount + 1
        end
    end
    
    -- Turn off the clock
    rs.setOutput(CLOCK_SIDE, false)
    print("Clock disabled")
    
    -- Calculate TPS
    local actualDuration = (os.epoch("utc") - startTime) / 1000 -- Convert to seconds
    local pulsesPerSecond = pulseCount / actualDuration
    
    -- Assuming 5 Hz clock = 10 ticks per second, 2 pulses per tick
    local tps = 4 * pulsesPerSecond
    
    print(string.format("Measured %d pulses in %.2f seconds (%.2f TPS)", 
          pulseCount, actualDuration, tps))
    
    return tps
end

-- ===== MAIN LOOP ============================================================
print("=== TPS Logger (clock-controlled) started ===")
print(string.format("Sampling every %d seconds", SAMPLE_DURATION))
print("Clock output: " .. CLOCK_SIDE)
print("Pulse input: " .. PULSE_SIDE)
print("Press Ctrl+T to stop.\n")

while true do
    -- Measure current TPS
    local tps = measureTPS()
    
    -- Get current players
    local players = detector.getOnlinePlayers()
    
    -- Send via rednet (broadcast)
    if modem then
        rednet.broadcast({type = "tps_update", tps = tps, players = players})
        print("Sent TPS via rednet")
    end
    local time = os.date("%Y-%m-%d %H:%M:%S")
    -- Write to local CSV
    appendLog(tps, players, time)
    
    -- Post to HTTP server
    sendToServer(tps, players, time)
    
    print("\nWaiting for next measurement cycle...\n")
end