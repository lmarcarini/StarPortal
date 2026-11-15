class_name SlowRules
extends RefCounted
## Which events slow the clock now (docs/content/event-time.md section 2). Instead of overwriting
## the speed, the Simulation calls sync() after every tick's systems: it adds a slow reason for
## every event that wants the player's attention and releases the ones whose event has ended, so the
## clock returns to cruise speed on its own. An overridden reason is not added again for the same
## event.
## Bible: docs/content/event-time.md section 2

## Reasons sync() owns: all of them.
const OWNED: Array[StringName] = [&"awaiting_answer", &"dialling", &"gate_ops", &"incursion"]


## The slow keys [param state] wants now from waiting items (a conversation holds the clock
## instead; docs/content/dialogue-screen.md section 2).
static func wanted(state: GameState) -> Array[StringName]:
	var keys: Array[StringName] = []
	if state.incursion.is_active():
		keys.append(TimeControl.slow_key(&"incursion"))
	if state.gate.mode == GateState.RingMode.DIALING:
		keys.append(TimeControl.slow_key(&"dialling"))
	if state.gate.operating:
		keys.append(TimeControl.slow_key(&"gate_ops"))
	if state.gate.has_incoming():
		keys.append(TimeControl.slow_key(&"awaiting_answer", &"incoming"))
	for contact: PendingContact in state.factions.pending:
		if contact.channel == &"phone":
			keys.append(TimeControl.slow_key(&"awaiting_answer", &"phone_" + contact.faction))
	var plan: ExpeditionState = state.expedition
	if plan.mode == ExpeditionState.Mode.MISSING and plan.signal_tick < 0:
		keys.append(TimeControl.slow_key(&"awaiting_answer", &"rescue"))
	return keys


## Adds the wanted slows of [param state] and releases its owned slows no longer wanted. A
## gate that is no longer locked by the player stops operating first.
static func sync(state: GameState) -> void:
	if state.gate.mode != GateState.RingMode.LOCKED or state.gate.is_incoming_lock():
		state.gate.operating = false
	var clock: ClockState = state.clock
	var keys: Array[StringName] = wanted(state)
	for key: StringName in clock.slows.duplicate():
		if OWNED.has(TimeControl.reason_of(key)) and not keys.has(key):
			_release(clock, key)
	for key: StringName in clock.overridden.duplicate():
		if OWNED.has(TimeControl.reason_of(key)) and not keys.has(key):
			clock.overridden.erase(key)
	for key: StringName in keys:
		if not clock.slows.has(key) and not clock.overridden.has(key):
			clock.slows.append(key)


static func _release(clock: ClockState, key: StringName) -> void:
	clock.slows.erase(key)
	clock.overridden.erase(key)
