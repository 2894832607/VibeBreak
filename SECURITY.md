# Security Policy

## Supported Versions

Only the latest tagged release receives security fixes while VibeBreak remains
in early development.

## Reporting

Do not open a public issue for a vulnerability that could expose local prompt
content, modify Codex data, execute an unintended application, or bypass the
configured lifecycle policy.

Report the issue privately to the repository maintainer. Include:

- the affected version and macOS version;
- the source adapter involved;
- reproduction steps without personal prompt content;
- expected and observed behavior.

## Security Boundaries

- Source databases are opened read-only.
- Unknown Codex schemas fail closed.
- Managed hook installation preserves unrelated user configuration.
- Managed plugin files are never overwritten or deleted after their ownership
  marker is removed.
- Bundle identifiers come from installed applications selected by the user.
- VibeBreak has no network client.
- Diagnostic logs exclude prompt and response text.
