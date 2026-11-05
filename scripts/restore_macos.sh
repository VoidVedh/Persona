#!/bin/bash
# restore_macos.sh — Fail-Safe Panic & Clean State Restoration Script for Persona Mode
# Compatible with macOS /bin/bash (v3.2)

set -e

DRY_RUN=0
FORCE_DEFAULTS=0
KILL_APP=1
REASON="manual"
SUPPORT_DIR="${PERSONA_SUPPORT_DIR:-$HOME/Library/Application Support/PersonaMode}"

# Parse arguments
while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --force-defaults)
            FORCE_DEFAULTS=1
            shift
            ;;
        --kill-app)
            KILL_APP=1
            shift
            ;;
        --no-kill-app)
            KILL_APP=0
            shift
            ;;
        --reason)
            REASON="$2"
            shift 2
            ;;
        --support-dir)
            SUPPORT_DIR="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 3
            ;;
    esac
done

echo "[restore_macos] Initiating restoration (reason: $REASON, dry-run: $DRY_RUN)..."

run() {
    echo "  >> $*"
    if [ "$DRY_RUN" -eq 0 ]; then
        "$@" || true
    fi
}

# 1. Mutex acquisition via mkdir
MUTEX_DIR="$SUPPORT_DIR/restore.lock.d"
if [ -d "$MUTEX_DIR" ]; then
    NOW=$(date +%s)
    MTIME=$(stat -f %m "$MUTEX_DIR" 2>/dev/null || echo 0)
    DIFF=$((NOW - MTIME))
    if [ "$DIFF" -gt 30 ]; then
        echo "[restore_macos] Cleaning up stale restore mutex (age: ${DIFF}s)..."
        rm -rf "$MUTEX_DIR"
    else
        echo "[restore_macos] Another restore process is actively running ($MUTEX_DIR exists). Aborting." >&2
        exit 3
    fi
fi

if [ "$DRY_RUN" -eq 0 ]; then
    mkdir -p "$SUPPORT_DIR" 2>/dev/null || true
    mkdir "$MUTEX_DIR" 2>/dev/null || {
        echo "[restore_macos] Failed to acquire mutex $MUTEX_DIR. Aborting." >&2
        exit 3
    }
    trap 'rm -rf "$MUTEX_DIR"' EXIT INT TERM
fi

# 2. Terminate Persona Mode processes if requested
if [ "$KILL_APP" -eq 1 ]; then
    LOCK_FILE="$SUPPORT_DIR/session.lock"
    if [ -f "$LOCK_FILE" ]; then
        APP_PID=$(head -n 1 "$LOCK_FILE" 2>/dev/null | tr -d '[:space:]' || true)
        if [ -n "$APP_PID" ]; then
            if [ "$DRY_RUN" -eq 1 ] || kill -0 "$APP_PID" 2>/dev/null; then
                echo "[restore_macos] Terminating active PersonaMode PID: $APP_PID"
                run kill -TERM "$APP_PID"
                if [ "$DRY_RUN" -eq 0 ]; then
                    sleep 0.5
                    if kill -0 "$APP_PID" 2>/dev/null; then
                        run kill -KILL "$APP_PID"
                    fi
                fi
            fi
        fi
    fi

    # Kill any dangling guardian or app processes
    run pkill -f "Persona Mode.app/Contents/MacOS"
    run pkill -f "scripts/guardian.sh"
fi

# 3. Read state.json or fall back to safe defaults
STATE_FILE="$SUPPORT_DIR/state.json"
STATE_VALID=0

if [ "$FORCE_DEFAULTS" -eq 0 ] && [ -f "$STATE_FILE" ]; then
    if plutil -extract schemaVersion raw -o - "$STATE_FILE" >/dev/null 2>&1; then
        STATE_VALID=1
    else
        echo "[restore_macos] WARNING: $STATE_FILE failed plutil validation (corrupt)."
    fi
fi

if [ "$STATE_VALID" -eq 1 ]; then
    echo "[restore_macos] Restoring from snapshot in $STATE_FILE..."

    # --- Dock Restore ---
    DOCK_PRESENT=$(plutil -extract snapshot.dock.autohide.present raw -o - "$STATE_FILE" 2>/dev/null || echo "false")
    if [ "$DOCK_PRESENT" = "true" ]; then
        DOCK_VAL=$(plutil -extract snapshot.dock.autohide.value raw -o - "$STATE_FILE" 2>/dev/null || echo "false")
        echo "[restore_macos] Restoring Dock autohide to $DOCK_VAL"
        run osascript -e "tell application \"System Events\" to set autohide of dock preferences to $DOCK_VAL"
    else
        echo "[restore_macos] Restoring Dock autohide to absent (defaulting to visible)"
        run osascript -e 'tell application "System Events" to set autohide of dock preferences to false'
        run defaults delete com.apple.dock autohide
    fi

    # --- Menu Bar Restore ---
    MB_SCRIPTED=$(plutil -extract snapshot.menuBar.scriptedAutohide raw -o - "$STATE_FILE" 2>/dev/null || echo "false")
    if [ "$MB_SCRIPTED" = "true" ] || [ "$MB_SCRIPTED" = "false" ]; then
        echo "[restore_macos] Restoring Menu Bar autohide to $MB_SCRIPTED"
        run osascript -e "tell application \"System Events\" to set autohide menu bar of dock preferences to $MB_SCRIPTED"
    fi

    MB_HIDE_PRESENT=$(plutil -extract snapshot.menuBar.hideMenuBar.present raw -o - "$STATE_FILE" 2>/dev/null || echo "false")
    if [ "$MB_HIDE_PRESENT" = "false" ]; then
        run defaults delete NSGlobalDomain _HIHideMenuBar
    fi

    MB_FS_PRESENT=$(plutil -extract snapshot.menuBar.visibleInFullscreen.present raw -o - "$STATE_FILE" 2>/dev/null || echo "false")
    if [ "$MB_FS_PRESENT" = "false" ]; then
        run defaults delete NSGlobalDomain AppleMenuBarVisibleInFullscreen
    fi

    # --- System Wallpaper Restore (if mode was system) ---
    WP_MODE=$(plutil -extract wallpaperMode raw -o - "$STATE_FILE" 2>/dev/null || echo "overlay")
    if [ "$WP_MODE" = "system" ]; then
        WP_URL=$(plutil -extract snapshot.wallpapers.0.url raw -o - "$STATE_FILE" 2>/dev/null || true)
        if [ -n "$WP_URL" ]; then
            echo "[restore_macos] Restoring system wallpaper to $WP_URL"
            run osascript -l JavaScript -e "var app = Application.currentApplication(); app.includeStandardAdditions = true; var ws = $.NSWorkspace.sharedWorkspace; ws.setDesktopImageURLForScreen($.NSURL.URLWithString('$WP_URL'), ws.screens.objectAtIndex(0), {}, null);"
        fi
    fi

    # --- Terminal profile cleanup from ledger ---
    HAS_TERM_PROFILE=$(tr -d '\n' < "$STATE_FILE" 2>/dev/null | grep -c '"terminalProfile"' || true)
    if [ "${HAS_TERM_PROFILE:-0}" -gt 0 ]; then
        echo "[restore_macos] Cleaning ledgered Terminal.app profile: Persona 3 Reload"
        if [ -f "$HOME/Library/Preferences/com.apple.Terminal.plist" ]; then
            run /usr/libexec/PlistBuddy -c "Delete :'Window Settings':'Persona 3 Reload'" "$HOME/Library/Preferences/com.apple.Terminal.plist"
        fi
    fi

    # --- Temp dirs cleanup from ledger (with strict security prefix check) ---
    # Safe prefixes: /tmp/PersonaMode*, $TMPDIR/PersonaMode*, $SUPPORT_DIR/*
    TEMP_DIR_CLEANUP=$(tr -d '\n' < "$STATE_FILE" 2>/dev/null | grep -oE '"tempDir"[^}]*"path" *: *"[^"]+"' | sed -E 's/.*"path" *: *"([^"]+)".*/\1/' | sed 's/\\//\//g' || true)
    for tpath in $TEMP_DIR_CLEANUP; do
        if [ -n "$tpath" ]; then
            IS_SAFE=0
            case "$tpath" in
                /tmp/PersonaMode*|/var/folders/*/T/PersonaMode*)
                    IS_SAFE=1
                    ;;
                *)
                    if [ -n "$TMPDIR" ] && [[ "$tpath" == "$TMPDIR"PersonaMode* || "$tpath" == "$TMPDIR/PersonaMode"* ]]; then
                        IS_SAFE=1
                    elif [ -n "$SUPPORT_DIR" ] && [[ "$tpath" == "$SUPPORT_DIR"/* ]]; then
                        IS_SAFE=1
                    fi
                    ;;
            esac

            if [ "$IS_SAFE" -eq 1 ]; then
                echo "[restore_macos] Cleaning ledgered temp directory: $tpath"
                run rm -rf "$tpath"
            else
                echo "[restore_macos] SECURITY WARNING: Refusing to delete path outside safe temp prefixes: $tpath" >&2
            fi
        fi
    done

else
    echo "[restore_macos] Failing open to stock macOS default visible desktop..."
    run osascript -e 'tell application "System Events" to set autohide of dock preferences to false'
    run defaults delete com.apple.dock autohide
    run osascript -e 'tell application "System Events" to set autohide menu bar of dock preferences to false'
    run defaults delete NSGlobalDomain _HIHideMenuBar
    run defaults delete NSGlobalDomain AppleMenuBarVisibleInFullscreen
fi

# 4. Remove session, temp profiles, and state files (session.lock deleted last)
if [ -n "${TMPDIR:-}" ] && [ -d "${TMPDIR%/}/PersonaMode" ]; then
    run rm -rf "${TMPDIR%/}/PersonaMode"
fi
if [ -d "/tmp/PersonaMode" ]; then
    run rm -rf "/tmp/PersonaMode"
fi
run rm -f "$SUPPORT_DIR/state.json"
run rm -f "$SUPPORT_DIR/state.json.tmp"
run rm -f "$SUPPORT_DIR/state.json.prev"
run rm -f "$SUPPORT_DIR/windows.json"
run rm -f "$SUPPORT_DIR/heartbeat"
run rm -f "$SUPPORT_DIR/session.lock.guardian"
run rm -f "$SUPPORT_DIR/session.lock"

# If support dir is empty, delete it
if [ -d "$SUPPORT_DIR" ] && [ "$DRY_RUN" -eq 0 ]; then
    rmdir "$SUPPORT_DIR" 2>/dev/null || true
fi

echo "[restore_macos] Restoration complete. macOS returned to prior state."
exit 0
