## Tests for the saved expedition (ExpeditionState, ExpeditionSaveChecks): an away team round
## trips through JSON and the game state validates; inconsistent data is refused.
## Bible: docs/content/m3-beyond-the-ring.md section 9 (saves)
extends GdUnitTestSuite

const Fixture := preload("res://tests/expedition/expedition_fixture.gd")


func _away() -> ExpeditionState:
	var game: GameState = Fixture.state()
	var expedition: ExpeditionState = game.expedition
	expedition.set_plan(
		ExpeditionState.Objective.RECOVER, Fixture.WORLD_ID, Fixture.ANCHOR_ID, Fixture.team(game)
	)
	expedition.mode = ExpeditionState.Mode.AWAY
	expedition.departed_tick = 120
	expedition.add_document("survey_report", Fixture.WORLD_ID, &"", 5)
	return expedition


func _json(data: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(data))


func test_new_expedition_is_valid_and_idle() -> void:
	var data: Dictionary = _json(ExpeditionState.new().to_dict())
	assert_array(ExpeditionState.validate_dict(data)).is_empty()
	assert_int(ExpeditionState.from_dict(data).mode).is_equal(ExpeditionState.Mode.IDLE)


func test_away_round_trips() -> void:
	var data: Dictionary = _json(_away().to_dict())
	assert_array(ExpeditionState.validate_dict(data)).is_empty()
	var loaded: ExpeditionState = ExpeditionState.from_dict(data)
	assert_dict(loaded.to_dict()).is_equal(_away().to_dict())
	assert_int(loaded.departed_tick).is_equal(120)


func test_game_state_carries_the_expedition() -> void:
	var game: GameState = Fixture.state()
	game.expedition = _away()
	var data: Dictionary = _json(game.to_dict())
	assert_array(GameState.validate_dict(data)).is_empty()
	var loaded: GameState = GameState.from_dict(data)
	assert_int(loaded.expedition.mode).is_equal(ExpeditionState.Mode.AWAY)
	data.erase("expedition")
	assert_array(GameState.validate_dict(data)).contains(["missing 'expedition'"])


func test_bad_data_refused() -> void:
	var cases: Array[Dictionary] = []
	var data: Dictionary = _json(_away().to_dict())
	data["mode"] = "lost"
	cases.append(data)
	data = _json(_away().to_dict())
	data["departed_tick"] = -1
	cases.append(data)
	data = _json(_away().to_dict())
	data["day_results"] = ["ok"]
	cases.append(data)
	data = _json(_away().to_dict())
	var team: Dictionary = data["team"]
	team.erase("soldier")
	cases.append(data)
	data = _json(_away().to_dict())
	data["target_id"] = ""
	cases.append(data)
	data = _json(ExpeditionState.new().to_dict())
	data["world_id"] = "x"
	cases.append(data)
	data = _json(_away().to_dict())
	data["documents"] = [{"kind": "nope"}]
	cases.append(data)
	for index: int in cases.size():
		assert_array(ExpeditionState.validate_dict(cases[index])).is_not_empty()
