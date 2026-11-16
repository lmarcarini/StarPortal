class_name MainKeyRules
extends RefCounted
## What the console's main key is now, from the state and the selected address: DIAL when the
## Ring is idle and an address is chosen, CLOSE while a wormhole is open, otherwise OFF with
## the reason as a translation key for its hover card. Pure.
## Bible: docs/content/interface-rethink.md section 4 (Gate, Console)

## Key modes.
enum Mode { DIAL, CLOSE, OFF }

## Hover reason for each dial refusal code.
const REFUSALS: Dictionary[StringName, StringName] = {
	&"ring_busy": &"GATE_REASON_BUSY",
	&"insufficient_charge": &"GATE_DIAL_REJECT_CHARGE",
	&"bad_address": &"STATION_REASON_NO_DESTINATION",
	&"incursion": &"STATION_REASON_INCURSION",
	&"shutter_closed": &"GATE_ERR_SHUTTER_CLOSED",
}


## The key's mode for [param state] with [param address] selected (null for none).
static func mode_of(state: GameState, address: GateAddress) -> Mode:
	if state.gate.mode == GateState.RingMode.LOCKED:
		return Mode.CLOSE
	if reason_of(state, address) != &"":
		return Mode.OFF
	return Mode.DIAL


## Why the key cannot dial now, or &"" when it can try (the dial command may still refuse).
static func reason_of(state: GameState, address: GateAddress) -> StringName:
	if state.gate.mode == GateState.RingMode.DIALING:
		return &"GATE_REASON_DIALING"
	if state.gate.mode == GateState.RingMode.LOCKED or state.gate.has_incoming():
		return &"GATE_REASON_BUSY"
	if PowerRules.capacity_mwh(state) <= 0.0:
		return &"GATE_DIAL_NO_CAPACITORS"
	if address == null or not address.is_well_formed():
		return &"STATION_REASON_NO_DESTINATION"
	if state.incursion.is_active():
		return &"STATION_REASON_INCURSION"
	if ShutterRules.is_closed(state):
		return &"GATE_ERR_SHUTTER_CLOSED"
	if state.power.stored_mwh <= 0.0:
		return &"GATE_DIAL_CAPACITORS_EMPTY"
	return &""


## Hover reason for the dial refusal [param code].
static func refusal_key(code: StringName) -> StringName:
	return REFUSALS.get(code, &"GATE_REASON_REJECTED")


## True when closing now would cut something short (a MOTH out, a canister in flight), so
## CLOSE asks to be held.
static func close_needs_confirm(state: GameState) -> bool:
	return state.probes.moth != null or state.probes.canister_ticks_left > 0
