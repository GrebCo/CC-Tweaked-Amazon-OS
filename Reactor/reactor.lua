-- reactor.lua
-- Simple Mekanism fission controller
-- SoC based P controller, minimal safety, no pcalls

local config = dofile("reactor_config.lua")
local notifications = dofile("chatbox_notifications.lua")

local reactor
local turbine
local lastBurnRate = 0
local controllerMode = "INIT"
local scramAttempts = 0
local maxScramAttempts = 3
local blindMode = false

-- Warning cooldown tracking
local lastLowFuelWarning = 0
local lastHighWasteWarning = 0

-- UI state
local monitor = term.current()
local logBuffer = {}
local maxLogLines = 5

local function log(msg)
    table.insert(logBuffer, 1, os.date("[%H:%M:%S] ") .. msg)
    if #logBuffer > maxLogLines then
        table.remove(logBuffer)
    end
end

local function drawUI()
    -- Cache all data FIRST before clearing screen
    local isRunning = false
    local temp, fuel, coolant, steam, waste, burn, soc = 0, 0, 0, 0, 0, 0, 0

    if reactor then
        isRunning = reactor.getStatus()
        temp = reactor.getTemperature()
        fuel = reactor.getFuelFilledPercentage()
        coolant = reactor.getCoolantFilledPercentage()
        steam = reactor.getHeatedCoolantFilledPercentage()
        waste = reactor.getWasteFilledPercentage()
        burn = reactor.getBurnRate()
    end

    if turbine and not blindMode then
        soc = turbine.getEnergyFilledPercentage()
    end

    -- NOW clear and draw immediately
    monitor.setBackgroundColor(colors.black)
    monitor.clear()
    monitor.setCursorPos(1, 1)

    -- Header: Reactor Status
    if isRunning then
        monitor.setTextColor(colors.lime)
        monitor.write("STATUS: RUNNING")
    else
        monitor.setTextColor(colors.red)
        monitor.write("STATUS: SCRAMMED")
    end

    -- Operation Mode
    monitor.setCursorPos(1, 2)
    monitor.setTextColor(colors.yellow)
    if controllerMode == "BLIND" then
        monitor.write("MODE: BLIND (Monitor Only)")
    elseif controllerMode == "CONTROL" then
        monitor.write("MODE: CONTROL")
    elseif controllerMode == "ERROR" then
        monitor.write("MODE: ERROR")
    else
        monitor.write("MODE: " .. controllerMode)
    end

    -- Separator
    monitor.setCursorPos(1, 3)
    monitor.setTextColor(colors.gray)
    monitor.write(string.rep("-", 51))

    if not reactor then
        monitor.setCursorPos(1, 5)
        monitor.setTextColor(colors.red)
        monitor.write("No reactor connected")
        return
    end

    -- Reactor Stats (using cached data)
    monitor.setCursorPos(1, 5)
    monitor.setTextColor(colors.white)
    monitor.write("Temperature: ")
    monitor.setTextColor(temp > config.WARM_TEMPERATURE and colors.orange or colors.lime)
    monitor.write(string.format("%.1f K", temp))

    monitor.setCursorPos(1, 6)
    monitor.setTextColor(colors.white)
    monitor.write("Fuel:        ")
    monitor.setTextColor(fuel < 0.2 and colors.orange or colors.lime)
    monitor.write(string.format("%.1f%%", fuel * 100))

    monitor.setCursorPos(1, 7)
    monitor.setTextColor(colors.white)
    monitor.write("Coolant:     ")
    monitor.setTextColor(coolant < 0.3 and colors.orange or colors.lime)
    monitor.write(string.format("%.1f%%", coolant * 100))

    monitor.setCursorPos(1, 8)
    monitor.setTextColor(colors.white)
    monitor.write("Steam:       ")
    monitor.setTextColor(steam > 0.8 and colors.orange or colors.lime)
    monitor.write(string.format("%.1f%%", steam * 100))

    monitor.setCursorPos(1, 9)
    monitor.setTextColor(colors.white)
    monitor.write("Waste:       ")
    monitor.setTextColor(waste > 0.7 and colors.orange or colors.lime)
    monitor.write(string.format("%.1f%%", waste * 100))

    monitor.setCursorPos(1, 10)
    monitor.setTextColor(colors.white)
    monitor.write("Burn Rate:   ")
    monitor.setTextColor(colors.cyan)
    monitor.write(string.format("%.2f mB/t", burn))

    -- Turbine stats (if available, using cached data)
    if turbine and not blindMode then
        monitor.setCursorPos(1, 11)
        monitor.setTextColor(colors.white)
        monitor.write("Battery SoC: ")
        monitor.setTextColor(colors.lightBlue)
        monitor.write(string.format("%.1f%%", soc * 100))
    end

    -- Separator
    monitor.setCursorPos(1, 13)
    monitor.setTextColor(colors.gray)
    monitor.write(string.rep("-", 51))

    -- Log output
    monitor.setCursorPos(1, 14)
    monitor.setTextColor(colors.lightGray)
    monitor.write("Recent Events:")

    for i, logLine in ipairs(logBuffer) do
        monitor.setCursorPos(1, 14 + i)
        monitor.setTextColor(colors.white)
        monitor.write(logLine)
    end
end

local function sendToast(message, isError)
    notifications.sendToast(message, isError)
end

local function safeShutdown(reason)
    log("CRITICAL: " .. reason)
    if reactor then
        if reactor.getStatus() then
            reactor.scram()
        end
        reactor.setBurnRate(0)
    end
    notifications.sendToast("CRITICAL: " .. reason, true)
    error(reason)
end

local function initPeripherals()
    reactor = peripheral.find("fissionReactorLogicAdapter") or peripheral.wrap("fissionReactor_0")

    if not reactor then
        log("No reactor found - cannot continue")
        error("No reactor found")
    end

    log("Found reactor on: " .. (peripheral.getName(reactor) or "<reactor>"))

    turbine = peripheral.find("turbineValve") or peripheral.wrap("turbineValve_0")

    if not turbine then
        blindMode = true
        log("No turbine found - entering BLIND MODE (monitoring only)")
        notifications.sendToast("Entering BLIND MODE - no burn rate control", false)
    else
        log("Found turbine on: " .. (peripheral.getName(turbine) or "<turbine>"))
    end

    -- Initialize chatbox notifications (safe, won't crash if it fails)
    notifications.init(config)
end

local function checkSafetyConditions()
    local temp = reactor.getTemperature()
    local damage = reactor.getDamagePercent()
    local coolant = reactor.getCoolantFilledPercentage()
    local steam = reactor.getHeatedCoolantFilledPercentage()
    local waste = reactor.getWasteFilledPercentage()

    if reactor.isForceDisabled() then
        return false, "Force disabled"
    elseif damage > 0 then
        return false, "Damage detected"
    elseif temp >= config.MAX_SAFE_TEMPERATURE then
        return false, "Over temperature"
    elseif coolant < config.MIN_SAFE_COOLANT_FRACTION then
        return false, "Low coolant"
    elseif steam > config.MAX_SAFE_STEAM_FRACTION then
        return false, "Steam full"
    elseif waste > config.MAX_SAFE_WASTE_FRACTION then
        return false, "Waste full"
    end

    return true, "All conditions safe"
end

local function checkWarnings()
    local currentTime = os.epoch("utc") / 1000  -- Convert to seconds

    -- Check fuel level
    local fuel = reactor.getFuelFilledPercentage()
    if fuel < config.LOW_FUEL_WARNING_FRACTION then
        if (currentTime - lastLowFuelWarning) > config.WARNING_COOLDOWN_SECONDS then
            local msg = string.format("Low fuel warning: %.1f%%", fuel * 100)
            log(msg)
            sendToast(msg, false)
            lastLowFuelWarning = currentTime
        end
    end

    -- Check waste level
    local waste = reactor.getWasteFilledPercentage()
    if waste > config.HIGH_WASTE_WARNING_FRACTION then
        if (currentTime - lastHighWasteWarning) > config.WARNING_COOLDOWN_SECONDS then
            local msg = string.format("High waste warning: %.1f%%", waste * 100)
            log(msg)
            sendToast(msg, false)
            lastHighWasteWarning = currentTime
        end
    end
end

local function scram(reason)
    controllerMode = "ERROR"
    log("SCRAM: " .. reason)
    sendToast("SCRAM: " .. reason, true)

    if(reactor.getStatus())then
        reactor.scram()
    end
    reactor.setBurnRate(0)
    lastBurnRate = 0

    scramAttempts = scramAttempts + 1
    log(string.format("Scram attempt %d/%d", scramAttempts, maxScramAttempts))

    if scramAttempts >= maxScramAttempts then
        log("Max scram attempts reached. Manual intervention required.")
        sendToast("Max scram attempts reached! Manual intervention required.", true)
        return
    end

    log("Waiting 20 seconds before restart attempt...")
    sleep(20)

    local safe, msg = checkSafetyConditions()
    if safe then
        log("Conditions clear, attempting restart...")
        if not reactor.getStatus() then
            reactor.activate()
        end
        controllerMode = "CONTROL"
        log("Reactor restarted successfully")
        sendToast("Reactor restarted successfully", false)
    else
        log("Restart aborted: " .. msg)
        log("Manual intervention required.")
        sendToast("Restart failed: " .. msg .. ". Manual intervention required.", true)
    end
end

local function main()
    controllerMode = "INIT"
    log("Starting reactor controller")
    initPeripherals()

    -- Initial startup
    local safe, msg = checkSafetyConditions()
    if safe then
        log("Starting reactor...")
        if not reactor.getStatus() then
            reactor.activate()
        end
    else
        log("Cannot start reactor: " .. msg)
        sendToast("Cannot start reactor: " .. msg, true)
        return
    end

    while true do
        local start = os.epoch("utc")

        local safe, reason = checkSafetyConditions()

        if not safe then
            scram(reason)
            -- If we've hit max attempts, exit the loop
            if scramAttempts >= maxScramAttempts then
                break
            end
        elseif controllerMode ~= "ERROR" then
            -- Reset scram counter on successful operation
            scramAttempts = 0

            -- Check for warnings (fuel/waste)
            checkWarnings()

            if blindMode then
                -- Blind mode: monitor only, no burn rate control
                controllerMode = "BLIND"
                local currentBurn = reactor.getBurnRate()
                log(string.format("BLIND MODE - Current burn: %.2f mB/t", currentBurn))
            else
                -- Normal control mode
                controllerMode = "CONTROL"
                local soc = turbine.getEnergyFilledPercentage()
                log(string.format("SoC: %.1f%%", soc * 100))

                local maxBurn = math.min(config.MAX_BURN_RATE_MBT, reactor.getMaxBurnRate())
                local kP = config.P_GAIN * maxBurn
                local burn = (config.TARGET_STATE_OF_CHARGE - soc) * kP
                if burn < 0 then burn = 0 end
                if burn > maxBurn then burn = maxBurn end

                if math.abs(burn - lastBurnRate) > config.MIN_BURN_CHANGE then
                    reactor.setBurnRate(burn)
                    lastBurnRate = burn
                    log(string.format("Set burn rate %.2f", burn))
                end
            end
        end

        -- Update UI
        drawUI()

        local elapsed = (os.epoch("utc") - start) / 1000
        local sleepTime = config.LOOP_INTERVAL_SECONDS - elapsed
        sleep(sleepTime > 0 and sleepTime or 0)
    end
end

main()
