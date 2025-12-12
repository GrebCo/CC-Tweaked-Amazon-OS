"""
CC LLM Agent Framework - Main Orchestrator

FastAPI application that manages WebSocket connections, tasks, and LLM interactions.
"""

from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from typing import Optional, List, Dict, Any
import asyncio
import json
import uuid

from .websocket_manager import WebSocketManager
from .task_manager import TaskManager, TaskStatus
from .llm_adapter import LLMAdapter
from .config import config


app = FastAPI(title="CC LLM Agent Framework Orchestrator")

# Initialize managers
ws_manager = WebSocketManager()
task_manager = TaskManager()
llm_adapter = LLMAdapter(
    base_url=config.llm.base_url,
    model=config.llm.model,
    temperature=config.llm.temperature,
    max_tokens=config.llm.max_tokens
)


# ============================================================================
# Pydantic Models for API
# ============================================================================

class CreateTaskRequest(BaseModel):
    """Request to create a new task."""
    request_id: str
    task_kind: str
    client_id: str
    prompt: str
    context: Optional[Dict[str, Any]] = None
    allowed_commands: Optional[List[str]] = None


class CommandResult(BaseModel):
    """Result from executing a command."""
    task_id: str
    call_id: str
    ok: bool
    result: Optional[Dict[str, Any]] = None
    error: Optional[str] = None


class CancelTaskRequest(BaseModel):
    """Request to cancel a task."""
    task_id: str


# ============================================================================
# WebSocket Endpoint
# ============================================================================

@app.websocket("/ws/{client_id}")
async def websocket_endpoint(websocket: WebSocket, client_id: str):
    """
    WebSocket endpoint for CC clients to connect and communicate.

    Args:
        websocket: WebSocket connection
        client_id: Unique identifier for the CC client
    """
    await ws_manager.connect(client_id, websocket)

    try:
        while True:
            # Receive message from client
            data = await websocket.receive_text()
            message = json.loads(data)

            message_type = message.get("type")

            if message_type == "create_task":
                # Handle task creation request
                await handle_create_task(message, client_id)

            elif message_type == "command_result":
                # Handle command result
                await handle_command_result(message)

            elif message_type == "cancel_task":
                # Handle task cancellation
                task_id = message.get("task_id")
                if task_id:
                    task_manager.update_status(task_id, TaskStatus.CANCELLED)
                    await ws_manager.send_to_client(client_id, {
                        "type": "task_update",
                        "task_id": task_id,
                        "status": "cancelled"
                    })

            elif message_type == "ping":
                # Respond to ping with pong
                await ws_manager.send_to_client(client_id, {"type": "pong"})

    except WebSocketDisconnect:
        ws_manager.disconnect(client_id)
    except Exception as e:
        print(f"[WS] Error in websocket for {client_id}: {e}")
        ws_manager.disconnect(client_id)


# ============================================================================
# Message Handlers
# ============================================================================

async def handle_create_task(message: dict, requesting_client_id: str):
    """
    Handle a create_task message from a CC client.

    Args:
        message: Message dictionary
        requesting_client_id: Client identifier of the requester
    """
    try:
        request_id = message["request_id"]
        task_kind = message["task_kind"]
        prompt = message["prompt"]
        context = message.get("context", {})
        allowed_commands = message.get("allowed_commands")

        # IMPORTANT: Use client_id from message (agent that will execute)
        # NOT the requesting_client_id (who created the task)
        target_client_id = message.get("client_id", requesting_client_id)

        print(f"[TASK] Task requested by '{requesting_client_id}', will execute on '{target_client_id}'")

        # Get task kind configuration
        kind_config = config.get_task_kind(task_kind)

        # Use allowed commands from message or default from config
        if allowed_commands is None:
            allowed_commands = kind_config.allowed_commands

        # Create task with the TARGET client (agent that will execute commands)
        task = task_manager.create_task(
            kind=task_kind,
            client_id=target_client_id,
            prompt=kind_config.system_prompt + "\n\n" + prompt,
            context=context,
            allowed_commands=allowed_commands
        )

        # Send task_created response back to REQUESTER
        await ws_manager.send_to_client(requesting_client_id, {
            "type": "task_created",
            "request_id": request_id,
            "task_id": task.task_id,
            "status": task.status.value
        })

        # Start processing the task
        asyncio.create_task(process_task(task.task_id))

    except Exception as e:
        print(f"[TASK] Error creating task: {e}")
        await ws_manager.send_to_client(requesting_client_id, {
            "type": "error",
            "message": f"Failed to create task: {str(e)}"
        })


async def handle_command_result(message: dict):
    """
    Handle a command_result message from a CC client.

    Args:
        message: Message dictionary
    """
    task_id = message["task_id"]
    call_id = message["call_id"]
    ok = message["ok"]
    result = message.get("result")
    error = message.get("error")

    print(f"[RESULT] Received command result for task {task_id}")
    print(f"[RESULT] Success: {ok}")
    if ok:
        print(f"[RESULT] Result: {str(result)[:200]}...")
    else:
        print(f"[RESULT] Error: {error}")

    task = task_manager.get_task(task_id)
    if not task:
        print(f"[TASK] Command result for unknown task: {task_id}")
        return

    # Verify this is the pending call
    if task.pending_call_id != call_id:
        print(f"[TASK] Unexpected call_id {call_id} for task {task_id}")
        return

    # Track errors to prevent infinite loops
    if not ok:
        task.consecutive_errors += 1
        print(f"[RESULT] Consecutive errors: {task.consecutive_errors}/{task.max_consecutive_errors}")

        if task.consecutive_errors >= task.max_consecutive_errors:
            print(f"[RESULT] Too many consecutive errors, failing task")
            task_manager.fail_task(task_id, f"Too many consecutive errors. Last error: {error}")
            await ws_manager.send_to_client(task.client_id, {
                "type": "task_failed",
                "task_id": task_id,
                "error": f"Task failed after {task.consecutive_errors} consecutive errors"
            })
            return
    else:
        # Reset error count on success
        task.consecutive_errors = 0

    # Add result to history
    tool_message = llm_adapter.format_tool_result(
        tool_name=task.pending_command or "unknown",
        result=result if ok else None,
        error=error if not ok else None
    )
    task.add_to_history(tool_message)

    # Clear pending command
    task_manager.clear_pending_command(task_id)

    # Continue processing the task
    print(f"[RESULT] Continuing task processing...")
    asyncio.create_task(process_task(task_id))


# ============================================================================
# Task Processing
# ============================================================================

async def process_task(task_id: str):
    """
    Process a task by stepping through LLM interactions.

    Args:
        task_id: Task identifier
    """
    task = task_manager.get_task(task_id)
    if not task:
        return

    # Update status to running
    task_manager.update_status(task_id, TaskStatus.RUNNING)
    print(f"[TASK] Processing task {task_id}...")

    try:
        # Get available tools for this task
        tools = config.get_commands_for_task(task.kind)
        print(f"[TASK] Available tools: {[t['name'] for t in tools]}")
        print(f"[TASK] Sending {len(task.history)} messages to LLM...")

        # Call LLM
        print("[LLM] Calling Ollama...")
        response = await llm_adapter.chat_completion(
            messages=task.history,
            tools=tools
        )
        print(f"[LLM] Response received ({len(response['content'])} chars)")
        print(f"[LLM] Response content: {response['content'][:500]}...")

        # Add assistant response to history
        task.add_to_history({
            "role": "assistant",
            "content": response["content"]
        })

        # Check if there are tool calls
        tool_calls = response.get("tool_calls", [])
        print(f"[LLM] Tool calls found: {len(tool_calls)}")

        if not tool_calls:
            # No tool calls - task is complete
            print(f"[TASK] Task {task_id} complete - no tool calls, sending result to client")
            task_manager.complete_task(task_id, {
                "message": response["content"]
            })

            # Send task_completed message
            await ws_manager.send_to_client(task.client_id, {
                "type": "task_completed",
                "task_id": task_id,
                "result": task.result
            })
            print(f"[TASK] Completion message sent to client {task.client_id}")
        else:
            # Process first tool call
            tool_call = tool_calls[0]
            print(f"[TASK] Executing tool: {tool_call['tool']}")
            print(f"[TASK] Tool arguments: {tool_call['arguments']}")
            await execute_tool_call(task, tool_call)

    except Exception as e:
        print(f"[TASK] Error processing task {task_id}: {e}")
        task_manager.fail_task(task_id, str(e))

        # Send task_failed message
        await ws_manager.send_to_client(task.client_id, {
            "type": "task_failed",
            "task_id": task_id,
            "error": str(e)
        })


async def execute_tool_call(task, tool_call: dict):
    """
    Execute a tool call by sending a command_call message to the client.

    Args:
        task: Task object
        tool_call: Tool call dictionary with 'tool' and 'arguments'
    """
    command = tool_call["tool"]
    args = tool_call["arguments"]

    # Verify command is allowed
    if command not in task.allowed_commands:
        error_msg = f"Command '{command}' not allowed for this task"
        print(f"[TOOL] ERROR: {error_msg}")
        tool_result = llm_adapter.format_tool_result(command, None, error_msg)
        task.add_to_history(tool_result)
        asyncio.create_task(process_task(task.task_id))
        return

    # Generate call ID
    call_id = str(uuid.uuid4())
    print(f"[TOOL] Sending command '{command}' to client '{task.client_id}' (call_id: {call_id})")

    # Track pending command
    task_manager.set_pending_command(task.task_id, call_id, command)

    # Send command_call message
    success = await ws_manager.send_to_client(task.client_id, {
        "type": "command_call",
        "task_id": task.task_id,
        "call_id": call_id,
        "command": command,
        "args": args
    })

    if success:
        print(f"[TOOL] Command sent successfully, waiting for result...")
    else:
        print(f"[TOOL] ERROR: Failed to send command to client {task.client_id}")


# ============================================================================
# HTTP Endpoints
# ============================================================================

@app.get("/")
async def root():
    """Root endpoint with API information."""
    return {
        "name": "CC LLM Agent Framework Orchestrator",
        "version": "1.0.0",
        "endpoints": {
            "websocket": "/ws/{client_id}",
            "status": "/status",
            "tasks": "/tasks",
            "clients": "/clients"
        }
    }


@app.get("/status")
async def get_status():
    """Get overall system status."""
    active_tasks = task_manager.get_active_tasks()
    return {
        "connected_clients": len(ws_manager.get_connected_clients()),
        "total_tasks": len(task_manager.tasks),
        "active_tasks": len(active_tasks),
        "llm_model": config.llm.model
    }


@app.get("/tasks")
async def get_tasks():
    """Get list of all tasks."""
    return {
        "tasks": task_manager.list_tasks()
    }


@app.get("/tasks/{task_id}")
async def get_task(task_id: str):
    """Get details of a specific task."""
    task = task_manager.get_task(task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")

    return task.to_dict()


@app.get("/clients")
async def get_clients():
    """Get list of connected clients."""
    clients = ws_manager.get_connected_clients()
    client_info = []

    for client_id in clients:
        tasks = task_manager.get_tasks_by_client(client_id)
        client_info.append({
            "client_id": client_id,
            "connected": True,
            "task_count": len(tasks)
        })

    return {
        "clients": client_info
    }


# ============================================================================
# Application Lifecycle
# ============================================================================

@app.on_event("startup")
async def startup_event():
    """Run on application startup."""
    print("=" * 60)
    print("[STARTUP] CC LLM Agent Framework Orchestrator")
    print("=" * 60)
    print(f"[STARTUP] LLM Model: {config.llm.model}")
    print(f"[STARTUP] LLM Base URL: {config.llm.base_url}")
    print(f"[STARTUP] Temperature: {config.llm.temperature}")
    print(f"[STARTUP] Max Tokens: {config.llm.max_tokens}")
    print(f"[STARTUP] Available Task Kinds: {list(config.task_kinds.keys())}")
    print("[STARTUP] Ready to accept connections!")
    print("=" * 60)


@app.on_event("shutdown")
async def shutdown_event():
    """Run on application shutdown."""
    print("[SHUTDOWN] Closing LLM adapter...")
    await llm_adapter.close()


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
