## Tests for the v8 -> v9 SaveMigrator step: "worlds" gains "horizon_records" (every world
## locked in v8) and the pole camera, in; everything else is kept. A real v8 save file written by
## the v8 SaveService (tests/services/fixtures/save_v8.json: seed 20261024, bank installed, SILL
## dialed and locked with the wormhole still open, its first-lock documents delivered) loads with
## SILL's horizon record taken, so its documents never come twice.
## Bible: technical-architecture.md#save-system (Migrations),
## game-design.md#base-building-and-power (the pole camera, horizon record)
extends GdUnitTestSuite

const SaveServiceScript := preload("res://src/services/save_service.gd")
const V8_FIXTURE: String = "res://tests/services/fixtures/save_v8.json"


func _v8_fixture() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(V8_FIXTURE))


## The fixture really is a v8 file with SILL locked, the wormhole open and no pole camera.
func test_fixture_is_v8() -> void:
	var data := _v8_fixture()
	assert_float(data["format_version"]).is_equal(8.0)
	var state: Dictionary = data["state"]
	var gate: Dictionary = state["gate"]
	assert_str(gate["mode"]).is_equal("locked")
	assert_str(gate["connected_world_id"]).is_equal("world_sill")
	var worlds: Dictionary = state["worlds"]
	assert_bool(worlds.has("consoles_read")).is_true()
	assert_bool(worlds.has("horizon_records")).is_false()
	assert_bool(worlds.has("pole_camera_world_id")).is_false()


## v8 -> v9 marks each locked world's horizon record taken, puts the camera in, keeps every
## other value, and the result is valid.
func test_v8_marks_locked_worlds_taken() -> void:
	var data := _v8_fixture()
	var result := SaveMigrator.migrate(data)
	assert_bool(result.is_ok).is_true()
	var migrated: Dictionary = result.value
	assert_int(migrated["format_version"]).is_equal(SaveMigrator.TARGET_VERSION)
	var v8_state: Dictionary = data["state"]
	var expected := v8_state.duplicate(true)
	var worlds: Dictionary = expected["worlds"]
	worlds["horizon_records"] = {"world_sill": true}
	worlds["pole_camera_world_id"] = ""
	worlds["pole_camera_ticks_left"] = 0
	expected["operations_log"] = {"entries": []}
	assert_dict(migrated["state"]).is_equal(expected)
	var migrated_state: Dictionary = migrated["state"]
	assert_array(GameState.validate_dict(migrated_state)).is_empty()


## No locked world gives no records; data with no state, no worlds object or unreadable
## statuses passes through for validation to reject.
func test_v8_edge_cases() -> void:
	var empty := SaveMigrator.migrate({"format_version": 8, "state": {"worlds": {"statuses": {}}}})
	var empty_state: Dictionary = empty.value["state"]
	assert_dict(empty_state["worlds"]["horizon_records"]).is_empty()
	var no_state := SaveMigrator.migrate({"format_version": 8, "state": 5})
	assert_dict(no_state.value).is_equal(
		{"format_version": SaveMigrator.TARGET_VERSION, "state": 5}
	)
	var no_worlds := SaveMigrator.migrate(
		{"format_version": 8, "state": {"worlds": 3, "operations_log": {"entries": []}}}
	)
	assert_dict(no_worlds.value).is_equal(
		{
			"format_version": SaveMigrator.TARGET_VERSION,
			"state": {"worlds": 3, "operations_log": {"entries": []}}
		}
	)
	var bad := SaveMigrator.migrate({"format_version": 8, "state": {"worlds": {"statuses": 1}}})
	var bad_state: Dictionary = bad.value["state"]
	assert_dict(bad_state["worlds"]["horizon_records"]).is_empty()


## The real v8 file loads through the SaveService with every other section intact and SILL's
## horizon record taken.
func test_v8_save_file_loads_into_v9() -> void:
	var loaded: GameState = _load_fixture()
	var v8_state: Dictionary = _v8_fixture()["state"]
	var expected: Dictionary = GameState.from_dict(v8_state).to_dict()
	for key: String in ["clock", "random", "flags", "gate", "power", "archive", "address_book"]:
		assert_dict(loaded.to_dict()[key]).override_failure_message(key).is_equal(expected[key])
	assert_bool(loaded.worlds.is_horizon_record_taken(&"world_sill")).is_true()
	assert_bool(loaded.worlds.is_pole_camera_out()).is_false()


## After loading the v8 file, the open wormhole to SILL refuses the pole camera with
## already_taken, and running on delivers nothing: SILL's documents never come twice.
func test_v8_save_never_redelivers() -> void:
	var loaded: GameState = _load_fixture()
	var received: Array[StringName] = loaded.archive.received.duplicate()
	var built: Result = GameSetup.build(loaded, GameDefs.from_registry(Registry))
	assert_bool(built.is_ok).is_true()
	var simulation: Simulation = built.value
	var result: CommandResult = simulation.submit(ExtendPoleCameraCommand.new())
	assert_str(result.error_code).is_equal(&"already_taken")
	for _tick: int in 10:
		simulation.advance_tick()
	assert_array(loaded.archive.received).is_equal(received)


## Loads the fixture through a SaveService with a temporary saves_dir.
func _load_fixture() -> GameState:
	var service: SaveServiceScript = SaveServiceScript.new()
	var dir := "user://test_migrator_v8_%d_%d" % [Time.get_ticks_usec(), get_instance_id()]
	service.saves_dir = dir
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join("old_v8.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(FileAccess.get_file_as_string(V8_FIXTURE))
	file.close()
	var result: Result = service.load_game(&"old_v8")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(dir)
	service.free()
	assert_bool(result.is_ok).override_failure_message(str(result.detail)).is_true()
	return result.value
