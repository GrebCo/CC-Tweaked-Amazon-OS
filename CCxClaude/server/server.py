"""
CCxClaude Server

FastAPI server bridging Claude Code (HTTP/curl) with ComputerCraft computers (WebSocket).
"""

from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import asyncio
import json
import uuid
import logging
from datetime import datetime
from typing import Optional
from collections import deque

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s'
)
logger = logging.getLogger(__name__)

app = FastAPI(title="CCxClaude Server")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Connected clients: name -> WebSocket
clients: dict[str, WebSocket] = {}

# Output buffers: name -> deque of output lines (last 1000)
output_buffers: dict[str, deque] = {}

# Pending requests: request_id -> asyncio.Future
pending_requests: dict[str, asyncio.Future] = {}

# Request timeout in seconds
REQUEST_TIMEOUT = 30


class ExecRequest(BaseModel):
    tool: str
    args: dict = {}


class ClientInfo(BaseModel):
    name: str
    connected_at: str


# Store connection times
client_connect_times: dict[str, str] = {}


# =============================================================================
# REST API Endpoints (for Claude to call via curl)
# =============================================================================

@app.get("/")
async def root():
    """Root endpoint for health check."""
    return {"status": "ok", "clients": len(clients)}


@app.get("/clients")
async def list_clients() -> list[ClientInfo]:
    """List all connected CC clients."""
    return [
        ClientInfo(name=name, connected_at=client_connect_times.get(name, "unknown"))
        for name in clients.keys()
    ]


@app.post("/exec/{client_name}")
async def execute_tool(client_name: str, request: ExecRequest):
    """
    Execute a tool on a specific CC client.
    Blocks until the client responds or timeout.
    """
    if client_name not in clients:
        raise HTTPException(status_code=404, detail=f"Client '{client_name}' not connected")

    ws = clients[client_name]
    request_id = str(uuid.uuid4())

    # Create future for response
    future = asyncio.get_event_loop().create_future()
    pending_requests[request_id] = future

    try:
        # Send command to CC client
        await ws.send_json({
            "type": "exec",
            "request_id": request_id,
            "tool": request.tool,
            "args": request.args
        })

        logger.info(f"Sent {request.tool} to {client_name} (req: {request_id[:8]})")

        # Wait for response with timeout
        result = await asyncio.wait_for(future, timeout=REQUEST_TIMEOUT)
        return result

    except asyncio.TimeoutError:
        raise HTTPException(status_code=504, detail=f"Request timed out after {REQUEST_TIMEOUT}s")
    finally:
        pending_requests.pop(request_id, None)


@app.get("/output/{client_name}")
async def get_output(client_name: str, clear: bool = False) -> dict:
    """
    Get buffered output from a CC client.

    Args:
        client_name: Name of the client
        clear: If true, clear the buffer after returning
    """
    if client_name not in output_buffers:
        return {"output": [], "count": 0}

    output = list(output_buffers[client_name])

    if clear:
        output_buffers[client_name].clear()

    return {"output": output, "count": len(output)}


@app.delete("/output/{client_name}")
async def clear_output(client_name: str):
    """Clear the output buffer for a client."""
    if client_name in output_buffers:
        output_buffers[client_name].clear()
    return {"status": "cleared"}


@app.delete("/clients/{client_name}")
async def remove_client(client_name: str):
    """Manually remove a stale client."""
    if client_name not in clients:
        raise HTTPException(status_code=404, detail=f"Client '{client_name}' not found")

    # Try to close the websocket
    ws = clients.pop(client_name, None)
    if ws:
        try:
            await ws.close()
        except:
            pass

    client_connect_times.pop(client_name, None)
    output_buffers.pop(client_name, None)
    logger.info(f"Client '{client_name}' manually removed")

    return {"status": "removed", "name": client_name}


# =============================================================================
# WebSocket Endpoint (for CC clients)
# =============================================================================

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    """WebSocket endpoint for CC clients to connect."""
    await websocket.accept()
    client_name: Optional[str] = None

    try:
        while True:
            data = await websocket.receive_text()
            message = json.loads(data)
            msg_type = message.get("type")

            if msg_type == "login":
                # Client logging in with a name
                name = message.get("name", "").strip()

                if not name:
                    await websocket.send_json({
                        "type": "error",
                        "message": "Name cannot be empty"
                    })
                    continue

                if name in clients:
                    await websocket.send_json({
                        "type": "error",
                        "message": f"Name '{name}' already in use"
                    })
                    continue

                # Register client
                client_name = name
                clients[name] = websocket
                client_connect_times[name] = datetime.now().isoformat()
                output_buffers[name] = deque(maxlen=1000)

                await websocket.send_json({
                    "type": "login_ok",
                    "message": f"Logged in as '{name}'"
                })

                logger.info(f"Client '{name}' connected")

            elif msg_type == "result":
                # Response to an exec request
                request_id = message.get("request_id")
                if request_id in pending_requests:
                    future = pending_requests[request_id]
                    if not future.done():
                        future.set_result({
                            "ok": message.get("ok", False),
                            "result": message.get("result"),
                            "error": message.get("error")
                        })

            elif msg_type == "output":
                # Output/print from CC client
                if client_name and client_name in output_buffers:
                    text = message.get("text", "")
                    output_buffers[client_name].append({
                        "time": datetime.now().isoformat(),
                        "text": text
                    })

            elif msg_type == "ping":
                await websocket.send_json({"type": "pong"})

    except WebSocketDisconnect:
        pass
    except Exception as e:
        logger.error(f"WebSocket error: {e}")
    finally:
        if client_name:
            clients.pop(client_name, None)
            client_connect_times.pop(client_name, None)
            logger.info(f"Client '{client_name}' disconnected")


# =============================================================================
# Main
# =============================================================================

if __name__ == "__main__":
    import uvicorn
    print("=" * 50)
    print("CCxClaude Server")
    print("=" * 50)
    print("REST API: http://localhost:8000")
    print("WebSocket: ws://localhost:8000/ws")
    print("=" * 50)
    uvicorn.run(app, host="0.0.0.0", port=8000)
