"""
Graph state for LangGraph orchestration.

Defines the state structure used by the LangGraph for managing task execution.
"""

from typing_extensions import TypedDict
from typing import Any, Literal


class AgentState(TypedDict, total=False):
    """
    State dictionary for the agent graph.

    Fields:
        task_id: Unique identifier for the task
        phase: Current phase of execution ("plan" or "execute")
        plan: The generated task plan (dict representation of TaskPlan)
        last_step: The last execution step (dict representation of ExecutorStep)
    """
    task_id: str
    phase: Literal["plan", "execute"]
    plan: dict[str, Any]
    last_step: dict[str, Any]
