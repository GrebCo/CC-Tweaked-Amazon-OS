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

    # Continue processing the task
    print(f"[RESULT] Continuing task processing...")
    asyncio.create_task(process_task(task_id))


# ============================================================================
# Tool Execution - Batching Support
# ============================================================================

async def execute_tool_calls(task, tool_calls: List[dict]):
    """
    Execute a list of tool calls in order, batching server-side tools and stopping at first CC-side tool.

    Server-side/immediate tools (send_status, future: patch_cached, lua_check_cached):
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
                # Invalid question - send error and continue task
                tool_result = llm_adapter.format_tool_result("ask_user", None, result.get("error"))
                task.add_to_history(tool_result)
                asyncio.create_task(process_task(task.task_id))
            return  # Stop batch execution (either waiting for response or gave error)

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
                return
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
        else:
            print(f"[TOOL] ERROR: Failed to send command to client {task.client_id}")

        # STOP batch execution - we must wait for command_result
        return

    # If we get here, all tools were server-side - continue processing
    print(f"[BATCH] All {len(tool_calls)} tools completed, continuing task...")
    asyncio.create_task(process_task(task.task_id))


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

    # Only auto-continue if not in batch mode
    if continue_processing:
        asyncio.create_task(process_task(task.task_id))


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
        parse_errors = response.get("parse_errors", [])
        print(f"[LLM] Tool calls found: {len(tool_calls)}")

        # If there are parse errors, ALWAYS send them back to the LLM
        if parse_errors:
            print(f"[PARSE] Sending {len(parse_errors)} parse errors back to LLM")
            error_msg = "[SYSTEM ERROR] Your response contained JSON formatting errors:\n\n"
            for i, err in enumerate(parse_errors, 1):
                error_msg += f"{i}. {err}\n"
            error_msg += "\nCOMMON MISTAKES:\n"
            error_msg += "1. Missing content value: {\"content\"}} ← WRONG (no value after content)\n"
            error_msg += "   Correct: {\"content\":\"print(\\\"Hello\\\")\"} ← RIGHT (has value)\n\n"
            error_msg += "2. Using equals instead of colon: {\"content\"=\"text\"} ← WRONG\n"
            error_msg += "   Correct: {\"content\":\"text\"} ← RIGHT\n\n"
            error_msg += "3. For files with code, you MUST include the full code as a string in the JSON:\n"
            error_msg += "   {\"tool\":\"fs_write\",\"arguments\":{\"path\":\"file.lua\",\"content\":\"local x = 5\\nprint(x)\"}}\n\n"
            error_msg += "Please fix these errors and try again. Do NOT run programs that don't exist yet - create them first!"

            task.add_to_history({
                "role": "user",
                "content": error_msg
            })

            # Reset consecutive errors since we're giving feedback
            task.consecutive_errors = 0

            # Re-process task to let LLM try again
            asyncio.create_task(process_task(task_id))
            return

        if not tool_calls:
            # Check if this is truly a completion or if the model forgot to call tools
            # A legitimate completion has explanatory text like "I created..." or "The task is complete..."
            # An illegitimate non-completion has prompting text like "Let's get started" or acknowledgments

            response_lower = response["content"].lower()
            suspicious_phrases = [
                "let's get started",
                "let's begin",
                "i'll follow",
                "i understand",
                "understood!",
                "i will",
                "shall we",
                "ready to",
                "waiting for"
            ]

            # Check if response is just giving code examples instead of creating files
            has_code_block = "```lua" in response["content"] or "```json" in response["content"]
            has_example_language = any(phrase in response_lower for phrase in [
                "here's a",
                "here is a",
                "simplified version",
                "example",
                "you can use",
                "this code"
            ])

            is_suspicious = any(phrase in response_lower for phrase in suspicious_phrases)
            has_completion_markers = any(marker in response_lower for marker in [
                "created",
                "completed",
                "finished",
                "done",
                "successfully",
                "verified",
                "tested",
                "working"
            ])

            # If giving code examples without tool calls, that's wrong
            is_code_example_without_action = has_code_block and has_example_language and not has_completion_markers

            if (is_suspicious or is_code_example_without_action) and not has_completion_markers and len(task.history) < 8:
                # This looks like the model acknowledging instructions without doing work
                print(f"[TASK] Model responded without tool calls but task is not complete!")

                if is_code_example_without_action:
                    error_msg = "[SYSTEM ERROR] You gave a code example instead of using tools.\n\n"
                    error_msg += "You wrote code in markdown format but DID NOT call fs_write to create the file.\n\n"
                    error_msg += "WRONG: Writing ```lua code ``` in your response\n"
                    error_msg += "RIGHT: Using ```json tool calls ``` to CREATE the file\n\n"
                    error_msg += "Do this instead:\n"
                    error_msg += "```json\n"
                    error_msg += "{\"tool\":\"fs_write\",\"arguments\":{\"path\":\"file.lua\",\"content\":\"<full lua code here>\"}}\n"
                    error_msg += "```\n"
                    error_msg += "```json\n"
                    error_msg += "{\"tool\":\"run_program\",\"arguments\":{\"path\":\"file.lua\",\"args\":[]}}\n"
                    error_msg += "```\n\n"
                    error_msg += "You are not a tutor showing examples. You are an ENGINEER who CREATES working files."
                else:
                    error_msg = "[SYSTEM ERROR] You responded without calling any tools.\n\n"
                    error_msg += "Your response was: \"" + response["content"][:200] + "\"\n\n"
                    error_msg += "This is FORBIDDEN. EVERY response must include at least one tool call in ```json format.\n\n"
                    error_msg += "The user asked you to complete a task. You must START WORKING IMMEDIATELY by calling tools.\n"
                    error_msg += "Do NOT acknowledge or explain - just start calling tools to complete the task.\n\n"
                    error_msg += "Example of what you should do:\n"
                    error_msg += "```json\n"
                    error_msg += "{\"tool\":\"fs_write\",\"arguments\":{\"path\":\"file.lua\",\"content\":\"print('hello')\"}}\n"
                    error_msg += "```\n"
                    error_msg += "```json\n"
                    error_msg += "{\"tool\":\"run_program\",\"arguments\":{\"path\":\"file.lua\",\"args\":[]}}\n"
                    error_msg += "```"

                task.add_to_history({
                    "role": "user",
                    "content": error_msg
                })

                # Re-process task
                asyncio.create_task(process_task(task_id))
                return

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
