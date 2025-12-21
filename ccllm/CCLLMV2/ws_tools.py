"""
ws_tools.py

WebSocket tool helper functions for calling CC computer commands.
"""

import asyncio
import uuid
import logging

logger = logging.getLogger(__name__)


async def call_cc_command(
    ws_client: dict,
    command: str,
    args: dict,
    timeout: float = 30.0
) -> dict:
    """
    Call a command on the CC computer via WebSocket and wait for result.

    Args:
        ws_client: WebSocket client info dict containing:
            - task_id: Task identifier
            - client_id: CC client identifier
            - ws_manager: WebSocketManager instance
            - pending_results: Dict to track pending results
        command: Command name (e.g., "fs_read", "run_program")
        args: Command arguments
        timeout: Timeout in seconds

    Returns:
        Command result dict

    Raises:
        Exception: If command fails or times out
    """
    task_id = ws_client["task_id"]
    client_id = ws_client["client_id"]
    ws_manager = ws_client["ws_manager"]
    pending_results = ws_client["pending_results"]

    # Generate call ID
    call_id = str(uuid.uuid4())

    logger.info(f"Calling {command} on {client_id} (call {call_id})")

    # Create future for result
    future = asyncio.Future()
    pending_results[(task_id, call_id)] = future

    # Send command to CC
    success = await ws_manager.send_to_client(client_id, {
        "type": "command_call",
        "task_id": task_id,
        "call_id": call_id,
        "command": command,
        "args": args
    })

    if not success:
        del pending_results[(task_id, call_id)]
        raise Exception(f"Failed to send command to client {client_id}")

    try:
        # Wait for result with timeout
        result = await asyncio.wait_for(future, timeout=timeout)
        logger.info(f"Command {command} completed successfully")
        return result
    except asyncio.TimeoutError:
        # Clean up on timeout
        if (task_id, call_id) in pending_results:
            del pending_results[(task_id, call_id)]
        raise Exception(f"Command {command} timed out after {timeout}s")
