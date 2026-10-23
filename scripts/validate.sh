#!/usr/bin/env bash
# Validates the game content headless: the Registry, the 36 glyphs, the anchor field, the authored
# worlds, the balance tunables, and the generated galaxies of seeds 1..20.
# Prints one line per problem. Exit code: 0 when the content is valid, non-zero otherwise.
#
# Usage: scripts/validate.sh
# Env:   GODOT_BIN  path to the Godot 4 binary (default: godot)
#
# Portable across Linux, macOS and Git Bash on Windows: POSIX tools only.

GODOT_BIN="${GODOT_BIN:-godot}"

# Repository root: the parent of this script's directory.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if ! command -v "$GODOT_BIN" > /dev/null 2>&1; then
	echo "validate.sh: Godot binary '$GODOT_BIN' not found. Set GODOT_BIN to its path." >&2
	exit 2
fi

# A fresh checkout has no .godot/ cache yet; import once so the tools' global classes are
# registered before the script starts.
echo "validate.sh: importing project ..."
"$GODOT_BIN" --headless --path "$PROJECT_DIR" --import
import_code=$?
if [ "$import_code" -ne 0 ]; then
	echo "validate.sh: project import failed with exit code $import_code" >&2
	exit "$import_code"
fi

echo "validate.sh: validating content ..."
# The output is kept so that a script that fails to compile (Godot then runs nothing and still
# exits 0) is reported as a failure, not as valid content.
log="$(mktemp)"
"$GODOT_BIN" --headless --path "$PROJECT_DIR" --script tools/validate_content.gd > "$log" 2>&1
validate_code=$?
cat "$log"
if [ "$validate_code" -eq 0 ] && grep -q -e "SCRIPT ERROR" -e "^ERROR:" "$log"; then
	echo "validate.sh: Godot reported script errors" >&2
	validate_code=1
fi
if [ "$validate_code" -eq 0 ] && ! grep -q "validate: content is valid" "$log"; then
	echo "validate.sh: the validator did not finish" >&2
	validate_code=1
fi
rm -f "$log"
echo "validate.sh: finished with exit code $validate_code"
exit "$validate_code"
