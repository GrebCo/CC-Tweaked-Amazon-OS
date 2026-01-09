-- Default protocol used for DNS communication via rednet
local DNS_PROTOCOL = "DNS"

-- Default file where resolved DNS entries (hostname → ID) are stored
local CACHE_FILE = "applications/EEBrowser/cache/dns_cache.txt"

-- Logging and output configuration flags
local ENABLE_LOG = true         -- If true, logs will be written to a file
local ENABLE_PRINT = false       -- If true, logs will be printed to the terminal
local LOG_FILE = "applications/EEBrowser/logs/dns_client.log"  -- The file to which logs are written

local log = function() end  -- default no-op
---------------------------------------------------------------------
-- Initializes the module with custom configuration
-- Allows user to override default settings by providing a config table
---------------------------------------------------------------------
local function init(config)
    local DNS_PROTOCOL     = config.DNS_PROTOCOL or DNS_PROTOCOL         -- Use custom protocol or default
    local CACHE_FILE   = config.CACHE_FILE or CACHE_FILE     -- Use custom cache file or default
    local ENABLE_LOG   = config.ENABLE_LOG or ENABLE_LOG     -- Override log-to-file flag
    local ENABLE_PRINT = config.ENABLE_PRINT or ENABLE_PRINT -- Override terminal print flag
    LOG_FILE     = config.LOG_FILE or LOG_FILE         -- Use custom log file or default
    if ENABLE_LOG then
        logger = require("OSUtil/Logger")
        log = logger.log
    else
        log = function() end
    end
end

---------------------------------------------------------------------
-- Logs a message to a file and/or to the terminal depending on config
-- Automatically timestamps logs when writing to file
---------------------------------------------------------------------


---------------------------------------------------------------------
-- Opens rednet networking on the first modem it finds
-- Needed before sending or receiving any messages
---------------------------------------------------------------------
function openRednet()
    if not peripheral.find("modem", rednet.open) then
        log("[ERROR] ModemNotFound")
        --error("No Modem Found")  
    else
        log("Rednet opened.")
    end
end

---------------------------------------------------------------------
-- Closes the rednet network interface
-- Good practice when shutting down or rebooting
---------------------------------------------------------------------
function closeRednet()
    rednet.close()  -- Closes all open rednet connections
    log("Rednet closed.")
end

---------------------------------------------------------------------
-- Ensures that rednet is open before any communication
-- Opens it automatically if not already open
---------------------------------------------------------------------
function ensureRednet()
    if not rednet.isOpen() then
        log("Rednet is not open. Attempting to open...")
        openRednet()
    end
end

---------------------------------------------------------------------
-- Requests updated DNS entries from a DNS server on the network
-- Looks up the server using a predefined protocol and caches response
---------------------------------------------------------------------
function requestNewDNS()
    ensureRednet()

    local serverID = rednet.lookup(DNS_PROTOCOL)
    if not serverID then
        log("DNS server not found.")
        return
    end

    rednet.send(serverID, "get", DNS_PROTOCOL)
    log("Requesting DNS data from server...")

    local senderID, response = rednet.receive(DNS_PROTOCOL, 5)
    if response then
        -- Validate JSON
        local success, dnsData = pcall(textutils.unserializeJSON, response)
        if not success or type(dnsData) ~= "table" then
            log("Received invalid JSON from server.")
            return
        end

        -- Save raw JSON response
        local file = fs.open(CACHE_FILE, "w")
        if file then
            file.write(response)
            file.close()
            log("DNS data cached to '" .. CACHE_FILE .. "'.")
        else
            log("Error: Could not write to cache file.")
        end

        -- Log parsed DNS table
        for _, entry in ipairs(dnsData) do
            log(string.format("Entry: %s : %d (%s)", entry.hostname, entry.id, entry.protocol))
        end
    else
        log("No response received from DNS server.")
    end
end

---------------------------------------------------------------------
-- Attempts to resolve a hostname to a numeric rednet ID
-- Tries the local cache first, then refreshes from the server if needed
---------------------------------------------------------------------
function resolveHostname(hostname)
    -- Local helper function to read and parse the cache file
    local function parseDNSFile()
        if not fs.exists(CACHE_FILE) then return nil end
    
        local file = fs.open(CACHE_FILE, "r")
        if not file then return nil end
    
        local content = file.readAll()
        file.close()
    
        local success, dnsData = pcall(textutils.unserializeJSON, content)
        if not success or type(dnsData) ~= "table" then
            return nil
        end
    
        -- Convert list of entries into a lookup table
        local dnsTable = {}
        for _, entry in ipairs(dnsData) do
            if entry.hostname and entry.id then
                dnsTable[entry.hostname] = entry.id
            end
        end
    
        return dnsTable
    end

    -- Try resolving using the local DNS cache
    local dnsData = parseDNSFile()
    if dnsData and dnsData[hostname] then
        log("Resolved '" .. hostname .. "' to ID: " .. dnsData[hostname])
        return dnsData[hostname]
    end

    -- If not found in cache, request updated DNS info
    log("Hostname '" .. hostname .. "' not found in cache. Attempting DNS update...")
    requestNewDNS()

    -- Try again after updating the cache
    dnsData = parseDNSFile()
    if dnsData and dnsData[hostname] then
        log("Resolved '" .. hostname .. "' to ID after update: " .. dnsData[hostname])
        return dnsData[hostname]
    end

    -- Still not found
    log("Failed to resolve hostname '" .. hostname .. "'.")
    return nil
end

---------------------------------------------------------------------
-- Sends a message to a target computer by hostname or numeric ID
-- Automatically resolves hostnames and logs activity
---------------------------------------------------------------------
function send(target, message, protocol)
    ensureRednet()  -- Make sure rednet is open

    local id = nil

    -- Handle numeric ID
    if type(target) == "number" then
        id = target

    -- Handle hostname resolution
    elseif type(target) == "string" then
        id = resolveHostname(target)
        if not id then
            log("Send failed: Could not resolve hostname '" .. target .. "'.")
            return false
        end

    -- Invalid input
    else
        log("Send failed: Invalid target type '" .. type(target) .. "'. Expected number or string.")
        return false
    end

    -- Send the message over rednet
    rednet.send(id, message, protocol)
    log("Sent message to ID " .. id .. " via protocol '" .. protocol .. "': " .. tostring(message))
    return true
end


-- TODO: Add query by lookup function
---------------------------------------------------------------------
-- Sends a query to a target and waits for a response (like RPC)
-- Target can be a hostname or numeric ID; includes optional timeout 
---------------------------------------------------------------------
function query(target, message, protocol)
    ensureRednet()

    local id = nil

    -- Handle direct numeric ID
    if type(target) == "number" then
        id = target

    -- Handle hostname
    elseif type(target) == "string" then
        id = resolveHostname(target)
        if not id then
            log("Query failed: Could not resolve hostname '" .. target .. "'.")
            return nil
        end

    -- Invalid target type
    else
        log("Query failed: Invalid target type '" .. type(target) .. "'. Expected number or string.")
        return nil
    end

    -- Send query
    rednet.send(id, message, protocol)
    log("Sent query to ID " .. id .. " via protocol '" .. protocol .. "': " .. tostring(message))

    -- Wait for response with optional timeout (default 5s)
    local senderID, response = rednet.receive(protocol, 5)
    if response then
        log("Received response from ID " .. senderID .. ": " .. tostring(response))
        return response
    else
        log("Query timed out waiting for reply from ID " .. id)
        return nil
    end
end

---------------------------------------------------------------------
-- Sends a message using rednet.lookup to find hosts by protocol
-- If protocol is a number, sends directly to that ID
-- If protocol is a string, looks up all hosts on that protocol
-- Returns table with {sent = count, ids = {list of IDs}}
---------------------------------------------------------------------
function sendByLookup(protocolOrId, message, messageProtocol)
    ensureRednet()

    local targetIds = {}

    -- Handle direct numeric ID
    if type(protocolOrId) == "number" then
        targetIds = {protocolOrId}
        log("sendByLookup: Using direct ID " .. protocolOrId)

    -- Handle protocol lookup
    elseif type(protocolOrId) == "string" then
        local result = rednet.lookup(protocolOrId)

        -- Handle single ID returned
        if type(result) == "number" then
            targetIds = {result}
            log("sendByLookup: Found single host for protocol '" .. protocolOrId .. "': " .. result)

        -- Handle table of IDs returned
        elseif type(result) == "table" then
            targetIds = result
            log("sendByLookup: Found " .. #targetIds .. " hosts for protocol '" .. protocolOrId .. "'")

        -- No hosts found
        else
            log("sendByLookup: No hosts found for protocol '" .. protocolOrId .. "'")
            return {sent = 0, ids = {}}
        end

    -- Invalid input
    else
        log("sendByLookup failed: Invalid protocolOrId type '" .. type(protocolOrId) .. "'. Expected number or string.")
        return {sent = 0, ids = {}}
    end

    -- Send to all target IDs
    local sentCount = 0
    local sentIds = {}

    for _, id in ipairs(targetIds) do
        rednet.send(id, message, messageProtocol or "")
        log("Sent message to ID " .. id .. " via protocol '" .. (messageProtocol or "") .. "': " .. tostring(message))
        sentCount = sentCount + 1
        table.insert(sentIds, id)
    end

    return {sent = sentCount, ids = sentIds}
end

-- TODO Remove?
local function getSanitized()
    return {
        send = send,
        query = query,
        sendByLookup = sendByLookup
    }
end

---------------------------------------------------------------------
-- Return all publicly available functions in this module
-- So other scripts can use them via `require`
---------------------------------------------------------------------
return {
    init = init,
    openRednet = openRednet,
    closeRednet = closeRednet,
    requestNewDNS = requestNewDNS,
    resolveHostname = resolveHostname,
    send = send,
    query = query,
    sendByLookup = sendByLookup
}


