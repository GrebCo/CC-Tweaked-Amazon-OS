local baseUrl = "https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/dev/Elliot/Ars_Crafter/"

local files = {
  "ars_crafter.lua",
  "utils.lua",
  "me_utils.lua",
  "ui.lua",
  "calibration.lua",
  "recipes.lua",
  "actions.lua",
  "imbue.lua",
  "enchant.lua"
}

for _, file in ipairs(files) do
  print("Downloading " .. file .. "...")
  local url = baseUrl .. file
  local success = http.get(url)
  if success and success.getResponseCode() == 200 then
    local content = success.readAll()
    local f = fs.open(file, "w")
    f.write(content)
    f.close()
    print("Downloaded " .. file)
  else
    print("Failed to download " .. file)
  end
end

print("Installation complete.")
