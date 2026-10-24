#!/bin/sh

set -eu

launch_label="app.vibebreak.agent"
launch_agent="$HOME/Library/LaunchAgents/$launch_label.plist"
launch_domain="gui/$(/usr/bin/id -u)"
target_app="$HOME/Applications/VibeBreak.app"

echo "Before uninstalling, open VibeBreak and remove its agent integrations."
echo "Deleting the app alone leaves hooks pointing to a missing bridge emitter."
echo "Settings, logs and agent configuration will NOT be deleted."
printf "Have you removed the integrations and quit VibeBreak? Type yes: "
read -r confirmation || exit 1
[ "$confirmation" = yes ] || { echo "Cancelled; nothing changed."; exit 1; }

[ ! -L "$HOME/Applications" ] || { echo "Refusing symlinked ~/Applications." >&2; exit 1; }
[ ! -L "$target_app" ] || { echo "Refusing symlinked app." >&2; exit 1; }
if [ -e "$target_app" ]; then
    bundle_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$target_app/Contents/Info.plist")
    [ "$bundle_id" = "app.vibebreak.VibeBreak" ] || {
        echo "Refusing to remove a different app: $target_app" >&2
        exit 1
    }
fi
[ ! -L "$launch_agent" ] || { echo "Refusing symlinked LaunchAgent." >&2; exit 1; }
if [ -e "$launch_agent" ]; then
    label=$(/usr/libexec/PlistBuddy -c 'Print :Label' "$launch_agent")
    app_path=$(/usr/libexec/PlistBuddy -c 'Print :ProgramArguments:2' "$launch_agent")
    [ "$label" = "$launch_label" ] && [ "$app_path" = "$target_app" ] || {
        echo "Refusing to remove an unrelated LaunchAgent." >&2
        exit 1
    }
fi
if /usr/bin/pgrep -x VibeBreak >/dev/null; then
    echo "Quit VibeBreak before uninstalling; nothing changed." >&2
    exit 1
fi

/bin/launchctl bootout "$launch_domain/$launch_label" 2>/dev/null || true
/bin/rm -f "$launch_agent"
if [ -e "$target_app" ]; then
    /bin/rm -rf "$target_app"
fi

echo "Uninstalled VibeBreak. Settings, logs and agent configuration were preserved."
