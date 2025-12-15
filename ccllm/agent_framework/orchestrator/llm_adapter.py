"""
LLM Adapter Module

Handles communication with Ollama for chat completions, manages conversation
histories, and parses tool calls from LLM responses.
"""

from typing import Dict, List, Optional, Any
import httpx
import json
import re
import traceback


class LLMAdapter:
    """Adapter for communicating with Ollama."""

    def __init__(
        self,
        base_url: str = "http://localhost:11434",
        model: str = "llama2",
        temperature: float = 0.7,
        max_tokens: int = 2048
    ):
        """
        Initialize LLM adapter.

        Args:
            base_url: Ollama API base URL
            model: Model name to use
            temperature: Sampling temperature
            max_tokens: Maximum tokens to generate
        """
        self.base_url = base_url
        self.model = model
        self.temperature = temperature
        self.max_tokens = max_tokens
        # Increase timeout for large contexts and thinking time (10 minutes)
        self.client = httpx.AsyncClient(timeout=600.0)

    async def chat_completion(
        self,
        messages: List[dict],
        tools: Optional[List[dict]] = None
    ) -> dict:
        """
        Send a chat completion request to Ollama.

        Args:
            messages: List of message dictionaries with 'role' and 'content'
            tools: Optional list of tool definitions

        Returns:
            Response dictionary with 'content' and optional 'tool_calls'
        """
        # Build the prompt with tool information if provided
        system_prompt = ""
        if tools:
            system_prompt = self._build_tool_prompt(tools)

        # Prepare messages
        formatted_messages = []
        for msg in messages:
            if msg["role"] == "system" and system_prompt:
                # Enhance system message with tool information
                formatted_messages.append({
                    "role": "system",
                    "content": msg["content"] + "\n\n" + system_prompt
                })
            else:
                formatted_messages.append(msg)

        # Make request to Ollama
        try:
            import time
            start_time = time.time()
            print(f"[LLM] Waiting for response from {self.model}...")

            response = await self.client.post(
                f"{self.base_url}/api/chat",
                json={
                    "model": self.model,
                    "messages": formatted_messages,
                    "stream": False,
                    "options": {
                        "temperature": self.temperature,
                        "num_predict": self.max_tokens
                    }
                }
            )

            elapsed = time.time() - start_time
            print(f"[LLM] Response received after {elapsed:.1f} seconds")

            response.raise_for_status()
            result = response.json()

            # Extract content
            content = result.get("message", {}).get("content", "")

            # Strip thinking tokens if present (qwen3 models output these)
            import re
            # Remove <think>...</think> blocks
            content = re.sub(r'<think>.*?</think>', '', content, flags=re.DOTALL)
            # Clean up any extra whitespace left behind
            content = content.strip()

            # Parse for tool calls
            tool_calls, parse_errors = self._parse_tool_calls(content)

            return {
                "content": content,
                "tool_calls": tool_calls,
                "parse_errors": parse_errors
            }

        except httpx.HTTPStatusError as e:
            print(f"[LLM] HTTP Error calling Ollama: {e.response.status_code} - {e.response.text[:500]}")
            traceback.print_exc()
            raise
        except httpx.TimeoutException as e:
            print(f"[LLM] Timeout calling Ollama (>120s): {e}")
            traceback.print_exc()
            raise
        except Exception as e:
            print(f"[LLM] Error calling Ollama: {type(e).__name__}: {str(e)}")
            traceback.print_exc()
            raise

    def _build_tool_prompt(self, tools: List[dict]) -> str:
        """
        Build a prompt section describing available tools.

        Args:
            tools: List of tool definitions

        Returns:
            Formatted tool description string
        """
        if not tools:
            return ""

        prompt = "\n\n# TOOL USAGE\n\n"
        prompt += "You can batch multiple tool calls in one response for efficiency.\n"
        prompt += "Server-side tools (send_status, patch_cached, lua_check_cached) execute immediately.\n"
        prompt += "CC-side tools (fs_read, fs_write, run_program) send commands and wait.\n\n"
        prompt += "## Single Tool Call Format:\n\n"
        prompt += "```json\n"
        prompt += '{"tool": "tool_name", "arguments": {"arg1": "value1"}}\n'
        prompt += "```\n\n"
        prompt += "## Multiple Tool Calls (Batched):\n\n"
        prompt += "Use separate ```json blocks:\n\n"
        prompt += "```json\n"
        prompt += '{"tool": "send_status", "arguments": {"message": "Reading file..."}}\n'
        prompt += "```\n"
        prompt += "```json\n"
        prompt += '{"tool": "fs_read", "arguments": {"path": "foo.lua"}}\n'
        prompt += "```\n\n"
        prompt += "## Edit Workflow Example:\n\n"
        prompt += "When editing existing code, use this pattern:\n\n"
        prompt += "```json\n"
        prompt += '{"tool": "fs_read", "arguments": {"path": "myfile.lua"}}\n'
        prompt += "```\n"
        prompt += "```json\n"
        prompt += '{"tool": "patch_cached", "arguments": {"path": "myfile.lua", "format": "replace_regex", "patch": "old_pattern|||new_replacement"}}\n'
        prompt += "```\n"
        prompt += "```json\n"
        prompt += '{"tool": "lua_check_cached", "arguments": {"path": "myfile.lua"}}\n'
        prompt += "```\n"
        prompt += "```json\n"
        prompt += '{"tool": "fs_write_cached", "arguments": {"path": "myfile.lua"}}\n'
        prompt += "```\n"
        prompt += "```json\n"
        prompt += '{"tool": "run_program", "arguments": {"path": "myfile.lua", "args": []}}\n'
        prompt += "```\n\n"
        prompt += "This batches: read → patch → syntax check → write → test in one response.\n"
        prompt += "Server tools run immediately; execution stops at the first CC-side tool.\n\n"
        prompt += "## Available Tools:\n\n"
        for tool in tools:
            prompt += f"**{tool['name']}**: {tool['description']}\n"
            if "parameters" in tool:
                prompt += "Parameters:\n"
                for param_name, param_info in tool["parameters"].items():
                    prompt += f"  - {param_name} ({param_info.get('type', 'any')}): {param_info.get('description', '')}\n"
            prompt += "\n"

        prompt += "\nIf a tool fails, you will receive the error and can try again with a different approach.\n"
        prompt += "When the task is complete, respond with a brief message (no tool call) explaining what you did.\n"

        return prompt

    def _parse_tool_calls(self, content: str) -> tuple[List[dict], List[str]]:
        """
        Parse tool calls from LLM response content.

        Looks for JSON blocks with tool calls in the format:
        ```json
        {
          "tool": "tool_name",
          "arguments": {...}
        }
        ```

        Args:
            content: LLM response content

        Returns:
            Tuple of (tool_calls, parse_errors)
        """
        tool_calls = []
        parse_errors = []

        print(f"[PARSE] Parsing content for tool calls...")
        print(f"[PARSE] Content length: {len(content)} chars")

        # Try 1: Look for JSON code blocks with ```json markers
        json_pattern = r"```json\s*(\{.*?\})\s*```"
        matches = list(re.finditer(json_pattern, content, re.DOTALL))
        print(f"[PARSE] Found {len(matches)} ```json code blocks")

        for i, match in enumerate(matches):
            try:
                json_str = match.group(1)
                print(f"[PARSE] Block {i+1}: {json_str[:100]}...")
                data = json.loads(json_str)

                # Check if it's a tool call
                if "tool" in data:
                    print(f"[PARSE] [OK] Valid tool call: {data['tool']}")
                    tool_calls.append({
                        "tool": data["tool"],
                        "arguments": data.get("arguments", {})
                    })
                else:
                    error_msg = f"JSON block {i+1} missing 'tool' field"
                    print(f"[PARSE] [X] {error_msg}")
                    parse_errors.append(error_msg)
            except json.JSONDecodeError as e:
                error_msg = f"Invalid JSON in block {i+1}: {str(e)}\nJSON was: {json_str[:200]}"
                print(f"[PARSE] [X] {error_msg}")
                parse_errors.append(error_msg)
                continue

        # Try 2: If no code blocks found, try parsing the entire content as JSON
        if not tool_calls:
            print("[PARSE] No code blocks found, trying raw JSON parse...")
            content_stripped = content.strip()
            if content_stripped.startswith("{") and content_stripped.endswith("}"):
                try:
                    data = json.loads(content_stripped)
                    if "tool" in data:
                        print(f"[PARSE] [OK] Valid tool call from raw JSON: {data['tool']}")
                        tool_calls.append({
                            "tool": data["tool"],
                            "arguments": data.get("arguments", {})
                        })
                except json.JSONDecodeError as e:
                    print(f"[PARSE] [X] Failed to parse as raw JSON: {e}")

        # Try 3: Look for JSON objects anywhere in the text (even with surrounding text)
        if not tool_calls:
            print("[PARSE] Trying to find JSON objects within text...")
            # Find all potential JSON objects (starting with { and ending with })
            # This regex finds balanced braces
            json_object_pattern = r'\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}'
            potential_jsons = re.findall(json_object_pattern, content)
            print(f"[PARSE] Found {len(potential_jsons)} potential JSON objects")

            for i, json_str in enumerate(potential_jsons):
                try:
                    data = json.loads(json_str)
                    if "tool" in data:
                        print(f"[PARSE] [OK] Valid tool call {i+1}: {data['tool']}")
                        tool_calls.append({
                            "tool": data["tool"],
                            "arguments": data.get("arguments", {})
                        })
                except json.JSONDecodeError:
                    continue

        if not tool_calls:
            print("[PARSE] [WARNING] No tool calls detected in response")
            print("[PARSE] Full response content:")
            print("-" * 60)
            print(content)
            print("-" * 60)

        return tool_calls, parse_errors

    def format_tool_result(self, tool_name: str, result: Any, error: Optional[str] = None) -> dict:
        """
        Format a tool result as a message for the conversation history.

        Args:
            tool_name: Name of the tool that was called
            result: Result from the tool
            error: Optional error message if tool failed

        Returns:
            Message dictionary
        """
        if error:
            content = f"[SYSTEM] Your '{tool_name}' call failed with error:\n{error}\n\nYou must fix this and try again."
        else:
            content = f"[SYSTEM] Your '{tool_name}' call succeeded. Result:\n```json\n{json.dumps(result, indent=2)}\n```"

        return {
            "role": "user",
            "content": content
        }

    async def close(self):
        """Close the HTTP client."""
        await self.client.aclose()
