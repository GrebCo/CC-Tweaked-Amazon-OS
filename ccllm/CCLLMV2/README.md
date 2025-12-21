# CC LLM Agent V2 - PydanticAI Version

A ComputerCraft LLM agent framework using PydanticAI with WebSocket communication.

## Features

- ✅ PydanticAI agent with native tool calling
- ✅ FastAPI WebSocket server
- ✅ Full integration with CC computers
- ✅ File caching for efficient edits
- ✅ Structured output with automatic validation

## Setup

### 1. Install Python Dependencies

```bash
cd CCLLMV2
pip install -r requirements.txt
```

### 2. Start Ollama

Make sure Ollama is running with qwen2.5-coder:7b:

```bash
ollama pull qwen2.5-coder:7b
ollama serve
```

## Usage

### Server Mode (Production)

1. Start the WebSocket orchestrator:

```bash
python orchestrator.py
```

Server will start on `ws://localhost:8000`

2. In ComputerCraft, upload the Lua files:
   - `agent_client.lua`
   - `core_tools.lua`
   - `cli.lua`

3. Run the CLI on your CC computer:

```lua
cli
```

4. Type tasks:
```
Task> Create a hello world program
Task> Write a fibonacci calculator
Task> List all my programs
```

### CLI Mode (Testing - No CC Required)

Test the agent locally without a CC computer:

```bash
python cc_agent_v2.py
```

This runs in "stub" mode where tools simulate CC operations.

## Architecture

### Python Files

- **orchestrator.py** - FastAPI WebSocket server that manages tasks
- **cc_agent_v2.py** - PydanticAI agent with tool definitions
- **ws_tools.py** - WebSocket communication helpers
- **websocket_manager.py** - WebSocket connection manager

### Lua Files (CC Computer)

- **agent_client.lua** - WebSocket client library
- **core_tools.lua** - Tool implementations (fs_read, fs_write, etc.)
- **cli.lua** - Interactive CLI interface

## How It Works

1. User types a task in the CC CLI
2. Task is sent via WebSocket to the orchestrator
3. Orchestrator creates a PydanticAI agent with dependencies
4. Agent decides which tools to call (fs_read, fs_write, run_program, etc.)
5. Tools send commands back to CC computer via WebSocket
6. CC computer executes commands and returns results
7. Agent processes results and decides next steps
8. When complete, agent returns final result to user

## Available Tools

### CC Computer Tools (Remote)
- `cc_read(path)` - Read files from CC
- `cc_write(path, content)` - Write files to CC
- `cc_list(path)` - List directory contents
- `cc_delete(path)` - Delete files/directories
- `cc_run_program(path, args)` - Execute Lua programs
- `cc_shell(command)` - Run CraftOS shell commands

### Local Cache Tools (Server-Side)
- `local_read(path)` - Read from cache
- `local_write(path, content)` - Write to cache
- `local_patch(path, old_text, new_text)` - Apply patches

### Communication Tools
- `send_status(message)` - Send progress updates
- `ask_user(question)` - Ask for clarification

## Example Tasks

```
Create a turtle mining program
Fix syntax errors in my startup.lua
List all files in the programs folder
Write a program that calculates prime numbers
Make a program that displays the current time
```

## Troubleshooting

**Agent not connecting?**
- Check Ollama is running: `ollama list`
- Check server is running: `http://localhost:8000/status`

**CC computer can't connect?**
- Verify WebSocket URL in cli.lua
- Check server logs for connection attempts
- Make sure CC computer has http API enabled

**Tools timing out?**
- Increase timeout in ws_tools.py (default 30s)
- Check CC computer is responsive

## Next Steps

- Add more sophisticated patching tools
- Implement multi-agent orchestration
- Add support for peripheral tools
- Create specialized agents for different task types
