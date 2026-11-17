#!/usr/bin/env bash
# Captures the game in the three reference states at 1920x1080 and writes comparison
# images next to the captures in build/reference/ (git-ignored).
# Reference: docs/content/interface-reference.md section 6
#
# Usage: scripts/reference.sh
# Env:   GODOT_BIN  path to the Godot 4 binary (default: godot)
# Needs: xvfb-run, python3 with Pillow.

GODOT_BIN="${GODOT_BIN:-godot}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT_DIR="$PROJECT_DIR/build/reference"

if ! command -v "$GODOT_BIN" > /dev/null 2>&1; then
	echo "reference.sh: Godot binary '$GODOT_BIN' not found. Set GODOT_BIN to its path." >&2
	exit 2
fi
mkdir -p "$OUT_DIR"
rm -f "$OUT_DIR"/*.png

"$GODOT_BIN" --headless --path "$PROJECT_DIR" --import > /dev/null 2>&1 || true
REF_OUT="$OUT_DIR" timeout 600 xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT_BIN" --path "$PROJECT_DIR" \
	--rendering-driver opengl3 --resolution 1920x1080 res://tools/reference/capture.tscn
python3 "$PROJECT_DIR/tools/reference/compare.py" "$OUT_DIR" "$PROJECT_DIR/docs/reference"
