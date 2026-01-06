local recipes = {}

local utils = require("utils")

function recipes.buildLookup(recipes, outputKey, stripSuffix)
  local lookup = {}
  for _, r in ipairs(recipes) do
    local s = r[outputKey] or r.output or r.result or ""
    s = s:gsub("ars_nouveau:glyph_", ""):gsub("ars_nouveau:", "")
    if stripSuffix then s = s:gsub(stripSuffix, "") end
    s = s:gsub("_", " ")
    local key = s:lower()
    if lookup[key] then
      if type(lookup[key]) ~= "table" or lookup[key][1] == nil then
        lookup[key] = { lookup[key] }
      end
      table.insert(lookup[key], r)
    else
      lookup[key] = r
    end
  end
  return lookup
end

function recipes.load(imbuementsFile, enchantmentsFile)
  local imb = utils.loadJSON(imbuementsFile) or {}
  local enc = utils.loadJSON(enchantmentsFile) or {}
  local imbByName = recipes.buildLookup(imb, "output", "_essence")
  local encByName = recipes.buildLookup(enc, "result", nil)
  return imbByName, encByName
end

return recipes
