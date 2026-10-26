## Tests for the v5 -> v6 SaveMigrator step: it adds the empty "archive" and "address_book"
## sections and keeps everything else; and a real v5 save file written by the v5 SaveService
## (tests/services/fixtures/save_v5.json: three dials, one lock) loads with its other sections
## intact and an empty Archive and Address Book.
## Bible: technical-architecture.md#save-system (Migrations)
extends GdUnitTestSuite

const SaveServiceScript := preload("res://src/services/save_service.gd")
const V5_FIXTURE: String = "res://tests/services/fixtures/save_v5.json"
const EMPTY_ARCHIVE: Dictionary = {"received": [], "read": {}, "received_tick": {}}
const EMPTY_BOOK: Dictionary = {"entries": []}


func _v5_fixture() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(V5_FIXTURE))


## The fixture really is a v5 file with Dial Log entries and no v6 sections.
func test_fixture_is_v5() -> void:
	var data := _v5_fixture()
	assert_float(data["format_version"]).is_equal(5.0)
	var state: Dictionary = data["state"]
	assert_bool(state.has("archive")).is_false()
	assert_bool(state.has("address_book")).is_false()
	var gate: Dictionary = state["gate"]
	var dial_log: Array = gate["dial_log"]
	assert_int(dial_log.size()).is_equal(3)


## v5 -> v6 adds the two empty sections and leaves every v5 section untouched (v6 -> v7 then
## adds the bank count: the v5 bank of 100 000 MWh is one installed bank), and the result is a
## valid state.
func test_v5_adds_archive_and_address_book() -> void:
	var data := _v5_fixture()
	var result := SaveMigrator.migrate(data)
	assert_bool(result.is_ok).is_true()
	var migrated: Dictionary = result.value
	assert_int(migrated["format_version"]).is_equal(SaveMigrator.TARGET_VERSION)
	var v5_state: Dictionary = data["state"]
	var expected := v5_state.duplicate(true)
	expected["archive"] = EMPTY_ARCHIVE
	expected["address_book"] = EMPTY_BOOK
	var power: Dictionary = expected["power"]
	power["banks_installed"] = 1
	power["install_ticks_left"] = 0
	var worlds: Dictionary = expected["worlds"]
	worlds["consoles_read"] = {}
	_add_v9_worlds(worlds)
	expected["operations_log"] = {"entries": []}
	assert_dict(migrated["state"]).is_equal(expected)
	var migrated_state: Dictionary = migrated["state"]
	assert_array(GameState.validate_dict(migrated_state)).is_empty()


## v5 data with no state object passes through the step untouched.
func test_v5_without_state_is_left_for_validation() -> void:
	var result := SaveMigrator.migrate({"format_version": 5, "state": 5})
	assert_dict(result.value).is_equal({"format_version": SaveMigrator.TARGET_VERSION, "state": 5})


## The real v5 file loads through the SaveService with its other sections intact (its bank
## counted as installed by v6 -> v7, its locked worlds' horizon records taken by v8 -> v9) and
## empty new ones, and sets up against the real content.
func test_v5_save_file_loads_into_v6() -> void:
	var service: SaveServiceScript = SaveServiceScript.new()
	var dir := "user://test_migrator_v5_%d_%d" % [Time.get_ticks_usec(), get_instance_id()]
	service.saves_dir = dir
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join("old_v5.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(FileAccess.get_file_as_string(V5_FIXTURE))
	file.close()
	var result: Result = service.load_game(&"old_v5")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(dir)
	service.free()
	assert_bool(result.is_ok).override_failure_message(str(result.detail)).is_true()
	var loaded: GameState = result.value
	var v5_state: Dictionary = _v5_fixture()["state"]
	var expected_state: GameState = GameState.from_dict(v5_state)
	expected_state.power.banks_installed = 1
	for world_id: StringName in expected_state.worlds.statuses:
		expected_state.worlds.horizon_records[world_id] = true
	var expected: Dictionary = expected_state.to_dict()
	for key: String in ["clock", "random", "flags", "gate", "power", "worlds"]:
		assert_dict(loaded.to_dict()[key]).override_failure_message(key).is_equal(expected[key])
	assert_array(loaded.gate.dial_log).has_size(3)
	assert_array(loaded.archive.received).is_empty()
	assert_array(loaded.address_book.entries).is_empty()
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
