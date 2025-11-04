local enchant = {}

local utils = require("utils")
local me_utils = require("me_utils")
local actions = require("actions")

function enchant.apparatus_list(apparatName)
  return utils.safeList(apparatName)
end

function enchant.center_item_name(apparatName)
  local inv = enchant.apparatus_list(apparatName)
  if inv[1] then return inv[1].name, inv[1].count end
  local c, last = 0, nil
  for _, st in pairs(inv) do
    c = c + 1
    last = st
  end
  if c == 1 and last then return last.name, last.count end
  return nil, 0
end

function enchant.item_has_tag(me, itemName, tagNoHash)
  local ok, data = pcall(function() return me.getItem({ name = itemName }) end)
  if not ok or not data or not data.tags then return false end
  local needle = tagNoHash
  for _, t in ipairs(data.tags) do
    if t:find(needle, 1, true) then return true end
  end
  return false
end

function enchant.enchant_once(me, apparatName, recipe, resolved, pedNames, watchdogSeconds, autoPlaceReagentWhenSafe)
  local needItem, needTag
  if type(recipe.reagent) == "table" and recipe.reagent.item then
    needItem = recipe.reagent.item
  elseif type(recipe.reagent) == "table" and recipe.reagent.tag then
    needTag = recipe.reagent.tag:gsub("^#", "")
  end

  if autoPlaceReagentWhenSafe and needItem then
    if me_utils.meHas(me, needItem, 1) then
      me_utils.meExport(me, needItem, 1, apparatName)
      sleep(0.2)
    end
  end

  local center, _ = enchant.center_item_name(apparatName)
  if needItem then
    if center ~= needItem then
      term.setTextColor(colors.yellow)
      print("Place reagent '" .. needItem .. "' in the apparatus center, then press Enter.")
      term.setTextColor(colors.lime)
      write("> ")
      term.setTextColor(colors.white)
      read()
      center, _ = enchant.center_item_name(apparatName)
      if center ~= needItem then
        term.setTextColor(colors.red)
        print("Center item mismatch. Aborting.")
        term.setTextColor(colors.white)
        return false
      end
    end
  elseif needTag then
    if not center or not enchant.item_has_tag(me, center, needTag) then
      term.setTextColor(colors.yellow)
      print("Place a reagent matching tag '" .. needTag .. "' in the center, then press Enter.")
      term.setTextColor(colors.lime)
      write("> ")
      term.setTextColor(colors.white)
      read()
      center, _ = enchant.center_item_name(apparatName)
      if not center or not enchant.item_has_tag(me, center, needTag) then
        term.setTextColor(colors.red)
        print("Center item does not match required tag. Aborting.")
        term.setTextColor(colors.white)
        return false
      end
    end
  else
    term.setTextColor(colors.yellow)
    print("No specific reagent required. Press Enter to proceed.")
    term.setTextColor(colors.lime)
    write("> ")
    term.setTextColor(colors.white)
    read()
  end

  local ok, badIdx, want = actions.verifyPedestalsExact(pedNames, resolved.ped)
  if not ok then
    term.setTextColor(colors.red)
    print("Pedestal " .. badIdx .. " missing " .. tostring(want))
    term.setTextColor(colors.white)
    return false
  end

  write("  Enchanting...")
  local t0 = os.clock()
  local lastCenter = center
  while true do
    local cur, cnt = enchant.center_item_name(apparatName)
    if cur and cur ~= lastCenter then
      pcall(function() me.importItem({ name = cur, count = cnt }, apparatName) end)
      print(" done.")
      return true
    end
    if os.clock() - t0 > watchdogSeconds then
      term.setTextColor(colors.red)
      print("\n[Enchant] Timeout. Aborting.")
      term.setTextColor(colors.white)
      utils.blink(4, "bottom")
      me_utils.meImportAll(me, apparatName)
      return false
    end
    sleep(0.5)
  end
end

function enchant.mode_enchant(me, apparatName, map, encByName, placeDelay, watchdogSeconds, autoPlaceReagentWhenSafe)
  if not apparatName or #map.apparat == 0 then
    term.setTextColor(colors.red)
    print("Enchanting not ready. Ensure apparatus exists and calibration completed for its pedestals.")
    term.setTextColor(colors.white)
    return
  end
  term.setTextColor(colors.cyan)
  print("Enchant mode. Type recipe (partial ok) and optional count, or 'back'.")
  term.setTextColor(colors.white)

  while true do
    term.setTextColor(colors.lime)
    write("> ")
    term.setTextColor(colors.white)
    local line = read()
    if line == "back" then return end
    local w = {}
    for s in line:gmatch("%S+") do
      table.insert(w, s)
    end
    local q = (w[1] or ""):lower():gsub("_", " ")
    local n = tonumber(w[2]) or 1

    local chosen = encByName[q] or (function()
      local matches = {}
      for k, v in pairs(encByName) do
        if k:find(q, 1, true) then
          table.insert(matches, { k = k, v = v })
        end
      end
      if #matches == 0 then
        return nil
      elseif #matches == 1 then
        return matches[1].v
      else
        term.setTextColor(colors.yellow)
        print("Matches:")
        term.setTextColor(colors.white)
        for i, m in ipairs(matches) do
          print("  " .. i .. ". " .. m.k)
        end
        term.setTextColor(colors.lime)
        write("> pick #: ")
        term.setTextColor(colors.white)
        local c = tonumber(read()) or 1
        return matches[c] and matches[c].v or nil
      end
    end)()

    if not chosen then
      term.setTextColor(colors.red)
      print("No matching enchanting recipe.")
      term.setTextColor(colors.white)
    else
      if type(chosen) == "table" and chosen[1] and chosen[1].result then
        term.setTextColor(colors.yellow)
        print("Multiple variants:")
        term.setTextColor(colors.white)
        for i, r in ipairs(chosen) do
          local rj = me_utils.meResolve(me, r.reagent) or "unknown"
          print("  " .. i .. ". reagent=" .. tostring(rj))
        end
        term.setTextColor(colors.lime)
        write("> pick #: ")
        term.setTextColor(colors.white)
        local c = tonumber(read()) or 1
        chosen = chosen[c] or chosen[1]
      end

      local res = actions.resolveAll(me, chosen, "enchant")
      local need = {}
      for _, x in ipairs(res.ped) do
        table.insert(need, x)
      end
      local missing = actions.checkME(me, need)
      if #missing > 0 then
        term.setTextColor(colors.red)
        print("[Enchant] Missing items:")
        for _, m in ipairs(missing) do
          print("  - " .. m)
        end
        term.setTextColor(colors.white)
      else
        for _, pname in ipairs(map.apparat) do
          me_utils.meImportAll(me, pname)
        end
        for i, name in ipairs(res.ped) do
          if map.apparat[i] then
            me_utils.meExport(me, name, 1, map.apparat[i])
            sleep(placeDelay)
          end
        end

        for i = 1, n do
          print("Cycle " .. i .. "/" .. n .. "...")
          local ok = enchant.enchant_once(me, apparatName, chosen, res, map.apparat, watchdogSeconds, autoPlaceReagentWhenSafe)
          if not ok then
            term.setTextColor(colors.red)
            print("Stopping batch due to failure.")
            term.setTextColor(colors.white)
            break
          end
        end
        for _, pname in ipairs(map.apparat) do
          me_utils.meImportAll(me, pname)
        end
        me_utils.meImportAll(me, apparatName)
        print("Enchant job complete.")
      end
    end
  end
end

return enchant
