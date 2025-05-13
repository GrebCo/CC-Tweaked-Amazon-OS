-- Default protocol used for DNS communication via rednet
local DNS_PROTOCOL = "DNS"

-- Default file where resolved DNS entries (hostname → ID) are stored
local CACHE_FILE = "dns_cache.txt"

-- Logging and output configuration flags
local ENABLE_LOG = true         -- If true, logs will be written to a file
local ENABLE_PRINT = true       -- If true, logs will be printed to the terminal
local LOG_FILE = "dns_client.log"  -- The file to which logs are written

---------------------------------------------------------------------
-- Initializes the module with custom configuration
-- Allows user to override default settings by providing a config table
---------------------------------------------------------------------
local function init(config)
    DNS_PROTOCOL     = config.DNS_PROTOCOL or DNS_PROTOCOL         -- Use custom protocol or default
    CACHE_FILE   = config.CACHE_FILE or CACHE_FILE     -- Use custom cache file or default
    ENABLE_LOG   = config.ENABLE_LOG or ENABLE_LOG     -- Override log-to-file flag
    ENABLE_PRINT = config.ENABLE_PRINT or ENABLE_PRINT -- Override terminal print flag
    LOG_FILE     = config.LOG_FILE or LOG_FILE         -- Use custom log file or default
end

---------------------------------------------------------------------
-- Logs a message to a file and/or to the terminal depending on config
-- Automatically timestamps logs when writing to file
---------------------------------------------------------------------
local function log(msg)
    -- Write to log file if enabled
    if ENABLE_LOG then
        local file = fs.open(LOG_FILE, "a") -- Open file in append mode
        if file then
            file.writeLine("[" .. os.time() .. "] " .. msg) -- Timestamped log line
            file.close()
        end
    end

    -- Print to screen if enabled
    if ENABLE_PRINT then
        print(msg)
    end
end

---------------------------------------------------------------------
-- Opens rednet networking on the first modem it finds
-- Needed before sending or receiving any messages
---------------------------------------------------------------------
function openRednet()
    peripheral.find("modem", rednet.open)  -- Automatically finds and opens a modem
    log("Rednet opened.")
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
    ensureRednet()  -- Ensure rednet is ready before sending

    -- Look up a server advertising the DNS protocol
    local serverID = rednet.lookup(DNS_PROTOCOL)
    if not serverID then
        log("DNS server not found.")
        return
    end

    -- Send request to the DNS server to get the full DNS table
    rednet.send(serverID, "get", DNS_PROTOCOL)
    log("Requesting DNS data from server...")

    -- Wait for a response for up to 5 seconds
    local senderID, response = rednet.receive(DNS_PROTOCOL, 5)
    if response then
        log("Received DNS data. Caching to file...")

        -- Write response to the local DNS cache file
        local file = fs.open(CACHE_FILE, "w")
        if file then
            file.write(response)
            file.close()
            log("DNS data cached to '" .. CACHE_FILE .. "'.")
        else
            log("Error: Could not write to cache file.")
        end

        -- Optionally print DNS data to screen/log
        log("\nDNS Data:\n" .. response)
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

        local dnsTable = {}
        -- Read each line and parse as "hostname:ID"
        for line in file.readLine do
            local name, id = string.match(line, "^(.-):(%d+)$")
            if name and id then
                dnsTable[name] = tonumber(id)
            end
        end
        file.close()
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

---------------------------------------------------------------------
-- Sends a query to a target and waits for a response (like RPC)
-- Target can be a hostname or numeric ID; includes optional timeout
---------------------------------------------------------------------
function query(target, message, protocol, timeout)
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
    local senderID, response = rednet.receive(protocol, timeout or 5)
    if response then
        log("Received response from ID " .. senderID .. ": " .. tostring(response))
        return response
    else
        log("Query timed out waiting for reply from ID " .. id)
        return nil
    end
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
    query = query
}