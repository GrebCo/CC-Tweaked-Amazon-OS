local localVersion = fs.open("Version.txt", "r")
local version
if localVersion then
    version = localVersion.readAll()
    localVersion.close()
else
    version = 0
end

print("Current version: " .. version)

shell.run("wget https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/Version-2.0/Client/Applications/EEBrowser/version.txt remoteversion.txt")

local file = fs.open("remoteversion.txt", "r")
local remoteVersion = file.readAll()
file.close()

print("Remote version: " .. remoteVersion)

shell.run("delete remoteversion.txt")

if remoteVersion ~= version then
    print("A new version is available! Updating now.")
    sleep(1)
    print("Deleting old files...")

    

    shell.run("delete OSUtil/")
    shell.run("mkdir OSUtil")
    
    print("Downloading new files...")
    shell.run("wget https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/Version-2.0/Client/OSUtil/UI OSUtil/UI.lua")
    shell.run("wget https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/Version-2.0/Client/OSUtil/ClientNetworkHandler.lua OSUtil/ClientNetworkHandler.lua")
    shell.run("wget https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/Version-2.0/Client/OSUtil/MiniMark.lua OSUtil/MiniMark.lua")
    
    
    local newVersion = fs.open("Version.txt", "w")
    newVersion.write(remoteVersion)
    newVersion.close()
end
