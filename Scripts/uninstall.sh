#!/bin/sh

set -eu

launch_label="app.vibebreak.agent"
launch_agent="$HOME/Library/LaunchAgents/$launch_label.plist"
launch_domain="gui/$(/usr/bin/id -u)"
target_app="$HOME/Applications/VibeBreak.app"

/bin/launchctl bootout "$launch_domain/$launch_label" 2>/dev/null || true
/usr/bin/pkill -f "VibeBreak.app/Contents/MacOS/VibeBreak" 2>/dev/null || true
/bin/rm -f "$launch_agent"
if [ -f "$target_app/Contents/Info.plist" ]; then
    bundle_id=$(
        /usr/bin/defaults read "$target_app/Contents/Info.plist" CFBundleIdentifier \
            2>/dev/null || true
    )
    if [ "$bundle_id" = "app.vibebreak.VibeBreak" ]; then
        /bin/rm -rf "$target_app"
    fi
fi

echo "Uninstalled VibeBreak. Settings and diagnostic logs were preserved."
