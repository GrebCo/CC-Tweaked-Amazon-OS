#!/usr/bin/env python3
"""
Convenience script to run the CC LLM Agent Framework orchestrator.
"""

import uvicorn

if __name__ == "__main__":
    print("=" * 60)
    print("CC LLM Agent Framework - Orchestrator")
    print("=" * 60)
    print()
    print("Starting server on http://0.0.0.0:8000")
    print("WebSocket endpoint: ws://0.0.0.0:8000/ws/{client_id}")
    print()
    print("Press Ctrl+C to stop")
    print("=" * 60)
    print()

    uvicorn.run(
        "orchestrator.main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level="info"
    )
