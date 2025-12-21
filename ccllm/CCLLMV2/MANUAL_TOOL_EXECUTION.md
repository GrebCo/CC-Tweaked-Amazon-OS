# Manual Tool Execution Pattern

## Overview

This implementation uses a **manual tool execution pattern** instead of PydanticAI's native function calling. This approach is compatible with Ollama models like qwen2.5-coder that don't support native function calling.

## How It Works

### 1. Agent Returns Structured JSON

The agent is configured with `output_type=AgentResponse` where AgentResponse can be:

**Tool Request** (kind="tool"):
```json
{
  "kind": "tool",
  "explanation": "Reading file...",
  "tool_call": {
    "tool": "cc_read",
    "args": {"path": "/startup.lua"}
  }
}
```

**Final Result** (kind="final"):
```json
{
  "kind": "final",
  "explanation": "Task completed",
  "success": true,
  "message": "Successfully created hello.lua",
  "details": {}
}
```

### 2. Manual Tool Execution Loop

The `execute_task_with_agent()` function implements the execution loop:

1. Call `agent.run(prompt)` to get an AgentResponse
2. If `kind="tool"`:
   - Look up tool in TOOL_REGISTRY
   - Execute tool function with provided args
   - Feed result back: `agent.run("TOOL_RESULT: {result}")`
3. If `kind="final"`:
   - Return the final response
4. Repeat until final or max_steps reached

### 3. No Tool Decorators

Tools are **standalone async functions** (not decorated with `@agent.tool`):

```python
async def cc_read(deps: CCAgentDeps, path: str) -> str:
    """Read a file from the CC computer."""
    if deps.mode == "stub":
        content = f"-- Stub content for {path}\n"
        deps.file_cache[path] = content
        return content
    else:
        result = await call_cc_command(deps.ws_client, "fs_read", {"path": path})
        return result.get("content", "")
```

### 4. Tool Registry

Tools are mapped in a simple dict:

```python
TOOL_REGISTRY = {
    "send_status": send_status,
    "ask_user": ask_user,
    "cc_read": cc_read,
    "cc_write": cc_write,
    "cc_list": cc_list,
    "cc_delete": cc_delete,
    "cc_run_program": cc_run_program,
    "cc_shell": cc_shell,
    "local_read": local_read,
    "local_write": local_write,
    "local_patch": local_patch,
}
```

## Why This Pattern?

### Problems with Native Function Calling

- Many Ollama models (qwen2.5-coder, gemma, etc.) don't support OpenAI-style function calling
- Models that claim support often just echo tool calls as text instead of executing them
- Limited to specific models (llama3.1, mistral-nemo)

### Benefits of Manual Execution

✅ **Model Agnostic**: Works with any model that can produce structured JSON output
✅ **Explicit Control**: We control exactly when and how tools execute
✅ **Better Debugging**: Can log and inspect every tool call
✅ **Error Handling**: Easy to catch and feed errors back to the agent
✅ **Works with qwen2.5-coder**: User's preferred model

## Example Execution

```
[STEP 1]
[EXPLANATION] Writing hello world program...
[TOOL] cc_write({'path': '/hello.lua', 'content': "print('Hello!')"})
[TOOL_RESULT] Wrote 15 bytes to /hello.lua

[STEP 2]
[EXPLANATION] Running the program...
[TOOL] cc_run_program({'path': '/hello.lua', 'args': []})
[TOOL_RESULT] Program /hello.lua executed successfully.
Output:
Hello!

[STEP 3]
[EXPLANATION] Task completed
[FINAL] Success=True, Message=Created and ran hello.lua
```

## Files Modified

1. **cc_agent_v2.py**
   - Removed `@agent.tool` decorators
   - Changed tools from `ctx: RunContext[CCAgentDeps]` to `deps: CCAgentDeps`
   - Added TOOL_REGISTRY dict
   - Added `execute_task_with_agent()` function
   - Updated `run_task_interactive()` to use manual execution

2. **test_server.py**
   - Import `execute_task_with_agent`
   - Use manual execution instead of `agent.run()`

3. **orchestrator.py**
   - Import `execute_task_with_agent`
   - Update `process_task()` to use manual execution

## Testing

Run test_server.py to verify:
```bash
cd CCLLMV2
python test_server.py
```

Run CLI interface:
```bash
cd CCLLMV2
python cc_agent_v2.py
```

Expected behavior:
- Agent requests tools via JSON
- Tools execute and return results
- Results feed back to agent
- Agent makes decisions and continues
- Eventually returns final result
