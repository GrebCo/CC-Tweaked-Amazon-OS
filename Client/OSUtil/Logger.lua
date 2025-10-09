local MAX_LOG_SIZE = 5000 -- max bytes before trimming (adjust as needed)
local TRIM_KEEP_LINES = 200 -- number of most recent lines to keep

local function trimLog(LOG_FILE)
    if not fs.exists(LOG_FILE) then return end
    local size = fs.getSize(LOG_FILE)
    if size <= MAX_LOG_SIZE then return end

    -- Read the whole log and trim it
    local file = fs.open(LOG_FILE, "r")
    local lines = {}
    for line in file.readLine do
        table.insert(lines, line)
    end
    file.close()

    -- Keep only the last N lines
    local start = math.max(1, #lines - TRIM_KEEP_LINES + 1)
    local trimmed = {}
    for i = start, #lines do
        table.insert(trimmed, lines[i])
    end

    -- Rewrite the file
    file = fs.open(LOG_FILE, "w")
    for _, line in ipairs(trimmed) do
        file.writeLine(line)
    end
    file.close()
end

local function log(msg, LOG_FILE)

    LOG_FILE = LOG_FILE or "logs/log.log"

    if ENABLE_LOG then
        trimLog(LOG_FILE)
        local file = fs.open(LOG_FILE, "a")
        if file then
            file.writeLine("[" .. os.time() .. "] " .. msg)
            file.close()
        end
    end
end

return { log = log }
