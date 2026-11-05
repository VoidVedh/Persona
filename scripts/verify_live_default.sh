#!/bin/bash
# scripts/verify_live_default.sh — Proves that PersonaMode runs LIVE by default when launched
# without PERSONA_DRY_RUN=1 (using --no-window-moves so open IDE/user windows are never moved).
# Temporarily mutates Dock/Menu Bar and guarantees full restoration via trap.
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RESTORE_SCRIPT="$SCRIPT_DIR/restore_macos.sh"
SUPPORT_DIR="${PERSONA_SUPPORT_DIR:-$HOME/Library/Application Support/PersonaMode}"

BUNDLE_BIN="$REPO_DIR/build/Persona Mode.app/Contents/MacOS/PersonaMode"
SWIFT_BIN="$(cd "$REPO_DIR" && swift build --show-bin-path 2>/dev/null)/PersonaMode"

if [ -x "$SWIFT_BIN" ] && { [ ! -x "$BUNDLE_BIN" ] || [ "$SWIFT_BIN" -nt "$BUNDLE_BIN" ]; }; then
    BIN_PATH="$SWIFT_BIN"
elif [ -x "$BUNDLE_BIN" ]; then
    BIN_PATH="$BUNDLE_BIN"
else
    echo "ERROR: PersonaMode binary not found. Run 'swift build' or 'make app' first." >&2
    exit 1
fi

CLEAN_RUN=0
cleanup() {
    [ -n "${APP_PID:-}" ] && kill -9 "$APP_PID" 2>/dev/null || true
    if [ "$CLEAN_RUN" -ne 1 ]; then
        /bin/bash "$RESTORE_SCRIPT" --force-defaults >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT INT TERM

d_read() {
    defaults read "$1" "$2" 2>/dev/null || echo "ABSENT"
}

fingerprint() {
    echo "dock_pref=$(d_read com.apple.dock autohide)"
    echo "mb_pref=$(d_read NSGlobalDomain _HIHideMenuBar)"
    echo "fs_pref=$(d_read NSGlobalDomain AppleMenuBarVisibleInFullscreen)"
    echo "dock_script=$(osascript -e 'tell application "System Events" to get autohide of dock preferences' 2>/dev/null || echo "ERROR")"
    echo "mb_script=$(osascript -e 'tell application "System Events" to get autohide menu bar of dock preferences' 2>/dev/null || echo "ERROR")"
}

echo "=== Verifying LIVE-by-default launch ($BIN_PATH) ==="
BASE_FP="$(fingerprint)"

# Launch with NO PERSONA_DRY_RUN env, passing --no-window-moves to protect developer windows
unset PERSONA_DRY_RUN || true
unset PERSONA_PHASE1_DEMO || true

"$BIN_PATH" --no-window-moves >/dev/null 2>&1 &
APP_PID=$!

LIVE_DETECTED=0
for _ in $(seq 1 35); do
    if [ -f "$SUPPORT_DIR/state.json" ]; then
        DOCK_AS="$(osascript -e 'tell application "System Events" to get autohide of dock preferences' 2>/dev/null || echo "false")"
        DOCK_DEF="$(d_read com.apple.dock autohide)"
        if [ "$DOCK_AS" = "true" ] || [ "$DOCK_DEF" = "1" ]; then
            LIVE_DETECTED=1
            break
        fi
    fi
    sleep 0.2
done

if [ "$LIVE_DETECTED" -ne 1 ]; then
    echo "LIVE DEFAULT: FAIL (Dock autohide did not activate in default live mode)" >&2
    exit 1
fi

kill -TERM "$APP_PID" 2>/dev/null || true
for _ in $(seq 1 40); do
    kill -0 "$APP_PID" 2>/dev/null || break
    sleep 0.1
done
APP_PID=""
sleep 1.5

AFTER_FP="$(fingerprint)"
if [ "$BASE_FP" != "$AFTER_FP" ]; then
    echo "LIVE DEFAULT: FAIL (fingerprint mismatch after SIGTERM)" >&2
    diff -u <(echo "$BASE_FP") <(echo "$AFTER_FP") >&2 || true
    exit 1
fi

CLEAN_RUN=1
echo "LIVE DEFAULT: PASS"
exit 0
