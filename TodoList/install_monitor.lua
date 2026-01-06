-- EETodo Monitor Client Installer
-- Downloads and sets up the EETodo monitor client

local BASE_URL = "https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/dev/Elliot/TodoList/"

local FILES = {
    "MonitorClient.lua",
    "EETodoCore.lua",
    "UI.lua",
    "themes.lua",
    "startup.lua"
}

print("EETodo Monitor Client Installer")
print("================================")
print("")

-- Check for monitor
local monitor = peripheral.find("monitor")
if not monitor then
    print("WARNING: No monitor detected!")
    print("Please attach a monitor before running.")
    print("")
end

-- Function to download a file
local function downloadFile(filename)
    local url = BASE_URL .. filename
    print("Downloading " .. filename .. "...")

    local response = http.get(url)
    if not response then
        error("Failed to download " .. filename)
    end

    local content = response.readAll()
    response.close()

    local file = fs.open(filename, "w")
    file.write(content)
    file.close()

    print("  [OK] " .. filename)
end

-- Download all files
for _, filename in ipairs(FILES) do
    downloadFile(filename)
end

print("")
print("Installation complete!")
print("The monitor client will start automatically on boot.")
print("You can also run it manually with: MonitorClient")
print("")
print("Rebooting in 3 seconds...")
sleep(3)
os.reboot()
