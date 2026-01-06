-- EETodo Server Installer
-- Downloads and sets up the EETodo server

local BASE_URL = "https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/dev/Elliot/TodoList/"

local FILES = {
    "Server.lua",
    "startup.lua"
}

print("EETodo Server Installer")
print("======================")
print("")

-- Function to download a file
local function downloadFile(filename)
    local url = BASE_URL .. filename
    print("Downloading " .. filename .. "...")

    local response = http.get(url)
    if not response then
        error("Failed to download " .. filename)
    end

    local content = response.readAll()
    response.close()

    local file = fs.open(filename, "w")
    file.write(content)
    file.close()

    print("  [OK] " .. filename)
end

-- Download all files
for _, filename in ipairs(FILES) do
    downloadFile(filename)
end

print("")
print("Installation complete!")
print("The server will start automatically on boot.")
print("You can also run it manually with: Server")
print("")
print("Rebooting in 3 seconds...")
sleep(3)
os.reboot()
