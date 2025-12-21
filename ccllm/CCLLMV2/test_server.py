"""
test_server.py

Quick test to verify the server components work correctly.
"""

import asyncio
from cc_agent_v2 import create_cc_agent, CCAgentDeps, execute_task_with_agent


async def test_agent_stub_mode():
    """Test the agent in stub mode (no WebSocket)."""
    print("Testing agent in stub mode with manual tool execution...")
    print("=" * 60)

    agent = create_cc_agent()
    deps = CCAgentDeps(mode="stub")

    tasks = [
        "List all files in the root directory",
        "Create a hello world program at /test.lua and run it",
    ]

    for task in tasks:
        print(f"\nTask: {task}")
        print("-" * 60)

        try:
            result = await execute_task_with_agent(agent, task, deps)
            print(f"\nSuccess: {result.success}")
            print(f"Message: {result.message}")
            if result.details:
                print(f"Details: {result.details}")
        except Exception as e:
            print(f"Error: {e}")
            import traceback
            traceback.print_exc()

    print("\n" + "=" * 60)
    print("Test complete!")


if __name__ == "__main__":
    asyncio.run(test_agent_stub_mode())
