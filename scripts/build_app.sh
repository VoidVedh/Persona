#!/bin/bash
# scripts/build_app.sh — Packages PersonaMode into a signed macOS .app bundle ("build/Persona Mode.app").
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_DIR"

BUILD_CONFIG="${PERSONA_BUILD_CONFIG:-debug}"
echo "=== Building PersonaMode ($BUILD_CONFIG) ==="
swift build -c "$BUILD_CONFIG" --product PersonaMode
BIN_DIR="$(swift build -c "$BUILD_CONFIG" --show-bin-path)"
BIN="$BIN_DIR/PersonaMode"

if [ ! -f "Resources/profiles/terminal-app/Persona3Reload.terminal" ]; then
    "$BIN" --probe gen-terminal-profile --out "Resources/profiles/terminal-app/Persona3Reload.terminal" >/dev/null
fi

APP_DIR="$REPO_DIR/build/Persona Mode.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RES_DIR="$CONTENTS_DIR/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RES_DIR/fonts" "$RES_DIR/profiles" "$RES_DIR/scripts"

cp "$BIN" "$MACOS_DIR/PersonaMode"
chmod +x "$MACOS_DIR/PersonaMode"

if [ -d "Resources/fonts" ]; then
    cp -R Resources/fonts/. "$RES_DIR/fonts/"
fi
if [ -d "Resources/profiles" ]; then
    cp -R Resources/profiles/. "$RES_DIR/profiles/"
fi

cp scripts/restore_macos.sh "$RES_DIR/scripts/restore_macos.sh"
cp scripts/guardian.sh "$RES_DIR/scripts/guardian.sh"
chmod +x "$RES_DIR/scripts/restore_macos.sh" "$RES_DIR/scripts/guardian.sh"

cp Resources/Info.plist.template "$CONTENTS_DIR/Info.plist"
plutil -lint "$CONTENTS_DIR/Info.plist"

IDENTITY="-"
if security find-identity -v -p codesigning 2>/dev/null | grep -q "PersonaMode Dev"; then
    IDENTITY="PersonaMode Dev"
    echo "Signing with stable identity: $IDENTITY"
else
    echo "NOTE: 'PersonaMode Dev' certificate not found; using ad-hoc signature ('-')."
    echo "      Run 'bash scripts/setup_signing.sh' if you want stable TCC Accessibility identity across rebuilds."
fi

codesign --force --deep --sign "$IDENTITY" --identifier dev.persona.mode "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"

echo "Built and verified: $APP_DIR"

