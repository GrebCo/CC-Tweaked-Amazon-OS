-- themes.lua
-- Additional built-in themes for UI.lua v2 theme system
-- Usage:
--   local ui = dofile("UI.lua")
--   dofile("themes.lua")(ui)  -- registers themes on the passed-in ui

return function(UI)
  -- Safety: ensure theme system exists
  if not (UI and UI.registerTheme and UI.setTheme) then
    error("themes.lua: UI theme system not found. Make sure UI.lua exposes registerTheme/setTheme.")
  end

  ----------------------------------------------------------------------
  -- LIGHT
  ----------------------------------------------------------------------
  UI.registerTheme("light", {
    -- Semantic
    primary   = colors.lightBlue,
    secondary = colors.cyan,
    success   = colors.lime,
    warning   = colors.yellow,
    danger    = colors.red,
    info      = colors.blue,

    -- Base
    background    = colors.white,
    surface       = colors.lightGray,
    text          = colors.black,
    textSecondary = colors.gray,
    border        = colors.gray,

    -- Elements
    button = {
      bg = colors.lightBlue,
      fg = colors.black,
      colorPressed = colors.cyan,
      bgDisabled = colors.lightGray
    },
    label = { fg = colors.black, bg = colors.white },
    textfield = { bg = colors.lightGray, fg = colors.black, bgActive = colors.white },
    checkbox = { fg = colors.black, bg = colors.white, checked = colors.lime },
    terminal = { bg = colors.white, fg = colors.black, prompt = colors.blue, spinner = colors.cyan },
    rectangle = { bg = colors.white, fg = colors.black },
    animatedLabel = { fg = colors.black, bg = colors.white },

    -- DataDisplay
    progressBar = { fg = colors.black, bg = colors.lightGray, fillColor = colors.blue },
    gauge       = { fg = colors.black, bg = colors.white, lowColor = colors.red, medColor = colors.yellow, highColor = colors.lime },
    statPanel   = { fg = colors.black, bg = colors.white, labelColor = colors.blue, valueColor = colors.black },
    scrollableList = { fg = colors.black, bg = colors.white, selectedBg = colors.lightBlue },
    table = { fg = colors.black, bg = colors.white, headerBg = colors.lightGray, headerFg = colors.black, grid = colors.gray },
    barChart = { fg = colors.black, bg = colors.white, bar = colors.blue, axis = colors.gray },
    rangeBar  = { fg = colors.black, bg = colors.white, zoneLow = colors.red, zoneMed = colors.yellow, zoneHigh = colors.lime, setpoint = colors.orange },
  })

  ----------------------------------------------------------------------
  -- NORDIC (dark, cool accents)
  ----------------------------------------------------------------------
  UI.registerTheme("nordic", {
    primary   = colors.cyan,
    secondary = colors.lightBlue,
    success   = colors.lime,
    warning   = colors.yellow,
    danger    = colors.red,
    info      = colors.cyan,

    background    = colors.black,
    surface       = colors.gray,
    text          = colors.white,
    textSecondary = colors.lightGray,
    border        = colors.gray,

    button = {
      bg = colors.cyan, fg = colors.black,
      colorPressed = colors.lightBlue, bgDisabled = colors.gray
    },
    label = { fg = colors.cyan, bg = colors.black },
    textfield = { bg = colors.gray, fg = colors.white, bgActive = colors.lightGray },
    checkbox = { fg = colors.white, bg = colors.black, checked = colors.cyan },
    terminal = { bg = colors.black, fg = colors.white, prompt = colors.cyan, spinner = colors.lightBlue },
    rectangle = { bg = colors.black, fg = colors.white },
    animatedLabel = { fg = colors.cyan, bg = colors.black },

    progressBar = { fg = colors.white, bg = colors.gray, fillColor = colors.cyan },
    gauge       = { fg = colors.white, bg = colors.black, lowColor = colors.red, medColor = colors.yellow, highColor = colors.cyan },
    statPanel   = { fg = colors.white, bg = colors.black, labelColor = colors.cyan, valueColor = colors.white },
    scrollableList = { fg = colors.white, bg = colors.black, selectedBg = colors.cyan },
    table = { fg = colors.white, bg = colors.black, headerBg = colors.gray, headerFg = colors.white, grid = colors.lightGray },
    barChart = { fg = colors.white, bg = colors.black, bar = colors.cyan, axis = colors.lightGray },
    rangeBar  = { fg = colors.white, bg = colors.black, zoneLow = colors.red, zoneMed = colors.yellow, zoneHigh = colors.cyan, setpoint = colors.lightBlue },
  })

  ----------------------------------------------------------------------
  -- SOLARIZED DARK-ish
  ----------------------------------------------------------------------
  UI.registerTheme("solarizedDark", {
    primary   = colors.orange,
    secondary = colors.cyan,
    success   = colors.lime,
    warning   = colors.yellow,
    danger    = colors.red,
    info      = colors.blue,

    background    = colors.black,
    surface       = colors.brown,
    text          = colors.lightGray,
    textSecondary = colors.gray,
    border        = colors.brown,

    button = { bg = colors.orange, fg = colors.black, colorPressed = colors.yellow, bgDisabled = colors.gray },
    label = { fg = colors.lightGray, bg = colors.black },
    textfield = { bg = colors.brown, fg = colors.lightGray, bgActive = colors.gray },
    checkbox = { fg = colors.lightGray, bg = colors.black, checked = colors.orange },
    terminal = { bg = colors.black, fg = colors.lightGray, prompt = colors.orange, spinner = colors.cyan },
    rectangle = { bg = colors.black, fg = colors.lightGray },
    animatedLabel = { fg = colors.orange, bg = colors.black },

    progressBar = { fg = colors.black, bg = colors.brown, fillColor = colors.orange },
    gauge       = { fg = colors.lightGray, bg = colors.black, lowColor = colors.red, medColor = colors.yellow, highColor = colors.orange },
    statPanel   = { fg = colors.lightGray, bg = colors.black, labelColor = colors.cyan, valueColor = colors.lightGray },
    scrollableList = { fg = colors.lightGray, bg = colors.black, selectedBg = colors.orange },
    table = { fg = colors.lightGray, bg = colors.black, headerBg = colors.brown, headerFg = colors.lightGray, grid = colors.gray },
    barChart = { fg = colors.lightGray, bg = colors.black, bar = colors.orange, axis = colors.gray },
    rangeBar  = { fg = colors.lightGray, bg = colors.black, zoneLow = colors.red, zoneMed = colors.yellow, zoneHigh = colors.lime, setpoint = colors.orange },
  })

  ----------------------------------------------------------------------
  -- GRUVBOX DARK-ish
  ----------------------------------------------------------------------
  UI.registerTheme("gruvboxDark", {
    primary   = colors.orange,
    secondary = colors.yellow,
    success   = colors.lime,
    warning   = colors.yellow,
    danger    = colors.red,
    info      = colors.lightBlue,

    background    = colors.black,
    surface       = colors.brown,
    text          = colors.lightGray,
    textSecondary = colors.gray,
    border        = colors.brown,

    button = { bg = colors.orange, fg = colors.black, colorPressed = colors.yellow, bgDisabled = colors.gray },
    label = { fg = colors.lightGray, bg = colors.black },
    textfield = { bg = colors.brown, fg = colors.lightGray, bgActive = colors.gray },
    checkbox = { fg = colors.lightGray, bg = colors.black, checked = colors.lime },
    terminal = { bg = colors.black, fg = colors.lightGray, prompt = colors.orange, spinner = colors.lightBlue },
    rectangle = { bg = colors.black, fg = colors.lightGray },
    animatedLabel = { fg = colors.orange, bg = colors.black },

    progressBar = { fg = colors.black, bg = colors.brown, fillColor = colors.lime },
    gauge       = { fg = colors.lightGray, bg = colors.black, lowColor = colors.red, medColor = colors.yellow, highColor = colors.lime },
    statPanel   = { fg = colors.lightGray, bg = colors.black, labelColor = colors.orange, valueColor = colors.lightGray },
    scrollableList = { fg = colors.lightGray, bg = colors.black, selectedBg = colors.orange },
    table = { fg = colors.lightGray, bg = colors.black, headerBg = colors.brown, headerFg = colors.lightGray, grid = colors.gray },
    barChart = { fg = colors.lightGray, bg = colors.black, bar = colors.lime, axis = colors.gray },
    rangeBar  = { fg = colors.lightGray, bg = colors.black, zoneLow = colors.red, zoneMed = colors.yellow, zoneHigh = colors.lime, setpoint = colors.orange },
  })

  ----------------------------------------------------------------------
  -- HIGH CONTRAST (accessibility)
  ----------------------------------------------------------------------
  UI.registerTheme("highContrast", {
    primary   = colors.white,
    secondary = colors.lightGray,
    success   = colors.white,
    warning   = colors.white,
    danger    = colors.white,
    info      = colors.white,

    background    = colors.black,
    surface       = colors.black,
    text          = colors.white,
    textSecondary = colors.white,
    border        = colors.white,

    button = { bg = colors.white, fg = colors.black, colorPressed = colors.lightGray, bgDisabled = colors.gray },
    label = { fg = colors.white, bg = colors.black },
    textfield = { bg = colors.gray, fg = colors.white, bgActive = colors.lightGray },
    checkbox = { fg = colors.white, bg = colors.black, checked = colors.white },
    terminal = { bg = colors.black, fg = colors.white, prompt = colors.white, spinner = colors.white },
    rectangle = { bg = colors.black, fg = colors.white },
    animatedLabel = { fg = colors.white, bg = colors.black },

    progressBar = { fg = colors.black, bg = colors.lightGray, fillColor = colors.white },
    gauge       = { fg = colors.white, bg = colors.black, lowColor = colors.white, medColor = colors.white, highColor = colors.white },
    statPanel   = { fg = colors.white, bg = colors.black, labelColor = colors.white, valueColor = colors.white },
    scrollableList = { fg = colors.white, bg = colors.black, selectedBg = colors.white },
    table = { fg = colors.white, bg = colors.black, headerBg = colors.lightGray, headerFg = colors.black, grid = colors.white },
    barChart = { fg = colors.white, bg = colors.black, bar = colors.white, axis = colors.white },
    rangeBar  = { fg = colors.white, bg = colors.black, zoneLow = colors.white, zoneMed = colors.white, zoneHigh = colors.white, setpoint = colors.white },
  })
end
