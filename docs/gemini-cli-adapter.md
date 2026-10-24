# Gemini CLI Adapter

Gemini CLI exposes synchronous command hooks. VibeBreak uses `BeforeAgent`
after prompt submission and `AfterAgent` after the final response.

Official reference: <https://geminicli.com/docs/hooks/reference/>

## Install

In VibeBreak settings, select **Install Integration** next to Gemini CLI.
VibeBreak merges its hook groups into:

```text
~/.gemini/settings.json
```

Existing settings and hooks are preserved.

## Contract

Both hooks provide the same `session_id`. VibeBreak creates a stable task ID at
`BeforeAgent`, persists it locally, and reuses it at `AfterAgent`.

Gemini requires command hooks to emit JSON on stdout. The bundled bridge emitter
returns `{}` after recording the lifecycle event and writes diagnostics only to
stderr.

