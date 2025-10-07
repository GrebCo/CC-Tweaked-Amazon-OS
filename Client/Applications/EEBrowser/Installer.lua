local localVersion = fs.open("Version.txt", "r")
local version
if localVersion then
    version = localVersion.readAll()
    localVersion.close()
else
    version = 0
end

print("Current version: " .. version)
-- TODO Update urls before release
shell.run("wget https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/efraimDev/Client/Applications/EEBrowser/version.txt remoteversion.txt")

local file = fs.open("remoteversion.txt", "r")
local remoteVersion = file.readAll()
file.close()

print("Remote version: " .. remoteVersion)

shell.run("delete remoteversion.txt")

if remoteVersion ~= version then
    print("A new version is available! Updating now.")
    sleep(1)
    print("Deleting old files...")

    
    shell.run("delete browser.lua")
    shell.run("delete network_config.lua")
    shell.run("delete Installer.lua")
    shell.run("delete Default.txt")


    print("Downloading new files...")
    shell.run("wget https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/efraimDev/Client/Applications/EEBrowser/Client/browser.lua browser.lua")
    shell.run("wget https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/efraimDev/Client/Applications/EEBrowser/Client/Default.txt Default.txt")
    shell.run("wget https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/efraimDev/Client/Applications/EEBrowser/Client/update.lua update.lua")
    shell.run("wget https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/efraimDev/Client/Applications/EEBrowser/Client/Installer.lua Installer.lua")
    
    local newVersion = fs.open("Version.txt", "w")
    newVersion.write(remoteVersion)
    newVersion.close()
end
