## Tests for the v13 save of the roster: round trip, the v12 clean break, and the load-time id
## checks against the content and the base (docs/content/m26-staff-and-money.md section 8,
## M2.5 follow-up #178).
## Bible: docs/content/m26-staff-and-money.md section 8, technical-architecture.md#save-system
extends GdUnitTestSuite

const SaveServiceScript := preload("res://src/services/save_service.gd")

var _service: SaveServiceScript
var _defs: GameDefs


func before_test() -> void:
	_service = SaveServiceScript.new()
	_service.saves_dir = "user://test_staff_saves_%d" % Time.get_ticks_usec()
	_defs = GameDefs.from_registry(Registry)


func after_test() -> void:
	for file: String in DirAccess.get_files_at(_service.saves_dir):
		DirAccess.remove_absolute(_service.saves_dir.path_join(file))
	DirAccess.remove_absolute(_service.saves_dir)
	_service.free()


func _state() -> GameState:
	var state: GameState = GameState.new_game(5, Registry.balance())
	var arriving := PersonState.new()
	arriving.name = "Dr Clara Novak"
	arriving.role = &"role_scientist"
	arriving.skill = 4
	arriving.salary_k = 35
	arriving.arrives_tick = 300
	state.staff.add_person(arriving)
	return state


## A JSON-safe copy of [param state]'s saved data.
func _data(state: GameState) -> Dictionary:
	return JSON.parse_string(JSON.stringify(state.to_dict()))


func test_v13_round_trips_the_roster() -> void:
	var state: GameState = _state()
	state.staff.auto_assign.erase(&"room_workshop")
	assert_bool(_service.save_game(state, &"staff").is_ok).is_true()
	var loaded: Result = _service.load_game(&"staff", _defs)
	assert_bool(loaded.is_ok).override_failure_message(loaded.detail).is_true()
	var back: GameState = loaded.value
	assert_dict(back.staff.to_dict()).is_equal(state.staff.to_dict())
	assert_str(back.staff.people[4].room_id).is_not_empty()
	var file := FileAccess.open(_service.slot_path(&"staff"), FileAccess.READ)
	var header: Dictionary = JSON.parse_string(file.get_as_text())
	var version: float = header["format_version"]
	assert_float(version).is_equal(13.0)


func test_v12_save_is_an_old_save() -> void:
	var result: Result = SaveMigrator.migrate({"format_version": 12, "state": {}})
	assert_str(result.error_code).is_equal(&"old_format_version")


func test_new_game_data_is_valid_against_the_content() -> void:
	assert_array(GameState.validate_dict(_data(_state()), _defs)).is_empty()


func _errors_after(edit: Callable) -> Array[String]:
	var data: Dictionary = _data(_state())
	edit.call(data)
	return GameState.validate_dict(data, _defs)


func test_unknown_role_is_rejected() -> void:
	var errors: Array[String] = _errors_after(
		func(data: Dictionary) -> void: data["staff"]["people"][0]["role"] = "role_medic"
	)
	assert_str("; ".join(errors)).contains("unknown role 'role_medic'")


func test_unknown_room_def_is_rejected() -> void:
	var errors: Array[String] = _errors_after(
		func(data: Dictionary) -> void: data["base"]["rooms"][2]["def_id"] = "room_bakery"
	)
	assert_str("; ".join(errors)).contains("unknown def 'room_bakery'")


func test_unknown_research_is_rejected() -> void:
	var errors: Array[String] = _errors_after(
		func(data: Dictionary) -> void: data["research"]["done"] = ["later_6_fission_plant"]
	)
	assert_str("; ".join(errors)).contains("unknown project")


## An assignment to a missing room is rejected without the content too.
func test_assignment_to_missing_room_is_rejected() -> void:
	var data: Dictionary = _data(_state())
	data["staff"]["people"][0]["room_id"] = "room_999"
	assert_str("; ".join(GameState.validate_dict(data))).contains("missing room 'room_999'")


func test_wrong_role_or_overfull_room_is_rejected() -> void:
	var errors: Array[String] = _errors_after(
		func(data: Dictionary) -> void:
			for index: int in 4:
				data["staff"]["people"][index]["room_id"] = "room_2"
	)
	var text: String = "; ".join(errors)
	assert_str(text).contains("in a room without role_scientist slots")
	assert_str(text).contains("holds more people than slots")


func test_arriving_person_with_a_room_is_rejected() -> void:
	var data: Dictionary = _data(_state())
	data["staff"]["people"][5]["room_id"] = "room_2"
	assert_str("; ".join(GameState.validate_dict(data))).contains("a room before arriving")


func test_bad_person_fields_are_rejected() -> void:
	var data: Dictionary = _data(_state())
	data["staff"]["people"][0]["skill"] = 6
	data["staff"]["people"][1]["id"] = "person_1"
	var text: String = "; ".join(GameState.validate_dict(data))
	assert_str(text).contains("'skill' is not a whole number from 1 to 5")
	data["staff"]["people"][0]["skill"] = 3
	assert_str("; ".join(GameState.validate_dict(data))).contains("duplicate id 'person_1'")
