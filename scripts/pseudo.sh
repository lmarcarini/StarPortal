#!/usr/bin/env bash
# Runs the game with Godot's built-in pseudolocalization switched on, to catch text overflow.
# Bible: technical-architecture.md#input-accessibility-and-localisation
#
# project.godot keeps pseudolocalization OFF and sets the expansion ratio (0.3, about 30%
# longer text, a little above Brazilian Portuguese's ~25%). This script switches it on for one
# run only, through a temporary override.cfg at the project root that it removes on exit.
# Nothing in project.godot changes.
#
# Needs a display: this launches the game window, so it does not run headless in CI.
#
# Usage: scripts/pseudo.sh [extra Godot arguments]
# Env:   GODOT_BIN  path to the Godot 4 binary (default: godot)
#
# Portable across Linux, macOS and Git Bash on Windows: POSIX tools only.

GODOT_BIN="${GODOT_BIN:-godot}"

# Repository root: the parent of this script's directory.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OVERRIDE_FILE="$PROJECT_DIR/override.cfg"

if ! command -v "$GODOT_BIN" > /dev/null 2>&1; then
	echo "pseudo.sh: Godot binary '$GODOT_BIN' not found. Set GODOT_BIN to its path." >&2
	exit 2
fi

# Never overwrite or delete an override.cfg this script did not create.
if [ -e "$OVERRIDE_FILE" ]; then
	echo "pseudo.sh: $OVERRIDE_FILE already exists; move it away and run again." >&2
	exit 2
fi

cleanup() {
	rm -f "$OVERRIDE_FILE"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# override.cfg replaces only the keys it lists; every other setting comes from project.godot.
cat > "$OVERRIDE_FILE" << 'EOF'
[internationalization]

pseudolocalization/use_pseudolocalization=true
EOF

echo "pseudo.sh: launching with pseudolocalization on ..."
"$GODOT_BIN" --path "$PROJECT_DIR" "$@"
game_code=$?

echo "pseudo.sh: game exited with code $game_code"
exit "$game_code"
