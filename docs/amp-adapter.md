# Amp Adapter

Amp exposes typed plugin lifecycle events. VibeBreak uses `agent.start`, which
fires for each submitted prompt, and `agent.end`, which fires when that turn
finishes.

Official references:

- <https://ampcode.com/manual#plugins>
- <https://ampcode.com/manual/plugin-api>

## Install

In VibeBreak settings, select **Install Integration** next to Amp. VibeBreak
installs its managed plugin at:

```text
~/.config/amp/plugins/vibebreak.js
```

Amp loads system plugins from this directory. Reload plugins or restart Amp
after installation if a running session does not pick it up.

## Contract

Both lifecycle events provide `event.thread.id`. The plugin uses it as
both `thread_id` and task identity, then emits matching start and finish records
to the local Agent Bridge. Sequential turns can safely reuse the identity after
the previous task settles.
