# VibeBreak

English | [简体中文](README.zh-CN.md)

VibeBreak is a local macOS menu bar app that reacts to AI coding-agent
lifecycle events:

- when a task starts, open an application you choose;
- when every active task settles, open another application or stay where you are.

VibeBreak supports Codex Desktop, Claude Code, Cursor, Gemini CLI, OpenCode,
Amp, and any tool that implements its local Agent Bridge contract. All
processing remains on the Mac; VibeBreak does not send telemetry or store
prompt content.

> Status: early alpha. Codex Desktop does not currently expose a supported
> lifecycle API, so the adapter is intentionally isolated and fails closed when
> its local log schema is incompatible.

## Features

- Any installed macOS app can be selected for task start.
- Task completion can open another app, restore the app that was frontmost
  before the first active task, or keep the current app.
- Explicit completion and interruption events; no inactivity timeout.
- Concurrent-task state prevents an early return while another task is active.
- Read-only WAL-mode access to the Codex Desktop log database.
- One-click local integration for Claude Code, Cursor, Gemini CLI, OpenCode,
  and Amp.
- JSONL Agent Bridge for Trae and future explicit sources.
- Schema/event-contract gates and visible connection diagnostics.
- Test buttons for both configured application actions.
- Transparent JSON settings and local rotating diagnostic log.
- Automatic migration from the original `Douyin Break` proof of concept.

## Requirements

- macOS 13 or newer
- Swift 5.10 or newer to build the app
- Swift 6 or Xcode 16 or newer to run the Swift Testing suite
- Codex Desktop for the Codex source
- Explicit Agent Bridge events for the manual Trae source

`make test` supports current Apple Command Line Tools and full Xcode. Full Xcode
is used in CI and remains the recommended release environment.

## Install

```bash
cd codex-vibe-break
make install
```

The installer builds an ad-hoc signed application at:

```text
~/Applications/VibeBreak.app
```

It also installs a user LaunchAgent so the menu bar app starts at login. The
settings window opens after installation.

To uninstall the app while preserving settings and logs:

```bash
make uninstall
```

## Configure

Open VibeBreak from the menu bar:

1. Enable automatic switching.
2. Install and enable at least one event source.
3. Choose the application opened when an agent task starts.
4. Choose whether completion opens another application, restores the previous
   application, or keeps the current one.
5. Use the test buttons to verify both actions.

Settings are stored at:

```text
~/Library/Application Support/VibeBreak/settings.json
```

Diagnostics are written without prompt text to:

```text
~/Library/Logs/VibeBreak.log
```

## How It Works

```text
CodexSQLiteEventSource / JSONLBridgeEventSource
        │ explicit lifecycle events
        ▼
TaskStateMachine
        │ idle ↔ active transitions
        ▼
FocusAutomation
        │ configured action
        ▼
MacApplicationOpener
```

The Codex adapter incrementally reads rows after a monotonic SQLite cursor. It
recognizes three verified structured events:

- `UserInput` submission: start;
- `needs_follow_up=false`: normal completion;
- explicit session interrupt: interrupted completion.

Intermediate tool-call sampling (`needs_follow_up=true`) is ignored.

See [Architecture](docs/architecture.md),
[Codex Adapter Contract](docs/codex-adapter.md),
[Agent Support Matrix](docs/support-matrix.md),
[Agent Bridge](docs/agent-bridge.md),
[Claude Code Adapter](docs/claude-code-adapter.md),
[Cursor Adapter](docs/cursor-adapter.md),
[Gemini CLI Adapter](docs/gemini-cli-adapter.md),
[OpenCode Adapter](docs/opencode-adapter.md),
[Amp Adapter](docs/amp-adapter.md), and
[Trae Adapter](docs/trae-adapter.md) for details.

## Development

```bash
make build
make test
make app
```

`make app` writes the distributable app to `dist/VibeBreak.app`.

The package has three targets:

- `VibeBreakCore`: lifecycle contracts, Codex adapter, state machine, settings,
  Agent Bridge, hook normalization, and automation policy;
- `VibeBreakApp`: native macOS UI, persistence, application catalog, logging,
  and menu bar integration.
- `VibeBreakBridgeEmit`: validates hook input and appends bridge events.

## Privacy

VibeBreak is local-only and has no network client. The Codex adapter reads only
the columns required to identify task boundaries. It does not persist or emit
the log body containing user input. See [PRIVACY.md](PRIVACY.md).

## Known Limitations

- Native private-log parsing is only implemented for Codex Desktop.
- Trae requires an external writer for the Agent Bridge contract.
- Codex log fields are private implementation details and may change.
- App switching uses `/usr/bin/open -b` because direct activation from a
  background accessory app is unreliable on recent macOS versions.
- The project is not notarized. Release signing and notarization require a
  maintainer-owned Apple Developer identity.

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request. Security
issues should follow [SECURITY.md](SECURITY.md).

Maintainers can publish a tagged build by following
[RELEASING.md](RELEASING.md).
Future work is prioritized in [ROADMAP.md](ROADMAP.md).

## License

MIT. See [LICENSE](LICENSE).
