# Agent Bridge

The Agent Bridge is the stable integration path for agents that can run a local
command when a task starts or settles. It avoids reading private UI state or
guessing from log text.

## Event File

Bridge events are appended to:

```text
~/Library/Application Support/VibeBreak/bridge/events.jsonl
```

The VibeBreak app tails this file from its current end when a bridge source is
enabled. Historical events are not replayed.

## Emit Tool

The app bundle includes:

```text
~/Applications/VibeBreak.app/Contents/MacOS/vibebreak-bridge-emit
```

The tool reads one JSON object from stdin and appends one line to the bridge
event file. It does not accept command-line parameters.

## Standard Event Contract

```json
{
  "version": 1,
  "source": "trae",
  "event": "started",
  "thread_id": "workspace-or-session-id",
  "task_id": "stable-task-id"
}
```

Fields:

- `version`: must be `1`.
- `source`: a source ID listed in the support matrix.
- `event`: `started`, `finished`, or `interrupted`.
- `thread_id`: stable session/workspace identifier.
- `task_id`: stable task identifier shared by start and finish.
- `reason`: optional for `finished`; `completed`, `interrupted`, or `failed`.
- `timestamp`: optional ISO-8601 timestamp.

Invalid JSON, unknown versions, empty IDs, and incomplete records are rejected.

## Claude Hook Input

When stdin contains a supported command-hook payload,
`vibebreak-bridge-emit` maps:

- Claude Code `UserPromptSubmit` to start and `Stop` / `StopFailure` to finish.
- Gemini CLI `BeforeAgent` / `AfterAgent` to start / finish.
- Cursor `beforeSubmitPrompt` / `stop` to start / finish.

The tool stores generated task IDs locally when the upstream hook does not
provide one, so completion matches start without transcript parsing.
