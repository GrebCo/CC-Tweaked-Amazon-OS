"""
cc_agent_pydantic.py

PydanticAI-based agent for ComputerCraft automation.
This is a simple CLI agent loop that will later be integrated with WebSocket server.

Features:
- Single agent using local Ollama LLM
- Structured output using PydanticAI
- Tool definitions matching CC core tools
- Conversation history management
- Simple CLI interface for testing
"""

from __future__ import annotations

import asyncio
import json
from typing import Any, Literal
from dataclasses import dataclass, field

from pydantic import BaseModel, Field

# PydanticAI core
from pydantic_ai import Agent, RunContext

# PydanticAI Ollama provider
from pydantic_ai.models.openai import OpenAIModel


# ============================================================================
# Structured Output Schemas
# ============================================================================


class ToolCall(BaseModel):
    """One tool invocation requested by the model."""
    tool: str
    arguments: dict[str, Any] = Field(default_factory=dict)


class AgentStep(BaseModel):
    """
    The structured output the agent returns on each step.
    PydanticAI enforces this schema and will retry until valid.
    """
    status: Literal["continue", "need_user", "complete"]
    tool_calls: list[ToolCall] = Field(default_factory=list)

    # Only used when status="need_user"
    user_question: str | None = None

    # Only used when status="complete"
    final_message: str | None = None

    # Optional short note for debugging/logs
    note: str | None = None


# ============================================================================
# Agent Dependencies (Context)
# ============================================================================


@dataclass
class AgentDependencies:
    """
    Dependencies passed to agent tools via RunContext.
    This will later include WebSocket client, task state, etc.
    """
    # File cache for server-side operations
    file_cache: dict[str, str] = field(default_factory=dict)

    # Status callback for progress updates
    status_callback: callable = field(default=lambda msg: print(f"[STATUS] {msg}"))

    # Simulated CC execution (will be replaced with actual WebSocket calls)
    cc_mode: Literal["stub", "websocket"] = "stub"


# ============================================================================
# Agent Creation
# ============================================================================


def create_agent(model_name: str = "qwen2.5-coder:7b") -> Agent[AgentDependencies, AgentStep]:
    """
    Create a PydanticAI agent with structured output and tool definitions.

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
        deps_type=AgentDependencies,
        system_prompt=_get_system_prompt(),
    )

    # Register tools
    _register_tools(agent)

    return agent


def _get_system_prompt() -> str:
    """System prompt for the agent."""
    return """You are an autonomous coding agent for ComputerCraft (CC:Tweaked) computers.

Your goal is to deliver correct, working results. You operate through tools and must return structured JSON responses.

CRITICAL RULES:
1. You MUST return a valid AgentStep JSON object with status and tool_calls fields
2. When status="continue": Include 1+ tool calls in tool_calls array
3. When status="need_user": Set user_question (for genuine requirement clarifications only)
4. When status="complete": Set final_message and empty tool_calls
5. NEVER ask users to provide code - you write the code
6. NEVER claim you did something without a tool result confirming it
7. Always test programs with run_program after creating them

EXECUTION MODEL:
- You can batch multiple tool calls in one response for efficiency
- Server-side tools (send_status) execute immediately
- CC-side tools (fs_read, fs_write, run_program) will wait for results
- Use send_status to keep users informed of progress

WORKFLOW:
1. Read files with fs_read before modifying
2. Write files with fs_write
3. Test with run_program
4. Fix errors by reading, analyzing, and rewriting
5. Complete when verified working

Available tools: fs_read, fs_write, fs_list, fs_delete, run_program, shell_exec, send_status, ask_user

Return ONLY valid AgentStep JSON. No markdown, no code fences, no extra text."""


# ============================================================================
# Tool Definitions
# ============================================================================


def _register_tools(agent: Agent) -> None:
    """Register all tools with the agent."""

    @agent.tool
    async def send_status(ctx: RunContext[AgentDependencies], message: str) -> dict[str, Any]:
        """
        Send a status update to the user.
        Use this frequently to keep the user informed of progress.

        Args:
            message: Short status message (e.g., "Writing file...", "Testing program...")

        Returns:
            Confirmation of status sent
        """
        ctx.deps.status_callback(message)
        return {"sent": True, "message": message}

    @agent.tool
    async def fs_read(ctx: RunContext[AgentDependencies], path: str) -> dict[str, Any]:
        """
        Read a file from the CC computer and cache it locally.

        Args:
            path: Path to file on CC computer

        Returns:
            File contents and metadata
        """
        if ctx.deps.cc_mode == "stub":
            # Stub implementation - simulate file read
            content = f"-- Stub content for {path}\nprint('Hello from {path}')\n"
            ctx.deps.file_cache[path] = content
            return {
                "path": path,
                "content": content,
                "size": len(content),
                "cached": True
            }
        else:
            # TODO: WebSocket implementation
            raise NotImplementedError("WebSocket mode not yet implemented")

    @agent.tool
    async def fs_write(ctx: RunContext[AgentDependencies], path: str, content: str) -> dict[str, Any]:
        """
        Write content to a file on the CC computer.
        Creates parent directories if needed.

        Args:
            path: Path to write to on CC computer
            content: Content to write

        Returns:
            Write confirmation with metadata
        """
        if ctx.deps.cc_mode == "stub":
            # Stub implementation - simulate file write
            ctx.deps.file_cache[path] = content
            print(f"[STUB] Would write {len(content)} bytes to {path}")
            print(f"[STUB] Content preview:\n{content[:200]}")
            return {
                "path": path,
                "size": len(content),
                "created": True
            }
        else:
            # TODO: WebSocket implementation
            raise NotImplementedError("WebSocket mode not yet implemented")

    @agent.tool
    async def fs_list(ctx: RunContext[AgentDependencies], path: str = "") -> dict[str, Any]:
        """
        List files and directories at a path on the CC computer.

        Args:
            path: Directory path to list (default: root)

        Returns:
            List of files/directories with metadata
        """
        if ctx.deps.cc_mode == "stub":
            # Stub implementation
            return {
                "path": path,
                "entries": [
                    {"name": "startup.lua", "path": "/startup.lua", "is_dir": False, "size": 256},
                    {"name": "programs", "path": "/programs", "is_dir": True, "size": 0},
                ],
                "count": 2
            }
        else:
            # TODO: WebSocket implementation
            raise NotImplementedError("WebSocket mode not yet implemented")

    @agent.tool
    async def fs_delete(ctx: RunContext[AgentDependencies], path: str) -> dict[str, Any]:
        """
        Delete a file or directory on the CC computer.

        Args:
            path: Path to delete

        Returns:
            Deletion confirmation
        """
        if ctx.deps.cc_mode == "stub":
            # Stub implementation
            if path in ctx.deps.file_cache:
                del ctx.deps.file_cache[path]
            print(f"[STUB] Would delete {path}")
            return {
                "path": path,
                "deleted": True
            }
        else:
            # TODO: WebSocket implementation
            raise NotImplementedError("WebSocket mode not yet implemented")

    @agent.tool
    async def run_program(ctx: RunContext[AgentDependencies], path: str, args: list[str] = None) -> dict[str, Any]:
        """
        Run a Lua program on the CC computer and capture output.
        Programs have a 5-second timeout.

        Args:
            path: Path to Lua program
            args: Optional command-line arguments (accessible as arg[1], arg[2], etc.)

        Returns:
            Program output, success status, and any errors
        """
        if args is None:
            args = []

        if ctx.deps.cc_mode == "stub":
            # Stub implementation - simulate program execution
            print(f"[STUB] Would run {path} with args {args}")
            return {
                "path": path,
                "success": True,
                "output": "Hello, World!\nProgram completed successfully.",
                "error": ""
            }
        else:
            # TODO: WebSocket implementation
            raise NotImplementedError("WebSocket mode not yet implemented")

    @agent.tool
    async def shell_exec(ctx: RunContext[AgentDependencies], command: str) -> dict[str, Any]:
        """
        Execute a CraftOS shell command on the CC computer.

        Args:
            command: Shell command to execute (e.g., "ls", "mkdir foo")

        Returns:
            Command output and success status
        """
        if ctx.deps.cc_mode == "stub":
            # Stub implementation
            print(f"[STUB] Would run shell command: {command}")
            return {
                "success": True,
                "output": f"Executed: {command}\n"
            }
        else:
            # TODO: WebSocket implementation
            raise NotImplementedError("WebSocket mode not yet implemented")

    @agent.tool
    async def ask_user(ctx: RunContext[AgentDependencies], question: str) -> dict[str, Any]:
        """
        Ask the user a question and wait for their response.
        Use SPARINGLY and only for genuine requirement clarifications.

        NEVER ask users to provide code or file contents - you should generate those yourself.

        Args:
            question: Question to ask (must be about requirements, not implementation)

        Returns:
            User's answer
        """
        # Validate question isn't asking for code/content
        forbidden_patterns = [
            "provide the content",
            "what should the content be",
            "give me the content",
            "write the content",
            "what code should",
        ]

        question_lower = question.lower()
        for pattern in forbidden_patterns:
            if pattern in question_lower:
                return {
                    "error": f"Invalid question. Never ask users to provide code. You must write it yourself.",
                    "answer": None
                }

        # In CLI mode, prompt for input
        print(f"\n[QUESTION] {question}")
        answer = input("Your answer: ")

        return {
            "answer": answer,
            "question": question
        }


# ============================================================================
# Agent Loop
# ============================================================================


async def run_agent_task(agent: Agent, task: str, deps: AgentDependencies, max_iterations: int = 20) -> None:
    """
    Run an agent task with conversation loop.

    Args:
        agent: The PydanticAI agent
        task: User's task description
        deps: Agent dependencies
        max_iterations: Maximum number of agent iterations
    """
    print(f"\n{'='*60}")
    print(f"TASK: {task}")
    print(f"{'='*60}\n")

    # Build initial prompt
    prompt = f"User request: {task}\n\nProvide your next AgentStep."

    # Conversation history (for multi-turn conversations)
    conversation_history = []

    for iteration in range(max_iterations):
        print(f"\n--- Iteration {iteration + 1}/{max_iterations} ---")

        try:
            # Run agent
            result = await agent.run(prompt, deps=deps, message_history=conversation_history)
            step: AgentStep = result.data

            print(f"Status: {step.status}")
            if step.note:
                print(f"Note: {step.note}")

            # Handle based on status
            if step.status == "complete":
                print(f"\n{'='*60}")
                print("TASK COMPLETE")
                print(f"{'='*60}")
                print(f"\n{step.final_message}")
                return

            elif step.status == "need_user":
                # This would be handled by ask_user tool in practice
                print(f"\nAgent needs user input: {step.user_question}")
                # The ask_user tool will handle the actual prompting
                # Continue to next iteration
                prompt = f"The user was asked: {step.user_question}\nContinue with your next AgentStep."

            elif step.status == "continue":
                if not step.tool_calls:
                    print("ERROR: Agent returned continue status but no tool calls!")
                    print("Prompting agent to provide tool calls...")
                    prompt = "ERROR: You returned status='continue' but provided no tool_calls. You MUST include at least one tool call when status is 'continue'."
                    continue

                print(f"Tool calls: {len(step.tool_calls)}")
                for tc in step.tool_calls:
                    print(f"  - {tc.tool}({', '.join(f'{k}={v}' for k, v in list(tc.arguments.items())[:2])}...)")

                # Tools were already executed by PydanticAI
                # Results are in the conversation history
                prompt = "Tool results received. Provide your next AgentStep."

            # Update conversation history from result
            conversation_history = result.all_messages()

        except Exception as e:
            print(f"\nERROR during iteration {iteration + 1}: {e}")
            import traceback
            traceback.print_exc()

            # Try to recover
            prompt = f"An error occurred: {e}\n\nPlease try a different approach. Provide your next AgentStep."

    print(f"\n{'='*60}")
    print("MAX ITERATIONS REACHED")
    print(f"{'='*60}")
    print("The task did not complete within the iteration limit.")


# ============================================================================
# CLI Interface
# ============================================================================


async def main() -> None:
    """
    Simple CLI interface for testing the agent.
    """
    print("=" * 60)
    print("ComputerCraft LLM Agent - PydanticAI Version")
    print("=" * 60)
    print()
    print("This is a test CLI for the agent. WebSocket integration coming soon.")
    print("Type 'quit' or 'exit' to exit.")
    print()

    # Create agent
    print("Initializing agent...")
    agent = create_agent()
    print("Agent ready!")
    print()

    # Main loop
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

            # Create fresh dependencies for this task
            deps = AgentDependencies()

            # Run the task
            await run_agent_task(agent, user_input, deps)

        except KeyboardInterrupt:
            print("\n\nInterrupted. Goodbye!")
            break
        except Exception as e:
            print(f"\nError: {e}")
            import traceback
            traceback.print_exc()


if __name__ == "__main__":
    asyncio.run(main())
