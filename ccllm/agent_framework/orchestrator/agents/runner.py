"""
Agent runner for managing LangGraph execution with checkpointing.

Provides start and resume functionality for durable, interruptible task execution.
"""

from __future__ import annotations

from langgraph.checkpoint.memory import MemorySaver
from langgraph.types import Command


class AgentRunner:
    """
    Manages LangGraph execution with checkpointing support.

    The runner maintains a checkpointer that stores graph state, allowing
    tasks to be paused and resumed (e.g., for CC command results or user input).
    """

    def __init__(self, graph):
        """
        Initialize the runner with a compiled LangGraph.

        Args:
            graph: Compiled LangGraph instance
        """
        self.graph = graph
        self.checkpointer = MemorySaver()

    async def start(self, task_id: str):
        """
        Start a new task execution.

        Args:
            task_id: Unique task identifier (used as thread_id for checkpointing)
        """
        await self.graph.ainvoke(
            {"task_id": task_id, "phase": "plan"},
            config={"configurable": {"thread_id": task_id}, "checkpointer": self.checkpointer},
        )

    async def resume(self, task_id: str, resume_payload: dict):
        """
        Resume a paused task execution.

        Args:
            task_id: Unique task identifier
            resume_payload: Data to resume with (e.g., command result, user answer)

        Returns:
            Graph execution result
        """
        return await self.graph.ainvoke(
            Command(resume=resume_payload),
            config={"configurable": {"thread_id": task_id}, "checkpointer": self.checkpointer},
        )
