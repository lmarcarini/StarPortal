## The MOTH rack (M4c-20): a new game has none and no MOTH; ordering needs the rack, at most
## two owned; an old save gets Survey drones and a built rack and keeps its MOTHs.
## Bible: docs/content/m4c-incursions.md section 6
extends GdUnitTestSuite


func test_new_game_has_no_moth_until_ordered() -> void:
	var state := GameState.new_game(3, Registry.balance())
	GameSetup.build_new(state, GameDefs.from_registry(Registry))
	assert_int(state.probes.rack).is_equal(0)
	assert_bool(MothRules.has_rack(state)).is_false()
	assert_str(String(OrderMothCommand.new().validate(state).error_code)).is_equal("no_rack")
	assert_str(String(LaunchMothCommand.new().validate(state).error_code)).is_equal("no_rack")
	preload("res://tests/gate/dial_fixture.gd").give_moth_rack(state)
	state.probes.rack = 0
	OrderMothCommand.new().apply(state)
	OrderMothCommand.new().apply(state)
	assert_str(String(OrderMothCommand.new().validate(state).error_code)).is_equal("rack_full")


func test_old_saves_get_the_rack_and_keep_their_moths() -> void:
	var state := GameState.new_game(3, Registry.balance())
	GameSetup.build_new(state, GameDefs.from_registry(Registry))
	state.probes.rack = 2
	var data: Dictionary = JSON.parse_string(JSON.stringify(state.to_dict()))
	var migrated: Result = SaveMigrator.migrate({"format_version": 20, "state": data})
	assert_bool(migrated.is_ok).is_true()
	var root: Dictionary = migrated.value
	var state_data: Dictionary = root["state"]
	var loaded: GameState = GameState.from_dict(state_data)
	assert_bool(loaded.research.done.has(&"survey_drones")).is_true()
	assert_bool(MothRules.has_rack(loaded)).is_true()
	assert_int(loaded.probes.rack).is_equal(2)
