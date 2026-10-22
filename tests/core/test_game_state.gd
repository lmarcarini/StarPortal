## Tests for GameState, ClockState and RandomState serialisation, including a JSON round
## trip that turns ints into floats.
## Bible: technical-architecture.md#data-model
extends GdUnitTestSuite


func _sample_state() -> GameState:
	var state := GameState.new_game(123456789)
	state.clock.tick = 44641
	state.clock.speed_index = 3
	state.clock.is_paused = false
	state.flags[&"met_director"] = true
	state.flags[&"briefings_heard"] = 7
	state.flags[&"last_world"] = "P3X-118"
	return state


func _json_round_trip(data: Dictionary) -> Dictionary:
	var parsed: Variant = JSON.parse_string(JSON.stringify(data))
	assert_bool(parsed is Dictionary).is_true()
	if not parsed is Dictionary:
		return {}
	return parsed


func _is_json_safe(value: Variant) -> bool:
	if value is Dictionary:
		var dict: Dictionary = value
		for key: Variant in dict:
			if not key is String or not _is_json_safe(dict[key]):
				return false
		return true
	if value is Array:
		var list: Array = value
		return list.all(_is_json_safe)
	return value == null or value is bool or value is int or value is float or value is String


## new_game() stores the seed and starts a paused clock at tick 0 with no flags.
func test_new_game_defaults() -> void:
	var state := GameState.new_game(42)
	assert_int(state.random.base_seed).is_equal(42)
	assert_int(state.clock.tick).is_equal(0)
	assert_int(state.clock.speed_index).is_equal(1)
	assert_bool(state.clock.is_paused).is_true()
	assert_dict(state.flags).is_empty()


## to_dict() returns only JSON-safe types: String keys, no StringName or objects.
func test_to_dict_is_json_safe() -> void:
	var data := _sample_state().to_dict()
	assert_bool(_is_json_safe(data)).is_true()


## from_dict(to_dict()) reproduces an equal dictionary.
func test_round_trip_reproduces_equal_dictionary() -> void:
	var data := _sample_state().to_dict()
	assert_dict(GameState.from_dict(data).to_dict()).is_equal(data)


## The round trip still matches after JSON.stringify -> JSON.parse_string.
func test_json_round_trip_reproduces_equal_dictionary() -> void:
	var data := _sample_state().to_dict()
	var restored := GameState.from_dict(_json_round_trip(data))
	assert_dict(restored.to_dict()).is_equal(data)


## After a JSON round trip the restored fields have their original types.
func test_json_round_trip_restores_types() -> void:
	var restored := GameState.from_dict(_json_round_trip(_sample_state().to_dict()))
	assert_int(typeof(restored.clock.tick)).is_equal(TYPE_INT)
	assert_int(restored.clock.tick).is_equal(44641)
	assert_int(restored.random.base_seed).is_equal(123456789)
	assert_bool(restored.flags.has(&"met_director")).is_true()
	assert_int(typeof(restored.flags.keys()[0])).is_equal(TYPE_STRING_NAME)
	assert_int(typeof(restored.flags[&"briefings_heard"])).is_equal(TYPE_INT)
	assert_that(restored.flags[&"last_world"]).is_equal("P3X-118")


## Missing sections fall back to defaults instead of failing.
func test_from_dict_with_empty_data_uses_defaults() -> void:
	var state := GameState.from_dict({})
	assert_int(state.clock.tick).is_equal(0)
	assert_bool(state.clock.is_paused).is_true()
	assert_int(state.random.base_seed).is_equal(0)
	assert_dict(state.flags).is_empty()


## ClockState and RandomState round-trip on their own.
func test_sub_states_round_trip() -> void:
	var clock := ClockState.new()
	clock.tick = 99
	clock.speed_index = 2
	clock.is_paused = false
	var clock_data := clock.to_dict()
	var restored_clock := ClockState.from_dict(_json_round_trip(clock_data))
	assert_dict(restored_clock.to_dict()).is_equal(clock_data)
	var random := RandomState.new()
	random.base_seed = 77
	var random_data := random.to_dict()
	var restored_random := RandomState.from_dict(_json_round_trip(random_data))
	assert_dict(restored_random.to_dict()).is_equal(random_data)


## validate_dict accepts int and float flags up to 2^53 in absolute value and rejects
## larger ones, whether they arrive as ints or as whole floats.
func test_validate_rejects_flags_beyond_two_pow_53() -> void:
	var limit: int = JsonLimits.MAX_EXACT_INT
	var base := _sample_state().to_dict()
	for value: Variant in [limit, -limit, float(limit), -float(limit)]:
		var data := base.duplicate(true)
		data["flags"]["edge"] = value
		var errors := GameState.validate_dict(data)
		assert_array(errors).override_failure_message(str(value)).is_empty()
	for value: Variant in [limit + 1, -limit - 1, float(limit) + 2.0, 1e300]:
		var data := base.duplicate(true)
		data["flags"]["edge"] = value
		var errors := GameState.validate_dict(data)
		assert_array(errors).override_failure_message(str(value)).contains(
			["flag 'edge' is not a bool, String or whole number"]
		)
