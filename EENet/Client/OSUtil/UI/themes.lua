-- themes.lua
-- Built-in theme pack for UI.lua palette-based theme system
-- Usage:
--   local ui = dofile("UI.lua")
--   local registerThemes = dofile("themes.lua")
--   ui.init(context)
--   registerThemes(ui)  -- registers themes on the passed-in ui
--   ui.setTheme("catppuccin")  -- activate a theme

return function(UI)
    -- Safety: ensure theme system exists
    if not (UI and UI.registerTheme and UI.setTheme) then
        error("themes.lua: UI theme system not found. Make sure UI.lua exposes registerTheme/setTheme.")
    end

    ----------------------------------------------------------------------
    -- CATPPUCCIN MOCHA
    ----------------------------------------------------------------------
    UI.registerTheme("catppuccin", {
        roles = {
            background = colors.black,
            text = colors.white,
            textDim = colors.lightGray,
            textMuted = colors.lightGray,

            surface = colors.gray,
            surfaceAlt = colors.brown,
            surfaceAlt2 = colors.black,
            border = colors.gray,

            headerBg = colors.brown,
            headerText = colors.white,

            accent = colors.blue,
            accentText = colors.black,

            interactive = colors.brown,           -- Darker base fill (Overlay0)
            interactiveHover = colors.blue,       -- Accent state
            interactiveActive = colors.cyan,      -- Accent state
            interactiveDisabled = colors.gray,
            interactiveText = colors.white,       -- White text on dark brown

            success = colors.lime,
            error = colors.red,
            warning = colors.yellow,
            info = colors.lightBlue,
            selection = colors.blue
        },
        palette = {
            [colors.black] = 0x1E1E2E,      -- Base
            [colors.white] = 0xCDD6F4,      -- Text
            [colors.gray] = 0x313244,       -- Surface0
            [colors.lightGray] = 0xBAC2DE,  -- Subtext1
            [colors.blue] = 0x89B4FA,       -- Blue
            [colors.lightBlue] = 0x89DCEB,  -- Sky
            [colors.cyan] = 0x74C7EC,       -- Sapphire
            [colors.lime] = 0xA6E3A1,       -- Green
            [colors.red] = 0xF38BA8,        -- Red
            [colors.yellow] = 0xF9E2AF,     -- Yellow
            [colors.orange] = 0xFAB387,     -- Peach
            [colors.magenta] = 0xF5C2E7,    -- Pink
            [colors.purple] = 0xCBA6F7,     -- Mauve
            [colors.pink] = 0xF5E0DC,       -- Rosewater
            [colors.brown] = 0x6C7086,      -- Overlay0
            [colors.green] = 0x94E2D5       -- Teal
        }
    })

    ----------------------------------------------------------------------
    -- GRUVBOX DARK
    ----------------------------------------------------------------------
    UI.registerTheme("gruvbox", {
        roles = {
            background = colors.black,
            text = colors.white,
            textDim = colors.lightGray,
            textMuted = colors.lightGray,

            surface = colors.gray,
            surfaceAlt = colors.brown,
            surfaceAlt2 = colors.black,
            border = colors.brown,

            headerBg = colors.brown,
            headerText = colors.white,

            accent = colors.orange,
            accentText = colors.black,

            interactive = colors.blue,
            interactiveHover = colors.lightBlue,
            interactiveActive = colors.cyan,
            interactiveDisabled = colors.gray,
            interactiveText = colors.white,       -- White text on dark buttons

            success = colors.lime,
            error = colors.red,
            warning = colors.yellow,
            info = colors.lightBlue,
            selection = colors.orange
        },
        palette = {
            [colors.black] = 0x282828,      -- bg0
            [colors.white] = 0xEBDBB2,      -- fg0
            [colors.gray] = 0x3C3836,       -- bg1
            [colors.lightGray] = 0xA89984,  -- fg2
            [colors.blue] = 0x458588,       -- blue
            [colors.lightBlue] = 0x83A598,  -- aqua
            [colors.cyan] = 0x689D6A,       -- cyan
            [colors.lime] = 0xB8BB26,       -- green
            [colors.red] = 0xCC241D,        -- red
            [colors.yellow] = 0xD79921,     -- yellow
            [colors.orange] = 0xFE8019,     -- orange
            [colors.magenta] = 0xB16286,    -- magenta
            [colors.purple] = 0xD3869B,     -- purple
            [colors.pink] = 0xFB4934,       -- red bright
            [colors.brown] = 0x665C54,      -- bg3
            [colors.green] = 0x98971A       -- green dark
        }
    })

    ----------------------------------------------------------------------
    -- NORD
    ----------------------------------------------------------------------
    UI.registerTheme("nord", {
        roles = {
            background = colors.black,
            text = colors.white,
            textDim = colors.lightGray,
            textMuted = colors.lightGray,

            surface = colors.gray,
            surfaceAlt = colors.brown,
            surfaceAlt2 = colors.black,
            border = colors.gray,

            headerBg = colors.brown,
            headerText = colors.white,

            accent = colors.cyan,
            accentText = colors.black,

            interactive = colors.blue,
            interactiveHover = colors.lightBlue,
            interactiveActive = colors.cyan,
            interactiveDisabled = colors.gray,
            interactiveText = colors.white,       -- White text on icy blue

            success = colors.lime,
            error = colors.red,
            warning = colors.yellow,
            info = colors.lightBlue,
            selection = colors.blue
        },
        palette = {
            [colors.black] = 0x2E3440,      -- Polar Night 0
            [colors.white] = 0xECEFF4,      -- Snow Storm 2
            [colors.gray] = 0x3B4252,       -- Polar Night 1
            [colors.lightGray] = 0xD8DEE9,  -- Snow Storm 0
            [colors.blue] = 0x5E81AC,       -- Frost 3
            [colors.lightBlue] = 0x81A1C1,  -- Frost 2
            [colors.cyan] = 0x88C0D0,       -- Frost 1
            [colors.lime] = 0xA3BE8C,       -- Aurora Green
            [colors.red] = 0xBF616A,        -- Aurora Red
            [colors.yellow] = 0xEBCB8B,     -- Aurora Yellow
            [colors.orange] = 0xD08770,     -- Aurora Orange
            [colors.magenta] = 0xB48EAD,    -- Aurora Purple
            [colors.purple] = 0xB48EAD,     -- Aurora Purple
            [colors.pink] = 0xBF616A,       -- Aurora Red
            [colors.brown] = 0x4C566A,      -- Polar Night 3
            [colors.green] = 0x8FBCBB       -- Frost 0
        }
    })

    ----------------------------------------------------------------------
    -- DRACULA
    ----------------------------------------------------------------------
    UI.registerTheme("dracula", {
        roles = {
            background = colors.black,
            text = colors.white,
            textDim = colors.lightGray,
            textMuted = colors.lightGray,

            surface = colors.gray,
            surfaceAlt = colors.brown,
            surfaceAlt2 = colors.black,
            border = colors.gray,

            headerBg = colors.purple,
            headerText = colors.white,

            accent = colors.magenta,
            accentText = colors.black,

            interactive = colors.purple,
            interactiveHover = colors.magenta,
            interactiveActive = colors.red,
            interactiveDisabled = colors.gray,
            interactiveText = colors.black,       -- Dark text on bright purple/pink

            success = colors.lime,
            error = colors.red,
            warning = colors.yellow,
            info = colors.cyan,
            selection = colors.magenta
        },
        palette = {
            [colors.black] = 0x282A36,      -- Background
            [colors.white] = 0xF8F8F2,      -- Foreground
            [colors.gray] = 0x44475A,       -- Current Line
            [colors.lightGray] = 0x6272A4,  -- Comment
            [colors.blue] = 0xBD93F9,       -- Purple (mapped to blue)
            [colors.lightBlue] = 0x8BE9FD,  -- Cyan
            [colors.cyan] = 0x8BE9FD,       -- Cyan
            [colors.lime] = 0x50FA7B,       -- Green
            [colors.red] = 0xFF5555,        -- Red
            [colors.yellow] = 0xF1FA8C,     -- Yellow
            [colors.orange] = 0xFFB86C,     -- Orange
            [colors.magenta] = 0xFF79C6,    -- Pink
            [colors.purple] = 0xBD93F9,     -- Purple
            [colors.pink] = 0xFF79C6,       -- Pink
            [colors.brown] = 0x6272A4,      -- Comment
            [colors.green] = 0x50FA7B       -- Green
        }
    })

    ----------------------------------------------------------------------
    -- TOKYO NIGHT
    ----------------------------------------------------------------------
    UI.registerTheme("tokyonight", {
        roles = {
            background = colors.black,
            text = colors.white,
            textDim = colors.lightGray,
            textMuted = colors.lightGray,

            surface = colors.gray,
            surfaceAlt = colors.brown,
            surfaceAlt2 = colors.black,
            border = colors.gray,

            headerBg = colors.brown,
            headerText = colors.white,

            accent = colors.magenta,
            accentText = colors.white,

            interactive = colors.magenta,         -- Purple-forward main button color
            interactiveHover = colors.blue,       -- Hover state
            interactiveActive = colors.cyan,
            interactiveDisabled = colors.gray,
            interactiveText = colors.white,       -- White text on purple

            success = colors.lime,
            error = colors.red,
            warning = colors.yellow,
            info = colors.lightBlue,
            selection = colors.blue
        },
        palette = {
            [colors.black] = 0x1A1B26,      -- Background
            [colors.white] = 0xC0CAF5,      -- Foreground
            [colors.gray] = 0x24283B,       -- Background dark
            [colors.lightGray] = 0x565F89,  -- Comment
            [colors.blue] = 0x7AA2F7,       -- Blue
            [colors.lightBlue] = 0x7DCFFF,  -- Cyan
            [colors.cyan] = 0x2AC3DE,       -- Cyan light
            [colors.lime] = 0x9ECE6A,       -- Green
            [colors.red] = 0xF7768E,        -- Red
            [colors.yellow] = 0xE0AF68,     -- Yellow
            [colors.orange] = 0xFF9E64,     -- Orange
            [colors.magenta] = 0xBB9AF7,    -- Purple
            [colors.purple] = 0xBB9AF7,     -- Purple
            [colors.pink] = 0xF7768E,       -- Red (pink)
            [colors.brown] = 0x414868,      -- Dark gray
            [colors.green] = 0x73DACA       -- Teal
        }
    })

    ----------------------------------------------------------------------
    -- ONE DARK
    ----------------------------------------------------------------------
    UI.registerTheme("onedark", {
        roles = {
            background = colors.black,
            text = colors.white,
            textDim = colors.lightGray,
            textMuted = colors.lightGray,

            surface = colors.gray,
            surfaceAlt = colors.brown,
            surfaceAlt2 = colors.black,
            border = colors.gray,

            headerBg = colors.gray,
            headerText = colors.white,

            accent = colors.blue,
            accentText = colors.white,

            interactive = colors.blue,
            interactiveHover = colors.lightBlue,
            interactiveActive = colors.cyan,
            interactiveDisabled = colors.gray,
            interactiveText = colors.white,       -- White text on blue

            success = colors.lime,
            error = colors.red,
            warning = colors.yellow,
            info = colors.lightBlue,
            selection = colors.blue
        },
        palette = {
            [colors.black] = 0x282C34,      -- Background
            [colors.white] = 0xABB2BF,      -- Foreground
            [colors.gray] = 0x3E4451,       -- Gutter gray
            [colors.lightGray] = 0x5C6370,  -- Comment gray
            [colors.blue] = 0x61AFEF,       -- Blue
            [colors.lightBlue] = 0x56B6C2,  -- Cyan
            [colors.cyan] = 0x56B6C2,       -- Cyan
            [colors.lime] = 0x98C379,       -- Green
            [colors.red] = 0xE06C75,        -- Red
            [colors.yellow] = 0xE5C07B,     -- Yellow
            [colors.orange] = 0xD19A66,     -- Orange
            [colors.magenta] = 0xC678DD,    -- Purple
            [colors.purple] = 0xC678DD,     -- Purple
            [colors.pink] = 0xE06C75,       -- Red (pink)
            [colors.brown] = 0x4B5263,      -- Dark gray
            [colors.green] = 0x98C379       -- Green
        }
    })

    ----------------------------------------------------------------------
    -- SOLARIZED DARK
    ----------------------------------------------------------------------
    UI.registerTheme("solarized", {
        roles = {
            background = colors.black,
            text = colors.white,
            textDim = colors.lightGray,
            textMuted = colors.lightGray,

            surface = colors.gray,
            surfaceAlt = colors.brown,
            surfaceAlt2 = colors.black,
            border = colors.brown,

            headerBg = colors.brown,
            headerText = colors.white,

            accent = colors.orange,
            accentText = colors.black,

            interactive = colors.blue,
            interactiveHover = colors.lightBlue,
            interactiveActive = colors.cyan,
            interactiveDisabled = colors.gray,
            interactiveText = colors.white,       -- White text on blue

            success = colors.lime,
            error = colors.red,
            warning = colors.yellow,
            info = colors.lightBlue,
            selection = colors.blue
        },
        palette = {
            [colors.black] = 0x002B36,      -- Base03 (background)
            [colors.white] = 0x839496,      -- Base0 (body text)
            [colors.gray] = 0x073642,       -- Base02 (background highlights)
            [colors.lightGray] = 0x586E75,  -- Base01 (comments)
            [colors.blue] = 0x268BD2,       -- Blue
            [colors.lightBlue] = 0x2AA198,  -- Cyan
            [colors.cyan] = 0x2AA198,       -- Cyan
            [colors.lime] = 0x859900,       -- Green
            [colors.red] = 0xDC322F,        -- Red
            [colors.yellow] = 0xB58900,     -- Yellow
            [colors.orange] = 0xCB4B16,     -- Orange
            [colors.magenta] = 0xD33682,    -- Magenta
            [colors.purple] = 0x6C71C4,     -- Violet
            [colors.pink] = 0xD33682,       -- Magenta
            [colors.brown] = 0x657B83,      -- Base00
            [colors.green] = 0x859900       -- Green
        }
    })

    ----------------------------------------------------------------------
    -- MONOKAI
    ----------------------------------------------------------------------
    UI.registerTheme("monokai", {
        roles = {
            background = colors.black,
            text = colors.white,
            textDim = colors.lightGray,
            textMuted = colors.lightGray,

            surface = colors.gray,
            surfaceAlt = colors.brown,
            surfaceAlt2 = colors.black,
            border = colors.gray,

            headerBg = colors.brown,
            headerText = colors.white,

            accent = colors.orange,
            accentText = colors.black,

            interactive = colors.lime,            -- High-sat green primary
            interactiveHover = colors.orange,     -- Hover state
            interactiveActive = colors.red,       -- Active/danger
            interactiveDisabled = colors.gray,
            interactiveText = colors.black,       -- Dark text on bright green

            success = colors.lime,
            error = colors.red,
            warning = colors.yellow,
            info = colors.lightBlue,
            selection = colors.purple             -- Purple selection highlight
        },
        palette = {
            [colors.black] = 0x272822,      -- Background
            [colors.white] = 0xF8F8F2,      -- Foreground
            [colors.gray] = 0x3E3D32,       -- Selection
            [colors.lightGray] = 0x75715E,  -- Comment
            [colors.blue] = 0x66D9EF,       -- Cyan/Blue
            [colors.lightBlue] = 0x66D9EF,  -- Cyan
            [colors.cyan] = 0x66D9EF,       -- Cyan
            [colors.lime] = 0xA6E22E,       -- Green
            [colors.red] = 0xF92672,        -- Red/Pink
            [colors.yellow] = 0xE6DB74,     -- Yellow
            [colors.orange] = 0xFD971F,     -- Orange
            [colors.magenta] = 0xF92672,    -- Pink
            [colors.purple] = 0xAE81FF,     -- Purple
            [colors.pink] = 0xF92672,       -- Pink
            [colors.brown] = 0x49483E,      -- Dark gray
            [colors.green] = 0xA6E22E       -- Green
        }
    })

    ----------------------------------------------------------------------
    -- MATERIAL DARK
    ----------------------------------------------------------------------
    UI.registerTheme("material", {
        roles = {
            background = colors.black,
            text = colors.white,
            textDim = colors.lightGray,
            textMuted = colors.lightGray,

            surface = colors.gray,
            surfaceAlt = colors.brown,
            surfaceAlt2 = colors.black,
            border = colors.gray,

            headerBg = colors.brown,
            headerText = colors.white,

            accent = colors.cyan,
            accentText = colors.black,

            interactive = colors.blue,            -- Cool blue theme
            interactiveHover = colors.lightBlue,
            interactiveActive = colors.cyan,
            interactiveDisabled = colors.gray,
            interactiveText = colors.white,       -- White text on blue

            success = colors.lime,
            error = colors.red,
            warning = colors.yellow,
            info = colors.lightBlue,
            selection = colors.cyan               -- Lean into cyan
        },
        palette = {
            [colors.black] = 0x212121,      -- Background
            [colors.white] = 0xEEFFFF,      -- Foreground
            [colors.gray] = 0x2C2C2C,       -- Surface
            [colors.lightGray] = 0x545454,  -- Comment
            [colors.blue] = 0x82AAFF,       -- Blue
            [colors.lightBlue] = 0x89DDFF,  -- Cyan
            [colors.cyan] = 0x89DDFF,       -- Cyan
            [colors.lime] = 0xC3E88D,       -- Green
            [colors.red] = 0xF07178,        -- Red
            [colors.yellow] = 0xFFCB6B,     -- Yellow
            [colors.orange] = 0xF78C6C,     -- Orange
            [colors.magenta] = 0xC792EA,    -- Purple
            [colors.purple] = 0xC792EA,     -- Purple
            [colors.pink] = 0xFF5370,       -- Pink
            [colors.brown] = 0x3B3B3B,      -- Dark surface
            [colors.green] = 0xC3E88D       -- Green
        }
    })

    ----------------------------------------------------------------------
    -- ROSÉ PINE
    ----------------------------------------------------------------------
    UI.registerTheme("rosepine", {
        roles = {
            background = colors.black,
            text = colors.white,
            textDim = colors.lightGray,
            textMuted = colors.lightGray,

            surface = colors.gray,
            surfaceAlt = colors.brown,
            surfaceAlt2 = colors.black,
            border = colors.gray,

            headerBg = colors.brown,
            headerText = colors.white,

            accent = colors.orange,
            accentText = colors.black,

            interactive = colors.orange,          -- Rose accent (EbbCBa)
            interactiveHover = colors.magenta,    -- Lavender/Iris
            interactiveActive = colors.red,       -- Love
            interactiveDisabled = colors.gray,
            interactiveText = colors.black,       -- Dark text on bright rose

            success = colors.lime,
            error = colors.red,
            warning = colors.yellow,
            info = colors.lightBlue,
            selection = colors.purple
        },
        palette = {
            [colors.black] = 0x191724,      -- Base
            [colors.white] = 0xE0DEF4,      -- Text
            [colors.gray] = 0x1F1D2E,       -- Surface
            [colors.lightGray] = 0x6E6A86,  -- Muted
            [colors.blue] = 0x9CCFD8,       -- Foam
            [colors.lightBlue] = 0x9CCFD8,  -- Foam
            [colors.cyan] = 0x31748F,       -- Pine
            [colors.lime] = 0x9CCFD8,       -- Foam (green-ish)
            [colors.red] = 0xEB6F92,        -- Love
            [colors.yellow] = 0xF6C177,     -- Gold
            [colors.orange] = 0xEBBCBA,     -- Rose
            [colors.magenta] = 0xC4A7E7,    -- Iris
            [colors.purple] = 0xC4A7E7,     -- Iris
            [colors.pink] = 0xEB6F92,       -- Love
            [colors.brown] = 0x403D52,      -- Overlay
            [colors.green] = 0x31748F       -- Pine
        }
    })

    ----------------------------------------------------------------------
    -- EVERFOREST
    ----------------------------------------------------------------------
    UI.registerTheme("everforest", {
        roles = {
            background = colors.black,
            text = colors.white,
            textDim = colors.lightGray,
            textMuted = colors.lightGray,

            surface = colors.gray,
            surfaceAlt = colors.brown,
            surfaceAlt2 = colors.black,
            border = colors.brown,

            headerBg = colors.brown,
            headerText = colors.white,

            accent = colors.lime,
            accentText = colors.black,

            interactive = colors.lime,
            interactiveHover = colors.green,
            interactiveActive = colors.cyan,
            interactiveDisabled = colors.gray,
            interactiveText = colors.black,       -- Dark text on bright green

            success = colors.lime,
            error = colors.red,
            warning = colors.yellow,
            info = colors.lightBlue,
            selection = colors.lime
        },
        palette = {
            [colors.black] = 0x2B3339,      -- Background
            [colors.white] = 0xD3C6AA,      -- Foreground
            [colors.gray] = 0x323C41,       -- Surface
            [colors.lightGray] = 0x859289,  -- Comment
            [colors.blue] = 0x7FBBB3,       -- Blue
            [colors.lightBlue] = 0x83C092,  -- Aqua
            [colors.cyan] = 0x83C092,       -- Aqua
            [colors.lime] = 0xA7C080,       -- Green
            [colors.red] = 0xE67E80,        -- Red
            [colors.yellow] = 0xDBBC7F,     -- Yellow
            [colors.orange] = 0xE69875,     -- Orange
            [colors.magenta] = 0xD699B6,    -- Purple
            [colors.purple] = 0xD699B6,     -- Purple
            [colors.pink] = 0xE67E80,       -- Red (pink)
            [colors.brown] = 0x503946,      -- Dark brown
            [colors.green] = 0xA7C080       -- Green
        }
    })

    ----------------------------------------------------------------------
    -- AYU DARK
    ----------------------------------------------------------------------
    UI.registerTheme("ayu", {
        roles = {
            background = colors.black,
            text = colors.white,
            textDim = colors.lightGray,
            textMuted = colors.lightGray,

            surface = colors.gray,
            surfaceAlt = colors.brown,
            surfaceAlt2 = colors.black,
            border = colors.gray,

            headerBg = colors.brown,
            headerText = colors.white,

            accent = colors.orange,
            accentText = colors.black,

            interactive = colors.orange,          -- Warm amber controls
            interactiveHover = colors.yellow,     -- Hover state
            interactiveActive = colors.red,
            interactiveDisabled = colors.gray,
            interactiveText = colors.black,       -- Dark text on bright buttons

            success = colors.lime,
            error = colors.red,
            warning = colors.yellow,
            info = colors.lightBlue,
            selection = colors.orange
        },
        palette = {
            [colors.black] = 0x0A0E14,      -- Background
            [colors.white] = 0xB3B1AD,      -- Foreground
            [colors.gray] = 0x0D1016,       -- Surface
            [colors.lightGray] = 0x626A73,  -- Comment
            [colors.blue] = 0x59C2FF,       -- Blue
            [colors.lightBlue] = 0x95E6CB,  -- Cyan
            [colors.cyan] = 0x95E6CB,       -- Cyan
            [colors.lime] = 0xC2D94C,       -- Green
            [colors.red] = 0xF07178,        -- Red
            [colors.yellow] = 0xFFB454,     -- Yellow
            [colors.orange] = 0xFF8F40,     -- Orange
            [colors.magenta] = 0xD2A6FF,    -- Purple
            [colors.purple] = 0xD2A6FF,     -- Purple
            [colors.pink] = 0xF07178,       -- Red (pink)
            [colors.brown] = 0x1F2430,      -- Dark gray
            [colors.green] = 0xC2D94C       -- Green
        }
    })

    ----------------------------------------------------------------------
    -- PAPER LIGHT
    ----------------------------------------------------------------------
    UI.registerTheme("paper", {
        roles = {
            background = colors.white,
            text = colors.black,
            textDim = colors.gray,
            textMuted = colors.gray,

            surface = colors.lightGray,
            surfaceAlt = colors.gray,
            surfaceAlt2 = colors.white,
            border = colors.gray,

            headerBg = colors.lightGray,
            headerText = colors.black,

            accent = colors.blue,
            accentText = colors.white,

            interactive = colors.blue,            -- Blue buttons
            interactiveHover = colors.cyan,
            interactiveActive = colors.lime,
            interactiveDisabled = colors.lightGray,
            interactiveText = colors.white,       -- White text on blue

            success = colors.lime,
            error = colors.red,
            warning = colors.orange,
            info = colors.cyan,
            selection = colors.blue
        },
        palette = {
            [colors.white] = 0xF0F0F0,      -- Background
            [colors.black] = 0x191919,      -- Text
            [colors.lightGray] = 0x999999,  -- Surface
            [colors.gray] = 0x4C4C4C,       -- Dim text/border
            [colors.blue] = 0x3366CC,       -- Blue
            [colors.cyan] = 0x4C99B2,       -- Cyan
            [colors.lime] = 0x7FCC19,       -- Green
            [colors.red] = 0xCC4C4C,        -- Red
            [colors.orange] = 0xF2B233,     -- Orange
            [colors.yellow] = 0xDEDE6C,     -- Yellow
            [colors.lightBlue] = 0x99B2F2,  -- Light blue
            [colors.green] = 0x57A64E,      -- Green
            [colors.magenta] = 0xE57FD8,    -- Magenta
            [colors.purple] = 0xB266E5,     -- Purple
            [colors.pink] = 0xF2B2CC,       -- Pink
            [colors.brown] = 0x7F664C       -- Brown
        }
    })

    ----------------------------------------------------------------------
    -- SOLARIZED LIGHT
    ----------------------------------------------------------------------
    UI.registerTheme("solarized_light", {
        roles = {
            background = colors.white,            -- Base3
            text = colors.black,                  -- Base00
            textDim = colors.gray,
            textMuted = colors.gray,

            surface = colors.lightGray,           -- Base2
            surfaceAlt = colors.gray,
            surfaceAlt2 = colors.white,
            border = colors.gray,                 -- Base1

            headerBg = colors.lightGray,
            headerText = colors.black,

            accent = colors.orange,
            accentText = colors.white,

            interactive = colors.blue,            -- Solarized blue
            interactiveHover = colors.cyan,
            interactiveActive = colors.green,
            interactiveDisabled = colors.lightGray,
            interactiveText = colors.white,       -- White text on blue

            success = colors.green,
            error = colors.red,
            warning = colors.yellow,
            info = colors.cyan,
            selection = colors.blue
        },
        palette = {
            [colors.white] = 0xFDF6E3,      -- Base3 (background)
            [colors.lightGray] = 0xEEE8D5,  -- Base2 (background highlights)
            [colors.gray] = 0x93A1A1,       -- Base1 (comments/secondary)
            [colors.black] = 0x657B83,      -- Base00 (body text)
            [colors.blue] = 0x268BD2,       -- Blue
            [colors.cyan] = 0x2AA198,       -- Cyan
            [colors.green] = 0x859900,      -- Green
            [colors.red] = 0xDC322F,        -- Red
            [colors.yellow] = 0xB58900,     -- Yellow
            [colors.orange] = 0xCB4B16,     -- Orange
            [colors.magenta] = 0xD33682,    -- Magenta
            [colors.purple] = 0x6C71C4,     -- Violet
            [colors.lime] = 0x859900,       -- Green (lime)
            [colors.pink] = 0xD33682,       -- Magenta
            [colors.brown] = 0x586E75,      -- Base01
            [colors.lightBlue] = 0x2AA198   -- Cyan
        }
    })

    ----------------------------------------------------------------------
    -- GRUVBOX LIGHT
    ----------------------------------------------------------------------
    UI.registerTheme("gruvbox_light", {
        roles = {
            background = colors.white,
            text = colors.black,
            textDim = colors.gray,
            textMuted = colors.gray,

            surface = colors.lightGray,
            surfaceAlt = colors.brown,
            surfaceAlt2 = colors.white,
            border = colors.brown,

            headerBg = colors.brown,
            headerText = colors.black,

            accent = colors.orange,
            accentText = colors.black,

            interactive = colors.green,           -- Green buttons
            interactiveHover = colors.orange,
            interactiveActive = colors.red,
            interactiveDisabled = colors.lightGray,
            interactiveText = colors.black,       -- Black text on bright buttons

            success = colors.green,
            error = colors.red,
            warning = colors.orange,
            info = colors.blue,
            selection = colors.orange
        },
        palette = {
            [colors.white] = 0xFBF1C7,      -- bg0 light
            [colors.lightGray] = 0xEBDBB2,  -- bg1 light
            [colors.gray] = 0x928374,       -- gray
            [colors.black] = 0x3C3836,      -- fg0 light
            [colors.brown] = 0xA89984,      -- bg3 light
            [colors.green] = 0x79740E,      -- green dark
            [colors.lime] = 0x98971A,       -- green
            [colors.orange] = 0xAF3A03,     -- orange dark
            [colors.red] = 0x9D0006,        -- red dark
            [colors.yellow] = 0xB57614,     -- yellow dark
            [colors.blue] = 0x076678,       -- blue dark
            [colors.lightBlue] = 0x427B58,  -- aqua dark
            [colors.cyan] = 0x427B58,       -- aqua dark
            [colors.purple] = 0x8F3F71,     -- purple dark
            [colors.magenta] = 0x8F3F71,    -- purple dark
            [colors.pink] = 0xCC241D        -- red
        }
    })
end
