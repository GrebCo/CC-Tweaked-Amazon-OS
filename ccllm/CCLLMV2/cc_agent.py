"""
cc_agent.py

PydanticAI-based agent for ComputerCraft automation.
Single agent, manual tool routing, clean structure.

Features:
- Structured output via PydanticAI (AgentStep)
- Manual tool routing for explicit control
- CC-side tools (cc_*) and local cache tools (local_*)
- Simple transcript-based conversation memory
- Stub mode for testing without WebSocket
"""

from __future__ import annotations

import asyncio
from typing import Any, Literal
from dataclasses import dataclass, field

from pydantic import BaseModel, Field

# PydanticAI core
from pydantic_ai import Agent
from pydantic_ai.models.openai import OpenAIModel


# ============================================================================
# Structured Output Schema
# ============================================================================


class ToolCall(BaseModel):
    """One tool invocation requested by the model."""
    tool: str
    args: dict[str, Any] = Field(default_factory=dict)


class AgentStep(BaseModel):
    """
    The ONLY thing the model is allowed to output.
    PydanticAI will validate and retry until it matches this schema.
    """
    status: Literal["continue", "need_user", "complete"]
    tool_calls: list[ToolCall] = Field(default_factory=list)

    # Only used when status="need_user"
    user_question: str | None = None

    # Only used when status="complete"
    final_message: str | None = None

    # Optional short note for logs (NOT chain-of-thought)
    note: str | None = None


# ============================================================================
# Agent Context
# ============================================================================


@dataclass
class AgentContext:
    """
    Context/state for the agent execution.
    Will later include WebSocket client, task info, etc.
    """
    # File cache for local operations
    file_cache: dict[str, str] = field(default_factory=dict)

    # Mode: "stub" for testing, "websocket" for real CC connection
    mode: Literal["stub", "websocket"] = "stub"

    # WebSocket client (future)
    ws_client: Any = None


# ============================================================================
# Agent Creation
# ============================================================================


def make_agent(model_name: str = "qwen2.5-coder:7b") -> Agent[None, AgentStep]:
    """
    Configure a PydanticAI Agent that returns AgentStep JSON every time.
    Single agent - no planner/coder split yet.

    Args:
        model_name: Ollama model to use

    Returns:
        Configured Agent instance
    """
    model = OpenAIModel(
        model_name=model_name,
        base_url="http://localhost:11434/v1",
    )

    agent = Agent(
        model=model,
        result_type=AgentStep,
        system_prompt=(
            "You are an automation agent for ComputerCraft computers.\n"
            "You MUST return only a JSON object matching the AgentStep schema.\n"
            "No markdown. No code fences. No extra keys.\n"
            "\n"
            "Rules:\n"
            "- If status='continue': include 1+ tool_calls\n"
            "- If status='need_user': set user_question (use sparingly!)\n"
            "- If status='complete': set final_message and NO tool_calls\n"
            "- NEVER ask users to provide code - you write the code\n"
            "- Always test programs after creating them\n"
            "\n"
            "Available tools:\n"
            "CC-side (remote): cc_read, cc_write, cc_list, cc_delete, cc_run_program, cc_shell\n"
            "Local (cache): local_read, local_write, local_patch, local_diff\n"
            "Other: send_status, ask_user\n"
        ),
    )
    return agent


# ============================================================================
# Tool Implementations
# ============================================================================


async def send_status(ctx: AgentContext, message: str) -> dict[str, Any]:
    """
    Send a status update to the user.
    Use frequently to keep user informed.

    Args:
        message: Short status message

    Returns:
        Confirmation
    """
    print(f"[STATUS] {message}")
    return {"sent": True}


async def cc_read(ctx: AgentContext, path: str, cache: bool = True) -> dict[str, Any]:
    """
    Read a file from the CC computer.

    Args:
        path: Path on CC computer
        cache: Whether to cache locally (default True)

    Returns:
        File content and metadata
    """
    if ctx.mode == "stub":
        # Stub implementation
        content = f"-- Stub content for {path}\nprint('Hello from {path}')\n"
        if cache:
            ctx.file_cache[path] = content
        return {
            "path": path,
            "content": content,
            "size": len(content),
            "cached": cache
        }
    else:
        # TODO: WebSocket call
        raise NotImplementedError("WebSocket mode not yet implemented")


async def cc_write(ctx: AgentContext, path: str, content: str) -> dict[str, Any]:
    """
    Write a file to the CC computer.

    Args:
        path: Path on CC computer
        content: File content

    Returns:
        Write confirmation
    """
    if ctx.mode == "stub":
        # Stub implementation
        print(f"[STUB] Would write {len(content)} bytes to {path}")
        print(f"[STUB] Content preview:\n{content[:200]}")
        return {
            "path": path,
            "size": len(content),
            "created": True
        }
    else:
        # TODO: WebSocket call
        raise NotImplementedError("WebSocket mode not yet implemented")


async def cc_write_from_cache(ctx: AgentContext, cache_path: str, cc_path: str) -> dict[str, Any]:
    """
    Write a cached file to the CC computer.

    Args:
        cache_path: Path in local cache
        cc_path: Destination path on CC computer

    Returns:
        Write confirmation
    """
    if cache_path not in ctx.file_cache:
        return {"error": f"File '{cache_path}' not in cache"}

    content = ctx.file_cache[cache_path]
    return await cc_write(ctx, cc_path, content)


async def cc_list(ctx: AgentContext, path: str = "") -> dict[str, Any]:
    """
    List files in a directory on CC computer.

    Args:
        path: Directory path (default: root)

    Returns:
        List of files/directories
    """
    if ctx.mode == "stub":
        # Stub implementation
        return {
            "path": path,
            "entries": [
                {"name": "startup.lua", "is_dir": False, "size": 256},
                {"name": "programs", "is_dir": True, "size": 0},
            ],
            "count": 2
        }
    else:
        # TODO: WebSocket call
        raise NotImplementedError("WebSocket mode not yet implemented")


async def cc_tree(ctx: AgentContext, path: str = "", max_depth: int = 3) -> dict[str, Any]:
    """
    Recursive directory listing on CC computer.

    Args:
        path: Root directory path
        max_depth: Maximum recursion depth

    Returns:
        Tree structure
    """
    if ctx.mode == "stub":
        # Stub implementation
        return {
            "path": path,
            "tree": {
                "startup.lua": None,
                "programs": {
                    "hello.lua": None,
                    "utils": {
                        "lib.lua": None
                    }
                }
            }
        }
    else:
        # TODO: WebSocket call
        raise NotImplementedError("WebSocket mode not yet implemented")


async def cc_delete(ctx: AgentContext, path: str) -> dict[str, Any]:
    """
    Delete a file or directory on CC computer.

    Args:
        path: Path to delete

    Returns:
        Deletion confirmation
    """
    if ctx.mode == "stub":
        # Stub implementation
        print(f"[STUB] Would delete {path}")
        return {"path": path, "deleted": True}
    else:
        # TODO: WebSocket call
        raise NotImplementedError("WebSocket mode not yet implemented")


async def cc_run_program(ctx: AgentContext, path: str, args: list[str] = None) -> dict[str, Any]:
    """
    Run a Lua program on CC computer.

    Args:
        path: Path to program
        args: Command-line arguments (accessible as arg[1], arg[2], etc.)

    Returns:
        Program output and success status
    """
    if args is None:
        args = []

    if ctx.mode == "stub":
        # Stub implementation
        print(f"[STUB] Would run {path} with args {args}")
        return {
            "path": path,
            "success": True,
            "output": "Hello, World!\nProgram completed successfully.",
            "error": ""
        }
    else:
        # TODO: WebSocket call
        raise NotImplementedError("WebSocket mode not yet implemented")


async def cc_shell(ctx: AgentContext, command: str) -> dict[str, Any]:
    """
    Execute a shell command on CC computer.

    Args:
        command: CraftOS shell command

    Returns:
        Command output
    """
    if ctx.mode == "stub":
        # Stub implementation
        print(f"[STUB] Would run shell: {command}")
        return {
            "success": True,
            "output": f"Executed: {command}\n"
        }
    else:
        # TODO: WebSocket call
        raise NotImplementedError("WebSocket mode not yet implemented")


async def local_read(ctx: AgentContext, path: str) -> dict[str, Any]:
    """
    Read a file from local cache.

    Args:
        path: Path in cache

    Returns:
        Cached content
    """
    if path not in ctx.file_cache:
        return {"error": f"File '{path}' not in cache. Use cc_read first."}

    content = ctx.file_cache[path]
    return {
        "path": path,
        "content": content,
        "size": len(content)
    }


async def local_write(ctx: AgentContext, path: str, content: str) -> dict[str, Any]:
    """
    Write a file to local cache.

    Args:
        path: Cache path
        content: File content

    Returns:
        Write confirmation
    """
    ctx.file_cache[path] = content
    return {
        "path": path,
        "size": len(content),
        "cached": True
    }


async def local_patch(ctx: AgentContext, path: str, old: str, new: str) -> dict[str, Any]:
    """
    Apply a simple find/replace patch to cached file.

    Args:
        path: Path in cache
        old: Text to find
        new: Replacement text

    Returns:
        Patch result with diff
    """
    if path not in ctx.file_cache:
        return {"error": f"File '{path}' not in cache"}

    original = ctx.file_cache[path]

    if old not in original:
        return {"error": f"Pattern not found: {old[:50]}..."}

    patched = original.replace(old, new)
    ctx.file_cache[path] = patched

    return {
        "path": path,
        "patched": True,
        "old_size": len(original),
        "new_size": len(patched),
        "changes": 1
    }


async def local_diff(ctx: AgentContext, path1: str, path2: str = None) -> dict[str, Any]:
    """
    Show diff between two cached files or cached vs provided content.

    Args:
        path1: First file path in cache
        path2: Second file path in cache (optional)

    Returns:
        Diff output
    """
    if path1 not in ctx.file_cache:
        return {"error": f"File '{path1}' not in cache"}

    content1 = ctx.file_cache[path1]

    if path2 and path2 in ctx.file_cache:
        content2 = ctx.file_cache[path2]
    else:
        content2 = ""

    # Simple line-by-line diff
    lines1 = content1.splitlines()
    lines2 = content2.splitlines()

    diff_lines = []
    for i, (l1, l2) in enumerate(zip(lines1, lines2)):
        if l1 != l2:
            diff_lines.append(f"Line {i+1}:")
            diff_lines.append(f"  - {l1}")
            diff_lines.append(f"  + {l2}")

    return {
        "diff": "\n".join(diff_lines),
        "changed_lines": len(diff_lines) // 3
    }


async def ask_user(ctx: AgentContext, question: str) -> dict[str, Any]:
    """
    Ask the user a question and wait for response.
    Use SPARINGLY - only for genuine requirement clarifications.

    Args:
        question: Question to ask

    Returns:
        User's answer
    """
    # Validate question
    forbidden_patterns = [
        "provide the content",
        "what should the content be",
        "give me the content",
        "write the content",
    ]

    question_lower = question.lower()
    for pattern in forbidden_patterns:
        if pattern in question_lower:
            return {
                "error": "Invalid question. Never ask users to provide code. You must write it yourself."
            }

    # In CLI mode, prompt directly
    print(f"\n[QUESTION] {question}")
    answer = input("Your answer: ")

    return {"answer": answer}


# ============================================================================
# Tool Router
# ============================================================================


# Tool registry for clean routing
TOOL_REGISTRY = {
    "send_status": send_status,
    "cc_read": cc_read,
    "cc_write": cc_write,
    "cc_write_from_cache": cc_write_from_cache,
    "cc_list": cc_list,
    "cc_tree": cc_tree,
    "cc_delete": cc_delete,
    "cc_run_program": cc_run_program,
    "cc_shell": cc_shell,
    "local_read": local_read,
    "local_write": local_write,
    "local_patch": local_patch,
    "local_diff": local_diff,
    "ask_user": ask_user,
}


async def execute_tool(ctx: AgentContext, tool_call: ToolCall) -> str:
    """
    Execute a tool call and return formatted result.

    Args:
        ctx: Agent context
        tool_call: Tool to execute

    Returns:
        Formatted tool result
    """
    tool_fn = TOOL_REGISTRY.get(tool_call.tool)

    if not tool_fn:
        return f"[error] unknown tool: {tool_call.tool}"

    try:
        result = await tool_fn(ctx, **tool_call.args)
        return f"TOOL[{tool_call.tool}] => {result}"
    except Exception as e:
        return f"TOOL[{tool_call.tool}] => [error] {type(e).__name__}: {e}"


# ============================================================================
# Main Agent Loop
# ============================================================================


async def run_task(agent: Agent, task: str, ctx: AgentContext, max_iters: int = 20) -> None:
    """
    Run an agent task with simple transcript-based memory.

    Args:
        agent: The PydanticAI agent
        task: User's task description
        ctx: Agent context
        max_iters: Maximum iterations
    """
    print(f"\n{'='*60}")
    print(f"TASK: {task}")
    print(f"{'='*60}\n")

    # Simple transcript for conversation memory
    transcript: list[str] = []
    transcript.append(f"USER_TASK: {task}")

    for i in range(max_iters):
        print(f"\n--- Iteration {i + 1}/{max_iters} ---")

        # Build prompt from transcript
        prompt = "\n".join(transcript) + "\n\nReturn the next AgentStep."

        try:
            # Call agent
            result = await agent.run(prompt)
            step: AgentStep = result.data

            # Log note if present
            if step.note:
                print(f"[note] {step.note}")

            # Handle completion
            if step.status == "complete":
                print(f"\n{'='*60}")
                print("TASK COMPLETE")
                print(f"{'='*60}")
                print(f"\n{step.final_message or '(no final_message provided)'}")
                return

            # Handle user input needed
            if step.status == "need_user":
                print(f"\n[needs user] {step.user_question}")
                # In real system, this would pause and wait for WebSocket message
                # For CLI, we'll prompt directly via ask_user tool
                fake_answer = "Continue with best guess."
                transcript.append(f"USER_ANSWER: {fake_answer}")
                continue

            # Handle tool execution
            if step.status == "continue":
                if not step.tool_calls:
                    print("[error] Agent returned 'continue' but no tool_calls!")
                    transcript.append("ERROR: You must provide tool_calls when status='continue'")
                    continue

                print(f"Executing {len(step.tool_calls)} tool(s)...")

                # Execute all tool calls
                tool_results: list[str] = []
                for tc in step.tool_calls:
                    print(f"  - {tc.tool}({list(tc.args.keys())})")
                    result_str = await execute_tool(ctx, tc)
                    tool_results.append(result_str)

                # Add results to transcript
                transcript.append(f"ITERATION_{i}:")
                transcript.extend(tool_results)

        except Exception as e:
            print(f"\n[error] {type(e).__name__}: {e}")
            import traceback
            traceback.print_exc()
            transcript.append(f"ERROR: {e}")

    print(f"\n{'='*60}")
    print("MAX ITERATIONS REACHED")
    print(f"{'='*60}")


# ============================================================================
# CLI Interface
# ============================================================================


async def main() -> None:
    """Simple CLI for testing the agent."""
    print("=" * 60)
    print("ComputerCraft LLM Agent - PydanticAI")
    print("=" * 60)
    print()
    print("Type 'quit' or 'exit' to quit.")
    print()

    # Create agent
    print("Initializing agent...")
    agent = make_agent()
    print("Agent ready!")
    print()

    while True:
        try:
            # Get user input
            print("-" * 60)
            user_input = input("Task> ").strip()

            if not user_input:
                continue

            if user_input.lower() in ["quit", "exit", "q"]:
                print("Goodbye!")
                break

            # Create fresh context for each task
            ctx = AgentContext()

            # Run task
            await run_task(agent, user_input, ctx)

        except KeyboardInterrupt:
            print("\n\nInterrupted. Goodbye!")
            break
        except Exception as e:
            print(f"\nError: {e}")
            import traceback
            traceback.print_exc()


if __name__ == "__main__":
    asyncio.run(main())
