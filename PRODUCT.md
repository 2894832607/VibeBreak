# Product

<!-- impeccable:product-schema 1 -->

## Platform

macOS

## Stack

Native macOS application written in Swift with AppKit and SwiftUI. Swift Package
Manager owns builds and tests. The distributed application is a menu bar agent.

## Users

Developers who run local coding agents and do not want to watch an agent work.
They want their attention moved to another application as soon as a task starts,
then returned to their coding application as soon as the task settles.

## Product Purpose

VibeBreak translates local AI-agent lifecycle events into deterministic macOS
application switching. Success means a start, completion, or interruption event
causes exactly one configured focus transition with low latency and no false
positives.

## Positioning

VibeBreak is a local lifecycle automation layer rather than a model plugin. Its
core separates agent-specific event sources from task state and macOS actions,
so one focus policy can work across multiple agents as adapters are added.

## Operating Context

- Runs continuously as a macOS menu bar application.
- Reads local agent lifecycle data only; it does not send telemetry.
- Supports concurrent tasks and only performs the completion action after all
  active tasks have settled.
- Bundled sources include Codex Desktop, one-click hook/plugin integrations for
  Claude Code, Cursor, Gemini CLI, OpenCode, and Amp, plus the local Agent
  Bridge for Trae and future explicit lifecycle emitters.
- Users select any installed macOS application for the running-task action and,
  optionally, for the completion action.

## Capabilities and Constraints

- Start action: immediately open a configured installed application.
- Completion action: open a configured application, restore the application
  that was frontmost before the first active task, or stay in the current one.
- Normal completion and user interruption are explicit lifecycle events; no
  inactivity timeout is used.
- Codex Desktop currently exposes no supported public lifecycle API. Its adapter
  reads the local WAL-mode log database through a read-only SQLite connection.
- Agents without a stable local lifecycle API must integrate through explicit
  Agent Bridge events rather than private log guessing.
- Private schema compatibility must be checked before monitoring. An unknown
  schema fails closed and is surfaced in diagnostics.
- The application switch is performed through `/usr/bin/open -b`, because recent
  macOS versions may reject focus changes initiated directly by an accessory app.
- Working product name: VibeBreak. Repository naming is an open decision before
  the first public release.

## Brand Commitments

VibeBreak should feel like a quiet native utility. It must use standard macOS
controls and terminology, expose state clearly, and avoid playful interruption
or productivity claims.

## Evidence on Hand

- Existing proof-of-concept implementation in `menu/`.
- Verified Codex Desktop lifecycle evidence in `~/.codex/logs_2.sqlite`.
- Verified start marker: `codex_core::session::handlers` with `op: UserInput`.
- Verified normal completion marker: `codex_core::session::turn` with
  `needs_follow_up=false`.
- Verified interruption marker: `codex_core::session` with
  `interrupt received`.
- No public users, benchmarks, screenshots, testimonials, or release assets
  exist yet; future work must not fabricate them.

## Product Principles

1. Fail closed when a source contract is unknown.
2. Keep lifecycle detection, task state, focus actions, and persistence isolated.
3. Prefer explicit source events over timing or inactivity inference.
4. Keep all behavior local, observable, and user-configurable.
5. Preserve native macOS expectations and make recovery paths visible.

## Accessibility & Inclusion

All controls must be keyboard reachable, expose native accessibility labels, and
remain usable with increased contrast and reduced motion settings.
