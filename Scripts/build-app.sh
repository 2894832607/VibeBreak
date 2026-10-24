#!/bin/sh

set -eu

project_root=$(CDPATH= cd -- "$(dirname "$0")/.." && /bin/pwd)
distribution_dir="$project_root/dist"
app_bundle="$distribution_dir/VibeBreak.app"

cd "$project_root"
/usr/bin/swift build -c release --product VibeBreak >&2
/usr/bin/swift build -c release --product vibebreak-bridge-emit >&2
binary_dir=$(/usr/bin/swift build -c release --show-bin-path)

/bin/rm -rf "$app_bundle"
/bin/mkdir -p "$app_bundle/Contents/MacOS" "$app_bundle/Contents/Resources"
/bin/cp "$binary_dir/VibeBreak" "$app_bundle/Contents/MacOS/VibeBreak"
/bin/cp "$binary_dir/vibebreak-bridge-emit" \
    "$app_bundle/Contents/MacOS/vibebreak-bridge-emit"
/bin/cp "$project_root/Resources/Info.plist" "$app_bundle/Contents/Info.plist"
/bin/cp -R "$project_root/Resources/Integrations" \
    "$app_bundle/Contents/Resources/Integrations"

/usr/bin/plutil -lint "$app_bundle/Contents/Info.plist" >/dev/null
/usr/bin/codesign --force --deep --sign - "$app_bundle" >/dev/null 2>&1

echo "$app_bundle"
