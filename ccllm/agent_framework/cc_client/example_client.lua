-- Example Client
--
-- This is an example of how to create tasks from a CC computer.

-- Configuration
local ORCHESTRATOR_URL = "ws://localhost:8000/ws"
local CLIENT_ID = "example_client_1"

-- Load the client library
local AgentClient = require("agent_client")

print("======================================")
print("CC LLM Agent Framework - Example Client")
print("======================================")
print()

-- Create client instance
local client = AgentClient.new(
    ORCHESTRATOR_URL .. "/" .. CLIENT_ID,
    CLIENT_ID
)

-- Connect to orchestrator
print("Connecting to orchestrator...")
if not client:connect() then
    error("Failed to connect to orchestrator")
end

print("Connected!")
print()

-- Create a test task
print("Creating a task...")

local taskCreated = false
local createdTaskId = nil

client:createTask(
    "code_job",  -- task kind
    "Please list all files in the current directory and tell me what you find.",  -- prompt
    {},  -- context
    nil,  -- allowed commands (use default)
    function(taskId, status)  -- callback
        print("Task created: " .. taskId)
        print("Initial status: " .. status)
        taskCreated = true
        createdTaskId = taskId
    end
)

-- Wait for task creation confirmation
print("Waiting for task creation...")
while not taskCreated do
    client:receive(1.0)
end

print()
print("Task created successfully!")
print("Task ID: " .. createdTaskId)
print()
print("The agent host will now process this task.")
print("You can monitor progress in the orchestrator logs.")
print()
print("Waiting for task completion...")

-- Wait for task completion
local taskDone = false
while not taskDone do
    -- Check for completion events
    local event, taskId, result = os.pullEvent()

    if event == "agent_task_completed" and taskId == createdTaskId then
        print()
        print("Task completed!")
        print("Result:")
        print(textutils.serialize(result))
        taskDone = true
    elseif event == "agent_task_failed" and taskId == createdTaskId then
        print()
        print("Task failed!")
        print("Error: " .. tostring(result))
        taskDone = true
    end

    -- Also receive messages to keep connection alive
    client:receive(0.1)
end

-- Disconnect
client:disconnect()
print()
print("Done!")
