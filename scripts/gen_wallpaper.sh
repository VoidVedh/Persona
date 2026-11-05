#!/bin/bash
# scripts/gen_wallpaper.sh — Generates Resources/wallpaper/p3r_wallpaper.png (3840x2160) from Resources/webui/wallpaper.html.
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_DIR"

BIN=".build/debug/PersonaMode"
if [ ! -x "$BIN" ]; then
    swift build --product PersonaMode
fi

mkdir -p "Resources/wallpaper"
OUT_PNG="Resources/wallpaper/p3r_wallpaper.png"

"$BIN" --probe render webui wallpaper "$OUT_PNG" --w 3840 --h 2160 --scale 1 --freeze 0 --seed 7
cp "$OUT_PNG" /tmp/v2_wallpaper_4k.png
echo "Generated 4K P3R wallpaper: $OUT_PNG"
ls -lh "$OUT_PNG"
