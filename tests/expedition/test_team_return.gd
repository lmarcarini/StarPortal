## Tests for a team seen coming home (M4.9-13): the return opens a friendly incoming
## wormhole for a few ticks (no charge, no answer awaited, the Shutter opens), the chip says
## TEAM RETURNING, the wormhole closes, and a debrief says what happened, including Come home
## now and a lost team.
## Bible: docs/content/interface-rethink.md section 4 (Gate, Teams come home)
extends GdUnitTestSuite

const Fixture := preload("res://tests/expedition/expedition_fixture.gd")
const RescueFixture := preload("res://tests/expedition/rescue_fixture.gd")
const ProbeFixture := preload("res://tests/gate/probe_fixture.gd")
const DAY: int = TimeMath.TICKS_PER_DAY

var _state: GameState
var _summaries: Array[Dictionary] = []


func before_test() -> void:
	_state = Fixture.state()
	_summaries.clear()


func _simulation() -> Simulation:
	var simulation: Simulation = RescueFixture.simulation(_state)
	simulation.event_posted.connect(
		func(name: StringName, args: Array) -> void:
			if name == &"team_debrief":
				_summaries.append(args[1])
	)
	return simulation


func test_return_holds_a_friendly_wormhole() -> void:
	var simulation: Simulation = _simulation()
	RescueFixture.send(simulation)
	simulation.submit(CloseWormholeCommand.new())
	_state.gate.shutter = GateState.Shutter.CLOSED
	Fixture.advance(simulation, 2 * DAY + 1)
	assert_int(_state.expedition.mode).is_equal(ExpeditionState.Mode.IDLE)
	assert_bool(TeamContactRules.is_team_call(_state)).is_true()
	assert_int(_state.gate.shutter).is_equal(GateState.Shutter.OPEN)
	assert_str(String(TopBarText.gate_status(_state))).is_equal("returning")
	var stored: float = _state.power.stored_mwh
	Fixture.advance(simulation, TeamContactRules.RETURN_TICKS + 1)
	assert_int(_state.gate.mode).is_equal(GateState.RingMode.IDLE)
	assert_float(_state.power.stored_mwh).is_greater_equal(stored)
	assert_int(_summaries.size()).is_equal(1)
	var debrief: DebriefRules.Debrief = DebriefRules.of_return(
		_state, Fixture.WORLD_ID, _summaries[0]
	)
	assert_int(debrief.outcome).is_equal(DebriefRules.Outcome.SUCCESS)
	assert_int(debrief.people.size()).is_equal(4)
	assert_array(debrief.findings).contains([&"surveyed"])


func test_come_home_now_debrief_says_so() -> void:
	var simulation: Simulation = _simulation()
	RescueFixture.send(simulation)
	simulation.submit(HailTeamCommand.new())
	simulation.submit(OrderTeamCommand.create(TeamContactRules.Order.COME_HOME))
	simulation.advance_tick()
	assert_int(_summaries.size()).is_equal(1)
	var debrief: DebriefRules.Debrief = DebriefRules.of_return(
		_state, Fixture.WORLD_ID, _summaries[0]
	)
	assert_int(debrief.outcome).is_equal(DebriefRules.Outcome.EARLY)


func test_lost_team_gets_a_card() -> void:
	assert_int(DebriefRules.of_end(&"w", true).outcome).is_equal(DebriefRules.Outcome.LOST)
