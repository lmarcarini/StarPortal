## Tests for SaveMigrator: pass-through at the current version, ordered step functions,
## distinct failures for bad, old (before the M2 clean break), newer and unmigratable versions.
## Bible: technical-architecture.md#save-system
extends GdUnitTestSuite


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


## The target is 29 (M8-01) and also the oldest loadable version (owner: no migration
## before alpha); no built-in steps.
func test_target_version_is_twenty_eight_with_no_steps() -> void:
	assert_int(SaveMigrator.TARGET_VERSION).is_equal(29)
	assert_int(SaveMigrator.OLDEST_VERSION).is_equal(29)
	assert_dict(SaveMigrator.built_in_steps()).is_empty()


## A v25 save is refused cleanly.
func test_v25_save_is_refused() -> void:
	var result: Result = SaveMigrator.migrate({"format_version": 25, "tick": 0, "state": {}})
	assert_str(String(result.error_code)).is_equal("old_format_version")


## Every version before the clean break fails with &"old_format_version".
func test_old_versions_fail() -> void:
	for version: int in SaveMigrator.OLDEST_VERSION:
		var result := SaveMigrator.migrate({"format_version": version, "state": {}})
		assert_str(result.error_code).override_failure_message(str(version)).is_equal(
			&"old_format_version"
		)


## A v14 save (M2.7) is rejected with the earlier-build code.
func test_v14_save_is_rejected() -> void:
	var result := SaveMigrator.migrate({"format_version": 14, "state": {}})
	assert_str(result.error_code).is_equal(&"old_format_version")


## A JSON-parsed version (a float such as 1.0) is accepted.
func test_json_float_version_is_accepted() -> void:
	var parsed: Variant = JSON.parse_string('{"format_version": 29, "tick": 3}')
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


## The version limit is exactly 2^53 (JsonLimits.MAX_EXACT_INT): the float 2^53 reads as
## that int, the next double above it fails with &"bad_format_version".
func test_version_boundary_is_two_pow_53() -> void:
	var limit: float = float(JsonLimits.MAX_EXACT_INT)
	var at_limit := SaveMigrator.read_version({"format_version": limit})
	assert_bool(at_limit.is_ok).is_true()
	assert_int(at_limit.value).is_equal(JsonLimits.MAX_EXACT_INT)
	var above := SaveMigrator.read_version({"format_version": limit + 2.0})
	assert_str(above.error_code).is_equal(&"bad_format_version")


## An old version with no step to bring it forward fails with &"missing_migration_step".
func test_missing_step_fails() -> void:
	var result := SaveMigrator.migrate_with_steps({"format_version": 0}, _no_steps(), 1)
	assert_bool(result.is_ok).is_false()
	assert_str(result.error_code).is_equal(&"missing_migration_step")


## A step that returns something other than a Dictionary fails with &"migration_failed".
func test_step_returning_no_data_fails() -> void:
	var steps := _no_steps()
	steps[0] = func(_data: Dictionary) -> Variant: return null
	var result := SaveMigrator.migrate_with_steps({"format_version": 0}, steps, 1)
	assert_bool(result.is_ok).is_false()
	assert_str(result.error_code).is_equal(&"migration_failed")
