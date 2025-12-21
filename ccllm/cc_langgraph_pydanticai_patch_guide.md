# Patch Guide: Migrate CC LLM Agent Framework to LangGraph + Pydantic AI (Dual LLM: Qwen Planner + Gemma Coder)

## What you have today (baseline)

Your orchestrator is a FastAPI WebSocket server that:
* Creates `Task` objects with a conversation history and an allowlist of commands fileciteturn10file13L24-L61
* Calls Ollama via `LLMAdapter.chat_completion()` and parses tool calls out of JSON code blocks embedded in the model’s text response fileciteturn10file7L41-L115 fileciteturn10file12L21-L83
* Supports “batching” by running server side tools immediately and stopping at the first CC side tool (or `ask_user`) fileciteturn10file10L13-L26
* Uses a file cache on the server to patch, diff, and syntax check Lua before writing back to the CC client fileciteturn10file2L1-L4 fileciteturn10file6L35-L66

This works, but you pay a lot of complexity for parsing and retry logic inside `process_task()` fileciteturn10file11L51-L75.

## Target end state (what we are building)

You will replace the “prompt plus regex JSON parsing” loop with:
* **LangGraph** to orchestrate a long running state machine, including pausing and resuming when you need CC results or user input (interrupts) citeturn2search0turn2search18
* **Pydantic AI** to enforce typed, validated model outputs and separate responsibilities across two models:
  * **Qwen3:14b** as a planner that produces a structured plan (no tools)
  * **Gemma3:12b** as an executor that produces a structured “next action” with tool calls (validated)

For Ollama integration, you will use Pydantic AI’s Ollama provider (OpenAI compatible API under the hood) citeturn1search7.

### Key behavior changes

1. The executor model no longer emits markdown with embedded JSON blocks.
2. Instead, it emits a **single JSON object** that matches a Pydantic schema (Pydantic AI will auto retry until it does).
3. “Task completion” is no longer inferred from “no tool calls” (your current prompt rule) fileciteturn10file0L20-L24.
   * Completion becomes explicit via `status: "complete"`.

## Migration strategy

Do this in two phases:
1. Phase A: Keep your existing command transport and batching semantics, but swap the LLM interface to Pydantic AI structured outputs.
2. Phase B: Wrap the Phase A loop in LangGraph with interrupt + resume so tasks become durable and easier to extend.

This guide is written as a patch guide (search and replace plus new files), not a full code dump.

---

# Phase A: Pydantic AI structured outputs (no LangGraph yet)

## Step A1: Add dependencies

Add these dependencies (choose the tool you use: pip, uv, poetry):
* `pydantic-ai`
* `langgraph` (you will use it in Phase B)
* `pydantic>=2`
* `typing-extensions` (safe)
* Optional but recommended: `logfire` (Pydantic ecosystem tracing)

Pydantic AI docs: citeturn1search1turn1search7  
LangGraph overview and install: citeturn2search5turn2search2

## Step A2: Update configuration to support two models

Edit `config.py` and replace your single `LLMConfig` with two configs.

### Patch: `config.py`

1. Add:
```py
class PlannerLLMConfig(BaseModel):
    base_url: str = "http://localhost:11434/v1"
    model: str = "qwen3:14b"
    temperature: float = 0.2
    max_tokens: int = 32768

class CoderLLMConfig(BaseModel):
    base_url: str = "http://localhost:11434/v1"
    model: str = "gemma3:12b"
    temperature: float = 0.2
    max_tokens: int = 32768
```

2. In `Config.__init__`, replace:
```py
self.llm = LLMConfig()
```
with:
```py
self.planner_llm = PlannerLLMConfig()
self.coder_llm = CoderLLMConfig()
```

3. Keep your `task_kinds` and `commands` as is for now. Your allowlist and tool schemas are already good fileciteturn10file9L41-L71 fileciteturn10file6L1-L66.

## Step A3: Add Pydantic output schemas

Create a new file: `agents/schemas.py`

```py
from __future__ import annotations

from typing import Any, Literal
from pydantic import BaseModel, Field

class ToolCall(BaseModel):
    tool: str
    arguments: dict[str, Any] = Field(default_factory=dict)

class ExecutorStep(BaseModel):
    # continue: run tools
    # need_user: ask_user tool call or direct question
    # complete: finish task with final_message
    status: Literal["continue", "need_user", "complete"]

    tool_calls: list[ToolCall] = Field(default_factory=list)

    # required when status="complete"
    final_message: str | None = None

    # required when status="need_user" (either user_question or an ask_user tool call)
    user_question: str | None = None

    # optional, short, for logs only (not chain of thought)
    note: str | None = None

class PlanStep(BaseModel):
    title: str
    details: str
    expected_tools: list[str] = Field(default_factory=list)

class TaskPlan(BaseModel):
    goal: str
    steps: list[PlanStep]
    risks: list[str] = Field(default_factory=list)
    success_criteria: list[str] = Field(default_factory=list)
```

## Step A4: Add Pydantic AI model wiring for Ollama

Create `agents/models.py`

```py
from __future__ import annotations

from pydantic_ai.models.openai import OpenAIChatModel
from pydantic_ai.providers.ollama import OllamaProvider

def make_ollama_model(model_name: str, base_url: str) -> OpenAIChatModel:
    # Pydantic AI supports Ollama via its OllamaProvider citeturn1search7
    # base_url should include /v1, eg http://localhost:11434/v1
    return OpenAIChatModel(
        model_name=model_name,
        provider=OllamaProvider(base_url=base_url),
    )
```

## Step A5: Create Planner and Coder agents

Create `agents/planner.py`

```py
from __future__ import annotations

from pydantic_ai import Agent
from .models import make_ollama_model
from .schemas import TaskPlan

def build_planner_agent(model_name: str, base_url: str) -> Agent[None, TaskPlan]:
    model = make_ollama_model(model_name, base_url)
    return Agent(
        model=model,
        output_type=TaskPlan,
        instructions=(
            "You are the planner.\n"
            "Return a structured plan for accomplishing the task.\n"
            "Do not write code. Do not call tools. Do not include chain of thought.\n"
            "Focus on sequencing, risks, and success criteria.\n"
        ),
    )
```

Create `agents/coder.py`

```py
from __future__ import annotations

from pydantic_ai import Agent
from .models import make_ollama_model
from .schemas import ExecutorStep

def build_coder_agent(model_name: str, base_url: str) -> Agent[None, ExecutorStep]:
    model = make_ollama_model(model_name, base_url)
    return Agent(
        model=model,
        output_type=ExecutorStep,
        instructions=(
            "You are the executor.\n"
            "You must return ONLY a JSON object matching the ExecutorStep schema.\n"
            "No markdown. No code fences. No extra keys.\n"
            "When status=continue, include at least one tool call.\n"
            "When status=complete, include final_message and no tool calls.\n"
            "When you need user input, use status=need_user and set user_question.\n"
        ),
    )
```

## Step A6: Swap `LLMAdapter` usage inside `process_task`

Today `process_task()` calls Ollama and then parses tool calls out of the assistant’s text fileciteturn10file11L51-L70. Replace that with:

1. Planner run once per task (store it in `task.context["plan"]`)
2. Coder run each tick (returns `ExecutorStep` with validated tool calls)
3. Execute tool calls using your existing `execute_tool_calls()` batching engine fileciteturn10file10L13-L26

### Patch: `main.py` initialization

Replace:

```py
llm_adapter = LLMAdapter(...)
```

with:

```py
from .agents.planner import build_planner_agent
from .agents.coder import build_coder_agent

planner_agent = build_planner_agent(
    model_name=config.planner_llm.model,
    base_url=config.planner_llm.base_url,
)
coder_agent = build_coder_agent(
    model_name=config.coder_llm.model,
    base_url=config.coder_llm.base_url,
)
```

### Patch: inside `process_task(task_id)`

Replace the “Call LLM” section and parsing logic with:

```py
# Build tool list for this task kind
tools = config.get_commands_for_task(task.kind)

# Planner (once)
if "plan" not in task.context:
    plan_prompt = (
        f"Task: {task.prompt}\n\n"
        f"Available tools: {[t['name'] for t in tools]}\n"
        "Return a plan."
    )
    plan = await planner_agent.run(plan_prompt)
    task.context["plan"] = plan.output.model_dump()

# Executor tick
exec_prompt = (
    f"Task: {task.prompt}\n\n"
    f"Plan: {json.dumps(task.context['plan'], indent=2)}\n\n"
    f"Available tools: {json.dumps(tools)}\n\n"
    f"Conversation so far: {json.dumps(task.history[-30:], indent=2)}\n\n"
    "Return the next ExecutorStep."
)

step = await coder_agent.run(exec_prompt)
decision = step.output

if decision.status == "complete":
    task_manager.complete_task(task_id, {"message": decision.final_message})
    await ws_manager.send_to_client(task.client_id, {
        "type": "task_update",
        "task_id": task_id,
        "status": "completed",
        "result": {"message": decision.final_message},
    })
    return

if decision.status == "need_user":
    tool_calls = [{"tool": "ask_user", "arguments": {"question": decision.user_question}}]
else:
    tool_calls = [tc.model_dump() for tc in decision.tool_calls]

await execute_tool_calls(task, tool_calls)
```

Notes:
* Keep your allowlist enforcement inside `execute_tool_calls()` fileciteturn10file10L39-L45.
* You can delete most of the parse error handling because Pydantic AI does that retry loop for you.
* Keep `task.consecutive_errors` for transport/tool failures, not JSON formatting.

At the end of Phase A, you still have the “re enter by scheduling `process_task()` again” behavior, but the model loop is now typed and far more reliable.

---

# Phase B: Wrap the runtime in LangGraph (durable, interruptible execution)

Phase A already gives you the two model separation and Pydantic validation. Phase B turns your orchestrator into an explicit state machine that can pause and resume cleanly for:
* CC side commands
* `ask_user`

LangGraph supports this with interrupts plus a checkpointer citeturn2search0turn2search3.

## Step B1: Introduce a small graph state

Create `agents/graph_state.py`

```py
from typing_extensions import TypedDict
from typing import Any, Literal

class AgentState(TypedDict, total=False):
    task_id: str
    phase: Literal["plan", "execute"]
    plan: dict[str, Any]
    last_step: dict[str, Any]
```

## Step B2: Build the LangGraph

Create `agents/graph.py`

```py
from __future__ import annotations

import json
from langgraph.graph import StateGraph, START, END
from langgraph.types import Command, interrupt  # interrupt enables pause until resume citeturn2search0

from .graph_state import AgentState
from .schemas import ExecutorStep
from .planner import build_planner_agent
from .coder import build_coder_agent

def build_agent_graph(task_manager, ws_manager, config, execute_tool_calls):
    planner_agent = build_planner_agent(config.planner_llm.model, config.planner_llm.base_url)
    coder_agent = build_coder_agent(config.coder_llm.model, config.coder_llm.base_url)

    async def ensure_plan(state: AgentState):
        task = task_manager.get_task(state["task_id"])
        tools = config.get_commands_for_task(task.kind)

        if "plan" in state:
            return state

        plan_prompt = (
            f"Task: {task.prompt}\n\n"
            f"Available tools: {[t['name'] for t in tools]}\n"
            "Return a plan."
        )
        plan = await planner_agent.run(plan_prompt)
        state["plan"] = plan.output.model_dump()
        state["phase"] = "execute"
        return state

    async def decide_next(state: AgentState):
        task = task_manager.get_task(state["task_id"])
        tools = config.get_commands_for_task(task.kind)

        exec_prompt = (
            f"Task: {task.prompt}\n\n"
            f"Plan: {json.dumps(state.get('plan', {}), indent=2)}\n\n"
            f"Available tools: {json.dumps(tools)}\n\n"
            f"Conversation so far: {json.dumps(task.history[-30:], indent=2)}\n\n"
            "Return the next ExecutorStep."
        )
        step = await coder_agent.run(exec_prompt)
        state["last_step"] = step.output.model_dump()
        return state

    async def act(state: AgentState):
        task = task_manager.get_task(state["task_id"])
        step = ExecutorStep.model_validate(state["last_step"])

        if step.status == "complete":
            await ws_manager.send_to_client(task.client_id, {
                "type": "task_update",
                "task_id": task.task_id,
                "status": "completed",
                "result": {"message": step.final_message},
            })
            task_manager.complete_task(task.task_id, {"message": step.final_message})
            return Command(goto=END)

        if step.status == "need_user":
            # Pause graph and return the question
            interrupt({"kind": "user", "question": step.user_question})  # citeturn2search18
            return state

        tool_calls = [tc.model_dump() for tc in step.tool_calls]
        outcome = await execute_tool_calls(task, tool_calls)

        if outcome["status"] == "waiting_for_command":
            interrupt({"kind": "command", "call_id": outcome["call_id"]})
            return state

        return state

    g = StateGraph(AgentState)
    g.add_node("ensure_plan", ensure_plan)
    g.add_node("decide_next", decide_next)
    g.add_node("act", act)

    g.add_edge(START, "ensure_plan")
    g.add_edge("ensure_plan", "decide_next")
    g.add_edge("decide_next", "act")
    g.add_edge("act", "decide_next")

    return g.compile()
```

## Step B3: Refactor `execute_tool_calls` to return an outcome

Right now, `execute_tool_calls` stops execution by returning early. For LangGraph, make it return a structured outcome.

Patch:
```py
async def execute_tool_calls(task, tool_calls: List[dict]) -> dict:
    '''
    Returns:
      {"status": "done"} or
      {"status": "waiting_for_command", "call_id": "...", "command": "..."} or
      {"status": "waiting_for_user"} or
      {"status": "error", "error": "..."}
    '''
```

When you send a CC side tool, return `waiting_for_command` plus call_id. You already generate call_id today fileciteturn10file11L1-L14.

## Step B4: Add a runner that manages invoke and resume

Create `agents/runner.py`

```py
from __future__ import annotations

from langgraph.checkpoint.memory import MemorySaver
from langgraph.types import Command

class AgentRunner:
    def __init__(self, graph):
        self.graph = graph
        self.checkpointer = MemorySaver()

    async def start(self, task_id: str):
        # thread_id is the checkpoint key citeturn2search3
        await self.graph.ainvoke(
            {"task_id": task_id, "phase": "plan"},
            config={"configurable": {"thread_id": task_id}, "checkpointer": self.checkpointer},
        )

    async def resume(self, task_id: str, resume_payload: dict):
        return await self.graph.ainvoke(
            Command(resume=resume_payload),
            config={"configurable": {"thread_id": task_id}, "checkpointer": self.checkpointer},
        )
```

## Step B5: Wire runner into WebSocket handlers

### Patch: on create_task

Instead of:
```py
asyncio.create_task(process_task(task.task_id))
```
call:
```py
asyncio.create_task(agent_runner.start(task.task_id))
```

Your task creation flow is here fileciteturn10file5L108-L110.

### Patch: on command_result

Right now you clear pending command and schedule `process_task()` again fileciteturn10file10L1-L7.

Replace that “continue processing” section with:
```py
await agent_runner.resume(task_id, {"kind": "command", "result": message})
```

Similarly, when the user answers an `ask_user` prompt, resume with:
```py
await agent_runner.resume(task_id, {"kind": "user", "answer": user_text})
```

---

# Prompt and UX adjustments

Your current `code_job` system prompt is heavily shaped around “json blocks in markdown” fileciteturn10file0L1-L24 and the adapter prompt shows examples of batched json blocks fileciteturn10file8L1-L13.

After Phase A, adjust the `code_job` prompt to:
* Remove “every response must have a ```json block”
* Replace with “every response must be a single JSON object matching ExecutorStep”
* Keep the same operational rules about batching and using `fs_write_cached`

---

# Validation and testing checklist

1. Smoke test: start server, connect CC client, create a trivial task that lists a directory.
2. Confirm that the coder returns a valid `ExecutorStep` without retries.
3. Confirm that `execute_tool_calls` still enforces allowlist fileciteturn10file10L39-L45.
4. Confirm that CC side tool calls still stop the batch and wait for `command_result`.
5. Confirm that `patch_cached` and `lua_check_cached` still operate on `task.file_cache` fileciteturn10file2L1-L4.
6. For LangGraph interrupts:
   * Confirm the graph pauses on CC tool or user question
   * Confirm `resume` continues from the same point citeturn2search0turn2search18
7. If you run uvicorn with multiple workers, switch the checkpointer from MemorySaver to a persistent option and ensure sticky routing or shared persistence.

---

# Quick summary of files you will touch

Existing files to modify:
* `config.py` add planner and coder configs, update prompts
* `main.py` replace llm_adapter usage, wire `AgentRunner`
* `llm_adapter.py` can be kept for fallback, but should no longer be the default
* `task_manager.py` and `websocket_manager.py` can remain as is fileciteturn10file1L13-L73

New files to add:
* `agents/schemas.py`
* `agents/models.py`
* `agents/planner.py`
* `agents/coder.py`
* `agents/graph_state.py`
* `agents/graph.py`
* `agents/runner.py`

If you follow Phase A then Phase B, you will have a clean, typed, interruptible dual LLM agent architecture without losing any of your current transport and batching behavior.
