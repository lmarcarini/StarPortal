## Tests for SaveMigrator: pass-through at the current version, ordered step functions,
## distinct failures for bad, newer and unmigratable versions, and the v1 -> v2 clock step.
## Bible: technical-architecture.md#save-system
extends GdUnitTestSuite

const SaveServiceScript := preload("res://src/services/save_service.gd")


func _no_steps() -> Dictionary[int, Callable]:
	var steps: Dictionary[int, Callable] = {}
	return steps


## Steps 0 -> 1 -> 2 -> 3 that each append their from-version to data["log"].
func _logging_steps() -> Dictionary[int, Callable]:
	var steps: Dictionary[int, Callable] = {}
	for from_version: int in 3:
		steps[from_version] = func(data: Dictionary) -> Dictionary:
			var log_entries: Array = data.get("log", [])
			log_entries.append(from_version)
			data["log"] = log_entries
			return data
	return steps


## At the current version the data comes back unchanged.
func test_current_version_is_pass_through() -> void:
	var data := {"format_version": SaveMigrator.TARGET_VERSION, "tick": 7, "state": {"a": 1}}
	var result := SaveMigrator.migrate(data)
	assert_bool(result.is_ok).is_true()
	assert_dict(result.value).is_equal(data)


## The target version is 2, with one built-in step from v1.
func test_target_version_is_two() -> void:
	assert_int(SaveMigrator.TARGET_VERSION).is_equal(2)
	assert_array(SaveMigrator.built_in_steps().keys()).is_equal([1])


## A v1 save with the given clock, as JSON would parse it.
func _v1_save(clock: Dictionary) -> Dictionary:
	var state := {"clock": clock, "random": {}, "flags": {}}
	return {"format_version": 1.0, "tick": 5.0, "state": state}


## v1 -> v2 turns "is_paused" into "mode", adds empty holds and drops "is_paused".
func test_v1_clock_migrates_to_mode() -> void:
	var cases: Array[Array] = [[true, "paused"], [false, "running"]]
	for case: Array in cases:
		var data := _v1_save({"tick": 5.0, "speed_index": 2.0, "is_paused": case[0]})
		var result := SaveMigrator.migrate(data)
		assert_bool(result.is_ok).is_true()
		var migrated: Dictionary = result.value
		assert_int(migrated["format_version"]).is_equal(2)
		var state: Dictionary = migrated["state"]
		(
			assert_dict(state["clock"])
			. is_equal(
				{
					"tick": 5.0,
					"speed_index": 2.0,
					"mode": case[1],
					"holds": [],
					"mode_after_hold": "paused",
				}
			)
		)
		var clock_data: Dictionary = state["clock"]
		assert_array(ClockState.validate_dict(clock_data)).is_empty()


## A v1 clock with a non-bool "is_paused" is left for validation to reject.
func test_v1_bad_is_paused_is_left_for_validation() -> void:
	var result := SaveMigrator.migrate(_v1_save({"tick": 1, "speed_index": 1, "is_paused": 1}))
	assert_bool(result.is_ok).is_true()
	var migrated: Dictionary = result.value
	var state: Dictionary = migrated["state"]
	var clock_data: Dictionary = state["clock"]
	var errors := ClockState.validate_dict(clock_data)
	assert_array(errors).contains(["missing 'mode'"])


## A v1 save with no state object or no clock object passes through the step untouched.
func test_v1_without_clock_is_left_for_validation() -> void:
	for data: Dictionary in [{"format_version": 1}, {"format_version": 1, "state": {"x": 1}}]:
		var result := SaveMigrator.migrate(data)
		assert_bool(result.is_ok).is_true()
		var expected := data.duplicate(true)
		expected["format_version"] = 2
		assert_dict(result.value).is_equal(expected)


## A JSON-parsed version (a float such as 1.0) is accepted.
func test_json_float_version_is_accepted() -> void:
	var parsed: Variant = JSON.parse_string('{"format_version": 1, "tick": 3}')
	var data: Dictionary = parsed
	var result := SaveMigrator.migrate(data)
	assert_bool(result.is_ok).is_true()


## A registered fake v0 -> v1 step runs and the version is bumped.
func test_fake_v0_to_v1_step_runs() -> void:
	var steps := _no_steps()
	steps[0] = func(data: Dictionary) -> Dictionary:
		data["day"] = data.get("old_day", 0)
		data.erase("old_day")
		return data
	var result := SaveMigrator.migrate_with_steps({"format_version": 0, "old_day": 12}, steps, 1)
	assert_bool(result.is_ok).is_true()
	assert_dict(result.value).is_equal({"format_version": 1, "day": 12})


## Steps run one per version, in ascending order, starting from the saved version.
func test_steps_run_in_version_order() -> void:
	var from_zero := SaveMigrator.migrate_with_steps({"format_version": 0}, _logging_steps(), 3)
	assert_bool(from_zero.is_ok).is_true()
	assert_dict(from_zero.value).is_equal({"format_version": 3, "log": [0, 1, 2]})
	var from_one := SaveMigrator.migrate_with_steps({"format_version": 1}, _logging_steps(), 3)
	assert_dict(from_one.value).is_equal({"format_version": 3, "log": [1, 2]})


## Migrating never modifies the caller's dictionary.
func test_input_is_not_modified() -> void:
	var data := {"format_version": 0, "nested": {"x": 1}}
	var steps := _no_steps()
	steps[0] = func(migrating: Dictionary) -> Dictionary:
		var nested: Dictionary = migrating["nested"]
		nested["x"] = 2
		return migrating
	SaveMigrator.migrate_with_steps(data, steps, 1)
	assert_dict(data).is_equal({"format_version": 0, "nested": {"x": 1}})


## A save from a newer game fails with &"newer_format_version".
func test_newer_version_fails() -> void:
	var result := SaveMigrator.migrate({"format_version": SaveMigrator.TARGET_VERSION + 1})
	assert_bool(result.is_ok).is_false()
	assert_str(result.error_code).is_equal(&"newer_format_version")


## Missing, non-numeric, fractional or negative versions fail with &"bad_format_version".
func test_bad_versions_fail() -> void:
	var bad_values: Array = [null, "1", 1.5, -1, [1], true, 1e20, INF, NAN]
	for bad: Variant in bad_values:
		var data := {"format_version": bad}
		if bad == null:
			data.erase("format_version")
		var result := SaveMigrator.migrate(data)
		assert_bool(result.is_ok).override_failure_message(str(bad)).is_false()
		assert_str(result.error_code).override_failure_message(str(bad)).is_equal(
			&"bad_format_version"
		)


## An old version with no step to bring it forward fails with &"missing_migration_step".
func test_missing_step_fails() -> void:
	var result := SaveMigrator.migrate({"format_version": 0})
	assert_bool(result.is_ok).is_false()
	assert_str(result.error_code).is_equal(&"missing_migration_step")


## A step that returns something other than a Dictionary fails with &"migration_failed".
func test_step_returning_no_data_fails() -> void:
	var steps := _no_steps()
	steps[0] = func(_data: Dictionary) -> Variant: return null
	var result := SaveMigrator.migrate_with_steps({"format_version": 0}, steps, 1)
	assert_bool(result.is_ok).is_false()
	assert_str(result.error_code).is_equal(&"migration_failed")


## Writes a v1 save file (clock "is_paused" = [param paused]) into a fresh temporary
## folder and loads it with a SaveService.
func _load_v1_file(paused: bool) -> Result:
	var service: SaveServiceScript = SaveServiceScript.new()
	var dir := "user://test_migrator_%d_%d" % [Time.get_ticks_usec(), get_instance_id()]
	service.saves_dir = dir
	var state_data := GameState.new_game(99).to_dict()
	state_data["clock"] = {"tick": 3, "speed_index": 2, "is_paused": paused}
	var data := {
		"format_version": 1,
		"game_version": SaveServiceScript.game_version(),
		"saved_at_unix": 1700000000,
		"tick": 3,
		"state": state_data,
	}
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join("old.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	var result: Result = service.load_game(&"old")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(dir)
	service.free()
	return result


## A v1 save file loads through the SaveService and migrator into the matching mode.
func test_v1_save_file_loads_into_mode() -> void:
	var cases: Array[Array] = [[true, ClockState.Mode.PAUSED], [false, ClockState.Mode.RUNNING]]
	for case: Array in cases:
		var paused: bool = case[0]
		var result := _load_v1_file(paused)
		assert_bool(result.is_ok).override_failure_message(str(result.detail)).is_true()
		var loaded: GameState = result.value
		assert_int(loaded.clock.mode).is_equal(case[1])
		assert_bool(loaded.clock.is_paused).is_equal(paused)
		assert_array(loaded.clock.holds).is_empty()
		assert_int(loaded.clock.mode_after_hold).is_equal(ClockState.Mode.PAUSED)
		assert_int(loaded.clock.tick).is_equal(3)
		assert_int(loaded.clock.speed_index).is_equal(2)
