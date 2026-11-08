## Tests for the team away (ExpeditionSystem, ExpeditionReturns): it is out of its rooms and
## recovers nothing until it returns, after the objective's days, to the rooms it kept; a Survey
## makes the world Surveyed with Confidence +3 once, threat and biohazard GOOD and a report; a
## Recover marks its target recovered (the anchor sets anchor_recovered); a failed one leaves
## the target recoverable. Check-ins fall every 24 hours from departure, the return last.
## Bible: docs/content/m3-beyond-the-ring.md section 4
extends GdUnitTestSuite

const Fixture := preload("res://tests/expedition/expedition_fixture.gd")
const ProbeFixture := preload("res://tests/gate/probe_fixture.gd")
const DAY: int = TimeMath.TICKS_PER_DAY

var _state: GameState
var _simulation: Simulation


func before_test() -> void:
	_state = Fixture.state()
	_simulation = Fixture.simulation(_state)


func _send(plan: PlanExpeditionCommand) -> void:
	assert_bool(_simulation.submit(plan).is_ok).is_true()
	ProbeFixture.open(_simulation)
	assert_bool(_simulation.submit(SendTeamCommand.new()).is_ok).is_true()


func _assigned_member() -> PersonState:
	for person_id: StringName in _state.expedition.member_ids():
		var person: PersonState = _state.staff.find_person(person_id)
		if person.is_assigned():
			return person
	return null


func test_team_out_of_its_room_and_back_on_return() -> void:
	_send(Fixture.survey(_state))
	var member: PersonState = _assigned_member()
	assert_object(member).is_not_null()
	var room: RoomState = _state.base.find_room(member.room_id)
	assert_bool(StaffRules.working(_state, room).has(member)).is_false()
	assert_bool(StaffRules.assigned(_state, room).has(member)).is_true()
	var departed: int = _state.expedition.departed_tick
	assert_array(_state.expedition.check_in_ticks()).is_equal([departed + DAY, departed + 2 * DAY])
	Fixture.advance(_simulation, departed + 2 * DAY - _state.clock.tick)
	assert_int(_state.expedition.mode).is_equal(ExpeditionState.Mode.AWAY)
	assert_int(_state.expedition.day_results.size()).is_equal(1)
	_simulation.advance_tick()
	assert_int(_state.expedition.mode).is_equal(ExpeditionState.Mode.IDLE)
	assert_str(String(member.room_id)).is_equal(String(room.id))
	assert_bool(StaffRules.working(_state, room).has(member)).is_true()


func test_survey_brings_back_state_report_and_confidence() -> void:
	var confidence: int = _state.committee.confidence
	_send(Fixture.survey(_state))
	Fixture.advance(_simulation, 2 * DAY + 1)
	assert_int(_state.worlds.status_of(Fixture.WORLD_ID)).is_equal(
		WorldsState.WorldStatus.SURVEYED
	)
	var report: WorldReport = _state.worlds.report_of(Fixture.WORLD_ID)
	assert_int(report.confidence_of(WorldReport.Fact.THREAT)).is_equal(WorldReport.Confidence.GOOD)
	assert_int(report.confidence_of(WorldReport.Fact.BIOHAZARD)).is_equal(
		WorldReport.Confidence.GOOD
	)
	assert_int(_state.expedition.documents.size()).is_equal(1)
	assert_str(_state.expedition.documents[0]["kind"]).is_equal("survey_report")
	var cause: ConfidenceCause = _state.committee.causes.back()
	assert_str(String(cause.cause)).is_equal("surveyed")
	assert_int(cause.change).is_equal(30)
	assert_bool(_state.committee.confidence >= confidence + 29).is_true()
	var after: int = _state.committee.confidence
	_send(Fixture.survey(_state))
	Fixture.advance(_simulation, 2 * DAY + 1)
	assert_bool(_state.committee.confidence < after + 30).is_true()


func test_recover_marks_target_recovered() -> void:
	WorldProgress.raise_target(
		_state, Fixture.WORLD_ID, Fixture.ANCHOR_ID, TargetStates.State.RECOVERABLE
	)
	_send(Fixture.recover(_state))
	assert_array(_state.expedition.check_in_ticks()).has_size(1)
	Fixture.advance(_simulation, DAY + 1)
	assert_int(_state.worlds.targets.state_of(Fixture.WORLD_ID, Fixture.ANCHOR_ID)).is_equal(
		TargetStates.State.RECOVERED
	)
	assert_str(_state.expedition.documents[0]["kind"]).is_equal("object")
	assert_bool(_state.flags.has(ExpeditionReturns.ANCHOR_FLAG)).is_false()


func test_failed_recover_leaves_the_target() -> void:
	WorldProgress.raise_target(
		_state, Fixture.WORLD_ID, Fixture.ANCHOR_ID, TargetStates.State.RECOVERABLE
	)
	_send(Fixture.recover(_state))
	_state.expedition.day_results.append(ExpeditionState.DAY_WASTED)
	var rng := RandomNumberGenerator.new()
	assert_bool(ExpeditionReturns.apply(_state, rng)).is_false()
	assert_bool(_state.worlds.targets.is_recoverable(Fixture.WORLD_ID, Fixture.ANCHOR_ID)).is_true()
	assert_array(_state.expedition.documents).is_empty()


func test_recovering_the_anchor_sets_the_flag() -> void:
	var world: StringName = ExpeditionReturns.ANCHOR_WORLD_ID
	var target: StringName = ExpeditionReturns.ANCHOR_TARGET_ID
	WorldProgress.raise_target(_state, world, target, TargetStates.State.RECOVERABLE)
	_state.expedition.set_plan(
		ExpeditionState.Objective.RECOVER, world, target, Fixture.team(_state)
	)
	assert_bool(ExpeditionReturns.apply(_state, RandomNumberGenerator.new())).is_true()
	assert_bool(_state.flags[ExpeditionReturns.ANCHOR_FLAG]).is_true()
	assert_int(_state.worlds.targets.state_of(world, target)).is_equal(
		TargetStates.State.RECOVERED
	)


func test_team_does_not_recover_from_injuries_away() -> void:
	_send(Fixture.survey(_state))
	var member: PersonState = _state.staff.find_person(_state.expedition.member_ids()[0])
	InjuryRules.injure(member, PersonState.Injury.LIGHT)
	var left: int = member.recovery_left
	Fixture.advance(_simulation, DAY)
	assert_int(member.recovery_left).is_equal(left)
	Fixture.advance(_simulation, DAY + 1)
	assert_int(_state.expedition.mode).is_equal(ExpeditionState.Mode.IDLE)
	Fixture.advance(_simulation, 1)
	assert_bool(member.recovery_left < left).is_true()


func test_plan_refused_while_away() -> void:
	_send(Fixture.survey(_state))
	var result: CommandResult = Fixture.survey(_state).validate(_state)
	assert_str(String(result.error_code)).is_equal("expedition_away")
