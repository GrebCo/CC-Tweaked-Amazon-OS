-- Agent Host Example
--
-- This is an example program that connects to the orchestrator and acts as
-- an agent host. It registers core tools and can be extended with custom tools.

-- Configuration
local ORCHESTRATOR_URL = "ws://localhost:8000/ws"
local CLIENT_ID = "agent_host_1"

-- Load the client library and core tools
local AgentClient = require("agent_client")
local CoreTools = require("core_tools")

print("======================================")
print("CC LLM Agent Host")
print("======================================")
print()

-- Create client instance
local client = AgentClient.new(
    ORCHESTRATOR_URL .. "/" .. CLIENT_ID,
    CLIENT_ID
)

-- Register core tools
CoreTools.registerAll(client)

-- Connect to orchestrator
print("Connecting to orchestrator...")
if not client:connect() then
    error("Failed to connect to orchestrator")
end

print()
print("Agent host is ready!")
print("Waiting for tasks from the orchestrator...")
print("Press Ctrl+T to terminate")
print()

-- Run the event loop
-- This will block and process messages from the orchestrator
client:run()
