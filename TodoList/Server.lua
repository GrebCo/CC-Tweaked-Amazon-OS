local TODOFILE = "todolist.dat"
local PROTOCOL = "EETodo"

local todos = {}
-- format will be {text = "task description", done = false}

local function loadState(path)
    if not fs.exists(path) then
        print("No existing file, starting fresh")
        return {}
    end

    local file = fs.open(path, "r")
    if not file then
        print("Error: Could not open file")
        return {}
    end

    local content = file.readAll()
    file.close()

    local success, data = pcall(textutils.unserialize, content)
    if success and type(data) == "table" then
        print("Loaded " .. #data .. " todos from disk")
        return data
    end

    print("Error: Could not parse state file")
    return {}
end


local function saveState(path, state)
    -- Use Lua serialization instead of JSON for reliability
    local serialized = textutils.serialize(state)

    local file = fs.open(path, "w")
    if not file then
        print("Error: Could not open file for writing")
        return
    end

    file.write(serialized)
    file.close()
    print("Saved " .. #state .. " todos to disk")
end

function openRednet()
    local modem = peripheral.find("modem")
    if modem then
        rednet.open(peripheral.getName(modem))
        print("Rednet opened on modem: " .. peripheral.getName(modem))
    else
        error("No modem found! Please attach a wired or wireless modem.")
    end
end

local function addTodoItem(item)
    table.insert(todos, item)
    saveState(TODOFILE, todos)
end

local function removeTodoItem(index)
    table.remove(todos, index)
    saveState(TODOFILE, todos)
end

local function modifyTodoItem(index, newItem)
    todos[index] = newItem
    saveState(TODOFILE, todos)
end

local function broadcastTodos()
    rednet.broadcast({request = "updated", item = todos}, PROTOCOL)
end

local function init()
    openRednet()
    rednet.host(PROTOCOL, "EETodoServer")
    todos = loadState(TODOFILE) or {}
    print("EEtodo Server is initialized.")
end

local function run()
    while true do
        local senderID, message = rednet.receive(PROTOCOL, 10)

        if not senderID or type(message) ~= "table" then --make sure the message is validish
            goto continue
        end

        if message.request == "add" then
            addTodoItem(message.item)
            broadcastTodos()
            print("Added new todo item from client " .. tostring(senderID))
        elseif message.request == "modify" then
            modifyTodoItem(message.index, message.item)
            broadcastTodos()
            print("Modified todo item from client " .. tostring(senderID))
        elseif message.request == "remove" then
            removeTodoItem(message.index)
            broadcastTodos()
            print("Removed todo item from client " .. tostring(senderID))
        elseif message.request == "fetch" then
            --rednet.send(senderID, {request = "fetchResponse", item = todos }, PROTOCOL)
            --print("Sent todo list to client " .. tostring(senderID))
            broadcastTodos()
        else
            print("[WARNING] Unknown request type: " .. tostring(message.request))
        end
        ::continue::
    end
end

init()
run()




