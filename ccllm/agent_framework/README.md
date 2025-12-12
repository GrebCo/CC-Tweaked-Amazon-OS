# CC LLM Agent Framework

A framework for integrating locally hosted language models with ComputerCraft (CC:Tweaked) computers, enabling autonomous AI agents that can execute commands, manage files, and run programs.

## Architecture Overview

The framework consists of three main components:

1. **LLM Orchestrator Service** (Python/FastAPI)
   - Manages WebSocket connections from CC clients
   - Communicates with local LLM via Ollama
   - Coordinates task execution and tool calls
   - Provides HTTP endpoints for monitoring

2. **CC Agent Host** (Lua)
   - ComputerCraft computer that connects via WebSocket
   - Registers and executes tools/commands
   - Provides core tools for shell, filesystem, and program execution

3. **CC Clients** (Lua)
   - Additional CC computers that can create tasks
   - Can also register custom tools

## Features

- Long-running autonomous agents
- Execute CraftOS shell commands
- Create, read, update, and delete files
- Run Lua programs and capture output
- Extensible tool system
- Support for multiple concurrent tasks
- WebSocket-based real-time communication

## Prerequisites

### Server Side
- Python 3.9 or higher
- [Ollama](https://ollama.ai) running locally with a model installed
- FastAPI and dependencies (see requirements.txt)

### CC Side
- CC:Tweaked (ComputerCraft mod for Minecraft)
- HTTP and WebSocket APIs enabled in CC:Tweaked config

## Installation

### 1. Set up the Orchestrator

```bash
cd agent_framework
pip install -r requirements.txt
```

### 2. Start Ollama

Make sure Ollama is running with a model loaded:

```bash
ollama run llama2
```

### 3. Configure the Orchestrator

Edit `orchestrator/config.py` to set:
- LLM model name
- Ollama base URL
- Task kinds and allowed commands

### 4. Upload CC Client Library

Copy the `cc_client` directory to your ComputerCraft computer:
- `agent_client.lua` - Core client library
- `core_tools.lua` - Built-in tools
- `agent_host.lua` - Example agent host program
- `example_client.lua` - Example client program

## Usage

### Start the Orchestrator

```bash
cd agent_framework/orchestrator
python -m uvicorn main:app --host 0.0.0.0 --port 8000
```

Or run directly:

```bash
python main.py
```

### Run an Agent Host (CC Computer)

1. Edit `agent_host.lua` and set the orchestrator URL:
   ```lua
   local ORCHESTRATOR_URL = "ws://YOUR_IP:8000/ws"
   ```

2. Run the agent host:
   ```lua
   agent_host
   ```

### Create a Task (from another CC Computer)

1. Edit `example_client.lua` and set the orchestrator URL

2. Run the example client:
   ```lua
   example_client
   ```

Or create tasks programmatically:

```lua
local AgentClient = require("agent_client")

local client = AgentClient.new("ws://localhost:8000/ws/my_client", "my_client")
client:connect()

client:createTask(
    "code_job",
    "List all Lua files in the current directory",
    {},
    nil,
    function(taskId, status)
        print("Task created: " .. taskId)
    end
)

client:run()
```

## API Endpoints

### WebSocket
- `ws://host:8000/ws/{client_id}` - WebSocket connection for CC clients

### HTTP
- `GET /` - API information
- `GET /status` - System status
- `GET /tasks` - List all tasks
- `GET /tasks/{task_id}` - Get task details
- `GET /clients` - List connected clients

## Communication Protocol

### Messages from CC to Orchestrator

#### create_task
```json
{
  "type": "create_task",
  "request_id": "unique_id",
  "task_kind": "general_agent",
  "client_id": "agent_host_1",
  "prompt": "Your task description",
  "context": {},
  "allowed_commands": ["shell_exec", "fs_read", "fs_write"]
}
```

#### command_result
```json
{
  "type": "command_result",
  "task_id": "task_uuid",
  "call_id": "call_uuid",
  "ok": true,
  "result": {"data": "..."}
}
```

### Messages from Orchestrator to CC

#### task_created
```json
{
  "type": "task_created",
  "request_id": "unique_id",
  "task_id": "task_uuid",
  "status": "queued"
}
```

#### command_call
```json
{
  "type": "command_call",
  "task_id": "task_uuid",
  "call_id": "call_uuid",
  "command": "fs_read",
  "args": {"path": "/startup.lua"}
}
```

#### task_completed
```json
{
  "type": "task_completed",
  "task_id": "task_uuid",
  "result": {"message": "Task completed successfully"}
}
```

#### task_failed
```json
{
  "type": "task_failed",
  "task_id": "task_uuid",
  "error": "Error message"
}
```

## Core Tools

### shell_exec
Execute a CraftOS shell command.

Arguments:
- `command` (string): Shell command to execute

### fs_list
List files and directories.

Arguments:
- `path` (string): Directory path to list

### fs_read
Read file contents.

Arguments:
- `path` (string): File path to read

### fs_write
Write content to a file.

Arguments:
- `path` (string): File path to write
- `content` (string): Content to write

### fs_delete
Delete a file or directory.

Arguments:
- `path` (string): Path to delete

### run_program
Run a Lua program.

Arguments:
- `path` (string): Program path
- `args` (array): Optional arguments

## Custom Tools

You can register custom tools in your agent host:

```lua
-- Register a custom tool
client:registerCommand("my_tool", function(args, taskId, callId)
    -- Your tool implementation
    local result = doSomething(args.parameter)

    return {
        success = true,
        data = result
    }
end)
```

## Task Kinds

### general_agent
Long-running autonomous agent with access to all core tools.

### code_job
One-off task for code inspection or modification (no shell_exec).

You can define custom task kinds in `orchestrator/config.py`.

## Configuration

Edit `orchestrator/config.py` to customize:

### LLM Configuration
```python
self.llm = LLMConfig(
    base_url="http://localhost:11434",
    model="llama2",
    temperature=0.7,
    max_tokens=2048
)
```

### Add Custom Task Kinds
```python
self.task_kinds["my_task"] = TaskKindConfig(
    name="my_task",
    description="My custom task type",
    allowed_commands=["fs_read", "fs_write"],
    system_prompt="Custom system prompt for this task type"
)
```

## Troubleshooting

### WebSocket Connection Failed
- Ensure the orchestrator is running
- Check that HTTP API is enabled in CC:Tweaked config
- Use your computer's IP address instead of localhost
- Verify firewall settings

### LLM Not Responding
- Check Ollama is running: `ollama list`
- Verify the model is loaded
- Check orchestrator logs for errors

### Commands Not Executing
- Ensure the agent host has registered the tools
- Check that commands are in the allowed_commands list for the task
- Review CC computer logs for errors

## Architecture Details

See [cc_llm_agent_framework_spec_v2.md](../cc_llm_agent_framework_spec_v2.md) for detailed architecture documentation.

## License

This framework is provided as-is for use with CC:Tweaked and Ollama.

## Credits

Developed for the CC:Tweaked Minecraft mod and Ollama local LLM platform.
