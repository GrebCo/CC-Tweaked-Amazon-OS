"""
Coder agent using Pydantic AI.

The coder executes tasks step-by-step by generating tool calls.
It uses Gemma3:12b by default and produces ExecutorStep outputs.
"""

from __future__ import annotations

import os
from pydantic_ai import Agent
from pydantic_ai.providers.ollama import OllamaProvider
from .schemas import ExecutorStep


def build_coder_agent(model_name: str, base_url: str) -> Agent[None, ExecutorStep]:
    """
    Build a Coder agent that generates structured execution steps.

    Args:
        model_name: Name of the Ollama model (e.g., "gemma3:12b")
        base_url: Base URL for Ollama API (will strip /v1 if present)

    Returns:
        Pydantic AI Agent configured for code execution
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
        output_type=ExecutorStep,
        system_prompt=(
            "You are the executor.\n"
            "You must return ONLY a JSON object matching the ExecutorStep schema.\n"
            "No markdown. No code fences. No extra keys.\n"
            "When status=continue, include at least one tool call.\n"
            "When status=complete, include final_message and no tool calls.\n"
            "When you need user input, use status=need_user and set user_question.\n"
        ),
    )
