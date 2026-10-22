## Tests for GateSystem driven through a Simulation with PowerSystem first: full dials while
## running and while paused, the cost of every outcome, the Dial Log entry, and the same
## timing and event shape for every outcome (no gate reveals nothing).
## Bible: gate-and-address-spec.md#dialing-outcomes-and-energy,
## technical-architecture.md#simulation-clock-and-commands
extends GdUnitTestSuite

const DialFixture := preload("res://tests/gate/dial_fixture.gd")

var _state: GameState
var _simulation: Simulation
## Every event emitted: [name, args, clock tick when emitted].
var _events: Array[Array] = []


func _setup(paused: bool) -> void:
	_state = DialFixture.state(null, paused)
	_simulation = DialFixture.simulation(_state)
	_events.clear()
	_simulation.event_posted.connect(_on_event)


func _on_event(event_name: StringName, args: Array) -> void:
	_events.append([event_name, args, _state.clock.tick])


func _address(id: StringName) -> GateAddress:
	return DialFixture.address_of(_state.galaxy, id)


## The fixture address that gives [param outcome].
func _address_for(outcome: DialOutcome.Kind) -> GateAddress:
	match outcome:
		DialOutcome.Kind.NO_GATE:
			return _state.galaxy.address_of(
				_state.galaxy.home().id, _state.galaxy.home().origin_glyph
			)
		DialOutcome.Kind.BLOCKED:
			return _address(DialFixture.BURIED_ID)
		DialOutcome.Kind.ORIGIN_REJECTED:
			var right: GateAddress = _address(DialFixture.OPEN_ID)
			for glyph: int in GateAddress.GLYPH_COUNT:
				if not right.seals().has(glyph):
					return GateAddress.create(right.coordinates, glyph)
		DialOutcome.Kind.HOSTILE_LOCK:
			return _address(DialFixture.GUARDED_ID)
	return _address(DialFixture.OPEN_ID)


func _events_named(event_name: StringName) -> Array[Array]:
	var found: Array[Array] = []
	for event: Array in _events:
		if event[0] == event_name:
			found.append(event)
	return found


func _advance(ticks: int) -> void:
	for index: int in ticks:
		_simulation.advance_tick()


## The system's id is gate.
func test_id() -> void:
	assert_str(String(GateSystem.new().get_id())).is_equal("gate")


## Running: dial_started comes out with the tick that applies the command, recording the
## submit's tick; dial_resolved exactly dial_duration_ticks later, with the Dial Log entry.
func test_full_dial_while_running() -> void:
	_setup(false)
	_state.clock.tick = 30
	var address: GateAddress = _address(DialFixture.OPEN_ID)
	var lock_energy: float = GateQueries.lock_energy_mwh(_state, address)
	assert_bool(_simulation.submit(DialCommand.create(address)).is_ok).is_true()
	assert_array(_events).is_empty()
	_advance(1)
	assert_array(_events).is_equal([[&"dial_started", [address.key()], 31]])
	assert_int(_state.gate.dial_started_tick).is_equal(30)
	assert_int(_state.gate.mode).is_equal(GateState.RingMode.DIALING)
	_advance(1)
	var resolved: Array[Array] = _events_named(&"dial_resolved")
	assert_array(resolved).is_equal(
		[[&"dial_resolved", [DialOutcome.Kind.LOCK as int, address.key()], 32]]
	)
	assert_float(_state.power.stored_mwh).is_equal(DialFixture.CAPACITY_MWH - lock_energy)
	assert_int(_state.gate.dial_log.size()).is_equal(1)
	var entry: DialLogEntry = _state.gate.dial_log[0]
	assert_int(entry.tick).is_equal(32)
	assert_bool(entry.address.equals(address)).is_true()
	assert_int(entry.outcome).is_equal(DialOutcome.Kind.LOCK)
	assert_float(entry.energy_spent_mwh).is_equal(lock_energy)
	assert_str(String(entry.world_id)).is_equal(String(DialFixture.OPEN_ID))
	assert_int(_state.gate.mode).is_equal(GateState.RingMode.LOCKED)
	assert_int(_state.gate.lock_started_tick).is_equal(32)
	assert_int(_state.worlds.status_of(DialFixture.OPEN_ID)).is_equal(
		WorldsState.WorldStatus.LOCKED
	)
	assert_array(GameState.validate_dict(_state.to_dict())).is_empty()


## Paused: the command applies at once and posts dial_started; nothing resolves until ticks
## run, then it resolves after exactly dial_duration_ticks of them.
func test_full_dial_while_paused() -> void:
	_setup(true)
	var address: GateAddress = _address(DialFixture.BURIED_ID)
	assert_bool(_simulation.submit(DialCommand.create(address)).is_ok).is_true()
	assert_array(_events).is_equal([[&"dial_started", [address.key()], 0]])
	assert_int(_state.gate.mode).is_equal(GateState.RingMode.DIALING)
	assert_int(_state.gate.dial_started_tick).is_equal(0)
	assert_array(GameState.validate_dict(_state.to_dict())).is_empty()
	_state.clock.is_paused = false
	_advance(1)
	assert_array(_events_named(&"dial_resolved")).is_empty()
	_advance(1)
	assert_array(_events_named(&"dial_resolved")).is_equal(
		[[&"dial_resolved", [DialOutcome.Kind.BLOCKED as int, address.key()], 2]]
	)
	assert_int(_state.gate.mode).is_equal(GateState.RingMode.IDLE)
	assert_int(_state.worlds.status_of(DialFixture.BURIED_ID)).is_equal(
		WorldsState.WorldStatus.UNKNOWN
	)


## Every outcome spends its fraction of the lock energy, takes the same ticks and posts the
## same two arguments: the outcome and the address key, nothing about the seals.
func test_every_outcome_costs_its_fraction_and_takes_the_same_time() -> void:
	var balance := BalanceConfig.new()
	var fractions: Dictionary = {
		DialOutcome.Kind.NO_GATE: balance.cost_fraction_no_gate,
		DialOutcome.Kind.BLOCKED: balance.cost_fraction_blocked,
		DialOutcome.Kind.ORIGIN_REJECTED: balance.cost_fraction_origin_rejected,
		DialOutcome.Kind.LOCK: 1.0,
		DialOutcome.Kind.HOSTILE_LOCK: 1.0,
	}
	for outcome: DialOutcome.Kind in fractions:
		_setup(false)
		var address: GateAddress = _address_for(outcome)
		var lock_energy: float = GateQueries.lock_energy_mwh(_state, address)
		_simulation.submit(DialCommand.create(address))
		_advance(balance.dial_duration_ticks)
		var expected_event: Array = [
			&"dial_resolved", [outcome as int, address.key()], balance.dial_duration_ticks
		]
		assert_array(_events_named(&"dial_resolved")).is_equal([expected_event])
		var fraction: float = fractions[outcome]
		var cost: float = lock_energy * fraction
		assert_float(_state.power.stored_mwh).is_equal(DialFixture.CAPACITY_MWH - cost)
		var entry: DialLogEntry = _state.gate.dial_log[0]
		assert_float(entry.energy_spent_mwh).is_equal(cost)
		assert_int(entry.outcome).is_equal(outcome)
		assert_array(GameState.validate_dict(_state.to_dict())).is_empty()


## A hostile lock opens a hostile wormhole and marks the world LOCKED.
func test_hostile_lock_opens_a_hostile_wormhole() -> void:
	_setup(true)
	_simulation.submit(DialCommand.create(_address(DialFixture.GUARDED_ID)))
	_state.clock.is_paused = false
	_advance(2)
	assert_int(_state.gate.mode).is_equal(GateState.RingMode.LOCKED)
	assert_bool(_state.gate.is_hostile).is_true()
	assert_str(String(_state.gate.connected_world_id)).is_equal(String(DialFixture.GUARDED_ID))
	assert_int(_state.worlds.status_of(DialFixture.GUARDED_ID)).is_equal(
		WorldsState.WorldStatus.LOCKED
	)


## A second dial after a failure is accepted once the Ring is IDLE again, and both attempts
## are in the log in order.
func test_dials_follow_each_other_in_the_log() -> void:
	_setup(true)
	var first: GateAddress = _address_for(DialOutcome.Kind.NO_GATE)
	var second: GateAddress = _address_for(DialOutcome.Kind.ORIGIN_REJECTED)
	_simulation.submit(DialCommand.create(first))
	_state.clock.is_paused = false
	_advance(2)
	_state.clock.is_paused = true
	assert_bool(_simulation.submit(DialCommand.create(second)).is_ok).is_true()
	_state.clock.is_paused = false
	_advance(2)
	assert_int(_state.gate.dial_log.size()).is_equal(2)
	assert_bool(_state.gate.dial_log[0].address.equals(first)).is_true()
	assert_bool(_state.gate.dial_log[1].address.equals(second)).is_true()
	assert_int(_state.gate.dial_log[1].tick).is_equal(4)
	assert_int(GateQueries.previous_attempts(_state, second).size()).is_equal(1)
