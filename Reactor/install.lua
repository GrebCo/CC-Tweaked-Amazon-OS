-- Reactor Controller Installer
-- Downloads and sets up the Mekanism Fission Reactor Controller

local GITHUB_BASE = "https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/dev/Elliot/Reactor/"
local FILES = {
    "reactor.lua",
    "reactor_config.lua",
    "chatbox_notifications.lua",
    "README.md"
}

-- Main installer
term.clear()
term.setCursorPos(1, 1)

print("======================================")
print("  Mekanism Reactor Controller Setup  ")
print("======================================")
print("")
print("Installing from GitHub...")
print("")

-- Check if HTTP API is enabled
if not http then
    print("ERROR: HTTP API is not enabled!")
    print("Enable it in ComputerCraft config")
    return
end

local success = true
for _, filename in ipairs(FILES) do
    local url = GITHUB_BASE .. filename
    print("Downloading " .. filename .. "...")

    local result = shell.run("wget", url, filename)
    if not result then
        print("  ERROR: Failed to download " .. filename)
        success = false
        break
    end
    print("  OK")
end

if success then
    print("")
    print("Installation complete!")
    print("")
    print("Next steps:")
    print("1. Edit reactor_config.lua to configure your reactor")
    print("2. Add your username to NOTIFY_PLAYERS list")
    print("3. Run: reactor")
    print("")
    print("For more info, see README.md")
else
    print("")
    print("Installation failed. Please check your internet connection.")
end
