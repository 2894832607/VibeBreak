# Changelog

All notable changes to VibeBreak are documented here.

## [0.2.1] - 2026-10-25

### Fixed

- SQLite interruption regression fixture now uses WAL mode, matching the
  production source contract and avoiding rollback-journal I/O failures on CI.
- First downloadable alpha; the `v0.2.0` tag did not pass CI and was not released.

## [0.2.0] - 2026-10-25

### Added

- Opt-in experimental Codex Hooks source with session/turn identity and
  mutually exclusive Codex source selection.
- Universal macOS builds for Apple Silicon and Intel, with downloadable
  application archives and disk images.
- Original hook configuration backup before managed integration changes.
- Bridge executable regression tests for identity collisions, file isolation,
  invalid input, and permissions.

### Fixed

- Source failures no longer erase all concurrent source task state.
- Explicit source invalidation clears only the affected source without
  triggering a false completion action.
- Disabled/restarted sources cannot forward stale queued callbacks.
- Codex database row-sequence rollback is detected while polling.
- Codex interruption handles overlapping task identities in one thread.
- Bridge state filenames use collision-resistant identities, and custom
  bridge paths keep task state beside the selected event file.

### Release notes

- Alpha builds remain ad-hoc signed and are not Apple-notarized.
- Official Codex Hooks are experimental: another Stop hook can request
  continuation after VibeBreak has received its callback.
- Existing tasks are not replayed at application startup.

## [0.1.0] - 2026-08-23

### Added

- Native macOS menu bar application and settings window.
- Codex Desktop SQLite lifecycle adapter with schema validation.
- Multi-source orchestration for Codex Desktop, Claude Code, Cursor, Gemini
  CLI, OpenCode, Amp, and Trae.
- Local JSONL Agent Bridge and `vibebreak-bridge-emit` hook tool.
- Idempotent one-click hook/plugin installation that preserves existing agent
  configuration.
- Complete-hook validation and managed plugin update detection.
- Bridge source tests for partial writes, invalid records, recovery, and
  truncation.
- Explicit start, completion, and interruption handling.
- Concurrent task state machine.
- Configurable application for task start.
- Configurable completion action: open an application, restore the previous
  application, or stay.
- Completion option to restore the application that was frontmost before the
  first concurrent task started.
- Connection diagnostics, action tests, and local rotating logs.
- Migration from the original Douyin Break configuration.
- Swift Package Manager build, tests, installer, documentation, and CI.
