# GPS Authentication Beacon Setup Guide

GPS beacons are stationary computers that measure distances to authenticating clients and forward measurements to the authentication server.

## Requirements

- ComputerCraft computer at a **fixed, known location**
- Wireless modem attached
- Clear line-of-sight for best accuracy (or within modem range)

## Installation

### Step 1: Install Beacon Software

Run this command on the beacon computer:

```lua
wget https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/main/EENet/GPS_Auth_Server/beacons/beacon_install.lua beacon_install.lua
```

Then run:
```lua
beacon_install
```

### Step 2: Configure Beacon Position

**CRITICAL**: You must configure the beacon's exact position for trilateration to work.

1. Stand at the beacon computer
2. Press **F3** to show debug screen
3. Note the exact X, Y, Z coordinates
4. Edit `beacon_config.lua`:

```lua
position = {
    x = 123,  -- Your X coordinate
    y = 64,   -- Your Y coordinate
    z = 456   -- Your Z coordinate
}
```

5. Set a unique `beaconID` (1, 2, 3, etc.) - each beacon needs a different ID

### Step 3: Start Beacon

```lua
beacon
```

Or reboot the computer (will auto-start via startup.lua).

## Configuration Reference

`beacon_config.lua` contains:

```lua
return {
    -- Beacon's exact position in the world
    position = {x = 100, y = 64, z = 200},

    -- Unique ID for this beacon (1, 2, 3, ...)
    beaconID = 1,

    -- DNS hostname of auth server (must match DNS registry)
    authServerHostname = "gps_auth_server",

    -- Protocol for sending measurements
    authProtocol = "GPSAuth",

    -- Channel to listen for auth requests
    listenChannel = 1000,

    -- DNS protocol for server lookup
    dnsProtocol = "DNS"
}
```

## Beacon Placement Guidelines

For accurate trilateration, beacon placement is critical:

### Minimum Requirements
- **At least 3 beacons** (4+ recommended for better accuracy)
- **Spread widely** - 50+ blocks apart minimum
- **Not collinear** - don't place in a straight line
- **Different heights** - vary Y-levels for 3D accuracy

### Optimal Placement
```
Example layout (top-down view):

    Beacon 1 (100, 70, 200)
         *
        / \
       /   \
      /     \
     /       \
    *---------*
Beacon 2     Beacon 3
(50, 65, 250) (150, 68, 250)

   (Auth area in center)
```

- Form a triangle or square around the authentication area
- Higher beacons can "see" farther (less obstruction)
- Avoid placing beacons underground if authenticating on surface

## How It Works

1. **Startup**: Beacon queries DNS to find auth server computer ID
2. **Listen**: Waits for auth requests on modem channel 1000
3. **Measure**: When request received, extracts distance from `modem_message` event
4. **Forward**: Sends measurement to auth server via rednet: `{beaconPos, beaconID, clientID, distance}`
5. **Repeat**: Continuously processes auth requests

## Security

- Beacon trusts DNS server to provide correct auth server ID
- Only sends measurements to the ID registered in `DNS_Master.json`
- Beacons are stateless - no session management
- Distance measurement cannot be spoofed (provided by ComputerCraft's modem API)

## Troubleshooting

### "DNS server not found"
- Check that DNS server is running
- Verify DNS server is on protocol "DNS"
- Use `rednet.lookup("DNS")` to test

### "Auth server not found in DNS"
- Verify auth server is registered in `DNS_Master.json`
- Entry should be: `{"id": <server_id>, "protocol": "GPSAuth", "hostname": "gps_auth_server"}`
- Restart DNS server after editing DNS_Master.json

### "No modem found"
- Attach a wireless modem to the beacon computer
- Use `peripheral.find("modem")` to verify

### Beacon not responding to auth requests
- Check that modem channel 1000 is open: `modem.open(1000)`
- Verify beacon is running (no errors on screen)
- Test with client in range (within 64 or 384 blocks depending on modem)

### Incorrect distance measurements
- Verify beacon position in `beacon_config.lua` is **exactly** correct
- Use F3 to double-check coordinates
- Remember: position is where the *beacon computer* is, not where you're standing
- Test: place client at known position, check measured distance vs actual

## Monitoring

Beacon logs show:
- DNS resolution results
- Incoming auth requests with client ID and measured distance
- Messages forwarded to auth server

Example output:
```
[DNS] Resolved 'gps_auth_server' to ID: 100
[REQUEST] Client ID: 42 | Distance: 45.23 blocks
[SENT] Measurement forwarded to auth server (ID: 100)
```

## Maintenance

- **DNS Refresh**: Beacon refreshes auth server ID every 5 minutes
- **Stateless**: No data to backup, can reboot anytime
- **Updates**: Re-run `beacon_install.lua` to update software

## Multiple Beacons

To set up multiple beacons:

1. Install on each computer
2. Configure each with:
   - Its own unique `beaconID` (1, 2, 3, 4, ...)
   - Its own exact `position` (use F3 at each location)
3. All beacons can use the same `authServerHostname` and other settings
4. Start all beacons

All beacons will automatically coordinate by sending measurements for the same client ID to the auth server, which collects and processes them together.

## Advanced: Custom Settings

You can modify beacon behavior by editing config:

- **listenChannel**: Change if channel 1000 conflicts (update clients too)
- **authProtocol**: Custom protocol name (update auth server too)
- **authServerHostname**: Different hostname if running multiple auth systems

## Related Documentation

- Main system: `../README.md`
- Auth server setup: See parent directory
- Client usage: See main README

## Support

For issues or questions:
- Check beacon logs for error messages
- Verify position accuracy (most common issue)
- Ensure DNS registration is correct
- Test with single beacon first, then add more
