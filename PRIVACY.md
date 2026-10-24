# Privacy

VibeBreak is designed to operate entirely on the local Mac.

## Data Access

The Codex Desktop adapter opens `~/.codex/logs_2.sqlite` in read-only mode. It
queries only:

- the monotonic row identifier;
- the log target;
- the Codex thread identifier;
- the structured log body needed to identify lifecycle boundaries.

The log body can contain user input because it is owned by Codex Desktop.
VibeBreak parses boundary fields in memory and does not copy prompt text into
its settings or diagnostic log.

The Agent Bridge reads local JSONL lifecycle events written by configured
agent hooks. Bridge records contain source, thread, task, event, optional
reason, and optional timestamp fields. They should not contain prompt or
response text.

## Data Storage

VibeBreak stores:

- user settings in
  `~/Library/Application Support/VibeBreak/settings.json`;
- bridge lifecycle events in
  `~/Library/Application Support/VibeBreak/bridge/events.jsonl`;
- diagnostic lifecycle and error records in
  `~/Library/Logs/VibeBreak.log`.

When the user explicitly selects **Install Integration**, VibeBreak adds only
its own hook entries to supported agent settings or installs a marked local
plugin file. Existing unrelated settings and hooks are preserved.

The diagnostic log rotates at approximately 1 MB and keeps one archive. Task
identifiers are truncated. Prompt and response content are not logged.

## Network

VibeBreak contains no network client, analytics SDK, crash reporter, or update
checker.

## Permissions

VibeBreak does not require Accessibility or Automation permission. Application
switching is delegated to the macOS `/usr/bin/open` command using a bundle
identifier selected by the user.
