class_name MissionOrderRules
extends RefCounted
## Rules of a mission order (M4.9-12). Pure static.
## Bible: docs/content/interface-rethink.md section 4 (Gate, A mission order)

## Minutes the wormhole must be able to stay open on top of the dial.
const OPEN_MINUTES: int = 10
## Ticks the gate stays open after the send, while the team walks through.
const WALK_TICKS: int = 3


## Charge an order to [param address] needs: the lock plus OPEN_MINUTES of drain, in MWh.
static func charge_needed(state: GameState, address: GateAddress) -> float:
	var drain: float = state.balance.open_drain_mw_8 * float(OPEN_MINUTES) / 60.0
	return GateQueries.lock_energy_mwh(state, address) + drain


## Why an order to [param address] cannot start now, or &"".
static func refusal(state: GameState, address: GateAddress, when_charged: bool) -> StringName:
	if state.expedition.order.is_active():
		return &"order_running"
	if state.gate.mode != GateState.RingMode.IDLE or state.gate.has_incoming():
		return &"ring_busy"
	if state.incursion.is_active():
		return &"incursion"
	if address == null or not address.is_well_formed():
		return &"bad_address"
	if not when_charged and state.power.stored_mwh < charge_needed(state, address):
		return &"insufficient_charge"
	return &""
