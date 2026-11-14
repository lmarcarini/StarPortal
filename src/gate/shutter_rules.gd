class_name ShutterRules
extends RefCounted
## The Shutter, pure (M4c-10): an installation in the Gate Room that closes the Ring. Closed,
## nothing comes through and nothing goes out; each incursion wave it stops takes
## STOP_COST_MWH from the capacitors, and with less stored it fails. A def marked
## breaches_shutter gets through anyway.
## Bible: docs/content/m4c-incursions.md section 6

## The Shutter installation.
const DEF_ID: StringName = &"installation_shutter"
## Energy a stopped wave takes.
const STOP_COST_MWH: float = 100.0


## True when the Gate Room of [param state] has a built Shutter.
static func is_installed(state: GameState) -> bool:
	for room: RoomState in state.base.rooms:
		if room.def_id == StartingBase.GATE_ROOM_DEF:
			var item: InstallationState = InstallationRules.find(room.installations, DEF_ID)
			return item != null and item.is_built()
	return false


## True while the Shutter of [param state] is closed.
static func is_closed(state: GameState) -> bool:
	return state.gate.shutter == GateState.Shutter.CLOSED


## At the end of the warning: true when the closed Shutter stops the wave (taking its energy),
## false when it is open, the def breaches it or the capacitors hold too little.
static func stops_wave(state: GameState, def: IncursionDef) -> bool:
	if not is_closed(state) or (def != null and def.breaches_shutter):
		return false
	if state.power.stored_mwh < STOP_COST_MWH:
		return false
	state.power.stored_mwh -= STOP_COST_MWH
	return true
