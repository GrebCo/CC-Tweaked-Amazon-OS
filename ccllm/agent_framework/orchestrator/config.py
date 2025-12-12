"""
Configuration Handler Module

Defines LLM model parameters, task kinds, and available commands.
"""

from typing import Dict, List
from pydantic import BaseModel


class LLMConfig(BaseModel):
    """Configuration for LLM connection and parameters."""
    base_url: str = "http://localhost:11434"
    model: str = "gemma3:12b"
    temperature: float = 0.7
    max_tokens: int = 32768


class TaskKindConfig(BaseModel):
    """Configuration for a specific task kind."""
    name: str
    description: str
    allowed_commands: List[str]
    system_prompt: str


class CommandDefinition(BaseModel):
    """Definition of an available command/tool."""
    name: str
    description: str
    parameters: Dict[str, dict]


class Config:
    """Main configuration handler."""

    def __init__(self):
        # LLM configuration
        self.llm = LLMConfig()

        # Define task kinds
        self.task_kinds: Dict[str, TaskKindConfig] = {
            "general_agent": TaskKindConfig(
                name="general_agent",
                description="Long-running general purpose agent",
                allowed_commands=[
                    "shell_exec",
                    "fs_list",
                    "fs_read",
                    "fs_write",
                    "fs_delete",
                    "run_program"
                ],
                system_prompt=self._get_general_agent_prompt()
            ),
            "code_job": TaskKindConfig(
                name="code_job",
                description="One-off code inspection or modification task",
                allowed_commands=[
                    "fs_list",
                    "fs_read",
                    "fs_write",
                    "run_program"
                ],
                system_prompt="You are an AUTONOMOUS agent controlling a ComputerCraft computer.\n\n"
                              "YOU write the code. YOU test it. YOU fix errors. YOU verify it works.\n\n"
                              "When you call a tool, you will receive the result in the next message.\n"
                              "If a tool fails, YOU must fix the problem and try again.\n"
                              "If a program has errors, YOU must read the error, fix YOUR code, and re-run it.\n\n"
                              "Work step-by-step:\n"
                              "1. Write code with fs_write\n"
                              "2. Test it with run_program\n"
                              "3. If it fails, read the error, fix YOUR code, and try again\n"
                              "4. Repeat until it works\n\n"
                              "You are responsible for all code you write. Fix your own mistakes."
            )
        }

        # Define available commands
        self.commands: Dict[str, CommandDefinition] = {
            "shell_exec": CommandDefinition(
                name="shell_exec",
                description="Execute a CraftOS shell command and return the result",
                parameters={
                    "command": {
                        "type": "string",
                        "description": "The shell command to execute (e.g., 'ls', 'mkdir foo')"
                    }
                }
            ),
            "fs_list": CommandDefinition(
                name="fs_list",
                description="List files and directories at a given path",
                parameters={
                    "path": {
                        "type": "string",
                        "description": "Path to list (default: current directory)"
                    }
                }
            ),
            "fs_read": CommandDefinition(
                name="fs_read",
                description="Read the contents of a file",
                parameters={
                    "path": {
                        "type": "string",
                        "description": "Path to the file to read"
                    }
                }
            ),
            "fs_write": CommandDefinition(
                name="fs_write",
                description="Write content to a file (creates or overwrites)",
                parameters={
                    "path": {
                        "type": "string",
                        "description": "Path to the file to write"
                    },
                    "content": {
                        "type": "string",
                        "description": "Content to write to the file"
                    }
                }
            ),
            "fs_delete": CommandDefinition(
                name="fs_delete",
                description="Delete a file or directory",
                parameters={
                    "path": {
                        "type": "string",
                        "description": "Path to delete"
                    }
                }
            ),
            "run_program": CommandDefinition(
                name="run_program",
                description="Run a Lua program and return its output or errors. Arguments are accessible via the global 'arg' table (arg[1], arg[2], etc.) or via varargs (...)",
                parameters={
                    "path": {
                        "type": "string",
                        "description": "Path to the program to run"
                    },
                    "args": {
                        "type": "array",
                        "description": "Optional arguments to pass to the program. Access in your Lua code with: arg[1], arg[2], etc."
                    }
                }
            )
        }

    def _get_general_agent_prompt(self) -> str:
        """Get the system prompt for general agents."""
        return """You are an autonomous agent running on a ComputerCraft computer in Minecraft.

You have access to a CraftOS environment and can:
- Execute shell commands to interact with the file system and run programs
- Read, write, and modify Lua files
- Run Lua programs and see their output
- Create and use custom tools by writing Lua code

Your working directory is the root of the CraftOS file system. You should:
- Be careful when modifying or deleting files
- Test programs after creating or modifying them
- Use descriptive names for files and tools you create
- Store custom tools in the /tools directory

When you need to use a tool, respond with a JSON code block specifying the tool and arguments.
After each tool call, you will receive the result and can decide on the next action.

Remember: You are operating in a Minecraft computer, so file paths use forward slashes and
the file system is limited in size. Be efficient with storage."""

    def get_task_kind(self, kind: str) -> TaskKindConfig:
        """
        Get configuration for a task kind.

        Args:
            kind: Task kind name

        Returns:
            TaskKindConfig object

        Raises:
            ValueError: If task kind not found
        """
        if kind not in self.task_kinds:
            raise ValueError(f"Unknown task kind: {kind}")
        return self.task_kinds[kind]

    def get_commands_for_task(self, task_kind: str) -> List[dict]:
        """
        Get list of available commands for a task kind.

        Args:
            task_kind: Task kind name

        Returns:
            List of command definition dictionaries
        """
        kind_config = self.get_task_kind(task_kind)
        return [
            {
                "name": cmd_name,
                "description": self.commands[cmd_name].description,
                "parameters": self.commands[cmd_name].parameters
            }
            for cmd_name in kind_config.allowed_commands
            if cmd_name in self.commands
        ]


# Global configuration instance
config = Config()
