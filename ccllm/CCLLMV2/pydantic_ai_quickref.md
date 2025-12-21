# PydanticAI ultra condensed quick reference (CLI buddy edition)

Repo: https://github.com/pydantic/pydantic-ai  
Docs: https://ai.pydantic.dev/

This is a *cheat sheet*, not a tutorial. It’s written to be skimmed while coding.

---

## 0) Install + environment

```bash
pip install pydantic-ai
# or: pip install "pydantic-ai[openai]" / "pydantic-ai[anthropic]" / etc if you use extras
```

Set provider env vars (examples):
```bash
export OPENAI_API_KEY="..."
export ANTHROPIC_API_KEY="..."
```

---

## 1) The 3 core concepts

- **Agent**: the thing you run. Holds model config, prompt, tools, validators, retries.
- **Tools**: python functions the model can call (schema from type hints + docstrings).
- **Result validation**: optional structured output via `result_type` (Pydantic model / type).

---

## 2) Minimal “hello world”

```py
from pydantic_ai import Agent

agent = Agent("openai:gpt-4o-mini")  # model string varies by provider
res = agent.run_sync("Say hi in 5 words.")
print(res.data)   # parsed output (str by default)
print(res.all_messages())  # full message history
```

Async version:
```py
import asyncio
from pydantic_ai import Agent

agent = Agent("openai:gpt-4o-mini")

async def main():
    res = await agent.run("Say hi in 5 words.")
    print(res.data)

asyncio.run(main())
```

---

## 3) Structured output (the #1 feature people want)

```py
from pydantic import BaseModel, Field
from pydantic_ai import Agent

class Answer(BaseModel):
    title: str
    bullets: list[str] = Field(min_length=1, max_length=6)
    confidence: float = Field(ge=0, le=1)

agent = Agent("openai:gpt-4o-mini", result_type=Answer, retries=2)

res = agent.run_sync("Summarize Rust (game) in bullets.")
print(res.data.title)
print(res.data.bullets)
```

Notes:
- If the model outputs invalid JSON/schema, PydanticAI **retries** up to `retries=`.
- Keep schemas tight (too flexible → garbage, too strict → retry storms).

---

## 4) System prompt options

Static system prompt:
```py
agent = Agent(
    "openai:gpt-4o-mini",
    system_prompt="You are a concise assistant. Use tools when needed.",
)
```

Dynamic system prompt (computed per run):
```py
from pydantic_ai import Agent, RunContext

agent = Agent("openai:gpt-4o-mini")

@agent.system_prompt
def sys_prompt(ctx: RunContext[None]) -> str:
    return "You are concise. Today’s focus: patching and diffs."
```

Rule of thumb:
- Use **static** prompt for persona + always true constraints.
- Use **dynamic** prompt for per-run context (user, project, env).

---

## 5) Tools (function calling)

### 5.1 Basic tool

```py
from pydantic_ai import Agent, RunContext

agent = Agent("openai:gpt-4o-mini")

@agent.tool
def add(ctx: RunContext[None], a: int, b: int) -> int:
    "Add two integers."
    return a + b

print(agent.run_sync("What is add(2, 5)?").data)
```

Key rules:
- Parameters are extracted from the signature; everything except `RunContext` becomes tool schema.
- Type hints matter a lot (they’re the schema).
- Docstrings help the model pick the right tool.

### 5.2 Async tool

```py
@agent.tool
async def fetch(ctx: RunContext[None], url: str) -> str:
    "Fetch text from a URL."
    ...
```

### 5.3 Tool timeouts + retries behavior

Agent-level default:
```py
agent = Agent("openai:gpt-4o-mini", tool_timeout=20, retries=2)
```

If a tool errors/times out, the model gets a retry prompt (counts against retries).

### 5.4 Serial vs parallel tool calls

If a model returns multiple tool calls in one response, PydanticAI may run them concurrently.
If you need strict ordering, use:
```py
with agent.sequential_tool_calls():
    res = agent.run_sync("Do the multi-step thing.")
```

---

## 6) Dependencies (DI) and `RunContext`

If you need DB handles, API clients, config, etc — pass a deps object once and use it in tools/prompts/validators.

```py
from dataclasses import dataclass
from pydantic_ai import Agent, RunContext

@dataclass
class Deps:
    api_key: str
    base_url: str

agent = Agent("openai:gpt-4o-mini", deps_type=Deps)

@agent.tool
def whoami(ctx: RunContext[Deps]) -> str:
    return f"base_url={ctx.deps.base_url}"

deps = Deps(api_key="x", base_url="https://example.com")
print(agent.run_sync("Call whoami.", deps=deps).data)
```

Notes:
- `ctx.deps` is your DI container.
- This keeps tools testable and avoids globals.

---

## 7) Message history (memory across runs)

Persist messages and feed them back in:
```py
history = []

r1 = agent.run_sync("Remember: my name is Elliot.")
history = r1.all_messages()

r2 = agent.run_sync("What is my name?", message_history=history)
print(r2.data)
```

Important:
- If you pass `message_history`, PydanticAI assumes the history already contains a system prompt.
  (So it won’t generate a new one.)

---

## 8) Streaming

Pattern (names can vary by version/provider; check docs if your IDE disagrees):
```py
# res = agent.run_stream(...)  # async iterator of events/tokens
# for event in res: ...
```

Use streaming when you need:
- partial output to UI
- tool call events
- progress logging

---

## 9) Output validation hooks (when `result_type` isn’t enough)

Use validators when you want to:
- enforce “must include tool result X”
- post-process / normalize model output
- reject and retry when rules fail

Pattern:
```py
from pydantic_ai import Agent, RunContext, ModelRetry

agent = Agent("openai:gpt-4o-mini")

@agent.result_validator
def validate(ctx: RunContext[None], data: str) -> str:
    if "forbidden" in data.lower():
        raise ModelRetry("Do not include the forbidden word.")
    return data
```

`ModelRetry` tells the agent to ask the model to try again.

---

## 10) “How do I…?” recipes

### “Use two models (planner + coder)”
- Make **two Agents** with different models.
- Use a tool on the planner that calls the coder agent with the same deps.
- Keep the interface narrow: planner outputs a plan schema, coder outputs patch steps or code.

### “Force the model to use tools”
- Put it in the system prompt (“Use tools when you need facts or state”).
- Give tools strong names + docstrings.
- Make result schema require tool-produced fields (so it must call tools).

### “Avoid retry death spirals”
- Lower `retries` while debugging to surface failures quickly.
- Relax the schema slightly or provide clearer field descriptions.
- Add validators that give **specific** retry messages.

### “I need to log everything”
- Store `result.all_messages()` for each run.
- Consider event stream handlers (docs) to capture tool call events.

---

## 11) Debug checklist (fast)

When it “doesn’t call tools”:
- Tool signature type hints present?
- Tool has docstring describing when to use?
- Tool registered on the right agent instance?
- System prompt tells it tool use is expected?

When schema validation fails:
- Print the raw model output from messages.
- Reduce schema strictness (min/max lengths, enums) until it stabilizes.
- Increase `retries` only after schema/prompt is solid.

When memory “doesn’t work”:
- Are you passing `message_history=` from `all_messages()`?
- Did you accidentally drop the system prompt from the history?

---

## 12) Reference pointers (go here when stuck)

- Agents: https://ai.pydantic.dev/agents/
- Tools: https://ai.pydantic.dev/tools/
- Advanced tools (parallel/serial, approval, etc.): https://ai.pydantic.dev/tools-advanced/
- Dependencies (DI): https://ai.pydantic.dev/dependencies/
- Message history: https://ai.pydantic.dev/message-history/
- API reference (Agent): https://ai.pydantic.dev/api/agent/
- API reference (Tools): https://ai.pydantic.dev/api/tools/
- Multi-agent patterns: https://ai.pydantic.dev/multi-agent-applications/

---

### Tiny “starter skeleton” you can paste into a new project

```py
from dataclasses import dataclass
from pydantic import BaseModel, Field
from pydantic_ai import Agent, RunContext, ModelRetry

@dataclass
class Deps:
    # put config, clients, handles here
    api_key: str

class Result(BaseModel):
    answer: str
    steps: list[str] = Field(default_factory=list)

agent = Agent(
    "openai:gpt-4o-mini",
    deps_type=Deps,
    result_type=Result,
    retries=2,
    system_prompt="Be concise. Use tools when needed.",
)

@agent.tool
def ping(ctx: RunContext[Deps]) -> str:
    "Health check tool."
    return "pong"

@agent.result_validator
def no_empty(ctx: RunContext[Deps], data: Result) -> Result:
    if not data.answer.strip():
        raise ModelRetry("Answer must not be empty.")
    return data

if __name__ == "__main__":
    deps = Deps(api_key="...")
    r = agent.run_sync("Call ping then answer: what is 2+2?", deps=deps)
    print(r.data)
```

