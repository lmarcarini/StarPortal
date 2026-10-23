## Tests for the v3 -> v4 SaveMigrator step: it adds empty "intel" (both counters 1, nothing
## scheduled) and "workbench" (origin -1) sections; and a real v3 save file written by the
## v3 SaveService (tests/services/fixtures/save_v3.json) loads through v4 into v5, which
## drops those sections and the dial queue again.
## Bible: technical-architecture.md#save-system
extends GdUnitTestSuite

const SaveServiceScript := preload("res://src/services/save_service.gd")
const V3_FIXTURE: String = "res://tests/services/fixtures/save_v3.json"
const EMPTY_INTEL: Dictionary = {
	"clues": [],
	"notes": {},
	"next_clue_number": 1,
	"next_dossier_number": 1,
	"scheduled_dossiers": {},
}
const EMPTY_WORKBENCH: Dictionary = {"origin_glyph": -1, "constraints": []}


## Runs the built-in steps on [param data] up to v4 only.
func _migrate_to_v4(data: Dictionary) -> Result:
	return SaveMigrator.migrate_with_steps(data, SaveMigrator.built_in_steps(), 4)


func _v3_fixture() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(V3_FIXTURE))


## The fixture really is a v3 file, without the v4 sections.
func test_fixture_is_v3() -> void:
	var data := _v3_fixture()
	assert_float(data["format_version"]).is_equal(3.0)
	var state: Dictionary = data["state"]
	assert_bool(state.has("intel")).is_false()
	assert_bool(state.has("workbench")).is_false()


## v3 -> v4 adds the empty intel and Workbench sections, leaves every v3 section untouched,
## and the result is a valid state.
func test_v3_adds_intel_and_workbench() -> void:
	var data := _v3_fixture()
	var result := _migrate_to_v4(data)
	assert_bool(result.is_ok).is_true()
	var migrated: Dictionary = result.value
	assert_int(migrated["format_version"]).is_equal(4)
	var v3_state: Dictionary = data["state"]
	var expected := v3_state.duplicate(true)
	expected["intel"] = EMPTY_INTEL
	expected["workbench"] = EMPTY_WORKBENCH
	assert_dict(migrated["state"]).is_equal(expected)
	var migrated_state: Dictionary = migrated["state"]
	assert_array(GameState.validate_dict(migrated_state)).is_empty()


## v3 data with no state object passes through the step untouched.
func test_v3_without_state_is_left_for_validation() -> void:
	var result := _migrate_to_v4({"format_version": 3, "state": 5})
	assert_bool(result.is_ok).is_true()
	assert_dict(result.value).is_equal({"format_version": 4, "state": 5})


## The real v3 file loads through the SaveService and keeps its v3 state, less the dial
## queue that v4 -> v5 drops.
func test_v3_save_file_loads_into_v5() -> void:
	var service: SaveServiceScript = SaveServiceScript.new()
	var dir := "user://test_migrator_v3_%d_%d" % [Time.get_ticks_usec(), get_instance_id()]
	service.saves_dir = dir
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join("old_v3.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(FileAccess.get_file_as_string(V3_FIXTURE))
	file.close()
	var result: Result = service.load_game(&"old_v3")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(dir)
	service.free()
	assert_bool(result.is_ok).override_failure_message(str(result.detail)).is_true()
	var loaded: GameState = result.value
	assert_int(loaded.clock.tick).is_equal(2400)
	assert_int(loaded.random.base_seed).is_equal(20261022)
	assert_bool(loaded.flags[&"met_director"]).is_true()
	assert_array(loaded.gate.dial_log).has_size(1)
	assert_bool(loaded.gate.dial_log[0].energy_spent_mwh == 0.1 + 0.2).is_true()
	assert_bool(loaded.power.stored_mwh == 1.0 / 3.0).is_true()
	assert_int(loaded.worlds.status_of(&"abydos")).is_equal(WorldsState.WorldStatus.LOCKED)
