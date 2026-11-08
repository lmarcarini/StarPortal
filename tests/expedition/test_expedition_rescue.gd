## Tests for the rescue (ExpeditionRescue, SignalTeamCommand): Signal T-1 needs the window and
## a wormhole open to the world; closing it early fails the Signal; the team reaches the Ring
## 15 minutes later and each member rolls (seeded, the same after save and load); the deceased
## leave with Confidence -3 each and a Log line; nobody surviving gives "No answer from T-1."
## and a lost team, as does a window that runs out (Confidence -10, lent soldiers replaced).
## Bible: docs/content/m3-beyond-the-ring.md section 4
extends GdUnitTestSuite

const Fixture := preload("res://tests/expedition/expedition_fixture.gd")
const RescueFixture := preload("res://tests/expedition/rescue_fixture.gd")
const ProbeFixture := preload("res://tests/gate/probe_fixture.gd")
const DAY: int = TimeMath.TICKS_PER_DAY

var _state: GameState
var _simulation: Simulation


func before_test() -> void:
	_state = Fixture.state()
	_simulation = RescueFixture.simulation(_state, 0)
	RescueFixture.send_and_miss(_simulation)


func _team() -> Array[StringName]:
	return _state.expedition.member_ids()


func _on_roster(ids: Array[StringName]) -> int:
	return (
		ids.filter(func(id: StringName) -> bool: return _state.staff.find_person(id) != null).size()
	)


func _reasons() -> Array[String]:
	var reasons: Array[String] = []
	for entry: LogEntry in _state.operations_log.entries:
		if entry.kind == &"expedition":
			reasons.append(str(entry.args["reason"]))
	return reasons


func test_signal_needs_the_window_and_an_open_wormhole() -> void:
	var command := SignalTeamCommand.new()
	assert_str(String(command.validate(_state).error_code)).is_equal(
		String(ExpeditionRules.NO_WORMHOLE)
	)
	assert_bool(RescueFixture.signal_team(_simulation).is_ok).is_true()
	assert_str(String(command.validate(_state).error_code)).is_equal(
		String(SignalTeamCommand.SIGNAL_WAITING)
	)
	var idle: GameState = Fixture.state()
	assert_str(String(command.validate(idle).error_code)).is_equal(
		String(SignalTeamCommand.NO_RESCUE)
	)


func test_closing_early_fails_and_the_player_can_try_again() -> void:
	RescueFixture.signal_team(_simulation)
	Fixture.advance(_simulation, 5)
	_simulation.submit(CloseWormholeCommand.new())
	Fixture.advance(_simulation, ExpeditionRescue.SIGNAL_TICKS)
	assert_int(_state.expedition.mode).is_equal(ExpeditionState.Mode.MISSING)
	assert_int(_state.expedition.signal_tick).is_equal(-1)
	assert_int(_on_roster(_team())).is_equal(4)
	assert_bool(RescueFixture.signal_team(_simulation).is_ok).is_true()


func test_team_comes_through_fifteen_minutes_after_the_signal() -> void:
	var team: Array[StringName] = _team()
	_state.random.stream(ExpeditionSystem.ID).seed = RescueFixture.seed_for(_state, 0, 0)
	RescueFixture.signal_team(_simulation)
	Fixture.advance(_simulation, ExpeditionRescue.SIGNAL_TICKS)
	assert_int(_state.expedition.mode).is_equal(ExpeditionState.Mode.MISSING)
	_simulation.advance_tick()
	assert_int(_state.expedition.mode).is_equal(ExpeditionState.Mode.IDLE)
	assert_int(_on_roster(team)).is_equal(4)
	assert_array(_reasons()).is_equal(["missed", "rescued"])


func test_deceased_leave_with_confidence_and_a_log_line_each() -> void:
	var team: Array[StringName] = _team()
	_state.random.stream(ExpeditionSystem.ID).seed = RescueFixture.seed_for(_state, 0, 2)
	var confidence: int = _state.committee.confidence
	RescueFixture.signal_team(_simulation)
	Fixture.advance(_simulation, ExpeditionRescue.SIGNAL_TICKS + 1)
	assert_int(_on_roster(team)).is_equal(2)
	assert_array(_reasons()).is_equal(["missed", "deceased", "deceased", "rescued"])
	var cause: ConfidenceCause = _state.committee.causes.back()
	assert_str(String(cause.cause)).is_equal(String(ConfidenceRules.DECEASED))
	assert_int(cause.count).is_equal(2)
	assert_int(cause.change).is_equal(-60)
	assert_int(_state.committee.confidence).is_equal(confidence - 60)


func test_nobody_surviving_is_no_answer_and_a_lost_team() -> void:
	var team: Array[StringName] = _team()
	_state.random.stream(ExpeditionSystem.ID).seed = RescueFixture.seed_for(_state, 0, 4)
	RescueFixture.signal_team(_simulation)
	Fixture.advance(_simulation, ExpeditionRescue.SIGNAL_TICKS + 1)
	assert_int(_on_roster(team)).is_equal(0)
	assert_int(_state.expedition.mode).is_equal(ExpeditionState.Mode.IDLE)
	assert_array(_reasons()).is_equal(["missed", "no_answer"])
	var cause: ConfidenceCause = _state.committee.causes.back()
	assert_str(String(cause.cause)).is_equal(String(ConfidenceRules.TEAM_LOST))
	assert_str(ExpeditionLogText.line({"reason": "no_answer"}, "")).is_equal(
		tr(&"LOG_LINE_TEAM_NO_ANSWER")
	)


func test_window_running_out_loses_the_team() -> void:
	var team: Array[StringName] = _team()
	var confidence: int = _state.committee.confidence
	var end: int = ExpeditionRescue.window_end_tick(_state.expedition)
	Fixture.advance(_simulation, end - _state.clock.tick)
	assert_int(_state.expedition.mode).is_equal(ExpeditionState.Mode.MISSING)
	_simulation.advance_tick()
	assert_int(_state.expedition.mode).is_equal(ExpeditionState.Mode.IDLE)
	assert_int(_on_roster(team)).is_equal(0)
	assert_int(_state.committee.confidence).is_equal(confidence - 100)
	assert_array(_reasons()).is_equal(["missed", "lost"])
	assert_array(_state.staff.lent_due).has_size(1)


func test_rolls_are_the_same_after_save_and_load() -> void:
	Fixture.advance(_simulation, DAY + 30)
	var data: Dictionary = JSON.parse_string(JSON.stringify(_state.to_dict()))
	var loaded: GameState = GameState.from_dict(data)
	loaded.balance = _state.balance
	loaded.galaxy = _state.galaxy
	loaded.room_defs = _state.room_defs
	var other: Simulation = RescueFixture.simulation(loaded, 0)
	for simulation: Simulation in [_simulation, other]:
		RescueFixture.signal_team(simulation)
		Fixture.advance(simulation, ExpeditionRescue.SIGNAL_TICKS + 1)
	var names: Array[String] = []
	var loaded_names: Array[String] = []
	for person: PersonState in _state.staff.people:
		names.append(person.name)
	for person: PersonState in loaded.staff.people:
		loaded_names.append(person.name)
	assert_array(loaded_names).is_equal(names)
	assert_int(loaded.committee.confidence).is_equal(_state.committee.confidence)
