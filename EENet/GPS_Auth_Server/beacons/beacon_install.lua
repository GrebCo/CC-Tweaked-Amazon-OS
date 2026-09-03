print("Installing GPS Authentication Beacon...")
print("")

print("Deleting old files...")
shell.run("delete beacon.lua")
shell.run("delete beacon_config.lua")

print("Downloading new files...")
local baseURL = "https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/main/EENet/GPS_Auth_Server/beacons/"

shell.run("wget " .. baseURL .. "beacon.lua beacon.lua")
shell.run("wget " .. baseURL .. "beacon_config.lua beacon_config.lua")

print("Downloading complete.")
print("")
print("==============================================")
print("Installation complete!")
print("==============================================")
print("")
print("IMPORTANT: You MUST configure this beacon!")
print("")
print("1. Use F3 to get this computer's exact X, Y, Z coordinates")
print("2. Edit beacon_config.lua and set the position")
print("3. Set a unique beaconID (1, 2, 3, etc.)")
print("4. Verify authServerHostname matches DNS registration")
print("5. Run 'beacon.lua' or 'reboot' to start")
print("")
print("Beacon will NOT work until configured!")
print("")
