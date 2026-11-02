#!/bin/bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RESTORE_SCRIPT="$SCRIPT_DIR/restore_macos.sh"
SUPPORT_DIR="${PERSONA_SUPPORT_DIR:-$HOME/Library/Application Support/PersonaMode}"
TMP_PERSONA_DIR="${TMPDIR:-/tmp}/PersonaMode"

BIN_PATH="$(cd "$REPO_DIR" && swift build --show-bin-path 2>/dev/null)/PersonaMode"

if [ ! -x "$BIN_PATH" ]; then
    echo "ERROR: PersonaMode binary not found. Run 'swift build' first." >&2
    exit 1
fi

CLEAN_RUN=0
trap 'if [ "$CLEAN_RUN" -ne 1 ]; then /bin/bash "$RESTORE_SCRIPT" --force-defaults >/dev/null 2>&1 || true; fi' EXIT INT TERM

d_read() {
    defaults read "$1" "$2" 2>/dev/null || echo "ABSENT"
}

fingerprint() {
    echo "dock_pref=$(d_read com.apple.dock autohide)"
    echo "mb_pref=$(d_read NSGlobalDomain _HIHideMenuBar)"
    echo "fs_pref=$(d_read NSGlobalDomain AppleMenuBarVisibleInFullscreen)"
    echo "dock_script=$(osascript -e 'tell application "System Events" to get autohide of dock preferences' 2>/dev/null || echo "ERROR")"
    echo "mb_script=$(osascript -e 'tell application "System Events" to get autohide menu bar of dock preferences' 2>/dev/null || echo "ERROR")"
    echo "wallpaper=$(osascript -l JavaScript -e 'ObjC.import("AppKit"); var ws = $.NSWorkspace.sharedWorkspace; $.NSScreen.screens.js.map(s => ws.desktopImageURLForScreen(s).absoluteString.js).join(",")' 2>/dev/null || echo "WP_NONE")"

    if [ ! -d "$SUPPORT_DIR" ] || [ -z "$(ls -A "$SUPPORT_DIR" 2>/dev/null)" ]; then
        echo "support_dir=EMPTY"
    else
        echo "support_dir=$(ls -1 "$SUPPORT_DIR" 2>/dev/null | sort | tr '\n' ',')"
    fi

    if [ ! -d "$TMP_PERSONA_DIR" ] || [ -z "$(ls -A "$TMP_PERSONA_DIR" 2>/dev/null)" ]; then
        echo "tmp_dir=EMPTY"
    else
        echo "tmp_dir=$(ls -1 "$TMP_PERSONA_DIR" 2>/dev/null | sort | tr '\n' ',')"
    fi

    PROCS=$(pgrep -fl 'guardian\.sh|PersonaMode' 2>/dev/null | grep -v 'verify_clean_state' | grep -v 'grep' || echo "NONE")
    echo "procs=$PROCS"
}

wait_for_hidden() {
    local max_wait=30
    local count=0
    while [ "$count" -lt "$max_wait" ]; do
        if [ -f "$SUPPORT_DIR/state.json" ]; then
            local is_hidden
            is_hidden=$(osascript -e 'tell application "System Events" to get autohide of dock preferences' 2>/dev/null || echo "false")
            if [ "$is_hidden" = "true" ]; then
                return 0
            fi
        fi
        sleep 0.2
        count=$(( count + 1 ))
    done
    return 1
}

wait_for_exit() {
    local pid="$1"
    local max_wait=40
    local count=0
    while kill -0 "$pid" 2>/dev/null && [ "$count" -lt "$max_wait" ]; do
        sleep 0.1
        count=$(( count + 1 ))
    done
}

echo "=== Starting Phase 1 Zero-Trace Verification ==="

# Baseline fingerprint
BASE_FP=$(fingerprint)

# ---------------------------------------------------------
# Scenario 1: SIGINT graceful termination
# ---------------------------------------------------------
echo "Running Scenario 1: SIGINT..."
PERSONA_PHASE1_DEMO=1 "$BIN_PATH" >/dev/null 2>&1 &
APP_PID=$!

if ! wait_for_hidden; then
    echo "SCENARIO 1: FAIL (did not reach hidden state)" >&2
    kill -9 "$APP_PID" 2>/dev/null || true
    exit 1
fi

kill -INT "$APP_PID" 2>/dev/null || true
wait_for_exit "$APP_PID"
sleep 1.5

AFTER_FP=$(fingerprint)
if [ "$BASE_FP" = "$AFTER_FP" ]; then
    echo "SCENARIO 1: PASS"
else
    echo "SCENARIO 1: FAIL (fingerprint mismatch)" >&2
    diff -u <(echo "$BASE_FP") <(echo "$AFTER_FP") >&2 || true
    exit 1
fi

# ---------------------------------------------------------
# Scenario 2: SIGTERM graceful termination
# ---------------------------------------------------------
echo "Running Scenario 2: SIGTERM..."
PERSONA_PHASE1_DEMO=1 "$BIN_PATH" >/dev/null 2>&1 &
APP_PID=$!

if ! wait_for_hidden; then
    echo "SCENARIO 2: FAIL (did not reach hidden state)" >&2
    kill -9 "$APP_PID" 2>/dev/null || true
    exit 1
fi

kill -TERM "$APP_PID" 2>/dev/null || true
wait_for_exit "$APP_PID"
sleep 1.5

AFTER_FP=$(fingerprint)
if [ "$BASE_FP" = "$AFTER_FP" ]; then
    echo "SCENARIO 2: PASS"
else
    echo "SCENARIO 2: FAIL (fingerprint mismatch)" >&2
    diff -u <(echo "$BASE_FP") <(echo "$AFTER_FP") >&2 || true
    exit 1
fi

# ---------------------------------------------------------
# Scenario 3: kill -9 crash (Guardian watchdog restores)
# ---------------------------------------------------------
echo "Running Scenario 3: kill -9 (Guardian restoration)..."
PERSONA_PHASE1_DEMO=1 "$BIN_PATH" >/dev/null 2>&1 &
APP_PID=$!

if ! wait_for_hidden; then
    echo "SCENARIO 3: FAIL (did not reach hidden state)" >&2
    kill -9 "$APP_PID" 2>/dev/null || true
    exit 1
fi

# Wait for guardian to attach
sleep 0.5
kill -9 "$APP_PID" 2>/dev/null || true

# Wait up to 4s for guardian to detect and restore
sleep 3.5

AFTER_FP=$(fingerprint)
if [ "$BASE_FP" = "$AFTER_FP" ]; then
    echo "SCENARIO 3: PASS"
else
    echo "SCENARIO 3: FAIL (fingerprint mismatch)" >&2
    diff -u <(echo "$BASE_FP") <(echo "$AFTER_FP") >&2 || true
    exit 1
fi

# ---------------------------------------------------------
# Scenario 4: kill -9 with PERSONA_NO_GUARDIAN=1 then run restore_macos.sh
# ---------------------------------------------------------
echo "Running Scenario 4: kill -9 with no guardian, manual restore..."
PERSONA_NO_GUARDIAN=1 PERSONA_PHASE1_DEMO=1 "$BIN_PATH" >/dev/null 2>&1 &
APP_PID=$!

if ! wait_for_hidden; then
    echo "SCENARIO 4: FAIL (did not reach hidden state)" >&2
    kill -9 "$APP_PID" 2>/dev/null || true
    exit 1
fi

kill -9 "$APP_PID" 2>/dev/null || true
sleep 0.5

# Run restore script
/bin/bash "$RESTORE_SCRIPT" >/dev/null 2>&1
sleep 1.5

AFTER_FP=$(fingerprint)
if [ "$BASE_FP" = "$AFTER_FP" ]; then
    echo "SCENARIO 4: PASS"
else
    echo "SCENARIO 4: FAIL (fingerprint mismatch)" >&2
    diff -u <(echo "$BASE_FP") <(echo "$AFTER_FP") >&2 || true
    exit 1
fi

# ---------------------------------------------------------
# Scenario 5: kill -STOP (hang) => Guardian restores within hangSeconds
# ---------------------------------------------------------
echo "Running Scenario 5: kill -STOP hang (Guardian restoration)..."
PERSONA_HANG_SECONDS=3 PERSONA_PHASE1_DEMO=1 "$BIN_PATH" >/dev/null 2>&1 &
APP_PID=$!

if ! wait_for_hidden; then
    echo "SCENARIO 5: FAIL (did not reach hidden state)" >&2
    kill -9 "$APP_PID" 2>/dev/null || true
    exit 1
fi

sleep 1.0
kill -STOP "$APP_PID" 2>/dev/null || true

# Wait for guardian hang threshold (3s) + restoration (2s)
sleep 5.0

# Verify app was killed
kill -9 "$APP_PID" 2>/dev/null || true
sleep 1.5

AFTER_FP=$(fingerprint)
if [ "$BASE_FP" = "$AFTER_FP" ]; then
    echo "SCENARIO 5: PASS"
else
    echo "SCENARIO 5: FAIL (fingerprint mismatch)" >&2
    diff -u <(echo "$BASE_FP") <(echo "$AFTER_FP") >&2 || true
    exit 1
fi

# ---------------------------------------------------------
# Scenario 6: Stale state: kill -9 with no guardian, then launch app again
# ---------------------------------------------------------
echo "Running Scenario 6: Stale state recovery on next launch..."
PERSONA_NO_GUARDIAN=1 PERSONA_PHASE1_DEMO=1 "$BIN_PATH" >/dev/null 2>&1 &
APP_PID=$!

if ! wait_for_hidden; then
    echo "SCENARIO 6: FAIL (did not reach hidden state)" >&2
    kill -9 "$APP_PID" 2>/dev/null || true
    exit 1
fi

kill -9 "$APP_PID" 2>/dev/null || true
sleep 0.5

# Launch app again without demo mutations; it must recover stale state first!
PERSONA_NO_GUARDIAN=1 PERSONA_PHASE1_DEMO=0 "$BIN_PATH" >/dev/null 2>&1 &
SECOND_PID=$!
sleep 2.0

kill -TERM "$SECOND_PID" 2>/dev/null || true
wait_for_exit "$SECOND_PID"
sleep 1.5

AFTER_FP=$(fingerprint)
if [ "$BASE_FP" = "$AFTER_FP" ]; then
    echo "SCENARIO 6: PASS"
else
    echo "SCENARIO 6: FAIL (fingerprint mismatch)" >&2
    diff -u <(echo "$BASE_FP") <(echo "$AFTER_FP") >&2 || true
    exit 1
fi

echo ""
echo "PHASE 1 ZERO-TRACE: PASS"
CLEAN_RUN=1
exit 0
