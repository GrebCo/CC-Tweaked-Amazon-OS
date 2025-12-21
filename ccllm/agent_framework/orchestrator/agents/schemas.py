"""
Pydantic schemas for structured LLM outputs.

Defines the output schemas for the Planner and Coder agents.
"""

from __future__ import annotations

from typing import Any, Literal
from pydantic import BaseModel, Field


class ToolCall(BaseModel):
    """Represents a single tool call with its arguments."""
    tool: str
    arguments: dict[str, Any] = Field(default_factory=dict)


class ExecutorStep(BaseModel):
    """
    Structured output from the Coder agent.

    The status field determines the next action:
    - continue: run tools (tool_calls must be non-empty)
    - need_user: ask_user tool call or direct question
    - complete: finish task with final_message
    """
    status: Literal["continue", "need_user", "complete"]

    tool_calls: list[ToolCall] = Field(default_factory=list)

    # required when status="complete"
    final_message: str | None = None

    # required when status="need_user" (either user_question or an ask_user tool call)
    user_question: str | None = None

    # optional, short, for logs only (not chain of thought)
    note: str | None = None


class PlanStep(BaseModel):
    """A single step in the task plan."""
    title: str
    details: str
    expected_tools: list[str] = Field(default_factory=list)


class TaskPlan(BaseModel):
    """
    Structured output from the Planner agent.

    Contains the high-level plan for accomplishing the task.
    """
    goal: str
    steps: list[PlanStep]
    risks: list[str] = Field(default_factory=list)
    success_criteria: list[str] = Field(default_factory=list)
