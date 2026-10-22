## Tests for GateQueries on the dial fixture: lock energy, ticks until a dial is ready, the
## earlier attempts at an address and the open wormhole's time left.
## Bible: gate-and-address-spec.md#dialing-outcomes-and-energy,
## gate-and-address-spec.md#player-tools, game-design.md#time-real-time-with-pause
extends GdUnitTestSuite

const DialFixture := preload("res://tests/gate/dial_fixture.gd")

var _state: GameState
var _address: GateAddress


func before_test() -> void:
	_state = DialFixture.state()
	_address = DialFixture.address_of(_state.galaxy, DialFixture.OPEN_ID)


## The lock energy is EnergyMath's, from the home Ring over the galaxy's anchors.
func test_lock_energy_matches_energy_math() -> void:
	var expected: float = EnergyMath.lock_energy_mwh(
		_address, _state.galaxy.home().position_ly, _state.galaxy.anchors_ly(), _state.balance
	)
	assert_float(GateQueries.lock_energy_mwh(_state, _address)).is_equal(expected)
	assert_float(expected).is_greater_equal(_state.balance.lock_energy_base_mwh)


## A full bank is ready now; an empty one counts the ticks at the plant output.
func test_ticks_until_ready() -> void:
	assert_int(GateQueries.ticks_until_ready(_state, _address)).is_equal(0)
	_state.power.stored_mwh = 0.0
	var needed: float = GateQueries.lock_energy_mwh(_state, _address)
	var expected: int = PowerMath.ticks_until_mwh(0.0, needed, _state.power.plant_output_mw)
	assert_int(GateQueries.ticks_until_ready(_state, _address)).is_equal(expected)
	assert_int(expected).is_greater(0)


## Never ready: a lock energy above the capacity, no output, or a drain at least the output.
func test_ticks_until_ready_never() -> void:
	_state.power.stored_mwh = 0.0
	_state.power.capacity_mwh = 10.0
	assert_int(GateQueries.ticks_until_ready(_state, _address)).is_equal(-1)
	_state.power.capacity_mwh = DialFixture.CAPACITY_MWH
	_state.power.plant_output_mw = 0.0
	assert_int(GateQueries.ticks_until_ready(_state, _address)).is_equal(-1)
	_state.power.plant_output_mw = _state.balance.open_drain_mw_8
	_state.gate.mode = GateState.RingMode.LOCKED
	assert_int(GateQueries.ticks_until_ready(_state, _address)).is_equal(-1)


## Earlier attempts are the log entries with the same seals, oldest first.
func test_previous_attempts() -> void:
	var other := GateAddress.create(_address.coordinates, (_address.origin + 1) % 36)
	if other.seals().count(other.origin) > 1:
		other.origin = (_address.origin + 2) % 36
	var first: DialLogEntry = _log(_address, 5)
	_log(other, 6)
	var third: DialLogEntry = _log(_address, 9)
	var found: Array[DialLogEntry] = GateQueries.previous_attempts(_state, _address)
	assert_array(found).contains_exactly([first, third])
	var none: GateAddress = GateAddress.create([30, 31, 32, 33, 34, 35, 0], 1)
	assert_array(GateQueries.previous_attempts(_state, none)).is_empty()


## Time left is 0 unless LOCKED; then max_open_ticks less the ticks open so far, never below 0.
func test_open_ticks_left() -> void:
	assert_int(GateQueries.open_ticks_left(_state)).is_equal(0)
	_state.clock.tick = 100
	_state.gate.mode = GateState.RingMode.LOCKED
	_state.gate.lock_started_tick = 100
	assert_int(GateQueries.open_ticks_left(_state)).is_equal(60)
	_state.clock.tick = 159
	assert_int(GateQueries.open_ticks_left(_state)).is_equal(1)
	_state.clock.tick = 200
	assert_int(GateQueries.open_ticks_left(_state)).is_equal(0)


func _log(address: GateAddress, tick: int) -> DialLogEntry:
	var entry := DialLogEntry.new()
	entry.tick = tick
	entry.address = GateAddress.create(address.coordinates, address.origin)
	entry.outcome = DialOutcome.Kind.NO_GATE
	_state.gate.dial_log.append(entry)
	return entry
