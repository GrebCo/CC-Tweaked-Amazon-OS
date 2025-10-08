local localVersionFile = fs.open("Version.txt", "w")
localVersionFile.write("0")
localVersionFile.close()
shell.run("Installer.lua")
