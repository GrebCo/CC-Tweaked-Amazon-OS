me = peripheral.wrap("left")
chest = peripheral.wrap("top")

direction = "top"

items = chest.list()

for i, v in pairs(items) do
    print("Importing", v.name, "count:",v.count)
    meTable = {name=v.name,count=v.count}
    me.importItem(meTable, direction)
end

