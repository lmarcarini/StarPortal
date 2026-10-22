## Tests for an open wormhole: it drains through PowerSystem and closes after max_open_ticks
## (&"timeout"), on CloseWormholeCommand (&"player"), and when storage is empty under a drain
## larger than the plant output (&"power").
## Bible: gate-and-address-spec.md#dialing-outcomes-and-energy,
## game-design.md#time-real-time-with-pause
extends GdUnitTestSuite

const DialFixture := preload("res://tests/gate/dial_fixture.gd")
const TOLERANCE: float = 1e-6

var _state: GameState
var _simulation: Simulation
## Every wormhole_closed reason, with the clock tick when emitted.
var _closes: Array[Array] = []


## Opens a wormhole to the open fixture world, leaving the clock running at the lock tick.
func before_test() -> void:
	_state = DialFixture.state(null, true)
	_simulation = DialFixture.simulation(_state)
	_closes.clear()
	_simulation.event_posted.connect(_on_event)
	var address: GateAddress = DialFixture.address_of(_state.galaxy, DialFixture.OPEN_ID)
	assert_bool(_simulation.submit(DialCommand.create(address)).is_ok).is_true()
	_state.clock.is_paused = false
	_advance(_state.balance.dial_duration_ticks)
	assert_int(_state.gate.mode).is_equal(GateState.RingMode.LOCKED)


func _on_event(event_name: StringName, args: Array) -> void:
	if event_name == &"wormhole_closed":
		_closes.append([args, _state.clock.tick])


func _advance(ticks: int) -> void:
	for index: int in ticks:
		_simulation.advance_tick()


## The lock drains 20 MW out of the 30 MW output for exactly 60 ticks, then closes with
## &"timeout"; the bank gains only the 10 MW left over.
func test_lock_drains_and_times_out_at_max_open_ticks() -> void:
	var lock_tick: int = _state.gate.lock_started_tick
	var stored_at_lock: float = _state.power.stored_mwh
	assert_int(GateQueries.open_ticks_left(_state)).is_equal(60)
	_advance(59)
	assert_array(_closes).is_empty()
	assert_int(GateQueries.open_ticks_left(_state)).is_equal(1)
	_advance(1)
	assert_array(_closes).is_equal([[[&"timeout"], lock_tick + 60]])
	assert_int(_state.gate.mode).is_equal(GateState.RingMode.IDLE)
	var net_mw: float = _state.balance.starting_plant_output_mw - _state.balance.open_drain_mw_8
	var expected: float = stored_at_lock + net_mw * 60.0 / PowerMath.TICKS_PER_HOUR
	assert_float(_state.power.stored_mwh).is_equal_approx(expected, TOLERANCE)
	_advance(1)
	assert_float(_state.power.stored_mwh).is_greater(expected)
	assert_int(_state.worlds.status_of(DialFixture.OPEN_ID)).is_equal(
		WorldsState.WorldStatus.LOCKED
	)
	assert_array(GameState.validate_dict(_state.to_dict())).is_empty()


## CloseWormholeCommand closes at once while paused, with &"player".
func test_player_closes_the_wormhole() -> void:
	_advance(5)
	_state.clock.is_paused = true
	assert_bool(_simulation.submit(CloseWormholeCommand.new()).is_ok).is_true()
	assert_array(_closes).is_equal([[[&"player"], _state.clock.tick]])
	assert_int(_state.gate.mode).is_equal(GateState.RingMode.IDLE)
	assert_int(GateQueries.open_ticks_left(_state)).is_equal(0)


## Storage reaching 0 under a drain larger than the output closes it with &"power".
func test_empty_storage_under_a_larger_drain_closes_for_power() -> void:
	_state.power.plant_output_mw = 5.0
	_state.power.stored_mwh = 0.6
	_advance(2)
	assert_array(_closes).is_empty()
	assert_float(_state.power.stored_mwh).is_equal_approx(0.1, TOLERANCE)
	_advance(1)
	assert_array(_closes).is_equal([[[&"power"], _state.clock.tick]])
	assert_float(_state.power.stored_mwh).is_equal(0.0)
	assert_int(_state.gate.mode).is_equal(GateState.RingMode.IDLE)


## Empty storage is not enough: while the output covers the drain the wormhole stays open.
func test_empty_storage_with_output_covering_the_drain_stays_open() -> void:
	_state.power.stored_mwh = 0.0
	_state.power.plant_output_mw = _state.balance.open_drain_mw_8
	_advance(10)
	assert_array(_closes).is_empty()
	assert_int(_state.gate.mode).is_equal(GateState.RingMode.LOCKED)
	assert_float(_state.power.stored_mwh).is_equal(0.0)


## The CloseWormholeCommand is rejected with &"not_locked" once the wormhole has closed.
func test_close_command_needs_an_open_wormhole() -> void:
	_advance(60)
	var result: CommandResult = CloseWormholeCommand.new().validate(_state)
	assert_str(String(result.error_code)).is_equal("not_locked")
