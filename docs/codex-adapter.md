# Codex Desktop Adapter Contract

## Upstream

Codex Desktop currently writes structured operational logs to:

```text
~/.codex/logs_2.sqlite
```

This is a private implementation detail, not a supported Codex API. VibeBreak
opens the database with SQLite read-only flags and never writes to it.

## Required Schema

The `logs` table must contain:

- `id`
- `target`
- `thread_id`
- `feedback_log_body`

The adapter rejects the database if any required column is missing.

## Lifecycle Markers

### Started

Target:

```text
codex_core::session::handlers
```

Required structured fields:

```text
Submission { id: "<task-id>", op: UserInput
```

### Completed

Target:

```text
codex_core::session::turn
```

Required structured fields:

```text
turn_id=<task-id>
needs_follow_up=false
```

`needs_follow_up=true` is an intermediate sampling state, commonly produced
during tool use, and must not complete a task.

### Interrupted

Target:

```text
codex_core::session
```

Required structured event:

```text
interrupt received: abort current task
```

The active task associated with that `thread_id` is completed with reason
`interrupted`.

## Cursor Semantics

Each poll captures `MAX(id)` as an upper bound, queries only relevant targets
between the previous cursor and that bound, then advances the cursor to the
bound even when no relevant rows exist. This prevents repeated scanning of
unrelated log traffic and ensures rows inserted during a query are handled by
the next poll.

## Compatibility Policy

VibeBreak does not maintain keyword fallback lists. If Codex changes these
structured markers, the adapter must be updated with evidence and tests. Unknown
formats are ignored or rejected; they are never interpreted heuristically.
