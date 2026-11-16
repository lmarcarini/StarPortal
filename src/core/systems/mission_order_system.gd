class_name MissionOrderSystem
extends SimSystem
## Runs a mission order each tick, after GateSystem (M4.9-12): WAIT_CHARGE dials once the
## charge is there; DIALLING waits for the lock (a failed dial fails the order); SENDING sends
## the team; CLOSING closes the wormhole a few ticks later, once the team is through. A refusal
## mid-order stops it (mission_order_failed with the reason). The slow reasons are those of a
## manual dial; the gate is never operated by an order, so they end with the dial.
## Bible: docs/content/interface-rethink.md section 4 (Gate, A mission order)


## Returns &"mission_order".
func get_id() -> StringName:
	return &"mission_order"


## Moves the running order on.
func tick(state: GameState) -> void:
	var order: MissionOrder = state.expedition.order
	match order.phase:
		MissionOrder.Phase.WAIT_CHARGE:
			try_dial(state)
		MissionOrder.Phase.DIALLING:
			_after_dial(state)
		MissionOrder.Phase.SENDING:
			_send(state)
		MissionOrder.Phase.CLOSING:
			_close(state)


## Dials the order's address when the gate is idle and the charge is there.
static func try_dial(state: GameState) -> void:
	var order: MissionOrder = state.expedition.order
	if state.gate.mode != GateState.RingMode.IDLE or state.gate.has_incoming():
		return
	if state.power.stored_mwh < MissionOrderRules.charge_needed(state, order.address):
		return
	var dial: DialCommand = DialCommand.create(order.address)
	var check: CommandResult = dial.validate(state)
	if not check.is_ok:
		fail(state, check.error_code)
		return
	dial.apply(state)
	order.enter(MissionOrder.Phase.DIALLING, state.clock.tick)


## Ends the order as FAILED with [param why]; a wormhole it opened is closed unless its team
## already went through.
static func fail(state: GameState, why: StringName) -> void:
	var order: MissionOrder = state.expedition.order
	if order.phase in [MissionOrder.Phase.SENDING, MissionOrder.Phase.DIALLING]:
		if state.gate.connected_world_id == order.world_id:
			_close_wormhole(state)
	order.reason = why
	order.enter(MissionOrder.Phase.FAILED, state.clock.tick)
	state.events.post(&"mission_order_failed", [order.world_id, String(why)])


static func _after_dial(state: GameState) -> void:
	var order: MissionOrder = state.expedition.order
	if state.gate.mode == GateState.RingMode.DIALING:
		return
	if (
		state.gate.mode == GateState.RingMode.LOCKED
		and state.gate.connected_world_id == order.world_id
	):
		order.enter(MissionOrder.Phase.SENDING, state.clock.tick)
		_send(state)
		return
	fail(state, &"dial_failed")


static func _send(state: GameState) -> void:
	var send: SendTeamCommand = SendTeamCommand.new()
	var check: CommandResult = send.validate(state)
	if not check.is_ok:
		_close_wormhole(state)
		fail(state, check.error_code)
		return
	send.apply(state)
	state.expedition.order.enter(MissionOrder.Phase.CLOSING, state.clock.tick)


static func _close(state: GameState) -> void:
	var order: MissionOrder = state.expedition.order
	if state.clock.tick < order.phase_tick + MissionOrderRules.WALK_TICKS:
		return
	_close_wormhole(state)
	order.enter(MissionOrder.Phase.DONE, state.clock.tick)
	state.events.post(&"mission_order_done", [order.world_id])


static func _close_wormhole(state: GameState) -> void:
	if state.gate.mode == GateState.RingMode.LOCKED and not state.gate.is_incoming_lock():
		RingControl.close(state.gate)
		state.events.post(&"wormhole_closed", [&"order"])
