# Cursor Adapter

Cursor exposes command hooks over JSON stdin/stdout. VibeBreak uses
`beforeSubmitPrompt` as the turn start and `stop` as the turn boundary.

Official reference: <https://cursor.com/docs/hooks>

## Install

In VibeBreak settings, select **Install Integration** next to Cursor. VibeBreak
merges its entries into:

```text
~/.cursor/hooks.json
```

Existing hooks are preserved. Cursor watches the file and normally reloads it
without a restart.

## Contract

Cursor provides:

- `conversation_id`: stable across turns and used as `thread_id`;
- `generation_id`: unique for each submitted turn and used as `task_id`;
- `status`: `completed`, `aborted`, or `error` on `stop`.

VibeBreak maps `aborted` to `interrupted` and `error` to `failed`. Missing
conversation or generation identifiers fail closed.

