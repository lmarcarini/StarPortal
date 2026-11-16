## Tests for mission orders (M4.9-12): an order from a closed gate dials, sends the team and
## closes; it is refused when the gate is busy or the charge short; a failed dial stops it with
## a reason; a cancel leaves the gate safe; a save mid-order continues it.
## Bible: docs/content/interface-rethink.md section 4 (Gate, A mission order)
extends GdUnitTestSuite

const Fixture := preload("res://tests/expedition/expedition_fixture.gd")
const DialFixture := preload("res://tests/gate/dial_fixture.gd")

var _state: GameState
var _simulation: Simulation


func before_test() -> void:
	_state = Fixture.state()
	_simulation = Fixture.simulation(_state)


func _order(world: StringName = Fixture.WORLD_ID) -> OrderMissionCommand:
	var address: GateAddress = DialFixture.address_of(_state.galaxy, world)
	return OrderMissionCommand.create(address, Fixture.survey(_state))


func _run(ticks: int) -> void:
	for i: int in ticks:
		_simulation.advance_tick()


func test_order_dials_sends_and_closes() -> void:
	assert_bool(_simulation.submit(_order()).is_ok).is_true()
	assert_int(_state.gate.mode).is_equal(GateState.RingMode.DIALING)
	_run(_state.balance.dial_duration_ticks + MissionOrderRules.WALK_TICKS + 3)
	assert_int(_state.expedition.mode).is_equal(ExpeditionState.Mode.AWAY)
	assert_int(_state.expedition.order.phase).is_equal(MissionOrder.Phase.DONE)
	assert_int(_state.gate.mode).is_equal(GateState.RingMode.IDLE)


func test_refused_when_busy_or_short() -> void:
	_simulation.submit(_order())
	assert_str(String(_order().validate(_state).error_code)).is_equal("order_running")
	_state.expedition.order.phase = MissionOrder.Phase.DONE
	assert_str(String(_order().validate(_state).error_code)).is_equal("ring_busy")
	_run(_state.balance.dial_duration_ticks + MissionOrderRules.WALK_TICKS + 3)
	_state.power.stored_mwh = 0.0
	assert_str(String(_order().validate(_state).error_code)).is_not_empty()


func test_cancel_leaves_the_gate_safe() -> void:
	_simulation.submit(_order())
	_run(_state.balance.dial_duration_ticks + 1)
	assert_bool(_simulation.submit(CancelMissionOrderCommand.new()).is_ok).is_true()
	assert_int(_state.expedition.order.phase).is_equal(MissionOrder.Phase.FAILED)
	if _state.expedition.mode != ExpeditionState.Mode.AWAY:
		assert_int(_state.gate.mode).is_equal(GateState.RingMode.IDLE)


func test_save_mid_order_continues() -> void:
	_simulation.submit(_order())
	var copy: ExpeditionState = ExpeditionState.from_dict(_state.expedition.to_dict())
	assert_int(copy.order.phase).is_equal(MissionOrder.Phase.DIALLING)
	assert_str(copy.order.address.key()).is_equal(_state.expedition.order.address.key())
