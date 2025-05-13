local PROTOCOL = "DNS"
local CACHE_FILE = "dns_cache.txt"
local ENABLE_LOG = true  -- Set to false to disable logging to file
local ENABLE_PRINT = true  -- Set to false to disable printing to screen
local LOG_FILE = "dns_client.log"

local function init(config)
    PROTOCOL     = config.PROTOCOL or PROTOCOL
    CACHE_FILE   = config.CACHE_FILE or CACHE_FILE
    ENABLE_LOG   = config.ENABLE_LOG or ENABLE_LOG
    ENABLE_PRINT = config.ENABLE_PRINT or ENABLE_PRINT
    LOG_FILE     = config.LOG_FILE or LOG_FILE
end

local function log(msg)
    -- Log to file if ENABLE_LOG is true
    if ENABLE_LOG then
        local file = fs.open(LOG_FILE, "a") --append mode
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

-- Function to parse the DNS cache and find the ID for a hostname
function resolveHostname(hostname)
    local function parseDNSFile()
        if not fs.exists(CACHE_FILE) then return nil end

        local file = fs.open(CACHE_FILE, "r")
        if not file then return nil end

        local dnsTable = {}
        for line in file.readLine do
            local name, id = string.match(line, "^(.-):(%d+)$")
            if name and id then
                dnsTable[name] = tonumber(id)
            end
        end
        file.close()
        return dnsTable
    end

    local dnsData = parseDNSFile()
    if dnsData and dnsData[hostname] then
        log("Resolved '" .. hostname .. "' to ID: " .. dnsData[hostname])
        return dnsData[hostname]
    end

    log("Hostname '" .. hostname .. "' not found in cache. Attempting DNS update...")
    requestNewDNS()

    dnsData = parseDNSFile()
    if dnsData and dnsData[hostname] then
        log("Resolved '" .. hostname .. "' to ID after update: " .. dnsData[hostname])
        return dnsData[hostname]
    end

    log("Failed to resolve hostname '" .. hostname .. "'.")
    return nil
end

-- Send a message to a numeric ID or hostname on a given protocol
function send(target, message, protocol)
    local id = nil

    if type(target) == "number" then
        id = target
    elseif type(target) == "string" then
        id = resolveHostname(target)
        if not id then
            log("Send failed: Could not resolve hostname '" .. target .. "'.")
            return false
        end
    else
        log("Send failed: Invalid target type '" .. type(target) .. "'. Expected number or string.")
        return false
    end

    rednet.send(id, message, protocol)
    log("Sent message to ID " .. id .. " via protocol '" .. protocol .. "': " .. tostring(message))
    return true
end

function query(target, message, protocol, timeout)

    local id = nil
    if type(target) == "number" then
        id = target
    elseif type(target) == "string" then
        id = resolveHostname(target)
        if not id then
            log("Query failed: Could not resolve hostname '" .. target .. "'.")
            return nil
        end
    else
        log("Query failed: Invalid target type '" .. type(target) .. "'. Expected number or string.")
        return nil
    end

    rednet.send(id, message, protocol)
    log("Sent query to ID " .. id .. " via protocol '" .. protocol .. "': " .. tostring(message))

    local senderID, response = rednet.receive(protocol, timeout or 5)
    if response then
        log("Received response from ID " .. senderID .. ": " .. tostring(response))
        return response
    else
        log("Query timed out waiting for reply from ID " .. id)
        return nil
    end
end

return 
{
    init = init,
    openRednet = openRednet,
    closeRednet = closeRednet,
    requestNewDNS = requestNewDNS,
    resolveHostname = resolveHostname,
    send = send,
    query = query
}


