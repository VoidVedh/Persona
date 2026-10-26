#!/bin/bash
# doctor.sh — Environment & Toolchain Diagnostics for Persona Mode

echo "=== System Information ==="
sw_vers
echo "Architecture: $(uname -m)"
echo "SIP Status: $(csrutil status 2>/dev/null || echo 'unknown')"

echo ""
echo "=== Developer Tools ==="
xcode-select -p 2>/dev/null || echo "xcode-select: not set"
swift --version 2>&1 | head -n 2

echo ""
echo "=== Required System Binaries ==="
MISSING_REQUIRED=0
for bin in swift plutil osascript defaults killall /usr/libexec/PlistBuddy; do
    if [ -x "$bin" ] || command -v "$bin" >/dev/null 2>&1; then
        echo "  [OK] $bin"
    else
        echo "  [MISSING] $bin"
        if [ "$bin" = "swift" ] || [ "$bin" = "plutil" ] || [ "$bin" = "osascript" ]; then
            MISSING_REQUIRED=1
        fi
    fi
done

echo ""
echo "=== Optional Rice & Terminal Binaries ==="
for term in fastfetch ghostty kitty wezterm alacritty cava; do
    LOC=$(command -v "$term" 2>/dev/null)
    if [ -n "$LOC" ]; then
        echo "  [FOUND] $term -> $LOC"
    else
        echo "  [NOT FOUND] $term (optional)"
    fi
done

echo ""
echo "=== Code Signing Identities ==="
security find-identity -v -p codesigning 2>/dev/null || echo "No code signing identities detected"

echo ""
if [ "$MISSING_REQUIRED" -ne 0 ]; then
    echo "ERROR: One or more required tools (swift, plutil, osascript) are missing!"
    exit 1
fi

echo "Doctor check complete: System is ready."
exit 0
