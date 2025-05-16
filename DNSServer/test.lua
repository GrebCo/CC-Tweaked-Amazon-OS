
local FILENAME = "hosts.json"

--- Sample data
local hosts = {
  { hostname = "storage", id = 3, protocol = "storageNet" },
  { hostname = "router", id = 5, protocol = "net" },
}

-- Save table to JSON file
local function saveHosts(data)
  local file = fs.open(FILENAME, "w")
  if not file then
    error("Failed to open file for writing: " .. FILENAME)
  end
  file.write(textutils.serializeJSON(data))
  file.close()
end

-- Load table from JSON file
local function loadHosts()
  if not fs.exists(FILENAME) then
    return nil, "File not found"
  end

  local file = fs.open(FILENAME, "r")
  local contents = file.readAll()
  file.close()

  local data = textutils.unserializeJSON(contents)
  return data
end

-- Example usage
saveHosts(hosts)