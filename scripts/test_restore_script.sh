#!/bin/bash
# test_restore_script.sh — Automated tests for restore_macos.sh
# Compatible with macOS /bin/bash (v3.2)

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESTORE_SCRIPT="$REPO_ROOT/scripts/restore_macos.sh"
FIXTURES_DIR="$REPO_ROOT/scripts/fixtures"

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local test_name="$3"
    if echo "$haystack" | grep -q -- "$needle"; then
        echo "  [PASS] $test_name"
    else
        echo "  [FAIL] $test_name" >&2
        echo "  Expected output to contain: '$needle'" >&2
        echo "  Actual output was:" >&2
        echo "$haystack" >&2
        exit 1
    fi
}

assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    local test_name="$3"
    if echo "$haystack" | grep -q -- "$needle"; then
        echo "  [FAIL] $test_name" >&2
        echo "  Expected output to NOT contain: '$needle'" >&2
        echo "  Actual output was:" >&2
        echo "$haystack" >&2
        exit 1
    else
        echo "  [PASS] $test_name"
    fi
}

echo "=== Running Restore Script Tests ==="

# Test 1: Restoring from valid hidden state fixture
echo "Test 1: Valid hidden state restoration"
T1_DIR=$(mktemp -d)
cp "$FIXTURES_DIR/state_hidden.json" "$T1_DIR/state.json"
echo "12345" > "$T1_DIR/session.lock"
T1_OUT=$(/bin/bash "$RESTORE_SCRIPT" --dry-run --support-dir "$T1_DIR" 2>&1)

assert_contains "$T1_OUT" "tell application \"System Events\" to set autohide of dock preferences to false" "T1: Dock scripted autohide reset"
assert_contains "$T1_OUT" "defaults delete com.apple.dock autohide" "T1: Dock raw pref deleted"
assert_contains "$T1_OUT" "tell application \"System Events\" to set autohide menu bar of dock preferences to false" "T1: Menu bar scripted autohide reset"
assert_contains "$T1_OUT" "defaults delete NSGlobalDomain _HIHideMenuBar" "T1: _HIHideMenuBar deleted"
assert_contains "$T1_OUT" "defaults delete NSGlobalDomain AppleMenuBarVisibleInFullscreen" "T1: AppleMenuBarVisibleInFullscreen deleted"
assert_contains "$T1_OUT" "rm -rf /tmp/PersonaMode/profiles" "T1: Ledgered temp dir removed"
assert_contains "$T1_OUT" "rm -f $T1_DIR/session.lock" "T1: Session lock file removed"
rm -rf "$T1_DIR"

# Test 2: Missing state file (defaults fallback)
echo "Test 2: Missing state file fails open to visible defaults"
T2_DIR=$(mktemp -d)
T2_OUT=$(/bin/bash "$RESTORE_SCRIPT" --dry-run --support-dir "$T2_DIR" 2>&1)

assert_contains "$T2_OUT" "Failing open to stock macOS default visible desktop" "T2: Fail open message"
assert_contains "$T2_OUT" "tell application \"System Events\" to set autohide of dock preferences to false" "T2: Dock set to false"
assert_contains "$T2_OUT" "defaults delete com.apple.dock autohide" "T2: Dock delete raw key"
assert_contains "$T2_OUT" "tell application \"System Events\" to set autohide menu bar of dock preferences to false" "T2: Menu bar set to false"
assert_contains "$T2_OUT" "defaults delete NSGlobalDomain _HIHideMenuBar" "T2: Menu bar delete _HIHideMenuBar"
rm -rf "$T2_DIR"

# Test 3: Corrupt state file
echo "Test 3: Corrupt state file triggers fallback"
T3_DIR=$(mktemp -d)
cp "$FIXTURES_DIR/state_corrupt.json" "$T3_DIR/state.json"
T3_OUT=$(/bin/bash "$RESTORE_SCRIPT" --dry-run --support-dir "$T3_DIR" 2>&1)

assert_contains "$T3_OUT" "failed plutil validation (corrupt)" "T3: Detects corrupt state"
assert_contains "$T3_OUT" "Failing open to stock macOS default visible desktop" "T3: Falls open to defaults"
assert_contains "$T3_OUT" "defaults delete com.apple.dock autohide" "T3: Deletes dock key on corrupt fallback"
rm -rf "$T3_DIR"

# Test 4: Security prefix guard refuses malicious tempdir
echo "Test 4: Security prefix guard refuses malicious temp directory"
T4_DIR=$(mktemp -d)
cat << 'EOF' > "$T4_DIR/state.json"
{
  "active" : true,
  "appPid" : 12345,
  "createdAt" : "2026-10-26T06:00:00Z",
  "ledger" : {
    "entries" : [
      {
        "id" : "MUT-MALICIOUS",
        "mutation" : {
          "tempDir" : {
            "path" : "/Users"
          }
        },
        "status" : "applied",
        "ts" : "2026-10-26T06:00:01Z"
      }
    ]
  },
  "macOS" : "26.6.2",
  "phase" : "active",
  "schemaVersion" : 1,
  "sessionId" : "TEST-MALICIOUS",
  "snapshot" : {
    "dock" : { "autohide" : { "present" : false } },
    "menuBar" : { "hideMenuBar" : { "present" : false }, "visibleInFullscreen" : { "present" : false } },
    "wallpapers" : []
  },
  "wallpaperMode" : "overlay"
}
EOF
T4_OUT=$(/bin/bash "$RESTORE_SCRIPT" --dry-run --support-dir "$T4_DIR" 2>&1)

assert_contains "$T4_OUT" "SECURITY WARNING: Refusing to delete path outside safe temp prefixes: /Users" "T4: Malicious path refused"
assert_not_contains "$T4_OUT" "rm -rf /Users" "T4: Does not emit rm -rf /Users"
rm -rf "$T4_DIR"

# Test 5: Process termination from session.lock
echo "Test 5: Process termination"
T5_DIR=$(mktemp -d)
echo "98765" > "$T5_DIR/session.lock"
T5_OUT=$(/bin/bash "$RESTORE_SCRIPT" --dry-run --support-dir "$T5_DIR" 2>&1)

assert_contains "$T5_OUT" "Terminating active PersonaMode PID: 98765" "T5: PID detected from session.lock"
assert_contains "$T5_OUT" "kill -TERM 98765" "T5: TERM signal emitted"
assert_contains "$T5_OUT" "pkill -f Persona Mode.app/Contents/MacOS" "T5: pkill app emitted"
assert_contains "$T5_OUT" "pkill -f scripts/guardian.sh" "T5: pkill guardian emitted"
rm -rf "$T5_DIR"

echo ""
echo "ALL RESTORE SCRIPT TESTS PASSED"
exit 0
