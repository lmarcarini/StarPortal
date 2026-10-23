## Tests for RingControl: every cell of the transition table, the assert on each illegal
## transition, what start, finish and close write to the GateState, and the debug-only log.
## Bible: technical-architecture.md#state-machines,
## gate-and-address-spec.md#dialing-outcomes-and-energy
extends GdUnitTestSuite

const IDLE := GateState.RingMode.IDLE
const DIALING := GateState.RingMode.DIALING
const LOCKED := GateState.RingMode.LOCKED


func _address() -> GateAddress:
	return GateAddress.create([1, 2, 3, 4, 5, 6, 7], 8)


func _entry(outcome: DialOutcome.Kind, world_id: StringName = &"world_x") -> DialLogEntry:
	var entry := DialLogEntry.new()
	entry.tick = 12
	entry.address = _address()
	entry.outcome = outcome
	entry.energy_spent_mwh = 30.0
	entry.world_id = world_id
	return entry


func _gate_in(mode: GateState.RingMode) -> GateState:
	var gate := GateState.new()
	if mode == IDLE:
		return gate
	RingControl.start_dial(gate, _address(), 300.0, 10)
	if mode == LOCKED:
		RingControl.finish_dial(gate, _entry(DialOutcome.Kind.LOCK))
	return gate


## Every cell of the table: IDLE -> DIALING; DIALING -> IDLE or LOCKED; LOCKED -> IDLE.
func test_every_cell_of_the_transition_table() -> void:
	var expected: Dictionary = {
		IDLE: {IDLE: false, DIALING: true, LOCKED: false},
		DIALING: {IDLE: true, DIALING: false, LOCKED: true},
		LOCKED: {IDLE: true, DIALING: false, LOCKED: false},
	}
	for from: GateState.RingMode in [IDLE, DIALING, LOCKED]:
		for to: GateState.RingMode in [IDLE, DIALING, LOCKED]:
			var cell: bool = expected[from][to]
			(
				assert_bool(RingControl.can_transition(from, to))
				. override_failure_message("%d -> %d" % [from, to])
				. is_equal(cell)
			)


## start_dial() moves IDLE to DIALING and keeps a copy of the address, the tick and energy.
func test_start_dial_sets_the_dial() -> void:
	var gate := GateState.new()
	var address: GateAddress = _address()
	RingControl.start_dial(gate, address, 321.5, 40)
	assert_int(gate.mode).is_equal(DIALING)
	assert_bool(gate.current_address.equals(address)).is_true()
	assert_object(gate.current_address).is_not_same(address)
	assert_int(gate.dial_started_tick).is_equal(40)
	assert_float(gate.lock_energy_mwh).is_equal(321.5)
	assert_array(GateState.validate_dict(gate.to_dict())).is_empty()


## A failed outcome logs the entry and returns the Ring to IDLE with every field unset.
func test_finish_dial_with_a_failure_returns_to_idle() -> void:
	for outcome: DialOutcome.Kind in [
		DialOutcome.Kind.NO_GATE, DialOutcome.Kind.BLOCKED, DialOutcome.Kind.ORIGIN_REJECTED
	]:
		var gate: GateState = _gate_in(DIALING)
		var world: StringName = &"" if outcome == DialOutcome.Kind.NO_GATE else &"world_x"
		var entry: DialLogEntry = _entry(outcome, world)
		RingControl.finish_dial(gate, entry)
		assert_int(gate.mode).is_equal(IDLE)
		assert_array(gate.dial_log).contains_exactly([entry])
		assert_dict(gate.to_dict()).is_equal(_idle_with_log(gate))


## A lock or hostile lock opens the wormhole to the entry's world from the entry's tick.
func test_finish_dial_with_a_lock_opens_the_wormhole() -> void:
	for outcome: DialOutcome.Kind in [DialOutcome.Kind.LOCK, DialOutcome.Kind.HOSTILE_LOCK]:
		var gate: GateState = _gate_in(DIALING)
		RingControl.finish_dial(gate, _entry(outcome, &"world_far"))
		assert_int(gate.mode).is_equal(LOCKED)
		assert_str(String(gate.connected_world_id)).is_equal("world_far")
		assert_int(gate.lock_started_tick).is_equal(12)
		assert_bool(gate.is_hostile).is_equal(outcome == DialOutcome.Kind.HOSTILE_LOCK)
		assert_int(gate.dial_log.size()).is_equal(1)
		assert_array(GateState.validate_dict(gate.to_dict())).is_empty()


## close() returns LOCKED to IDLE and clears the connection; the log stays.
func test_close_returns_to_idle() -> void:
	var gate: GateState = _gate_in(LOCKED)
	RingControl.close(gate)
	assert_int(gate.mode).is_equal(IDLE)
	assert_dict(gate.to_dict()).is_equal(_idle_with_log(gate))
	assert_int(gate.dial_log.size()).is_equal(1)


## Starting a dial from DIALING or LOCKED asserts and changes nothing.
func test_start_dial_while_busy_asserts() -> void:
	for mode: GateState.RingMode in [DIALING, LOCKED]:
		var gate: GateState = _gate_in(mode)
		var before: Dictionary = gate.to_dict()
		var name: String = GateState.RingMode.find_key(mode)
		await (
			assert_error(func() -> void: RingControl.start_dial(gate, _address(), 1.0, 99))
			. is_runtime_error(
				"Assertion failed: RingControl: illegal transition %s -> DIALING" % name
			)
		)
		assert_dict(gate.to_dict()).is_equal(before)


## Finishing a dial when none is in progress asserts and logs nothing.
func test_finish_dial_without_a_dial_asserts() -> void:
	var cases: Dictionary = {
		IDLE: "RingControl.finish_dial(): the Ring is IDLE, not DIALING",
		LOCKED: "RingControl.finish_dial(): the Ring is LOCKED, not DIALING",
	}
	for mode: GateState.RingMode in cases:
		var gate: GateState = _gate_in(mode)
		var before: Dictionary = gate.to_dict()
		var entry: DialLogEntry = _entry(DialOutcome.Kind.NO_GATE, &"")
		await (
			assert_error(func() -> void: RingControl.finish_dial(gate, entry))
			. is_runtime_error("Assertion failed: " + str(cases[mode]))
		)
		assert_dict(gate.to_dict()).is_equal(before)


## A lock entry outside DIALING fails the same guard.
func test_finish_dial_with_a_lock_outside_dialing_asserts() -> void:
	var gate: GateState = _gate_in(IDLE)
	var entry: DialLogEntry = _entry(DialOutcome.Kind.LOCK)
	await (
		assert_error(func() -> void: RingControl.finish_dial(gate, entry))
		. is_runtime_error(
			"Assertion failed: RingControl.finish_dial(): the Ring is IDLE, not DIALING"
		)
	)
	assert_int(gate.mode).is_equal(IDLE)


## Closing an IDLE or DIALING Ring asserts and changes nothing: a dial is never cut short.
func test_close_without_a_wormhole_asserts() -> void:
	for mode: GateState.RingMode in [IDLE, DIALING]:
		var gate: GateState = _gate_in(mode)
		var before: Dictionary = gate.to_dict()
		var name: String = GateState.RingMode.find_key(mode)
		await (
			assert_error(func() -> void: RingControl.close(gate))
			. is_runtime_error(
				"Assertion failed: RingControl.close(): the Ring is %s, not LOCKED" % name
			)
		)
		assert_dict(gate.to_dict()).is_equal(before)


## The internal transition asserts on every cell the table forbids and changes nothing.
func test_every_illegal_cell_asserts() -> void:
	for from: GateState.RingMode in [IDLE, DIALING, LOCKED]:
		for to: GateState.RingMode in [IDLE, DIALING, LOCKED]:
			if RingControl.can_transition(from, to):
				continue
			var gate: GateState = _gate_in(from)
			var message: String = (
				"Assertion failed: RingControl: illegal transition %s -> %s"
				% [GateState.RingMode.find_key(from), GateState.RingMode.find_key(to)]
			)
			await (
				assert_error(func() -> void: RingControl._transition(gate, to))
				. is_runtime_error(message)
			)
			assert_int(gate.mode).is_equal(from)


## The transition log is plain print output inside an assert (debug builds only): never a
## warning or error, and called from exactly one place.
func test_transition_log_is_debug_only_print() -> void:
	var source := FileAccess.get_file_as_string("res://src/gate/ring_control.gd")
	for word: String in ["push_warning", "push_error", "printerr"]:
		assert_bool(source.contains(word)).override_failure_message(word).is_false()
	assert_int(source.count("_log_transition(from, to)")).is_equal(1)
	assert_bool(source.contains("\tassert(_log_transition(from, to))")).is_true()


## The expected to_dict() of an IDLE Ring that keeps [param gate]'s log.
func _idle_with_log(gate: GateState) -> Dictionary:
	var idle := GateState.new()
	idle.dial_log = gate.dial_log
	return idle.to_dict()
