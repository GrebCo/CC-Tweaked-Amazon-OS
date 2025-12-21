"""
Planner agent using Pydantic AI.

The planner generates a structured plan for accomplishing a task.
It uses Qwen3:14b by default and produces TaskPlan outputs.
"""

from __future__ import annotations

import os
from pydantic_ai import Agent
from pydantic_ai.providers.ollama import OllamaProvider
from .schemas import TaskPlan


def build_planner_agent(model_name: str, base_url: str) -> Agent[None, TaskPlan]:
    """
    Build a Planner agent that generates structured task plans.

    Args:
        model_name: Name of the Ollama model (e.g., "qwen3:14b")
        base_url: Base URL for Ollama API (will strip /v1 if present)

    Returns:
        Pydantic AI Agent configured for planning
    """
    # Ensure /v1 suffix is present for OpenAI-compatible endpoint
    if not base_url.endswith('/v1'):
        base_url = base_url + '/v1'

    # Set environment variable for Ollama base URL (required by pydantic_ai)
    os.environ['OLLAMA_BASE_URL'] = base_url

    # Pydantic AI Agent uses model name directly for Ollama
    model_name_with_provider = f'ollama:{model_name}'

    return Agent(
        model_name_with_provider,
        output_type=TaskPlan,
        system_prompt=(
            "You are the planner.\n"
            "Return a structured plan for accomplishing the task.\n"
            "Do not write code. Do not call tools. Do not include chain of thought.\n"
            "Focus on sequencing, risks, and success criteria.\n"
        ),
    )
