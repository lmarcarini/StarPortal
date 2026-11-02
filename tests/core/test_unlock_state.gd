## Tests for UnlockState: the new game's unlocks, the JSON round trip inside a v12 GameState
## and validate_dict().
## Bible: docs/content/m25-lean-start.md sections 1, 3 and 7, technical-architecture.md#save-system
extends GdUnitTestSuite


## A new game may build the bank, the lab and corridors; no dig; one bank; no override.
func test_new_game_unlocks() -> void:
	var state := GameState.new_game(3, BalanceConfig.new())
	assert_array(state.unlocks.rooms).is_equal(
		[&"room_capacitor_bank", &"room_research_lab", &"room_corridor"]
	)
	assert_int(state.unlocks.dig_depth).is_equal(1)
	assert_int(state.unlocks.bank_cap).is_equal(1)
	assert_dict(state.unlocks.upkeep_overrides).is_empty()


## Every field survives a JSON round trip of the whole game, which validates.
func test_round_trip_in_game_state() -> void:
	var state := GameState.new_game(3, BalanceConfig.new())
	for project_id: StringName in UnlockRules.PROJECTS:
		UnlockRules.apply_project(state.unlocks, project_id)
	var data: Dictionary = JSON.parse_string(JSON.stringify(state.to_dict()))
	assert_array(GameState.validate_dict(data)).is_empty()
	var loaded := GameState.from_dict(data)
	assert_dict(loaded.unlocks.to_dict()).is_equal(state.unlocks.to_dict())
	assert_bool(loaded.unlocks.has_room(&"room_workshop")).is_true()
	assert_int(loaded.unlocks.dig_depth).is_equal(4)
	assert_int(loaded.unlocks.bank_cap).is_equal(3)
	assert_int(loaded.unlocks.upkeep_overrides[&"room_power_plant"]).is_equal(100)


## A save without "unlocks" is invalid.
func test_game_state_needs_unlocks() -> void:
	var data: Dictionary = GameState.new_game(3).to_dict()
	data.erase("unlocks")
	assert_array(GameState.validate_dict(data)).contains(["missing 'unlocks'"])


## validate_dict() rejects missing keys and bad values.
func test_validate_rejects_bad_data() -> void:
	var good: Dictionary = UnlockState.starting(BalanceConfig.new()).to_dict()
	assert_array(UnlockState.validate_dict(good)).is_empty()
	var cases: Array[Dictionary] = [
		{"rooms": "room_lab"},
		{"rooms": ["room_lab", "room_lab"]},
		{"rooms": [""]},
		{"rooms": [3]},
		{"dig_depth": 0},
		{"dig_depth": 1.5},
		{"bank_cap": -1},
		{"upkeep_overrides": []},
		{"upkeep_overrides": {"room_power_plant": -5}},
	]
	for change: Dictionary in cases:
		var bad: Dictionary = good.duplicate(true)
		bad.merge(change, true)
		(
			assert_array(UnlockState.validate_dict(bad))
			. override_failure_message(str(change))
			. is_not_empty()
		)
	var missing: Dictionary = good.duplicate(true)
	missing.erase("bank_cap")
	assert_array(UnlockState.validate_dict(missing)).contains(["missing 'bank_cap'"])
