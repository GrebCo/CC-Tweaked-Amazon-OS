local localVersion = fs.open("version.txt", "r")
local version
if localVersion then
    version = localVersion.readAll()
    localVersion.close()
else
    version = 0
end

print("Current version: " .. version)

shell.run("wget https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/dev/Elliot/Client/version.txt remoteVersion.txt")

local file = fs.open("remoteVersion.txt", "r")
local remoteVersion = file.readAll()
file.close()

print("Remote version: " .. remoteVersion)

shell.run("delete remoteversion.txt")

if remoteVersion ~= version then
    print("A new version is available! Updating now.")
    sleep(1)
    print("Deleting old files...")

    

    shell.run("delete OSUtil/")
    shell.run("delete EEBrowser/")
    shell.run("delete Config/")
    shell.run("delete Installer.lua")
    shell.run("mkdir OSUtil")
    shell.run("mkdir EEBrowser")
    shell.run("mkdir Config")
    
    print("Downloading new files...")
    shell.run("wget https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/dev/Elliot/Client/OSUtil/UI.lua OSUtil/UI.lua")
    shell.run("wget https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/dev/Elliot/Client/OSUtil/ClientNetworkHandler.lua OSUtil/ClientNetworkHandler.lua")
    shell.run("wget https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/dev/Elliot/Client/OSUtil/MiniMark.lua OSUtil/MiniMark.lua")
    shell.run("wget https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/dev/Elliot/Client/OSUtil/MiniMark.lua OSUtil/events.lua")
    shell.run("wget https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/dev/Elliot/Client/Installer.lua Installer.lua")
    shell.run("wget https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/dev/Elliot/Client/Installer.lua update.lua")


    -- get Browser
    shell.run("wget https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/dev/Elliot/Client/EEBrowser/browser.lua EEBrowser/browser.lua")
    shell.run("wget https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/dev/Elliot/Client/EEBrowser/Default.txt EEBrowser/Default.txt")
    shell.run("wget https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/dev/Elliot/Client/EEBrowser/fizzle.txt EEBrowser/fizzle.lua")

    -- get Network Config
    shell.run("wget https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/dev/Elliot/Client/Config/network_config.lua Config/network_config.lua")
    
    local newVersion = fs.open("version.txt", "w")
    newVersion.write(remoteVersion)
    newVersion.close()
end
