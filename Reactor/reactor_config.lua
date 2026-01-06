-- reactor_config.lua
-- All tunable parameters for the reactor controller

local config = {

    TARGET_STATE_OF_CHARGE = 0.95,
    MAX_BURN_RATE_MBT = 30,
    P_GAIN = 20.0,

    LOOP_INTERVAL_SECONDS = 1.0,
    MIN_BURN_CHANGE = 0.01,

    MAX_SAFE_TEMPERATURE      = 1000,
    MIN_SAFE_COOLANT_FRACTION = 0.20,
    MAX_SAFE_STEAM_FRACTION   = 0.95,
    MAX_SAFE_WASTE_FRACTION   = 0.95,

    WARM_TEMPERATURE = 800,

    -- Warning thresholds (not scram-worthy, just alerts)
    LOW_FUEL_WARNING_FRACTION = 0.65,     -- Alert when fuel < 65%
    HIGH_WASTE_WARNING_FRACTION = 0.35,   -- Alert when waste > 35%
    WARNING_COOLDOWN_SECONDS = 300,       -- Don't spam warnings (5 min cooldown)

    -- Chatbox settings
    NOTIFY_PLAYERS = {"Easease"},  -- Empty table means notify all online players
    TOAST_TITLE = "Reactor Alert",
}

return config
