"""
WebSocket Manager Module

Manages WebSocket connections from CC clients, handles message routing,
and provides helper functions for sending messages to clients.
"""

from typing import Dict, Optional
from fastapi import WebSocket
import json


class WebSocketManager:
    """Manages WebSocket connections to CC clients."""

    def __init__(self):
        # Maps client_id to WebSocket connection
        self.connections: Dict[str, WebSocket] = {}

    async def connect(self, client_id: str, websocket: WebSocket):
        """
        Accept and store a new WebSocket connection.

        Args:
            client_id: Unique identifier for the client
            websocket: WebSocket connection object
        """
        await websocket.accept()
        self.connections[client_id] = websocket
        print(f"[WS] Client '{client_id}' connected. Total clients: {len(self.connections)}")

    def disconnect(self, client_id: str):
        """
        Remove a client connection.

        Args:
            client_id: Unique identifier for the client
        """
        if client_id in self.connections:
            del self.connections[client_id]
            print(f"[WS] Client '{client_id}' disconnected. Total clients: {len(self.connections)}")

    async def send_to_client(self, client_id: str, message: dict) -> bool:
        """
        Send a message to a specific client.

        Args:
            client_id: Target client identifier
            message: Dictionary message to send (will be JSON serialized)

        Returns:
            True if sent successfully, False otherwise
        """
        print(f"[WS] Attempting to send to client '{client_id}'")
        print(f"[WS] Connected clients: {list(self.connections.keys())}")

        if client_id not in self.connections:
            print(f"[WS] [ERROR] Cannot send to '{client_id}': not connected")
            print(f"[WS] Available clients: {list(self.connections.keys())}")
            return False

        try:
            websocket = self.connections[client_id]
            json_str = json.dumps(message)
            print(f"[WS] Sending message: {json_str[:200]}...")
            await websocket.send_text(json_str)
            print(f"[WS] [OK] Message sent to '{client_id}'")
            return True
        except Exception as e:
            print(f"[WS] [ERROR] Error sending to client '{client_id}': {e}")
            import traceback
            traceback.print_exc()
            return False

    def is_connected(self, client_id: str) -> bool:
        """
        Check if a client is currently connected.

        Args:
            client_id: Client identifier to check

        Returns:
            True if connected, False otherwise
        """
        return client_id in self.connections

    def get_connected_clients(self) -> list[str]:
        """
        Get list of all connected client IDs.

        Returns:
            List of client identifiers
        """
        return list(self.connections.keys())
