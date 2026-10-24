# Trae Adapter

Trae support currently uses the Agent Bridge. The local evidence available so
far does not expose a stable public task lifecycle database or hook contract
equivalent to Codex SQLite or Claude Code hooks. VibeBreak therefore does not
ship a private Trae log parser.

## Required VibeBreak Source

Enable `Trae` in the VibeBreak settings window.

## Bridge Contract

Any Trae extension, local automation, or wrapper that can run a command at task
start and task finish can write bridge events through:

```text
~/Applications/VibeBreak.app/Contents/MacOS/vibebreak-bridge-emit
```

The command reads JSON from stdin. It does not accept command-line parameters.

Start event:

```json
{
  "version": 1,
  "source": "trae",
  "event": "started",
  "thread_id": "trae-session-or-workspace-id",
  "task_id": "trae-task-id"
}
```

Finish event:

```json
{
  "version": 1,
  "source": "trae",
  "event": "finished",
  "thread_id": "trae-session-or-workspace-id",
  "task_id": "trae-task-id",
  "reason": "completed"
}
```

Interrupted event:

```json
{
  "version": 1,
  "source": "trae",
  "event": "interrupted",
  "thread_id": "trae-session-or-workspace-id",
  "task_id": "trae-task-id"
}
```

`thread_id` and `task_id` must match between start and finish for the same task.

## Why This Is Bridge-First

The inspected Trae local files include large private data stores and application
logs, but no confirmed, stable, documented lifecycle boundary. Guessing from
private log phrases would create false positives and would violate VibeBreak's
fail-closed source policy.

When Trae exposes a stable lifecycle hook or documented local event stream,
VibeBreak can add a native `AgentEventSource` without changing task state or
focus automation.

