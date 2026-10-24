# Releasing VibeBreak 0.2.0 public alpha

## Release contract

- macOS 13+, Universal **arm64 + x86_64** for both `VibeBreak` and
  `vibebreak-bridge-emit`.
- **Unsigned alpha in the distribution-trust sense: ad-hoc signed only,
  NOT Developer ID signed, NOT notarized.** No certificate, Apple account
  or notarization secret is required by these scripts or workflows.
- Bundle ID: `app.vibebreak.VibeBreak`; version: `0.2.0`; build: `2`.
- Install at **`~/Applications/VibeBreak.app`**, not `/Applications`.
  Generated hooks use
  `"$HOME/Applications/VibeBreak.app/Contents/MacOS/vibebreak-bridge-emit"`.

## Local validation and packaging

Use macOS with a Swift 5.10+ toolchain (full Xcode recommended). The build
uses SwiftPM's repeated `--arch arm64 --arch x86_64` flags; it checks the
actual resulting binaries with `lipo`, rather than assuming they are fat.
Unsupported toolchains fail the build; there is no silent native-only fallback.

```bash
for script in Scripts/*.sh; do sh -n "$script"; done
plutil -lint Resources/Info.plist Resources/LaunchAgent.plist
node --check Resources/Integrations/opencode-vibebreak.js
node --check Resources/Integrations/amp-vibebreak.js
make test
./Scripts/build-app.sh
lipo -archs dist/VibeBreak.app/Contents/MacOS/VibeBreak
lipo -archs dist/VibeBreak.app/Contents/MacOS/vibebreak-bridge-emit
codesign --verify --deep --strict --all-architectures dist/VibeBreak.app
codesign -dv --verbose=4 dist/VibeBreak.app
(cd dist && shasum -a 256 -c SHA256SUMS)
```

Packaging does **not** install or launch the app. Release builds use the
separate `.build/universal-release` scratch directory. Both executables are
ad-hoc signed explicitly before signing and verifying the enclosing bundle.
Build output and diagnostics go to stderr; stdout remains the bundle path
for the installer.

Outputs in `dist/`:

| Artifact | Contents |
| --- | --- |
| `VibeBreak.app` | Validated Universal app bundle |
| `VibeBreak.zip` | App bundle, preserving macOS metadata |
| `VibeBreak.dmg` | App bundle and `INSTALL.txt` |
| `SHA256SUMS` | SHA-256 for ZIP and DMG |

Packaging completes in a temporary directory before publishing outputs.
Existing outputs (including the original ZIP) are renamed to
`<name>.previous-<UTC timestamp>.<pid>`, not silently overwritten.
An interrupted final multi-file publish is not atomic; inspect `dist/`
and its retained previous outputs before retrying.

## Install and uninstall

For downloaded assets, verify `SHA256SUMS` **before** mounting/extracting.
Checksums detect corruption; a checksum downloaded alongside the package
is not an independent proof of publisher identity.

1. Quit an existing VibeBreak. Open the DMG and read `INSTALL.txt`.
2. In Finder choose **Go > Go to Folder**, enter `~/Applications`.
   Create `Applications` in your home folder if missing.
3. Drag `VibeBreak.app` to that folder. Only replace a known VibeBreak
   installation; Finder does not enforce the script's bundle-ID checks.
4. Eject the DMG and open `~/Applications/VibeBreak.app`. For ZIP, extract
   and move the bundle to the same location.

The DMG intentionally has no `/Applications` shortcut: that would disagree
with the hook commands. Running from the mounted disk image is unsupported.
Manual drag-and-drop does not create a login LaunchAgent.

Gatekeeper may block downloaded ad-hoc builds. After checking the source
and checksum, use **System Settings > Privacy & Security > Open Anyway**
if offered. Do not disable Gatekeeper, strip quarantine globally, or bypass
company policy. Ad-hoc verification is not notarization or publisher trust.

For a source checkout, explicitly run `./Scripts/install.sh` only when you
want to install. It refuses an unrelated/invalid existing bundle, symlinked
target, or unrelated LaunchAgent before building. Quit the app first.
It stages and verifies the new bundle before replacing the old one and
registers the LaunchAgent with the same `~/Applications` path.
Failures restore prior app/LaunchAgent files and try to restore the previously
loaded service. If restoration itself fails, the backup path is printed
and retained for manual recovery. Successful bootstrap means registration,
not proof that Gatekeeper allowed the GUI to run. No legacy application,
agent hooks, settings or logs are automatically removed.

**Before uninstalling, remove integrations inside VibeBreak, then quit it.**
Deleting the bundle alone leaves hooks pointing to a missing emitter.
`./Scripts/uninstall.sh` requires an explicit `yes`, validates bundle and
LaunchAgent identities, and removes only this app and its matching login
agent. User configuration, settings and logs are preserved. Manual installs
can be removed in Finder after the same integration-removal step.

## GitHub workflow (maintainer action only)

1. Update changelog and `Resources/Info.plist` together. The release tag must
   match `v<CFBundleShortVersionString>` exactly (first alpha: `v0.2.0`).
2. Run local checks above and review Intel + Apple Silicon smoke-test results.
3. Only when explicitly ready to publish, create and push the annotated tag.
   Editing workflow files alone does not create a release.

CI uses `contents: read`, no persisted checkout credentials, runs tests
before packaging, and uploads only ZIP, DMG and checksums. Release packaging
also runs validation and tests with read-only permissions. A separate job
receives `contents: write` only to publish the verified artifacts as a
**prerelease**, with explicit unsigned/ad-hoc, unnotarized alpha notes.
No signing credentials are expected and no notarization is claimed.

## Remaining acceptance gates

Universal slices and valid ad-hoc signatures are necessary, not sufficient:
verify launch, integration install/removal, sleep/wake and upgrades on real
Intel and Apple Silicon Macs running supported macOS versions. An arm64
host does not prove Intel runtime compatibility; local unquarantined launch
does not prove downloaded-app Gatekeeper behavior. Test source installation
and rollback in a disposable macOS user account before declaring them
runtime-verified.
