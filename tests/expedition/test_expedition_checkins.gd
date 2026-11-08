## Tests for check-ins (ExpeditionSystem): a check-in that is not the return posts its message
## and writes a Log line without pausing; one due while CAIRN's wormhole is open comes when it
## closes; Recall team makes the next check-in the return; a missed check-in (the field-event
## hook, ExpeditionState.DAY_MISSED) pauses, sets the speed to 1× and opens the rescue window.
## Bible: docs/content/m3-beyond-the-ring.md section 4
extends GdUnitTestSuite

const Fixture := preload("res://tests/expedition/expedition_fixture.gd")
const RescueFixture := preload("res://tests/expedition/rescue_fixture.gd")
const ProbeFixture := preload("res://tests/gate/probe_fixture.gd")
const DAY: int = TimeMath.TICKS_PER_DAY

var _state: GameState
var _events: Array[StringName] = []
var _pauses: Array[StringName] = []


func before_test() -> void:
	_state = Fixture.state()
	_events.clear()
	_pauses.clear()


func _simulation(missed_day: int = -1) -> Simulation:
	var simulation: Simulation = RescueFixture.simulation(_state, missed_day)
	simulation.event_posted.connect(func(name: StringName, _a: Array) -> void: _events.append(name))
	simulation.pause_requested.connect(func(reason: StringName) -> void: _pauses.append(reason))
	return simulation


func _expedition_lines() -> Array[String]:
	var reasons: Array[String] = []
	for entry: LogEntry in _state.operations_log.entries:
		if entry.kind == &"expedition":
			reasons.append(str(entry.args["reason"]))
	return reasons


func test_check_in_posts_and_logs_without_pausing() -> void:
	var simulation: Simulation = _simulation()
	RescueFixture.send(simulation)
	var member: PersonState = _state.staff.find_person(_state.expedition.member_ids()[2])
	InjuryRules.injure(member, PersonState.Injury.LIGHT)
	_state.clock.speed_index = 3
	Fixture.advance(simulation, _state.expedition.next_day_end_tick() - _state.clock.tick + 1)
	assert_bool(_events.has(ExpeditionSystem.CHECKED_IN_EVENT)).is_true()
	assert_array(_pauses).is_empty()
	assert_int(_state.clock.speed_index).is_equal(3)
	assert_array(_expedition_lines()).is_equal(["departed", "checked_in"])
	var entry: LogEntry = _state.operations_log.entries.back()
	assert_int(entry.args["light"]).is_equal(1)
	assert_str(ExpeditionLogText.injuries(entry.args)).is_equal(tr(&"TEAM_INJURY_LIGHT_ONE"))
	assert_int(_state.expedition.mode).is_equal(ExpeditionState.Mode.AWAY)


func test_check_in_waits_while_the_wormhole_is_open() -> void:
	var simulation: Simulation = _simulation()
	RescueFixture.send(simulation)
	var due: int = _state.expedition.next_day_end_tick()
	Fixture.advance(simulation, due - _state.clock.tick - 5)
	ProbeFixture.open(simulation)
	Fixture.advance(simulation, 10)
	assert_int(_state.expedition.day_results.size()).is_equal(0)
	simulation.submit(CloseWormholeCommand.new())
	simulation.advance_tick()
	assert_int(_state.expedition.day_results.size()).is_equal(1)


func test_recall_turns_the_next_check_in_into_the_return() -> void:
	var simulation: Simulation = _simulation()
	assert_str(String(RecallTeamCommand.new().validate(_state).error_code)).is_equal(
		String(RecallTeamCommand.NOT_AWAY)
	)
	RescueFixture.send(simulation)
	assert_bool(simulation.submit(RecallTeamCommand.new()).is_ok).is_true()
	assert_str(String(RecallTeamCommand.new().validate(_state).error_code)).is_equal(
		String(RecallTeamCommand.ALREADY_RECALLED)
	)
	Fixture.advance(simulation, DAY + 1)
	assert_int(_state.expedition.mode).is_equal(ExpeditionState.Mode.IDLE)
	assert_bool(_events.has(ExpeditionSystem.RETURNED_EVENT)).is_true()
	assert_bool(_events.has(ExpeditionSystem.CHECKED_IN_EVENT)).is_false()
	assert_array(_expedition_lines()).is_equal(["departed", "returned", "prologue"])
	assert_int(_state.worlds.status_of(Fixture.WORLD_ID)).is_equal(WorldsState.WorldStatus.PROBED)
	assert_array(_state.expedition.documents).is_empty()


func test_missed_check_in_pauses_at_normal_speed_and_opens_the_window() -> void:
	var simulation: Simulation = _simulation(0)
	RescueFixture.send(simulation)
	_state.clock.speed_index = 3
	var due: int = _state.expedition.next_day_end_tick()
	Fixture.advance(simulation, due - _state.clock.tick + 1)
	var plan: ExpeditionState = _state.expedition
	assert_int(plan.mode).is_equal(ExpeditionState.Mode.MISSING)
	assert_int(plan.missed_tick).is_equal(due)
	assert_array(_pauses).is_equal([ExpeditionRescue.PAUSE_REASON])
	assert_int(_state.clock.speed_index).is_equal(ClockState.NORMAL_SPEED_INDEX)
	assert_bool(_events.has(ExpeditionSystem.CHECKED_IN_EVENT)).is_false()
	assert_array(_expedition_lines()).is_equal(["departed", "missed"])
	assert_array(plan.away_ids()).has_size(4)
	assert_str(String(Fixture.survey(_state).validate(_state).error_code)).is_equal(
		String(ExpeditionRules.BUSY)
	)


func test_missed_return_opens_the_window() -> void:
	var simulation: Simulation = _simulation(1)
	RescueFixture.send(simulation)
	Fixture.advance(simulation, 2 * DAY + 1)
	assert_int(_state.expedition.mode).is_equal(ExpeditionState.Mode.MISSING)
	assert_bool(_events.has(ExpeditionSystem.RETURNED_EVENT)).is_false()
	assert_int(_state.worlds.status_of(Fixture.WORLD_ID)).is_equal(WorldsState.WorldStatus.PROBED)


func test_only_a_missed_check_in_pauses() -> void:
	var simulation: Simulation = _simulation()
	RescueFixture.send(simulation)
	Fixture.advance(simulation, 2 * DAY + 1)
	assert_int(_state.expedition.mode).is_equal(ExpeditionState.Mode.IDLE)
	assert_array(_pauses).is_empty()
