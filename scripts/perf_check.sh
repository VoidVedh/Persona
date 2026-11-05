#!/bin/bash
# Performance budget check (§11.2, §11.3):
# PersonaMode runs LIVE by default; this script exports PERSONA_DRY_RUN=1 so sampling
# never mutates Dock/Menu Bar or moves user windows.
# Accounts for both the PersonaMode main process AND newly spawned WebKit XPC helper processes
# (com.apple.WebKit.WebContent, .GPU, .Networking) via PID-diff (§11.3).
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BIN="$(cd "$REPO_DIR" && swift build --show-bin-path 2>/dev/null)/PersonaMode"

DURATION="${1:-10}"
SAMPLE_INTERVAL=2
if [ "$DURATION" -lt 4 ]; then
    SAMPLE_INTERVAL=1
fi

echo "=== Persona Mode V2 Performance Check (${DURATION}s sample, app + WebKit helpers) ==="

export PERSONA_SUPPORT_DIR="$(mktemp -d)"
export PERSONA_DRY_RUN=1
export PERSONA_NO_GUARDIAN=1

cleanup() {
    [ -n "${APP_PID:-}" ] && kill -9 "$APP_PID" 2>/dev/null || true
    /bin/bash "$SCRIPT_DIR/restore_macos.sh" --support-dir "$PERSONA_SUPPORT_DIR" >/dev/null 2>&1 || true
    rm -rf "$PERSONA_SUPPORT_DIR"
}
trap cleanup EXIT

# Snapshot existing WebKit helper PIDs before launching PersonaMode (§11.3)
PRE_WK_PIDS="$(pgrep -f 'com\.apple\.WebKit\.(WebContent|GPU|Networking)' 2>/dev/null | sort -n | tr '\n' ' ' || true)"

"$BIN" >/dev/null 2>&1 &
APP_PID=$!

for _ in $(seq 1 40); do
    [ -f "$PERSONA_SUPPORT_DIR/state.json" ] && break
    sleep 0.1
done
sleep 3

# Diff WebKit helper PIDs to find newly spawned helpers belonging to our session
POST_WK_PIDS="$(pgrep -f 'com\.apple\.WebKit\.(WebContent|GPU|Networking)' 2>/dev/null | sort -n || true)"
OUR_WK_PIDS=""
HELPER_COUNT=0
for pid in $POST_WK_PIDS; do
    case " $PRE_WK_PIDS " in
        *" $pid "*) ;;
        *)
            OUR_WK_PIDS="$OUR_WK_PIDS $pid"
            HELPER_COUNT=$(( HELPER_COUNT + 1 ))
            ;;
    esac
done

echo "Monitoring App PID $APP_PID + $HELPER_COUNT WebKit helper PIDs ($OUR_WK_PIDS)..."

TOTAL_APP_CPU=0
TOTAL_WK_CPU=0
MAX_APP_RSS=0
MAX_WK_RSS=0
MAX_TOTAL_RSS=0
SAMPLES=0

STEPS=$(( DURATION / SAMPLE_INTERVAL ))
[ "$STEPS" -lt 1 ] && STEPS=1

for _ in $(seq 1 "$STEPS"); do
    sleep "$SAMPLE_INTERVAL"
    if ! kill -0 "$APP_PID" 2>/dev/null; then
        echo "ERROR: Process exited prematurely" >&2
        exit 1
    fi

    APP_STATS=$(ps -o %cpu=,rss= -p "$APP_PID" 2>/dev/null || echo "0 0")
    APP_CPU=$(echo "$APP_STATS" | awk '{print $1+0}')
    APP_RSS=$(echo "$APP_STATS" | awk '{print int($2+0)}')

    WK_CPU=0
    WK_RSS=0
    for wpid in $OUR_WK_PIDS; do
        if kill -0 "$wpid" 2>/dev/null; then
            WSTATS=$(ps -o %cpu=,rss= -p "$wpid" 2>/dev/null || echo "0 0")
            W_C=$(echo "$WSTATS" | awk '{print $1+0}')
            W_R=$(echo "$WSTATS" | awk '{print int($2+0)}')
            WK_CPU=$(echo "$WK_CPU + $W_C" | bc -l)
            WK_RSS=$(( WK_RSS + W_R ))
        fi
    done

    TOTAL_APP_CPU=$(echo "$TOTAL_APP_CPU + $APP_CPU" | bc -l)
    TOTAL_WK_CPU=$(echo "$TOTAL_WK_CPU + $WK_CPU" | bc -l)

    [ "$APP_RSS" -gt "$MAX_APP_RSS" ] && MAX_APP_RSS="$APP_RSS"
    [ "$WK_RSS" -gt "$MAX_WK_RSS" ] && MAX_WK_RSS="$WK_RSS"
    COMBINED_RSS=$(( APP_RSS + WK_RSS ))
    [ "$COMBINED_RSS" -gt "$MAX_TOTAL_RSS" ] && MAX_TOTAL_RSS="$COMBINED_RSS"

    SAMPLES=$(( SAMPLES + 1 ))
    COMBINED_CPU=$(echo "$APP_CPU + $WK_CPU" | bc -l)
    printf "  sample %d: app=%.2f%%/%dKB | webkit=%.2f%%/%dKB | total=%.2f%%/%dKB\n" \
        "$SAMPLES" "$APP_CPU" "$APP_RSS" "$WK_CPU" "$WK_RSS" "$COMBINED_CPU" "$COMBINED_RSS"
done

kill -TERM "$APP_PID" 2>/dev/null || true
for _ in $(seq 1 30); do
    kill -0 "$APP_PID" 2>/dev/null || break
    sleep 0.1
done
APP_PID=""

AVG_APP_CPU=$(echo "$TOTAL_APP_CPU / $SAMPLES" | bc -l)
AVG_WK_CPU=$(echo "$TOTAL_WK_CPU / $SAMPLES" | bc -l)
AVG_TOTAL_CPU=$(echo "$AVG_APP_CPU + $AVG_WK_CPU" | bc -l)

MAX_APP_MB=$(echo "$MAX_APP_RSS / 1024" | bc -l)
MAX_WK_MB=$(echo "$MAX_WK_RSS / 1024" | bc -l)
MAX_TOTAL_MB=$(echo "$MAX_TOTAL_RSS / 1024" | bc -l)

CPU_BUDGET="${PERSONA_CPU_BUDGET:-10.0}"
RSS_BUDGET="${PERSONA_RSS_BUDGET:-500.0}"

printf "app:            avg CPU=%.2f%% | max RSS=%.2f MB\n" "$AVG_APP_CPU" "$MAX_APP_MB"
printf "webkit helpers: avg CPU=%.2f%% | max RSS=%.2f MB (count=%d)\n" "$AVG_WK_CPU" "$MAX_WK_MB" "$HELPER_COUNT"
printf "total:          avg CPU=%.2f%% (budget <= %s%%) | max RSS=%.2f MB (budget <= %s MB)\n" \
    "$AVG_TOTAL_CPU" "$CPU_BUDGET" "$MAX_TOTAL_MB" "$RSS_BUDGET"

CPU_PASS=$(echo "$AVG_TOTAL_CPU <= $CPU_BUDGET" | bc -l)
RSS_PASS=$(echo "$MAX_TOTAL_MB <= $RSS_BUDGET" | bc -l)

if [ "$CPU_PASS" -eq 1 ] && [ "$RSS_PASS" -eq 1 ]; then
    echo "PERF OK"
    exit 0
else
    echo "ERROR: Performance budget exceeded!" >&2
    exit 1
fi
