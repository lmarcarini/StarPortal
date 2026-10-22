## Tests for SaveService with the intel and Workbench sections: two clues of different kinds
## with constraints and text arguments, two notes with links and tags and a five-constraint
## draft save and load identically, and hand-edited data fails cleanly. Each test uses its
## own instance pointed at a unique temporary user:// folder.
## Bible: technical-architecture.md#save-system (round-trip test),
## technical-architecture.md#data-model
extends GdUnitTestSuite

const SaveServiceScript := preload("res://src/services/save_service.gd")
const Fixture := preload("res://tests/core/intel_fixture.gd")

var _service: SaveServiceScript


func before_test() -> void:
	_service = SaveServiceScript.new()
	_service.saves_dir = (
		"user://test_saves_intel_%d_%d" % [Time.get_ticks_usec(), get_instance_id()]
	)


func after_test() -> void:
	var dir := DirAccess.open(_service.saves_dir)
	if dir != null:
		for file_name: String in dir.get_files():
			DirAccess.remove_absolute(_service.saves_dir.path_join(file_name))
		DirAccess.remove_absolute(_service.saves_dir)
	_service.free()


## Save then load reproduces the state's to_dict() exactly, with typed values restored.
func test_round_trip_is_identical() -> void:
	var state := Fixture.state()
	var original := state.to_dict()
	assert_bool(_service.save_game(state, &"intel_round_trip").is_ok).is_true()
	var result: Result = _service.load_game(&"intel_round_trip")
	assert_bool(result.is_ok).override_failure_message(str(result.detail)).is_true()
	var loaded: GameState = result.value
	assert_dict(loaded.to_dict()).is_equal(original)
	assert_array(loaded.intel.clues).has_size(2)
	assert_int(loaded.intel.clues[0].kind).is_equal(ClueRecord.Kind.FRAGMENT)
	assert_int(loaded.intel.clues[1].kind).is_equal(ClueRecord.Kind.SKY_CHART)
	assert_dict(loaded.intel.clues[0].text_args).is_equal(Fixture.fragment().text_args)
	var chart := Fixture.sky_chart().constraints[0]
	assert_bool(loaded.intel.clues[1].constraints[0].equals(chart)).is_true()
	var fragment_note := loaded.intel.note_for(Fixture.FRAGMENT_ID)
	assert_array(fragment_note.links).is_equal([Fixture.SKY_CHART_ID])
	assert_array(fragment_note.tags).is_equal(["P3X-118", "Heron?"])
	assert_that(fragment_note.board_position).is_equal(Vector2i(120, 3400))
	assert_array(loaded.intel.note_for(Fixture.SKY_CHART_ID).tags).is_equal(["ÁGUA"])
	assert_int(loaded.intel.scheduled_dossiers[&"world_abydos"]).is_equal(5000)
	assert_int(loaded.workbench.origin_glyph).is_equal(30)
	assert_array(loaded.workbench.constraints).has_size(5)


## The file stores kinds as lowercase names and positions as [x, y] arrays.
func test_file_shape() -> void:
	_service.save_game(Fixture.state(), &"shape")
	var data: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(_service.slot_path(&"shape"))
	)
	var intel: Dictionary = data["state"]["intel"]
	assert_str(intel["clues"][1]["kind"]).is_equal("sky_chart")
	assert_array(intel["notes"]["clue_0001"]["board_position"]).is_equal([120.0, 3400.0])
	assert_float(data["format_version"]).is_equal(4.0)


## Hand-edited intel and Workbench data fails with &"invalid_state".
func test_hand_edited_sections_are_invalid_state() -> void:
	_service.save_game(Fixture.state(), &"edited")
	var good: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(_service.slot_path(&"edited"))
	)
	var cases: Array[Array] = [
		[["intel", "clues", 0, "kind"], "cipher", "intel: clue 0: 'kind'"],
		[["intel", "clues", 1, "id"], "clue_0001", "repeats id"],
		[["intel", "clues", 0, "grade"], 5, "'grade'"],
		[["intel", "notes", "clue_0001", "links"], ["clue_0001"], "links to itself"],
		[["intel", "notes", "clue_0001", "tags"], ["a\u0007"], "control character"],
		[["intel", "notes", "clue_0001", "board_position"], [0, 4001], "'board_position'"],
		[["intel", "next_clue_number"], 0, "'next_clue_number'"],
		[["workbench", "origin_glyph"], 36, "workbench: 'origin_glyph'"],
		[["workbench", "constraints", 0, "seal"], 8, "workbench: constraint 0"],
	]
	for case: Array in cases:
		var data := good.duplicate(true)
		var path: Array = case[0]
		_set_path(data["state"], path, case[1])
		var file := FileAccess.open(_service.slot_path(&"edited"), FileAccess.WRITE)
		file.store_string(JSON.stringify(data))
		file.close()
		var result: Result = _service.load_game(&"edited")
		assert_str(result.error_code).override_failure_message(str(case)).is_equal(&"invalid_state")
		assert_str(result.detail).override_failure_message(str(case)).contains(str(case[2]))


## Sets the value at [param path] (keys and indices) inside [param root].
func _set_path(root: Variant, path: Array, value: Variant) -> void:
	var node: Variant = root
	for step: int in path.size() - 1:
		node = node[path[step]]
	node[path[path.size() - 1]] = value
