# OpenCode Adapter

OpenCode loads JavaScript or TypeScript plugins from its global plugin
directory. Its official event bus exposes `session.status` with `busy`, `retry`,
and `idle` states.

Official reference: <https://opencode.ai/docs/plugins/>

## Install

In VibeBreak settings, select **Install Integration** next to OpenCode.
VibeBreak installs its managed plugin at:

```text
~/.config/opencode/plugins/vibebreak.js
```

OpenCode loads files in that directory automatically at startup.

## Contract

- first `session.status: busy` starts a task;
- repeated `busy` and `retry` states do not create duplicate tasks;
- `session.status: idle` completes the active task;
- `session.error` settles the active task as failed.

The plugin uses the serialized session ID as both thread and task identity.
Sequential turns safely reuse it after the previous task settles, and repeated
busy events remain idempotent in `TaskStateMachine`.
