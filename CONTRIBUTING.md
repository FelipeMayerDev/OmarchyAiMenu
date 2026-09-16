# Contributing

Thanks for considering a contribution! The most common contribution is adding
support for a new AI harness (a CLI agent such as OpenCode, Codex, Claude, or
OMP). This document defines the rules a new harness integration must follow
before it can be merged.

## Adding a new harness

A harness integration touches three places, and all three must be complete:

1. **`bin/harness-info`** — detection and model catalog.
2. **`bin/ai-run`** — command construction and stream handling.
3. **`test.js`** — regression assertions covering the items below.

If a harness cannot satisfy one of the mandatory requirements (session
resume, YOLO bypass, thinking separation, usage reporting), open an issue
first so we can decide whether the limitation is acceptable.

### Mandatory requirements

Every new harness **must** implement all of the following. These are the
contract the rest of the app depends on; the QML side only understands the
JSON event shape emitted by `bin/ai-run` (`text`, `thinking`, `usage`).

#### 1. Detection and model catalog (`bin/harness-info`)

- Add the harness to `NAMES` with a human-readable label. Detection is
  simply `shutil.which(key)` — do not add version checks or network probes.
- Provide a `*_models()` function returning a list of entries, each with:
  - `value` — the exact model identifier passed back to the harness CLI,
  - `label` — what the user sees in the dropdown,
  - `efforts` — supported reasoning/thinking effort levels (`["default"]`
    if the harness has no such knob),
  - `defaultEffort` — one of the entries in `efforts`.
- Read the catalog from the harness's own local cache or CLI. Never ship a
  hardcoded model list and never hit the network at detection time. If the
  catalog cannot be read, return an empty list with an `error` string, as
  the existing handlers do.

#### 2. Command construction (`bin/ai-run`, `command()`)

- Build the argument list for three inputs: a fresh session, a resumed
  session, and the effort level. **Session resume is mandatory** — follow-up
  questions are the core feature. If the harness needs a session id it does
  not expose up front, generate one (see how the Claude handler passes
  `--session-id` with a fresh UUID).
- **Non-YOLO mode must be read-only**: the harness must run with tools
  disabled or restricted so it cannot execute commands or modify files
  while the user has not enabled YOLO. A harness that can only run with
  full permissions cannot be merged.
- **YOLO mode** must use the harness's own native bypass/approval-skip
  mechanism (e.g. `--dangerously-skip-permissions`, `--approval-mode yolo`,
  `danger-full-access`). Never wrap commands in shell, and never invent a
  permission-bypass of your own.
- The prompt is passed as the final argv element, never through a shell
  string, so prompts containing quotes and newlines are safe.
- Output must be **newline-delimited JSON on stdout**. If the harness only
  prints prose, use its JSON/text output flag; if it has none, it is not a
  good fit. Human-readable progress on stderr is fine and is ignored.

#### 3. Stream handler (`bin/ai-run`, `HANDLERS`)

Write a `*_handler(session, state)` function that consumes one stdout line
per call and emits events in the existing OpenCode event shape:

- `emit(session, text)` — answer text deltas, streamed as they arrive.
  **Streaming is mandatory**: a handler that only emits the final message
  at completion is not acceptable when the harness offers any streaming
  output. Emit incremental deltas, not the full accumulated text on every
  event (deduplicate with `state`, as the OpenCode SSE path does with its
  `seen` map).
- **Thinking separation is mandatory**: reasoning/thinking content must be
  emitted through `emit_thinking` and never mixed into the answer text.
  The UI renders thinking in a separate dimmed, pulsing block; text that
  arrives inside a thinking/reasoning part must stay there even when the
  underlying stream labels all deltas as `text` (see how the OpenCode path
  tracks part kinds via `message.part.updated` snapshots).
- **Token usage is mandatory**: track token consumption in `state["used"]`
  (keeping the maximum seen, since some harnesses report per-turn counts)
  and the context window in `state["limit"]` if the stream exposes it. If
  the harness does not report a context window, leave `limit` at `0` —
  `run_cli` fills it in from models.dev automatically. Emit nothing
  yourself; `run_cli`/`opencode_main` call `emit_usage` at the end.
- Capture the session id from the stream into `session` (the shared list)
  on the harness's init/started event, so resume works on the next turn.
- Unknown event types must be ignored silently — the harness may add event
  kinds in future versions.
- Set `state["emitted"] = True` whenever you emit answer text. If nothing
  was emitted by the end of the stream, `fallback()` surfaces the raw
  output; make sure at least one known event carries the final answer text
  so users never see silence on success.

#### 4. Code block formatting

The prompt sent to every harness already asks for Markdown with fenced code
blocks, and the QML side parses fences via `OpenCodeEvent.blocks()` into
copyable code cards. To keep this working:

- Do not post-process, re-wrap, or strip Markdown from the harness output.
  Emit model output verbatim.
- Do not emit ANSI escape codes, terminal control sequences, or harness
  "chrome" (spinners, box-drawing UI) as part of the text stream. If the
  harness prints these by default, use its plain/JSON output mode.
- If the harness needs an explicit output-format flag to guarantee clean
  Markdown (e.g. `--output-format stream-json`), set it in `command()`.

#### 5. Operational constraints

- **Timeout**: `TIMEOUT` in `bin/ai-run` is an *idle* watchdog (60 s), not a
  total-duration cap — it is renewed whenever the stream emits thinking or
  text deltas. Do not add a second timeout mechanism; make sure the harness
  starts streaming (even just thinking deltas) within the idle window.
- **Exit codes**: propagate the harness's non-zero exit code
  (`raise SystemExit(process.returncode)`); the UI shows stderr on failure.
- Keep stdout strictly to the event JSON. Anything the harness prints to
  stdout that is not an event must be consumed and discarded by the
  handler, never forwarded.
- Follow the existing code style: standard library only, no new files for
  a harness (a `command()` branch + a handler function is enough), and
  comments only where the harness's behavior demands an explanation.

### Tests (`test.js`)

Every new harness must add assertions to `test.js`:

- Its key appears in `bin/harness-info` and has a `*_models` provider.
- `bin/ai-run` contains the YOLO/bypass flag and the read-only restriction
  flag for the harness.
- `bin/ai-run` contains the handler registration in `HANDLERS` and one
  distinctive event-type or flag string per supported feature (session
  init, text delta, thinking delta, usage).

Run the checks before opening a PR:

```bash
omarchy plugin validate .
node test.js
```

Both must pass with no output. If you changed UI behavior, also smoke-test
the overlay manually: ask a question, verify streaming, thinking block,
code block copy, `/new`, and the usage indicator.

### Manual acceptance checklist

Before opening the PR, verify against the real harness binary:

- [ ] Fresh question streams an answer token-by-token.
- [ ] Follow-up question continues the same session (harness remembers context).
- [ ] Thinking appears in the dimmed thinking block, separate from the answer.
- [ ] With YOLO off, the harness cannot run shell commands or edit files.
- [ ] With YOLO on, the harness runs commands without prompting.
- [ ] Usage indicator shows tokens used and a non-zero context window.
- [ ] Fenced code blocks render as copyable code cards with a language label.
- [ ] A failing run (bad model id) shows a readable error, not silence.

## Other contributions

Bug fixes and UI improvements are welcome too. Keep the scope tight, match
the existing style, and update `test.js` when you change behavior it
asserts on. The JSON event contract between `bin/ai-run` and
`OpenCodeEvent.js` is the app's public seam — changes to it must update
both sides and the tests in the same PR.
