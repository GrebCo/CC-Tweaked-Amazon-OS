local utils = {}

function utils.strTypes(name)
  local t = peripheral.getType(name)
  if type(t) == "table" then t = table.concat(t, ",") end
  return t or ""
end

function utils.findPeripherals(types)
  local found = {}
  for _, name in ipairs(peripheral.getNames()) do
    local pType = utils.strTypes(name)
    for typeName, _ in pairs(types) do
      if pType:find(typeName) then
        if not found[typeName] then found[typeName] = {} end
        table.insert(found[typeName], name)
      end
    end
  end
  return found
end

function utils.loadJSON(path)
  if not fs.exists(path) then return nil end
  local f = fs.open(path, "r")
  local txt = f.readAll()
  f.close()
  return textutils.unserializeJSON(txt)
end

function utils.saveJSON(path, tbl)
  local ok, encoded = pcall(textutils.serializeJSON, tbl, false)
  if not ok or not encoded then
    local fallback = textutils.serialize(tbl)
    encoded = fallback
      :gsub("([%w_]+)%s*=", '"%1":')
      :gsub("'", '"')
  end
  local f = fs.open(path, "w")
  f.write(encoded)
  f.close()
end

function utils.blink(times, side)
  for i = 1, times do
    redstone.setOutput(side, true)
    sleep(0.2)
    redstone.setOutput(side, false)
    sleep(0.2)
  end
end

function utils.safeList(periphName)
  local ok, inv = pcall(peripheral.call, periphName, "list")
  if ok and type(inv) == "table" then return inv end
  return {}
end

function utils.invHasAny(periphName)
  for _, st in pairs(utils.safeList(periphName)) do
    if st and st.count and st.count > 0 then return true end
  end
  return false
end

return utils
