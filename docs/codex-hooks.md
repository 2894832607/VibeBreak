# Codex Hooks (experimental)

Official reference: <https://developers.openai.com/codex/hooks/>.
Contract reviewed on 2026-10-25. Version-specific support must be verified
against the Codex installation actually running the task.

## Contract

| Event | Required identity | Bridge action |
| --- | --- | --- |
| `UserPromptSubmit` | `session_id`, `turn_id` | started |
| `Stop` | `session_id`, `turn_id` | finished / completed |
| `Interrupt` | `session_id`, `turn_id` | finished / interrupted |

VibeBreak writes only its own command hooks to the user-level `hooks.json`
inside `CODEX_HOME` (normally `~/.codex`). Existing configuration is preserved;
the original JSON file is backed up once before modification.
The command reads hook JSON from stdin and returns `{}` without blocking the
agent. Prompt and response fields are neither persisted nor copied into events.

## Limitations

`Stop` hooks can ask Codex to continue. VibeBreak cannot observe the combined
decisions of other hooks, so its `Stop` event may precede actual final
settlement. This is why this source is experimental and opt-in, not a blanket
replacement for the existing Desktop adapter.

Only one Codex source can be selected at a time. Do not emit both SQLite
and Hook events for the same task, or start/finish actions could be duplicated.
Configuration selection enforces this mutual exclusion.

## Verify before use

1. Put the application in `~/Applications/VibeBreak.app`.
2. Install and enable Codex Hooks in the settings window. Review and trust the
   new command in Codex `/hooks`; restart the relevant session if needed to
   reload hooks. “Installed” means the file exists, not that Codex has trusted it.
3. Submit a short task and check that start and finish events appear in diagnostics.
4. Submit a longer task, interrupt it, and check that the active task count returns
   to zero.
5. If another `Stop` hook requests continuation, use the Desktop source instead
   until final-settlement semantics can be guaranteed.
