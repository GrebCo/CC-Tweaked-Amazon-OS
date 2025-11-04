local actions = {}

local utils = require("utils")
local me_utils = require("me_utils")

function actions.resolveAll(me, recipe, kind)
  if kind == "imbue" then
    local input = me_utils.meResolve(me, recipe.input)
    local peds = {}
    for i, e in ipairs(recipe.pedestal_items or {}) do
      peds[i] = me_utils.meResolve(me, e)
    end
    return { input = input, ped = peds }
  else
    local reagent = me_utils.meResolve(me, recipe.reagent)
    local peds = {}
    for i, e in ipairs(recipe.pedestal_items or {}) do
      peds[i] = me_utils.meResolve(me, e)
    end
    return { reagent = reagent, ped = peds }
  end
end

function actions.checkME(me, items)
  local missing = {}
  for _, name in ipairs(items) do
    if name and not name:match("^#") then
      if not me_utils.meHas(me, name, 1) then
        table.insert(missing, name)
      end
    else
      table.insert(missing, name)
    end
  end
  return missing
end

function actions.verifyPedestalsExact(pedNames, expectedItems)
  for i, pname in ipairs(pedNames) do
    local want = expectedItems[i]
    if want then
      local ok = false
      for _, it in pairs(utils.safeList(pname)) do
        if it.name == want and it.count > 0 then
          ok = true
          break
        end
      end
      if not ok then return false, i, want end
    end
  end
  return true
end

return actions
