"""
cc_agent_v2.py

PydanticAI-based agent for ComputerCraft - Two-Agent Architecture.
Implements Planner + Executor pattern for better control with qwen models.

Architecture:
- PlannerAgent: Thinks freely, writes loose directives (ASK_USER, WRITE_FILE, RUN, SHELL, DONE)
- ExecutorAgent: Translates directives to strict JSON tool calls, no memory/planning
- Control loop: Planner → Executor → Tool → Repeat

Key benefits:
- Planner has full memory and can think/design freely
- Executor enforces strict validation on tool calls
- Validation errors bounce back to Planner for retry
- Compatible with qwen models that struggle with direct function calling
"""

from __future__ import annotations

import asyncio
import os
import re
from typing import Literal, Any
from dataclasses import dataclass, field
from datetime import datetime

from pydantic import BaseModel, Field, TypeAdapter
from pydantic_ai import Agent, RunContext, ModelRetry
from pydantic_ai.models.openai import OpenAIModel
from pydantic_ai.providers.ollama import OllamaProvider

# Set Ollama base URL for PydanticAI
os.environ.setdefault("OLLAMA_BASE_URL", "http://localhost:11434/v1")

try:
    from ws_tools import call_cc_command
except ImportError:
    # For standalone testing
    call_cc_command = None


# ============================================================================
# Agent Dependencies (Context)
# ============================================================================


@dataclass
class CCAgentDeps:
    """
    Dependencies/context passed to agent and tools.
    Contains state like file cache, WebSocket client, etc.
    """
    # File cache for local operations
    file_cache: dict[str, str] = field(default_factory=dict)

    # Mode: "stub" for testing, "websocket" for real CC connection
    mode: Literal["stub", "websocket"] = "stub"

    # WebSocket client info (for websocket mode)
    ws_client: dict | None = None

    # Task info (for logging/tracking)
    task_id: str = "test"


# ============================================================================
# Task Memory (for PlannerAgent)
# ============================================================================


@dataclass
class TaskMemory:
    """
    Stores full context for PlannerAgent.
    PlannerAgent gets complete history, ExecutorAgent gets only current directive.
    """
    task_id: str
    original_prompt: str
    directives: list[str] = field(default_factory=list)  # PlannerAgent outputs
    tool_requests: list[dict] = field(default_factory=list)  # ExecutorAgent outputs
    tool_results: list[dict] = field(default_factory=list)  # Tool execution results
    user_answers: list[tuple[str, str]] = field(default_factory=list)  # Q&A pairs
    created_at: datetime = field(default_factory=datetime.now)

    def build_planner_context(self) -> str:
        """
        Render full context for PlannerAgent input.

        Format:
        TASK
        <original prompt>

        HISTORY
        Step 1
        Planner directive:
        ...
        Executor tool request:
        ...
        Tool result:
        ...

        USER ANSWERS
        Q: ...
        A: ...
        """
        sections = [
            f"TASK\n{self.original_prompt}",
            "\nHISTORY"
        ]

        # Add each step's full history
        for i in range(len(self.directives)):
            sections.append(f"\nStep {i + 1}")
            sections.append(f"Planner directive:\n{self.directives[i]}")

            if i < len(self.tool_requests):
                sections.append(f"Executor tool request:\n{self.tool_requests[i]}")

            if i < len(self.tool_results):
                result = self.tool_results[i]
                if result.get("ok"):
                    sections.append(f"Tool result:\n{result.get('output', '')}")
                else:
                    sections.append(f"Tool error:\n{result.get('error', 'Unknown error')}")

        # Add user answers if any
        if self.user_answers:
            sections.append("\nUSER ANSWERS")
            for q, a in self.user_answers:
                sections.append(f"Q: {q}\nA: {a}")

        return "\n\n".join(sections)


# ============================================================================
# Executor Schemas (Strict JSON for ExecutorAgent)
# ============================================================================

# Per-Tool Parameter Models (strict validation with extra="forbid")

class CCReadParams(BaseModel):
    """Parameters for cc_read tool."""
    model_config = {"extra": "forbid"}
    path: str = Field(..., description="Path to file on CC computer")


class CCListParams(BaseModel):
    """Parameters for cc_list tool."""
    model_config = {"extra": "forbid"}
    path: str = Field(default="", description="Directory path (default: root)")


class CCTreeParams(BaseModel):
    """Parameters for cc_tree tool."""
    model_config = {"extra": "forbid"}
    path: str = Field(default="", description="Starting directory path")
    max_depth: int = Field(default=3, ge=1, le=5, description="Maximum recursion depth")


class CCWriteParams(BaseModel):
    """Parameters for cc_write tool."""
    model_config = {"extra": "forbid"}
    path: str = Field(..., description="Path on CC computer")
    content: str = Field(..., description="File content to write")


class CCWriteAndRunParams(BaseModel):
    """Parameters for cc_write_and_run tool."""
    model_config = {"extra": "forbid"}
    path: str = Field(..., description="Path on CC computer")
    content: str = Field(..., description="File content to write")
    args: list[str] = Field(default_factory=list, description="Command-line arguments for testing")


class CCRunProgramParams(BaseModel):
    """Parameters for cc_run_program tool."""
    model_config = {"extra": "forbid"}
    path: str = Field(..., description="Path to the Lua program")
    args: list[str] = Field(default_factory=list, description="Command-line arguments")


class CCShellParams(BaseModel):
    """Parameters for cc_shell tool."""
    model_config = {"extra": "forbid"}
    command: str = Field(..., description="Shell command to execute")


class CCDeleteParams(BaseModel):
    """Parameters for cc_delete tool."""
    model_config = {"extra": "forbid"}
    path: str = Field(..., description="Path to delete")


class LocalReadParams(BaseModel):
    """Parameters for local_read tool."""
    model_config = {"extra": "forbid"}
    path: str = Field(..., description="Path in cache")


class LocalWriteParams(BaseModel):
    """Parameters for local_write tool."""
    model_config = {"extra": "forbid"}
    path: str = Field(..., description="Cache path")
    content: str = Field(..., description="File content")


class LocalPatchParams(BaseModel):
    """Parameters for local_patch tool."""
    model_config = {"extra": "forbid"}
    path: str = Field(..., description="Path in cache")
    old_text: str = Field(..., description="Text to find and replace")
    new_text: str = Field(..., description="Replacement text")


class TaskCompleteParams(BaseModel):
    """Parameters for task_complete pseudo-tool."""
    model_config = {"extra": "forbid"}
    success: bool = Field(..., description="Whether task completed successfully")
    summary: str = Field(..., description="One line summary of what was accomplished")


# Discriminated Union for Tool Calls

class CCReadCall(BaseModel):
    """Tool call for cc_read."""
    kind: Literal["tool"] = "tool"
    explanation: str = Field(..., min_length=1, max_length=200)
    tool: Literal["cc_read"] = "cc_read"
    parameters: CCReadParams


class CCListCall(BaseModel):
    """Tool call for cc_list."""
    kind: Literal["tool"] = "tool"
    explanation: str = Field(..., min_length=1, max_length=200)
    tool: Literal["cc_list"] = "cc_list"
    parameters: CCListParams


class CCTreeCall(BaseModel):
    """Tool call for cc_tree."""
    kind: Literal["tool"] = "tool"
    explanation: str = Field(..., min_length=1, max_length=200)
    tool: Literal["cc_tree"] = "cc_tree"
    parameters: CCTreeParams


class CCWriteCall(BaseModel):
    """Tool call for cc_write."""
    kind: Literal["tool"] = "tool"
    explanation: str = Field(..., min_length=1, max_length=200)
    tool: Literal["cc_write"] = "cc_write"
    parameters: CCWriteParams


class CCWriteAndRunCall(BaseModel):
    """Tool call for cc_write_and_run."""
    kind: Literal["tool"] = "tool"
    explanation: str = Field(..., min_length=1, max_length=200)
    tool: Literal["cc_write_and_run"] = "cc_write_and_run"
    parameters: CCWriteAndRunParams


class CCRunProgramCall(BaseModel):
    """Tool call for cc_run_program."""
    kind: Literal["tool"] = "tool"
    explanation: str = Field(..., min_length=1, max_length=200)
    tool: Literal["cc_run_program"] = "cc_run_program"
    parameters: CCRunProgramParams


class CCShellCall(BaseModel):
    """Tool call for cc_shell."""
    kind: Literal["tool"] = "tool"
    explanation: str = Field(..., min_length=1, max_length=200)
    tool: Literal["cc_shell"] = "cc_shell"
    parameters: CCShellParams


class CCDeleteCall(BaseModel):
    """Tool call for cc_delete."""
    kind: Literal["tool"] = "tool"
    explanation: str = Field(..., min_length=1, max_length=200)
    tool: Literal["cc_delete"] = "cc_delete"
    parameters: CCDeleteParams


class LocalReadCall(BaseModel):
    """Tool call for local_read."""
    kind: Literal["tool"] = "tool"
    explanation: str = Field(..., min_length=1, max_length=200)
    tool: Literal["local_read"] = "local_read"
    parameters: LocalReadParams


class LocalWriteCall(BaseModel):
    """Tool call for local_write."""
    kind: Literal["tool"] = "tool"
    explanation: str = Field(..., min_length=1, max_length=200)
    tool: Literal["local_write"] = "local_write"
    parameters: LocalWriteParams


class LocalPatchCall(BaseModel):
    """Tool call for local_patch."""
    kind: Literal["tool"] = "tool"
    explanation: str = Field(..., min_length=1, max_length=200)
    tool: Literal["local_patch"] = "local_patch"
    parameters: LocalPatchParams


class FinalResult(BaseModel):
    """Final task completion result."""
    kind: Literal["final"] = "final"
    explanation: str = Field(..., min_length=1, max_length=200)
    success: bool = Field(..., description="Whether task completed successfully")
    message: str = Field(..., description="Summary of result")
    details: dict = Field(default_factory=dict, description="Additional details")


# Discriminated union of all possible executor responses
# Pydantic will choose the correct subclass based on 'tool' field
ToolCall = (
    CCReadCall | CCListCall | CCTreeCall | CCWriteCall | CCWriteAndRunCall |
    CCRunProgramCall | CCShellCall | CCDeleteCall | LocalReadCall |
    LocalWriteCall | LocalPatchCall
)

ExecutorResponse = ToolCall | FinalResult

# TypeAdapter for validating the discriminated union
ExecutorResponseAdapter = TypeAdapter(ExecutorResponse)


# ============================================================================
# Legacy Schemas (for backward compatibility during migration)
# ============================================================================


class ToolCall(BaseModel):
    """Arguments for a tool call."""
    tool: str = Field(..., description="Tool name to call")
    args: dict[str, Any] = Field(default_factory=dict, description="Tool arguments")


class AgentResponse(BaseModel):
    """
    Response from the agent on each step.
    Either a tool request OR a final result.
    """
    kind: Literal["tool", "final"]
    explanation: str = Field(..., min_length=1, max_length=200, description="Brief status update")

    # Tool fields (when kind="tool")
    tool_call: ToolCall | None = None

    # Final fields (when kind="final")
    success: bool | None = None
    message: str | None = None
    details: dict = Field(default_factory=dict)


# ============================================================================
# Agent Creation
# ============================================================================


def create_cc_agent(model_name: str = "qwen2.5-coder:14b") -> Agent:
    """
    Create a PydanticAI agent for ComputerCraft automation.

    The agent returns structured JSON responses indicating either:
    - A tool to call (kind="tool")
    - A final result (kind="final")

    We manually execute tools based on the agent's requests.

    Args:
        model_name: Ollama model to use

    Returns:
        Configured Agent
    """
    # Create agent with Ollama model - NO tool registration
    agent = Agent(
        f"ollama:{model_name}",
        output_type=AgentResponse,
        deps_type=CCAgentDeps,
        retries=5,  # Increased retries for JSON format issues
        system_prompt=(
            "You are a ComputerCraft automation agent.\n\n"
            "=== CRITICAL: JSON FORMAT ===\n"
            "RETURN ONLY VALID JSON IN THIS EXACT FORMAT:\n\n"
            "TOOL REQUEST:\n"
            "{\n"
            '  "kind": "tool",\n'
            '  "explanation": "Brief status",\n'
            '  "tool_call": {\n'
            '    "tool": "tool_name",\n'
            '    "args": {...}\n'
            "  }\n"
            "}\n\n"
            "FINAL RESULT:\n"
            "{\n"
            '  "kind": "final",\n'
            '  "explanation": "Task completed",\n'
            '  "success": true,\n'
            '  "message": "Summary",\n'
            '  "details": {}\n'
            "}\n\n"
            "DO NOT use any other format! NO 'name' field, NO 'parameters' field!\n"
            "Always include 'kind' and 'explanation' fields!\n\n"
            "TASK TYPES AND WORKFLOWS:\n\n"
            "A) CODE CREATION TASKS (user asks you to write/create/make a program):\n"
            "   PREFERRED: Use cc_write_and_run(path, content, args) - Writes AND tests in one step\n"
            "   Step 1: cc_write_and_run(path, content, args) - Write and test together\n"
            "   Step 2a: Test succeeds → return kind=final with success=true\n"
            "   Step 2b: Test fails → fix bug, use cc_write_and_run again\n\n"
            "   ALTERNATIVE (for complex debugging):\n"
            "   Step 1: cc_write(path, content) - Write the program\n"
            "   Step 2: cc_run_program(path, args) - Test separately\n"
            "   Step 3: If fails, use local_patch to fix, then cc_write, then re-test\n\n"
            "B) READ/SEARCH TASKS (user asks to find/read/explain/list files):\n"
            "   Step 1a: If looking in root directory, use cc_list(path='') - faster and cleaner\n"
            "   Step 1b: If exploring subdirectories, use cc_tree(path='', max_depth=2) - keep depth low\n"
            "   Step 2: Use cc_read to read specific files\n"
            "   Step 3: Return kind=final with the information\n"
            "   DO NOT write programs unless specifically requested!\n\n"
            "C) FIX/DEBUG TASKS (user asks to fix/debug an existing program):\n"
            "   Step 1: cc_read to read the broken program\n"
            "   Step 2: Identify ALL bugs in the code\n"
            "   Step 3: cc_write_and_run with FULLY FIXED code and test args (NOT local_patch!)\n"
            "   Step 4a: Test succeeds → return kind=final with success=true\n"
            "   Step 4b: Test fails → fix ALL remaining bugs, use cc_write_and_run again\n"
            "   IMPORTANT: Do NOT use local_patch/local_write for fixes - use cc_write_and_run directly!\n\n"
            "D) OTHER TASKS (delete, run existing programs, etc.):\n"
            "   Use appropriate tools (cc_delete, cc_run_program, cc_shell)\n"
            "   Return kind=final when done\n\n"
            "CRITICAL: Identify the task type FIRST, then follow the correct workflow!\n\n"
            "EXAMPLE 1 - CODE CREATION (user: 'Create a greeter program'):\n"
            "Response 1: {\"kind\":\"tool\", \"explanation\":\"Writing and testing greet.lua...\", \"tool_call\":{\"tool\":\"cc_write_and_run\", \"args\":{\"path\":\"/greet.lua\", \"content\":\"print('Hello, '..arg[1]..'!)\", \"args\":[\"World\"]}}}\n"
            "Tool result: 'Wrote 30 bytes\\n\\nTest Result: SUCCESS\\nProgram executed successfully. Output: Hello, World!'\n"
            "Response 2: {\"kind\":\"final\", \"explanation\":\"Task completed\", \"success\":true, \"message\":\"Created and tested greet.lua successfully\"}\n\n"
            "EXAMPLE 2 - READ TASK (user: 'Find and explain ClientNetworkHandler.lua'):\n"
            "Response 1: {\"kind\":\"tool\", \"explanation\":\"Listing root directory...\", \"tool_call\":{\"tool\":\"cc_list\", \"args\":{\"path\":\"\"}}}\n"
            "Tool result: Shows OSUtil/ directory\n"
            "Response 2: {\"kind\":\"tool\", \"explanation\":\"Reading ClientNetworkHandler.lua...\", \"tool_call\":{\"tool\":\"cc_read\", \"args\":{\"path\":\"/OSUtil/ClientNetworkHandler.lua\"}}}\n"
            "Tool result: '-- Network handler module\\nlocal handler = {}...'\n"
            "Response 3: {\"kind\":\"final\", \"explanation\":\"Found and analyzed the file\", \"success\":true, \"message\":\"ClientNetworkHandler.lua is a network handler module...\"}\n\n"
            "EXAMPLE 3 - FIX TASK (user: 'Fix buggy_calculator.lua'):\n"
            "Response 1: {\"kind\":\"tool\", \"explanation\":\"Reading buggy_calculator.lua...\", \"tool_call\":{\"tool\":\"cc_read\", \"args\":{\"path\":\"/buggy_calculator.lua\"}}}\n"
            "Tool result: Shows code with typo 'tonumer' on line 7 and '=' instead of '==' on line 25\n"
            "Response 2: {\"kind\":\"tool\", \"explanation\":\"Fixing bugs and testing...\", \"tool_call\":{\"tool\":\"cc_write_and_run\", \"args\":{\"path\":\"/buggy_calculator.lua\", \"content\":\"<fixed code>\", \"args\":[\"5\", \"+\", \"3\"]}}}\n"
            "Tool result: 'Test Result: SUCCESS. Output: Result: 5 + 3 = 8'\n"
            "Response 3: {\"kind\":\"final\", \"explanation\":\"Fixed and tested\", \"success\":true, \"message\":\"Fixed typo and comparison bug, calculator now works correctly\"}\n\n"
            "TOOLS - CC COMPUTER (Remote):\n"
            "- cc_write_and_run(path, content, args=[]) - Write program AND test it (PREFERRED for code creation)\n"
            "- cc_write(path, content) - Write file to CC computer (use when you don't want to test yet)\n"
            "- cc_run_program(path, args=[]) - Run existing Lua program on CC computer\n"
            "- cc_read(path) - Read file from CC computer (also caches locally)\n"
            "- cc_list(path='') - List files in a directory (flat, one level)\n"
            "- cc_tree(path='', max_depth=3) - Recursive tree view of filesystem (better for exploring)\n"
            "- cc_delete(path) - Delete file on CC computer\n"
            "- cc_shell(command) - Execute shell command on CC computer\n\n"
            "TOOLS - LOCAL CACHE (For Debugging/Editing):\n"
            "- local_read(path) - Read from cache (file must be cached first)\n"
            "- local_write(path, content) - Write to cache ONLY (doesn't upload to CC)\n"
            "- local_patch(path, old_text, new_text) - Edit cached file\n\n"
            "DEBUGGING WORKFLOW (when program fails):\n"
            "Option A (RECOMMENDED): Just rewrite the whole file with cc_write_and_run\n"
            "1. Read the broken code, identify bugs\n"
            "2. cc_write_and_run(path, fixed_content, test_args) - Write and test in one step\n\n"
            "Option B (for incremental fixes): Use local_patch then write\n"
            "1. cc_read(path) - Read and cache\n"
            "2. local_patch(path, old_text, new_text) - Fix in cache\n"
            "3. local_read(path) - Get the patched content\n"
            "4. cc_write_and_run(path, patched_content, test_args) - Write and test\n\n"
            "TOOLS - OTHER:\n"
            "- ask_user(question) - Ask user for clarification\n\n"
            "RULES:\n"
            "- Return ONLY valid JSON, no markdown\n"
            "- One tool call per response\n"
            "- Use 'explanation' field to communicate status updates\n"
            "- Identify task type before starting (code creation vs read vs other)\n"
            "- Never ask users to write code - you write it\n\n"
            "FOR CODE CREATION TASKS ONLY:\n"
            "- MANDATORY: After ANY cc_write, you MUST call cc_run_program with test args\n"
            "- FORBIDDEN: Returning kind=final after a FAILED test\n"
            "- If cc_run_program shows 'failed' or 'Error:', you MUST fix and re-test\n"
            "- Test with realistic arguments (e.g., if program takes input, provide test input)\n"
            "- SUCCESS CRITERIA: cc_run_program output shows NO errors\n\n"
            "FOR READ/SEARCH TASKS:\n"
            "- Use cc_tree to explore filesystem structure (better for finding files)\n"
            "- Use cc_list for specific directory contents\n"
            "- Use cc_read to read specific files\n"
            "- DO NOT create programs unless specifically requested\n"
            "- Return results in the final message\n"
        ),
    )

    return agent


# ============================================================================
# Two-Agent Architecture: Planner + Executor
# ============================================================================


def create_planner_agent(model_name: str = "qwen2.5-coder:14b") -> Agent:
    """
    Create the PlannerAgent - thinks freely, outputs text with JSON tool call at the end.

    The PlannerAgent:
    - Has full memory of the task via TaskMemory
    - Can think freely and write explanations
    - Outputs normal text followed by a JSON tool call at the end
    - Must end output with exactly ONE valid JSON tool call
    - Never calls tools directly (executor validates and executes)

    Output format:
    [free-form thinking and explanation]

    {"tool": "tool_name", "parameters": {...}, "reasoning": "..."}

    Args:
        model_name: Ollama model to use

    Returns:
        Configured PlannerAgent
    """
    agent = Agent(
        f"ollama:{model_name}",
        output_type=str,  # String output containing text + JSON (executor will extract and validate)
        deps_type=CCAgentDeps,
        retries=2,
        system_prompt=(
            "You are the PLANNER AGENT for a ComputerCraft automation system.\n"
            "You receive task context including previous steps, tool results, and errors.\n"
            "Your job is to analyze the situation, think through the next step, and output a tool call.\n\n"
            "=== OUTPUT FORMAT ===\n\n"
            "You can think freely and explain your reasoning in normal text.\n"
            "At the END of your output, you MUST include a valid JSON tool call on its own line.\n\n"
            "Example output:\n"
            "Looking at the task, I need to first read the file to see what's in it.\n"
            "The user mentioned there's a bug, so I should examine the code carefully.\n"
            "I'll start by reading the file.\n\n"
            '{"tool": "cc_read", "parameters": {"path": "/broken.lua"}, "reasoning": "Reading file to identify bugs"}\n\n'
            "=== JSON TOOL CALL FORMAT ===\n\n"
            "The JSON at the end MUST be in this EXACT format:\n\n"
            "{\n"
            '  "tool": "tool_name",\n'
            '  "parameters": {\n'
            '    "param1": "value1",\n'
            '    "param2": "value2"\n'
            "  },\n"
            '  "reasoning": "Brief explanation of why you chose this tool"\n'
            "}\n\n"
            "CRITICAL JSON RULES:\n"
            "- The JSON must be on its own line(s) at the END of your output\n"
            "- DO NOT use markdown code fences around the JSON (no ```json)\n"
            "- DO NOT add comments in the JSON\n"
            "- The JSON must be valid and parseable\n"
            "- Include all three fields: tool, parameters, reasoning\n\n"
            "=== AVAILABLE TOOLS ===\n\n"
            "1. cc_read - Read a file from CC computer\n"
            "   Format:\n"
            "   {\n"
            '     "tool": "cc_read",\n'
            '     "parameters": {"path": "/path/to/file.lua"},\n'
            '     "reasoning": "Need to read the file"\n'
            "   }\n\n"
            "2. cc_list - List files in a directory\n"
            "   Format:\n"
            "   {\n"
            '     "tool": "cc_list",\n'
            '     "parameters": {"path": "/programs"},\n'
            '     "reasoning": "Need to see what files exist"\n'
            "   }\n\n"
            "3. cc_write_and_run - Write a file AND test it (PREFERRED for code creation)\n"
            "   Format:\n"
            "   {\n"
            '     "tool": "cc_write_and_run",\n'
            '     "parameters": {\n'
            '       "path": "/path/to/file.lua",\n'
            '       "content": "-- Lua code here\\nprint(\\"Hello\\")",\n'
            '       "args": ["arg1", "arg2"]\n'
            "     },\n"
            '     "reasoning": "Writing and testing the program"\n'
            "   }\n"
            "   NOTE: content must be raw code string, NO markdown fences!\n\n"
            "4. cc_write - Write a file (use when you don't want to test yet)\n"
            "   Format:\n"
            "   {\n"
            '     "tool": "cc_write",\n'
            '     "parameters": {\n'
            '       "path": "/path/to/file.lua",\n'
            '       "content": "-- Lua code here"\n'
            "     },\n"
            '     "reasoning": "Writing file without testing"\n'
            "   }\n\n"
            "5. cc_run_program - Run an existing program\n"
            "   Format:\n"
            "   {\n"
            '     "tool": "cc_run_program",\n'
            '     "parameters": {\n'
            '       "path": "/path/to/program.lua",\n'
            '       "args": ["arg1", "arg2"]\n'
            "     },\n"
            '     "reasoning": "Testing the program"\n'
            "   }\n\n"
            "6. cc_shell - Execute a shell command\n"
            "   Format:\n"
            "   {\n"
            '     "tool": "cc_shell",\n'
            '     "parameters": {"command": "ls /programs"},\n'
            '     "reasoning": "Running shell command"\n'
            "   }\n\n"
            "7. task_complete - Mark task as complete\n"
            "   Format:\n"
            "   {\n"
            '     "tool": "task_complete",\n'
            '     "parameters": {\n'
            '       "success": true,\n'
            '       "summary": "One line summary of what was accomplished"\n'
            "     },\n"
            '     "reasoning": "Task is finished"\n'
            "   }\n\n"
            "=== RULES ===\n\n"
            "1. Output exactly ONE JSON object per turn\n"
            "2. JSON must be valid and parseable\n"
            "3. When writing code in 'content' parameter:\n"
            "   - Use raw code as a string\n"
            "   - Use \\n for newlines\n"
            "   - Escape quotes as \\\"\n"
            "   - DO NOT use markdown fences\n"
            "   - Example: \"content\": \"print(\\\"Hello\\\")\\nprint(\\\"World\\\")\"\n"
            "4. When debugging, analyze errors and fix ALL bugs\n"
            "5. Do NOT mark task complete without successful test results\n"
            "6. Review HISTORY section to see previous tool results and errors\n"
            "7. If a test fails, use cc_write_and_run again with fixed code\n\n"
            "=== WORKFLOW EXAMPLES ===\n\n"
            "For CODE CREATION:\n"
            "Step 1: {\"tool\": \"cc_write_and_run\", \"parameters\": {\"path\": \"/hello.lua\", \"content\": \"print('Hello')\", \"args\": []}, \"reasoning\": \"Creating and testing hello program\"}\n"
            "Step 2 (if test passes): {\"tool\": \"task_complete\", \"parameters\": {\"success\": true, \"summary\": \"Created hello.lua\"}, \"reasoning\": \"Task done\"}\n"
            "Step 2 (if test fails): {\"tool\": \"cc_write_and_run\", \"parameters\": {\"path\": \"/hello.lua\", \"content\": \"<fixed code>\", \"args\": []}, \"reasoning\": \"Fixing bugs\"}\n\n"
            "For DEBUGGING:\n"
            "Step 1: {\"tool\": \"cc_read\", \"parameters\": {\"path\": \"/broken.lua\"}, \"reasoning\": \"Reading broken code\"}\n"
            "Step 2: {\"tool\": \"cc_write_and_run\", \"parameters\": {\"path\": \"/broken.lua\", \"content\": \"<fixed code>\", \"args\": []}, \"reasoning\": \"Fixing and testing\"}\n"
            "Step 3: {\"tool\": \"task_complete\", \"parameters\": {\"success\": true, \"summary\": \"Fixed broken.lua\"}, \"reasoning\": \"All tests pass\"}\n\n"
            "For READ/SEARCH:\n"
            "Step 1: {\"tool\": \"cc_list\", \"parameters\": {\"path\": \"\"}, \"reasoning\": \"Exploring root directory\"}\n"
            "Step 2: {\"tool\": \"cc_read\", \"parameters\": {\"path\": \"/file.lua\"}, \"reasoning\": \"Reading the file\"}\n"
            "Step 3: {\"tool\": \"task_complete\", \"parameters\": {\"success\": true, \"summary\": \"Found and read file.lua\"}, \"reasoning\": \"Search complete\"}\n\n"
            "=== REMEMBER ===\n\n"
            "- Output ONLY the JSON object\n"
            "- No text before or after\n"
            "- No markdown fences\n"
            "- Valid JSON only\n"
        ),
    )

    return agent


def create_executor_agent(model_name: str = "qwen2.5-coder:14b") -> Agent:
    """
    Create the ExecutorAgent - extracts and validates JSON tool calls from planner output.

    The ExecutorAgent:
    - Has NO memory of the overall task
    - Receives the planner's full output (text + JSON)
    - Extracts the JSON tool call from the planner's output
    - Outputs plain text containing JSON (we validate manually)
    - Never plans, never thinks, never decides which tool to use

    Args:
        model_name: Ollama model to use

    Returns:
        Configured ExecutorAgent
    """
    agent = Agent(
        f"ollama:{model_name}",
        output_type=str,  # Plain text output - we extract and validate JSON ourselves
        deps_type=CCAgentDeps,
        retries=0,  # No automatic retries - we handle validation manually
        system_prompt=(
            "You are a JSON VALIDATOR and EXTRACTOR.\n\n"
            "Your job:\n"
            "1. Find the JSON tool call in the planner's output\n"
            "2. Validate it matches the required schema\n"
            "3. Output an ExecutorResponse with the validated tool call\n\n"
            "=== INPUT ===\n\n"
            "You receive the planner's output, which contains thinking/explanation followed by a JSON tool call.\n\n"
            "Example input:\n"
            "I need to read the file first.\n"
            '{"tool": "cc_read", "parameters": {"path": "/file.lua"}, "reasoning": "Reading the file"}\n\n'
            "=== YOUR JOB ===\n\n"
            "1. Extract the JSON object from the input (it should be at the end)\n"
            "2. Validate it has the required fields:\n"
            "   - tool (string)\n"
            "   - parameters (object)\n"
            "   - reasoning (string)\n"
            "3. Check that 'tool' is one of the valid tools:\n"
            "   cc_read, cc_list, cc_write, cc_write_and_run, cc_run_program, cc_shell, task_complete\n"
            "4. Output an ExecutorResponse\n\n"
            "=== EXECUTOR RESPONSE FORMAT ===\n\n"
            "For a valid tool call, output:\n"
            "{\n"
            '  "kind": "tool",\n'
            '  "explanation": "copy the reasoning from the JSON",\n'
            '  "tool": "tool_name from the JSON",\n'
            '  "parameters": {copy the parameters object from the JSON}\n'
            "}\n\n"
            "For task_complete, output:\n"
            "{\n"
            '  "kind": "final",\n'
            '  "explanation": "Task completed",\n'
            '  "success": true/false from parameters,\n'
            '  "message": "summary from parameters",\n'
            '  "details": {}\n'
            "}\n\n"
            "For invalid/missing JSON, output:\n"
            "{\n"
            '  "kind": "final",\n'
            '  "explanation": "Validation error",\n'
            '  "success": false,\n'
            '  "message": "Description of what went wrong",\n'
            '  "details": {}\n'
            "}\n\n"
            "=== EXAMPLES ===\n\n"
            "Example 1 - Valid tool call:\n"
            "Input: Looking at the task... I should read the file.\\n"
            '{"tool": "cc_read", "parameters": {"path": "/file.lua"}, "reasoning": "Reading the file"}\n\n'
            "Output:\n"
            "{\n"
            '  "kind": "tool",\n'
            '  "explanation": "Reading the file",\n'
            '  "tool": "cc_read",\n'
            '  "parameters": {"path": "/file.lua"}\n'
            "}\n\n"
            "Example 2 - Task complete:\n"
            'Input: Task is done!\\n{"tool": "task_complete", "parameters": {"success": true, "summary": "Created hello.lua"}, "reasoning": "Task finished"}\n\n'
            "Output:\n"
            "{\n"
            '  "kind": "final",\n'
            '  "explanation": "Task completed",\n'
            '  "success": true,\n'
            '  "message": "Created hello.lua",\n'
            '  "details": {}\n'
            "}\n\n"
            "Example 3 - Invalid JSON:\n"
            "Input: I need to read... (no JSON found)\n\n"
            "Output:\n"
            "{\n"
            '  "kind": "final",\n'
            '  "explanation": "Validation error",\n'
            '  "success": false,\n'
            '  "message": "No JSON tool call found in planner output",\n'
            '  "details": {}\n'
            "}\n\n"
            "=== RULES ===\n\n"
            "- Extract JSON from the END of the input\n"
            "- Validate all required fields exist\n"
            "- Never modify the parameters - copy them exactly\n"
            "- If planner asks for a tool call you MUST call that tool, you CANNOT end the task early without the planner explicitly asking to\n"
        ),
    )

    return agent


# ============================================================================
# Tool Implementations (Standalone - No decorators)
# ============================================================================


# ========================================
# Communication Tools
# ========================================

async def ask_user(deps: CCAgentDeps, question: str) -> str:
    """
    Ask the user a question and get their response.
    Use SPARINGLY - only for genuine requirement clarifications.

    NEVER ask users to provide code or file contents - you write those yourself.

    Args:
        question: The question to ask (must be about requirements, not implementation)

    Returns:
        User's answer
    """
    # Validate question
    forbidden = ["provide the content", "what code", "write the content"]
    if any(p in question.lower() for p in forbidden):
        raise ModelRetry(
            f"Invalid use of ask_user. Question was: '{question}'\n\n"
            "NEVER ask users to provide code. You must write it yourself.\n"
            "Only ask about requirements/behavior, not implementation details."
        )

    # In CLI mode, prompt directly
    print(f"\n[QUESTION] {question}")
    answer = input("Your answer: ")
    return answer


# ========================================
# CC Computer Tools (Remote Operations)
# ========================================

async def cc_read(deps: CCAgentDeps, path: str) -> str:
    """
    Read a file from the CC computer and cache it locally.

    Args:
        path: Path to file on CC computer

    Returns:
        The file contents
    """
    if deps.mode == "stub":
        # Stub implementation
        content = f"-- Stub content for {path}\nprint('Hello from {path}')\n"
        deps.file_cache[path] = content
        return content
    else:
        # WebSocket call
        result = await call_cc_command(deps.ws_client, "fs_read", {"path": path})
        content = result.get("content", "")
        # Cache locally
        deps.file_cache[path] = content
        return content


async def cc_write(deps: CCAgentDeps, path: str, content: str) -> str:
    """
    Write a file to the CC computer.
    Creates parent directories automatically if needed.

    Args:
        path: Path on CC computer
        content: File content to write

    Returns:
        Confirmation message with file size
    """
    if deps.mode == "stub":
        # Stub implementation
        deps.file_cache[path] = content
        print(f"[STUB] Writing {len(content)} bytes to {path}")
        print(f"[STUB] Content preview:\n{content[:200]}")
        return f"Wrote {len(content)} bytes to {path}"
    else:
        # WebSocket call
        result = await call_cc_command(deps.ws_client, "fs_write", {"path": path, "content": content})
        size = result.get("size", len(content))
        return f"Wrote {size} bytes to {path}"


async def cc_list(deps: CCAgentDeps, path: str = "") -> str:
    """
    List files and directories at a path on the CC computer.

    Args:
        path: Directory path (default: root directory)

    Returns:
        Formatted list of files and directories
    """
    if deps.mode == "stub":
        # Stub implementation
        return (
            f"Files in {path or '/'}:\n"
            "  startup.lua (256 bytes)\n"
            "  programs/ (directory)\n"
        )
    else:
        # WebSocket call
        result = await call_cc_command(deps.ws_client, "fs_list", {"path": path})
        entries = result.get("entries", [])
        lines = [f"Files in {path or '/'}:"]
        for entry in entries:
            name = entry.get("name", "")
            is_dir = entry.get("isDir", False) or entry.get("is_dir", False)
            size = entry.get("size", 0)
            if is_dir:
                lines.append(f"  {name}/ (directory)")
            else:
                lines.append(f"  {name} ({size} bytes)")
        return "\n".join(lines)


async def cc_tree(deps: CCAgentDeps, path: str = "", max_depth: int = 3) -> str:
    """
    Recursively list files and directories in a tree format.
    Useful for exploring filesystem structure.

    Args:
        path: Starting directory path (default: root directory)
        max_depth: Maximum recursion depth (default: 3, max: 5)

    Returns:
        Tree-formatted directory listing
    """
    # Limit max depth to prevent overwhelming output
    max_depth = min(max_depth, 5)

    if deps.mode == "stub":
        # Stub implementation
        return (
            f"Tree of {path or '/'}:\n"
            "/\n"
            "├── startup.lua (256 bytes)\n"
            "├── programs/\n"
            "│   ├── test.lua (128 bytes)\n"
            "│   └── utils.lua (512 bytes)\n"
            "└── data/\n"
            "    └── config.txt (64 bytes)\n"
        )
    else:
        # WebSocket call
        result = await call_cc_command(deps.ws_client, "fs_tree", {"path": path, "max_depth": max_depth})
        tree_output = result.get("tree", "")
        return tree_output


async def cc_delete(deps: CCAgentDeps, path: str) -> str:
    """
    Delete a file or directory on the CC computer.

    Args:
        path: Path to delete

    Returns:
        Confirmation message
    """
    if deps.mode == "stub":
        # Stub implementation
        if path in deps.file_cache:
            del deps.file_cache[path]
        print(f"[STUB] Deleted {path}")
        return f"Deleted {path}"
    else:
        # WebSocket call
        result = await call_cc_command(deps.ws_client, "fs_delete", {"path": path})
        return f"Deleted {path}"


async def cc_write_and_run(deps: CCAgentDeps, path: str, content: str, args: list[str] | None = None) -> str:
    """
    Write a program AND immediately test it (combined operation).
    This is the preferred tool for code creation tasks.

    Args:
        path: Path on CC computer
        content: File content to write
        args: Optional command-line arguments for testing

    Returns:
        Combined result showing write success and test output
    """
    args = args or []

    if deps.mode == "stub":
        # Stub implementation
        deps.file_cache[path] = content
        print(f"[STUB] Writing {len(content)} bytes to {path}")
        print(f"[STUB] Running {path} with args {args}")

        # Check for syntax errors
        if "syntax error" in content.lower():
            return (
                f"Wrote {len(content)} bytes to {path}\n\n"
                f"Test Result: FAILED\n"
                f"Program {path} failed.\n"
                f"Error: syntax error in {path}"
            )

        return (
            f"Wrote {len(content)} bytes to {path}\n\n"
            f"Test Result: SUCCESS\n"
            f"Program {path} executed successfully.\n"
            f"Output:\n"
            f"Hello, World!\n"
            f"Program completed."
        )
    else:
        # WebSocket call - combined write and run
        result = await call_cc_command(deps.ws_client, "write_and_run", {
            "path": path,
            "content": content,
            "args": args
        })

        write_size = result.get("write_size", len(content))
        success = result.get("success", False)
        output = result.get("output", "")
        error = result.get("error", "")

        if success:
            return (
                f"Wrote {write_size} bytes to {path}\n\n"
                f"Test Result: SUCCESS\n"
                f"Program {path} executed successfully.\n"
                f"Output:\n{output}"
            )
        else:
            return (
                f"Wrote {write_size} bytes to {path}\n\n"
                f"Test Result: FAILED\n"
                f"Program {path} failed.\n"
                f"Error: {error}\n"
                f"Output:\n{output}"
            )


async def cc_run_program(deps: CCAgentDeps, path: str, args: list[str] | None = None) -> str:
    """
    Run a Lua program on the CC computer and capture its output.
    Programs have a 5-second timeout.

    Args:
        path: Path to the Lua program
        args: Optional command-line arguments (accessible in program as arg[1], arg[2], etc.)

    Returns:
        Program output, or error message if it failed
    """
    args = args or []

    if deps.mode == "stub":
        # Stub implementation
        print(f"[STUB] Running {path} with args {args}")

        # Check if file exists in cache
        if path in deps.file_cache:
            content = deps.file_cache[path]
            # Simple simulation - check for syntax errors
            if "syntax error" in content.lower():
                return f"Error: syntax error in {path}"

        return (
            f"Program {path} executed successfully.\n"
            "Output:\n"
            "Hello, World!\n"
            "Program completed."
        )
    else:
        # WebSocket call
        result = await call_cc_command(deps.ws_client, "run_program", {"path": path, "args": args})
        success = result.get("success", False)
        output = result.get("output", "")
        error = result.get("error", "")

        if success:
            return f"Program {path} executed successfully.\nOutput:\n{output}"
        else:
            return f"Program {path} failed.\nError: {error}\nOutput:\n{output}"


async def cc_shell(deps: CCAgentDeps, command: str) -> str:
    """
    Execute a CraftOS shell command on the CC computer.

    Args:
        command: Shell command to execute (e.g., "ls", "mkdir programs")

    Returns:
        Command output
    """
    if deps.mode == "stub":
        # Stub implementation
        print(f"[STUB] Executing shell: {command}")
        return f"Executed: {command}\nCommand completed successfully."
    else:
        # WebSocket call
        result = await call_cc_command(deps.ws_client, "shell_exec", {"command": command})
        success = result.get("success", False)
        output = result.get("output", "")

        if success:
            return f"Command executed successfully.\nOutput:\n{output}"
        else:
            return f"Command failed.\nOutput:\n{output}"


# ========================================
# Local Cache Tools
# ========================================

async def local_read(deps: CCAgentDeps, path: str) -> str:
    """
    Read a file from the local cache.
    File must have been previously cached with cc_read.

    Args:
        path: Path in cache

    Returns:
        Cached file content
    """
    if path not in deps.file_cache:
        raise ModelRetry(
            f"File '{path}' not in cache. Use cc_read first to cache it."
        )
    return deps.file_cache[path]


async def local_write(deps: CCAgentDeps, path: str, content: str) -> str:
    """
    Write a file to the local cache.
    Does NOT upload to CC computer - use cc_write for that.

    Args:
        path: Cache path
        content: File content

    Returns:
        Confirmation message
    """
    deps.file_cache[path] = content
    return f"Cached {len(content)} bytes at {path}"


async def local_patch(deps: CCAgentDeps, path: str, old_text: str, new_text: str) -> str:
    """
    Apply a simple find/replace patch to a cached file.
    File must be in cache first (use cc_read or local_read).

    Args:
        path: Path in cache
        old_text: Text to find and replace
        new_text: Replacement text

    Returns:
        Confirmation with number of replacements made
    """
    if path not in deps.file_cache:
        raise ModelRetry(
            f"File '{path}' not in cache. Use cc_read first to cache it."
        )

    content = deps.file_cache[path]

    if old_text not in content:
        raise ModelRetry(
            f"Pattern not found in {path}:\n'{old_text[:100]}...'\n\n"
            "Make sure the old_text matches exactly what's in the file."
        )

    count = content.count(old_text)
    deps.file_cache[path] = content.replace(old_text, new_text)

    return f"Patched {path}: replaced {count} occurrence(s)"


# ============================================================================
# Directive Parser (Extract info from PlannerAgent output)
# ============================================================================


def parse_directive(directive_text: str) -> dict[str, Any]:
    """
    Parse PlannerAgent's loose directive into structured data.

    Args:
        directive_text: Raw text output from PlannerAgent

    Returns:
        Dict with parsed directive info:
        {
            "type": "READ" | "LIST" | "WRITE_FILE" | "RUN" | "SHELL" | "DONE",
            "path": "...",  # for READ, LIST, WRITE_FILE, RUN
            "content": "...",  # for WRITE_FILE
            "language": "...",  # for WRITE_FILE
            "test_args": [...],  # for WRITE_FILE
            "args": [...],  # for RUN
            "command": "...",  # for SHELL
            "success": true/false,  # for DONE
            "summary": "...",  # for DONE
            "notes": "...",  # for DONE
        }

    Raises:
        ValueError: If directive format is invalid
    """
    lines = directive_text.strip().split("\n")
    result: dict[str, Any] = {}

    # Extract directive type
    directive_line = None
    for line in lines:
        if line.strip().startswith("DIRECTIVE:"):
            directive_line = line
            break

    if not directive_line:
        raise ValueError("No DIRECTIVE: line found in planner output")

    directive_type = directive_line.split("DIRECTIVE:", 1)[1].strip()
    result["type"] = directive_type

    # Parse based on type
    if directive_type == "READ":
        result["path"] = _extract_field(lines, "PATH:")

    elif directive_type == "LIST":
        result["path"] = _extract_field(lines, "PATH:", optional=True) or ""

    elif directive_type == "WRITE_FILE":
        result["path"] = _extract_field(lines, "PATH:")
        result["language"] = _extract_field(lines, "LANGUAGE:", optional=True) or "lua"
        result["content"] = _extract_code_block(directive_text)
        result["test_args"] = _extract_json_field(lines, "TEST_ARGS:", default=[])
        result["expect"] = _extract_field(lines, "EXPECT:", optional=True)

    elif directive_type == "RUN":
        result["path"] = _extract_field(lines, "PATH:")
        result["args"] = _extract_json_field(lines, "ARGS:", default=[])
        result["expect"] = _extract_field(lines, "EXPECT:", optional=True)

    elif directive_type == "SHELL":
        result["command"] = _extract_field(lines, "COMMAND:")
        result["expect"] = _extract_field(lines, "EXPECT:", optional=True)

    elif directive_type == "DONE":
        success_str = _extract_field(lines, "SUCCESS:")
        result["success"] = success_str.lower() in ("true", "yes", "1")
        result["summary"] = _extract_field(lines, "SUMMARY:")
        result["notes"] = _extract_field(lines, "NOTES:", optional=True)

    else:
        raise ValueError(f"Unknown directive type: {directive_type}")

    return result


def _extract_field(lines: list[str], field_name: str, optional: bool = False) -> str:
    """Extract a single-line field value."""
    for line in lines:
        if line.strip().startswith(field_name):
            value = line.split(field_name, 1)[1].strip()
            return value

    if optional:
        return ""

    raise ValueError(f"Required field {field_name} not found in directive")


def _extract_json_field(lines: list[str], field_name: str, default: Any = None) -> Any:
    """Extract a JSON field value."""
    import json

    for line in lines:
        if line.strip().startswith(field_name):
            value_str = line.split(field_name, 1)[1].strip()
            try:
                return json.loads(value_str)
            except json.JSONDecodeError:
                # Try eval as fallback (less safe but works for simple lists)
                try:
                    import ast
                    return ast.literal_eval(value_str)
                except (ValueError, SyntaxError):
                    if default is not None:
                        return default
                    raise ValueError(f"Invalid JSON in field {field_name}: {value_str}")

    if default is not None:
        return default

    raise ValueError(f"Required field {field_name} not found in directive")


def sanitize_code_content(s: str) -> str:
    """
    Remove accidental Markdown wrappers from code content.
    - Strips ```lang fences if the entire string is a fenced block
    - Strips single surrounding inline backticks if present
    """
    if not isinstance(s, str):
        return s

    text = s.strip()

    # Strip fenced code block if the whole payload is fenced
    m = re.match(r"^```(?:\w+)?\n(.*?)\n```$", text, re.DOTALL)
    if m:
        return m.group(1)

    # Strip single surrounding inline backticks
    if len(text) >= 2 and text.startswith("`") and text.endswith("`"):
        return text[1:-1].strip()

    return s


def _extract_code_block(text: str) -> str:
    """Extract code from a fenced code block (```language ... ```)."""
    # Match ```language\ncode\n```
    match = re.search(r"```(?:\w+)?\n(.*?)\n```", text, re.DOTALL)
    if match:
        return match.group(1)

    # Fallback: look for CONTENT: followed by text
    if "CONTENT:" in text:
        content_start = text.index("CONTENT:") + len("CONTENT:")
        # Find next field or end
        next_field = len(text)
        for field in ["TEST_ARGS:", "EXPECT:", "DIRECTIVE:"]:
            idx = text.find(field, content_start)
            if idx != -1 and idx < next_field:
                next_field = idx
        content = text[content_start:next_field].strip()
        # Remove leading ``` and trailing ``` if present
        content = re.sub(r"^```\w*\n?", "", content)
        content = re.sub(r"\n?```$", "", content)
        return content

    raise ValueError("No code block found in WRITE_FILE directive")


# ============================================================================
# Tool Registry and Manual Execution
# ============================================================================

# Map tool names to their functions
TOOL_REGISTRY = {
    "cc_read": cc_read,
    "cc_write": cc_write,
    "cc_write_and_run": cc_write_and_run,
    "cc_list": cc_list,
    "cc_tree": cc_tree,
    "cc_delete": cc_delete,
    "cc_run_program": cc_run_program,
    "cc_shell": cc_shell,
    "local_read": local_read,
    "local_write": local_write,
    "local_patch": local_patch,
}


def get_parsed(result: Any) -> AgentResponse:
    """Extract the AgentResponse from the agent result."""
    for attr in ("data", "output", "result"):
        v = getattr(result, attr, None)
        if isinstance(v, AgentResponse):
            return v
        if callable(v):
            try:
                out = v()
                if isinstance(out, AgentResponse):
                    return out
            except TypeError:
                pass
    raise AttributeError("Couldn't find parsed AgentResponse on result.")


def get_parsed_executor(result: Any) -> ToolRequestUnion:
    """Extract the ToolRequestUnion from the executor result."""
    for attr in ("data", "output", "result"):
        v = getattr(result, attr, None)
        if isinstance(v, (ToolRequest, FinalResult)):
            return v
        if callable(v):
            try:
                out = v()
                if isinstance(out, (ToolRequest, FinalResult)):
                    return out
            except TypeError:
                pass
    raise AttributeError("Couldn't find parsed ToolRequestUnion on result.")


# ============================================================================
# Helper Functions for JSON Extraction
# ============================================================================


def extract_json_from_text(text: str) -> tuple[str, dict | None]:
    """
    Extract JSON from planner output.

    Returns:
        (thinking_text, json_dict) where:
        - thinking_text is everything before the JSON
        - json_dict is the parsed JSON object or None if not found
    """
    import json
    import re

    # Try to find JSON at the end of the text
    # Look for patterns like {...} at the end
    json_pattern = r'\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}\s*$'
    match = re.search(json_pattern, text, re.MULTILINE | re.DOTALL)

    if match:
        json_str = match.group(0).strip()
        thinking_text = text[:match.start()].strip()

        try:
            json_dict = json.loads(json_str)
            return thinking_text, json_dict
        except json.JSONDecodeError:
            return text, None

    return text, None


def extract_last_json_object(text: str) -> str | None:
    """
    Extract the last JSON object from text using brace balancing.

    Scans from the end of the text to find the last complete {...} block.

    Args:
        text: Text potentially containing JSON

    Returns:
        The JSON string if found, None otherwise
    """
    if not text:
        return None

    # Scan from end to find last '}'
    last_close = text.rfind('}')
    if last_close == -1:
        return None

    # Scan backwards from last '}' to find matching '{'
    brace_count = 0
    for i in range(last_close, -1, -1):
        if text[i] == '}':
            brace_count += 1
        elif text[i] == '{':
            brace_count -= 1
            if brace_count == 0:
                # Found matching opening brace
                json_str = text[i:last_close + 1].strip()
                return json_str

    return None


def validate_executor_text(text: str) -> ExecutorResponse:
    """
    Extract and validate JSON from executor's plain text output.

    Args:
        text: Plain text output from executor agent

    Returns:
        Validated ExecutorResponse object (discriminated union)

    Raises:
        ValueError: If no JSON found in text
        ValidationError: If JSON doesn't match ExecutorResponse schema (with strict per-tool params)
    """
    json_str = extract_last_json_object(text)
    if not json_str:
        raise ValueError("No JSON object found in executor output")

    # Use TypeAdapter to validate the discriminated union
    # This will automatically choose the correct tool call subclass based on 'tool' field
    # and enforce extra="forbid" on all parameter models
    return ExecutorResponseAdapter.validate_json(json_str)


def check_directive_compatibility(planner_directive: dict | None, executor_response: ExecutorResponse) -> tuple[bool, str]:
    """
    Check if executor response matches what planner requested.

    If planner requested a specific tool, executor must return that tool (not early "final").

    Args:
        planner_directive: Parsed JSON from planner output (contains "tool" field)
        executor_response: Validated executor response

    Returns:
        (is_valid, error_message) - error_message empty if valid
    """
    # If we don't have planner directive, can't validate compatibility
    if not planner_directive:
        return True, ""

    # Check if planner requested a tool
    planner_tool = planner_directive.get("tool")
    if not planner_tool:
        # Planner didn't specify a tool (shouldn't happen but handle gracefully)
        return True, ""

    # If planner asked for task_complete, executor can return final
    if planner_tool == "task_complete":
        if executor_response.kind == "final":
            return True, ""
        else:
            return False, f"Planner requested task_complete but executor returned tool call: {executor_response.tool}"

    # Planner requested a real tool
    if executor_response.kind == "final":
        return False, (
            f"EARLY_FINAL_ERROR: Planner requested tool '{planner_tool}' but executor returned 'final'. "
            f"You cannot end the task without executing the requested tool first."
        )

    # Both are tool calls - check they match
    executor_tool = executor_response.tool
    if planner_tool != executor_tool:
        return False, (
            f"TOOL_MISMATCH_ERROR: Planner requested '{planner_tool}' but executor called '{executor_tool}'. "
            f"You must call the exact tool the planner specified."
        )

    return True, ""


# ============================================================================
# Two-Agent Execution Loop
# ============================================================================


async def execute_task_with_two_agents(
    planner: Agent,
    executor: Agent,
    prompt: str,
    deps: CCAgentDeps,
    max_steps: int = 20
) -> AgentResponse:
    """
    Execute a task using the two-agent architecture: PlannerAgent + ExecutorAgent.

    Control loop:
    1. Build context for PlannerAgent (full task memory)
    2. PlannerAgent outputs one directive
    3. ExecutorAgent translates directive to strict JSON tool call
    4. Execute tool, capture result
    5. Append to memory, repeat

    Validation errors bounce back to PlannerAgent for retry.

    Args:
        planner: PlannerAgent instance
        executor: ExecutorAgent instance
        prompt: User's task description
        deps: Dependencies for tools
        max_steps: Maximum iterations (default: 20)

    Returns:
        Final AgentResponse when task completes
    """
    # Initialize task memory
    memory = TaskMemory(
        task_id=deps.task_id,
        original_prompt=prompt
    )

    # Duplicate detection: track recent tool calls to prevent loops
    recent_tools: list[tuple[str, str]] = []  # (tool_name, args_hash)
    MAX_DUPLICATE_COUNT = 3

    for step in range(max_steps):
        print(f"\n{'='*60}")
        print(f"STEP {step + 1}/{max_steps}")
        print(f"{'='*60}")

        # ========================================
        # Phase 1: PlannerAgent - Create Directive
        # ========================================

        planner_context = memory.build_planner_context()
        print(f"\n[PLANNER] Context length: {len(planner_context)} chars")
        print(f"[PLANNER] Calling PlannerAgent...")

        # Try planner first time
        planner_result = await planner.run(planner_context, deps=deps)
        directive_text = planner_result.output if hasattr(planner_result, 'output') else str(planner_result)

        # Extract and display thinking vs JSON
        thinking, json_obj = extract_json_from_text(directive_text)

        if thinking:
            print(f"\n[PLANNER] THINKING:")
            print("=" * 80)
            print(thinking)
            print("=" * 80)

        if json_obj:
            print(f"\n[PLANNER] TOOL CALL:")
            print("=" * 80)
            import json
            print(json.dumps(json_obj, indent=2))
            print("=" * 80)
        else:
            # No JSON found - attempt self-repair once
            print(f"\n[PLANNER] WARNING: No JSON found in output - attempting self-repair...")

            repair_context = (
                f"{planner_context}\n\n"
                f"FORMAT ERROR: Your previous output did not contain a valid JSON directive.\n"
                f"Your output was:\n{directive_text}\n\n"
                f"You MUST output exactly ONE JSON object at the end of your response.\n"
                f"Format: {{\"tool\": \"tool_name\", \"parameters\": {{...}}, \"reasoning\": \"...\"}}\n"
                f"Please try again with correct JSON format."
            )

            planner_result_2 = await planner.run(repair_context, deps=deps)
            directive_text_2 = planner_result_2.output if hasattr(planner_result_2, 'output') else str(planner_result_2)

            thinking_2, json_obj_2 = extract_json_from_text(directive_text_2)

            if json_obj_2:
                print(f"\n[PLANNER] ✓ Self-repair succeeded, found JSON")
                print("=" * 80)
                print(json.dumps(json_obj_2, indent=2))
                print("=" * 80)
                directive_text = directive_text_2
                json_obj = json_obj_2
            else:
                # Still no JSON after repair - fail this step
                print(f"\n[PLANNER] ✗ Self-repair failed, still no JSON")
                error_msg = (
                    f"PLANNER_FORMAT_ERROR: No JSON directive found after 2 attempts.\n"
                    f"First output:\n{directive_text[:300]}...\n\n"
                    f"Second output:\n{directive_text_2[:300]}...\n\n"
                    f"Task cannot proceed without valid JSON directive."
                )
                memory.directives.append(error_msg)
                memory.tool_results.append({"ok": False, "error": error_msg})
                continue

        # Store directive in memory
        memory.directives.append(directive_text)

        # ========================================
        # Phase 2: ExecutorAgent - Extract and Validate Tool Call (2-Strike Policy)
        # ========================================

        print(f"\n[EXECUTOR] Translating directive to tool call...")

        executor_result = None
        validation_errors = []

        # Attempt 1: Normal executor run
        executor_input = directive_text
        exec_result_1 = await executor.run(executor_input, deps=deps)
        executor_text_1 = exec_result_1.output if hasattr(exec_result_1, 'output') else str(exec_result_1)

        print(f"\n[EXECUTOR] RAW OUTPUT (Attempt 1):")
        print("=" * 80)
        print(executor_text_1)
        print("=" * 80)

        try:
            # Validate attempt 1
            executor_result = validate_executor_text(executor_text_1)
            print(f"\n[EXECUTOR] ✓ Validation succeeded on attempt 1")

        except Exception as e1:
            # Validation attempt 1 failed
            validation_errors.append(str(e1))
            print(f"\n[EXECUTOR] ✗ Validation failed (Attempt 1): {e1}")

            # Attempt 2: Retry with validation error
            executor_retry_input = (
                f"{directive_text}\n\n"
                f"VALIDATION ERROR:\n{validation_errors[0]}\n\n"
                f"Return ONLY valid JSON matching ExecutorResponse schema.\n"
                f"Format: {{\"kind\": \"tool\"|\"final\", \"explanation\": \"...\", ...}}"
            )

            print(f"\n[EXECUTOR] Retrying with validation error feedback...")
            exec_result_2 = await executor.run(executor_retry_input, deps=deps)
            executor_text_2 = exec_result_2.output if hasattr(exec_result_2, 'output') else str(exec_result_2)

            print(f"\n[EXECUTOR] RAW OUTPUT (Attempt 2):")
            print("=" * 80)
            print(executor_text_2)
            print("=" * 80)

            try:
                # Validate attempt 2
                executor_result = validate_executor_text(executor_text_2)
                print(f"\n[EXECUTOR] ✓ Validation succeeded on attempt 2")

            except Exception as e2:
                # Validation attempt 2 failed - escalate to planner
                validation_errors.append(str(e2))
                print(f"\n[EXECUTOR] ✗ Validation failed (Attempt 2): {e2}")

                # Escalate to planner with both errors
                error_msg = (
                    f"EXECUTOR_VALIDATION_ERROR: Executor failed validation twice.\n\n"
                    f"Original planner directive:\n{directive_text}\n\n"
                    f"Validation error 1: {validation_errors[0]}\n\n"
                    f"Validation error 2: {validation_errors[1]}\n\n"
                    f"Executor output 1:\n{executor_text_1[:500]}...\n\n"
                    f"Executor output 2:\n{executor_text_2[:500]}...\n\n"
                    f"Please regenerate your directive with correct JSON format."
                )
                print(f"\n[ESCALATE] Bouncing back to planner with both validation errors")
                memory.tool_results.append({"ok": False, "error": error_msg})
                continue  # Go back to planner

        # If we got here, validation succeeded
        if executor_result is None:
            # Should not happen, but handle gracefully
            print(f"\n[ERROR] Unexpected state: executor_result is None after validation")
            continue

        # Print validated result
        print(f"\n[EXECUTOR] VALIDATED OUTPUT:")
        print("=" * 80)
        print(f"Kind: {executor_result.kind}")
        print(f"Explanation: {executor_result.explanation}")
        if executor_result.kind == "tool":
            print(f"Tool: {executor_result.tool}")
            print(f"Parameters: {executor_result.parameters}")
        elif executor_result.kind == "final":
            print(f"Success: {executor_result.success}")
            print(f"Message: {executor_result.message}")
        print("=" * 80)

        # Check directive compatibility (executor must call the tool planner requested)
        is_compatible, compat_error = check_directive_compatibility(json_obj, executor_result)
        if not is_compatible:
            print(f"\n[EXECUTOR] ✗ Directive compatibility check failed")
            print(f"[EXECUTOR] {compat_error}")
            # Treat as validation error - bounce back to executor once, then escalate
            if len(validation_errors) == 0:
                # First compatibility failure - retry executor once
                validation_errors.append(compat_error)

                executor_retry_input = (
                    f"{directive_text}\n\n"
                    f"COMPATIBILITY ERROR:\n{compat_error}\n\n"
                    f"You must return the exact tool the planner requested.\n"
                    f"Return ONLY valid JSON matching ExecutorResponse schema."
                )

                print(f"\n[EXECUTOR] Retrying with compatibility error feedback...")
                exec_result_3 = await executor.run(executor_retry_input, deps=deps)
                executor_text_3 = exec_result_3.output if hasattr(exec_result_3, 'output') else str(exec_result_3)

                print(f"\n[EXECUTOR] RAW OUTPUT (Compatibility Retry):")
                print("=" * 80)
                print(executor_text_3)
                print("=" * 80)

                try:
                    executor_result = validate_executor_text(executor_text_3)
                    print(f"\n[EXECUTOR] ✓ Validation succeeded on compatibility retry")

                    # Check compatibility again
                    is_compatible_2, compat_error_2 = check_directive_compatibility(json_obj, executor_result)
                    if not is_compatible_2:
                        # Still incompatible - escalate to planner
                        validation_errors.append(compat_error_2)
                        error_msg = (
                            f"EXECUTOR_COMPATIBILITY_ERROR: Executor failed compatibility check twice.\n\n"
                            f"Original planner directive:\n{directive_text}\n\n"
                            f"Compatibility error 1: {validation_errors[0]}\n\n"
                            f"Compatibility error 2: {validation_errors[1]}\n\n"
                            f"Please regenerate your directive."
                        )
                        print(f"\n[ESCALATE] Bouncing back to planner with compatibility errors")
                        memory.tool_results.append({"ok": False, "error": error_msg})
                        continue

                except Exception as e3:
                    # Validation failed on retry - escalate
                    validation_errors.append(str(e3))
                    error_msg = (
                        f"EXECUTOR_ERROR: Compatibility retry failed validation.\n\n"
                        f"Original planner directive:\n{directive_text}\n\n"
                        f"Compatibility error: {validation_errors[0]}\n\n"
                        f"Validation error: {validation_errors[1]}\n\n"
                        f"Please regenerate your directive."
                    )
                    print(f"\n[ESCALATE] Bouncing back to planner")
                    memory.tool_results.append({"ok": False, "error": error_msg})
                    continue
            else:
                # Already retried for schema validation, now compatibility also failed - escalate
                validation_errors.append(compat_error)
                error_msg = (
                    f"EXECUTOR_MULTI_ERROR: Executor had both validation and compatibility issues.\n\n"
                    f"Original planner directive:\n{directive_text}\n\n"
                    f"All errors: {', '.join(validation_errors)}\n\n"
                    f"Please regenerate your directive with correct format and tool."
                )
                print(f"\n[ESCALATE] Bouncing back to planner with multiple errors")
                memory.tool_results.append({"ok": False, "error": error_msg})
                continue

        print(f"\n[EXECUTOR] ✓ Directive compatibility check passed")

        # Store executor output in memory
        memory.tool_requests.append({
            "kind": executor_result.kind,
            "explanation": executor_result.explanation
        })

        # Send status update to WebSocket client
        if deps.mode == "websocket" and deps.ws_client:
            try:
                ws_manager = deps.ws_client.get("ws_manager")
                client_id = deps.ws_client.get("client_id")
                task_id = deps.ws_client.get("task_id")

                if ws_manager and client_id:
                    await ws_manager.send_to_client(client_id, {
                        "type": "status_update",
                        "task_id": task_id,
                        "message": executor_result.explanation
                    })
            except Exception as e:
                print(f"[WARNING] Failed to send status update: {e}")

        # ========================================
        # Phase 3: Handle Result
        # ========================================

        if executor_result.kind == "final":
            # Check if this is a validation error or actual task completion
            if executor_result.success is False and "validation" in executor_result.message.lower():
                # Validation error - bounce back to planner
                print(f"\n[EXECUTOR] VALIDATION ERROR: {executor_result.message}")
                error_msg = f"VALIDATION_ERROR: {executor_result.message}\nPlease fix your output and try again."
                memory.tool_results.append({"ok": False, "error": error_msg})
                continue
            else:
                # Task actually complete!
                print(f"\n[FINAL] Success: {executor_result.success}")
                print(f"\n[FINAL] Message: {executor_result.message}")

                # Return as AgentResponse for compatibility
                return AgentResponse(
                    kind="final",
                    explanation=executor_result.explanation,
                    success=executor_result.success,
                    message=executor_result.message,
                    details=executor_result.details or {}
                )

        # Execute tool
        if executor_result.kind == "tool":
            tool_name = executor_result.tool
            tool_params = executor_result.parameters

            # Convert Pydantic model to dict for tool execution
            tool_args = tool_params.model_dump()

            # Sanitize code content to remove accidental Markdown wrappers
            if tool_name in ("cc_write", "cc_write_and_run"):
                if "content" in tool_args and isinstance(tool_args["content"], str):
                    original_content = tool_args["content"]
                    tool_args["content"] = sanitize_code_content(tool_args["content"])
                    if original_content != tool_args["content"]:
                        print(f"[SANITIZER] Removed Markdown wrapper from content")

            print(f"\n[TOOL] Executing {tool_name}({tool_args})")

            # Check for duplicates
            import hashlib
            args_hash = hashlib.md5(str(sorted(tool_args.items())).encode()).hexdigest()
            recent_tools.append((tool_name, args_hash))
            if len(recent_tools) > MAX_DUPLICATE_COUNT:
                recent_tools.pop(0)

            # Count duplicates
            duplicate_count = sum(1 for t, h in recent_tools if t == tool_name and h == args_hash)
            if duplicate_count >= MAX_DUPLICATE_COUNT:
                error_msg = (
                    f"DUPLICATE_TOOL_CALL_ERROR: You've called {tool_name} with the same arguments {duplicate_count} times in a row.\n"
                    f"This suggests you're stuck in a loop. Try a different approach."
                )
                print(f"[ENFORCEMENT] {error_msg}")
                memory.tool_results.append({"ok": False, "error": error_msg})
                continue

            # Look up tool in registry
            if tool_name not in TOOL_REGISTRY:
                error_msg = f"Unknown tool: {tool_name}. Available: {list(TOOL_REGISTRY.keys())}"
                print(f"[ERROR] {error_msg}")
                memory.tool_results.append({"ok": False, "error": error_msg})
                continue

            tool_func = TOOL_REGISTRY[tool_name]

            # Execute tool
            try:
                tool_result = await tool_func(deps, **tool_args)

                # Print FULL tool result for debugging
                print(f"\n[TOOL_RESULT] RAW OUTPUT:")
                print("=" * 80)
                print(tool_result)
                print("=" * 80)

                # Store result in memory (cap at 100k chars to keep context manageable)
                MAX_RESULT_CHARS = 100_000
                memory.tool_results.append({
                    "ok": True,
                    "output": tool_result[:MAX_RESULT_CHARS]
                })

            except Exception as e:
                error_msg = f"{type(e).__name__}: {e}"
                print(f"\n[TOOL_ERROR] RAW ERROR:")
                print("=" * 80)
                print(error_msg)
                print("=" * 80)
                import traceback
                traceback.print_exc()
                memory.tool_results.append({"ok": False, "error": error_msg})

    # Max steps exceeded
    raise RuntimeError(f"Task exceeded maximum {max_steps} steps without completing")


# ============================================================================
# Legacy Single-Agent Execution (for backward compatibility)
# ============================================================================


async def execute_task_with_agent(agent: Agent, prompt: str, deps: CCAgentDeps, max_steps: int = 20) -> AgentResponse:
    """
    Execute a task using manual tool execution loop, WITH rolling memory.

    Pattern:
    - Call agent to get tool request or final result
    - Execute tool manually
    - Append tool call + result/error to transcript
    - Repeat until final result
    """
    # Rolling transcript ("memory") that we feed back to the model each step.
    # Keep it compact, but include enough context for multi-step debugging.
    history: list[str] = [f"USER_TASK: {prompt}"]

    # Tunable: keep the last ~25k chars of transcript (plus system prompt).
    MAX_HISTORY_CHARS = 1_500_000
    MAX_EVENT_CHARS = 100_000  # cap any single TOOL_RESULT chunk

    last_written_file: str | None = None  # Track files that need testing

    def _trim_history() -> None:
        # Trim from the front until under the budget; preserve USER_TASK if possible.
        while sum(len(x) + 1 for x in history) > MAX_HISTORY_CHARS and len(history) > 2:
            history.pop(1)

    def add(tag: str, message: str) -> None:
        msg = (message or "").strip()
        if not msg:
            return
        history.append(f"{tag}: {msg}")
        _trim_history()

    def build_prompt() -> str:
        # Tiny state summary (do NOT dump full cache).
        state_parts: list[str] = []
        if last_written_file:
            state_parts.append(f"needs_test={last_written_file}")
        state_line = "STATE: " + (" ".join(state_parts) if state_parts else "ok")

        return "\n\n".join(history + [state_line, "NEXT: Respond with exactly one JSON object matching AgentResponse."])

    for step in range(max_steps):
        print(f"\n[STEP {step + 1}]")

        # Call agent with full transcript + tiny state
        result = await agent.run(build_prompt(), deps=deps)
        response = get_parsed(result)

        print(f"[EXPLANATION] {response.explanation}")
        add("ASSISTANT", response.explanation)

        # Send explanation to WebSocket client if in websocket mode
        if deps.mode == "websocket" and deps.ws_client:
            try:
                ws_manager = deps.ws_client.get("ws_manager")
                client_id = deps.ws_client.get("client_id")
                task_id = deps.ws_client.get("task_id")

                if ws_manager and client_id:
                    await ws_manager.send_to_client(client_id, {
                        "type": "status_update",
                        "task_id": task_id,
                        "message": response.explanation
                    })
            except Exception as e:
                print(f"[WARNING] Failed to send status update: {e}")

        if response.kind == "final":
            # Check if agent tried to complete without testing
            if last_written_file:
                error_msg = (
                    f"CRITICAL ERROR: You wrote {last_written_file} but never tested it!\n"
                    f"You MUST call cc_run_program({last_written_file}) to test the program before completing.\n"
                    f"Testing is MANDATORY. Write → Test → Complete. You skipped the Test step."
                )
                print(f"[ENFORCEMENT] {error_msg}")
                add("ENFORCEMENT", error_msg)
                continue  # Force agent to test

            # Task complete!
            print(f"[FINAL] Success={response.success}, Message={response.message}")
            add("FINAL", f"success={response.success} message={response.message}")
            return response

        if response.kind != "tool":
            raise ValueError(f"Unknown response kind: {response.kind}")

        # Execute the requested tool
        if not response.tool_call:
            error_msg = (
                "CRITICAL JSON ERROR: You returned kind='tool' but did not include the 'tool_call' field!\n"
                "Your response must include:\n"
                '{\n'
                '  "kind": "tool",\n'
                '  "explanation": "...",\n'
                '  "tool_call": {\n'
                '    "tool": "tool_name",\n'
                '    "args": {...}\n'
                '  }\n'
                '}\n'
                "Please fix your JSON and include the tool_call field."
            )
            print(f"[ENFORCEMENT] {error_msg}")
            add("ENFORCEMENT", error_msg)
            continue

        tool_name = response.tool_call.tool
        tool_args = response.tool_call.args

        print(f"[TOOL] {tool_name}({tool_args})")
        add("TOOL", f"{tool_name} {tool_args}")

        # Look up tool in registry
        if tool_name not in TOOL_REGISTRY:
            error_msg = f"Unknown tool: {tool_name}. Available: {list(TOOL_REGISTRY.keys())}"
            print(f"[ERROR] {error_msg}")
            add("TOOL_ERROR", error_msg)
            continue

        tool_func = TOOL_REGISTRY[tool_name]

        # Execute tool
        try:
            tool_result = await tool_func(deps, **tool_args)
            preview = tool_result[:200] + ("..." if len(tool_result) > 200 else "")
            print(f"[TOOL_RESULT] {preview}")

            # Store a capped chunk of tool output to keep prompt sane
            add("TOOL_RESULT", tool_result[:MAX_EVENT_CHARS])

            # Track cc_write usage - file needs testing
            if tool_name == "cc_write" and "path" in tool_args:
                last_written_file = tool_args["path"]
                print(f"[TRACKING] File {last_written_file} written - MUST test before completing")
                add("STATE_UPDATE", f"wrote={last_written_file}")

            # Track cc_write_and_run usage - file was written AND tested in one call
            if tool_name == "cc_write_and_run" and "path" in tool_args:
                written_file = tool_args["path"]
                # Check if test succeeded or failed
                if "failed" in tool_result.lower() or "error:" in tool_result.lower():
                    print(f"[TRACKING] Write+Test FAILED for {written_file} - MUST fix and re-test")
                    last_written_file = written_file  # Still needs successful test
                    add("STATE_UPDATE", f"write_and_run_failed={written_file}")
                else:
                    print(f"[TRACKING] Write+Test SUCCEEDED for {written_file} - OK to complete")
                    last_written_file = None  # Both write and test done successfully
                    add("STATE_UPDATE", f"write_and_run_ok={written_file}")

            # Track cc_run_program usage - file was tested
            if tool_name == "cc_run_program" and "path" in tool_args:
                tested_file = tool_args["path"]
                if last_written_file == tested_file:
                    # Only clear the flag if the test SUCCEEDED
                    if "failed" in tool_result.lower() or "error:" in tool_result.lower():
                        print(f"[TRACKING] Test FAILED for {tested_file} - MUST fix and re-test before completing")
                        add("STATE_UPDATE", f"test_failed={tested_file}")
                        # Keep last_written_file set
                    else:
                        print(f"[TRACKING] Test SUCCEEDED for {tested_file} - OK to complete")
                        add("STATE_UPDATE", f"test_ok={tested_file}")
                        last_written_file = None
                else:
                    print(f"[TRACKING] Tested {tested_file}, but still need to test {last_written_file}")
                    add("STATE_UPDATE", f"tested_other={tested_file}")

        except Exception as e:
            error_msg = f"{type(e).__name__}: {e}"
            print(f"[TOOL_ERROR] {error_msg}")
            add("TOOL_ERROR", error_msg)

    # Max steps exceeded
    raise RuntimeError(f"Task exceeded maximum {max_steps} steps without completing")


# ============================================================================
# CLI Interface
# ============================================================================


async def run_task_interactive(task_description: str) -> None:
    """
    Run a single task interactively using manual tool execution.

    Args:
        task_description: What the user wants to accomplish
    """
    print(f"\n{'='*60}")
    print(f"TASK: {task_description}")
    print(f"{'='*60}\n")

    # Create agent
    agent = create_cc_agent()

    # Create dependencies
    deps = CCAgentDeps(mode="stub")

    try:
        # Run task with manual tool execution loop
        final_response = await execute_task_with_agent(agent, task_description, deps)

        print(f"\n{'='*60}")
        print("RESULT")
        print(f"{'='*60}")
        print(f"Success: {final_response.success}")
        print(f"Message: {final_response.message}")
        if final_response.details:
            print(f"Details: {final_response.details}")
        print()

    except Exception as e:
        print(f"\n{'='*60}")
        print("ERROR")
        print(f"{'='*60}")
        print(f"{type(e).__name__}: {e}")
        import traceback
        traceback.print_exc()


async def main() -> None:
    """CLI interface for testing the agent."""
    print("=" * 60)
    print("ComputerCraft LLM Agent - PydanticAI + Manual Tool Execution")
    print("=" * 60)
    print()
    print("Using qwen2.5-coder:14b with manual tool execution pattern.")
    print("Compatible with models that don't support native function calling.")
    print("Type 'quit' or 'exit' to quit.")
    print()

    while True:
        try:
            print("-" * 60)
            user_input = input("Task> ").strip()

            if not user_input:
                continue

            if user_input.lower() in ["quit", "exit", "q"]:
                print("Goodbye!")
                break

            # Run the task
            await run_task_interactive(user_input)

        except KeyboardInterrupt:
            print("\n\nInterrupted. Goodbye!")
            break
        except Exception as e:
            print(f"\nError: {e}")
            import traceback
            traceback.print_exc()


if __name__ == "__main__":
    asyncio.run(main())
