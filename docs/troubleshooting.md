# Troubleshooting

## Menu Bar Shows “需要完成设置”

Open settings and choose an application for the task start action. If completion
is configured to open an application, choose that application as well. At least
one event source must be enabled.

## Source Shows “连接失败”

For Codex Desktop, confirm that Codex has been launched and this file exists:

```text
~/.codex/logs_2.sqlite
```

The Diagnostics tab shows the exact path VibeBreak is monitoring.

For hook, plugin, or manual Bridge sources, confirm that this file is writable:

```text
~/Library/Application Support/VibeBreak/bridge/events.jsonl
```

## Source Shows “未安装接入”

Use **安装接入** in the source row. VibeBreak merges only its own hook entries
for Claude Code, Cursor, and Gemini CLI. For OpenCode and Amp it installs a
marked local plugin file and refuses to overwrite an unmarked file.

Restart or reload the agent if its running process does not reload configuration
automatically.

## Source Shows “不兼容”

Codex changed or has not initialized the required `logs` table. VibeBreak fails
closed and will not switch applications. Open an issue with:

- Codex Desktop version;
- macOS version;
- the VibeBreak diagnostic status.

Do not attach the database because it can contain prompt content.

## Claude Code Events Are Not Detected

Confirm the `Claude Code` source is enabled in VibeBreak and that your Claude
settings include `UserPromptSubmit`, `Stop`, and `StopFailure` hooks pointing to:

```text
~/Applications/VibeBreak.app/Contents/MacOS/vibebreak-bridge-emit
```

See [Claude Code Adapter](claude-code-adapter.md).

## Trae Events Are Not Detected

Confirm the `Trae` source is enabled in VibeBreak. Trae currently requires an
explicit bridge writer from a Trae extension, wrapper, or automation that knows
the true task start and finish boundaries. VibeBreak does not parse private Trae
logs.

See [Trae Adapter](trae-adapter.md).

## The Event Is Detected but the App Does Not Open

Use “测试开始动作” in settings. Confirm the selected application is still
installed. VibeBreak does not substitute another app when a bundle identifier is
missing.

## A Tool-Using Task Returns Too Early

This is a bug. The adapter ignores `needs_follow_up=true` and only treats
`needs_follow_up=false` as normal completion. Include the truncated task IDs from
the diagnostic log in a report; do not include prompt text.

## Logs

VibeBreak diagnostics:

```text
~/Library/Logs/VibeBreak.log
```

Codex operational logs remain owned by Codex:

```text
~/.codex/logs_2.sqlite
```

Bridge events are local JSONL records:

```text
~/Library/Application Support/VibeBreak/bridge/events.jsonl
```

VibeBreak diagnostics contain lifecycle state, truncated identifiers, source
health, and action failures only.
