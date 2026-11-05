#!/bin/bash
# scripts/uninstall.sh — Restores stock macOS state (if active), resets TCC grants, and removes build artifacts.
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SUPPORT_DIR="${PERSONA_SUPPORT_DIR:-$HOME/Library/Application Support/PersonaMode}"

echo "=== Persona Mode Uninstaller ==="

if [ -f "$SUPPORT_DIR/state.json" ] || [ -f "$SUPPORT_DIR/session.lock" ]; then
    echo "Active or stale Persona Mode session detected; restoring macOS state..."
    bash "$SCRIPT_DIR/restore_macos.sh" --support-dir "$SUPPORT_DIR" || true
fi

echo "Resetting TCC permissions for dev.persona.mode..."
tccutil reset Accessibility dev.persona.mode 2>/dev/null || true
tccutil reset AppleEvents dev.persona.mode 2>/dev/null || true

echo "Removing temporary profiles and build bundle..."
rm -rf "${TMPDIR:-/tmp}/PersonaMode" /tmp/PersonaMode
rm -rf "$REPO_DIR/build"

echo "Uninstall complete."

