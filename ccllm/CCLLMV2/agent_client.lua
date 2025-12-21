-- CC LLM Agent Framework - Client Library
--
-- This library handles the WebSocket protocol for CC computers to communicate
-- with the orchestrator, register commands, and manage tasks.

local AgentClient = {}
AgentClient.__index = AgentClient

-- Create a new agent client instance
-- @param wsUrl: WebSocket URL (e.g., "ws://192.168.1.100:8000/ws/my_client")
-- @param clientId: Unique identifier for this client
function AgentClient.new(wsUrl, clientId)
    local self = setmetatable({}, AgentClient)

    self.wsUrl = wsUrl
    self.clientId = clientId
    self.ws = nil
    self.connected = false

    -- Command registry: command_name -> handler_function
    self.commands = {}

    -- Task tracking: task_id -> task_info
    self.tasks = {}

    -- Pending requests: request_id -> callback
    self.pendingRequests = {}

    -- Message handlers
    self.messageHandlers = {
        task_created = function(msg) self:handleTaskCreated(msg) end,
        task_update = function(msg) self:handleTaskUpdate(msg) end,
        task_completed = function(msg) self:handleTaskCompleted(msg) end,
        task_failed = function(msg) self:handleTaskFailed(msg) end,
        command_call = function(msg) self:handleCommandCall(msg) end,
        error = function(msg) self:handleError(msg) end,
        pong = function(msg) end
    }

    return self
end

-- Connect to the orchestrator
function AgentClient:connect()
    if not http or not http.websocket then
        error("WebSocket API not available")
    end

    local success, handle = pcall(http.websocket, self.wsUrl)

    if success and handle then
        self.ws = handle
        self.connected = true
        return true
    else
        print("[ERROR] Connection failed: " .. tostring(handle))
        return false
    end
end

-- Disconnect from the orchestrator
function AgentClient:disconnect()
    if self.ws then
        pcall(self.ws.close)
        self.ws = nil
    end
    self.connected = false
end

-- Register a command handler
-- @param name: Command name
-- @param handler: Function(args, taskId, callId) -> result_table or error
function AgentClient:registerCommand(name, handler)
    self.commands[name] = handler
end

-- Create a new task
-- @param taskKind: Type of task (e.g., "general_agent")
-- @param prompt: Prompt for the LLM
-- @param context: Optional context table
-- @param allowedCommands: Optional list of allowed command names
-- @param callback: Optional callback function(taskId, status)
-- @return request_id
function AgentClient:createTask(taskKind, prompt, context, allowedCommands, callback)
    local requestId = self:generateId()

    local message = {
        type = "create_task",
        request_id = requestId,
        task_kind = taskKind,
        client_id = self.clientId,
        prompt = prompt,
        context = context or {},
        allowed_commands = allowedCommands
    }

    -- Store callback if provided
    if callback then
        self.pendingRequests[requestId] = callback
    end

    self:sendMessage(message)
    return requestId
end

-- Send a command result
-- @param taskId: Task identifier
-- @param callId: Call identifier
-- @param ok: Boolean success flag
-- @param result: Result table (if ok=true)
-- @param error: Error string (if ok=false)
function AgentClient:sendCommandResult(taskId, callId, ok, result, errorMsg)
    local message = {
        type = "command_result",
        task_id = taskId,
        call_id = callId,
        ok = ok
    }

    if ok then
        message.result = result or {}
    else
        message.error = errorMsg or "Unknown error"
    end

    self:sendMessage(message)
end

-- Send a ping message
function AgentClient:sendPing()
    self:sendMessage({type = "ping"})
end

-- Send a message to the orchestrator
function AgentClient:sendMessage(message)
    if not self.connected or not self.ws then
        return false
    end

    local json = textutils.serializeJSON(message)
    self.ws.send(json)
    return true
end

-- Receive and handle incoming messages (blocking with timeout)
-- @param timeout: Optional timeout in seconds (default: nil = blocking)
-- @return true if message received, false if timeout
function AgentClient:receive(timeout)
    if not self.connected or not self.ws then
        return false
    end

    local msg = self.ws.receive(timeout)
    if msg then
        self:handleMessage(msg)
        return true
    end
    return false
end

-- Main message routing
function AgentClient:handleMessage(msgData)
    local ok, data = pcall(textutils.unserializeJSON, msgData)
    if not ok then
        return
    end

    local msgType = data.type
    local handler = self.messageHandlers[msgType]

    if handler then
        handler(data)
    end
end

-- Handle task_created message
function AgentClient:handleTaskCreated(msg)
    local requestId = msg.request_id
    local taskId = msg.task_id
    local status = msg.status

    -- Store task info
    self.tasks[taskId] = {
        task_id = taskId,
        status = status
    }

    -- Call callback if registered
    local callback = self.pendingRequests[requestId]
    if callback then
        callback(taskId, status)
        self.pendingRequests[requestId] = nil
    end
end

-- Handle task_update message
function AgentClient:handleTaskUpdate(msg)
    local taskId = msg.task_id
    local status = msg.status

    if self.tasks[taskId] then
        self.tasks[taskId].status = status
    end
end

-- Handle task_completed message
function AgentClient:handleTaskCompleted(msg)
    local taskId = msg.task_id
    local result = msg.result

    if self.tasks[taskId] then
        self.tasks[taskId].status = "completed"
        self.tasks[taskId].result = result
    end

    -- Queue an event for programs to react to
    os.queueEvent("agent_task_completed", taskId, result)
end

-- Handle task_failed message
function AgentClient:handleTaskFailed(msg)
    local taskId = msg.task_id
    local error = msg.error

    if self.tasks[taskId] then
        self.tasks[taskId].status = "failed"
        self.tasks[taskId].error = error
    end

    -- Queue an event
    os.queueEvent("agent_task_failed", taskId, error)
end

-- Handle command_call message
function AgentClient:handleCommandCall(msg)
    local taskId = msg.task_id
    local callId = msg.call_id
    local command = msg.command
    local args = msg.args

    print("[CLIENT] Command call: " .. command .. " (call " .. callId .. ")")

    -- Look up command handler
    local handler = self.commands[command]
    if not handler then
        self:sendCommandResult(taskId, callId, false, nil, "Unknown command: " .. command)
        return
    end

    -- Execute command in protected mode
    local success, result = pcall(handler, args, taskId, callId)

    if success then
        -- Handler succeeded
        self:sendCommandResult(taskId, callId, true, result, nil)
    else
        -- Handler threw an error
        self:sendCommandResult(taskId, callId, false, nil, tostring(result))
    end
end

-- Handle error message
function AgentClient:handleError(msg)
    -- Error messages are handled by the orchestrator
end

-- Generate a unique ID
function AgentClient:generateId()
    -- Simple ID generation (you might want to improve this)
    return tostring(os.epoch("utc")) .. "_" .. tostring(math.random(1000, 9999))
end

-- Run the client event loop
-- This blocks and processes messages continuously
function AgentClient:run()
    while self.connected do
        self:receive(1.0)  -- 1 second timeout
    end
end

return AgentClient
