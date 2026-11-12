## Tests for ResearchState: the new game's state, the JSON round trip inside a v12 GameState,
## validate_dict() and a v12 save without a research section (rejected).
## Bible: docs/content/m25-lean-start.md sections 3 and 7, technical-architecture.md#save-system
extends GdUnitTestSuite


## A new game has nothing running and nothing done.
func test_new_game() -> void:
	var state := GameState.new_game(3, BalanceConfig.new())
	assert_bool(state.research.is_running()).is_false()
	assert_int(state.research.ticks_done).is_equal(0)
	assert_array(state.research.done).is_empty()


## Every field survives a JSON round trip of the whole game, which validates.
func test_round_trip_in_game_state() -> void:
	var state := GameState.new_game(3, BalanceConfig.new())
	state.research.active = &"lift_shaft"
	state.research.ticks_done = 1234
	state.research.done.assign([&"excavation_survey", &"bank_array"])
	var data: Dictionary = JSON.parse_string(JSON.stringify(state.to_dict()))
	assert_array(GameState.validate_dict(data)).is_empty()
	var loaded := GameState.from_dict(data)
	assert_dict(loaded.research.to_dict()).is_equal(state.research.to_dict())
	assert_that(loaded.research.active).is_equal(&"lift_shaft")
	assert_bool(loaded.research.is_done(&"bank_array")).is_true()


## A v12 save without "research" (written before this card) is invalid: the load fails with
## invalid_state rather than guessing what was researched.
func test_game_state_needs_research() -> void:
	var data: Dictionary = GameState.new_game(3).to_dict()
	data.erase("research")
	assert_array(GameState.validate_dict(data)).contains(["missing 'research'"])


## validate_dict() rejects missing keys and bad values.
func test_validate_dict() -> void:
	var good: Dictionary = {
		"active": "", "ticks_done": 0, "done": ["bank_array"], "queue": [], "revealed": []
	}
	assert_array(ResearchState.validate_dict(good)).is_empty()
	assert_array(ResearchState.validate_dict({})).has_size(5)
	var cases: Array[Dictionary] = [
		{"active": 3, "ticks_done": 0, "done": [], "queue": [], "revealed": []},
		{"active": "a", "ticks_done": -1, "done": [], "queue": [], "revealed": []},
		{"active": "a", "ticks_done": 1.5, "done": [], "queue": [], "revealed": []},
		{"active": "", "ticks_done": 5, "done": [], "queue": [], "revealed": []},
		{"active": "", "ticks_done": 0, "done": "x", "queue": [], "revealed": []},
		{"active": "", "ticks_done": 0, "done": ["a", "a"], "queue": [], "revealed": []},
		{"active": "", "ticks_done": 0, "done": [""], "queue": [], "revealed": []},
		{"active": "a", "ticks_done": 0, "done": ["a"], "queue": [], "revealed": []},
	]
	for data: Dictionary in cases:
		(
			assert_array(ResearchState.validate_dict(data))
			. override_failure_message(str(data))
			. is_not_empty()
		)
