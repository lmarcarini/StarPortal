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

## Lint

GDScript under `src/`, `tests/` and `tools/` is checked with
[gdtoolkit](https://github.com/Scony/godot-gdscript-toolkit) (`gdformat` and `gdlint`) at the
exact version pinned in `.gdtoolkit-version`. That file is the only place the version is
written: CI installs from it, `scripts/lint.sh` names it in its install hint, and CI fails if
the version string appears in any other tracked file outside `addons/`.
Vendored `addons/` are not checked. Rules live in `gdlintrc` at the repository root: max line
length 100, max 400 lines per file, max 4 function arguments, snake_case function names and
PascalCase class names.

```sh
pip install "gdtoolkit==$(cat .gdtoolkit-version)"   # once
scripts/lint.sh                # check formatting and lint; exits non-zero on any problem
gdformat src tests tools       # fix formatting in place
```

CI (`.github/workflows/ci.yml`, status check `ci`) runs on pull requests that are not drafts:
lint, then Godot project import, then `scripts/test.sh`. Pull requests that change only docs or
Markdown skip it, and pushes to `main` do not run it again (the pull request already did). When
tests fail, the reports in `.godot/test-reports/` are uploaded as the `test-reports` artifact of
the run. The Godot zip is checked against the `SHA512-SUMS.txt` of the same
`godotengine/godot-builds` release, on every run (cached or not), before Godot is started. A
newer push to a pull request cancels its older run. The `soak` job runs nightly on `main`, only
when it got new commits in the last 24 hours, and can be started by hand (Actions → ci → Run
workflow).

## Tools

Headless content tools live in `tools/` (run from the project root; `tools/` is for development
only: no game file refers to it, and a test checks that).

- **Content validator:** `GODOT_BIN=/path/to/godot scripts/validate.sh` checks the Registry, the 36
  glyphs (indices, translation keys in `glyphs.csv`, constellations), the home anchor field (36
  anchors within the coordinate bounds, at least 2,500 ly apart), CAIRN and the authored worlds
  (origin glyphs, unique addresses from every origin), the balance tunables, and, for galaxy seeds
  1..20, the generator (early reach, unique addresses). It prints one line per problem and exits
  non-zero on any; the run takes about 5 seconds and prints its timing. CI runs it after the
  tests.
- **Reference capture:** `GODOT_BIN=/path/to/godot scripts/reference.sh` (needs `xvfb-run` and
  Python with Pillow) runs `scenario_gate_station` at 1920 × 1080 through
  `tools/reference/capture.tscn`, captures the three reference states (`gate_idle` with SILL
  selected, `gate_open` with the mission sheet, `other_station` on the Base) and writes into
  `build/reference/` (git-ignored): `<state>.png`, `<state>_compare.png` (capture | reference over
  capture under the overlay | difference, half size) and `<state>_overlay.png` (full size, for
  checking regions against `docs/reference/layout.json`). Every UI PR embeds the three
  `_compare.png` images (docs/content/interface-reference.md section 6).
- **Export:** the project has no `export_presets.cfg` yet. When export presets are added, their
  exclude filter must list `tools/*` (and a test fails if a preset file exists without it).

## Baking the Gate hall

The 3D Gate hall (`src/scenes/stations/gate_hall.tscn`, preview behind the
`display/stations_3d` setting) has a LightmapGI node; its lamps are static. Baking needs a
Vulkan-capable machine:

1. Open the editor with Forward+: `godot --rendering-method forward_plus -e`.
2. Open `src/scenes/stations/gate_hall.tscn`, select the `LightmapGI` node and press **Bake
   Lightmaps**.
3. Commit the `.lmbake` and `.exr` files written beside the scene. The Compatibility renderer
   shows them. Rebake after `python3 tools/m5/gen_hall.py src/scenes/stations/gate_hall.tscn`.

## Translations

All visible text comes from translation tables, one CSV per area in `localization/` (`core`,
`gate`, `glyphs`, `clues`, `workbench`, `board`; UTF-8, no BOM), each with the columns
`keys,en,pt_BR`: English and Brazilian Portuguese. A key lives in exactly one table. Godot imports
each table into `.translation` files (generated, not committed) that are listed under
`[internationalization]` in `project.godot`.

- **Keys** are `AREA_SCREEN_NAME` in UPPER_SNAKE_CASE, for example `UI_SHELL_DATE` or
  `UI_SPEED_PAUSED`. Scenes store the key as the text (`text = "UI_SPEED_PAUSED"`); Godot
  translates it at runtime. A test fails if any `text`, `tooltip_text` or `placeholder_text` in
  a `.tscn` under `src/` is not a key from the table.
- **Placeholders** are named braces, filled with `String.format`, never string concatenation:
  `tr("UI_SPEED_MULTIPLIER").format({"speed": 2})` gives `2×`. Both languages must use the
  same placeholders.
- **Adding a string:** add a row to your area's table with a non-empty `en` and `pt_BR` value,
  then run `scripts/test.sh` (it re-imports the tables and checks them).
- **Overflow check:** Brazilian Portuguese runs about 25% longer than English, so lay every label
  out to grow. `scripts/pseudo.sh` runs the game with Godot's pseudolocalization on (accented
  text, about 30% longer, wrapped in `[ ]`), so clipped or overflowing labels are easy to spot. It
  needs a display, takes `GODOT_BIN` like `scripts/test.sh`, and switches pseudolocalization on
  for that run only, through a temporary `override.cfg` it deletes on exit.

```sh
GODOT_BIN=/path/to/godot scripts/pseudo.sh
```

## Project board

The GitHub Project board follows the cards through a workflow; see [docs/board.md](docs/board.md).
