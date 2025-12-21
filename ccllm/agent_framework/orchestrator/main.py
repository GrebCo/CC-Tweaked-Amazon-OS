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
import logging
import traceback
from datetime import datetime

from .websocket_manager import WebSocketManager
from .task_manager import TaskManager, TaskStatus
from .llm_adapter import LLMAdapter
from .config import config
from .agents.planner import build_planner_agent
from .agents.coder import build_coder_agent
from .agents.schemas import ExecutorStep
from .agents.graph import build_agent_graph
from .agents.runner import AgentRunner

# Set up logging to both file and console
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[
        logging.FileHandler(f'orchestrator_{datetime.now().strftime("%Y%m%d_%H%M%S")}.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)


app = FastAPI(title="CC LLM Agent Framework Orchestrator")

# Initialize managers
ws_manager = WebSocketManager()
task_manager = TaskManager()

# Keep legacy LLM adapter for backwards compatibility with tools
llm_adapter = LLMAdapter(
    base_url=config.llm.base_url,
    model=config.llm.model,
    temperature=config.llm.temperature,
    max_tokens=config.llm.max_tokens
)

# Initialize Pydantic AI agents (Dual LLM: Qwen planner + Gemma coder)
planner_agent = build_planner_agent(
    model_name=config.planner_llm.model,
    base_url=config.planner_llm.base_url,
)
coder_agent = build_coder_agent(
    model_name=config.coder_llm.model,
    base_url=config.coder_llm.base_url,
)

# Agent runner will be initialized after execute_tool_calls is defined
agent_runner = None


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

        # Start processing the task with AgentRunner
        asyncio.create_task(agent_runner.start(task.task_id))

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

        # Cache file contents from successful fs_read for server-side patching
        if task.pending_command == "fs_read" and result and "content" in result:
            file_path = result.get("path", "")
            file_content = result.get("content", "")
            if file_path:
                task.file_cache[file_path] = file_content
                print(f"[CACHE] Cached {len(file_content)} chars from '{file_path}'")

    # Add result to history
    tool_message = llm_adapter.format_tool_result(
        tool_name=task.pending_command or "unknown",
        result=result if ok else None,
        error=error if not ok else None
    )
    task.add_to_history(tool_message)

    # Clear pending command
    task_manager.clear_pending_command(task_id)

    # Continue processing the task with AgentRunner
    print(f"[RESULT] Resuming task with AgentRunner...")
    asyncio.create_task(agent_runner.resume(task_id, {"kind": "command", "result": message}))


# ============================================================================
# Tool Execution - Batching Support
# ============================================================================

async def execute_tool_calls(task, tool_calls: List[dict]) -> dict:
    """
    Execute a list of tool calls in order, batching server-side tools and stopping at first CC-side tool.

    Server-side/immediate tools (send_status, patch_cached, lua_check_cached):
      - Execute immediately
      - Add result to history
      - Continue to next tool

    CC-side/remote tools (fs_read, fs_write, run_program):
      - Send to CC client
      - Set pending_call_id
      - Stop execution (wait for command_result)

    Args:
        task: Task object
        tool_calls: List of tool call dictionaries

    Returns:
        dict with outcome:
          {"status": "done"} - all tools completed (server-side only)
          {"status": "waiting_for_command", "call_id": str, "command": str} - stopped for CC tool
          {"status": "waiting_for_user"} - stopped for ask_user
          {"status": "error", "error": str} - error occurred
    """
    print(f"[BATCH] Executing {len(tool_calls)} tool calls...")

    for i, tool_call in enumerate(tool_calls):
        command = tool_call["tool"]
        args = tool_call["arguments"]

        print(f"[BATCH] Tool {i+1}/{len(tool_calls)}: {command}")

        # Verify command is allowed
        if command not in task.allowed_commands:
            error_msg = f"Command '{command}' not allowed for this task"
            print(f"[TOOL] ERROR: {error_msg}")
            tool_result = llm_adapter.format_tool_result(command, None, error_msg)
            task.add_to_history(tool_result)
            continue  # Skip to next tool

        # Handle server-side/immediate tools (execute and continue)
        if command == "send_status":
            # Execute send_status WITHOUT auto-reentry (we're in batch mode)
            await handle_send_status(task, args, continue_processing=False)
            print(f"[BATCH] send_status completed, continuing to next tool...")
            continue

        if command == "ask_user":
            # ask_user must wait for user response, so stop batch here
            print(f"[BATCH] ask_user requires user input, stopping batch...")
            result = await handle_ask_user(task, args)
            if result and not result.get("ok"):
                # Invalid question - send error and return error status
                tool_result = llm_adapter.format_tool_result("ask_user", None, result.get("error"))
                task.add_to_history(tool_result)
                return {"status": "error", "error": result.get("error")}
            # Waiting for user response
            return {"status": "waiting_for_user"}

        # Server-side file cache tools
        if command == "patch_cached":
            result = await handle_patch_cached(task, args)
            tool_result = llm_adapter.format_tool_result("patch_cached", result if result.get("ok") else None, result.get("error"))
            task.add_to_history(tool_result)
            print(f"[BATCH] patch_cached completed, continuing to next tool...")
            continue

        if command == "lua_check_cached":
            result = await handle_lua_check_cached(task, args)
            tool_result = llm_adapter.format_tool_result("lua_check_cached", result if result.get("ok") else None, result.get("error"))
            task.add_to_history(tool_result)
            print(f"[BATCH] lua_check_cached completed, continuing to next tool...")
            continue

        if command == "diff_cached":
            result = await handle_diff_cached(task, args)
            tool_result = llm_adapter.format_tool_result("diff_cached", result)
            task.add_to_history(tool_result)
            print(f"[BATCH] diff_cached completed, continuing to next tool...")
            continue

        if command == "fs_write_cached":
            result = await handle_fs_write_cached(task, args)
            if result is None:
                # fs_write_cached sent command to CC, stop batch
                print(f"[BATCH] fs_write_cached dispatched to CC, stopping batch...")
                # The call_id is in the pending_call_id on the task
                return {
                    "status": "waiting_for_command",
                    "call_id": task.pending_call_id,
                    "command": "fs_write"
                }
            else:
                # Error occurred
                tool_result = llm_adapter.format_tool_result("fs_write_cached", None, result.get("error"))
                task.add_to_history(tool_result)
                print(f"[BATCH] fs_write_cached failed, continuing to next tool...")
                continue

        # All other tools are CC-side - send to client and STOP batch
        print(f"[BATCH] {command} is CC-side, dispatching and stopping batch...")

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
            # STOP batch execution - return waiting status
            return {
                "status": "waiting_for_command",
                "call_id": call_id,
                "command": command
            }
        else:
            print(f"[TOOL] ERROR: Failed to send command to client {task.client_id}")
            return {"status": "error", "error": f"Failed to send command to client {task.client_id}"}

    # If we get here, all tools were server-side - return done
    print(f"[BATCH] All {len(tool_calls)} tools completed")
    return {"status": "done"}


# ============================================================================
# Special Tool Handlers
# ============================================================================

async def handle_send_status(task, args: dict, continue_processing: bool = True):
    """
    Handle send_status tool - sends a status update to the user.

    Args:
        task: Task object
        args: Arguments containing 'message'
        continue_processing: Whether to auto-continue task processing (default True for backward compat)
    """
    message = args.get("message", "")
    print(f"[STATUS] {message}")

    # Send status update to client
    await ws_manager.send_to_client(task.client_id, {
        "type": "status_update",
        "task_id": task.task_id,
        "message": message
    })

    # Add success result to history
    tool_result = llm_adapter.format_tool_result("send_status", {"sent": True})
    task.add_to_history(tool_result)

    # Note: With LangGraph, the graph manages flow control
    # The continue_processing parameter is kept for backwards compatibility
    # but auto-continue is now handled by the graph's act node


async def handle_ask_user(task, args: dict):
    """
    Handle ask_user tool - asks the user a question and waits for response.

    Args:
        task: Task object
        args: Arguments containing 'question'

    Returns:
        dict with error if question is invalid, None otherwise
    """
    question = args.get("question", "")
    print(f"[ASK_USER] {question}")

    # Validate that this is a reasonable question
    question_lower = question.lower()
    forbidden_patterns = [
        "please provide the content",
        "provide the content for",
        "what should the content be",
        "give me the content",
        "write the content",
        "what code should",
        "should i create",  # Don't ask if you should create - just do it!
        "do you want me to create",
        "shall i create"
    ]

    # Check for questions about parameters that should be program arguments
    parameter_patterns = [
        ("shift value", "Make shift value a command-line argument: arg[1]"),
        ("what value", "Use a sensible default or make it a parameter"),
        ("which value", "Use a sensible default or make it a parameter"),
        ("what number", "Use a sensible default or make it a parameter")
    ]

    for pattern, suggestion in parameter_patterns:
        if pattern in question_lower:
            error_msg = (
                f"[SYSTEM ERROR] Don't ask about implementation parameters.\n\n"
                f"You asked: \"{question}\"\n\n"
                f"This is unnecessary. {suggestion}\n\n"
                f"For caesar cipher example:\n"
                f"- Make shift a command-line argument: local shift = tonumber(arg[1]) or 3\n"
                f"- Or use a sensible default: local shift = 3\n\n"
                f"Only use ask_user for genuine REQUIREMENT clarifications like:\n"
                f"- \"Should non-alphabetic characters be left unchanged?\"\n"
                f"- \"Do you want uppercase and lowercase handled separately?\"\n\n"
                f"Do NOT ask about implementation details. Design it yourself!"
            )
            print(f"[ASK_USER] Rejecting parameter question")
            return {"ok": False, "error": error_msg}

    for pattern in forbidden_patterns:
        if pattern in question_lower:
            error_msg = (
                f"[SYSTEM ERROR] Invalid use of ask_user tool.\n\n"
                f"You asked: \"{question}\"\n\n"
                f"This is FORBIDDEN. You are an AI engineer - YOU make design decisions.\n"
                f"The user asked you to create a program. You must:\n"
                f"1. Design the solution yourself\n"
                f"2. Write the code using fs_write\n"
                f"3. Test it using run_program\n\n"
                f"Only use ask_user for genuine clarification questions about BEHAVIOR:\n"
                f"- \"Should the program handle negative numbers?\"\n"
                f"- \"Do you want the output sorted?\"\n"
                f"- \"Should it wrap around after Z?\"\n\n"
                f"Do NOT ask the user to make design decisions for you. That's your job!"
            )
            print(f"[ASK_USER] Rejecting invalid question")
            return {"ok": False, "error": error_msg}

    # Generate call ID to track this question
    call_id = str(uuid.uuid4())

    # Track pending command (for question/answer)
    task_manager.set_pending_command(task.task_id, call_id, "ask_user")

    # Send question to client
    await ws_manager.send_to_client(task.client_id, {
        "type": "user_question",
        "task_id": task.task_id,
        "call_id": call_id,
        "question": question
    })

    # The response will come back as a regular command_result
    return None


# ============================================================================
# Server-Side Tools (File Cache Operations)
# ============================================================================

async def handle_patch_cached(task, args: dict) -> dict:
    """
    Apply a patch to cached file content.

    Args:
        task: Task object
        args: {path: str, patch: str, format: str, dry_run: bool}

    Returns:
        {ok: bool, diff: str, new_size: int, notes: str}
    """
    import difflib
    import re

    path = args.get("path", "")
    patch_text = args.get("patch", "")
    patch_format = args.get("format", "unified_diff")
    dry_run = args.get("dry_run", False)

    if not path:
        return {"ok": False, "error": "Missing 'path' argument"}

    if path not in task.file_cache:
        return {"ok": False, "error": f"File '{path}' not in cache. Use fs_read first."}

    original_content = task.file_cache[path]
    lines = original_content.splitlines(keepends=True)

    try:
        if patch_format == "unified_diff":
            # Apply unified diff patch
            import subprocess
            import tempfile

            with tempfile.NamedTemporaryFile(mode='w', suffix='.txt', delete=False) as f:
                f.write(original_content)
                temp_path = f.name

            with tempfile.NamedTemporaryFile(mode='w', suffix='.patch', delete=False) as f:
                f.write(patch_text)
                patch_path = f.name

            try:
                # Try to apply patch
                result = subprocess.run(
                    ['patch', temp_path, patch_path],
                    capture_output=True,
                    text=True,
                    timeout=5
                )

                if result.returncode == 0:
                    with open(temp_path, 'r') as f:
                        new_content = f.read()
                else:
                    return {"ok": False, "error": f"Patch failed: {result.stderr}"}
            finally:
                import os
                os.unlink(temp_path)
                os.unlink(patch_path)

        elif patch_format == "replace_regex":
            # Simple regex replacement
            # patch should be: "pattern|||replacement"
            parts = patch_text.split("|||", 1)
            if len(parts) != 2:
                return {"ok": False, "error": "replace_regex format: 'pattern|||replacement'"}

            pattern, replacement = parts
            new_content = re.sub(pattern, replacement, original_content, flags=re.MULTILINE | re.DOTALL)

        elif patch_format == "replace_range":
            # Replace specific line range
            # patch format: "start_line,end_line\nnew content"
            parts = patch_text.split("\n", 1)
            if len(parts) != 2:
                return {"ok": False, "error": "replace_range format: 'start,end\\nnew content'"}

            range_spec, new_text = parts
            try:
                start, end = map(int, range_spec.split(","))
                lines[start-1:end] = [new_text + "\n"]
                new_content = "".join(lines)
            except (ValueError, IndexError) as e:
                return {"ok": False, "error": f"Invalid range: {e}"}

        else:
            return {"ok": False, "error": f"Unknown patch format: {patch_format}"}

        # Generate diff for display
        diff = "\n".join(difflib.unified_diff(
            original_content.splitlines(),
            new_content.splitlines(),
            fromfile=f"{path} (original)",
            tofile=f"{path} (patched)",
            lineterm=""
        ))

        # Update cache if not dry run
        if not dry_run:
            task.file_cache[path] = new_content
            notes = "Patch applied to cache"
        else:
            notes = "Dry run - cache not modified"

        return {
            "ok": True,
            "diff": diff,
            "new_size": len(new_content),
            "notes": notes
        }

    except Exception as e:
        return {"ok": False, "error": f"Patch error: {type(e).__name__}: {str(e)}"}


async def handle_lua_check_cached(task, args: dict) -> dict:
    """
    Syntax check cached Lua file using local Lua/luac.

    Args:
        task: Task object
        args: {path: str}

    Returns:
        {ok: bool, error: str (if failed)}
    """
    import subprocess
    import tempfile

    path = args.get("path", "")

    if not path:
        return {"ok": False, "error": "Missing 'path' argument"}

    if path not in task.file_cache:
        return {"ok": False, "error": f"File '{path}' not in cache. Use fs_read first."}

    content = task.file_cache[path]

    try:
        # Write to temp file
        with tempfile.NamedTemporaryFile(mode='w', suffix='.lua', delete=False) as f:
            f.write(content)
            temp_path = f.name

        try:
            # Try luac first (syntax check only)
            result = subprocess.run(
                ['luac', '-p', temp_path],
                capture_output=True,
                text=True,
                timeout=5
            )

            if result.returncode == 0:
                return {"ok": True}
            else:
                # Parse error message
                error_msg = result.stderr.strip()
                return {"ok": False, "error": error_msg}

        except FileNotFoundError:
            # luac not found, try lua with loadfile
            return {"ok": False, "error": "luac not available on server - cannot syntax check"}
        finally:
            import os
            os.unlink(temp_path)

    except Exception as e:
        return {"ok": False, "error": f"Check error: {type(e).__name__}: {str(e)}"}


async def handle_diff_cached(task, args: dict) -> dict:
    """
    Show diff between cached versions or against provided text.

    Args:
        task: Task object
        args: {path: str, against: str, provided: str}

    Returns:
        {diff: str}
    """
    import difflib

    path = args.get("path", "")
    against = args.get("against", "original")  # "original" | "provided"
    provided_text = args.get("provided", "")

    if not path:
        return {"error": "Missing 'path' argument"}

    if path not in task.file_cache:
        return {"error": f"File '{path}' not in cache"}

    current_content = task.file_cache[path]

    if against == "provided":
        if not provided_text:
            return {"error": "Missing 'provided' text for diff"}
        other_content = provided_text
        label = "provided"
    else:
        # For now, "original" = cached (we'd need to track original separately)
        other_content = current_content
        label = "original"

    diff = "\n".join(difflib.unified_diff(
        other_content.splitlines(),
        current_content.splitlines(),
        fromfile=f"{path} ({label})",
        tofile=f"{path} (current)",
        lineterm=""
    ))

    return {"diff": diff}


async def handle_fs_write_cached(task, args: dict) -> dict:
    """
    Write cached file content back to CC by sending fs_write command.

    Args:
        task: Task object
        args: {path: str}

    Returns:
        Same as regular fs_write, but sent to CC
    """
    path = args.get("path", "")

    if not path:
        return {"ok": False, "error": "Missing 'path' argument"}

    if path not in task.file_cache:
        return {"ok": False, "error": f"File '{path}' not in cache. Use fs_read first."}

    content = task.file_cache[path]

    print(f"[CACHE_WRITE] Writing {len(content)} chars to '{path}' on CC")

    # Generate call ID
    call_id = str(uuid.uuid4())

    # Track pending command
    task_manager.set_pending_command(task.task_id, call_id, "fs_write")

    # Send fs_write to CC with cached content
    success = await ws_manager.send_to_client(task.client_id, {
        "type": "command_call",
        "task_id": task.task_id,
        "call_id": call_id,
        "command": "fs_write",
        "args": {"path": path, "content": content}
    })

    if success:
        print(f"[TOOL] fs_write_cached sent successfully, waiting for result...")
        # This will be handled like a normal CC-side command
        # The result will come back via handle_command_result
        return None  # Signal to batch executor to stop (waiting for CC)
    else:
        print(f"[TOOL] ERROR: Failed to send fs_write_cached to client {task.client_id}")
        return {"ok": False, "error": "Failed to send command to client"}


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

        # Planner (run once per task)
        if "plan" not in task.context:
            print("[PLANNER] Generating task plan...")
            plan_prompt = (
                f"Task: {task.prompt}\n\n"
                f"Available tools: {[t['name'] for t in tools]}\n"
                "Return a plan."
            )
            plan_result = await planner_agent.run(plan_prompt)
            task.context["plan"] = plan_result.data.model_dump()
            print(f"[PLANNER] Plan generated: {task.context['plan']['goal']}")

        # Coder tick (generates next ExecutorStep)
        print("[CODER] Deciding next action...")
        exec_prompt = (
            f"Task: {task.prompt}\n\n"
            f"Plan: {json.dumps(task.context['plan'], indent=2)}\n\n"
            f"Available tools: {json.dumps(tools)}\n\n"
            f"Conversation so far: {json.dumps(task.history[-30:], indent=2)}\n\n"
            "Return the next ExecutorStep."
        )

        step_result = await coder_agent.run(exec_prompt)
        decision = step_result.data
        print(f"[CODER] Decision status: {decision.status}")

        # Add coder's decision to history
        task.add_to_history({
            "role": "assistant",
            "content": json.dumps(decision.model_dump(), indent=2)
        })

        # Handle decision based on status
        if decision.status == "complete":
            print(f"[TASK] Task {task_id} complete")
            task_manager.complete_task(task_id, {"message": decision.final_message})
            await ws_manager.send_to_client(task.client_id, {
                "type": "task_completed",
                "task_id": task_id,
                "result": {"message": decision.final_message}
            })
            return

        if decision.status == "need_user":
            # Convert to ask_user tool call
            tool_calls = [{"tool": "ask_user", "arguments": {"question": decision.user_question}}]
        else:
            # status == "continue"
            tool_calls = [tc.model_dump() for tc in decision.tool_calls]

        print(f"[CODER] Tool calls to execute: {len(tool_calls)}")

        # Process all tool calls with batch executor
        await execute_tool_calls(task, tool_calls)

    except Exception as e:
        error_msg = f"{type(e).__name__}: {str(e)}"
        print(f"[TASK] Error processing task {task_id}: {error_msg}")
        print(f"[TASK] Full traceback:")
        traceback.print_exc()

        task_manager.fail_task(task_id, error_msg)

        # Send task_failed message
        await ws_manager.send_to_client(task.client_id, {
            "type": "task_failed",
            "task_id": task_id,
            "error": error_msg
        })


# ============================================================================
# Legacy Tool Execution (Single Tool - Not Used)
# ============================================================================

async def execute_tool_call_legacy(task, tool_call: dict):
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

    # Handle special orchestrator-only commands
    if command == "send_status":
        await handle_send_status(task, args)
        return

    if command == "ask_user":
        result = await handle_ask_user(task, args)
        if result and not result.get("ok"):
            # Invalid question - send error and continue task
            tool_result = llm_adapter.format_tool_result("ask_user", None, result.get("error"))
            task.add_to_history(tool_result)
            asyncio.create_task(process_task(task.task_id))
        return

    # Generate call ID for regular commands
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
    global agent_runner

    print("=" * 60)
    print("[STARTUP] CC LLM Agent Framework Orchestrator")
    print("=" * 60)
    print(f"[STARTUP] Planner Model: {config.planner_llm.model}")
    print(f"[STARTUP] Coder Model: {config.coder_llm.model}")
    print(f"[STARTUP] LLM Base URL: {config.llm.base_url}")
    print(f"[STARTUP] Temperature: {config.llm.temperature}")
    print(f"[STARTUP] Max Tokens: {config.llm.max_tokens}")
    print(f"[STARTUP] Available Task Kinds: {list(config.task_kinds.keys())}")

    # Initialize LangGraph and AgentRunner
    print("[STARTUP] Building LangGraph...")
    agent_graph = build_agent_graph(task_manager, ws_manager, config, execute_tool_calls)
    agent_runner = AgentRunner(agent_graph)
    print("[STARTUP] AgentRunner initialized")

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
