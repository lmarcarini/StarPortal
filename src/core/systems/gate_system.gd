class_name GateSystem
extends SimSystem
## Runs CAIRN's Ring each tick, after PowerSystem: resolves a dial once its seals have engaged
## for [member BalanceConfig.dial_duration_ticks] ticks, and closes an open wormhole when it
## times out or the capacitors run empty. Reads the transient balance and galaxy on the state.
## [br][br]
## Timing: the Simulation advances the clock after every system has ticked, so the tick
## being run ends at clock tick + 1. A dial that started at tick S has engaged its seals
## through ticks S .. S + duration - 1 and resolves as tick S + duration begins; a lock
## opened at tick L drains through ticks L .. L + max_open_ticks - 1 and closes at
## L + max_open_ticks. Every outcome takes the same time, so timing reveals nothing.
## [br][br]
## The gate never writes the speed: dialling and operating the gate slow the clock through
## slow reasons (SlowRules, docs/content/event-time.md section 3).
## [br][br]
## Posts dial_resolved(outcome, address key), address_book_changed() and
## wormhole_closed(reason), reason &"timeout" or &"power"; a dial_resolved event carries
## nothing but the outcome and the address key.
## Bible: gate-and-address-spec.md#dialing-outcomes-and-energy,
## gate-and-address-spec.md#the-dial-console (Address Book),
## game-design.md#time-real-time-with-pause ,
## gate-and-address-spec.md#the-dialing-sequence-and-an-open-wormhole,
## technical-architecture.md#simulation-clock-and-commands

## Close reason when the wormhole reached its maximum open time.
const REASON_TIMEOUT: StringName = &"timeout"
## Close reason when the open wormhole drained the capacitors empty.
const REASON_POWER: StringName = &"power"
## Pause reason when an incoming wormhole activates the Ring.
const INCOMING_PAUSE: StringName = &"incoming_wormhole"


## Returns the system id, &"gate".
func get_id() -> StringName:
	return &"gate"


## Resolves a dial that has finished engaging, or closes a lock that must close. A dial that
## resolves into a lock is not checked for closing until the next tick.
func tick(state: GameState) -> void:
	assert(state.balance != null and state.galaxy != null, "GateSystem: no balance or galaxy")
	if state.balance == null or state.galaxy == null:
		return
	var end_tick: int = state.clock.tick + 1
	match state.gate.mode:
		GateState.RingMode.IDLE:
			_run_incoming(state)
		GateState.RingMode.DIALING:
			if end_tick - state.gate.dial_started_tick >= state.balance.dial_duration_ticks:
				_resolve(state, end_tick)
		GateState.RingMode.LOCKED:
			var reason: StringName = _close_reason(state, end_tick)
			if not reason.is_empty():
				RingControl.close(state.gate)
				state.events.post(&"wormhole_closed", [reason])


## Resolves the dial in progress at [param end_tick]: spends the outcome's cost, logs the
## attempt, marks a reached world LOCKED, posts dial_resolved, then records the dial in the
## Address Book (the world only on a lock) and posts address_book_changed.
func _resolve(state: GameState, end_tick: int) -> void:
	var gate: GateState = state.gate
	var answer: Dictionary = DialResolver.resolve(gate.current_address, state.galaxy)
	var outcome: DialOutcome.Kind = answer["outcome"]
	var cost: float = EnergyMath.dial_cost_mwh(gate.lock_energy_mwh, outcome, state.balance)
	state.power.stored_mwh = maxf(state.power.stored_mwh - cost, 0.0)
	var entry := DialLogEntry.new()
	entry.tick = end_tick
	entry.address = GateAddress.from_dict(gate.current_address.to_dict())
	entry.outcome = outcome
	entry.energy_spent_mwh = cost
	entry.world_id = answer["world_id"]
	RingControl.finish_dial(gate, entry)
	if DialOutcome.is_lock(outcome):
		WorldProgress.raise_status(state, entry.world_id, WorldsState.WorldStatus.LOCKED)
	state.events.post(&"dial_resolved", [outcome as int, entry.address.key()])
	state.address_book.record_dial(entry)
	state.events.post(&"address_book_changed", [])


## Returns why the open wormhole closes as [param end_tick] begins, or &"" when it stays open.
## Power is checked first: the capacitors are empty (docs/content/m2-base.md section 3).
func _close_reason(state: GameState, end_tick: int) -> StringName:
	if state.power.stored_mwh <= 0.0 and not state.gate.is_incoming_lock():
		return REASON_POWER
	if end_tick - state.gate.lock_started_tick >= GateQueries.max_open_ticks(state):
		return REASON_TIMEOUT
	return &""


## While IDLE: an incoming wormhole that waited too long is ignored; with none waiting and no
## conversation running, the oldest pending incoming contact activates the Ring from the far
## side for incoming_answer_minutes and asks for a pause.
func _run_incoming(state: GameState) -> void:
	var gate: GateState = state.gate
	if gate.has_incoming():
		if state.clock.tick >= gate.incoming_until_tick:
			IncomingRules.ignore(state)
		return
	if state.conversations.active != null:
		return
	var index: int = ContactRules.next_pending(state, &"incoming")
	if index < 0:
		return
	var contact: PendingContact = state.factions.pending[index]
	state.factions.pending.remove_at(index)
	gate.incoming_faction = contact.faction
	gate.incoming_conversation = contact.conversation
	# One tick is one minute.
	gate.incoming_until_tick = state.clock.tick + state.balance.incoming_answer_minutes
	state.events.post(&"incoming_wormhole", [contact.faction])
	state.events.post(Simulation.PAUSE_EVENT, [INCOMING_PAUSE])
