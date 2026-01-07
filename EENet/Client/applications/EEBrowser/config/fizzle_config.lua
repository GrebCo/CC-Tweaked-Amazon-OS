-- ============================================================================
-- FIZZLE SCRIPT TIMEOUT CONFIGURATION
-- ============================================================================
-- This file controls how fizzle scripts are protected from infinite loops
-- and excessive execution time that could hang the browser UI.
--
-- HOW TO CONFIGURE:
-- Simply uncomment and modify the values below to override defaults.
-- Commented values show the defaults that are used if this file doesn't exist.
--
-- ============================================================================

return {
    -- Maximum number of Lua instructions before a script times out
    -- Higher values = more complex scripts allowed, but slower timeout detection
    -- Lower values = faster timeout, but may kill legitimate long scripts
    -- Set to 0 to disable timeout (NOT RECOMMENDED for untrusted content!)
    --
    -- Default: 100000
    -- Examples:
    --   10000   = Very strict (good for simple scripts only)
    --   100000  = Default (handles most reasonable scripts)
    --   500000  = Permissive (for complex calculations or DOM manipulation)
    --   1000000 = Very permissive (use with caution)
    --
    MAX_INSTRUCTIONS = 100000,

    -- Enable or disable timeout protection entirely
    -- Setting to false disables ALL timeout protection (dangerous!)
    --
    -- Default: true
    --
    TIMEOUT_ENABLED = true,

    -- Log timeout events to console
    -- Useful for debugging why scripts are timing out
    --
    -- Default: true
    --
    LOG_TIMEOUTS = true,

    -- Events that are exempt from timeout checking
    -- Use this ONLY for trusted events that genuinely need long execution
    -- Format: { eventName = true, anotherEvent = true }
    --
    -- Default: {} (no exemptions)
    -- Example: { onUpdate = true } -- Allow onUpdate to run without limits
    --
    EXEMPT_EVENTS = {}
}
