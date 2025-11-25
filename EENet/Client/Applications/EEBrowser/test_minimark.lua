-- test_minimark.lua
-- Renders a provided MiniMark file, prints the UI registry and parsed scripts.

local mm = dofile("OSUtil/MiniMark.lua")

local FILE = arg and arg[1] or "EEBrowser/Default.txt"
local scroll = 0
local startY = 1

local function printRegistry(reg)
  print("\n--- UI Registry ---")
  for i, rec in ipairs(reg) do
    local e = rec.element or {}
    print(("[%02d] y=%d  type=%s  x=%d  width=%s  id=%s  label=%s  target=%s"):format(
      i, rec.y or -1, tostring(e.type), tonumber(e.x or -1), tostring(e.width or "-"),
      tostring(e.id or "-"), tostring(e.label or "-"), tostring(e.target or "-")
    ))
  end
end

local function printScripts(scripts)
  print("\n--- Scripts ---")
  for i, s in ipairs(scripts) do
    print(("Script %d  event=%s"):format(i, tostring(s.event or "-")))
    print(s.code)
    print(("="):rep(40))
  end
end

local function main()
  term.clear()
  term.setCursorPos(1,1)
  print("Rendering: " .. FILE)
  local reg, lastY = mm.renderPage(FILE, scroll, startY)

  printRegistry(reg)

  local scripts = mm.getScripts(FILE)
  printScripts(scripts)

  print("\nDone. Press any key to exit.")
  os.pullEvent("key")
end

main()
