#!/bin/bash
# Phase 2/3 GUI smoke test (DRY RUN — never mutates Dock/Menu Bar or moves user windows;
# PersonaMode runs LIVE by default, so automated scripts explicitly export PERSONA_DRY_RUN=1).
# Launches the GUI, verifies the bar + overlay windows appear at the expected levels, quits via
# SIGTERM, and verifies no windows or state remain.
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BIN_DIR="$(cd "$REPO_DIR" && swift build --show-bin-path 2>/dev/null)"
BIN="$BIN_DIR/PersonaMode"
[ -x "$BIN" ] || { echo "ERROR: build first (swift build)"; exit 1; }

export PERSONA_SUPPORT_DIR="$(mktemp -d)"
export PERSONA_DRY_RUN=1
export PERSONA_NO_GUARDIAN=1
FAILS=0
check() { if [ "$2" = "$3" ]; then echo "  PASS $1"; else echo "  FAIL $1 (got '$2', want '$3')"; FAILS=$((FAILS+1)); fi; }

cleanup() {
    [ -n "${APP_PID:-}" ] && kill -9 "$APP_PID" 2>/dev/null
    /bin/bash "$SCRIPT_DIR/restore_macos.sh" --support-dir "$PERSONA_SUPPORT_DIR" >/dev/null 2>&1
    rm -rf "$PERSONA_SUPPORT_DIR"
}
trap cleanup EXIT

"$BIN" >/dev/null 2>&1 &
APP_PID=$!

# wait for the session to be armed
for _ in $(seq 1 50); do [ -f "$PERSONA_SUPPORT_DIR/state.json" ] && break; sleep 0.1; done
check "state.json written (I1)" "$([ -f "$PERSONA_SUPPORT_DIR/state.json" ] && echo yes || echo no)" "yes"
sleep 2

"$BIN" --probe windows-of --pid "$APP_PID" --out /tmp/persona_smoke_on.json >/dev/null 2>&1
ON=$(plutil -extract onScreenCount raw -o - /tmp/persona_smoke_on.json 2>/dev/null || echo -1)
echo "  on-screen windows while running: $ON"
check "bar + overlay on screen (>=2)" "$([ "$ON" -ge 2 ] && echo yes || echo no)" "yes"
LAYERS=$(plutil -extract layers json -o - /tmp/persona_smoke_on.json 2>/dev/null)
echo "  layers: $LAYERS"
check "bar layer 25 present" "$(echo "$LAYERS" | grep -c '\b25\b')" "1"

if [ -n "${SMOKE_QUIT_VIA:-}" ]; then
    # optional: exercise `--ctl quit`
    "$BIN" --ctl "$SMOKE_QUIT_VIA" >/dev/null 2>&1
else
    kill -TERM "$APP_PID" 2>/dev/null
fi
for _ in $(seq 1 40); do kill -0 "$APP_PID" 2>/dev/null || break; sleep 0.1; done
check "process exited after SIGTERM" "$(kill -0 "$APP_PID" 2>/dev/null && echo alive || echo gone)" "gone"
sleep 0.5
"$BIN" --probe windows-of --pid "$APP_PID" --out /tmp/persona_smoke_off.json >/dev/null 2>&1
OFF=$(plutil -extract onScreenCount raw -o - /tmp/persona_smoke_off.json 2>/dev/null || echo -1)
check "no windows after quit" "$OFF" "0"
check "state dir cleaned" "$([ -z "$(ls -A "$PERSONA_SUPPORT_DIR" 2>/dev/null)" ] && echo empty || echo leftovers)" "empty"
APP_PID=""

if [ "$FAILS" -eq 0 ]; then echo "GUI SMOKE: PASS"; exit 0; else echo "GUI SMOKE: FAIL ($FAILS)"; exit 1; fi
