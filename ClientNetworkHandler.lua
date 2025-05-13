local PROTOCOL = "DNS"
local CACHE_FILE = "dns_cache.txt"
local ENABLE_LOG = true  -- Set to false to disable logging to file
local ENABLE_PRINT = true  -- Set to false to disable printing to screen
local LOG_FILE = "dns_client.log"

local function log(msg)
    -- Log to file if ENABLE_LOG is true
    if ENABLE_LOG then
        local file = fs.open(LOG_FILE, "a")
        if file then
            file.writeLine("[" .. os.time() .. "] " .. msg)
            file.close()
        end
    end

    -- Print to screen if ENABLE_PRINT is true
    if ENABLE_PRINT then
        print(msg)
    end
end

function openRednet()
    -- Open rednet via modem
    peripheral.find("modem", rednet.open)
    log("Rednet opened.")
end

function closeRednet()
    -- Close rednet
    rednet.close()
    log("Rednet closed.")
end

function requestNewDNS()
    -- Locate DNS server
    local serverID = rednet.lookup(PROTOCOL)
    if not serverID then
        log("DNS server not found.")
        return
    end

    -- Send DNS request
    rednet.send(serverID, "get", PROTOCOL)
    log("Requesting DNS data from server...")

    -- Wait for response
    local senderID, response = rednet.receive(PROTOCOL, 5)
    if response then
        log("Received DNS data. Caching to file...")

        local file = fs.open(CACHE_FILE, "w")
        if file then
            file.write(response)
            file.close()
            log("DNS data cached to '" .. CACHE_FILE .. "'.")
        else
            log("Error: Could not write to cache file.")
        end

        log("\nDNS Data:\n" .. response)
    else
        log("No response received from DNS server.")
    end
end

-- Main execution
openRednet()
requestNewDNS()
closeRednet()