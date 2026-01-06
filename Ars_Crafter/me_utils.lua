local me_utils = {}

function me_utils.meHas(me, nameOrTag, count)
  local ok, res = pcall(function() return me.getItem({name=nameOrTag}) end)
  if not ok or not res then return false end
  local amt = res.amount or res.count or 0
  return amt >= (count or 1)
end

function me_utils.meResolve(me, entry)
  if type(entry) == "table" and entry.item then return entry.item end
  if type(entry) == "table" and entry.tag then
    local tag = entry.tag
    if not tag:match("^#") then tag = "#" .. tag end
    local ok, res = pcall(function() return me.getItem({name=tag}) end)
    if ok and res and res.name then return res.name end
    return entry.tag
  end
  return entry
end

function me_utils.meExport(me, name, n, targetPeriph)
  return pcall(function()
    return me.exportItem({name=name, count=n}, targetPeriph)
  end)
end

function me_utils.meImportAll(me, targetPeriph)
  local utils = require("utils")
  for _, st in pairs(utils.safeList(targetPeriph)) do
    pcall(function() me.importItem({name=st.name, count=st.count}, targetPeriph) end)
    sleep(0.05)
  end
  pcall(function() me.importItem({name="minecraft:air", count=0}, targetPeriph) end)
end

return me_utils
