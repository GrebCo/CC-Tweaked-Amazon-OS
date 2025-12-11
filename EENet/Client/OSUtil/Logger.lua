local MAX_LOG_SIZE = 5000 -- max bytes before trimming
local TRIM_KEEP_LINES = 200 -- lines to keep

local ENABLE_LOG = true

-- Queue for batched logging
local logQueue = {}

local function trimLog(LOG_FILE)
    if not fs.exists(LOG_FILE) then return end
    local size = fs.getSize(LOG_FILE)
    if size <= MAX_LOG_SIZE then return end

    local file = fs.open(LOG_FILE, "r")
    local lines = {}
    local line = file.readLine()
    while line do
        table.insert(lines, line)
        line = file.readLine()
    end
    file.close()

    local start = math.max(1, #lines - TRIM_KEEP_LINES + 1)
    local trimmed = {}
    for i = start, #lines do
        table.insert(trimmed, lines[i])
    end

    file = fs.open(LOG_FILE, "w")
    for _, line in ipairs(trimmed) do
        file.writeLine(line)
    end
    file.close()
end

-- Immediate logging (original behavior)
local function log(msg, LOG_FILE)
    LOG_FILE = LOG_FILE or "applications/EEBrowser/logs/log.log"

    -- make sure folder exists
    local dir = fs.getDir(LOG_FILE)
    if not fs.exists(dir) then fs.makeDir(dir) end

    if ENABLE_LOG then
        trimLog(LOG_FILE)
        local file = fs.open(LOG_FILE, "a")
        if file then

            local timestamp = os.date("%Y-%m-%d %H:%M:%S")
            file.writeLine("[" .. timestamp .. "] " .. msg)

            file.close()
        else
            print("Logger failed to open file: " .. LOG_FILE)
        end
    end
end

-- Queue a log message (no I/O, just memory)
local function queue(msg, LOG_FILE)
    if ENABLE_LOG then
        LOG_FILE = LOG_FILE or "applications/EEBrowser/logs/log.log"
        local timestamp = os.date("%Y-%m-%d %H:%M:%S")
        table.insert(logQueue, {
            timestamp = timestamp,
            msg = msg,
            file = LOG_FILE
        })
    end
end

-- Push all queued messages to disk (call after rendering)
local function push()
    if not ENABLE_LOG or #logQueue == 0 then return end

    -- Group messages by file
    local fileGroups = {}
    for _, entry in ipairs(logQueue) do
        fileGroups[entry.file] = fileGroups[entry.file] or {}
        table.insert(fileGroups[entry.file], entry)
    end

    -- Write each file's messages
    for LOG_FILE, entries in pairs(fileGroups) do
        -- make sure folder exists
        local dir = fs.getDir(LOG_FILE)
        if not fs.exists(dir) then fs.makeDir(dir) end

        trimLog(LOG_FILE)
        local file = fs.open(LOG_FILE, "a")
        if file then
            for _, entry in ipairs(entries) do
                file.writeLine("[" .. entry.timestamp .. "] " .. entry.msg)
            end
            file.close()
        else
            print("Logger failed to open file: " .. LOG_FILE)
        end
    end

    -- Clear queue
    logQueue = {}
end

-- Clear queue without writing (in case you want to discard)
local function clear()
    logQueue = {}
end

return {
    log = log,      -- Immediate write
    queue = queue,  -- Add to queue
    push = push,    -- Write all queued
    clear = clear   -- Discard queue
}
