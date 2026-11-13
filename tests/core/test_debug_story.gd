## Tests for the debug story tools (M4-19): each action through DebugStoryCommand with a
## "(debug)" Log line, unknown ids refused, and the overlay row submitting it.
extends GdUnitTestSuite

var _state: GameState


func before_test() -> void:
	_state = GameState.new_game(3)
	GameSetup.build_new(_state, GameDefs.from_registry(Registry))
	_state.events.drain()


func _run(action: StringName, id: StringName, value: String = "") -> CommandResult:
	var command := DebugStoryCommand.create(action, id, value)
	var result: CommandResult = command.validate(_state)
	if result.is_ok:
		command.apply(_state)
	return result


func test_actions() -> void:
	assert_bool(_run(&"standing", &"faction_ossar", "30").is_ok).is_true()
	assert_int(FactionRules.standing(_state, &"faction_ossar")).is_equal(30)
	assert_bool(_run(&"meet", &"faction_kindred").is_ok).is_true()
	assert_array(_state.factions.met).contains([&"faction_kindred"])
	_run(&"flag", &"relic_in_hand", "true")
	assert_bool(_state.flags[&"relic_in_hand"]).is_true()
	_run(&"offer", &"request_survey_hearth")
	assert_int(_state.requests.items.size()).is_equal(1)
	_run(&"contact", &"conv_kindred_gift")
	assert_str(String(_state.factions.pending[0].channel)).is_equal("incoming")


func test_refusals_and_log() -> void:
	assert_str(String(_run(&"meet", &"faction_nobody").error_code)).is_equal("unknown_id")
	assert_str(String(_run(&"teleport", &"x").error_code)).is_equal("bad_action")
	_run(&"flag", &"x", "5")
	var events: Array[SimEvent] = _state.events.drain()
	var last: SimEvent = events[-1]
	var entries: Array[LogEntry] = LogRules.entries_for(last.name, last.args, _state, 1)
	TranslationServer.set_locale("en")
	assert_str(ArchiveLogRow.line_for(entries[0], _state)).is_equal("(debug) flag x")


func test_overlay_row() -> void:
	var simulation := Simulation.new(_state, [])
	SimClock.start(simulation)
	var overlay: DebugOverlay = (
		(load("res://src/ui/debug/debug_overlay.tscn") as PackedScene).instantiate() as DebugOverlay
	)
	add_child(overlay)
	overlay.set_story(1, "faction_kindred", "")
	assert_bool(overlay.run_story().is_ok).is_true()
	assert_array(_state.factions.met).contains([&"faction_kindred"])
	SimClock.stop()
	overlay.free()
