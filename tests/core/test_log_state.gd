## Tests for LogEntry and LogState: saved shape, round trip, validation and the cap.
## Bible: game-design.md#core-loop (Archive: the operations log)
extends GdUnitTestSuite


func _entry(tick: int, kind: StringName = &"dial") -> LogEntry:
	return LogEntry.create(tick, kind, &"world_sill", {"address": "1-2-3", "seals": [1, 2]})


## An entry survives a JSON round trip with whole floats back as ints.
func test_entry_round_trip_through_json() -> void:
	var entry := _entry(42)
	var data: Dictionary = JSON.parse_string(JSON.stringify(entry.to_dict()))
	assert_array(LogEntry.validate_dict(data)).is_empty()
	var back := LogEntry.from_dict(data)
	assert_int(back.tick).is_equal(42)
	assert_str(String(back.kind)).is_equal("dial")
	assert_str(String(back.world_id)).is_equal("world_sill")
	assert_dict(back.args).is_equal({"address": "1-2-3", "seals": [1, 2]})
	var seals: Array = back.args["seals"]
	assert_bool(seals[0] is int).is_true()


## Bad ticks, kinds, world ids and argument values are reported.
func test_entry_validation() -> void:
	var errors := LogEntry.validate_dict(
		{"tick": -1, "kind": "party", "world_id": 3, "args": {"x": 1.5, "y": [1, "a"]}}
	)
	assert_int(errors.size()).is_equal(5)
	assert_array(LogEntry.validate_dict({"tick": 1, "kind": "lock", "world_id": ""})).contains(
		["'args' is not an object"]
	)


## Adding past the cap drops the oldest entries.
func test_cap_drops_the_oldest() -> void:
	var log_state := LogState.new()
	for tick: int in LogState.CAP + 5:
		log_state.add(_entry(tick))
	assert_int(log_state.entries.size()).is_equal(LogState.CAP)
	assert_int(log_state.entries[0].tick).is_equal(5)
	assert_int(log_state.last_tick()).is_equal(LogState.CAP + 4)


## A log round trips; too many entries, a non-object or ticks going back are rejected.
func test_state_round_trip_and_validation() -> void:
	var log_state := LogState.new()
	log_state.add(_entry(3))
	log_state.add(_entry(7, &"close"))
	var data: Dictionary = JSON.parse_string(JSON.stringify(log_state.to_dict()))
	assert_array(LogState.validate_dict(data)).is_empty()
	assert_dict(LogState.from_dict(data).to_dict()).is_equal(log_state.to_dict())
	var backwards: Dictionary = data.duplicate(true)
	var backwards_entries: Array = backwards["entries"]
	backwards_entries.reverse()
	assert_int(LogState.validate_dict(backwards).size()).is_equal(1)
	assert_int(LogState.validate_dict({"entries": [5]}).size()).is_equal(1)
	assert_int(LogState.validate_dict({}).size()).is_equal(1)
	var too_many: Array = []
	too_many.resize(LogState.CAP + 1)
	too_many.fill(_entry(1).to_dict())
	assert_int(LogState.validate_dict({"entries": too_many}).size()).is_equal(1)


## GameState saves the log and rejects an entry later than the clock.
func test_game_state_saves_the_log() -> void:
	var state := GameState.new_game(1)
	state.clock.tick = 10
	state.operations_log.add(_entry(10))
	var data: Dictionary = JSON.parse_string(JSON.stringify(state.to_dict()))
	assert_array(GameState.validate_dict(data)).is_empty()
	assert_int(GameState.from_dict(data).operations_log.entries.size()).is_equal(1)
	var clock: Dictionary = data["clock"]
	clock["tick"] = 9
	assert_array(GameState.validate_dict(data)).contains(
		["operations_log: the newest entry's 'tick' is later than the clock tick"]
	)
