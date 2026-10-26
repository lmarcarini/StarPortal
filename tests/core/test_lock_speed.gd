## Tests for the lock speed rule: a dial that resolves into a lock or hostile lock drops a
## clock faster than 1× to 1×; 0.5×, pause and holds are left alone, other outcomes never
## change the speed, and the player can speed up again while the wormhole is open.
## Bible: game-design.md#time-real-time-with-pause,
## gate-and-address-spec.md#the-dialing-sequence-and-an-open-wormhole
extends GdUnitTestSuite

const DialFixture := preload("res://tests/gate/dial_fixture.gd")

const HALF: int = 0
const NORMAL: int = ClockState.NORMAL_SPEED_INDEX
const FAST: int = 2
const FASTEST: int = 3

var _state: GameState
var _simulation: Simulation


func before_test() -> void:
	_state = DialFixture.state(null, false)
	_simulation = DialFixture.simulation(_state)


## Dials world [param id] at speed index [param speed] and runs the dial to its end.
func _dial(id: StringName, speed: int) -> void:
	_state.clock.speed_index = speed
	var address: GateAddress = _address(id)
	assert_bool(_simulation.submit(DialCommand.create(address)).is_ok).is_true()
	_advance(_state.balance.dial_duration_ticks)


## The fixture address of [param id]; &"" is the home Ring's own address (No gate).
func _address(id: StringName) -> GateAddress:
	var galaxy: GalaxyCatalogue = _state.galaxy
	if id.is_empty():
		return galaxy.address_of(galaxy.home().id, galaxy.home().origin_glyph)
	return DialFixture.address_of(galaxy, id)


func _advance(ticks: int) -> void:
	for index: int in ticks:
		_simulation.advance_tick()


func test_normal_speed_index_is_one_times() -> void:
	assert_float(SimClock.SPEEDS[ClockState.NORMAL_SPEED_INDEX]).is_equal(1.0)


func test_lock_drops_ten_and_three_times_to_one_times() -> void:
	for speed: int in [FASTEST, FAST]:
		before_test()
		_dial(DialFixture.OPEN_ID, speed)
		assert_int(_state.gate.mode).is_equal(GateState.RingMode.LOCKED)
		assert_int(_state.clock.speed_index).is_equal(NORMAL)


func test_hostile_lock_drops_to_one_times() -> void:
	_dial(DialFixture.GUARDED_ID, FASTEST)
	assert_bool(_state.gate.is_hostile).is_true()
	assert_int(_state.clock.speed_index).is_equal(NORMAL)


func test_lock_leaves_one_times_and_half_speed_alone() -> void:
	for speed: int in [NORMAL, HALF]:
		before_test()
		_dial(DialFixture.OPEN_ID, speed)
		assert_int(_state.gate.mode).is_equal(GateState.RingMode.LOCKED)
		assert_int(_state.clock.speed_index).is_equal(speed)


func test_no_gate_and_blocked_never_change_speed() -> void:
	for id: StringName in [&"", DialFixture.BURIED_ID]:
		for speed: int in [FASTEST, FAST, HALF]:
			before_test()
			_dial(id, speed)
			assert_int(_state.gate.mode).is_equal(GateState.RingMode.IDLE)
			assert_int(_state.clock.speed_index).is_equal(speed)


## The drop happens on the resolving tick and does not touch the mode.
func test_lock_changes_speed_only_on_the_resolving_tick() -> void:
	_state.clock.speed_index = FASTEST
	(
		assert_bool(_simulation.submit(DialCommand.create(_address(DialFixture.OPEN_ID))).is_ok)
		. is_true()
	)
	_advance(_state.balance.dial_duration_ticks - 1)
	assert_int(_state.gate.mode).is_equal(GateState.RingMode.DIALING)
	assert_int(_state.clock.speed_index).is_equal(FASTEST)
	_advance(1)
	assert_int(_state.gate.mode).is_equal(GateState.RingMode.LOCKED)
	assert_int(_state.clock.speed_index).is_equal(NORMAL)
	assert_int(_state.clock.mode).is_equal(ClockState.Mode.RUNNING)


## A hold in force while the lock resolves (the dial was stepped by a tool) stays in force.
func test_lock_leaves_hold_and_pause_alone() -> void:
	_state.clock.speed_index = FASTEST
	(
		assert_bool(_simulation.submit(DialCommand.create(_address(DialFixture.OPEN_ID))).is_ok)
		. is_true()
	)
	TimeControl.add_hold(_state.clock, &"cutscene")
	_advance(_state.balance.dial_duration_ticks)
	assert_int(_state.gate.mode).is_equal(GateState.RingMode.LOCKED)
	assert_int(_state.clock.speed_index).is_equal(NORMAL)
	assert_int(_state.clock.mode).is_equal(ClockState.Mode.HELD)
	assert_array(_state.clock.holds).is_equal([&"cutscene"])


func test_speeding_up_while_open_is_kept_until_the_next_lock() -> void:
	_dial(DialFixture.OPEN_ID, FASTEST)
	_state.clock.speed_index = FASTEST
	_advance(10)
	assert_int(_state.gate.mode).is_equal(GateState.RingMode.LOCKED)
	assert_int(_state.clock.speed_index).is_equal(FASTEST)
	assert_bool(_simulation.submit(CloseWormholeCommand.new()).is_ok).is_true()
	_advance(1)
	assert_int(_state.gate.mode).is_equal(GateState.RingMode.IDLE)
	assert_int(_state.clock.speed_index).is_equal(FASTEST)
	_dial(DialFixture.OPEN_ID, FAST)
	assert_int(_state.gate.mode).is_equal(GateState.RingMode.LOCKED)
	assert_int(_state.clock.speed_index).is_equal(NORMAL)
