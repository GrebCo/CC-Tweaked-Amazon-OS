from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi import HTTPException
from pydantic import BaseModel
from fastapi import status
from fastapi.responses import HTMLResponse, StreamingResponse
import uvicorn
import json
import asyncio
import time
from typing import Dict, List

from fastapi.middleware.cors import CORSMiddleware

app = FastAPI()

class PostPacket(BaseModel):
    message: str
    name: str

class AckPacket(BaseModel):
    id: int

# WebSocket connection manager
class ConnectionManager:
    def __init__(self):
        # Maps server name to list of active WebSocket connections
        self.active_connections: Dict[str, List[WebSocket]] = {}
        # Event queues for SSE clients
        self.ack_queues: Dict[str, List[asyncio.Queue]] = {}

    async def connect(self, websocket: WebSocket, server_name: str):
        await websocket.accept()
        if server_name not in self.active_connections:
            self.active_connections[server_name] = []
        self.active_connections[server_name].append(websocket)
        print(f"WebSocket connected for server: {server_name}")

    def disconnect(self, websocket: WebSocket, server_name: str):
        if server_name in self.active_connections:
            self.active_connections[server_name].remove(websocket)
            if len(self.active_connections[server_name]) == 0:
                del self.active_connections[server_name]
        print(f"WebSocket disconnected for server: {server_name}")

    async def send_message(self, server_name: str, message: dict):
        """Send a message to all WebSocket clients connected to this server"""
        if server_name in self.active_connections:
            for connection in self.active_connections[server_name]:
                try:
                    await connection.send_json(message)
                except Exception as e:
                    print(f"Error sending to WebSocket: {e}")

    def add_ack_queue(self, server_name: str, queue: asyncio.Queue):
        """Add an SSE client queue for ack notifications"""
        if server_name not in self.ack_queues:
            self.ack_queues[server_name] = []
        self.ack_queues[server_name].append(queue)

    def remove_ack_queue(self, server_name: str, queue: asyncio.Queue):
        """Remove an SSE client queue"""
        if server_name in self.ack_queues:
            if queue in self.ack_queues[server_name]:
                self.ack_queues[server_name].remove(queue)
            if len(self.ack_queues[server_name]) == 0:
                del self.ack_queues[server_name]

    async def broadcast_ack(self, server_name: str, msg_id: int):
        """Broadcast ack to all SSE clients listening for this server"""
        print(f"[ACK] Broadcasting ack for message {msg_id} on server {server_name}")
        print(f"[ACK] Active SSE queues: {list(self.ack_queues.keys())}")
        if server_name in self.ack_queues:
            print(f"[ACK] Found {len(self.ack_queues[server_name])} SSE clients")
            for queue in self.ack_queues[server_name]:
                try:
                    await queue.put({"type": "ack", "id": msg_id})
                    print(f"[ACK] Sent ack to SSE client")
                except Exception as e:
                    print(f"[ACK] Error broadcasting ack: {e}")
        else:
            print(f"[ACK] No SSE clients listening for server {server_name}")

    async def broadcast_failed(self, server_name: str, msg_id: int):
        """Broadcast failure to all SSE clients listening for this server"""
        print(f"[FAIL] Broadcasting failure for message {msg_id} on server {server_name}")
        if server_name in self.ack_queues:
            for queue in self.ack_queues[server_name]:
                try:
                    await queue.put({"type": "failed", "id": msg_id})
                    print(f"[FAIL] Sent failure to SSE client")
                except Exception as e:
                    print(f"[FAIL] Error broadcasting failure: {e}")

manager = ConnectionManager()

messages = {
    "CraftoriaNA":
    [

    ],
    "CraftoriaEU":
    [
        #there is nothing here because noone plays EU
    ]
}

origins = [
"http://localhost:3000",
"http://localhost:5173",
]


app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

nextid = 3


@app.get("/", response_class=HTMLResponse)
async def root():
    return """
    <!DOCTYPE html>
    <html>
      <head>
        <meta charset="utf-8" />
        <title>CC Remote Chat</title>
        <style>
          body { font-family: sans-serif; max-width: 600px; margin: 2rem auto; }
          input[type="text"] { padding: 0.3rem; }
          .row { margin-bottom: 0.5rem; }
          .messages { margin-top: 1rem; padding: 0.5rem; border: 1px solid #ccc; }
          .msg-id { opacity: 0.6; font-size: 0.8rem; }
        </style>
      </head>
      <body>
        <h1>CC Remote Chat</h1>

        <div class="row">
          <label>
            Server:
            <input id="serverName" type="text" value="CraftoriaNA" />
          </label>
        </div>

        <div class="row">
          <label>
            Name:
            <input id="name" type="text" value="RemoteElliot" />
          </label>
        </div>

        <div class="row">
          <label>
            Message:
            <input id="message" type="text" placeholder="Type a message to send in-game" style="width: 100%;" />
          </label>
        </div>

        <div class="row">
          <button id="sendBtn">Send</button>
          <button id="refreshBtn">Refresh messages (debug)</button>
        </div>

        <p id="status"></p>

        <div class="messages">
          <strong>Queued messages:</strong>
          <ul id="messagesList"></ul>
        </div>

        <script>
          const statusEl = document.getElementById("status");
          const messagesList = document.getElementById("messagesList");
          const serverInput = document.getElementById("serverName");
          const nameInput = document.getElementById("name");
          const messageInput = document.getElementById("message");
          const sendBtn = document.getElementById("sendBtn");
          const refreshBtn = document.getElementById("refreshBtn");

          function setStatus(text) {
            statusEl.textContent = text;
          }

          async function sendMessage() {
            const serverName = serverInput.value.trim();
            const name = nameInput.value.trim();
            const message = messageInput.value.trim();

            if (!serverName || !name || !message) {
              setStatus("Server, name, and message are required.");
              return;
            }

            setStatus("Sending...");

            try {
              const res = await fetch(`/api/messages/${encodeURIComponent(serverName)}`, {
                method: "POST",
                headers: {
                  "Content-Type": "application/json"
                },
                body: JSON.stringify({ message: message, name: name })
              });

              if (!res.ok) {
                const data = await res.json().catch(() => ({}));
                setStatus(`Error: ${res.status} ${data.detail || ""}`);
                return;
              }

              setStatus("Sent!");
              messageInput.value = "";
              await refreshMessages();  // optional: update list after send
            } catch (err) {
              console.error(err);
              setStatus("Network error while sending.");
            }
          }

          async function refreshMessages() {
            const serverName = serverInput.value.trim();
            if (!serverName) {
              setStatus("Server name is required to load messages.");
              return;
            }

            setStatus("Loading messages...");

            try {
              const res = await fetch(`/api/messages/${encodeURIComponent(serverName)}`);

              if (res.status === 404) {
                messagesList.innerHTML = "";
                setStatus("No messages for this server.");
                return;
              }

              if (!res.ok) {
                const data = await res.json().catch(() => ({}));
                setStatus(`Error: ${res.status} ${data.detail || ""}`);
                return;
              }

              const data = await res.json();
              messagesList.innerHTML = "";

              if (Array.isArray(data)) {
                data.forEach(m => {
                  const li = document.createElement("li");
                  li.innerHTML = `<strong>${m.name}:</strong> ${m.message} <span class="msg-id">(id: ${m.id})</span>`;
                  messagesList.appendChild(li);
                });
                setStatus(`Loaded ${data.length} message(s).`);
              } else {
                setStatus("Unexpected response format.");
              }
            } catch (err) {
              console.error(err);
              setStatus("Network error while loading messages.");
            }
          }

          sendBtn.addEventListener("click", (e) => {
            e.preventDefault();
            sendMessage();
          });

          refreshBtn.addEventListener("click", (e) => {
            e.preventDefault();
            refreshMessages();
          });

          // Optional: load messages initially
          // refreshMessages();
        </script>
      </body>
    </html>
    """

#Client wants to post a new message on some Minecraft server
#Packet will be a string : message, string : name
@app.post("/api/messages/{serverName}", status_code=status.HTTP_201_CREATED)
async def postMessagePacket(serverName: str, packet: PostPacket):

    global nextid

    if serverName not in messages: #check dict to make sure we have the key, if not make it
        messages[serverName] = []

    msg = {
        "id": nextid,
        "message": packet.message,
        "name": packet.name,
        "timestamp": time.time(),  # Add timestamp for expiration
    }

    nextid += 1
    messages[serverName].append(msg)

    # Push to WebSocket clients immediately
    await manager.send_message(serverName, {
        "type": "new_message",
        "data": msg
    })

    return {"detail": "Message added", "id": msg["id"]}


#CC computer wants to get any new messages that are queued for it's server
#Packet will just be a string : Servername and will return all messages for that server and clear them

@app.get("/api/messages/{serverName}")
async def getMessagePacket(serverName: str):
    print(serverName)
    if serverName in messages:
        return messages[serverName]
    else:
        raise HTTPException(status_code=404, detail="No messages for this server")

@app.get("/api/status/{serverName}")
async def getServerStatus(serverName: str):
    """Check if a CC computer is connected via WebSocket for this server"""
    is_connected = serverName in manager.active_connections and len(manager.active_connections[serverName]) > 0
    connection_count = len(manager.active_connections.get(serverName, []))
    queued_count = len(messages.get(serverName, []))

    return {
        "server": serverName,
        "cc_connected": is_connected,
        "connection_count": connection_count,
        "queued_messages": queued_count
    }

@app.post("/api/messages/{serverName}/ack", status_code=status.HTTP_202_ACCEPTED)
async def ack_messages(serverName: str, ack: AckPacket): #this is for the CC computer to acknowlege that the message was sent and the webserver will delete that entry
    if serverName not in messages:
        raise HTTPException(status_code=404, detail="Server not found")

    id = ack.id

    for index, msg in enumerate(messages[serverName]):
        if msg["id"] == id:
            messages[serverName].pop(index)
            return {"detail": "Message acknowledged"}
    raise HTTPException(status_code=404, detail="id not found")

# Server-Sent Events endpoint for frontend to receive ack notifications
@app.get("/api/events/{serverName}")
async def sse_endpoint(serverName: str):
    print(f"[SSE] New client connected for server: {serverName}")
    async def event_generator():
        queue = asyncio.Queue()
        manager.add_ack_queue(serverName, queue)
        print(f"[SSE] Added queue for {serverName}, total queues: {len(manager.ack_queues.get(serverName, []))}")
        try:
            # Send a keepalive comment immediately
            yield ": keepalive\n\n"

            while True:
                try:
                    # Wait for ack events with timeout to send keepalives
                    event = await asyncio.wait_for(queue.get(), timeout=15.0)
                    print(f"[SSE] Sending event to client: {event}")
                    yield f"data: {json.dumps(event)}\n\n"
                except asyncio.TimeoutError:
                    # Send keepalive comment every 15 seconds
                    yield ": keepalive\n\n"
        except asyncio.CancelledError:
            print(f"[SSE] Client disconnected for server: {serverName}")
            manager.remove_ack_queue(serverName, queue)
            raise
        except Exception as e:
            print(f"[SSE] Error in event generator: {e}")
            manager.remove_ack_queue(serverName, queue)
            raise

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        }
    )

# WebSocket endpoint for CC computers to connect and receive real-time messages
@app.websocket("/ws/{serverName}")
async def websocket_endpoint(websocket: WebSocket, serverName: str):
    await manager.connect(websocket, serverName)
    try:
        # Send any existing queued messages immediately upon connection
        if serverName in messages and messages[serverName]:
            await websocket.send_json({
                "type": "queued_messages",
                "data": messages[serverName]
            })

        # Keep connection alive and handle incoming messages (like acks)
        while True:
            data = await websocket.receive_json()

            # Handle ack from CC computer
            if data.get("type") == "ack":
                msg_id = data.get("id")
                print(f"[WS] Received ack for message {msg_id} on server {serverName}")
                if serverName in messages:
                    for index, msg in enumerate(messages[serverName]):
                        if msg["id"] == msg_id:
                            messages[serverName].pop(index)
                            print(f"[WS] Message {msg_id} removed from queue")
                            # Broadcast ack to frontend clients
                            await manager.broadcast_ack(serverName, msg_id)
                            await websocket.send_json({
                                "type": "ack_confirmed",
                                "id": msg_id
                            })
                            break

    except WebSocketDisconnect:
        manager.disconnect(websocket, serverName)
    except Exception as e:
        print(f"WebSocket error: {e}")
        manager.disconnect(websocket, serverName)

async def cleanup_expired_messages():
    """Background task to remove messages older than 60 seconds and notify frontend"""
    MESSAGE_TIMEOUT = 60  # seconds
    while True:
        await asyncio.sleep(10)  # Check every 10 seconds
        current_time = time.time()

        for server_name, msg_list in list(messages.items()):
            expired = []
            for msg in msg_list[:]:  # Create a copy to iterate
                if current_time - msg.get("timestamp", current_time) > MESSAGE_TIMEOUT:
                    print(f"[CLEANUP] Message {msg['id']} expired on {server_name}")
                    expired.append(msg)
                    msg_list.remove(msg)
                    # Notify frontend that this message failed
                    await manager.broadcast_failed(server_name, msg["id"])

            if expired:
                print(f"[CLEANUP] Removed {len(expired)} expired messages from {server_name}")

@app.on_event("startup")
async def startup_event():
    """Start background tasks on server startup"""
    asyncio.create_task(cleanup_expired_messages())
    print("[STARTUP] Background cleanup task started")

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)