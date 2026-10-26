## Tests for the v6 -> v7 SaveMigrator step: "power" gains "banks_installed" (1 when the v6
## capacity is above 0, else 0) and "install_ticks_left" 0, and everything else is kept; and a
## real v6 save file written by the v6 SaveService (tests/services/fixtures/save_v6.json: a
## new game charged to 400 MWh, one lock dialed, a note, 62.4 MWh left) loads with its old
## charge and one installed bank.
## Bible: technical-architecture.md#save-system (Migrations),
## gate-and-address-spec.md#the-dial-console
extends GdUnitTestSuite

const SaveServiceScript := preload("res://src/services/save_service.gd")
const V6_FIXTURE: String = "res://tests/services/fixtures/save_v6.json"


func _v6_fixture() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(V6_FIXTURE))


## A v6 save whose power section is [param power].
func _v6_with_power(power: Variant) -> Dictionary:
	return {"format_version": 6, "state": {"power": power}}


## The fixture really is a v6 file with a 400 MWh bank, some charge and no bank fields.
func test_fixture_is_v6() -> void:
	var data := _v6_fixture()
	assert_float(data["format_version"]).is_equal(6.0)
	var state: Dictionary = data["state"]
	assert_bool(state.has("archive")).is_true()
	var power: Dictionary = state["power"]
	assert_bool(power.has("banks_installed")).is_false()
	var capacity: String = power["capacity_mwh"]
	var stored: String = power["stored_mwh"]
	assert_float(ExactFloat.decode(capacity)).is_equal(400.0)
	assert_float(ExactFloat.decode(stored)).is_greater(0.0)


## v6 -> v7 adds one installed bank and no install to a bank with capacity, keeps every other
## value, and the result is a valid state.
func test_v6_with_capacity_has_one_bank() -> void:
	var data := _v6_fixture()
	var result := SaveMigrator.migrate(data)
	assert_bool(result.is_ok).is_true()
	var migrated: Dictionary = result.value
	assert_int(migrated["format_version"]).is_equal(9)
	var v6_state: Dictionary = data["state"]
	var expected := v6_state.duplicate(true)
	var power: Dictionary = expected["power"]
	power["banks_installed"] = 1
	power["install_ticks_left"] = 0
	var worlds: Dictionary = expected["worlds"]
	worlds["consoles_read"] = {}
	_add_v9_worlds(worlds)
	assert_dict(migrated["state"]).is_equal(expected)
	var migrated_state: Dictionary = migrated["state"]
	assert_array(GameState.validate_dict(migrated_state)).is_empty()


## A v6 power section with no capacity has no bank installed.
func test_v6_without_capacity_has_no_bank() -> void:
	var power := {
		"stored_mwh": ExactFloat.encode(0.0),
		"capacity_mwh": ExactFloat.encode(0.0),
		"plant_output_mw": ExactFloat.encode(30.0),
	}
	var result := SaveMigrator.migrate(_v6_with_power(power))
	var expected := power.duplicate()
	expected["banks_installed"] = 0
	expected["install_ticks_left"] = 0
	assert_dict(result.value).is_equal({"format_version": 9, "state": {"power": expected}})


## Data with no state, or no power object, passes through for validation to reject; an
## unreadable capacity counts as no bank.
func test_v6_without_state_or_power_is_left_for_validation() -> void:
	var no_state := SaveMigrator.migrate({"format_version": 6, "state": 5})
	assert_dict(no_state.value).is_equal({"format_version": 9, "state": 5})
	var no_power := SaveMigrator.migrate(_v6_with_power(3))
	assert_dict(no_power.value).is_equal({"format_version": 9, "state": {"power": 3}})
	var bad := SaveMigrator.migrate(_v6_with_power({"capacity_mwh": 400.0}))
	var bad_power: Dictionary = bad.value["state"]["power"]
	assert_int(bad_power["banks_installed"]).is_equal(0)


## The real v6 file loads through the SaveService with its old charge and capacity, one bank
## installed and no install running, and sets up against the real content.
func test_v6_save_file_loads_into_v7() -> void:
	var service: SaveServiceScript = SaveServiceScript.new()
	var dir := "user://test_migrator_v6_%d_%d" % [Time.get_ticks_usec(), get_instance_id()]
	service.saves_dir = dir
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join("old_v6.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(FileAccess.get_file_as_string(V6_FIXTURE))
	file.close()
	var result: Result = service.load_game(&"old_v6")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(dir)
	service.free()
	assert_bool(result.is_ok).override_failure_message(str(result.detail)).is_true()
	var loaded: GameState = result.value
	var v6_state: Dictionary = _v6_fixture()["state"]
	var expected: Dictionary = GameState.from_dict(v6_state).to_dict()
	var expected_worlds: Dictionary = expected["worlds"]
	_add_v9_worlds(expected_worlds)
	for key: String in ["clock", "random", "flags", "gate", "worlds", "archive", "address_book"]:
		assert_dict(loaded.to_dict()[key]).override_failure_message(key).is_equal(expected[key])
	var v6_power: Dictionary = v6_state["power"]
	var v6_stored: String = v6_power["stored_mwh"]
	assert_float(loaded.power.stored_mwh).is_equal(ExactFloat.decode(v6_stored))
	assert_float(loaded.power.capacity_mwh).is_equal(400.0)
	assert_int(loaded.power.banks_installed).is_equal(1)
	assert_int(loaded.power.install_ticks_left).is_equal(0)
	assert_bool(GameSetup.build(loaded, GameDefs.from_registry(Registry)).is_ok).is_true()


## Adds what v8 -> v9 gives [param worlds]: a horizon record for each locked world, the pole
## camera in.
func _add_v9_worlds(worlds: Dictionary) -> void:
	var records: Dictionary = {}
	var statuses: Dictionary = worlds["statuses"]
	for world_id: String in statuses:
		if statuses[world_id] == "locked":
			records[world_id] = true
	worlds["horizon_records"] = records
	worlds["pole_camera_world_id"] = ""
	worlds["pole_camera_ticks_left"] = 0
