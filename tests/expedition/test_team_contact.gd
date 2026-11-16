## Tests for talking to a team only through an open gate (M4.9-11): hail and Carry on, hail
## and Come home now, the team's distress call and Come through, a closed Shutter opening for
## the team's code, overdue then a rescue.
## Bible: docs/content/interface-rethink.md section 4; m3-beyond-the-ring.md section 4
extends GdUnitTestSuite

const Fixture := preload("res://tests/expedition/expedition_fixture.gd")
const RescueFixture := preload("res://tests/expedition/rescue_fixture.gd")
const ProbeFixture := preload("res://tests/gate/probe_fixture.gd")
const DAY: int = TimeMath.TICKS_PER_DAY

var _state: GameState
var _events: Array[StringName] = []


func before_test() -> void:
	_state = Fixture.state()
	_events.clear()


func _simulation(missed_day: int = -1) -> Simulation:
	var simulation: Simulation = RescueFixture.simulation(_state, missed_day)
	simulation.event_posted.connect(func(name: StringName, _a: Array) -> void: _events.append(name))
	return simulation


func _send_and_close(simulation: Simulation) -> void:
	RescueFixture.send(simulation)
	simulation.submit(CloseWormholeCommand.new())


func test_hail_needs_an_open_wormhole_to_the_team() -> void:
	var simulation: Simulation = _simulation()
	_send_and_close(simulation)
	assert_bool(HailTeamCommand.new().validate(_state).is_ok).is_false()
	Fixture.advance(simulation, DAY + 5)
	ProbeFixture.open(simulation)
	assert_bool(simulation.submit(HailTeamCommand.new()).is_ok).is_true()
	assert_bool(_events.has(&"team_hailed")).is_true()
	assert_int(_state.expedition.heard_days).is_equal(1)
	var carry: OrderTeamCommand = OrderTeamCommand.create(TeamContactRules.Order.CARRY_ON)
	assert_bool(simulation.submit(carry).is_ok).is_true()
	assert_int(_state.expedition.mode).is_equal(ExpeditionState.Mode.AWAY)


func test_hail_and_come_home_now() -> void:
	var simulation: Simulation = _simulation()
	_send_and_close(simulation)
	Fixture.advance(simulation, 60)
	ProbeFixture.open(simulation)
	simulation.submit(HailTeamCommand.new())
	var home: OrderTeamCommand = OrderTeamCommand.create(TeamContactRules.Order.COME_HOME)
	assert_bool(simulation.submit(home).is_ok).is_true()
	simulation.advance_tick()
	assert_int(_state.expedition.mode).is_equal(ExpeditionState.Mode.IDLE)
	assert_bool(_events.has(ExpeditionSystem.RETURNED_EVENT)).is_true()


func test_stay_longer_moves_the_return() -> void:
	var simulation: Simulation = _simulation()
	_send_and_close(simulation)
	ProbeFixture.open(simulation)
	var before: int = TeamContactRules.due_tick_of(_state.expedition)
	simulation.submit(HailTeamCommand.new())
	simulation.submit(OrderTeamCommand.create(TeamContactRules.Order.STAY_LONGER))
	assert_int(TeamContactRules.due_tick_of(_state.expedition)).is_equal(before + DAY)


func test_distress_and_come_through() -> void:
	var simulation: Simulation = _simulation(0)
	_send_and_close(simulation)
	_state.gate.shutter = GateState.Shutter.CLOSED
	Fixture.advance(simulation, DAY + 3)
	assert_bool(_state.gate.has_incoming()).is_true()
	var stored: float = _state.power.stored_mwh
	assert_bool(simulation.submit(AnswerIncomingCommand.new()).is_ok).is_true()
	assert_int(_state.gate.shutter).is_equal(GateState.Shutter.OPEN)
	assert_bool(TeamContactRules.is_team_call(_state)).is_true()
	var through: OrderTeamCommand = OrderTeamCommand.create(TeamContactRules.Order.COME_THROUGH)
	assert_bool(simulation.submit(through).is_ok).is_true()
	Fixture.advance(simulation, ExpeditionRescue.SIGNAL_TICKS + 2)
	assert_int(_state.expedition.mode).is_equal(ExpeditionState.Mode.IDLE)
	assert_int(_state.gate.mode).is_equal(GateState.RingMode.IDLE)
	assert_float(_state.power.stored_mwh).is_greater_equal(stored)


func test_overdue_then_rescue() -> void:
	var simulation: Simulation = _simulation(0)
	_send_and_close(simulation)
	Fixture.advance(simulation, DAY + 3)
	simulation.submit(IgnoreIncomingCommand.new())
	assert_bool(_state.expedition.calling).is_false()
	Fixture.advance(simulation, DAY + TeamContactRules.GRACE_TICKS + 5)
	assert_bool(_state.expedition.overdue).is_true()
	assert_bool(_events.has(&"team_overdue")).is_true()
	assert_bool(RescueFixture.signal_team(simulation).is_ok).is_true()
	Fixture.advance(simulation, ExpeditionRescue.SIGNAL_TICKS + 2)
	assert_int(_state.expedition.mode).is_equal(ExpeditionState.Mode.IDLE)
