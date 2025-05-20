local localVersion = fs.open("localVersion.txt", "r")
local version
if localVersion then
    version = localVersion.readAll()
    localVersion.close()
else
    version = 0
end

print("Current version: " .. version)

shell.run("wget https://raw.githubusercontent.com/Easease/CC-Tweaked-Amazon-OS/refs/heads/main/version.txt remoteversion.txt")

local file = fs.open("remoteversion.txt", "r")
local remoteVersion = file.readAll()
file.close()

print("Remote version: " .. remoteVersion)

shell.run("delete remoteversion.txt")

if remoteVersion ~= version then
    print("A new version is available! Updating now.")
    sleep(1)
    print("Deleting old files...")
    shell.run("delete localVersion.txt")
    
    shell.run("delete ClientNetworkHandler.lua")
    shell.run("delete UI.lua")
    shell.run("delete MiniMark.lua")
    shell.run("delete browser.lua")
    shell.run("delete network_config.lua")


    print("Downloading new files...")
    shell.run("wget https://raw.githubusercontent.com/Easease/CC-Tweaked-Amazon-OS/refs/heads/main/Client/ClientNetworkHandler.lua ClientNetworkHandler.lua")
    shell.run("wget https://raw.githubusercontent.com/Easease/CC-Tweaked-Amazon-OS/refs/heads/main/Client/UI.lua UI.lua")
    shell.run("wget https://raw.githubusercontent.com/Easease/CC-Tweaked-Amazon-OS/refs/heads/main/Client/MiniMark.lua MiniMark.lua")
    shell.run("wget https://raw.githubusercontent.com/Easease/CC-Tweaked-Amazon-OS/refs/heads/main/Client/browser.lua browser.lua")
    shell.run("wget https://raw.githubusercontent.com/Easease/CC-Tweaked-Amazon-OS/refs/heads/main/Client/network_config.lua network_config.lua")
    shell.run("wget https://raw.githubusercontent.com/Easease/CC-Tweaked-Amazon-OS/refs/heads/main/Client/Default.txt Default.txt")

    local newVersion = fs.open("localVersion.txt", "w")
    newVersion.write(remoteVersion)
    newVersion.close()
end

shell.run("browser.lua")
