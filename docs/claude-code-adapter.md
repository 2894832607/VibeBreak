# Claude Code Adapter

Claude Code has explicit hook events, so VibeBreak integrates through the local
Agent Bridge rather than reading Claude transcripts.

## Required VibeBreak Source

Enable `Claude Code` in the VibeBreak settings window.

## Install

Select **Install Integration** next to Claude Code in VibeBreak settings. The
app merges its hook groups into `~/.claude/settings.json` and preserves existing
settings and hooks.

## Manual Hook Configuration

Add these hooks to your Claude Code settings. Preserve any existing hooks by
merging the arrays.

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"$HOME/Applications/VibeBreak.app/Contents/MacOS/vibebreak-bridge-emit\"",
            "timeout": 3
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"$HOME/Applications/VibeBreak.app/Contents/MacOS/vibebreak-bridge-emit\"",
            "timeout": 3
          }
        ]
      }
    ],
    "StopFailure": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"$HOME/Applications/VibeBreak.app/Contents/MacOS/vibebreak-bridge-emit\"",
            "timeout": 3
          }
        ]
      }
    ]
  }
}
```

## Semantics

- `UserPromptSubmit` creates a new task and emits `started`.
- `Stop` emits `finished` for the active task in that Claude session.
- `StopFailure` also emits `finished`, so focus does not remain stuck when a
  turn fails after it started.

VibeBreak does not inspect prompt content or transcript files for this adapter.
