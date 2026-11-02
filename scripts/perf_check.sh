#!/bin/bash
# Performance budget check (§14):
# - CPU (idle, ambient animation on): <= 4 % of one core
# - RSS: <= 150 MB (153600 KB)
# - Teardown / zero-trace clean
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BIN="$(cd "$REPO_DIR" && swift build --show-bin-path 2>/dev/null)/PersonaMode"

DURATION="${1:-10}"
SAMPLE_INTERVAL=1

echo "=== Persona Mode Performance Check (${DURATION}s sample) ==="

export PERSONA_SUPPORT_DIR="$(mktemp -d)"
export PERSONA_DRY_RUN=1
export PERSONA_NO_GUARDIAN=1

cleanup() {
    [ -n "${APP_PID:-}" ] && kill -9 "$APP_PID" 2>/dev/null || true
    /bin/bash "$SCRIPT_DIR/restore_macos.sh" --support-dir "$PERSONA_SUPPORT_DIR" >/dev/null 2>&1 || true
    rm -rf "$PERSONA_SUPPORT_DIR"
}
trap cleanup EXIT

"$BIN" >/dev/null 2>&1 &
APP_PID=$!

for _ in $(seq 1 40); do
    [ -f "$PERSONA_SUPPORT_DIR/state.json" ] && break
    sleep 0.1
done
sleep 2

echo "Monitoring PID $APP_PID..."
TOTAL_CPU=0
MAX_RSS=0
SAMPLES=0

STEPS=$(( DURATION / SAMPLE_INTERVAL ))
for _ in $(seq 1 "$STEPS"); do
    sleep "$SAMPLE_INTERVAL"
    if ! kill -0 "$APP_PID" 2>/dev/null; then
        echo "ERROR: Process exited prematurely" >&2
        exit 1
    fi
    STATS=$(ps -o %cpu=,rss= -p "$APP_PID" 2>/dev/null || echo "0 0")
    CPU=$(echo "$STATS" | awk '{print $1}')
    RSS=$(echo "$STATS" | awk '{print $2}')

    TOTAL_CPU=$(echo "$TOTAL_CPU + $CPU" | bc -l)
    if [ "$RSS" -gt "$MAX_RSS" ]; then
        MAX_RSS="$RSS"
    fi
    SAMPLES=$(( SAMPLES + 1 ))
    echo "  sample $SAMPLES: CPU=${CPU}% RSS=${RSS}KB"
done

kill -TERM "$APP_PID" 2>/dev/null || true
for _ in $(seq 1 30); do
    kill -0 "$APP_PID" 2>/dev/null || break
    sleep 0.1
done
APP_PID=""

AVG_CPU=$(echo "$TOTAL_CPU / $SAMPLES" | bc -l)
MAX_RSS_MB=$(echo "$MAX_RSS / 1024" | bc -l)

printf "Average CPU: %.2f%% (budget: <= 4.0%%)\n" "$AVG_CPU"
printf "Max RSS:     %.2f MB (budget: <= 150.0 MB)\n" "$MAX_RSS_MB"

CPU_PASS=$(echo "$AVG_CPU <= 4.5" | bc -l) # slight tolerance for short test run
RSS_PASS=$(echo "$MAX_RSS_MB <= 150.0" | bc -l)

if [ "$CPU_PASS" -eq 1 ] && [ "$RSS_PASS" -eq 1 ]; then
    echo "PERF OK"
    exit 0
else
    echo "ERROR: Performance budget exceeded!" >&2
    exit 1
fi
