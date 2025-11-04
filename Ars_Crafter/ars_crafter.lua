--[[ ====================================================================
  Ars Nouveau Master: Calibration + Imbuement + Enchanting (Refactored)
==================================================================== ]]--

-- ============================== CONFIG ==============================
local CFG = {
  placeDelay = 0.10,
  startDelay = 0.50,
  checkInterval = 0.50,
  watchdogSeconds = 30,
  alertSide = "bottom",
  files = {
    imbuements = "/imbuements.json",
    enchantments = "/enchantments.json",
    pedestalMap = "/pedestal_map.json",
  },
  enchant = {
    autoPlaceReagentWhenSafe = false,
  }
}

-- ========================= LIBS & UTILS =========================
local utils = require("utils")
local ui = require("ui")
local calibration = require("calibration")
local recipes = require("recipes")
local imbue = require("imbue")
local enchant = require("enchant")

-- ========================= PERIPHERALS ========================
local peripherals = utils.findPeripherals({
  ["ars_nouveau:imbuement_chamber"] = true,
  ["ars_nouveau:enchanting_apparatus"] = true,
  ["ars_nouveau:arcane_pedestal"] = true,
  ["me_bridge"] = true,
})

local meName = (peripherals["me_bridge"] or {})[1]
local altarName = (peripherals["ars_nouveau:imbuement_chamber"] or {})[1]
local apparatName = (peripherals["ars_nouveau:enchanting_apparatus"] or {})[1]
local allPedestals = peripherals["ars_nouveau:arcane_pedestal"] or {}
table.sort(allPedestals)

if not meName then error("No ME bridge found on network!") end

local me = peripheral.wrap(meName)

term.setTextColor(colors.green)
print("[Connected] ME Bridge: " .. meName)
if altarName then print("[Connected] Imbuement Chamber: " .. altarName) end
if apparatName then print("[Connected] Enchanting Apparatus: " .. apparatName) end
term.setTextColor(colors.white)

-- ======================= LOAD DATA =====================
local imbByName, encByName = recipes.load(CFG.files.imbuements, CFG.files.enchantments)
local map = utils.loadJSON(CFG.files.pedestalMap) or { altar = {}, apparat = {} }

-- =============================== MENU ===============================
local function mainMenu()
  local c = ui.mainMenu()
  if c == "1" or c == "calibrate" then
    calibration.mode_calibrate(allPedestals, CFG.files.pedestalMap)
    map = utils.loadJSON(CFG.files.pedestalMap) or { altar = {}, apparat = {} } -- Reload map
  elseif c == "2" or c == "imbue" then
    map = utils.loadJSON(CFG.files.pedestalMap) or map -- Reload map
    imbue.mode_imbue(me, altarName, map, imbByName, CFG.placeDelay, CFG.watchdogSeconds)
  elseif c == "3" or c == "enchant" then
    map = utils.loadJSON(CFG.files.pedestalMap) or map -- Reload map
    enchant.mode_enchant(me, apparatName, map, encByName, CFG.placeDelay, CFG.watchdogSeconds, CFG.enchant.autoPlaceReagentWhenSafe)
  elseif c == "4" or c == "quit" then
    return false
  else
    print("Unknown option.")
  end
  return true
end

while mainMenu() do end
print("Goodbye.")