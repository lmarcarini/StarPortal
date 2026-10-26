## Tests for the v7 -> v8 SaveMigrator step: "worlds" gains an empty "consoles_read" and
## everything else is kept; and a real v7 save file written by the v7 SaveService
## (tests/services/fixtures/save_v7.json: seed 20261024, bank installed, its cheapest open world
## dialed and the wormhole still open, a note) loads with no console read, and the open
## wormhole's console can then be read.
## Bible: technical-architecture.md#save-system (Migrations),
## gate-and-address-spec.md#where-addresses-come-from (Ring consoles)
extends GdUnitTestSuite

const SaveServiceScript := preload("res://src/services/save_service.gd")
const V7_FIXTURE: String = "res://tests/services/fixtures/save_v7.json"


func _v7_fixture() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(V7_FIXTURE))


## The fixture really is a v7 file with an open wormhole and no consoles_read.
func test_fixture_is_v7() -> void:
	var data := _v7_fixture()
	assert_float(data["format_version"]).is_equal(7.0)
	var state: Dictionary = data["state"]
	var power: Dictionary = state["power"]
	assert_bool(power.has("banks_installed")).is_true()
	var gate: Dictionary = state["gate"]
	assert_str(gate["mode"]).is_equal("locked")
	var worlds: Dictionary = state["worlds"]
	assert_bool(worlds.has("consoles_read")).is_false()


## v7 -> v8 adds an empty consoles_read, keeps every other value, and the result is valid.
func test_v7_adds_empty_consoles_read() -> void:
	var data := _v7_fixture()
	var result := SaveMigrator.migrate(data)
	assert_bool(result.is_ok).is_true()
	var migrated: Dictionary = result.value
	assert_int(migrated["format_version"]).is_equal(9)
	var v7_state: Dictionary = data["state"]
	var expected := v7_state.duplicate(true)
	var worlds: Dictionary = expected["worlds"]
	worlds["consoles_read"] = {}
	_add_v9_worlds(worlds)
	assert_dict(migrated["state"]).is_equal(expected)
	var migrated_state: Dictionary = migrated["state"]
	assert_array(GameState.validate_dict(migrated_state)).is_empty()


## Data with no state, or no worlds object, passes through for validation to reject.
func test_v7_without_state_or_worlds_is_left_for_validation() -> void:
	var no_state := SaveMigrator.migrate({"format_version": 7, "state": 5})
	assert_dict(no_state.value).is_equal({"format_version": 9, "state": 5})
	var no_worlds := SaveMigrator.migrate({"format_version": 7, "state": {"worlds": 3}})
	assert_dict(no_worlds.value).is_equal({"format_version": 9, "state": {"worlds": 3}})


## The real v7 file loads through the SaveService with every section intact and no console
## read; it sets up against the real content and the open wormhole's console can be read.
func test_v7_save_file_loads_into_v8() -> void:
	var service: SaveServiceScript = SaveServiceScript.new()
	var dir := "user://test_migrator_v7_%d_%d" % [Time.get_ticks_usec(), get_instance_id()]
	service.saves_dir = dir
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join("old_v7.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(FileAccess.get_file_as_string(V7_FIXTURE))
	file.close()
	var result: Result = service.load_game(&"old_v7")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(dir)
	service.free()
	assert_bool(result.is_ok).override_failure_message(str(result.detail)).is_true()
	var loaded: GameState = result.value
	var v7_state: Dictionary = _v7_fixture()["state"]
	var expected: Dictionary = GameState.from_dict(v7_state).to_dict()
	for key: String in ["clock", "random", "flags", "gate", "power", "archive", "address_book"]:
		assert_dict(loaded.to_dict()[key]).override_failure_message(key).is_equal(expected[key])
	assert_dict(loaded.worlds.consoles_read).is_empty()
	var built: Result = GameSetup.build(loaded, GameDefs.from_registry(Registry))
	assert_bool(built.is_ok).is_true()
	var simulation: Simulation = built.value
	assert_bool(simulation.submit(ReadConsoleCommand.new()).is_ok).is_true()
	assert_int(loaded.address_book.entries.size()).is_greater(1)


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
