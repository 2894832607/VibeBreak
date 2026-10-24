#!/bin/sh

set -eu

project_root=$(CDPATH= cd -- "$(dirname "$0")/.." && /bin/pwd)
source_app=$(/bin/sh "$project_root/Scripts/build-app.sh")
target_app="$HOME/Applications/VibeBreak.app"

launch_label="app.vibebreak.agent"
launch_agent="$HOME/Library/LaunchAgents/$launch_label.plist"
launch_domain="gui/$(/usr/bin/id -u)"

legacy_label="com.local.douyin-break-menu"
legacy_agent="$HOME/Library/LaunchAgents/$legacy_label.plist"
legacy_app="$HOME/Applications/Douyin Break.app"

/bin/launchctl bootout "$launch_domain/$legacy_label" 2>/dev/null || true
/bin/launchctl bootout "$launch_domain/$launch_label" 2>/dev/null || true
/usr/bin/pkill -f "Douyin Break.app/Contents/MacOS/DouyinBreakMenu" 2>/dev/null || true
/usr/bin/pkill -f "VibeBreak.app/Contents/MacOS/VibeBreak" 2>/dev/null || true

for attempt in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
    if ! /usr/bin/pgrep -f "VibeBreak.app/Contents/MacOS/VibeBreak" >/dev/null; then
        break
    fi
    /bin/sleep 0.1
done

/bin/mkdir -p "$HOME/Applications" "$HOME/Library/LaunchAgents"
/usr/bin/ditto "$source_app" "$target_app"

/bin/cp "$project_root/Resources/LaunchAgent.plist" "$launch_agent"
/usr/libexec/PlistBuddy \
    -c "Set :ProgramArguments:2 $target_app" \
    "$launch_agent"
/usr/bin/plutil -lint "$launch_agent" >/dev/null

/bin/launchctl bootstrap "$launch_domain" "$launch_agent"
/bin/launchctl kickstart "$launch_domain/$launch_label"

for attempt in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
    if /usr/bin/pgrep -f "VibeBreak.app/Contents/MacOS/VibeBreak" >/dev/null; then
        break
    fi
    /bin/sleep 0.1
done

/bin/sleep 0.5

/bin/rm -f "$legacy_agent"
if [ -f "$legacy_app/Contents/Info.plist" ]; then
    legacy_bundle_id=$(
        /usr/bin/defaults read "$legacy_app/Contents/Info.plist" CFBundleIdentifier \
            2>/dev/null || true
    )
    if [ "$legacy_bundle_id" = "com.local.douyin-break-menu" ]; then
        /bin/rm -rf "$legacy_app"
    fi
fi

/usr/bin/osascript -l JavaScript -e \
    'ObjC.import("Foundation"); $.NSDistributedNotificationCenter.defaultCenter.postNotificationNameObjectUserInfoDeliverImmediately("app.vibebreak.show-settings", null, null, true)'

echo "Installed: $target_app"
