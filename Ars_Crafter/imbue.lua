local imbue = {}

local utils = require("utils")
local me_utils = require("me_utils")
local actions = require("actions")

function imbue.imbue_once(me, altarName, recipe, resolved, pedNames, watchdogSeconds)
  local ok, badIdx, want = actions.verifyPedestalsExact(pedNames, resolved.ped)
  if not ok then
    term.setTextColor(colors.red)
    print("[Imbue] Pedestal " .. badIdx .. " missing " .. tostring(want))
    term.setTextColor(colors.white)
    return false
  end
  sleep(0.5)
  local gem = resolved.input
  local okExp = select(1, me_utils.meExport(me, gem, 1, altarName))
  if not okExp then
    term.setTextColor(colors.red)
    print("[Imbue] Failed to export gem to altar")
    term.setTextColor(colors.white)
    return false
  end
  write("  Imbuing...")
  local t0 = os.clock()
  local started = false
  while true do
    local inv = utils.safeList(altarName)
    local cnt, last = 0, nil
    for _, st in pairs(inv) do
      cnt = cnt + 1
      last = st
    end
    if not started and cnt > 0 then started = true end
    if started and cnt == 1 and last and last.name ~= gem then
      pcall(function() me.importItem({ name = last.name, count = last.count }, altarName) end)
      print(" done.")
      return true
    end
    if os.clock() - t0 > watchdogSeconds then
      term.setTextColor(colors.red)
      print("\n[Imbue] Timeout! Aborting cycle.")
      term.setTextColor(colors.white)
      utils.blink(4, "bottom")
      me_utils.meImportAll(me, altarName)
      return false
    end
    sleep(0.5)
  end
end

function imbue.mode_imbue(me, altarName, map, imbByName, placeDelay, watchdogSeconds)
  if not altarName or #map.altar ~= 3 then
    term.setTextColor(colors.red)
    print("Imbuement not ready. Ensure chamber exists and calibration (3 pedestals) is saved.")
    term.setTextColor(colors.white)
    return
  end

  term.setTextColor(colors.cyan)
  print("Imbue mode. Type recipe (partial ok) and optional count, or 'back'.")
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

    local chosen = imbByName[q] or (function()
      local matches = {}
      for k, v in pairs(imbByName) do
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
      print("No matching imbuement recipe.")
      term.setTextColor(colors.white)
    else
      if type(chosen) == "table" and chosen[1] and chosen[1].output then
        term.setTextColor(colors.yellow)
        print("Multiple variants:")
        term.setTextColor(colors.white)
        for i, r in ipairs(chosen) do
          local inp = me_utils.meResolve(me, r.input) or "unknown"
          print("  " .. i .. ". input=" .. tostring(inp))
        end
        term.setTextColor(colors.lime)
        write("> pick #: ")
        term.setTextColor(colors.white)
        local c = tonumber(read()) or 1
        chosen = chosen[c] or chosen[1]
      end

      local res = actions.resolveAll(me, chosen, "imbue")
      local need = { res.input }
      for _, x in ipairs(res.ped) do
        table.insert(need, x)
      end
      local missing = actions.checkME(me, need)
      if #missing > 0 then
        term.setTextColor(colors.red)
        print("[Imbue] Missing items:")
        for _, m in ipairs(missing) do
          print("  - " .. m)
        end
        term.setTextColor(colors.white)
      else
        for i = 1, #map.altar do
          me_utils.meImportAll(me, map.altar[i])
        end
        for i, name in ipairs(res.ped) do
          me_utils.meExport(me, name, 1, map.altar[i])
          sleep(placeDelay)
        end

        for i = 1, n do
          print("Cycle " .. i .. "/" .. n .. "...")
          local ok = imbue.imbue_once(me, altarName, chosen, res, map.altar, watchdogSeconds)
          if not ok then
            term.setTextColor(colors.red)
            print("Stopping batch due to failure.")
            term.setTextColor(colors.white)
            break
          end
        end
        for i = 1, #map.altar do
          me_utils.meImportAll(me, map.altar[i])
        end
        print("Imbue job complete.")
      end
    end
  end
end

return imbue
