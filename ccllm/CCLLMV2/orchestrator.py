"""
orchestrator.py

FastAPI WebSocket server for ComputerCraft LLM Agent.
Integrates PydanticAI agent with WebSocket communication.
"""

from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.responses import JSONResponse
from contextlib import asynccontextmanager
import asyncio
import json
import uuid
import logging
import os
from datetime import datetime
from typing import Optional

from websocket_manager import WebSocketManager
from cc_agent_v2 import (
    create_cc_agent,
    create_planner_agent,
    create_executor_agent,
    CCAgentDeps,
    execute_task_with_agent,
    execute_task_with_two_agents
)
from ws_tools import call_cc_command

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[
        logging.FileHandler(f'orchestrator_{datetime.now().strftime("%Y%m%d_%H%M%S")}.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifespan event handler for startup and shutdown."""
    # Startup
    logger.info("=" * 60)
    logger.info("CC LLM Agent Orchestrator - Two-Agent Architecture")
    logger.info("=" * 60)
    logger.info("Architecture: PlannerAgent + ExecutorAgent")
    logger.info("Model: qwen2.5-coder:14b")
    logger.info("WebSocket endpoint: ws://localhost:8000/ws/{client_id}")
    logger.info("Ready to accept connections!")
    logger.info("=" * 60)

    yield

    # Shutdown (if needed in future)
    logger.info("Shutting down orchestrator...")


app = FastAPI(
    title="CC LLM Agent Orchestrator",
    lifespan=lifespan
)

# WebSocket manager
ws_manager = WebSocketManager()

# Active tasks: task_id -> task info
active_tasks: dict[str, dict] = {}

# Pending command results: (task_id, call_id) -> asyncio.Future
pending_results: dict[tuple[str, str], asyncio.Future] = {}


# ============================================================================
# WebSocket Endpoint
# ============================================================================


@app.websocket("/ws/{client_id}")
async def websocket_endpoint(websocket: WebSocket, client_id: str):
    """
    WebSocket endpoint for CC clients.

    Args:
        websocket: WebSocket connection
        client_id: Unique identifier for the CC client
    """
    await ws_manager.connect(client_id, websocket)
    logger.info(f"Client '{client_id}' connected")

    try:
        while True:
            # Receive message from client
            data = await websocket.receive_text()
            message = json.loads(data)
            message_type = message.get("type")

            logger.info(f"Received from {client_id}: {message_type}")

            if message_type == "create_task":
                # Handle task creation
                await handle_create_task(message, client_id)

            elif message_type == "command_result":
                # Handle command result from CC
                await handle_command_result(message)

            elif message_type == "ping":
                # Respond to ping
                await ws_manager.send_to_client(client_id, {"type": "pong"})

    except WebSocketDisconnect:
        ws_manager.disconnect(client_id)
        logger.info(f"Client '{client_id}' disconnected")
    except Exception as e:
        logger.error(f"Error in websocket for {client_id}: {e}")
        ws_manager.disconnect(client_id)


# ============================================================================
# Message Handlers
# ============================================================================


async def handle_create_task(message: dict, client_id: str):
    """
    Handle task creation request from CC client.

    Args:
        message: Message dict with request_id, prompt, etc.
        client_id: Client identifier
    """
    try:
        request_id = message["request_id"]
        prompt = message["prompt"]
        task_id = str(uuid.uuid4())

        logger.info(f"Creating task {task_id} for client {client_id}")
        logger.info(f"Prompt: {prompt}")

        # Send task_created response
        await ws_manager.send_to_client(client_id, {
            "type": "task_created",
            "request_id": request_id,
            "task_id": task_id,
            "status": "running"
        })

        # Start task processing in background
        asyncio.create_task(process_task(task_id, prompt, client_id))

    except Exception as e:
        logger.error(f"Error creating task: {e}")
        await ws_manager.send_to_client(client_id, {
            "type": "error",
            "message": f"Failed to create task: {str(e)}"
        })


async def handle_command_result(message: dict):
    """
    Handle command result from CC client.

    Args:
        message: Message dict with task_id, call_id, ok, result/error
    """
    task_id = message["task_id"]
    call_id = message["call_id"]
    ok = message["ok"]

    logger.info(f"Command result for task {task_id}, call {call_id}: ok={ok}")

    # Find the pending future
    key = (task_id, call_id)
    if key in pending_results:
        future = pending_results[key]

        if ok:
            result = message.get("result", {})
            future.set_result(result)
        else:
            error = message.get("error", "Unknown error")
            future.set_exception(Exception(error))

        # Clean up
        del pending_results[key]
    else:
        logger.warning(f"Received result for unknown call: {key}")


# ============================================================================
# Task Processing
# ============================================================================


async def process_task(task_id: str, prompt: str, client_id: str):
    """
    Process a task using the PydanticAI agent.

    Args:
        task_id: Task identifier
        prompt: User's task description
        client_id: CC client identifier
    """
    logger.info(f"Starting task {task_id}")

    # Store task info
    active_tasks[task_id] = {
        "task_id": task_id,
        "client_id": client_id,
        "status": "running",
        "prompt": prompt
    }

    try:
        # Create agents (two-agent architecture)
        planner = create_planner_agent()
        executor = create_executor_agent()

        # Create dependencies with WebSocket support
        deps = CCAgentDeps(
            mode="websocket",
            ws_client={
                "task_id": task_id,
                "client_id": client_id,
                "ws_manager": ws_manager,
                "pending_results": pending_results
            },
            task_id=task_id
        )

        # Run task with two-agent execution loop
        final_response = await execute_task_with_two_agents(planner, executor, prompt, deps)

        # Task completed successfully
        logger.info(f"Task {task_id} completed successfully")

        await ws_manager.send_to_client(client_id, {
            "type": "task_completed",
            "task_id": task_id,
            "result": {
                "success": final_response.success,
                "message": final_response.message,
                "details": final_response.details
            }
        })

        active_tasks[task_id]["status"] = "completed"

    except Exception as e:
        logger.error(f"Task {task_id} failed: {e}")
        import traceback
        traceback.print_exc()

        await ws_manager.send_to_client(client_id, {
            "type": "task_failed",
            "task_id": task_id,
            "error": str(e)
        })

        active_tasks[task_id]["status"] = "failed"


# ============================================================================
# HTTP Endpoints
# ============================================================================


@app.get("/")
async def root():
    """Root endpoint."""
    return {
        "name": "CC LLM Agent Orchestrator",
        "version": "2.0.0",
        "status": "running"
    }


@app.get("/status")
async def get_status():
    """Get system status."""
    return {
        "connected_clients": len(ws_manager.get_connected_clients()),
        "active_tasks": len([t for t in active_tasks.values() if t["status"] == "running"]),
        "total_tasks": len(active_tasks)
    }


@app.get("/tasks")
async def get_tasks():
    """Get all tasks."""
    return {"tasks": list(active_tasks.values())}


@app.get("/tasks/{task_id}")
async def get_task(task_id: str):
    """Get specific task."""
    if task_id not in active_tasks:
        return JSONResponse(status_code=404, content={"error": "Task not found"})
    return active_tasks[task_id]


# ============================================================================
# Server Entry Point
# ============================================================================


if __name__ == "__main__":
    import uvicorn

    # Get the directory containing this file for auto-reload watching
    current_dir = os.path.dirname(os.path.abspath(__file__))

    uvicorn.run(
        "orchestrator:app",  # Pass as import string for reload to work
        host="0.0.0.0",
        port=8000,
        reload=True,  # Auto-reload on code changes
        reload_dirs=[current_dir],  # Watch this directory
        log_level="info"
    )
