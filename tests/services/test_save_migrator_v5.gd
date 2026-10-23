## Tests for the v4 -> v5 SaveMigrator step: it drops the "intel" and "workbench" sections and
## the Ring's "dial_queue" and keeps everything else; and a real v4 save file written by the
## v4 SaveService (tests/services/fixtures/save_v4.json: ten clues, a note, a five-constraint
## draft, a queued address and three Dial Log entries) loads with its gate, power, worlds and
## clock intact.
## Bible: technical-architecture.md#save-system (Migrations)
extends GdUnitTestSuite

const SaveServiceScript := preload("res://src/services/save_service.gd")
const V4_FIXTURE: String = "res://tests/services/fixtures/save_v4.json"


func _v4_fixture() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(V4_FIXTURE))


## The v4 state of the fixture without what v4 -> v5 drops, plus the empty sections v5 -> v6
## adds.
func _expected_v6_state() -> Dictionary:
	var v4_state: Dictionary = _v4_fixture()["state"]
	var expected := v4_state.duplicate(true)
	expected.erase("intel")
	expected.erase("workbench")
	var gate: Dictionary = expected["gate"]
	gate.erase("dial_queue")
	expected["archive"] = {"received": [], "read": {}, "received_tick": {}}
	expected["address_book"] = {"entries": []}
	return expected


## The fixture really is a v4 file with clues, a draft and a queued address.
func test_fixture_is_v4() -> void:
	var data := _v4_fixture()
	assert_float(data["format_version"]).is_equal(4.0)
	var state: Dictionary = data["state"]
	var intel: Dictionary = state["intel"]
	var clues: Array = intel["clues"]
	assert_bool(clues.is_empty()).is_false()
	var workbench: Dictionary = state["workbench"]
	var constraints: Array = workbench["constraints"]
	assert_bool(constraints.is_empty()).is_false()
	var gate: Dictionary = state["gate"]
	var queue: Array = gate["dial_queue"]
	assert_bool(queue.is_empty()).is_false()


## v4 -> v5 drops intel, the Workbench and the dial queue, keeps every other section as it
## is, and after v5 -> v6 the result is a valid state.
func test_v4_drops_intel_workbench_and_queue() -> void:
	var result := SaveMigrator.migrate(_v4_fixture())
	assert_bool(result.is_ok).is_true()
	var migrated: Dictionary = result.value
	assert_int(migrated["format_version"]).is_equal(6)
	assert_dict(migrated["state"]).is_equal(_expected_v6_state())
	var migrated_state: Dictionary = migrated["state"]
	assert_array(GameState.validate_dict(migrated_state)).is_empty()


## v4 data with no state object, or a gate that is not an object, passes through for
## validation to reject.
func test_v4_without_state_or_gate_is_left_for_validation() -> void:
	var no_state := SaveMigrator.migrate({"format_version": 4, "state": 5})
	assert_dict(no_state.value).is_equal({"format_version": 6, "state": 5})
	var bad_gate := SaveMigrator.migrate({"format_version": 4, "state": {"gate": 3, "intel": {}}})
	var empty_sections := {
		"gate": 3,
		"archive": {"received": [], "read": {}, "received_tick": {}},
		"address_book": {"entries": []},
	}
	assert_dict(bad_gate.value).is_equal({"format_version": 6, "state": empty_sections})


## The real v4 file loads through the SaveService with its gate, power, worlds and clock
## intact, and the loaded state sets up against the real content.
func test_v4_save_file_loads_into_v5() -> void:
	var service: SaveServiceScript = SaveServiceScript.new()
	var dir := "user://test_migrator_v4_%d_%d" % [Time.get_ticks_usec(), get_instance_id()]
	service.saves_dir = dir
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join("old_v4.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(FileAccess.get_file_as_string(V4_FIXTURE))
	file.close()
	var result: Result = service.load_game(&"old_v4")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(dir)
	service.free()
	assert_bool(result.is_ok).override_failure_message(str(result.detail)).is_true()
	var loaded: GameState = result.value
	var expected: Dictionary = GameState.from_dict(_expected_v6_state()).to_dict()
	for key: String in ["clock", "random", "flags", "gate", "power", "worlds"]:
		assert_dict(loaded.to_dict()[key]).override_failure_message(key).is_equal(expected[key])
	assert_int(loaded.clock.tick).is_equal(1548)
	assert_array(loaded.gate.dial_log).has_size(3)
	assert_int(loaded.gate.mode).is_equal(GateState.RingMode.IDLE)
	assert_bool(GameSetup.build(loaded, GameDefs.from_registry(Registry)).is_ok).is_true()
