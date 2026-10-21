#!/usr/bin/env bash
# Checks GDScript formatting (gdformat --check) and lint rules (gdlint, configured by
# gdlintrc) over src/, tests/ and tools/. Vendored addons/ are not checked.
# Exit code: 0 when both pass, non-zero otherwise.
#
# Usage: scripts/lint.sh
# Needs: gdtoolkit 4.x on PATH (pip install "gdtoolkit==4.5.0").
#        To fix formatting: gdformat src tests tools
#
# Portable across Linux, macOS and Git Bash on Windows: POSIX tools only.

# Repository root: the parent of this script's directory. gdlint finds gdlintrc
# by searching upwards from the working directory, so run from the root.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR" || exit 2

LINT_PATHS="src tests tools"

for tool in gdformat gdlint; do
	if ! command -v "$tool" > /dev/null 2>&1; then
		echo "lint.sh: '$tool' not found. Install gdtoolkit: pip install \"gdtoolkit==4.5.0\"" >&2
		exit 2
	fi
done

echo "lint.sh: checking formatting ($(gdformat --version)) ..."
# shellcheck disable=SC2086 # word splitting of LINT_PATHS is intended
gdformat --check --line-length=100 $LINT_PATHS
format_code=$?

echo "lint.sh: linting ..."
# shellcheck disable=SC2086
gdlint $LINT_PATHS
lint_code=$?

if [ "$format_code" -ne 0 ] || [ "$lint_code" -ne 0 ]; then
	echo "lint.sh: failed (gdformat exit $format_code, gdlint exit $lint_code)" >&2
	exit 1
fi

echo "lint.sh: all checks passed"
exit 0
