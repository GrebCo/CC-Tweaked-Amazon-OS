-- GitHub API-based Installer for EEBrowser
-- Uses GitHub's Contents API to recursively list and download files
-- No unzip needed; downloads exactly what you need

-- ========================================
-- CONFIGURATION - Edit these to change branch/repo
-- ========================================
local config = {
    owner = "GrebCo",
    repo = "CC-Tweaked-Amazon-OS",
    branch = "EEnetv2",  -- Change this to switch branches
    basePath = "EENet/Client",
}
-- ========================================

-- Helper function to make HTTP requests and parse JSON
local function githubRequest(path)
    local url = string.format(
        "https://api.github.com/repos/%s/%s/contents/%s?ref=%s",
        config.owner,
        config.repo,
        path,
        config.branch
    )

    local response = http.get(url)
    if not response then
        return nil, "Failed to connect to GitHub API"
    end

    local content = response.readAll()
    response.close()

    -- Parse JSON using CC:Tweaked's built-in textutils.unserialiseJSON
    local success, data = pcall(textutils.unserialiseJSON, content)
    if not success then
        return nil, "Failed to parse JSON response"
    end

    return data, nil
end

-- Helper function to create directories
local function ensureDirectory(path)
    if not fs.exists(path) then
        fs.makeDir(path)
    end
end

-- Helper function to download a file from raw GitHub URL
local function downloadFile(filePath, localPath)
    print("  Downloading: " .. filePath)

    local url = string.format(
        "https://raw.githubusercontent.com/%s/%s/%s/%s",
        config.owner,
        config.repo,
        config.branch,
        filePath
    )

    -- Create directory if it doesn't exist
    local dir = localPath:match("^(.*/)[^/]+$")
    if dir then
        ensureDirectory(dir)
    end

    -- Download using wget
    shell.run("wget", url, localPath)

    return true
end

-- Recursive function to traverse GitHub directory structure
local function traverseDirectory(githubPath, localPath, depth)
    depth = depth or 0
    if depth > 10 then return end  -- Prevent infinite recursion

    print("Scanning: " .. githubPath)

    local entries, err = githubRequest(githubPath)
    if not entries then
        print("  Error: " .. tostring(err))
        return false
    end

    -- Create local directory
    ensureDirectory(localPath)

    if type(entries) == "table" then
        -- API returns array of entries
        for _, entry in ipairs(entries) do
            if entry.type == "file" then
                local fullLocalPath = localPath .. "/" .. entry.name
                downloadFile(githubPath .. "/" .. entry.name, fullLocalPath)
            elseif entry.type == "dir" then
                -- Recurse into directories
                local newLocalPath = localPath .. "/" .. entry.name
                traverseDirectory(githubPath .. "/" .. entry.name, newLocalPath, depth + 1)
            end
        end
    end

    return true
end

-- Main installation function
local function install()
    print("=== EEBrowser API Installer ===")
    print("Owner: " .. config.owner)
    print("Repo: " .. config.repo)
    print("Branch: " .. config.branch)
    print("")

    -- Check current version
    local localVersionFile = fs.open("applications/EEBrowser/version.txt", "r")
    local currentVersion = "0"
    if localVersionFile then
        currentVersion = localVersionFile.readAll()
        localVersionFile.close()
    end

    print("Current version: " .. currentVersion)

    -- Fetch remote version
    print("Fetching remote version...")
    local remoteVersionUrl = string.format(
        "https://raw.githubusercontent.com/%s/%s/%s/%s/version.txt",
        config.owner,
        config.repo,
        config.branch,
        config.basePath .. "/applications/EEBrowser"
    )

    local response = http.get(remoteVersionUrl)
    if not response then
        print("Error: Could not fetch remote version")
        return false
    end

    local remoteVersion = response.readAll()
    response.close()

    print("Remote version: " .. remoteVersion)
    print("")

    if remoteVersion == currentVersion then
        print("Already up to date!")
        return true
    end

    -- Ask for confirmation
    print("A new version is available!")
    print("Type 'yes' to install, anything else to cancel:")
    local input = read()
    if input ~= "yes" then
        print("Installation cancelled.")
        return false
    end

    print("")
    print("Starting installation...")
    print("")

    -- Delete old files
    print("Deleting old files...")
    fs.delete("OSUtil")
    fs.delete("applications")
    print("")

    -- Create directory structure and download files
    print("Creating directory structure and downloading files...")
    print("")

    -- Start from the Client directory in the repository
    local basePath = config.basePath

    traverseDirectory(basePath .. "/OSUtil", "OSUtil", 0)
    traverseDirectory(basePath .. "/applications/EEBrowser", "applications/EEBrowser", 0)

    print("")
    print("Installation complete!")

    -- Update version file
    local versionFile = fs.open("applications/EEBrowser/version.txt", "w")
    versionFile.write(remoteVersion)
    versionFile.close()

    print("Updated to version: " .. remoteVersion)

    return true
end

-- Check if running with arguments
local args = {...}
if args[1] == "check" then
    -- Just check for updates without installing
    local localVersionFile = fs.open("applications/EEBrowser/version.txt", "r")
    local currentVersion = "0"
    if localVersionFile then
        currentVersion = localVersionFile.readAll()
        localVersionFile.close()
    end

    local remoteVersionUrl = string.format(
        "https://raw.githubusercontent.com/%s/%s/%s/%s/version.txt",
        config.owner,
        config.repo,
        config.branch,
        config.basePath .. "/applications/EEBrowser"
    )

    local response = http.get(remoteVersionUrl)
    if response then
        local remoteVersion = response.readAll()
        response.close()
        print("Current: " .. currentVersion)
        print("Remote: " .. remoteVersion)
        if remoteVersion ~= currentVersion then
            print("Update available!")
        else
            print("Already up to date")
        end
    else
        print("Could not check for updates")
    end
else
    install()
end
