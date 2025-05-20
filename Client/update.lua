local localVersionFile = fs.open("version.txt", "w")
localVersionFile.write("0")
localVersionFile.close()
os.reboot()
