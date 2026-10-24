class_name WormholeText
extends RefCounted
## Pure text of the wormhole screen over a GameState whose Ring is LOCKED: the destination,
## the time left, the drain, the bank's state and the documents this lock delivered. It never
## shows an address's lock energy.
## Translates with the TranslationServer so it can stay static.
## Bible: gate-and-address-spec.md#the-dialing-sequence-and-an-open-wormhole,
## gate-and-address-spec.md#dialing-outcomes-and-energy

## Translation key of the message for each close reason.
const CLOSED_KEYS: Dictionary[StringName, StringName] = {
	&"player": &"GATE_CLOSED_PLAYER",
	&"timeout": &"GATE_CLOSED_TIMEOUT",
	&"power": &"GATE_CLOSED_POWER",
}


## Returns "Destination: <designation>" for the connected world.
static func destination(state: GameState) -> String:
	var designation: String = GateRoomFormat.translate(&"GATE_WORMHOLE_UNNAMED")
	var world: WorldRecord = state.galaxy.get_world(state.gate.connected_world_id)
	if world != null and not world.designation.is_empty():
		designation = world.designation
	return _format(&"GATE_WORMHOLE_DESTINATION", {"designation": designation})


## Returns the time left of the maximum open time, e.g. "Time left: 50 min of 1 h 0 min".
static func time_left(state: GameState) -> String:
	return _format(
		&"GATE_WORMHOLE_TIME_LEFT",
		{
			"left": GateRoomFormat.duration(GateQueries.open_ticks_left(state)),
			"total": GateRoomFormat.duration(state.balance.max_open_ticks),
		}
	)


## Returns the open wormhole's power drain, e.g. "Power drain: 20.0 MW".
static func drain(state: GameState) -> String:
	var drain_mw: float = PowerMath.drain_mw(state.gate, state.balance)
	return _format(&"GATE_WORMHOLE_DRAIN", {"power": String.num(drain_mw, 1)})


## Returns the bank's state: stored of capacity, and either how long until it runs dry under
## the drain or that the plant covers the drain.
static func bank(state: GameState) -> String:
	var power: PowerState = state.power
	var values: Dictionary = {
		"stored": GateRoomFormat.energy(power.stored_mwh),
		"capacity": GateRoomFormat.energy(power.capacity_mwh),
	}
	var net: float = PowerMath.net_flow_mw(
		power.plant_output_mw, PowerMath.drain_mw(state.gate, state.balance)
	)
	if net >= 0.0:
		return _format(&"GATE_WORMHOLE_BANK_STEADY", values)
	values["time"] = GateRoomFormat.duration(ticks_until_empty(power.stored_mwh, -net))
	return _format(&"GATE_WORMHOLE_BANK_FALLING", values)


## Returns the ticks until [param stored_mwh] is used up at [param loss_mw]; 0 when nothing
## is stored, -1 when nothing is lost.
static func ticks_until_empty(stored_mwh: float, loss_mw: float) -> int:
	if loss_mw <= 0.0:
		return -1
	return maxi(ceili(stored_mwh * PowerMath.TICKS_PER_HOUR / loss_mw), 0)


## Returns the documents this lock delivered, in arrival order, read from the Archive: those
## received on the tick the lock happened. DocumentSystem delivers on the tick a lock is logged,
## stamped with the clock's tick, one before the lock's own tick (the tick that tick ends at).
static func new_documents(state: GameState) -> Array[StringName]:
	var lock_tick: int = state.gate.lock_started_tick
	var archive: ArchiveState = state.archive
	if state.gate.mode != GateState.RingMode.LOCKED or lock_tick < 1:
		return []
	return archive.received.filter(
		func(id: StringName) -> bool: return archive.received_tick.get(id, -1) == lock_tick - 1
	)


## Returns "New in the Archive: <title>, <title>" for the documents [param defs] (a null def
## reads "Untitled document"), or "" for none.
static func new_documents_line(defs: Array[DocumentDef]) -> String:
	if defs.is_empty():
		return ""
	var titles: PackedStringArray = []
	for def: DocumentDef in defs:
		titles.append(DocumentText.title(def))
	return _format(&"GATE_WORMHOLE_NEW_DOCUMENTS", {"titles": ", ".join(titles)})


## Returns the message for close [param reason].
static func closed(reason: StringName) -> String:
	var key: StringName = CLOSED_KEYS.get(reason, &"GATE_CLOSED_OTHER")
	return GateRoomFormat.translate(key)


static func _format(key: StringName, values: Dictionary) -> String:
	return GateRoomFormat.translate(key).format(values)
