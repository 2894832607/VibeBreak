#!/bin/sh

set -eu

project_root=$(CDPATH= cd -- "$(dirname "$0")/.." && /bin/pwd)
target_app="$HOME/Applications/VibeBreak.app"
launch_label="app.vibebreak.agent"
launch_agent="$HOME/Library/LaunchAgents/$launch_label.plist"
launch_domain="gui/$(/usr/bin/id -u)"

fail() { echo "$*" >&2; exit 1; }
bundle_id() {
    /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$1/Contents/Info.plist"
}

# Check before building, stopping services or overwriting anything.
[ ! -L "$HOME/Applications" ] || fail "Refusing a symlinked ~/Applications."
[ ! -L "$target_app" ] || fail "Refusing a symlink at $target_app."
if [ -e "$target_app" ]; then
    [ "$(bundle_id "$target_app")" = "app.vibebreak.VibeBreak" ] \
        || fail "Refusing to overwrite a different or invalid app: $target_app"
fi
[ ! -L "$launch_agent" ] || fail "Refusing a symlink at $launch_agent."
if [ -e "$launch_agent" ]; then
    [ "$(/usr/libexec/PlistBuddy -c 'Print :Label' "$launch_agent")" = "$launch_label" ] \
        || fail "Refusing to overwrite an unrelated LaunchAgent."
    [ "$(/usr/libexec/PlistBuddy -c 'Print :ProgramArguments:2' "$launch_agent")" = "$target_app" ] \
        || fail "LaunchAgent points to a different app; review it manually."
fi
if /usr/bin/pgrep -x VibeBreak >/dev/null; then
    fail "Quit VibeBreak before installing; no running app has been stopped."
fi

source_app=$(/bin/sh "$project_root/Scripts/build-app.sh")
[ "$(bundle_id "$source_app")" = "app.vibebreak.VibeBreak" ] \
    || fail "Build produced an unexpected bundle identity."
/usr/bin/codesign --verify --deep --strict --all-architectures "$source_app"
for executable in VibeBreak vibebreak-bridge-emit; do
    for arch in arm64 x86_64; do
        /usr/bin/lipo "$source_app/Contents/MacOS/$executable" -verify_arch "$arch"
    done
done

/bin/mkdir -p "$HOME/Applications" "$HOME/Library/LaunchAgents"
staging=$(/usr/bin/mktemp -d "$HOME/Applications/.vibebreak-install.XXXXXX")
had_app=false
had_agent=false
was_loaded=false
app_replaced=false
agent_replaced=false
committed=false
if /bin/launchctl print "$launch_domain/$launch_label" >/dev/null 2>&1; then
    was_loaded=true
fi

cleanup() {
    result=$?
    trap - EXIT INT TERM
    if [ "$committed" = false ]; then
        if [ "$agent_replaced" = true ]; then
            /bin/launchctl bootout "$launch_domain/$launch_label" 2>/dev/null || true
            /bin/rm -f "$launch_agent"
        fi
        if [ "$app_replaced" = true ]; then
            /bin/rm -rf "$target_app"
        fi
        if [ "$had_app" = true ]; then
            /bin/mv "$staging/previous.app" "$target_app" || {
                echo "Restore failed; old app retained at $staging/previous.app" >&2
                exit 1
            }
        fi
        if [ "$had_agent" = true ]; then
            /bin/cp -p "$staging/previous.plist" "$launch_agent" || {
                echo "Restore failed; old LaunchAgent retained in $staging" >&2
                exit 1
            }
        fi
        if [ "$was_loaded" = true ] && [ "$agent_replaced" = true ]; then
            /bin/launchctl bootstrap "$launch_domain" "$launch_agent" \
                || echo "Old files restored; LaunchAgent must be restarted manually." >&2
        fi
    fi
    /bin/rm -rf "$staging"
    exit "$result"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

/usr/bin/ditto "$source_app" "$staging/VibeBreak.app"
/usr/bin/codesign --verify --deep --strict --all-architectures "$staging/VibeBreak.app"
/bin/cp "$project_root/Resources/LaunchAgent.plist" "$staging/agent.plist"
/usr/libexec/PlistBuddy -c "Set :ProgramArguments:2 $target_app" "$staging/agent.plist"
/usr/bin/plutil -lint "$staging/agent.plist" >/dev/null

if [ -e "$launch_agent" ]; then
    /bin/cp -p "$launch_agent" "$staging/previous.plist"
    had_agent=true
fi
if [ "$was_loaded" = true ]; then
    /bin/launchctl bootout "$launch_domain/$launch_label"
fi
# Mark this before any changes so failures also restore the prior service.
agent_replaced=true
if [ -e "$target_app" ]; then
    /bin/mv "$target_app" "$staging/previous.app"
    had_app=true
fi
/bin/mv "$staging/VibeBreak.app" "$target_app"
app_replaced=true
/bin/cp "$staging/agent.plist" "$launch_agent"
/bin/launchctl bootstrap "$launch_domain" "$launch_agent"
committed=true

echo "Installed: $target_app"
echo "LaunchAgent registered. This is an ad-hoc signed, unnotarized alpha."
echo "If macOS blocks launch, review Privacy & Security; do not bypass company policy."
echo "Hooks use $target_app/Contents/MacOS/vibebreak-bridge-emit."
