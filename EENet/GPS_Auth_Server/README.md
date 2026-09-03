# GPS-Based Player Authentication System (Outside-In Design)

A secure location-based authentication system for ComputerCraft that verifies player identity by physically triangulating computer positions and matching them against real player locations.

## Overview

This system authenticates **players** to **ComputerCraft computers** by binding a client computer's **physical radio position** to a player's **detected in-world position**.

**Key Security Principle**: The **client never reports its own location**. Location is computed centrally from **trusted beacon-measured distances** and then matched to a **player detector**.

### How It Works

1. **Client Broadcasts**: Computer sends auth request with nonce
2. **Beacons Measure**: Fixed GPS beacons measure radio distance (from `modem_message` event)
3. **Trilateration**: Auth server computes computer's 3D position from 4+ beacon measurements
4. **Player Verification**: Server checks if a real player is at that computed position
5. **Authentication**: If player found within tolerance → authenticated as that player

## Features

- **Anti-Spoofing**: Client cannot fake position in software
- **Nonce System**: Prevents request collisions and replay attacks
- **Beacon Whitelisting**: Only trusted beacons accepted
- **Position Override**: Server uses configured beacon positions, ignores packets
- **4+ Beacon Requirement**: Stable 3D trilateration with least-squares
- **Protocol Filtering**: All messages include protocol/type for validation
- **DNS Security**: Auth server ID registered in DNS
- **Bounded Timeouts**: Collection windows and request expiry

## Requirements

### Authentication Server
- ComputerCraft computer
- Wireless modem
- **Player Detector** peripheral (Advanced Peripherals)

### GPS Beacons (4+ required)
- ComputerCraft computers at fixed, known locations
- Wireless modems
- Spread 50+ blocks apart, not collinear

### Network Infrastructure
- DNS server running
- Rednet network

## Installation

### 1. Set Up Authentication Server

```lua
wget https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/main/EENet/GPS_Auth_Server/install.lua install.lua
install
```

**Critical Configuration Steps**:

1. Note the server's computer ID from installer output
2. **Edit `authServer.lua`** and configure `KNOWN_BEACONS` table:

```lua
local KNOWN_BEACONS = {
    [10] = {x = 100, y = 64, z = 200, beacon_id = "beacon_1"},
    [11] = {x = 150, y = 70, z = 250, beacon_id = "beacon_2"},
    [12] = {x = 50, y = 65, z = 180, beacon_id = "beacon_3"},
    [13] = {x = 120, y = 68, z = 270, beacon_id = "beacon_4"},
}
```

Each entry: `[beaconComputerID] = {x, y, z, beacon_id}`

3. Add server to `DNS_Master.json`:
```json
{"id": 100, "protocol": "GPSAuth", "hostname": "gps_auth_server"}
```

4. Restart DNS server and auth server

### 2. Set Up GPS Beacons (4+ Required)

On each beacon computer:

```lua
wget https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/main/EENet/GPS_Auth_Server/beacons/beacon_install.lua beacon_install.lua
beacon_install
```

Then configure each beacon:
1. Use F3 to get exact coordinates
2. Edit `beacon_config.lua` with position and unique beacon ID
3. Run `beacon.lua` or reboot

See `beacons/README_BEACON.md` for detailed setup.

## Protocol Specification

### Message Formats

All messages include:
- `p` (protocol): `"GPSAuth"`
- `t` (type): message type

#### Auth Request (Client → Beacons, modem broadcast on channel 1000)
```lua
{
    p = "GPSAuth",
    t = "auth_request",
    client_id = number,
    nonce = string,  -- "{timestamp}:{random}:{client_id}"
    reply_ch = number
}
```

#### Beacon Sample (Beacon → Auth Server, rednet)
```lua
{
    p = "GPSAuth",
    t = "beacon_sample",
    client_id = number,
    nonce = string,
    reply_ch = number,
    beacon_id = string,
    d = number,  -- measured distance from modem_message
    timestamp = number
}
```

**Security Note**: Beacon position is NOT included in packet. Server overrides using `KNOWN_BEACONS` configuration.

#### Auth Result (Server → Client, modem transmit to reply_ch)
```lua
-- Success
{
    p = "GPSAuth",
    t = "auth_result",
    client_id = number,
    nonce = string,
    ok = true,
    player = string,
    position = {x, y, z},  -- if DEBUG_OUTPUT enabled
    samples = number        -- if DEBUG_OUTPUT enabled
}

-- Failure
{
    p = "GPSAuth",
    t = "auth_result",
    client_id = number,
    nonce = string,
    ok = false,
    reason = "insufficient_beacons" | "geometry_error" | "no_match",
    position = {x, y, z}  -- if available and DEBUG_OUTPUT enabled
}
```

## Client Usage

See `client_example.lua` for a complete reference implementation.

### Basic Usage

```lua
local PROTOCOL = "GPSAuth"
local modem = peripheral.find("modem")

-- Generate nonce
local nonce = string.format("%d:%d:%d",
    os.epoch("utc"),
    math.random(1000000, 9999999),
    os.getComputerID())

-- Open reply channel
modem.open(1001)

-- Broadcast auth request
modem.transmit(1000, 1001, {
    p = PROTOCOL,
    t = "auth_request",
    client_id = os.getComputerID(),
    nonce = nonce,
    reply_ch = 1001
})

-- Wait for response
local timer = os.startTimer(5)
while true do
    local event, p1, p2, p3, p4 = os.pullEvent()

    if event == "modem_message" and p2 == 1001 then
        local message = p4

        -- Protocol and nonce validation
        if message.p == PROTOCOL and
           message.t == "auth_result" and
           message.nonce == nonce then

            if message.ok then
                print("Authenticated as: " .. message.player)
                -- Success - store session
            else
                print("Auth failed: " .. message.reason)
            end
            break
        end

    elseif event == "timer" and p1 == timer then
        print("Timeout")
        break
    end
end

modem.close(1001)
```

## Security Model

### What This Prevents

1. **Client Position Spoofing**: Client cannot lie about its location in software
2. **Fake Beacon Injection**: Unknown beacons are rejected by whitelist
3. **Beacon Position Manipulation**: Server uses configured positions, ignores packets
4. **Request Collision**: Nonce ensures concurrent requests don't interfere
5. **Replay Attacks**: Nonces are unique per request, expired requests are dropped

### What This Does NOT Prevent

1. **Physical Relay**: Attacker can place relay computer at allowed location
2. **Co-Location**: Attacker standing near legitimate player may authenticate
3. **DNS Compromise**: Attacker with DNS access can redirect to fake server

### Trust Model

**Trusted Components**:
- Auth server (computes position, checks players)
- GPS beacons (measure distances)
- Player detector peripheral (provides player positions)
- DNS server (provides auth server ID)

**Untrusted Components**:
- Client computers (never trust self-reported location)
- Network messages (validate protocol, nonce, whitelist senders)

## Configuration

### Auth Server (`authServer.lua`)

```lua
local PROTOCOL = "GPSAuth"
local MIN_BEACONS = 4  -- Minimum for stable 3D
local SAMPLE_WINDOW = 1.5  -- Seconds to collect measurements
local REQUEST_EXPIRY = 8  -- Seconds before dropping stale requests
local MATCH_TOLERANCE = 4.0  -- Blocks tolerance for player matching
local DEBUG_OUTPUT = true  -- Include position/samples in response

local KNOWN_BEACONS = {
    -- [beaconComputerID] = {x, y, z, beacon_id}
    [10] = {x = 100, y = 64, z = 200, beacon_id = "beacon_1"},
    -- ... add all your beacons
}
```

### Beacons (`beacon_config.lua`)

```lua
return {
    position = {x = 100, y = 64, z = 200},  -- Exact coordinates (F3)
    beaconID = 1,  -- Unique ID
    authServerHostname = "gps_auth_server",
    authProtocol = "GPSAuth",
    listenChannel = 1000,
    dnsProtocol = "DNS"
}
```

## Troubleshooting

### "insufficient_beacons"
- Less than 4 beacons responded
- Check beacons are running and in range
- Verify beacons are in `KNOWN_BEACONS` whitelist
- Check DNS registration

### "geometry_error"
- Trilateration failed (singular matrix)
- Beacons may be collinear (in straight line)
- Check beacon positions are correct in `KNOWN_BEACONS`
- Add more beacons for redundancy

### "no_match"
- No player within `MATCH_TOLERANCE` blocks of computed position
- Player may not be at computer location
- Increase `MATCH_TOLERANCE` if needed (but reduces security)
- Check player detector is working: `playerDetector.getOnlinePlayers()`

### "[REJECT] Unknown beacon"
- Beacon not in `KNOWN_BEACONS` whitelist
- Add beacon computer ID to `KNOWN_BEACONS` in `authServer.lua`

### Inaccurate position
- Beacon positions in `KNOWN_BEACONS` don't match actual positions
- Use F3 to verify exact coordinates
- Re-configure all beacons
- Ensure beacons are spread out (50+ blocks apart)

## Testing & Validation

### Acceptance Tests

1. **Happy Path**
   - Client requests auth, receives `ok=true` with correct player name

2. **Concurrency**
   - Same client does two requests back-to-back with different nonces
   - Responses don't cross (nonce validation works)

3. **Insufficient Beacons**
   - With <4 responding beacons, get `ok=false, reason="insufficient_beacons"`

4. **No Nearby Players**
   - With no player at computed position, get `ok=false, reason="no_match"`

5. **Fake Beacon Rejection**
   - Inject beacon_sample from untrusted ID
   - Server logs "[REJECT] Unknown beacon" and ignores it

## Beacon Placement Guidelines

For accurate trilateration:

- **Minimum 4 beacons** (more is better)
- **Spread widely** - 50+ blocks apart
- **Not collinear** - don't place in straight line
- **Vary heights** - different Y-levels for 3D accuracy
- **Form perimeter** - surround authentication area

### Example Layout

```
    Beacon 1 (100, 70, 200)
        *
       / \
      /   \
     /     \
    *-------*
Beacon 2   Beacon 3
(50, 65, 250) (150, 68, 250)

        *
    Beacon 4
(120, 72, 180)

  (Auth area in center)
```

## Limitations

1. **Range**: Modem range (64 or 384 blocks with ender modems)
2. **Setup Complexity**: Requires beacon placement and configuration
3. **Accuracy**: ±1-2 block typical
4. **Single Dimension**: Works within one dimension only
5. **Player Detector Range**: ~50 block limit
6. **Stationary Beacons**: Beacons must not move

## Advanced Peripherals API

This system uses:
- `playerDetector.getOnlinePlayers()` → list of player names
- `playerDetector.getPlayer(name)` → `{x, y, z}` position

Verify your Advanced Peripherals version supports these methods.

## Files

```
GPS_Auth_Server/
├── authServer.lua          # Main server (configure KNOWN_BEACONS)
├── trilateration.lua       # 3D trilateration (4+ beacons)
├── startup.lua             # Auto-start
├── install.lua             # Server installer
├── client_example.lua      # Reference client implementation
├── README.md               # This file
└── beacons/
    ├── beacon.lua          # GPS beacon program
    ├── beacon_config.lua   # Beacon config template
    ├── beacon_install.lua  # Beacon installer
    └── README_BEACON.md    # Beacon setup guide
```

## Related Systems

- **OTP Authentication**: Chatbox-based auth (`../Authentication_Server/`)
- **Web Server**: Serve MiniMark content (`../WebServer/`)
- **DNS Server**: Service discovery (`../DNSServer/`)
- **EEBrowser**: Client browser (`../Client/`)

## Support

Setup checklist:
1. ✅ 4+ beacons placed and configured
2. ✅ Beacon positions added to `KNOWN_BEACONS` in `authServer.lua`
3. ✅ Auth server added to `DNS_Master.json`
4. ✅ Player detector attached to auth server
5. ✅ DNS server running
6. ✅ Test with `client_example.lua`

For issues, check:
- Server logs for detailed error messages
- Beacon computer IDs match `KNOWN_BEACONS`
- Beacon positions are exactly correct (use F3)
- Player detector API is available
- DNS registration is correct

## License

Part of the CC-Tweaked-Amazon-OS / EENet project.
