#!/bin/bash
# Downloads the bundled OFL fonts (Rajdhani, Bebas Neue) into Resources/fonts.
# Idempotent; verifies each file is a TrueType font. Requires network (curl).
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEST="$SCRIPT_DIR/../Resources/fonts"
BASE="https://github.com/google/fonts/raw/main/ofl"
mkdir -p "$DEST"

fetch() {
    local url="$1" out="$2"
    if [ -s "$DEST/$out" ]; then
        echo "have   $out"
        return 0
    fi
    echo "fetch  $out"
    curl -fsSL --retry 3 -o "$DEST/$out.tmp" "$url"
    mv "$DEST/$out.tmp" "$DEST/$out"
}

fetch "$BASE/rajdhani/Rajdhani-SemiBold.ttf" "Rajdhani-SemiBold.ttf"
fetch "$BASE/rajdhani/Rajdhani-Bold.ttf" "Rajdhani-Bold.ttf"
fetch "$BASE/rajdhani/OFL.txt" "OFL-rajdhani.txt"
fetch "$BASE/bebasneue/BebasNeue-Regular.ttf" "BebasNeue-Regular.ttf"
fetch "$BASE/bebasneue/OFL.txt" "OFL-bebasneue.txt"

for f in "$DEST"/*.ttf; do
    if ! file "$f" | grep -q "TrueType"; then
        echo "ERROR: $f is not a TrueType font" >&2
        exit 1
    fi
done
echo "fonts OK:"
ls -1 "$DEST"
