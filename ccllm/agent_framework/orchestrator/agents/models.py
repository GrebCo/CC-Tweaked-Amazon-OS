"""
Pydantic AI model wiring for Ollama.

Provides factory functions to create Ollama-backed models for use with Pydantic AI.
"""

from __future__ import annotations

from pydantic_ai.models.ollama import OllamaModel


def make_ollama_model(model_name: str, base_url: str) -> OllamaModel:
    """
    Create an Ollama-backed model for Pydantic AI.

    Pydantic AI has native Ollama support via OllamaModel.
    The base_url should be the Ollama server URL (e.g., http://localhost:11434)

    Args:
        model_name: Name of the Ollama model (e.g., "qwen3:14b", "gemma3:12b")
        base_url: Base URL for Ollama API (will strip /v1 if present)

    Returns:
        OllamaModel instance configured for Ollama
    """
    # Strip /v1 suffix if present since OllamaModel doesn't need it
    if base_url.endswith('/v1'):
        base_url = base_url[:-3]

    return OllamaModel(
        model_name=model_name,
        base_url=base_url,
    )
