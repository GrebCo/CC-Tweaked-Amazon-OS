-- Reactor Controller Installer
-- Downloads and sets up the Mekanism Fission Reactor Controller

local GITHUB_BASE = "https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/dev/Elliot/Reactor"
local FILES = {
    "reactor.lua",
    "reactor_config.lua",
    "chatbox_notifications.lua",
    "README.md"
}

local function downloadFile(url, filename)
    print("Downloading " .. filename .. "...")

    local response = http.get(url)
    if not response then
        print("ERROR: Failed to download " .. filename)
        return false
    end

    local content = response.readAll()
    response.close()

    local file = fs.open(filename, "w")
    file.write(content)
    file.close()

    print("  Downloaded " .. filename)
    return true
end

local function localInstall()
    print("Installing Reactor Controller (Local Mode)")
    print("")

    -- Check if files already exist
    if fs.exists("reactor.lua") then
        print("Files already exist in this directory.")
        print("This appears to be a fresh install or update.")
        print("")
    end

    print("Setup complete!")
    print("")
    print("Next steps:")
    print("1. Edit reactor_config.lua to configure your reactor")
    print("2. Add your username to NOTIFY_PLAYERS list")
    print("3. Run: reactor")
    print("")
    print("For more info, see README.md")
end

local function githubInstall()
    print("Installing Reactor Controller from GitHub")
    print("")

    -- Check if HTTP API is enabled
    if not http then
        print("ERROR: HTTP API is not enabled!")
        print("Enable it in ComputerCraft config")
        return
    end

    local success = true
    for _, filename in ipairs(FILES) do
        if not downloadFile(GITHUB_BASE .. filename, filename) then
            success = false
            break
        end
    end

    if success then
        print("")
        print("Installation complete!")
        print("")
        print("Next steps:")
        print("1. Edit reactor_config.lua to configure your reactor")
        print("2. Add your username to NOTIFY_PLAYERS list")
        print("3. Run: reactor")
    else
        print("")
        print("Installation failed. Please check your internet connection.")
    end
end

-- Main installer
term.clear()
term.setCursorPos(1, 1)

print("======================================")
print("  Mekanism Reactor Controller Setup  ")
print("======================================")
print("")
print("This installer will set up the reactor")
print("controller on this computer.")
print("")
print("Installation method:")
print("  [1] Local (files already present)")
print("  [2] Download from GitHub")
print("")
write("Select option (1 or 2): ")

local choice = read()

print("")

if choice == "1" then
    localInstall()
elseif choice == "2" then
    githubInstall()
else
    print("Invalid choice. Installation cancelled.")
end
