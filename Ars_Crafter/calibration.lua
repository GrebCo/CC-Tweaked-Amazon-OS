local calibration = {}

local ui = require("ui")
local utils = require("utils")

function calibration.capturePedestalOrder(prompt, expectedCount, allPedestals)
  local seenAt = {}
  local order = {}

  local function rebuildOrder()
    local tmp = {}
    for name, t in pairs(seenAt) do
      table.insert(tmp, { name = name, t = t })
    end
    table.sort(tmp, function(a, b) return a.t < b.t end)
    order = {}
    for _, v in ipairs(tmp) do
      table.insert(order, v.name)
    end
  end

  local wantStop = false

  local function scanner()
    while not wantStop do
      for _, name in ipairs(allPedestals) do
        local occupied = utils.invHasAny(name)
        if occupied and not seenAt[name] then
          seenAt[name] = os.clock()
          rebuildOrder()
        elseif (not occupied) and seenAt[name] then
          seenAt[name] = nil
          rebuildOrder()
        end
      end
      ui.drawCalibrationUI(prompt, expectedCount, order)
      sleep(0.3)
    end
  end

  local function waiter()
    read()
    wantStop = true
  end

  parallel.waitForAny(scanner, waiter)

  if expectedCount and #order ~= expectedCount then
    term.setTextColor(colors.red)
    print("\nExpected " .. expectedCount .. " pedestals, got " .. #order .. ". Restarting selection...")
    term.setTextColor(colors.white)
    sleep(1.0)
    return calibration.capturePedestalOrder(prompt, expectedCount, allPedestals)
  end
  return order
end

function calibration.mode_calibrate(allPedestals, pedestalMapFile)
  local altarOrder = calibration.capturePedestalOrder(
    "Calibration: IMBUEMENT — select pedestals for the imbuement chamber.",
    3,
    allPedestals
  )
  local apparatOrder = calibration.capturePedestalOrder(
    "Calibration: ENCHANTING — select pedestals for the enchanting apparatus.",
    nil,
    allPedestals
  )

  utils.saveJSON(pedestalMapFile, { altar = altarOrder, apparat = apparatOrder })
  term.setTextColor(colors.lime)
  print("\nCalibration complete. Saved to " .. pedestalMapFile)
  term.setTextColor(colors.white)
end

return calibration
