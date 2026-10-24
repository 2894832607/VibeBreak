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
The original JSON hook configuration is backed up once before the first
managed modification. That backup may include unrelated settings from the
original file; it stays alongside that file and is never uploaded.

Experimental Codex Hooks read stdin JSON, including lifecycle identity fields.
Only `session_id` and `turn_id` are needed for task pairing; prompt and response
fields are not saved. Temporary bridge task state uses hashed filenames and
owner-only file permissions. Changing `VIBEBREAK_BRIDGE_FILE` also moves task
state beside the selected bridge file.

The diagnostic log rotates at approximately 1 MB and keeps one archive. Task
identifiers are truncated. Prompt and response content are not logged.

## Network

VibeBreak contains no network client, analytics SDK, crash reporter, or update
checker.

## Permissions

VibeBreak does not require Accessibility or Automation permission. Application
switching is delegated to the macOS `/usr/bin/open` command using a bundle
identifier selected by the user.
