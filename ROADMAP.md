# VibeBreak Roadmap

Roadmap items must preserve explicit lifecycle boundaries, local-only
processing, deterministic actions, and fail-closed behavior.

## Shipped

- Multiple concurrent agent sources.
- One-click managed hooks and plugins.
- Open an application, restore the previously frontmost application, or stay
  when all active tasks settle.

## Next

### macOS Shortcuts Actions

Run a selected Shortcut at the active and idle boundaries. This expands
VibeBreak beyond application switching without adding a network client. Example
uses include Focus modes, audio, lighting, and workspace setup.

### Per-Source Profiles

Allow each agent source to select a shared default profile or its own action
profile. Add this only after actions have a stable representation; do not
duplicate start/completion fields per source.

## Later

- **Respect manual focus override:** optionally skip restore when the user has
  deliberately left the configured break application.
- **Menu bar task inspector:** show active source and task counts without
  storing prompt content.
- **Bridge transport optimization:** consider a Unix domain socket only if
  profiling shows JSONL polling has meaningful battery or latency cost.

## Non-Goals

- UI text or Accessibility scraping to infer agent state.
- Inactivity timeout as a completion signal.
- Prompt-keyword routing.
- Cloud telemetry, accounts, or remote lifecycle storage.

