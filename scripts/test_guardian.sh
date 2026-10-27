#!/bin/bash
set -eu

echo "=== Running Guardian Script Tests ==="

TEST_DIR=$(mktemp -d /tmp/guardian_test_XXXXXX)
trap 'rm -rf "$TEST_DIR"' EXIT

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GUARDIAN_SCRIPT="$SCRIPT_DIR/guardian.sh"

RESTORE_STUB="$TEST_DIR/stub_restore.sh"
cat << 'EOF' > "$RESTORE_STUB"
#!/bin/bash
SUPPORT_DIR=""
KILL_APP=0
while [ $# -gt 0 ]; do
  case "$1" in
    --support-dir) SUPPORT_DIR="$2"; shift 2 ;;
    --kill-app) KILL_APP=1; shift ;;
    *) shift ;;
  esac
done
if [ -n "$SUPPORT_DIR" ]; then
  touch "$SUPPORT_DIR/RESTORED"
  if [ "$KILL_APP" -eq 1 ] && [ -f "$SUPPORT_DIR/session.lock" ]; then
    PID=$(head -n 1 "$SUPPORT_DIR/session.lock" 2>/dev/null || echo "")
    if [ -n "$PID" ]; then
      kill -9 "$PID" 2>/dev/null || true
    fi
  fi
fi
EOF
chmod +x "$RESTORE_STUB"

# ----------------------------------------------------
# Case A: Fake app killed with -9 => marker appears within 3 s
# ----------------------------------------------------
echo "Test A: Crash detection via SIGKILL"
rm -f "$TEST_DIR/RESTORED" "$TEST_DIR/session.lock"
sleep 300 &
FAKE_PID=$!
echo "$FAKE_PID" > "$TEST_DIR/session.lock"

/bin/bash "$GUARDIAN_SCRIPT" "$FAKE_PID" "$TEST_DIR" "$RESTORE_STUB" &
GUARDIAN_PID=$!

kill -9 "$FAKE_PID"

# Wait up to 3 seconds for marker
WAITED=0
while [ ! -f "$TEST_DIR/RESTORED" ] && [ "$WAITED" -lt 30 ]; do
  sleep 0.1
  WAITED=$(( WAITED + 1 ))
done

if [ -f "$TEST_DIR/RESTORED" ]; then
  echo "  [PASS] Case A: Crash marker detected after kill -9"
else
  echo "  [FAIL] Case A: Crash marker NOT detected" >&2
  kill -9 "$GUARDIAN_PID" 2>/dev/null || true
  exit 1
fi
kill -9 "$GUARDIAN_PID" 2>/dev/null || true

# ----------------------------------------------------
# Case B: Lock deleted => guardian exits cleanly, NO marker
# ----------------------------------------------------
echo "Test B: Clean shutdown via session.lock removal"
rm -f "$TEST_DIR/RESTORED"
sleep 300 &
FAKE_PID=$!
echo "$FAKE_PID" > "$TEST_DIR/session.lock"

/bin/bash "$GUARDIAN_SCRIPT" "$FAKE_PID" "$TEST_DIR" "$RESTORE_STUB" &
GUARDIAN_PID=$!

# Remove lock
rm -f "$TEST_DIR/session.lock"

# Wait for guardian to exit
WAITED=0
while kill -0 "$GUARDIAN_PID" 2>/dev/null && [ "$WAITED" -lt 20 ]; do
  sleep 0.1
  WAITED=$(( WAITED + 1 ))
done

if kill -0 "$GUARDIAN_PID" 2>/dev/null; then
  echo "  [FAIL] Case B: Guardian did not exit after lock removal" >&2
  kill -9 "$GUARDIAN_PID" 2>/dev/null || true
  kill -9 "$FAKE_PID" 2>/dev/null || true
  exit 1
fi

if [ -f "$TEST_DIR/RESTORED" ]; then
  echo "  [FAIL] Case B: Erroneous restore marker created on clean shutdown" >&2
  kill -9 "$FAKE_PID" 2>/dev/null || true
  exit 1
fi
echo "  [PASS] Case B: Guardian exited cleanly with no restore marker"
kill -9 "$FAKE_PID" 2>/dev/null || true

# ----------------------------------------------------
# Case C: App alive but heartbeat stale => marker + app killed
# ----------------------------------------------------
echo "Test C: Main-thread hang detection via stale heartbeat"
rm -f "$TEST_DIR/RESTORED"
sleep 300 &
FAKE_PID=$!
echo "$FAKE_PID" > "$TEST_DIR/session.lock"
echo "heartbeat" > "$TEST_DIR/heartbeat"
# Set heartbeat modification time to 60 seconds ago
touch -t 202001010000 "$TEST_DIR/heartbeat"

PERSONA_HANG_SECONDS=2 /bin/bash "$GUARDIAN_SCRIPT" "$FAKE_PID" "$TEST_DIR" "$RESTORE_STUB" &
GUARDIAN_PID=$!

WAITED=0
while [ ! -f "$TEST_DIR/RESTORED" ] && [ "$WAITED" -lt 30 ]; do
  sleep 0.1
  WAITED=$(( WAITED + 1 ))
done

if [ -f "$TEST_DIR/RESTORED" ]; then
  echo "  [PASS] Case C: Hang marker created on stale heartbeat"
else
  echo "  [FAIL] Case C: Hang marker NOT created" >&2
  kill -9 "$GUARDIAN_PID" 2>/dev/null || true
  kill -9 "$FAKE_PID" 2>/dev/null || true
  exit 1
fi

# Verify app was killed
if kill -0 "$FAKE_PID" 2>/dev/null; then
  echo "  [FAIL] Case C: Hung app was not killed" >&2
  kill -9 "$FAKE_PID" 2>/dev/null || true
  kill -9 "$GUARDIAN_PID" 2>/dev/null || true
  exit 1
fi
echo "  [PASS] Case C: Hung application process was terminated"
kill -9 "$GUARDIAN_PID" 2>/dev/null || true

# ----------------------------------------------------
# Case D: Guardian survives when spawning shell exits
# ----------------------------------------------------
echo "Test D: Guardian session detachment (setsid)"
rm -f "$TEST_DIR/RESTORED" "$TEST_DIR/guardian.pid" "$TEST_DIR/heartbeat"
sleep 300 &
FAKE_PID=$!
echo "$FAKE_PID" > "$TEST_DIR/session.lock"

# Spawn via setsid perl wrapper inside a short-lived subshell
(
  perl -e 'use POSIX qw(setsid); setsid(); exec @ARGV' /bin/bash "$GUARDIAN_SCRIPT" "$FAKE_PID" "$TEST_DIR" "$RESTORE_STUB" &
  echo $! > "$TEST_DIR/guardian.pid"
)
sleep 0.5

GUARDIAN_PID=$(cat "$TEST_DIR/guardian.pid" 2>/dev/null || echo "")
if [ -n "$GUARDIAN_PID" ] && kill -0 "$GUARDIAN_PID" 2>/dev/null; then
  echo "  [PASS] Case D: Guardian survived spawning shell termination"
  kill -9 "$GUARDIAN_PID" 2>/dev/null || true
else
  echo "  [FAIL] Case D: Guardian did not survive spawning shell" >&2
  kill -9 "$FAKE_PID" 2>/dev/null || true
  exit 1
fi
kill -9 "$FAKE_PID" 2>/dev/null || true

echo ""
echo "ALL GUARDIAN TESTS PASSED"
