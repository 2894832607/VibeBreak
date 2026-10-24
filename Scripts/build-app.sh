#!/bin/sh

set -eu

project_root=$(CDPATH= cd -- "$(dirname "$0")/.." && /bin/pwd)
distribution_dir="$project_root/dist"

cd "$project_root"
# Keep release builds separate from development/test builds.
scratch_path="$project_root/.build/universal-release"
/usr/bin/swift build -c release --scratch-path "$scratch_path" \
    --arch arm64 --arch x86_64 --product VibeBreak >&2
/usr/bin/swift build -c release --scratch-path "$scratch_path" \
    --arch arm64 --arch x86_64 --product vibebreak-bridge-emit >&2
binary_dir=$(/usr/bin/swift build -c release --scratch-path "$scratch_path" \
    --arch arm64 --arch x86_64 --show-bin-path)

/bin/mkdir -p "$distribution_dir"
staging=$(/usr/bin/mktemp -d "$distribution_dir/.package.XXXXXX")
trap '/bin/rm -rf "$staging"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
app_bundle="$staging/VibeBreak.app"
/bin/mkdir -p "$app_bundle/Contents/MacOS" "$app_bundle/Contents/Resources"
/bin/cp "$binary_dir/VibeBreak" "$app_bundle/Contents/MacOS/VibeBreak"
/bin/cp "$binary_dir/vibebreak-bridge-emit" \
    "$app_bundle/Contents/MacOS/vibebreak-bridge-emit"
/bin/cp "$project_root/Resources/Info.plist" "$app_bundle/Contents/Info.plist"
/bin/cp -R "$project_root/Resources/Integrations" \
    "$app_bundle/Contents/Resources/Integrations"

/usr/bin/plutil -lint "$app_bundle/Contents/Info.plist" >/dev/null
for executable in vibebreak-bridge-emit VibeBreak; do
    binary="$app_bundle/Contents/MacOS/$executable"
    for arch in arm64 x86_64; do
        /usr/bin/lipo "$binary" -verify_arch "$arch"
    done
    /usr/bin/codesign --force --sign - "$binary" >&2
done
/usr/bin/codesign --force --sign - "$app_bundle" >&2
/usr/bin/codesign --verify --deep --strict --all-architectures "$app_bundle" >&2

/usr/bin/ditto -c -k --sequesterRsrc --keepParent \
    "$app_bundle" "$staging/VibeBreak.zip"
dmg_root="$staging/dmg"
/bin/mkdir "$dmg_root"
/usr/bin/ditto "$app_bundle" "$dmg_root/VibeBreak.app"
/bin/cat > "$dmg_root/INSTALL.txt" <<'EOF'
VibeBreak 0.2.0 — public alpha / Universal (Apple Silicon + Intel)

INSTALL (no administrator privileges):
1. Quit VibeBreak before replacing an existing copy.
2. In Finder choose Go > Go to Folder, enter ~/Applications.
   Create this folder in your home folder if it does not exist.
3. Drag VibeBreak.app from this disk image to THAT folder.
   Do not overwrite an unrelated app with the same name.
4. Eject the disk image. Open ~/Applications/VibeBreak.app.

The integration hooks expect:
~/Applications/VibeBreak.app/Contents/MacOS/vibebreak-bridge-emit
Do not run from this disk image or install in /Applications.

This alpha is ad-hoc signed, NOT Developer ID signed or notarized.
Gatekeeper may block it. After verifying the download checksum and source,
use System Settings > Privacy & Security > Open Anyway if available.
If your organization's policy blocks unsigned apps, do not bypass it.

UNINSTALL: first remove integrations INSIDE VibeBreak, then quit it.
Only then remove the app. Deleting the app alone leaves hooks behind.
Settings, logs and other agents' configuration are not automatically deleted.
For a LaunchAgent installed by Scripts/install.sh, use Scripts/uninstall.sh.
EOF
/usr/bin/hdiutil create -volname "VibeBreak Alpha" -srcfolder "$dmg_root" \
    -format UDZO "$staging/VibeBreak.dmg" >&2
(cd "$staging" && /usr/bin/shasum -a 256 VibeBreak.zip VibeBreak.dmg > SHA256SUMS)

# Publish only after build, signature checks and both packages succeed.
# Retain earlier artifacts, including the imported dist/VibeBreak.zip.
backup_suffix="$(/bin/date -u +%Y%m%dT%H%M%SZ).$$"
for artifact in VibeBreak.app VibeBreak.zip VibeBreak.dmg SHA256SUMS; do
    if [ -e "$distribution_dir/$artifact" ] || [ -L "$distribution_dir/$artifact" ]; then
        /bin/mv "$distribution_dir/$artifact" \
            "$distribution_dir/$artifact.previous-$backup_suffix"
    fi
    /bin/mv "$staging/$artifact" "$distribution_dir/$artifact"
done
echo "$distribution_dir/VibeBreak.app"
