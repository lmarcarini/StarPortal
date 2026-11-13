class_name RingControl
extends RefCounted
## Pure rules of the Ring's state machine over a GateState: start a dial, finish it with its
## Dial Log entry, close the wormhole. Mutates only the GateState passed in. Every mode change
## goes through one guarded transition: an illegal one fails an assert in debug builds and is
## refused in release builds.
## [br][br]
## In debug builds every mode change is printed (from, to). That print is the only side
## effect. It runs inside an assert, so release builds, which strip asserts, skip it: the gate
## rules may not read engine singletons, so the debug check cannot be written out here.
## Bible: technical-architecture.md#state-machines,
## gate-and-address-spec.md#dialing-outcomes-and-energy

## Allowed transitions: each RingMode maps to the RingModes it may change to.
const ALLOWED: Dictionary = {
	GateState.RingMode.IDLE: [GateState.RingMode.DIALING],
	GateState.RingMode.DIALING: [GateState.RingMode.IDLE, GateState.RingMode.LOCKED],
	GateState.RingMode.LOCKED: [GateState.RingMode.IDLE],
}


## True when the table allows changing from [param from] to [param to]. Staying in the same
## mode is not a transition.
static func can_transition(from: GateState.RingMode, to: GateState.RingMode) -> bool:
	var targets: Array = ALLOWED.get(from, [])
	return targets.has(to)


## Starts dialing [param address] at [param tick]: IDLE becomes DIALING, and the Ring keeps a
## copy of the address, the tick and [param lock_energy_mwh] until the dial resolves.
static func start_dial(
	gate: GateState, address: GateAddress, lock_energy_mwh: float, tick: int
) -> void:
	assert(address != null, "RingControl.start_dial(): no address")
	if address == null or not _transition(gate, GateState.RingMode.DIALING):
		return
	gate.current_address = GateAddress.create(address.coordinates, address.origin)
	gate.dial_started_tick = tick
	gate.lock_energy_mwh = lock_energy_mwh


## Ends the dial in progress with [param entry]: appends it to the Dial Log, then a lock or a
## hostile lock opens the wormhole to the entry's world from the entry's tick (LOCKED), and
## any other outcome returns the Ring to IDLE. Only from DIALING: anything else fails an
## assert.
static func finish_dial(gate: GateState, entry: DialLogEntry) -> void:
	assert(entry != null, "RingControl.finish_dial(): no entry")
	if entry == null or not _is_in(gate, GateState.RingMode.DIALING, "finish_dial"):
		return
	var is_lock: bool = DialOutcome.is_lock(entry.outcome)
	var target: GateState.RingMode = GateState.RingMode.IDLE
	if is_lock:
		target = GateState.RingMode.LOCKED
	if not _transition(gate, target):
		return
	gate.dial_log.append(entry)
	if not is_lock:
		_clear(gate)
		return
	gate.connected_world_id = entry.world_id
	gate.lock_started_tick = entry.tick
	gate.is_hostile = entry.outcome == DialOutcome.Kind.HOSTILE_LOCK


## Opens the waiting incoming wormhole from the far side at [param tick]: IDLE becomes LOCKED
## to [param world_id] without a dial (the far side dialed; nothing goes in the Dial Log).
## Only while an incoming wormhole waits: anything else fails an assert.
static func answer_incoming(gate: GateState, world_id: StringName, tick: int) -> void:
	var waiting: bool = gate.has_incoming()
	assert(waiting, "RingControl.answer_incoming(): no incoming wormhole waits")
	if not waiting:
		return
	gate.mode = GateState.RingMode.LOCKED
	assert(_log_transition(GateState.RingMode.IDLE, GateState.RingMode.LOCKED))
	gate.connected_world_id = world_id
	gate.lock_started_tick = tick
	gate.is_hostile = false


## Closes the open wormhole: LOCKED becomes IDLE and the Ring forgets the connection. Only
## from LOCKED: anything else fails an assert (a dial in progress is never cut short).
static func close(gate: GateState) -> void:
	if not _is_in(gate, GateState.RingMode.LOCKED, "close"):
		return
	if not _transition(gate, GateState.RingMode.IDLE):
		return
	_clear(gate)


## Changes [param gate] to [param to] when the table allows it; returns whether it did.
static func _transition(gate: GateState, to: GateState.RingMode) -> bool:
	var allowed: bool = can_transition(gate.mode, to)
	assert(allowed, "RingControl: illegal transition %s -> %s" % [_name(gate.mode), _name(to)])
	if not allowed:
		return false
	var from: GateState.RingMode = gate.mode
	gate.mode = to
	assert(_log_transition(from, to))
	return true


## True when [param gate] is in [param mode]; otherwise fails an assert naming
## [param action] (debug) and returns false (release).
static func _is_in(gate: GateState, mode: GateState.RingMode, action: String) -> bool:
	var is_in_mode: bool = gate.mode == mode
	assert(
		is_in_mode,
		"RingControl.%s(): the Ring is %s, not %s" % [action, _name(gate.mode), _name(mode)]
	)
	return is_in_mode


## Resets the fields of the current dial and connection to their unset values.
static func _clear(gate: GateState) -> void:
	gate.current_address = null
	gate.dial_started_tick = -1
	gate.lock_energy_mwh = 0.0
	gate.connected_world_id = &""
	gate.lock_started_tick = -1
	gate.is_hostile = false
	gate.clear_incoming()


## Prints one mode change and returns true; called only inside an assert, so only in debug
## builds. Plain print output, never a warning.
static func _log_transition(from: GateState.RingMode, to: GateState.RingMode) -> bool:
	print("RingControl: %s -> %s" % [_name(from), _name(to)])
	return true


static func _name(mode: GateState.RingMode) -> String:
	return str(GateState.RingMode.find_key(mode))
