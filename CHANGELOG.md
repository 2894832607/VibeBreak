# Changelog

All notable changes to VibeBreak are documented here.

## [Unreleased]

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
