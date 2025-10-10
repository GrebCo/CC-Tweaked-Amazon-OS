local MAX_LOG_SIZE = 5000 -- max bytes before trimming
local TRIM_KEEP_LINES = 200 -- lines to keep

local ENABLE_LOG = true

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

local function log(msg, LOG_FILE)
    LOG_FILE = LOG_FILE or "logs/log.log"

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

return { log = log }
