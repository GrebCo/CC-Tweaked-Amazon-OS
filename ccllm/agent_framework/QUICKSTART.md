# Quick Start Guide

Get the CC LLM Agent Framework up and running in minutes!

## Step 1: Install Dependencies

```bash
cd agent_framework
pip install -r requirements.txt
```

## Step 2: Start Ollama

Make sure Ollama is installed and running with a model:

```bash
# Install Ollama from https://ollama.ai if you haven't already

# Pull and run a model (e.g., llama2)
ollama run llama2
```

Keep Ollama running in the background.

## Step 3: Start the Orchestrator

```bash
python run_orchestrator.py
```

You should see:
```
Starting server on http://0.0.0.0:8000
WebSocket endpoint: ws://0.0.0.0:8000/ws/{client_id}
```

## Step 4: Set Up CC Agent Host

In Minecraft with CC:Tweaked:

1. Place a computer
2. Create or upload these files to the computer:
   - `agent_client.lua`
   - `core_tools.lua`
   - `agent_host.lua`

3. Edit `agent_host.lua` and change the URL to your server's IP:
   ```lua
   local ORCHESTRATOR_URL = "ws://YOUR_IP:8000/ws"
   ```

4. Run the agent host:
   ```
   > agent_host
   ```

## Step 5: Test with Example Client

On another CC computer:

1. Upload `agent_client.lua` and `example_client.lua`

2. Edit `example_client.lua` with your server's IP

3. Run the example:
   ```
   > example_client
   ```

The client will create a task asking the agent to list files. You should see:
- The orchestrator processing the task
- The agent host executing the fs_list command
- The LLM responding with information about the files
- The client receiving the completion message

## What's Happening?

1. **Example Client** sends a task creation request to the orchestrator
2. **Orchestrator** creates the task and starts processing it with the LLM
3. **LLM** (via Ollama) decides to use the `fs_list` tool
4. **Orchestrator** sends a command_call message to the **Agent Host**
5. **Agent Host** executes the command and sends back the result
6. **Orchestrator** gives the result to the **LLM** to continue
7. **LLM** formulates a response and completes the task
8. **Example Client** receives the task_completed message

## Next Steps

- Try different prompts in `example_client.lua`
- Create custom tools and register them
- Build long-running agents
- Read the full README.md for more details

## Troubleshooting

### Can't connect to orchestrator
- Make sure it's running on port 8000
- Use your computer's actual IP address, not "localhost"
- Check firewall settings

### Ollama errors
- Ensure Ollama is running: `ollama list`
- The model must be downloaded first: `ollama pull llama2`

### WebSocket errors in CC
- Enable HTTP API in CC:Tweaked config
- Check that `http.websocket` is available

## Configuration Tips

### Change the LLM Model

Edit `orchestrator/config.py`:

```python
self.llm = LLMConfig(
    model="mistral",  # or any other Ollama model
    temperature=0.7
)
```

### Add More Tools

In your agent host, after registering core tools:

```lua
CoreTools.registerAll(client)

-- Add your custom tool
client:registerCommand("my_tool", function(args)
    -- Your code here
    return { result = "success" }
end)
```

### Create Different Task Types

Edit `orchestrator/config.py` to add new task kinds with different system prompts and allowed commands.

---

You're now ready to build autonomous AI agents in ComputerCraft!
