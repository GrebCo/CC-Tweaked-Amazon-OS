local ui = {}

function ui.drawCalibrationUI(title, expectedCount, order)
  term.setBackgroundColor(colors.black)
  term.clear()
  term.setCursorPos(1, 1)
  term.setTextColor(colors.yellow)
  print(title)
  term.setTextColor(colors.white)
  print("")
  print("Place a marker (e.g., dirt) on each intended pedestal in order.")
  print("Remove/re-add to change order. Press ENTER to confirm.\n")
  term.setTextColor(colors.cyan)
  local cap = "Current selection (" .. tostring(#order)
  if expectedCount then cap = cap .. "/" .. tostring(expectedCount) end
  cap = cap .. "):"
  print(cap)
  term.setTextColor(colors.white)
  if #order == 0 then
    print("  <none>")
  else
    for i, n in ipairs(order) do
      print(string.format("  %2d. %s", i, n))
    end
  end
  print("")
  term.setTextColor(colors.yellow)
  print("Press ENTER to confirm.")
  term.setTextColor(colors.white)
end

function ui.mainMenu()
  term.setTextColor(colors.cyan)
    print("\nArs Master — select a mode:")
  term.setTextColor(colors.white)
  print("  1) calibrate")
  print("  2) imbue")
  print("  3) enchant")
  print("  4) quit")
  term.setTextColor(colors.lime)
  write("> ")
  term.setTextColor(colors.white)
  local c = read()
  return c
end

return ui
