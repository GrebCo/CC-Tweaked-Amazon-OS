-- Load configuration
dofile("applications/EEBrowser/installer_config.lua")

-- Helper function to build GitHub raw URL
local function buildUrl(relativePath)
    return string.format(
        "https://raw.githubusercontent.com/%s/%s/refs/heads/%s/%s/%s",
        config.owner,
        config.repo,
        config.branch,
        config.basePath,
        relativePath
    )
end

-- Helper function to create directories
local function ensureDirectory(path)
    if not fs.exists(path) then
        fs.makeDir(path)
    end
end

-- Check current version
local localVersion = fs.open("applications/EEBrowser/version.txt", "r")
local version = "0"
if localVersion then
    version = localVersion.readAll()
    localVersion.close()
end

print("=== EEBrowser Updater ===")
print("Current version: " .. version)
print("Branch: " .. config.branch)
print("")

-- Fetch remote version
print("Checking for updates...")
local remoteVersionUrl = buildUrl("applications/EEBrowser/version.txt")
shell.run("wget", remoteVersionUrl, "applications/EEBrowser/remoteVersion.txt")

local file = fs.open("applications/EEBrowser/remoteVersion.txt", "r")
local remoteVersion = file.readAll()
file.close()

print("Remote version: " .. remoteVersion)
print("")

fs.delete("applications/EEBrowser/remoteVersion.txt")

if remoteVersion ~= version then
    print("A new version is available! Updating now.")
    sleep(1)
    print("Deleting old files...")

    fs.delete("OSUtil")
    fs.delete("applications")

    print("Creating directory structure...")
    ensureDirectory("OSUtil")
    ensureDirectory("OSUtil/UI")
    ensureDirectory("applications")
    ensureDirectory("applications/EEBrowser")
    ensureDirectory("applications/EEBrowser/fizzleLibraries")
    ensureDirectory("applications/EEBrowser/config")
    ensureDirectory("applications/EEBrowser/cache")
    ensureDirectory("applications/EEBrowser/cache/scripts")
    ensureDirectory("applications/EEBrowser/logs")

    print("")
    print("Downloading files...")

    -- OSUtil files
    print("Downloading OSUtil files...")
    shell.run("wget", buildUrl("OSUtil/UI.lua"), "OSUtil/UI.lua")
    shell.run("wget", buildUrl("OSUtil/ClientNetworkHandler.lua"), "OSUtil/ClientNetworkHandler.lua")
    shell.run("wget", buildUrl("OSUtil/events.lua"), "OSUtil/events.lua")
    shell.run("wget", buildUrl("OSUtil/Logger.lua"), "OSUtil/Logger.lua")

    -- OSUtil/UI files
    print("Downloading OSUtil/UI files...")
    shell.run("wget", buildUrl("OSUtil/UI/UI.lua"), "OSUtil/UI/UI.lua")
    shell.run("wget", buildUrl("OSUtil/UI/Inputs.lua"), "OSUtil/UI/Inputs.lua")
    shell.run("wget", buildUrl("OSUtil/UI/dataDisplay.lua"), "OSUtil/UI/dataDisplay.lua")
    shell.run("wget", buildUrl("OSUtil/UI/themes.lua"), "OSUtil/UI/themes.lua")
    shell.run("wget", buildUrl("OSUtil/UI/advancedTerminal.lua"), "OSUtil/UI/advancedTerminal.lua")

    -- EEBrowser main files
    print("Downloading EEBrowser files...")
    shell.run("wget", buildUrl("applications/EEBrowser/browser.lua"), "applications/EEBrowser/browser.lua")
    shell.run("wget", buildUrl("applications/EEBrowser/fizzle.lua"), "applications/EEBrowser/fizzle.lua")
    shell.run("wget", buildUrl("applications/EEBrowser/MiniMark.lua"), "applications/EEBrowser/MiniMark.lua")
    shell.run("wget", buildUrl("applications/EEBrowser/version.txt"), "applications/EEBrowser/version.txt")

    -- Fizzle libraries
    print("Downloading Fizzle libraries...")
    shell.run("wget", buildUrl("applications/EEBrowser/fizzleLibraries/libraries.lua"), "applications/EEBrowser/fizzleLibraries/libraries.lua")
    shell.run("wget", buildUrl("applications/EEBrowser/fizzleLibraries/fizzleNetwork.lua"), "applications/EEBrowser/fizzleLibraries/fizzleNetwork.lua")
    shell.run("wget", buildUrl("applications/EEBrowser/fizzleLibraries/document.lua"), "applications/EEBrowser/fizzleLibraries/document.lua")
    shell.run("wget", buildUrl("applications/EEBrowser/fizzleLibraries/fizzleCookie.lua"), "applications/EEBrowser/fizzleLibraries/fizzleCookie.lua")

    -- Config files
    print("Downloading Config files...")
    shell.run("wget", buildUrl("applications/EEBrowser/config/network_config.lua"), "applications/EEBrowser/config/network_config.lua")
    shell.run("wget", buildUrl("applications/EEBrowser/config/fizzle_config.lua"), "applications/EEBrowser/config/fizzle_config.lua")

    -- Installer files
    print("Downloading installer files...")
    shell.run("wget", buildUrl("applications/EEBrowser/Installer.lua"), "applications/EEBrowser/Installer.lua")
    shell.run("wget", buildUrl("applications/EEBrowser/update.lua"), "applications/EEBrowser/update.lua")
    shell.run("wget", buildUrl("applications/EEBrowser/APIInstaller.lua"), "applications/EEBrowser/APIInstaller.lua")
    shell.run("wget", buildUrl("applications/EEBrowser/installer_config.lua"), "applications/EEBrowser/installer_config.lua")

    print("")
    print("Update complete!")
else
    print("Already up to date!")
end
