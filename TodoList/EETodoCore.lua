-- EETodo Client Core
-- Shared client-side state and network handling for todo clients

local todos = {}
local serverID = nil
PROTOCOL = "EETodo"

local function fetchTodos()
    rednet.send(serverID, { request = "fetch" }, PROTOCOL)
    local senderID, message = rednet.receive(PROTOCOL, 5)

    if senderID == serverID and message and message.request == "updated" and message.item then
        todos = message.item
    end
end

local function init()
    peripheral.find("modem", rednet.open)

    serverID = rednet.lookup(PROTOCOL)

    if not serverID then
        error("[ERROR] No EETodo server found.")
    end

    fetchTodos()
end

local function getTodos()
    return todos
end

local function addTodoItem(item)
    if not item or item == "" then return end
    rednet.send(serverID, { request = "add", item = item}, PROTOCOL)
end

local function modifyTodoItem(index, newItem)
    -- Optional sanity checks
    if not index or type(index) ~= "number" then return end
    if not newItem or type(newItem) ~= "table" then return end

    rednet.send(serverID, {
        request = "modify",
        index   = index,
        item    = newItem
    }, PROTOCOL)
end


local function removeTodoItem(index)
    if not index then return end
    rednet.send(serverID, { request = "remove", index = index }, PROTOCOL)
end

local function handleRednetMessage(senderId, msg, protocol)
    if protocol ~= PROTOCOL then
        return
    end

    if msg.request == "updated" and msg.item then
        todos = msg.item
    end
end

return {
    init = init,
    getTodos = getTodos,
    addTodoItem = addTodoItem,
    modifyTodoItem = modifyTodoItem,
    removeTodoItem = removeTodoItem,
    handleRednetMessage = handleRednetMessage
}


