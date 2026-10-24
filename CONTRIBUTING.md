# Contributing

## Development Setup

1. Install Xcode or Apple Command Line Tools.
2. Run `swift build`.
3. Run `make test`.
4. Run `Scripts/build-app.sh` to verify the app bundle.

## Change Boundaries

- Keep agent-specific parsing inside a source adapter.
- Keep task concurrency and idempotency inside `TaskStateMachine`.
- Keep macOS application launching outside the core target.
- Do not add timing-based completion inference.
- Do not log prompt or response content.
- Unknown source schemas must fail closed.

## Pull Requests

Every behavior change should include:

- the lifecycle contract being changed;
- focused unit or integration coverage;
- an update to relevant documentation;
- confirmation that `swift build`, `make test`, and `Scripts/build-app.sh`
  succeed locally or in the full-Xcode CI environment.

UI changes should preserve native keyboard navigation, accessibility labels,
increased-contrast behavior, and reduced-motion behavior.

## Adding an Agent Source

Use the shallowest supported integration:

1. For command hooks, map the documented hook payload through
   `HookEventMapper` and the bundled bridge emitter.
2. For plugin APIs, add one managed plugin resource that emits the Agent Bridge
   contract.
3. Implement a new `AgentEventSource` only when the upstream transport cannot
   use the Bridge.

Every source must emit stable source, thread, and task identifiers, document its
official upstream contract, and avoid inferred completion based on inactivity.
Add it to `docs/support-matrix.md` with an honest support level.
