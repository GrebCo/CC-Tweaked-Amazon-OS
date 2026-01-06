-- EETodo Startup Script
-- Automatically detects and runs the appropriate client/server

if fs.exists("Server.lua") then
    -- This is a server
    shell.run("Server.lua")
elseif fs.exists("MonitorClient.lua") then
    -- This is a monitor client
    shell.run("MonitorClient.lua")
else
    print("No EETodo client or server found!")
    print("Please run the appropriate installer.")
end
