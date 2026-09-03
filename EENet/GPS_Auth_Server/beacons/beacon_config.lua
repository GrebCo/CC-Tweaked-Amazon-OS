-- GPS Beacon Configuration Template
-- Copy this file and edit with your beacon's actual position

return {
    -- Beacon's physical position in the world
    -- IMPORTANT: Use F3 to get exact coordinates
    -- These coordinates must be accurate for trilateration to work!
    position = {
        x = 100,  -- Replace with actual X coordinate
        y = 64,   -- Replace with actual Y coordinate
        z = 200   -- Replace with actual Z coordinate
    },

    -- Unique identifier for this beacon
    -- Use different IDs for each beacon (1, 2, 3, etc.)
    beaconID = 1,

    -- DNS hostname of the authentication server
    -- This hostname must be registered in DNS_Master.json
    authServerHostname = "gps_auth_server",

    -- Protocol for communication with auth server
    authProtocol = "GPSAuth",

    -- Modem channel to listen for auth requests
    listenChannel = 1000,

    -- DNS protocol for looking up auth server
    dnsProtocol = "DNS"
}
