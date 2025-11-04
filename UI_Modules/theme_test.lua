-- theme_test.lua
local ui = dofile("UI.lua")
local dataDisplay = dofile("dataDisplay.lua")
local registerThemes = dofile("themes.lua")   -- << bring in extra themes

-- Init
local context = { scenes = {}, elements = {}, functions = { log = function() end } }
ui.init(context)
dataDisplay.init(ui)

registerThemes(ui)          -- << register: light, nordic, solarizedDark, etc.
ui.setTheme("nordic")       -- << make *everything* use the Nordic palette
-- ui.markDirty()            -- (optional) if your loop doesn’t auto-rerender

ui.newScene("Themes")
ui.setScene("Themes")

ui.label({
  text = "UI Theme Demo (Nordic)",
  position = "topCenter",
  yOffset = 1
})

Danger = ui.label({
  text = "Danger",
  position = "topCenter",
  yOffset = 3,
  theme = "danger",         -- semantic color pulls from current theme (Nordic)
})

Info = ui.label({
  text = "Info",
  position = "topCenter",
  yOffset = 5,
  theme = "info",           -- semantic color pulls from current theme (Nordic)
})

ui.run()
