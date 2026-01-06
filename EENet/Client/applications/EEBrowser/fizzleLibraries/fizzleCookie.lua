local contextTable = nil
local logger = nil
local cookiesBasePath = "/applications/EEBrowser/cookies/"
local maxSizePerDomain = 1048576 -- 1MB in bytes

-- Extract base domain from URL (e.g., "example.com/page" -> "example.com")
local function getBaseDomain(url)
    if not url then return nil end
    local domain = url:match("([^/]+)")
    return domain
end

-- Get the current domain from the renderer's current path
-- domainMode can be:
--   nil or "base" - returns base domain only (e.g., "local")
--   "full" - returns full URL path (e.g., "local/cookiedemo")
--   a custom string - returns that string as the domain
local function getCurrentDomain(domainMode)
    if not contextTable or not contextTable.fizzleLibFunctions or not contextTable.fizzleLibFunctions.mmRenderer then
        return nil
    end

    local mmRenderer = contextTable.fizzleLibFunctions.mmRenderer
    if not mmRenderer.path then
        return nil
    end

    -- The path is the cached file path, we need to get the URL from somewhere
    -- For now, we'll store it in contextTable when pages are loaded
    if contextTable.currentUrl then
        -- If domainMode is a custom string, use it directly
        if domainMode and type(domainMode) == "string" and domainMode ~= "base" and domainMode ~= "full" then
            return domainMode
        end

        -- If domainMode is "full", return the full URL path
        if domainMode == "full" then
            return contextTable.currentUrl
        end

        -- Default to base domain
        return getBaseDomain(contextTable.currentUrl)
    end

    return nil
end

-- Get the directory path for a domain's cookies
local function getDomainCookiePath(domain)
    if not domain then return nil end
    -- Sanitize domain name for file system
    local safeDomain = domain:gsub("[^%w_%-]", "_")
    return cookiesBasePath .. safeDomain .. "/"
end

-- Calculate total size of all cookies for a domain
local function getTotalDomainCookieSize(domain)
    local cookiePath = getDomainCookiePath(domain)
    if not cookiePath or not fs.exists(cookiePath) then
        return 0
    end

    local totalSize = 0
    local files = fs.list(cookiePath)
    for _, fileName in ipairs(files) do
        local filePath = fs.combine(cookiePath, fileName)
        if fs.exists(filePath) and not fs.isDir(filePath) then
            totalSize = totalSize + fs.getSize(filePath)
        end
    end

    return totalSize
end

-- Write a cookie file for the current domain
-- fileName: the name of the cookie file
-- contents: the data to write
-- domainMode (optional): "base" (default), "full", or a custom domain string
local function cookieWrite(fileName, contents, domainMode)
    local domain = getCurrentDomain(domainMode)
    if not domain then
        error("Cannot write cookie: no domain context available")
        return false
    end

    -- Sanitize filename
    local safeFileName = fileName:gsub("[^%w_%-%.]+", "_")

    local cookiePath = getDomainCookiePath(domain)
    if not cookiePath then
        error("Invalid cookie path for domain: " .. domain)
        return false
    end

    -- Ensure cookie directory exists
    if not fs.exists(cookiePath) then
        fs.makeDir(cookiePath)
    end

    local fullPath = fs.combine(cookiePath, safeFileName)

    -- Calculate size of new content
    local newSize = #tostring(contents)

    -- Get current size of this file (if it exists) to subtract from total
    local existingSize = 0
    if fs.exists(fullPath) then
        existingSize = fs.getSize(fullPath)
    end

    -- Calculate what the total would be after this write
    local currentTotal = getTotalDomainCookieSize(domain)
    local projectedTotal = currentTotal - existingSize + newSize

    -- Check if it would exceed the limit
    if projectedTotal > maxSizePerDomain then
        error(string.format("Cookie write would exceed domain size limit (%d bytes). Current: %d, Attempting to add: %d",
            maxSizePerDomain, currentTotal, newSize))
        return false
    end

    -- Write the cookie
    local file = fs.open(fullPath, "w")
    if not file then
        error("Failed to open cookie file for writing: " .. fullPath)
        return false
    end

    file.write(tostring(contents))
    file.close()

    if logger then
        logger(string.format("[cookie] Wrote cookie '%s' for domain '%s' (%d bytes)", safeFileName, domain, newSize))
    end

    return true
end

-- Read a cookie file for the current domain
-- fileName: the name of the cookie file
-- domainMode (optional): "base" (default), "full", or a custom domain string
local function cookieRead(fileName, domainMode)
    local domain = getCurrentDomain(domainMode)
    if not domain then
        error("Cannot read cookie: no domain context available")
        return nil
    end

    -- Sanitize filename
    local safeFileName = fileName:gsub("[^%w_%-%.]+", "_")

    local cookiePath = getDomainCookiePath(domain)
    if not cookiePath then
        error("Invalid cookie path for domain: " .. domain)
        return nil
    end

    local fullPath = fs.combine(cookiePath, safeFileName)

    -- Check if cookie exists
    if not fs.exists(fullPath) then
        if logger then
            logger(string.format("[cookie] Cookie '%s' not found for domain '%s'", safeFileName, domain))
        end
        return nil
    end

    -- Read the cookie
    local file = fs.open(fullPath, "r")
    if not file then
        error("Failed to open cookie file for reading: " .. fullPath)
        return nil
    end

    local contents = file.readAll()
    file.close()

    if logger then
        logger(string.format("[cookie] Read cookie '%s' for domain '%s' (%d bytes)", safeFileName, domain, #contents))
    end

    return contents
end

-- Setup function called by libraries.lua
local function setupCookie(context)
    contextTable = context
    logger = (context.functions and context.functions.log) or function() end

    local cookieLibrary = {
        cookieWrite = cookieWrite,
        cookieRead = cookieRead
    }

    return cookieLibrary
end

return setupCookie
