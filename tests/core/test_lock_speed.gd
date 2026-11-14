## Event time at the gate (M4.7-04): the dial slows the clock from the first seal to the lock
## or failure (dialling), a lock never changes the speed, operating the gate slows it
## (gate_ops) and Stand by or the wormhole closing gives cruise speed back.
## Bible: docs/content/event-time.md section 3
extends GdUnitTestSuite

const DialFixture := preload("res://tests/gate/dial_fixture.gd")

const FASTEST: int = 3

var _state: GameState
var _simulation: Simulation


func before_test() -> void:
	_state = DialFixture.state(null, false)
	_simulation = DialFixture.simulation(_state)
	_state.clock.speed_index = FASTEST


func _effective() -> int:
	return TimeControl.effective_speed_index(_state.clock)


func _address(id: StringName) -> GateAddress:
	var galaxy: GalaxyCatalogue = _state.galaxy
	if id.is_empty():
		return galaxy.address_of(galaxy.home().id, galaxy.home().origin_glyph)
	return DialFixture.address_of(galaxy, id)


func _advance(ticks: int) -> void:
	for index: int in ticks:
		_simulation.advance_tick()


func _submit(command: Command) -> bool:
	return _simulation.submit(command).is_ok


func test_normal_speed_index_is_one_times() -> void:
	assert_float(SimClock.SPEEDS[ClockState.NORMAL_SPEED_INDEX]).is_equal(1.0)


func test_the_dial_is_slow_until_it_resolves() -> void:
	for id: StringName in [DialFixture.OPEN_ID, DialFixture.BURIED_ID, &""]:
		before_test()
		assert_bool(_submit(DialCommand.create(_address(id)))).is_true()
		_advance(1)
		assert_int(_state.gate.mode).is_equal(GateState.RingMode.DIALING)
		assert_int(_effective()).is_equal(ClockState.NORMAL_SPEED_INDEX)
		_advance(_state.balance.dial_duration_ticks)
		assert_int(_effective()).is_equal(FASTEST)
		assert_int(_state.clock.speed_index).is_equal(FASTEST)


func test_operate_and_stand_by() -> void:
	assert_bool(_submit(OperateGateCommand.new())).is_false()
	assert_bool(_submit(DialCommand.create(_address(DialFixture.OPEN_ID)))).is_true()
	_advance(_state.balance.dial_duration_ticks + 1)
	assert_int(_state.gate.mode).is_equal(GateState.RingMode.LOCKED)
	assert_bool(_submit(StandByCommand.new())).is_false()
	assert_bool(_submit(OperateGateCommand.new())).is_true()
	_advance(1)
	assert_bool(_state.gate.operating).is_true()
	assert_int(_effective()).is_equal(ClockState.NORMAL_SPEED_INDEX)
	assert_bool(_submit(StandByCommand.new())).is_true()
	_advance(1)
	assert_int(_effective()).is_equal(FASTEST)
	assert_int(_state.gate.mode).is_equal(GateState.RingMode.LOCKED)


func test_closing_the_wormhole_stops_operating() -> void:
	assert_bool(_submit(DialCommand.create(_address(DialFixture.OPEN_ID)))).is_true()
	_advance(_state.balance.dial_duration_ticks + 1)
	assert_bool(_submit(OperateGateCommand.new())).is_true()
	_advance(1)
	RingControl.close(_state.gate)
	_advance(1)
	assert_bool(_state.gate.operating).is_false()
	assert_int(_effective()).is_equal(FASTEST)


func test_operating_is_saved() -> void:
	var gate := GateState.new()
	gate.operating = true
	assert_bool(GateState.from_dict(gate.to_dict()).operating).is_true()
