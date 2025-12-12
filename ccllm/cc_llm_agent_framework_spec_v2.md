# CC LLM Agent Framework – Architecture Spec

This document describes a general framework for integrating a locally hosted language model with ComputerCraft (or CC:Tweaked) computers.

The goal is to create a flexible system where:

- A central LLM service can create and manage long running tasks.
- CC computers connect to this service over WebSocket.
- The LLM can execute CraftOS commands (for example `shell.run("dir")`), create and edit Lua files, and run programs.
- You can define custom tools, and the LLM can also create or modify tools by editing Lua code that the CC side loads dynamically.

This spec is intentionally generic so it can support many different projects.

---

## 1. High level architecture

There are three main parts.

1. **LLM Orchestrator Service**

   - Runs on a regular computer or server.
   - Uses FastAPI for HTTP and WebSocket endpoints.
   - Uses Ollama to run one or more local models.
   - Manages long lived "tasks" representing agents or jobs.
   - Translates between LLM tool calls and JSON messages to CC computers.

2. **CC Agent Host**

   - A ComputerCraft computer that connects to the orchestrator via WebSocket.
   - Exposes a registry of commands (tools) the LLM can call.
   - Provides core tools for:
     - Executing CraftOS shell commands.
     - Reading and writing files.
     - Running Lua programs and reporting results.
   - Can load and register additional tools from Lua scripts, and those scripts themselves can be edited by the LLM.

3. **Other CC Clients (optional)**

   - Any additional CC computers can connect as clients.
   - They can register their own tools.
   - They can also create tasks on the orchestrator and observe results.

The orchestrator is model agnostic aside from the fact that it talks to Ollama. The CC side is designed so that tools and behavior are configured in Lua files and can be modified or extended over time.

---

## 2. Goals and requirements

### 2.1 Functional goals

- Allow the LLM to act as an autonomous agent that runs for long periods of time.
- Give the LLM the ability to:
  - Execute arbitrary CraftOS shell commands through a controlled interface.
  - Create, read, update and delete Lua files and other files.
  - Run Lua programs and see any errors output.
  - Use custom tools that are implemented as Lua modules or scripts.
  - Create new tools or edit existing tools and then use them.

- Support multiple CC computers connecting to the same orchestrator.

### 2.2 Non functional goals

- Framework should be reusable across many different projects.
- Avoid embedding project specific logic into the orchestrator.
- Keep the protocol simple and JSON based for easy inspection.
- Be tolerant of slow LLM response times. Tasks may run for hours or days.

---

## 3. Core concepts

### 3.1 Task

A task represents a single continuous interaction with the LLM. Examples include:

- A long running agent that continuously reacts to environment information.
- A one off job such as “inspect these files and suggest improvements”.

Properties of a task:

- `task_id`: unique identifier.
- `kind`: string describing the type (for example `"general_agent"`, `"code_job"`).
- `status`: `"queued"`, `"running"`, `"waiting_for_command"`, `"completed"`, `"failed"`, `"cancelled"`.
- `client_id`: primary CC client associated with the task (optional).
- `allowed_commands`: names of tools the task is permitted to use.
- `history`: conversation and tool call history used for LLM context.
- `metadata`: arbitrary extra fields that projects can use.

### 3.2 Command (tool)

A command is an operation that the LLM can ask a CC client to perform. It has:

- A name, such as `shell_exec` or `fs_write`.
- An argument schema (expressed descriptively in prompts).
- A result structure (also described in prompts).
- An implementation on a CC computer.

Commands are registered on the CC side and referenced by name in LLM prompts. The orchestrator does not implement most commands itself, it forwards calls to the relevant CC client.

### 3.3 Client

A client is a CC computer that connects to the orchestrator WebSocket and identifies itself with a `client_id`. A single orchestrator can manage multiple clients at once.

Each client:

- Maintains its own set of registered commands.
- May create tasks or simply execute commands for other tasks.
- Implements a small client side library to handle the WebSocket protocol.

---

## 4. Communication protocol (WebSocket, JSON)

All communication between CC computers and the orchestrator uses a WebSocket with text messages containing JSON objects.

### 4.1 General rules

- Every message has a `"type"` field that indicates message type.
- Errors are reported with `type: "error"` and an explanatory message.
- Message fields use snake_case.

### 4.2 Messages from CC to orchestrator

#### 4.2.1 Create task

Sent by a CC client to start a new task.

Fields:

- `type: "create_task"`
- `request_id: string` – identifier chosen by the client so it can match responses.
- `task_kind: string` – description of the task type.
- `client_id: string` – id of the sending client.
- `prompt: string` – main natural language prompt for the LLM.
- `context: object` – optional extra structured information.
- `allowed_commands: [string]` – names of tools this task may use.

The orchestrator responds with a `task_created` message.

#### 4.2.2 Command result

Sent by a CC client after executing a command requested by the LLM.

Fields:

- `type: "command_result"`
- `task_id: string`
- `call_id: string`
- `ok: boolean`
- `result: object` – present when `ok` is true.
- `error: string` – present when `ok` is false.

#### 4.2.3 Optional control messages

- `type: "cancel_task"` with `task_id: string` to request cancellation.
- `type: "ping"` for keep alive if desired.

### 4.3 Messages from orchestrator to CC

#### 4.3.1 Task created

Response to `create_task`.

Fields:

- `type: "task_created"`
- `request_id: string`
- `task_id: string`
- `status: string` – initial status, such as `"queued"`.

#### 4.3.2 Task update

Status update.

Fields:

- `type: "task_update"`
- `task_id: string`
- `status: string`
- `progress: number` – optional, from 0 to 1.
- `message: string` – optional human readable text.

#### 4.3.3 Task completed

Final result of a task.

Fields:

- `type: "task_completed"`
- `task_id: string`
- `result: object`

The `result` structure is task specific.

#### 4.3.4 Task failed

Failure information for a task.

Fields:

- `type: "task_failed"`
- `task_id: string`
- `error: string`

#### 4.3.5 Command call

Sent when the LLM requests a tool.

Fields:

- `type: "command_call"`
- `task_id: string`
- `call_id: string`
- `command: string`
- `args: object`

The client must look up `command` in its local registry, execute it with `args`, then send a `command_result` message.

---

## 5. Orchestrator design (FastAPI and Ollama)

The orchestrator is responsible for:

- Managing WebSocket connections from CC clients.
- Tracking tasks and their state.
- Communicating with the LLM via Ollama.
- Transforming LLM tool calls into `command_call` messages and handling `command_result` responses.

### 5.1 Main modules

Suggested logical modules:

1. **WebSocket manager**

   - Keeps a mapping of `client_id` to WebSocket connection.
   - Accepts new connections and associates them with client ids.
   - Forwards messages from clients to the task manager.
   - Provides helper functions to send a message to a given client id.

2. **Task manager**

   - Stores tasks indexed by `task_id`.
   - Creates tasks on request from CC clients.
   - Updates status, progress and results.
   - Coordinates between `command_call` and `command_result` for a task.

3. **LLM adapter**

   - Wraps calls to Ollama for chat style completions.
   - Maintains conversation histories per task.
   - Represents tool calls in a way the LLM can use.
   - Provides an interface such as “step this task once”, which:
     - Sends a prompt and recent history to the model.
     - Inspects the response for a tool call or final answer.
     - Either triggers a `command_call` or updates the task result.

4. **Configuration handler**

   - Defines LLM model name and parameters (temperature, maximum tokens, etc).
   - Defines task kinds and which commands are allowed for each.

5. **HTTP endpoints (optional)**

   - Provide diagnostic and monitoring endpoints, such as:
     - List of tasks and their statuses.
     - List of connected clients.
     - Basic health check.

### 5.2 Interaction with Ollama

The orchestrator uses the Ollama HTTP API to send chat style requests.

Requirements:

- Support system and user messages.
- Provide tool information inside the prompt or using a structured tools feature if available.
- Enforce a format for tool calls that the orchestrator can parse reliably.

The overall loop for a task step is:

1. Collect the last part of the conversation history for the task.
2. Include a description of available tools and their arguments.
3. Call the model through Ollama.
4. If the model returns a pure answer, update the task result and mark as completed.
5. If the model requests a tool:
   - Create a `command_call` record for the task.
   - Send a `command_call` message on the appropriate CC client.
   - Wait for the matching `command_result`.
   - Append a tool result message to the conversation history.
   - Repeat the process to continue generation.

The orchestrator should support long running tasks by:
- Storing tasks in memory and optionally persisting state if desired.
- Allowing tasks to be stepped periodically by a scheduler or on demand.

---

## 6. CC client library behavior

Each CC computer uses a common client side library to handle the protocol.

Responsibilities of the library:

- Open a WebSocket connection to the orchestrator using `http.websocket`.
- Manage message handling and event dispatch.
- Provide an API to:
  - Start tasks.
  - Register commands.
  - Retrieve task status locally if desired.

### 6.1 Local data structures

The client library maintains:

- `ws_url`: WebSocket endpoint URL.
- `client_id`: string identifying this CC computer.
- `commands`: a mapping from command name to handler function.
- `tasks`: mapping from `task_id` to task metadata.
- `pending_requests`: mapping from `request_id` to callbacks used for `task_created` responses.

### 6.2 Command registration

The library provides a function to register tools:

- Input: `name` (string) and `handler` (function taking args, task id, call id).
- The handler returns a result object or throws an error.

When a `command_call` message is received, the library:

- Looks up the handler by command name.
- Calls it inside a protected context.
- Sends a `command_result` message containing either the returned result or an error description.

### 6.3 Task creation and updates

The library provides a function to create a task:

- Accepts task kind, prompt, context and allowed commands.
- Generates a `request_id`.
- Sends a `create_task` message.
- Stores a callback associated with `request_id` to handle `task_created`.

Upon receiving `task_created`, `task_update`, `task_completed` and `task_failed` messages, the library updates its local `tasks` table and may optionally raise local events (for example `os.queueEvent`) so calling programs can react.

---

## 7. Core built in tools on the agent host

The agent host CC computer provides basic tools that are generally useful for many projects.

### 7.1 Shell command execution

Tool: `shell_exec`

Purpose:

- Let the LLM execute CraftOS commands in a controlled way.
- Support commands such as `dir`, `mkdir`, `copy`, running Lua programs, etc.

Behavior:

- Input arguments:
  - `command`: string – the text that would be given to `shell.run`.
  - Optional flags for working directory or environment configuration if desired.
- Execution:
  - Use `shell.run` or equivalent to execute the command.
  - Capture exit status.
  - Optionally capture text output via redirection conventions or simple logging.
- Output:
  - A boolean success field.
  - Optional plain text or structured output.
  - Error message if execution fails.

Security and risk level for this tool are project dependent. This spec assumes the agent host is intentionally granting broad access.

### 7.2 File system tools

Tools:

- `fs_list`
- `fs_read`
- `fs_write`
- Optional `fs_delete` and `fs_move`

Focus is on enabling the LLM to:

- Inspect existing Lua files and other resources.
- Create new Lua scripts.
- Modify copies of existing files.

Projects can decide whether to restrict access to a sandbox directory or allow full access to the CraftOS root. For maximum flexibility, this spec assumes full access is permitted, with an option for sandboxing if desired.

### 7.3 Program execution tools

Tool: `run_program`

Purpose:

- Run a Lua program and return whether it succeeded and any error text.

Behavior:

- Input arguments:
  - Program path.
  - Optional arguments to pass to the program.
- Execution:
  - Use `shell.run` or similar mechanism to execute the program.
  - Catch runtime errors and stack traces.
- Output:
  - Success flag.
  - Error string if failures occur.

This tool allows the LLM to test Lua files that it has created or modified and then debug based on observed errors.

---

## 8. Custom tools and tool creation by the LLM

A key requirement of this framework is that the LLM can:

1. Use tools that you define.
2. Create new tools or modify existing tools.

### 8.1 Custom tools defined by the user

Users define tools by:

- Writing Lua modules or scripts that implement specific functionality.
- Registering these modules as commands in the CC client library.

Examples of such tools might include:

- Operations on in game peripherals.
- Higher level workflows (for example complex sequences of shell commands).
- File transformations.

The orchestrator does not need to know about these tools in detail. It only needs the tool names and descriptions to include in LLM prompts.

### 8.2 Tools defined and modified by the LLM

To support LLM generated tools, establish a convention such as:

- A directory on the CC agent host dedicated to tools (for example `/tools`).
- Each file in this directory represents one tool or a collection of tools.
- A simple configuration file or registry that maps tool names to file paths and callable functions.

The LLM can then:

1. Use file system tools to create or edit Lua files in the tools directory.
2. Update the registry to define new mappings or change existing ones.
3. Instruct the agent host to reload or re register tools as needed.

The CC side implements a loader that:

- Reads the registry.
- Loads Lua files indicated by the registry.
- Registers the corresponding commands with the client library.

As a result, the LLM can:

- Propose a new tool in natural language.
- Write the corresponding Lua implementation.
- Update the registry.
- Call the new tool in later interactions.

### 8.3 Tool lifecycle

To keep the system manageable, consider a tool lifecycle along these lines:

- **Draft**: LLM creates an initial version of a tool.
- **Test**: LLM uses `run_program` or other tools to test and refine it.
- **Active**: When the tool is stable, it is added to the registry.
- **Retired**: Tools can be removed or archived if they are no longer needed.

The lifecycle itself is up to the project, but the framework should not limit how many times a tool may be edited.

---

## 9. Long running agent tasks

The framework is designed to support long running agents that operate primarily by:

- Reading and writing files.
- Executing shell commands.
- Creating and using tools.

For such agents:

- Use a specific `task_kind` like `"general_agent"`.
- Allow a broad set of commands, including the shell and file tools and tool management commands.
- Provide a system prompt that explains:
  - The directory layout and where tools and projects live.
  - Conventions for creating and registering tools.
  - Expectations about testing new tools and preserving working code.

The orchestrator:

- Keeps the task’s conversation history.
- Periodically steps the task or reacts to triggers from the outside world.
- Does not encode behavior about what the agent should do, beyond what is stated in the prompt and what tools are available.

---

## 10. Possible future extensions

The core framework is intentionally simple. Some natural extensions for later work include:

- HTTP endpoints for interacting with tasks directly from a browser client.
- A React based frontend that:
  - Provides a chat style interface to an agent.
  - Shows task lists and command logs.
  - Exposes controls for creating and configuring new agents.
- Logging and persistence of task history to files or a database.
- Authentication and authorization for tools if the framework is used in multi user environments.

These are not required for the initial version of the framework but are compatible with the design described above.

---

## 11. Summary

This spec describes a general purpose framework for connecting a local LLM to ComputerCraft computers via a FastAPI based orchestrator and a simple WebSocket protocol.

Key points:

- The orchestrator manages tasks, communicates with the LLM through Ollama and forwards tool calls.
- CC clients implement a small library to handle the protocol, register commands and create tasks.
- The agent host provides core tools for shell execution, file system access and program execution, plus a mechanism for loading custom tools.
- The LLM can create and modify tools by editing Lua files and updating tool registries, then call those tools later.

The result is a flexible base that can support a wide range of CC focused automation and agent behaviors without baking project specific logic into the framework itself.
