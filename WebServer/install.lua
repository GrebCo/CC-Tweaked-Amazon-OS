print("Installing Webserver Program...")

print("Deleting old files...")

shell.run("delete webServer.lua")
shell.run("delete startup.lua")

print("Downloading new files...")
shell.run("wget https://raw.githubusercontent.com/Easease/CC-Tweaked-Amazon-OS/refs/heads/main/WebServer/webServer.lua webServer.lua")
shell.run("wget https://raw.githubusercontent.com/Easease/CC-Tweaked-Amazon-OS/refs/heads/main/WebServer/startup.lua startup.lua")
shell.run("wget https://raw.githubusercontent.com/Easease/CC-Tweaked-Amazon-OS/refs/heads/main/WebServer/Demo.txt Demo.txt")
print("Downloading complete.")
print("Restarting Webserver...")
sleep(5)
shell.run("reboot")
