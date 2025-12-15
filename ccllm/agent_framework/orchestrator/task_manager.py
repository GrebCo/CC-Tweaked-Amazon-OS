"""
Task Manager Module

Manages task lifecycle, state, and history. Coordinates between command calls
and command results for active tasks.
"""

from typing import Dict, List, Optional, Any
from datetime import datetime
from enum import Enum
import uuid


class TaskStatus(str, Enum):
    """Possible task statuses."""
    QUEUED = "queued"
    RUNNING = "running"
    WAITING_FOR_COMMAND = "waiting_for_command"
    COMPLETED = "completed"
    FAILED = "failed"
    CANCELLED = "cancelled"


class Task:
    """Represents a single task/agent interaction with the LLM."""

    def __init__(
        self,
        task_id: str,
        kind: str,
        client_id: str,
        prompt: str,
        context: Optional[dict] = None,
        allowed_commands: Optional[List[str]] = None,
        metadata: Optional[dict] = None
    ):
        self.task_id = task_id
        self.kind = kind
        self.client_id = client_id
        self.prompt = prompt
        self.context = context or {}
        self.allowed_commands = allowed_commands or []
        self.metadata = metadata or {}
        self.status = TaskStatus.QUEUED
        self.history: List[dict] = []
        self.result: Optional[dict] = None
        self.error: Optional[str] = None
        self.created_at = datetime.now()
        self.updated_at = datetime.now()

        # Pending command call tracking
        self.pending_call_id: Optional[str] = None
        self.pending_command: Optional[str] = None

        # Error tracking to prevent infinite loops
        self.consecutive_errors = 0
        self.max_consecutive_errors = 3

        # File cache for server-side patching/diff operations
        # Key: file path (str), Value: file content (str)
        self.file_cache: dict = {}

    def add_to_history(self, entry: dict):
        """Add an entry to the conversation history."""
        self.history.append(entry)
        self.updated_at = datetime.now()

    def to_dict(self) -> dict:
        """Convert task to dictionary representation."""
        return {
            "task_id": self.task_id,
            "kind": self.kind,
            "client_id": self.client_id,
            "status": self.status.value,
            "prompt": self.prompt,
            "context": self.context,
            "allowed_commands": self.allowed_commands,
            "metadata": self.metadata,
            "result": self.result,
            "error": self.error,
            "created_at": self.created_at.isoformat(),
            "updated_at": self.updated_at.isoformat(),
            "history_length": len(self.history)
        }


class TaskManager:
    """Manages all tasks and their lifecycle."""

    def __init__(self):
        # Maps task_id to Task object
        self.tasks: Dict[str, Task] = {}

    def create_task(
        self,
        kind: str,
        client_id: str,
        prompt: str,
        context: Optional[dict] = None,
        allowed_commands: Optional[List[str]] = None,
        metadata: Optional[dict] = None
    ) -> Task:
        """
        Create a new task.

        Args:
            kind: Type of task (e.g., "general_agent", "code_job")
            client_id: ID of the CC client associated with this task
            prompt: Main prompt for the LLM
            context: Optional context dictionary
            allowed_commands: List of command names this task can use
            metadata: Optional metadata dictionary

        Returns:
            Created Task object
        """
        task_id = str(uuid.uuid4())
        task = Task(
            task_id=task_id,
            kind=kind,
            client_id=client_id,
            prompt=prompt,
            context=context,
            allowed_commands=allowed_commands,
            metadata=metadata
        )
        self.tasks[task_id] = task

        # Add initial system message to history
        task.add_to_history({
            "role": "system",
            "content": prompt
        })

        print(f"[TASK] Created task {task_id} of kind '{kind}' for client '{client_id}'")
        return task

    def get_task(self, task_id: str) -> Optional[Task]:
        """Get a task by ID."""
        return self.tasks.get(task_id)

    def update_status(self, task_id: str, status: TaskStatus, message: Optional[str] = None):
        """
        Update task status.

        Args:
            task_id: Task identifier
            status: New status
            message: Optional status message
        """
        task = self.get_task(task_id)
        if not task:
            print(f"[TASK] Cannot update status: task {task_id} not found")
            return

        task.status = status
        task.updated_at = datetime.now()
        print(f"[TASK] Task {task_id} status: {status.value}")

        if message:
            print(f"[TASK]   Message: {message}")

    def complete_task(self, task_id: str, result: dict):
        """
        Mark a task as completed with a result.

        Args:
            task_id: Task identifier
            result: Result dictionary
        """
        task = self.get_task(task_id)
        if not task:
            return

        task.status = TaskStatus.COMPLETED
        task.result = result
        task.updated_at = datetime.now()
        print(f"[TASK] Task {task_id} completed")

    def fail_task(self, task_id: str, error: str):
        """
        Mark a task as failed.

        Args:
            task_id: Task identifier
            error: Error message
        """
        task = self.get_task(task_id)
        if not task:
            return

        task.status = TaskStatus.FAILED
        task.error = error
        task.updated_at = datetime.now()
        print(f"[TASK] Task {task_id} failed: {error}")

    def set_pending_command(self, task_id: str, call_id: str, command: str):
        """
        Track a pending command call for a task.

        Args:
            task_id: Task identifier
            call_id: Unique call identifier
            command: Command name
        """
        task = self.get_task(task_id)
        if not task:
            return

        task.pending_call_id = call_id
        task.pending_command = command
        task.status = TaskStatus.WAITING_FOR_COMMAND
        task.updated_at = datetime.now()

    def clear_pending_command(self, task_id: str):
        """
        Clear pending command tracking for a task.

        Args:
            task_id: Task identifier
        """
        task = self.get_task(task_id)
        if not task:
            return

        task.pending_call_id = None
        task.pending_command = None

    def get_tasks_by_client(self, client_id: str) -> List[Task]:
        """
        Get all tasks for a specific client.

        Args:
            client_id: Client identifier

        Returns:
            List of Task objects
        """
        return [task for task in self.tasks.values() if task.client_id == client_id]

    def get_active_tasks(self) -> List[Task]:
        """
        Get all tasks that are not completed, failed, or cancelled.

        Returns:
            List of active Task objects
        """
        active_statuses = {TaskStatus.QUEUED, TaskStatus.RUNNING, TaskStatus.WAITING_FOR_COMMAND}
        return [task for task in self.tasks.values() if task.status in active_statuses]

    def list_tasks(self) -> List[dict]:
        """
        Get a list of all tasks as dictionaries.

        Returns:
            List of task dictionaries
        """
        return [task.to_dict() for task in self.tasks.values()]
