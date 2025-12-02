# Mekanism Fission Reactor Controller

A sophisticated ComputerCraft controller for Mekanism fission reactors with automatic control, safety monitoring, and chatbox notifications.

## Features

- **Automatic Burn Rate Control**: PID-based controller that adjusts burn rate based on turbine battery state of charge
- **Safety Monitoring**: Monitors temperature, coolant, steam, waste, and damage levels
- **Auto-Restart**: Attempts to automatically restart after transient faults (up to 3 attempts)
- **Blind Mode**: Continues monitoring if turbine is disconnected (no burn rate control)
- **Chatbox Notifications**: Sends toast notifications to players for errors and warnings
- **Real-time UI**: Clean dashboard display with color-coded status indicators
- **Low Fuel/Waste Warnings**: Configurable alerts with anti-spam cooldown

## Requirements

- ComputerCraft computer (or Advanced Computer for color display)
- Mekanism Fission Reactor with Logic Adapter
- Mekanism Industrial Turbine with Valve
- Advanced Peripherals Chat Box (optional, for notifications)

## Installation

### Method 1: Quick Install
```lua
pastebin run <CODE>  -- TODO: Upload to pastebin
```

### Method 2: Manual Install
1. Copy these files to your computer:
   - `reactor.lua` - Main controller program
   - `reactor_config.lua` - Configuration file
   - `chatbox_notifications.lua` - Chatbox integration module

2. Edit `reactor_config.lua` to match your setup

3. Run: `reactor`

### Method 3: Using Installer
```lua
wget run install.lua
```

## Configuration

Edit `reactor_config.lua` to configure the controller:

### Control Parameters
```lua
TARGET_STATE_OF_CHARGE = 0.95  -- Target battery level (95%)
MAX_BURN_RATE_MBT = 30         -- Maximum burn rate limit (mB/t)
P_GAIN = 20.0                  -- Proportional gain for PID controller
```

### Safety Limits
```lua
MAX_SAFE_TEMPERATURE = 1000           -- Kelvin
MIN_SAFE_COOLANT_FRACTION = 0.20      -- 20%
MAX_SAFE_STEAM_FRACTION = 0.95        -- 95%
MAX_SAFE_WASTE_FRACTION = 0.95        -- 95%
```

### Warning Thresholds
```lua
LOW_FUEL_WARNING_FRACTION = 0.15      -- Alert when fuel < 15%
HIGH_WASTE_WARNING_FRACTION = 0.80    -- Alert when waste > 80%
WARNING_COOLDOWN_SECONDS = 300        -- 5 min between warnings
```

### Notifications
```lua
NOTIFY_PLAYERS = {"YourName"}  -- Empty {} for all online players
TOAST_TITLE = "Reactor Alert"
```

## How It Works

### Normal Operation (CONTROL Mode)
1. Monitors turbine battery state of charge (SoC)
2. Calculates desired burn rate using proportional controller:
   - `burn = (TARGET_SoC - current_SoC) × kP`
3. Adjusts reactor burn rate to maintain target SoC
4. Continuously monitors all safety parameters

### Blind Mode
If the turbine is not found at startup:
- Enters BLIND mode (monitoring only)
- Does NOT adjust burn rate
- Continues monitoring safety conditions
- Can still SCRAM on faults
- Displays current burn rate

### Safety System
The controller monitors:
- **Temperature**: SCRAMs if ≥ MAX_SAFE_TEMPERATURE
- **Coolant**: SCRAMs if < MIN_SAFE_COOLANT_FRACTION
- **Steam**: SCRAMs if > MAX_SAFE_STEAM_FRACTION
- **Waste**: SCRAMs if > MAX_SAFE_WASTE_FRACTION
- **Damage**: SCRAMs if any damage detected
- **Force Disabled**: SCRAMs if manually disabled

### Auto-Restart Logic
After a SCRAM:
1. Waits 20 seconds
2. Re-checks all safety conditions
3. If safe: Restarts reactor
4. If unsafe: Stays scrammed
5. After 3 failed restarts: Requires manual intervention (program restart)

## Display Layout

```
STATUS: RUNNING/SCRAMMED
MODE: CONTROL/BLIND/ERROR/INIT
---------------------------------------------------
Temperature: XXX.X K
Fuel:        XX.X%
Coolant:     XX.X%
Steam:       XX.X%
Waste:       XX.X%
Burn Rate:   XX.XX mB/t
Battery SoC: XX.X%
---------------------------------------------------
Recent Events:
[HH:MM:SS] Event message
[HH:MM:SS] Event message
...
```

### Color Coding
- **Green**: Normal/Safe
- **Orange**: Warning threshold
- **Red**: Error/Scrammed
- **Yellow**: Mode indicator
- **Cyan**: Burn rate
- **Light Blue**: Battery SoC

## Peripheral Setup

The controller automatically searches for peripherals:

1. **Reactor**: Looks for `fissionReactorLogicAdapter` or wrapped as `fissionReactor_0`
2. **Turbine**: Looks for `turbineValve` or wrapped as `turbineValve_0`
3. **Chatbox**: Looks for `chat_box` (optional)

You can wrap peripherals manually if needed:
```lua
-- In ComputerCraft terminal
peripheral.wrap("side", "fissionReactor_0")
peripheral.wrap("side", "turbineValve_0")
```

## Notifications

With a chatbox connected, players receive toast notifications for:
- **SCRAM events** (with reason)
- **Auto-restart success/failure**
- **Max restart attempts reached**
- **Low fuel warnings** (with cooldown)
- **High waste warnings** (with cooldown)
- **Startup failures**

All notifications show "ReactorController" as the sender.

## Tuning the Controller

### If battery drains too much:
- Increase `P_GAIN` for more aggressive control
- Increase `TARGET_STATE_OF_CHARGE` to maintain higher charge

### If battery stays full:
- Decrease `P_GAIN` for gentler control
- Decrease `TARGET_STATE_OF_CHARGE`

### If reactor is unstable:
- Decrease `P_GAIN`
- Increase `MIN_BURN_CHANGE` to reduce adjustment frequency

## Troubleshooting

**Reactor won't start**
- Check fuel levels
- Check coolant levels
- Verify steam tanks not full
- Check for damage

**Entering BLIND mode**
- Turbine peripheral not found
- Check peripheral connections
- Verify turbine valve is connected to computer network

**Frequent SCRAMs**
- Check safety thresholds in config
- Monitor which condition is triggering
- Ensure adequate coolant flow
- Verify steam is being consumed

**No notifications**
- Check chatbox is connected
- Verify `NOTIFY_PLAYERS` list in config
- Check chatbox peripheral name is `chat_box`

## Files

- `reactor.lua` - Main controller (342 lines)
- `reactor_config.lua` - Configuration (30 lines)
- `chatbox_notifications.lua` - Notification module (47 lines)
- `README.md` - This file
- `install.lua` - Installer script

## License

MIT License - Feel free to modify and distribute

## Credits

Created for Mekanism v10+ with ComputerCraft and Advanced Peripherals

## Changelog

### v1.0.0
- Initial release
- PID-based burn rate control
- Auto-restart with attempt limiting
- Blind mode for monitoring without turbine
- Chatbox notifications
- Static UI display with color coding
- Low fuel and high waste warnings
