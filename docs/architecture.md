# Architecture

VibeBreak uses ports and adapters so agent-specific implementation details do
not enter task policy or the UI.

## Layers

### Source

`AgentEventSource` emits `LifecycleEvent` and `SourceHealth`.
`CodexSQLiteEventSource` opens the Codex Desktop database read-only, validates
its schema, and advances through a monotonic row cursor. `JSONLBridgeEventSource`
tails VibeBreak's local bridge file for agents that can emit explicit lifecycle
events through a hook or wrapper.

`AgentIntegrationManager` installs and removes only VibeBreak-owned hook entries
or managed plugin files. It preserves unrelated user configuration and refuses
to overwrite a plugin file whose managed marker is missing.

### Protocol

`CodexLogParser` translates exactly three verified Codex log shapes into source
signals. `BridgeEventParser` validates versioned JSON bridge records and maps
them into lifecycle events only when their `source` matches the source adapter.
Neither parser owns persistence, timers, task state, or macOS actions.

### State

`TaskStateMachine` owns the active task set. It makes duplicate events
idempotent and reduces events to four transitions:

- idle to active;
- active count changed;
- active to idle;
- ignored.

### Policy

`FocusAutomation` maps only idle/active boundary transitions to configured
application actions. It depends on the `ApplicationOpening` protocol and has no
AppKit dependency.

For the restore strategy, the first idle-to-active transition captures the
frontmost bundle identifier. Additional concurrent tasks do not replace it, and
the final active-to-idle transition restores that application.

### macOS

`VibeBreakApp` provides settings persistence, source orchestration,
installed-application discovery, menu bar state, SwiftUI settings, diagnostics,
and `MacApplicationOpener`.

## Event Flow

```text
SQLite rows / Bridge JSONL
  -> CodexLogParser / BridgeEventParser
  -> LifecycleEvent
  -> TaskStateMachine
  -> FocusAutomation
  -> ApplicationOpening
```

`AgentSourceController` starts and stops enabled sources from settings, forwards
events to automation, and forwards per-source health to the UI.

## Concurrency

Task identity is the tuple `(sourceID, threadID, taskID)`. The first active task
performs the start action. Additional tasks only update the active count. The
completion action runs only when the final active task settles.

## Failure Semantics

- Missing database: source health becomes failed and connection retries.
- Unknown schema: source health becomes incompatible; no events are emitted.
- SQLite query failure: the read-only connection closes and reconnects from the
  previous cursor so rows written during the interruption are not skipped.
- Database replacement with a lower row sequence: source task state is cleared,
  the UI is reset, and monitoring resumes from the new generation.
- Bridge file truncation: bridge source state is cleared and monitoring resumes
  from the new end of file.
- Invalid bridge record: the source reports failed health and emits no event for
  that record.
- Enabled managed source without an installed hook/plugin: source stays stopped
  and automation fails closed.
- Unknown or duplicate lifecycle event: ignored by the state machine.
- Missing configured application: action fails visibly; no fallback app is used.
- Unrecognized Codex log shape: ignored rather than guessed.
- Unsupported agent lifecycle source: use the bridge contract; do not infer task
  boundaries from private UI or log phrases.

Health and state invalidation are separate signals. Temporary I/O errors or a
malformed record do not erase tasks. An explicit `onStateInvalidated` callback
(sequence rollback, bridge truncation, or source removal) clears only that
source's tasks without synthesizing completion events. Other sources remain
active. If no valid tasks remain, focus ownership is abandoned rather than
performing a false completion action.

App orchestration serializes callbacks on the main queue and checks a
subscription identity before forwarding them. Callbacks queued by a disabled
or earlier subscription cannot enter the current automation.

Startup tails new records rather than replaying old tasks. Temporary SQLite
reconnections retain the cursor; an application restart does not restore
previous active state. Codex Hooks is opt-in and mutually exclusive with
the Desktop source; see [its experimental contract](codex-hooks.md).

## Persistence

The settings file is the single source of truth for behavior, including enabled
source IDs. The App view model persists a complete settings value before
notifying automation and source orchestration. Legacy keys are accepted only
during decoding and are never written back.
