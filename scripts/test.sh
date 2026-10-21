#!/usr/bin/env bash
# Runs every gdUnit4 test under res://tests headless, except res://tests/soak/.
# Exit code: 0 when all tests pass, non-zero on any failure or error.
#
# Usage: scripts/test.sh [extra gdUnit4 runner options]
# Env:   GODOT_BIN  path to the Godot 4 binary (default: godot)
#
# Portable across Linux, macOS and Git Bash on Windows: POSIX tools only.

GODOT_BIN="${GODOT_BIN:-godot}"

# Repository root: the parent of this script's directory.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if ! command -v "$GODOT_BIN" > /dev/null 2>&1; then
	echo "test.sh: Godot binary '$GODOT_BIN' not found. Set GODOT_BIN to its path." >&2
	exit 2
fi

# A fresh checkout has no .godot/ cache yet; import once so gdUnit4's
# global classes are registered before the runner starts.
echo "test.sh: importing project ..."
"$GODOT_BIN" --headless --path "$PROJECT_DIR" --import > /dev/null 2>&1
import_code=$?
if [ "$import_code" -ne 0 ]; then
	echo "test.sh: project import failed with exit code $import_code" >&2
	exit "$import_code"
fi

# No -d flag: Godot's interactive CLI debugger would wait for input on a
# script error and hang a CI run. Errors are reported by gdUnit4 instead.
echo "test.sh: running tests ..."
"$GODOT_BIN" --headless --path "$PROJECT_DIR" -s \
	res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
	--ignoreHeadlessMode \
	-a res://tests \
	-i res://tests/soak/ \
	-rd res://.godot/test-reports \
	"$@"
test_code=$?

echo "test.sh: tests finished with exit code $test_code"
exit "$test_code"
