## Tests for world states and report facts as commands and events: states only go up, a lock
## never lowers a later state, and both survive a save (v15).
## Bible: docs/content/m3-beyond-the-ring.md section 3 (Worlds) and section 9 (Saves)
extends GdUnitTestSuite

const DialFixture := preload("res://tests/gate/dial_fixture.gd")
const S := WorldsState.WorldStatus
const C := WorldReport.Confidence


func _status(world: StringName, status: S) -> RaiseWorldStatusCommand:
	return RaiseWorldStatusCommand.create(world, status)


func _fact(level: C) -> RaiseWorldFactCommand:
	var change := WorldProgress.FactChange.create(
		DialFixture.OPEN_ID, WorldReport.Fact.THREAT, level, &"moth"
	)
	return RaiseWorldFactCommand.create(change)


## A status command raises the state and posts world_status_changed; lower or equal states and
## unknown worlds are rejected.
func test_status_command() -> void:
	var game: GameState = DialFixture.state()
	var probe := _status(DialFixture.OPEN_ID, S.PROBED)
	assert_bool(probe.validate(game).is_ok).is_true()
	probe.apply(game)
	assert_int(game.worlds.status_of(DialFixture.OPEN_ID)).is_equal(S.PROBED)
	var events: Array[SimEvent] = game.events.drain()
	assert_int(events.size()).is_equal(1)
	assert_str(events[0].name).is_equal(&"world_status_changed")
	assert_array(events[0].args).is_equal([DialFixture.OPEN_ID, S.PROBED as int])
	var lower := _status(DialFixture.OPEN_ID, S.LOCKED)
	assert_str(lower.validate(game).error_code).is_equal(&"status_not_higher")
	assert_str(_status(&"nowhere", S.LOCKED).validate(game).error_code).is_equal(&"unknown_world")


## WorldProgress never lowers a state: a later lock keeps PROBED, with no event.
func test_lock_keeps_later_state() -> void:
	var game: GameState = DialFixture.state()
	WorldProgress.raise_status(game, DialFixture.OPEN_ID, S.SURVEYED)
	game.events.drain()
	var changed := WorldProgress.raise_status(game, DialFixture.OPEN_ID, S.LOCKED)
	assert_bool(changed).is_false()
	assert_int(game.worlds.status_of(DialFixture.OPEN_ID)).is_equal(S.SURVEYED)
	assert_int(game.events.size()).is_zero()
	assert_bool(game.worlds.has_reached(DialFixture.OPEN_ID, S.PROBED)).is_true()


## A fact command raises confidence with its source and tick and posts world_fact_raised.
func test_fact_command() -> void:
	var game: GameState = DialFixture.state()
	game.clock.tick = 42
	var command := _fact(C.FAIR)
	assert_bool(command.validate(game).is_ok).is_true()
	command.apply(game)
	var entry := game.worlds.report_of(DialFixture.OPEN_ID).entry_of(WorldReport.Fact.THREAT)
	assert_int(entry.confidence).is_equal(C.FAIR)
	assert_str(entry.source).is_equal(&"moth")
	assert_int(entry.tick).is_equal(42)
	var events: Array[SimEvent] = game.events.drain()
	assert_str(events[0].name).is_equal(&"world_fact_raised")
	assert_str(_fact(C.POOR).validate(game).error_code).is_equal(&"confidence_not_higher")


## Both commands round-trip through JSON and the factory.
func test_commands_round_trip() -> void:
	var commands: Array[Command] = [_status(DialFixture.OPEN_ID, S.CONTACTED), _fact(C.GOOD)]
	for command: Command in commands:
		var data: Dictionary = JSON.parse_string(JSON.stringify(command.to_dict()))
		var result := CommandFactory.from_dict(data)
		assert_bool(result.is_ok).is_true()
		var rebuilt: Command = result.value
		assert_dict(rebuilt.to_dict()).is_equal(command.to_dict())
	var bad := CommandFactory.from_dict({"type": "raise_world_status", "world_id": 3})
	assert_str(bad.error_code).is_equal(&"malformed_command")


## World states and reports survive the worlds save, and bad data is reported.
func test_worlds_save_round_trip() -> void:
	var game: GameState = DialFixture.state()
	WorldProgress.raise_status(game, DialFixture.OPEN_ID, S.CONTACTED)
	_fact(C.POOR).apply(game)
	var data: Dictionary = JSON.parse_string(JSON.stringify(game.worlds.to_dict()))
	assert_array(WorldsState.validate_dict(data)).is_empty()
	var loaded := WorldsState.from_dict(data)
	assert_int(loaded.status_of(DialFixture.OPEN_ID)).is_equal(S.CONTACTED)
	assert_dict(loaded.to_dict()).is_equal(game.worlds.to_dict())
	data["reports"] = {"": {}}
	assert_array(WorldsState.validate_dict(data)).is_not_empty()
	data.erase("reports")
	assert_array(WorldsState.validate_dict(data)).contains(["missing 'reports'"])
