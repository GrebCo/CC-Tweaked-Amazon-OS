local localVersion = fs.open("applications/EEBrowser/version.txt", "r")
local version
if localVersion then
    version = localVersion.readAll()
    localVersion.close()
else
    version = 0
end

print("Current version: " .. version)

shell.run("wget https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/dev/Elliot/Client/Applications/EEBrowser/version.txt applications/EEBrowser/remoteVersion.txt")

local file = fs.open("applications/EEBrowser/remoteVersion.txt", "r")
local remoteVersion = file.readAll()
file.close()

print("Remote version: " .. remoteVersion)

shell.run("delete applications/EEBrowser/remoteVersion.txt")

if remoteVersion ~= version then
    print("A new version is available! Updating now.")
    sleep(1)
    print("Deleting old files...")

    shell.run("delete OSUtil/")
    shell.run("delete EEBrowser/")
    shell.run("delete applications/")
    shell.run("delete Config/")
    shell.run("delete cache/")
    shell.run("delete logs/")

    print("Creating directory structure...")
    shell.run("mkdir OSUtil")
    shell.run("mkdir OSUtil/UI")
    shell.run("mkdir applications")
    shell.run("mkdir applications/EEBrowser")
    shell.run("mkdir applications/EEBrowser/fizzleLibraries")
    shell.run("mkdir applications/EEBrowser/config")
    shell.run("mkdir applications/EEBrowser/cache")
    shell.run("mkdir applications/EEBrowser/cache/scripts")
    shell.run("mkdir applications/EEBrowser/logs")

    print("Downloading OSUtil files...")
    shell.run("wget https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/dev/Elliot/Client/OSUtil/UI.lua OSUtil/UI.lua")
    shell.run("wget https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/dev/Elliot/Client/OSUtil/ClientNetworkHandler.lua OSUtil/ClientNetworkHandler.lua")
    shell.run("wget https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/dev/Elliot/Client/OSUtil/events.lua OSUtil/events.lua")
    shell.run("wget https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/dev/Elliot/Client/OSUtil/Logger.lua OSUtil/Logger.lua")

    print("Downloading OSUtil/UI files...")
    shell.run("wget https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/dev/Elliot/Client/OSUtil/UI/UI.lua OSUtil/UI/UI.lua")
    shell.run("wget https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/dev/Elliot/Client/OSUtil/UI/Inputs.lua OSUtil/UI/Inputs.lua")
    shell.run("wget https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/dev/Elliot/Client/OSUtil/UI/dataDisplay.lua OSUtil/UI/dataDisplay.lua")
    shell.run("wget https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/dev/Elliot/Client/OSUtil/UI/themes.lua OSUtil/UI/themes.lua")
    shell.run("wget https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/dev/Elliot/Client/OSUtil/UI/advancedTerminal.lua OSUtil/UI/advancedTerminal.lua")

    print("Downloading EEBrowser...")
    shell.run("wget https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/dev/Elliot/Client/Applications/EEBrowser/browser.lua applications/EEBrowser/browser.lua")
    shell.run("wget https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/dev/Elliot/Client/Applications/EEBrowser/Default.txt applications/EEBrowser/Default.txt")
    shell.run("wget https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/dev/Elliot/Client/Applications/EEBrowser/fizzle.lua applications/EEBrowser/fizzle.lua")
    shell.run("wget https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/dev/Elliot/Client/Applications/EEBrowser/MiniMark.lua applications/EEBrowser/MiniMark.lua")
    shell.run("wget https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/dev/Elliot/Client/Applications/EEBrowser/version.txt applications/EEBrowser/version.txt")

    print("Downloading Fizzle libraries...")
    shell.run("wget https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/dev/Elliot/Client/Applications/EEBrowser/fizzleLibraries/libraries.lua applications/EEBrowser/fizzleLibraries/libraries.lua")
    shell.run("wget https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/dev/Elliot/Client/Applications/EEBrowser/fizzleLibraries/fizzleNetwork.lua applications/EEBrowser/fizzleLibraries/fizzleNetwork.lua")
    shell.run("wget https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/dev/Elliot/Client/Applications/EEBrowser/fizzleLibraries/document.lua applications/EEBrowser/fizzleLibraries/document.lua")

    print("Downloading Config files...")
    shell.run("wget https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/dev/Elliot/Client/Config/network_config.lua applications/EEBrowser/config/network_config.lua")

    print("Downloading installer files...")
    shell.run("wget https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/dev/Elliot/Client/Applications/EEBrowser/Installer.lua applications/EEBrowser/Installer.lua")
    shell.run("wget https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/dev/Elliot/Client/Applications/EEBrowser/update.lua applications/EEBrowser/update.lua")

    local newVersion = fs.open("applications/EEBrowser/version.txt", "w")
    newVersion.write(remoteVersion)
    newVersion.close()

    print("Update complete!")
end
