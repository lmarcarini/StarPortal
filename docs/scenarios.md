# Scenarios

A scenario is a shipped starting state: a save file and a `ScenarioDef` under `data/scenarios/`.
The main menu lists them under **Scenarios** in `order`, with the title and the description.
Choosing one loads the save through the same checks and migrations as any save and starts it
paused. Saving afterwards writes a normal user slot; the shipped file is never written.

## Adding one

1. Play to the state you want and save it to a slot (pause menu → Save, or F8 for `quicksave`).
2. Run, from the project folder:

   ```
   godot --headless -s tools/make_scenario.gd -- <slot> <scenario_id> "<title>" "<description>"
   ```

   This copies `user://saves/<slot>.json` to `data/scenarios/<scenario_id>.json`, writes
   `data/scenarios/<scenario_id>.tres` (placed after the others) and adds the title and
   description to `localization/core.csv` with the English text in both columns.
3. Translate the pt_BR column, adjust `order` if needed, and commit both files.

## Keeping them fresh

`tests/content/test_scenarios.gd` loads every shipped scenario on every run, so a save-format
change that breaks one fails the tests. The content validator also checks that each def's file
exists and migrates. When a format change makes a migration impossible, re-make the scenario.
