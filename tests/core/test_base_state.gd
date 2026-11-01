## Tests for BaseState, LevelState and RoomState: the new game's base, the save round trip and
## validate_dict().
## Bible: game-design.md#base-building-and-power, technical-architecture.md#data-model
extends GdUnitTestSuite


## A new game has the starting base.
func test_new_game_has_the_starting_base() -> void:
	var state := GameState.new_game(7)
	assert_dict(state.base.to_dict()).is_equal(StartingBase.build(BalanceConfig.new()).to_dict())


## Every value survives a JSON round trip and validates.
func test_round_trip() -> void:
	var base := StartingBase.build(BalanceConfig.new())
	base.levels.append(LevelState.new())
	base.levels[3].dig_ticks_left = 500
	var lab: RoomState = base.add_room(&"room_physics_lab", 1, Vector2i(3, 4))
	lab.rotated = true
	lab.build_ticks_left = 99
	lab.powered_on = false
	var data: Dictionary = JSON.parse_string(JSON.stringify(base.to_dict()))
	assert_array(BaseState.validate_dict(data)).is_empty()
	var loaded := BaseState.from_dict(data)
	assert_dict(loaded.to_dict()).is_equal(base.to_dict())
	assert_int(loaded.level_count).is_equal(4)
	var last: RoomState = loaded.rooms[loaded.rooms.size() - 1]
	assert_str(String(last.id)).is_equal(String(lab.id))
	assert_that(last.origin).is_equal(Vector2i(3, 4))


## The whole GameState round trip keeps the base and validates.
func test_game_state_round_trip() -> void:
	var state := GameState.new_game(7)
	state.base.add_room(&"room_physics_lab", 1, Vector2i(1, 1))
	var data: Dictionary = JSON.parse_string(JSON.stringify(state.to_dict()))
	assert_array(GameState.validate_dict(data)).is_empty()
	assert_dict(GameState.from_dict(data).base.to_dict()).is_equal(state.base.to_dict())


## validate_dict() rejects missing keys, bad shapes and impossible placements.
func test_validate_rejects_bad_data() -> void:
	assert_array(BaseState.validate_dict({})).has_size(4)
	var cases: Array[Dictionary] = [
		{"grid_size": [0, 20]},
		{"grid_size": [36]},
		{"next_room_number": 0},
		{"levels": []},
		{"levels": [{"dig_ticks_left": -1}]},
		{"rooms": 3},
		{"rooms": [5]},
	]
	for change: Dictionary in cases:
		var data: Dictionary = StartingBase.build(BalanceConfig.new()).to_dict()
		data.merge(change, true)
		(
			assert_array(BaseState.validate_dict(data))
			. override_failure_message(str(change))
			. is_not_empty()
		)


## validate_dict() rejects bad rooms: bad fields, duplicate ids, missing level, origin off grid.
func test_validate_rejects_bad_rooms() -> void:
	var cases: Array[Dictionary] = [
		{"id": ""},
		{"def_id": 4},
		{"level": 1.5},
		{"origin": [-1, 0]},
		{"rotated": "no"},
		{"powered_on": 1},
		{"build_ticks_left": -3},
		{"level": 4},
		{"level": 0},
		{"origin": [36, 0]},
	]
	for change: Dictionary in cases:
		var data: Dictionary = StartingBase.build(BalanceConfig.new()).to_dict()
		var rooms: Array = data["rooms"]
		var room: Dictionary = rooms[0]
		room.merge(change, true)
		(
			assert_array(BaseState.validate_dict(data))
			. override_failure_message(str(change))
			. is_not_empty()
		)
	var twice: Dictionary = StartingBase.build(BalanceConfig.new()).to_dict()
	var twice_rooms: Array = twice["rooms"]
	var first: Dictionary = twice_rooms[0]
	twice_rooms.append(first.duplicate())
	var dup: String = "rooms %d: duplicate id 'room_1'" % (twice_rooms.size() - 1)
	assert_array(BaseState.validate_dict(twice)).contains([dup])


## next_room_number at or below an existing room's number is rejected: add_room() would repeat
## an id.
func test_validate_rejects_next_room_number_not_above_ids() -> void:
	var base := BaseState.new()
	base.levels.append(LevelState.new())
	base.grid_size = Vector2i(10, 10)
	base.add_room(&"room_quarters", 1, Vector2i(1, 1))
	base.add_room(&"room_quarters", 1, Vector2i(5, 1))
	var data: Dictionary = base.to_dict()
	assert_array(BaseState.validate_dict(data)).is_empty()
	data["next_room_number"] = 2
	assert_array(BaseState.validate_dict(data)).is_not_empty()


func test_start_and_cancel_dig() -> void:
	var base := BaseState.new()
	base.levels.append(LevelState.new())
	assert_int(base.start_dig(50)).is_equal(2)
	assert_int(base.digging_level()).is_equal(2)
	assert_bool(base.cancel_dig()).is_true()
	assert_int(base.level_count).is_equal(1)
	assert_bool(base.cancel_dig()).is_false()
