# Far Side Protocol

A Godot game inspired by the Stargate TV series.

## Requirements

- Godot **4.7.2** (stable, standard build — not .NET). The exact version is pinned in `.godot-version`.

## Opening the project

1. Install Godot 4.7.2 (see <https://godotengine.org/download/archive/>).
2. Clone this repository.
3. Start Godot, choose **Import**, and select the `project.godot` file at the repository root.
4. Press **F5** (Run Project) to start the main scene.

From the command line:

```sh
godot --path .            # run the game
godot --editor --path .   # open the editor
```

The main scene is `res://src/scenes/shell/shell.tscn`.

## Running tests

Tests use [gdUnit4](https://github.com/MikeSchulze/gdUnit4) (vendored in `addons/gdUnit4/`) and
run headless from one command, on Linux, macOS and Git Bash on Windows:

```sh
scripts/test.sh                              # uses `godot` from PATH
GODOT_BIN=/path/to/godot scripts/test.sh     # or point at a specific binary
```

- Runs every test under `res://tests` except `res://tests/soak/` (the long soak run).
- Imports the project first, so it works on a fresh checkout with no `.godot/` folder.
- Exits `0` when all tests pass and non-zero on any failure or script error.
- Extra arguments are passed to the gdUnit4 runner. Reports are written to `.godot/test-reports/`.

Test suites extend `GdUnitTestSuite`; test functions start with `test_`.
