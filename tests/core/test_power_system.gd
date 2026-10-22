## Tests for PowerSystem: the placeholder plant charging the bank and the open drain.
## Bible: gate-and-address-spec.md#dialing-outcomes-and-energy,
## game-design.md#base-building-and-power
extends GdUnitTestSuite

const TOLERANCE: float = 1e-9

var _balance: BalanceConfig
var _system: PowerSystem
var _state: GameState


func before_test() -> void:
	_balance = BalanceConfig.new()
	_system = PowerSystem.new(_balance)
	_state = GameState.new_game(1, _balance)


func _tick(count: int) -> void:
	for index: int in count:
		_system.tick(_state)


func _lock_ring() -> void:
	_state.gate.mode = GateState.RingMode.LOCKED


## The system's id is power.
func test_id() -> void:
	assert_str(String(_system.get_id())).is_equal("power")


## An empty 400 MWh bank with 30 MW and an idle Ring holds 300 MWh after 10 hours.
func test_idle_ring_charges_the_bank() -> void:
	_tick(600)
	assert_float(_state.power.stored_mwh).is_equal_approx(300.0, TOLERANCE)


## The bank stops at its capacity, exactly.
func test_bank_stops_at_capacity() -> void:
	_tick(800)
	assert_float(_state.power.stored_mwh).is_equal(400.0)
	_tick(500)
	assert_float(_state.power.stored_mwh).is_equal(400.0)


## While LOCKED the 20 MW drain comes out of the output first: the bank gains 10 MW worth.
func test_locked_ring_drain_comes_from_output_first() -> void:
	_lock_ring()
	_tick(60)
	assert_float(_state.power.stored_mwh).is_equal_approx(10.0, TOLERANCE)


## An output below the drain makes the bank lose the difference, and it stops at 0.
func test_drain_above_output_empties_the_bank_and_stops_at_zero() -> void:
	_state.power.stored_mwh = 100.0
	_state.power.plant_output_mw = 5.0
	_lock_ring()
	_tick(60)
	assert_float(_state.power.stored_mwh).is_equal_approx(85.0, TOLERANCE)
	_tick(60 * 7)
	assert_float(_state.power.stored_mwh).is_equal(0.0)
	_tick(120)
	assert_float(_state.power.stored_mwh).is_equal(0.0)


## DIALING does not drain: only an open wormhole does.
func test_dialing_ring_does_not_drain() -> void:
	_state.gate.mode = GateState.RingMode.DIALING
	_tick(60)
	assert_float(_state.power.stored_mwh).is_equal_approx(30.0, TOLERANCE)


## Closing the wormhole ends the drain.
func test_drain_follows_the_ring_mode() -> void:
	_lock_ring()
	_tick(60)
	_state.gate.mode = GateState.RingMode.IDLE
	_tick(60)
	assert_float(_state.power.stored_mwh).is_equal_approx(40.0, TOLERANCE)


## Zero capacity or zero output never produces NaN or infinity.
func test_zero_capacity_and_zero_output_stay_finite() -> void:
	_state.power.capacity_mwh = 0.0
	_tick(10)
	assert_float(_state.power.stored_mwh).is_equal(0.0)
	_state.power = PowerState.starting(_balance)
	_state.power.plant_output_mw = 0.0
	_tick(10)
	assert_float(_state.power.stored_mwh).is_equal(0.0)
	_lock_ring()
	_tick(10)
	assert_float(_state.power.stored_mwh).is_equal(0.0)
	assert_bool(is_finite(_state.power.stored_mwh)).is_true()


## The system posts no events.
func test_posts_no_events() -> void:
	_lock_ring()
	_tick(5)
	assert_bool(_state.events.size() == 0).is_true()
