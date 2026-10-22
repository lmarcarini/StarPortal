## Tests for the SaveService: JSON files, atomic writes, slot names, load failures,
## exact round trips including RNG streams, autosave rotation and EventBus signals.
## Each test uses its own instance pointed at a unique temporary user:// folder, never
## user://saves.
## Bible: technical-architecture.md#save-system
extends GdUnitTestSuite

const SaveServiceScript := preload("res://src/services/save_service.gd")
## 2^53 + 1: the smallest positive integer a JSON number (double) cannot hold exactly.
const ABOVE_2_POW_53: int = 9007199254740993
## Marks a key to remove in _load_with_state_edit().
const ERASE: String = "<erase>"

var _service: SaveServiceScript
var _saved: Array[StringName] = []
var _loaded: Array[StringName] = []


func before_test() -> void:
	_saved.clear()
	_loaded.clear()
	_service = SaveServiceScript.new()
	_service.saves_dir = "user://test_saves_%d_%d" % [Time.get_ticks_usec(), get_instance_id()]
	EventBus.game_saved.connect(_on_game_saved)
	EventBus.game_loaded.connect(_on_game_loaded)


func after_test() -> void:
	EventBus.game_saved.disconnect(_on_game_saved)
	EventBus.game_loaded.disconnect(_on_game_loaded)
	_remove_dir(_service.saves_dir)
	_service.free()


func _on_game_saved(slot: StringName) -> void:
	_saved.append(slot)


func _on_game_loaded(slot: StringName) -> void:
	_loaded.append(slot)


func _remove_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		DirAccess.remove_absolute(path.path_join(file_name))
	DirAccess.remove_absolute(path)


func _state_at_tick(tick: int) -> GameState:
	var state := GameState.new_game(ABOVE_2_POW_53)
	state.clock.tick = tick
	return state


func _write_text(slot: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(_service.saves_dir)
	var file := FileAccess.open(_service.saves_dir.path_join(slot), FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _read_json(slot: StringName) -> Dictionary:
	var text := FileAccess.get_file_as_string(_service.slot_path(slot))
	var parsed: Variant = JSON.parse_string(text)
	assert_bool(parsed is Dictionary).is_true()
	if not parsed is Dictionary:
		return {}
	return parsed


func _files() -> PackedStringArray:
	var dir := DirAccess.open(_service.saves_dir)
	if dir == null:
		return PackedStringArray()
	return dir.get_files()


## Asserts that the "state" object saved in [param slot] passes GameState.validate_dict.
func _assert_saved_state_valid(slot: StringName) -> void:
	var saved_state: Dictionary = _read_json(slot)["state"]
	assert_array(GameState.validate_dict(saved_state)).is_empty()


func _draw(rng: RandomNumberGenerator, count: int) -> Array[int]:
	var values: Array[int] = []
	for i: int in count:
		values.append(rng.randi())
	return values


func _assert_load_fails(slot: StringName, code: StringName) -> void:
	var result: Result = _service.load_game(slot)
	assert_bool(result.is_ok).override_failure_message(String(slot)).is_false()
	assert_str(result.error_code).override_failure_message(String(slot)).is_equal(code)


## Save then load reproduces the state exactly, and the RNG streams continue with the same
## values they would have drawn without the save. The saved state passes validate_dict.
func test_round_trip_preserves_state_and_rng_streams() -> void:
	var state := _state_at_tick(12345)
	state.flags[&"met_the_general"] = true
	state.flags[&"glyphs_found"] = 4
	state.flags[&"codename"] = "CAIRN"
	_draw(state.random.stream(&"expedition"), 5)
	_draw(state.random.stream(&"research"), 3)
	var original := state.to_dict()
	assert_bool(_service.save_game(state, &"round_trip").is_ok).is_true()
	_assert_saved_state_valid(&"round_trip")
	var expected_expedition := _draw(state.random.stream(&"expedition"), 10)
	var expected_research := _draw(state.random.stream(&"research"), 10)

	var result: Result = _service.load_game(&"round_trip")
	assert_bool(result.is_ok).is_true()
	var loaded: GameState = result.value
	assert_dict(loaded.to_dict()).is_equal(original)
	assert_array(_draw(loaded.random.stream(&"expedition"), 10)).is_equal(expected_expedition)
	assert_array(_draw(loaded.random.stream(&"research"), 10)).is_equal(expected_research)


## The file is plain JSON text with the documented header, named <slot>.json. The game
## version is application/config/version, or "0.0.0" when that is not set.
func test_file_is_json_with_header() -> void:
	assert_bool(_service.save_game(_state_at_tick(42), &"slot_1").is_ok).is_true()
	assert_array(_files()).contains_exactly(["slot_1.json"])
	var data := _read_json(&"slot_1")
	assert_array(data.keys()).contains_exactly_in_any_order(
		["format_version", "game_version", "saved_at_unix", "tick", "state"]
	)
	assert_float(data["format_version"]).is_equal(float(SaveServiceScript.FORMAT_VERSION))
	assert_str(str(data["game_version"])).is_equal(SaveServiceScript.game_version())
	var configured := str(ProjectSettings.get_setting("application/config/version", ""))
	assert_str(SaveServiceScript.game_version()).is_equal(
		configured if not configured.is_empty() else "0.0.0"
	)
	assert_float(data["tick"]).is_equal(42.0)
	var now := Time.get_unix_time_from_system()
	assert_float(data["saved_at_unix"]).is_between(now - 60.0, now + 1.0)
	assert_dict(data["state"]).is_equal(
		JSON.parse_string(JSON.stringify(_state_at_tick(42).to_dict()))
	)


## The service code never uses ResourceLoader or ResourceSaver.
func test_never_uses_resource_loader() -> void:
	for path: String in [
		"res://src/services/save_service.gd", "res://src/services/save_migrator.gd"
	]:
		for line: String in FileAccess.get_file_as_string(path).split("\n"):
			var code := line.get_slice("#", 0)
			assert_str(code).override_failure_message(path).not_contains("ResourceLoader")
			assert_str(code).override_failure_message(path).not_contains("ResourceSaver")


## A save leaves no temporary file behind and overwrites the previous save.
func test_save_overwrites_without_leftover_temp() -> void:
	_service.save_game(_state_at_tick(1), &"slot")
	assert_bool(_service.save_game(_state_at_tick(2), &"slot").is_ok).is_true()
	assert_array(_files()).contains_exactly(["slot.json"])
	var loaded: GameState = _service.load_game(&"slot").value
	assert_int(loaded.clock.tick).is_equal(2)


## An interrupted write (a partial .tmp) leaves the previous save loadable, is hidden from
## list_slots, and is replaced by the next save.
func test_interrupted_write_keeps_previous_save() -> void:
	_service.save_game(_state_at_tick(5), &"slot")
	_write_text("slot.json.tmp", '{"format_version": 1, "tick": 9, "sta')
	var loaded: Result = _service.load_game(&"slot")
	assert_bool(loaded.is_ok).is_true()
	var state: GameState = loaded.value
	assert_int(state.clock.tick).is_equal(5)
	assert_int(_service.list_slots().size()).is_equal(1)
	assert_bool(_service.save_game(_state_at_tick(6), &"slot").is_ok).is_true()
	assert_array(_files()).contains_exactly(["slot.json"])


## Slot names must match [a-z0-9_]{1,32}; anything else (including a trailing newline)
## fails with &"bad_slot_name" for save, load and delete, and nothing is written. Digits,
## underscores and exactly 32 characters are valid.
func test_bad_slot_names_fail() -> void:
	var bad_names: Array[String] = ["", "a".repeat(33), "abc\u0000"]
	bad_names.append_array(
		"Slot|a-b|../up|a/b|x.json|a b|é|abc\n|\nabc|ab\nc|abc |abc\t".split("|")
	)
	for name: String in bad_names:
		var slot := StringName(name)
		assert_bool(SaveServiceScript.is_valid_slot_name(slot)).is_false()
		var save: Result = _service.save_game(_state_at_tick(1), slot)
		assert_str(save.error_code).override_failure_message(String(slot)).is_equal(
			&"bad_slot_name"
		)
		_assert_load_fails(slot, &"bad_slot_name")
		var delete: Result = _service.delete_slot(slot)
		assert_str(delete.error_code).is_equal(&"bad_slot_name")
	assert_array(_files()).is_empty()
	assert_array(_saved).is_empty()
	for slot: StringName in [&"a", &"slot_01", &"9", &"_", StringName("z".repeat(32))]:
		assert_bool(SaveServiceScript.is_valid_slot_name(slot)).is_true()
		assert_bool(_service.save_game(_state_at_tick(1), slot).is_ok).is_true()


## Missing file, corrupt JSON and a newer format fail with distinct codes, without crashing
## and without emitting game_loaded.
func test_load_failures_have_distinct_codes() -> void:
	_assert_load_fails(&"nothing_here", &"missing_file")
	_write_text("corrupt.json", '{"format_version": 1, "tick": ')
	_assert_load_fails(&"corrupt", &"corrupt_json")
	_write_text("not_object.json", "[1, 2, 3]")
	_assert_load_fails(&"not_object", &"corrupt_json")
	_write_text("empty.json", "")
	_assert_load_fails(&"empty", &"corrupt_json")
	_service.save_game(_state_at_tick(1), &"future")
	var data := _read_json(&"future")
	data["format_version"] = SaveServiceScript.FORMAT_VERSION + 1
	_write_text("future.json", JSON.stringify(data))
	_assert_load_fails(&"future", &"newer_format_version")
	assert_array(_loaded).is_empty()


## Hand-edited files with wrong types fail cleanly instead of crashing.
func test_hand_edited_wrong_types_fail() -> void:
	_service.save_game(_state_at_tick(1), &"edited")
	var good := _read_json(&"edited")
	var cases: Array[Array] = [
		["tick", "twelve", &"corrupt_save"],
		["tick", -5, &"corrupt_save"],
		["tick", 1e300, &"corrupt_save"],
		["saved_at_unix", 1.5, &"corrupt_save"],
		["saved_at_unix", -1, &"corrupt_save"],
		["saved_at_unix", 1e300, &"corrupt_save"],
		["game_version", 3, &"corrupt_save"],
		["state", "{}", &"corrupt_save"],
		["format_version", "1", &"bad_format_version"],
		["format_version", 1e20, &"bad_format_version"],
	]
	for edit: Array in cases:
		var data := good.duplicate(true)
		data[edit[0]] = edit[1]
		_write_text("edited.json", JSON.stringify(data))
		var code: StringName = edit[2]
		_assert_load_fails(&"edited", code)
	assert_array(_loaded).is_empty()


## Saves a state with an RNG stream, sets the value at [param path] inside the saved
## "state" object (an empty path replaces the whole state; ERASE removes the key), writes
## it back and loads it.
func _load_with_state_edit(path: Array, value: Variant) -> Result:
	var state := _state_at_tick(7)
	state.random.stream(&"expedition").randi()
	_service.save_game(state, &"edited")
	var data := _read_json(&"edited")
	if path.is_empty():
		data["state"] = value
	else:
		var target: Dictionary = data["state"]
		for key: Variant in path.slice(0, -1):
			target = target[key]
		if value is String and value == ERASE:
			target.erase(path[-1])
		else:
			target[path[-1]] = value
	_write_text("edited.json", JSON.stringify(data))
	return _service.load_game(&"edited")


## Each case is [path, value, text expected in the error detail].
func _assert_invalid_state(cases: Array[Array]) -> void:
	for case: Array in cases:
		var path: Array = case[0]
		var expected: String = case[2]
		var result := _load_with_state_edit(path, case[1])
		var label := str(case)
		assert_bool(result.is_ok).override_failure_message(label).is_false()
		assert_str(result.error_code).override_failure_message(label).is_equal(&"invalid_state")
		assert_str(result.detail).override_failure_message(label).contains(expected)
	assert_array(_loaded).is_empty()


## A string where an int belongs inside the state fails with &"invalid_state".
func test_string_clock_tick_is_invalid_state() -> void:
	_assert_invalid_state([[["clock", "tick"], "x", "tick"]])


## A non-numeric or out-of-range seed string fails with &"invalid_state".
func test_bad_seed_strings_are_invalid_state() -> void:
	_assert_invalid_state(
		[
			[["random", "base_seed"], "abc", "base_seed"],
			[["random", "base_seed"], "99999999999999999999", "base_seed"],
			[["random", "base_seed"], 5, "base_seed"],
			[["random", "streams", "expedition", "state"], "zzz", "expedition"],
		]
	)


## A missing required key fails with &"invalid_state".
func test_missing_required_keys_are_invalid_state() -> void:
	_assert_invalid_state(
		[
			[["clock", "tick"], ERASE, "tick"],
			[["random"], ERASE, "random"],
			[["random", "streams", "expedition", "seed"], ERASE, "seed"],
		]
	)


## An empty or wrongly shaped state object fails with &"invalid_state".
func test_empty_or_misshaped_state_is_invalid_state() -> void:
	_assert_invalid_state(
		[
			[[], {}, "clock"],
			[["clock"], "x", "clock"],
			[["clock", "mode"], 1, "mode"],
			[["clock", "mode"], "frozen", "mode"],
			[["clock", "holds"], [1], "hold"],
			[["clock", "mode_after_hold"], "held", "mode_after_hold"],
			[["clock", "speed_index"], "fast", "speed_index"],
			[["clock", "tick"], -1, "tick"],
			[["flags", "f"], [1], "flag"],
		]
	)


## Autosaves fill the slots one by one, then five autosaves keep exactly three files,
## newest in autosave_1.
func test_autosave_rotates_three_files() -> void:
	for tick: int in range(1, 6):
		assert_bool(_service.autosave(_state_at_tick(tick)).is_ok).is_true()
		assert_int(_files().size()).is_equal(mini(tick, 3))
		_assert_saved_state_valid(&"autosave_1")
	assert_array(_files()).contains_exactly_in_any_order(
		["autosave_1.json", "autosave_2.json", "autosave_3.json"]
	)
	for index: int in range(1, 4):
		var loaded: GameState = _service.load_game(StringName("autosave_%d" % index)).value
		assert_int(loaded.clock.tick).is_equal(6 - index)
	assert_array(_saved).is_equal(
		[&"autosave_1", &"autosave_1", &"autosave_1", &"autosave_1", &"autosave_1"]
	)


## list_slots reports every readable slot, newest first, and skips corrupt files.
func test_list_slots() -> void:
	assert_array(_service.list_slots()).is_empty()
	_service.save_game(_state_at_tick(10), &"b_slot")
	_service.save_game(_state_at_tick(20), &"a_slot")
	_write_text("broken.json", "not json")
	_write_text("Bad-Name.json", "{}")
	var slots: Array[Dictionary] = _service.list_slots()
	assert_int(slots.size()).is_equal(2)
	var now := int(Time.get_unix_time_from_system())
	var by_slot: Dictionary = {}
	for entry: Dictionary in slots:
		assert_array(entry.keys()).contains_exactly_in_any_order(
			["slot", "tick", "saved_at_unix", "format_version"]
		)
		assert_int(entry["format_version"]).is_equal(SaveServiceScript.FORMAT_VERSION)
		assert_int(entry["saved_at_unix"]).is_between(now - 60, now + 1)
		by_slot[entry["slot"]] = entry["tick"]
	assert_dict(by_slot).is_equal({&"a_slot": 20, &"b_slot": 10})


## delete_slot removes the file and its leftover .tmp. Deleting a missing slot fails with
## &"missing_file" and still removes an orphan .tmp.
func test_delete_slot() -> void:
	_service.save_game(_state_at_tick(1), &"doomed")
	_write_text("doomed.json.tmp", "partial")
	assert_bool(_service.delete_slot(&"doomed").is_ok).is_true()
	assert_array(_files()).is_empty()
	_write_text("doomed.json.tmp", "orphan")
	var again: Result = _service.delete_slot(&"doomed")
	assert_str(again.error_code).is_equal(&"missing_file")
	assert_array(_files()).is_empty()


## Successful saves and loads emit game_saved / game_loaded with the slot name.
func test_emits_event_bus_signals() -> void:
	_service.save_game(_state_at_tick(1), &"signals")
	_service.load_game(&"signals")
	assert_array(_saved).is_equal([&"signals"])
	assert_array(_loaded).is_equal([&"signals"])


## A folder that cannot be created fails with &"write_failed" and emits nothing.
func test_unwritable_folder_fails() -> void:
	_write_text("blocker", "a file where a folder should be")
	var real_dir := _service.saves_dir
	_service.saves_dir = real_dir.path_join("blocker")
	var result: Result = _service.save_game(_state_at_tick(1), &"slot")
	_service.saves_dir = real_dir
	assert_bool(result.is_ok).is_false()
	assert_str(result.error_code).is_equal(&"write_failed")
	assert_array(_saved).is_empty()
