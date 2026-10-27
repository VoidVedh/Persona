#!/bin/bash
set -eu

APP_PID="${1:-}"
SUPPORT_DIR="${2:-}"
RESTORE_SCRIPT="${3:-}"

if [ -z "$APP_PID" ] || [ -z "$SUPPORT_DIR" ] || [ -z "$RESTORE_SCRIPT" ]; then
    echo "Usage: guardian.sh <appPid> <supportDir> <restoreScript>" >&2
    exit 1
fi

LOCK_FILE="$SUPPORT_DIR/session.lock"
HEARTBEAT_FILE="$SUPPORT_DIR/heartbeat"
HANG_SECONDS="${PERSONA_HANG_SECONDS:-15}"

while true; do
    # 1. Clean shutdown check: if session.lock missing, exit 0
    if [ ! -f "$LOCK_FILE" ]; then
        exit 0
    fi

    # 2. Check if parent application process is alive
    if ! kill -0 "$APP_PID" 2>/dev/null; then
        if [ -x "$RESTORE_SCRIPT" ]; then
            "$RESTORE_SCRIPT" --support-dir "$SUPPORT_DIR" --reason "guardian-crash" || true
        else
            /bin/bash "$RESTORE_SCRIPT" --support-dir "$SUPPORT_DIR" --reason "guardian-crash" || true
        fi
        exit 0
    fi

    # 3. Check heartbeat liveness if heartbeat file exists
    if [ -f "$HEARTBEAT_FILE" ]; then
        NOW=$(date +%s)
        MTIME=$(stat -f %m "$HEARTBEAT_FILE" 2>/dev/null || echo "$NOW")
        DIFF=$(( NOW - MTIME ))
        if [ "$DIFF" -ge "$HANG_SECONDS" ]; then
            if [ -x "$RESTORE_SCRIPT" ]; then
                "$RESTORE_SCRIPT" --support-dir "$SUPPORT_DIR" --reason "guardian-hang" --kill-app || true
            else
                /bin/bash "$RESTORE_SCRIPT" --support-dir "$SUPPORT_DIR" --reason "guardian-hang" --kill-app || true
            fi
            exit 0
        fi
    fi

    sleep 0.5
done
