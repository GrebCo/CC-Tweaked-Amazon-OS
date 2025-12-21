# Patch guide: Two agent planner executor architecture for CC LLM tool calls

This guide describes how to refactor your current single agent flow into a two agent system.

Goals
1. Qwen1 is the thinker and coder. It has full memory of the task and writes loose, human readable directives.
2. Qwen2 is the executor. It has no memory, it only interprets Qwen1 directives and turns them into strict, validated tool calls.
3. Qwen2 may ask the user questions only when Qwen1 explicitly requests it. Answers always flow back to Qwen1.
4. Tool calls remain strictly validated with Pydantic models at the boundary, even though Qwen1 uses loose schemas.
5. The system logs exactly what each model saw and produced, so you can diagnose early stopping and bad tool calls.

## High level architecture

Control loop, one iteration is one step
1. Gather state: task prompt, tool history, recent file snapshots, recent errors, user answers, and any extra notes.
2. Call Qwen1 with that full state, Qwen1 produces one directive.
3. Run Qwen2 on Qwen1 output only, Qwen2 emits exactly one action in strict schema.
4. Execute the tool call, capture result.
5. Append tool result to memory and repeat until Qwen1 says DONE or you hit a hard limit.

Important constraint: Qwen2 never plans. Qwen2 never designs code. Qwen2 never decides which tool to use. Qwen2 only translates Qwen1 intent into validated tool calls and enforces the strict Pydantic schema. In the strictest version, Qwen2 does not need to know the overall task at all (it can operate on the directive alone).

## What you need to add or clarify up front

1. Completion criteria
   Define what it means to be done for each task type. Example, for a TODO program fix, you require add, list, done, remove, stats to run without error, and at least one end to end scenario passes.

2. Step budget and stop conditions
   Set a maximum number of iterations and a maximum number of tool calls. When exceeded, return a failure result that includes the last Qwen1 plan and last tool error.

3. Retry policy, strict and predictable
   Do not let Qwen2 blindly retry the same invalid tool call.
   Suggested rule:
   - If Qwen2 output fails strict validation, give Qwen2 exactly one retry where you append the validation error and instruct it to fix only the JSON.
   - If the second attempt still fails validation, do not call tools. Append the validation error to Qwen1 memory and ask Qwen1 to restate the directive (or choose a different directive).

4. Ask user gating
   Qwen2 is allowed to call ask_user only when Qwen1 emits an ASK_USER directive with a WHY field.
   Add a per task limit, for example at most 2 questions unless the user explicitly asks for an interactive session.

5. Memory growth and truncation TODO
   Qwen1 gets the entire task context now. You will need a memory system later.
   Add a TODO in code: implement summarization and pinning of key facts, keep last N tool results verbatim, summarize older ones.

6. Security boundary
   In ComputerCraft the blast radius is usually limited, and you may choose to keep this permissive.
   Note: even with a denylist, an agent could potentially achieve similar effects via write_and_run, so treat sandboxing as a later project if you need stronger guarantees.
   Optional: still consider a lightweight confirm step for obviously destructive operations if you want a safety catch.

## Data model and schemas

You want two layers of schemas.

Layer A, loose directives from Qwen1
This is not strict JSON only. It is a human readable block format that Qwen2 can parse reliably.

Recommended directive formats, Qwen1 must output exactly one directive per turn.

A1 ASK_USER
DIRECTIVE: ASK_USER
QUESTION: <one line question>
WHY: <one line reason>
NEXT: <what Qwen1 will do with the answer>

A2 WRITE_FILE
DIRECTIVE: WRITE_FILE
PATH: /TODO.lua
LANGUAGE: lua
CONTENT:
```lua
full file contents here
```
THEN:
1 RUN /TODO.lua list
2 RUN /TODO.lua add 2 buy milk

A3 RUN
DIRECTIVE: RUN
PATH: /TODO.lua
ARGS: ["list"]
EXPECT: optional text

A4 SHELL
DIRECTIVE: SHELL
COMMAND: "ls"
EXPECT: optional text

A5 DONE
DIRECTIVE: DONE
SUMMARY: <one line>
NOTES: <optional>

Layer B, strict tool request from Qwen2
Qwen2 output is strict JSON validated by Pydantic before any tool call happens.

Example schema
1 kind, must be "tool" or "final"
2 explanation, short text you display to the user
3 tool, tool name
4 parameters, tool args

Example tool request JSON
{
  "kind": "tool",
  "explanation": "Writing updated TODO.lua and running list to verify the fix",
  "tool": "cc_write_and_run",
  "parameters": {
    "path": "/TODO.lua",
    "content": "...",
    "args": ["list"]
  }
}

Example final JSON
{
  "kind": "final",
  "explanation": "All core commands pass basic tests",
  "result": {
    "success": true,
    "message": "Fixed file IO, corrected escaping, verified add list done stats",
    "details": { "tests_run": ["list","add","done","stats"] }
  }
}

## Prompts

Qwen1 system prompt, planner and coder
Key points
1 You can think freely, you can write code freely.
2 You must output exactly one directive block in the formats above.
3 You must not call tools directly.
4 You must incorporate tool results and errors from memory.
5 You should propose concrete tests, not just claims.

Skeleton system prompt for Qwen1
You are Qwen1, the thinker and coder for a ComputerCraft automation system.
You will be given task context including previous steps, tool results, errors, and user answers.
Your job is to decide the next best step and output exactly one directive block.

Allowed directives are ASK_USER, WRITE_FILE, RUN, SHELL, DONE.
Follow the directive templates exactly.
When you write code, include the full file content inside a fenced code block.
When debugging, propose a small test after each change.
Do not claim success without a test that executed.

Qwen2 system prompt, executor and translator
Key points
1 You have no memory and you do not plan.
2 You receive Qwen1 directive and nothing else (no overall task context). Optionally you may also receive a tool catalog and the strict Pydantic schema.
3 You must output strict JSON matching the ToolRequest or Final schema.
4 If the directive is unclear or missing required fields, output a validation error as a final failure, or a tool request that asks Qwen1 for clarification via a special tool if you have one. Do not guess.

Skeleton system prompt for Qwen2
You are Qwen2, a strict executor.
Input is a single directive produced by Qwen1.
You must translate it into exactly one JSON object that matches the schema.
If DIRECTIVE is ASK_USER, call ask_user with the QUESTION.
If DIRECTIVE is WRITE_FILE, call cc_write_and_run, using PATH and the code block as content, and run the first THEN action if present.
If DIRECTIVE is RUN, call cc_run_program with PATH and ARGS.
If DIRECTIVE is DONE, output kind final with the provided summary.
Never invent code. Never invent paths. Never invent tool arguments.

## Orchestrator changes, implementation steps

Step 1 Add a memory store for Qwen1
1 Add a TaskMemory object per task_id.
2 Store
   a original prompt
   b all Qwen1 directives
   c all Qwen2 tool requests
   d all tool results and errors
   e all user answers
3 Provide a function build_qwen1_context(memory) that renders the full context into a single text input.

Recommended memory rendering format
TASK
<original prompt>

STATE
client_id, task_id, mode, time

FILES
optional cached file snippets

HISTORY
Step 1
Qwen1 directive
...
Qwen2 tool request
...
Tool result
...

Step 2
...

USER ANSWERS
Question, answer pairs

Step 2 Add Qwen1 agent
1 Create Agent for Qwen1 with output_type str.
2 Do not constrain to JSON only.
3 Set retries low, your logic handles retries by looping.

Step 3 Add Qwen2 agent
1 Create Agent for Qwen2 with output_type ToolRequestUnion, a Pydantic model.
2 Qwen2 input is only the Qwen1 directive text.
3 Qwen2 retries can be low, 1 or 2, because you will bounce errors to Qwen1.

Step 4 Add directive parser, optional but recommended
You can either
1 let Qwen2 parse Qwen1 directives directly, simplest
2 or do a light Python parse first, and give Qwen2 a pre digested structure, more robust

If you do Python pre parsing
1 parse DIRECTIVE field
2 extract PATH, QUESTION, and code block content
3 if parse fails, record error and ask Qwen1 to re emit directive

Step 5 Tool dispatch and strict validation
1 Run Qwen2 on the Qwen1 directive, get ToolRequest model instance.
2 Validate with Pydantic.
3 If validation fails, retry Qwen2 once with the validation error appended (Qwen2 must only repair the JSON).
4 If validation still fails, do not call any tools. Append the validation error to Qwen1 memory and go back to Qwen1.

Step 6 Ask user flow
1 Qwen2 emits tool request for ask_user.
2 You call ask_user and get answer.
3 Append answer to memory as a USER_ANSWER block.
4 Loop back to Qwen1.

Step 7 Execution, tests, and feedback
1 Execute tool
2 Capture output, errors, and any metadata
3 Append to memory
4 Loop

Step 8 Logging and transparency
Log these exact artifacts per step
1 Qwen1 input context string, optionally truncated in logs but store full in file
2 Qwen1 output directive
3 Qwen2 input directive
4 Qwen2 output tool request JSON
5 Tool call name and args
6 Tool result, stdout, stderr, and ok flag

This will let you confirm whether Qwen is being handicapped by output constraints and whether it is actually receiving the prior errors.

## Suggested guardrails to prevent failure spirals

Reminder: one Qwen1 directive should result in exactly one tool call (or one ask_user, or DONE). If you have multi step primitives, wrap them as explicit single tools like write_and_run so the rule stays true.

1 Duplicate tool call suppression
If the exact same tool call with the exact same args happens N times in a row (recommend 2 or 3), stop and send the repetition evidence to Qwen1.

2 Validation error bounce
If Qwen2 output fails validation twice in a row (initial attempt plus one retry), feed the validation error to Qwen1 and ask it to restate the directive.

3 Small steps first
Qwen1 should be instructed to produce minimal patches and test after each patch.

4 Separate write from run when needed
Your cc_write_and_run is convenient but can hide whether the failure was write or run.
Keep cc_write_and_run, but also keep cc_write and cc_run_program so Qwen1 can request separate steps when debugging.

## TODO memory upgrade later

Add a TODO in code for a future memory system
1 Keep a persistent MASTER PLAN from Qwen1 for the whole task (a short checklist and success criteria).
2 Keep a rolling event log of the last N steps, including the last N tool results verbatim.
3 Summarize older steps into a compact facts list (important discoveries, current failure, last known good state).
4 Pin key artifacts: current file version, current failing line, last stack trace, last planned tests.
5 Optional: store diffs instead of whole files for large patches, and store a hash of the current file so you can detect drift.

## Minimal acceptance test plan

You can build a single smoke test task in CC
1 Provide a broken TODO.lua
2 Ask the system to fix it
3 Require the final result to include proof, at least one run output for add, list, done, stats
4 Ensure no ask_user happens unless required

If this passes on Qwen, the architecture is working.

## Notes for your current codebase

Your orchestrator already has
1 WebSocket client routing
2 A tool layer that can read, write, and run
3 Step logging

The main changes are
1 Replace single agent loop with Qwen1 then Qwen2 loop
2 Add TaskMemory and context builder
3 Add strict ToolRequest models for Qwen2 output
4 Add bounce on validation errors rather than retries

End of guide
