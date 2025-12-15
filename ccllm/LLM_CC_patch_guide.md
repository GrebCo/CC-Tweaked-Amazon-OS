# Patch guide: make the CC LLM agent stop “band-aiding” and start doing real edits

This guide assumes you want **server-side patching/diffs + syntax checks**, plus **multi-tool batching** (so the agent can “patch → check → write → run → status” in one go).

---

## 0) What’s currently causing the death-spiral

### Only the *first* tool call is executed
Your LLM adapter can parse multiple tool calls from multiple ```json blocks, but the orchestrator only executes the first one each cycle. In `main.py`, you do `tool_call = tool_calls[0]` and execute that single call. fileciteturn19file0L40-L46

So even if the model tries to do “send_status + fs_write + run_program” in one response, you’ll only do the first tool, and the rest are ignored.

### Your tool prompt tells the model “one step at a time”
The tool prompt explicitly instructs the model to do one step at a time and outputs a single tool call. fileciteturn19file7L1-L14  
That pushes the model into incremental trial-and-error “micro-fixes” (aka band-aids) rather than structured edit cycles.

### `send_status` auto-re-enters task processing
`handle_send_status` always schedules another `process_task()` call immediately. fileciteturn19file1L8-L12  
Once you support batching, this auto-reentry becomes a foot-gun: the task can re-enter mid-batch and interleave steps.

### `shell_exec` output capture is unreliable
`shell_exec` attempts to redirect output via `command .. " > " .. outputFile`. fileciteturn20file0L18-L33  
CraftOS/CC:Tweaked shell does **not** behave like a Unix shell, so this frequently yields empty output or weird behavior.

---

## 1) Add multi-tool batching (the most important patch)

### Goal
Let the model return **multiple tool calls**, and the orchestrator should execute as many as possible **in-order** until it hits a tool that must wait for a CC result.

### Patch steps

#### 1.1 Add an executor that runs a list of tool calls
Create a helper in `main.py`:

- Executes “immediate” tools (server tools, `send_status`) and continues.
- For “remote” tools (sent to CC), dispatch **one** and then stop (because you must wait for the command_result).

Pseudo-logic:

1. For each tool_call in list:
   - If tool is server-side → run now, append tool result to history, continue
   - Else if tool is `send_status` → send status, append tool result, continue
   - Else dispatch to CC, set pending_call_id, **return** (wait)

#### 1.2 Change `process_task()` to run the whole list
Replace the “first tool only” behavior: fileciteturn19file0L40-L46  
with something like:

- `await execute_tool_calls(task, tool_calls)`

#### 1.3 Stop `send_status` from auto-reentering the task during a batch
Right now, `handle_send_status()` always `create_task(process_task(...))`. fileciteturn19file1L8-L12  
Change it so it **does not** auto-continue. Let the batch executor decide.

A simple pattern:

- `handle_send_status(task, args, continue_processing: bool = True)`
- In batched execution, call it with `False`.

---

## 2) Add “server tools” + a file cache so the model can patch safely

You want: **read file from CC → patch/diff on server → syntax check → write back to CC**.

Do that by adding *server-side tools* that operate on **cached file content**, so the LLM never has to paste the full file into JSON arguments.

### 2.1 Add a per-task file cache (in Task object)
When a remote `fs_read` completes successfully, store its content:

- Keyed by `path` (and implicitly the task)
- Example: `task.file_cache[path] = result["content"]`

You can do this in `handle_command_result` after you add the tool result to history. (The tool result formatting is already centralized there.) fileciteturn19file12L90-L103

### 2.2 Add these server-side tools (executed in Python, not on CC)

#### `patch_cached`
Applies a patch to cached content and updates the cache.

Arguments:
- `path` (string)
- `patch` (string)
- `format` ("unified_diff" | "replace_regex" | "replace_range")
- `dry_run` (bool, default false)

Returns:
- `ok` (bool)
- `diff` (string)
- `new_size` (int)
- `notes` (string)

#### `diff_cached`
Shows a diff between cached versions or between cache and provided text.

Arguments:
- `path` (string)
- `against` ("original" | "last_written" | "provided")
- `provided` (string, optional)

Returns:
- `diff` (string)

#### `lua_check_cached`
Runs a syntax check against cached content (server-side).

Arguments:
- `path` (string)

Returns:
- `ok` (bool)
- `error` (string, optional)

Implementation options (choose one):
- Preferred: run local `luac -p` on a temp file.
- Fallback: run local `lua` that calls `loadfile` / `load`.

#### `fs_write_cached`
Writes cached content back to CC by internally sending the normal `fs_write` command with the cached content.

Arguments:
- `path` (string)

Returns:
- whatever your existing `fs_write` returns (created, size, etc.)

This is the key “free tool”: the LLM never has to embed the full file contents in the tool call; your server sends them over WS.

### 2.3 Wire server tools into `execute_tool_call`
Currently, you special-case only `send_status` and `ask_user`. fileciteturn19file2L37-L45  
Extend this to include server tools:

- If `command in SERVER_TOOLS`: run it locally, then add a formatted tool result message (like you do for errors), and continue.

---

## 3) Fix `shell_exec` so it actually captures output

Right now `shell_exec` uses output redirection: fileciteturn20file0L18-L33  
Patch it to capture output by **temporarily redirecting `term`** to a capture terminal implementation.

### Recommended capture approach (CC side)
Implement a tiny “capture term” object that collects written text into lines.

Minimum required methods commonly used by programs:
- `write`, `blit`
- `clear`, `clearLine`
- `getCursorPos`, `setCursorPos`
- `getSize`, `scroll`
- `isColor`, `setTextColor`, `setBackgroundColor`

Then:

1. `local old = term.redirect(captureTerm)`
2. `local ok = pcall(function() shell.run(command) end)`
3. `term.redirect(old)`
4. return `{success = ok and true/false, output = captureTerm.getText()}`

This makes `shell_exec` reliable for:
- listing files
- running built-in programs like `peripherals`, `label`, etc.
- quick reconnaissance without writing custom Lua programs

---

## 4) Add a minimal “peripheral_scan” CC tool (worth it)

Even if you do most tooling server-side, peripherals must be discovered *on the CC computer*. Add:

Tool: `peripheral_scan`
Returns:
- `{names=[...], entries=[{name,type,methods?}...]}`

Implementation:
- `peripheral.getNames()`
- `peripheral.getType(name)`
- Optional: `peripheral.getMethods(name)` (can be large; consider a `include_methods` flag)

This avoids having the model guess peripheral names and helps stop the “try random wrap” spiral.

---

## 5) Update the tool prompt so the model stops band-aiding

### 5.1 Allow multi-tool calls
Your current tool prompt demands a single tool call. fileciteturn19file7L1-L14  
Change it to allow either:

**Option A (recommended): one JSON block with a list**
```json
{"tool_calls":[
  {"tool":"send_status","arguments":{"message":"..."}},
  {"tool":"fs_read","arguments":{"path":"foo.lua"}},
  {"tool":"patch_cached","arguments":{"path":"foo.lua","format":"unified_diff","patch":"..."}},
  {"tool":"lua_check_cached","arguments":{"path":"foo.lua"}},
  {"tool":"fs_write_cached","arguments":{"path":"foo.lua"}},
  {"tool":"run_program","arguments":{"path":"foo.lua","args":[]}}
]}
```

**Option B: multiple ```json blocks**  
(works too, but easier to break markdown)

### 5.2 Teach a “real edit loop”
Add a short workflow section to your system prompt (in `config.py`), right next to the existing workflow (which currently is write → run → fix). fileciteturn19file5L23-L39

Suggested workflow (model-facing):
1. `send_status("Reading file…")`
2. `fs_read(path)` (always read before editing)
3. `patch_cached(path, …)` (make a **small** patch; avoid rewriting)
4. `lua_check_cached(path)`
5. `fs_write_cached(path)`
6. `run_program(path)`
7. If error: repeat from step 2, and *only patch what the error indicates*

This makes “band-aid flailing” much less likely.

---

## 6) Example: the new best-practice tool batch for code edits

When the model needs to edit an existing file:

1) Read it  
2) Patch it server-side  
3) Syntax check  
4) Write it back  
5) Run it  
6) Status updates throughout

That is exactly what your orchestrator should support after the patches above.

---

## 7) Optional guardrails that help Gemma 3 a lot

These are small but high-impact:

- **Stop condition for repeated identical errors** (same error string N times) → auto-`ask_user` or fail gracefully.
- **“Patch size limit”**: if a patch replaces > X% of file, require a `send_status` explaining why.
- **Always include the last tool error message in the next LLM turn** (you already do this via `format_tool_result`), so keep that.

---

## Quick checklist

- [ ] Multi-tool execution loop in `main.py` (not just `tool_calls[0]`) fileciteturn19file0L40-L46  
- [ ] `send_status` no longer auto-reenters task processing during a batch fileciteturn19file1L8-L12  
- [ ] Add per-task file cache populated by successful `fs_read` results
- [ ] Add server tools: `patch_cached`, `lua_check_cached`, `fs_write_cached`
- [ ] Fix CC `shell_exec` output capture (remove `>` redirection) fileciteturn20file0L18-L33  
- [ ] Update LLM tool prompt to support `{"tool_calls":[...]}` and teach the edit loop fileciteturn19file7L1-L14  
