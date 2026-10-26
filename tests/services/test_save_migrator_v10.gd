## Tests for the v9 -> v10 SaveMigrator step: the "operations_log" section is added, empty.
## A real v9 save file written by the v9 SaveService (tests/services/fixtures/save_v9.json: seed
## 20261026, bank installed, SILL dialed and locked, its horizon record taken and documents
## delivered, its console read, the wormhole closed) loads with every other section intact and
## an empty log that the next event fills.
## Bible: technical-architecture.md#save-system (Migrations),
## game-design.md#core-loop (Archive: the operations log)
extends GdUnitTestSuite

const SaveServiceScript := preload("res://src/services/save_service.gd")
const V9_FIXTURE: String = "res://tests/services/fixtures/save_v9.json"


func _v9_fixture() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(V9_FIXTURE))


## The fixture really is a v9 file with SILL's records and no operations log.
func test_fixture_is_v9() -> void:
	var data := _v9_fixture()
	assert_float(data["format_version"]).is_equal(9.0)
	var state: Dictionary = data["state"]
	assert_bool(state.has("operations_log")).is_false()
	var worlds: Dictionary = state["worlds"]
	assert_dict(worlds["horizon_records"]).is_equal({"world_sill": true})
	assert_dict(worlds["consoles_read"]).is_equal({"world_sill": true})


## v9 -> v10 adds an empty log, keeps every other value, and the result is valid.
func test_v9_adds_an_empty_log() -> void:
	var data := _v9_fixture()
	var result := SaveMigrator.migrate(data)
	assert_bool(result.is_ok).is_true()
	var migrated: Dictionary = result.value
	assert_int(migrated["format_version"]).is_equal(10)
	var v9_state: Dictionary = data["state"]
	var expected := v9_state.duplicate(true)
	expected["operations_log"] = {"entries": []}
	assert_dict(migrated["state"]).is_equal(expected)
	var migrated_state: Dictionary = migrated["state"]
	assert_array(GameState.validate_dict(migrated_state)).is_empty()


## Data with no state object passes through for validation to reject.
func test_v9_without_state_is_left_for_validation() -> void:
	var no_state := SaveMigrator.migrate({"format_version": 9, "state": 5})
	assert_dict(no_state.value).is_equal({"format_version": 10, "state": 5})


## The real v9 file loads with every other section intact; the log starts empty and the next
## event (a document arriving) is its first entry.
func test_v9_save_file_loads_with_an_empty_log() -> void:
	var loaded: GameState = _load_fixture()
	var v9_state: Dictionary = _v9_fixture()["state"]
	var expected: Dictionary = GameState.from_dict(v9_state).to_dict()
	var keys: Array[String] = ["clock", "random", "flags", "gate", "power", "worlds", "archive"]
	keys.append("address_book")
	for key: String in keys:
		assert_dict(loaded.to_dict()[key]).override_failure_message(key).is_equal(expected[key])
	assert_array(loaded.operations_log.entries).is_empty()
	var built: Result = GameSetup.build(loaded, GameDefs.from_registry(Registry))
	assert_bool(built.is_ok).is_true()
	var simulation: Simulation = built.value
	var command := DeliverDocumentCommand.create(&"doc_lintel_dossier")
	assert_bool(simulation.submit(command).is_ok).is_true()
	assert_int(loaded.operations_log.entries.size()).is_equal(1)
	assert_str(String(loaded.operations_log.entries[0].kind)).is_equal("document")
	assert_int(loaded.operations_log.entries[0].tick).is_equal(loaded.clock.tick)


## Loads the fixture through a SaveService with a temporary saves_dir.
func _load_fixture() -> GameState:
	var service: SaveServiceScript = SaveServiceScript.new()
	var dir := "user://test_migrator_v9_%d_%d" % [Time.get_ticks_usec(), get_instance_id()]
	service.saves_dir = dir
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join("old_v9.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(FileAccess.get_file_as_string(V9_FIXTURE))
	file.close()
	var result: Result = service.load_game(&"old_v9")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(dir)
	service.free()
	assert_bool(result.is_ok).override_failure_message(str(result.detail)).is_true()
	return result.value
