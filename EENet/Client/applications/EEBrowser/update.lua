local localVersionFile = fs.open("applications/EEBrowser/version.txt", "w")
localVersionFile.write("0")
localVersionFile.close()
shell.run("applications/EEBrowser/Installer.lua")
