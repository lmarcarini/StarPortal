## Tests for the SaveService header "tick" check: a file whose header tick differs from
## the state's clock tick fails to load with &"invalid_state" and is skipped by
## list_slots(). Kept apart from test_save_service.gd, which is near the file-size limit.
## Bible: technical-architecture.md#save-system
extends GdUnitTestSuite

const SaveServiceScript := preload("res://src/services/save_service.gd")

var _service: SaveServiceScript
var _loaded: Array[StringName] = []


func before_test() -> void:
	_loaded.clear()
	_service = SaveServiceScript.new()
	_service.saves_dir = "user://test_header_%d_%d" % [Time.get_ticks_usec(), get_instance_id()]
	EventBus.game_loaded.connect(_on_game_loaded)


func after_test() -> void:
	EventBus.game_loaded.disconnect(_on_game_loaded)
	var dir := DirAccess.open(_service.saves_dir)
	if dir != null:
		for file_name: String in dir.get_files():
			DirAccess.remove_absolute(_service.saves_dir.path_join(file_name))
		DirAccess.remove_absolute(_service.saves_dir)
	_service.free()


func _on_game_loaded(slot: StringName) -> void:
	_loaded.append(slot)


## Saves a state at [param tick] to [param slot], then rewrites the file with the header
## "tick" set to [param header_tick] and the clock "tick" to [param clock_tick].
func _save_with_ticks(slot: StringName, header_tick: Variant, clock_tick: Variant) -> void:
	var state := GameState.new_game(1)
	state.clock.tick = 10
	assert_bool(_service.save_game(state, slot).is_ok).is_true()
	var path := _service.slot_path(slot)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	data["tick"] = header_tick
	data["state"]["clock"]["tick"] = clock_tick
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


func _listed_slots() -> Array[StringName]:
	var slots: Array[StringName] = []
	for entry: Dictionary in _service.list_slots():
		slots.append(entry["slot"])
	return slots


## A header tick above or below the clock tick fails with &"invalid_state", naming both
## ticks, and emits nothing.
func test_mismatched_header_tick_is_invalid_state() -> void:
	for header_tick: int in [11, 9, 0]:
		_save_with_ticks(&"edited", header_tick, 10)
		var result: Result = _service.load_game(&"edited")
		var label := str(header_tick)
		assert_bool(result.is_ok).override_failure_message(label).is_false()
		assert_str(result.error_code).override_failure_message(label).is_equal(&"invalid_state")
		assert_str(result.detail).override_failure_message(label).contains(
			"header tick %d differs from clock tick 10" % header_tick
		)
	assert_array(_loaded).is_empty()


## A file whose header tick matches its clock tick still loads, here at a hand-edited tick.
func test_matching_header_tick_loads() -> void:
	_save_with_ticks(&"edited", 25, 25)
	var result: Result = _service.load_game(&"edited")
	assert_bool(result.is_ok).is_true()
	var state: GameState = result.value
	assert_int(state.clock.tick).is_equal(25)
	assert_array(_loaded).is_equal([&"edited"])


## list_slots() skips files whose header tick differs from the clock tick, or whose clock
## tick is missing or not a number, and keeps the matching ones.
func test_list_slots_skips_mismatched_header_tick() -> void:
	_save_with_ticks(&"good", 10, 10)
	_save_with_ticks(&"ahead", 11, 10)
	_save_with_ticks(&"behind", 10, 11)
	_save_with_ticks(&"text_tick", 10, "10")
	_save_with_ticks(&"no_tick", 10, null)
	assert_array(_listed_slots()).contains_exactly([&"good"])
