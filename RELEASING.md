# Releasing VibeBreak

1. Update `CHANGELOG.md`.
2. Run:

   ```bash
   swift build
   make test
   ./Scripts/build-app.sh
   ```

3. Create and push an annotated `v*` tag.
4. The Release workflow builds and tests the tag, creates
   `VibeBreak.zip`, writes `SHA256SUMS`, and publishes both assets.

Release bundles are ad-hoc signed. A notarized release requires a maintainer
Apple Developer identity and is intentionally not simulated by CI.
