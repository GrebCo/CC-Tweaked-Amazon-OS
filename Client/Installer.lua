local localVersion = fs.open("version.txt", "r")
local version
if localVersion then
    version = localVersion.readAll()
    localVersion.close()
else
    version = 0
end

print("Current version: " .. version)

shell.run("wget https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/Version-2.0/Client/version.txt remoteVersion.txt")

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
    shell.run("delete Installer.lua")
    shell.run("mkdir OSUtil")
    
    print("Downloading new files...")
    shell.run("wget https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/Version-2.0/Client/OSUtil/UI.lua OSUtil/UI.lua")
    shell.run("wget https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/Version-2.0/Client/OSUtil/ClientNetworkHandler.lua OSUtil/ClientNetworkHandler.lua")
    shell.run("wget https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/Version-2.0/Client/OSUtil/MiniMark.lua OSUtil/MiniMark.lua")
    shell.run("wget https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/Version-2.0/Client/Installer.lua Installer.lua")
    
    
    local newVersion = fs.open("Version.txt", "w")
    newVersion.write(remoteVersion)
    newVersion.close()
end
