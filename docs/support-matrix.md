# Agent Support Matrix

VibeBreak calls an integration supported only when it has an explicit start and
settle event. It does not infer lifecycle state from UI text, process CPU, or
inactivity.

| Agent | Integration | Start | Settle | Setup |
| --- | --- | --- | --- | --- |
| Codex Desktop | Read-only SQLite adapter | Verified `UserInput` record | Verified completion or interrupt record | Built in |
| Claude Code | Command hooks | `UserPromptSubmit` | `Stop` / `StopFailure` | One click |
| Cursor | Command hooks | `beforeSubmitPrompt` | `stop` | One click |
| Gemini CLI | Command hooks | `BeforeAgent` | `AfterAgent` | One click |
| OpenCode | Local plugin | `session.status: busy` | `session.status: idle` / `session.error` | One click |
| Amp | Local plugin | `agent.start` | `agent.end` | One click |
| Trae | Agent Bridge | External `started` event | External `finished` / `interrupted` event | Manual |

## Support Levels

- **Built in:** VibeBreak owns and validates the local source adapter.
- **One click:** VibeBreak installs only its own hook or plugin entries and
  preserves unrelated user configuration.
- **Manual:** the agent must provide explicit lifecycle events through the
  versioned Agent Bridge contract.

## Official Contracts

- Cursor hooks:
  <https://cursor.com/docs/hooks>
- Gemini CLI hooks:
  <https://geminicli.com/docs/hooks/reference/>
- OpenCode plugins:
  <https://opencode.ai/docs/plugins/>
- Amp plugins:
  <https://ampcode.com/manual#plugins>
- Amp plugin API:
  <https://ampcode.com/manual/plugin-api>

