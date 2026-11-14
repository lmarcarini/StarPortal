class_name ArtefactRules
extends RefCounted
## Pure rules of where artefacts are: Gate Room holding (never over capacity), waiting at the
## gate, and room slots of a fitting class (Containment also takes vault artefacts); with the
## moves the commands apply.
## Bible: docs/content/m4-core-systems.md section 5 (Holding, Housing)


## Room uid of room id [param room_id] ("room_<n>" → n), or −1.
static func room_uid_of(room_id: StringName) -> int:
	var text: String = String(room_id).trim_prefix("room_")
	return text.to_int() if text.is_valid_int() else -1


## Artefacts holding can keep.
static func capacity(state: GameState) -> int:
	return 2 if state.balance == null else state.balance.holding_capacity


## Uids of the artefacts in Gate Room holding, in arrival order.
static func holding(state: GameState) -> Array[int]:
	return _uids_at(state, ArtefactRecord.IN_HOLDING)


## Uids of the artefacts waiting at the gate, in arrival order.
static func at_gate(state: GameState) -> Array[int]:
	return _uids_at(state, ArtefactRecord.AT_GATE)


## Artefacts housed in room uid [param room_uid].
static func slots_used(state: GameState, room_uid: int) -> int:
	return _uids_at(state, room_uid).size() if room_uid >= 0 else 0


## The artefact with [param uid], or null.
static func find(state: GameState, uid: int) -> ArtefactRecord:
	for record: ArtefactRecord in state.artefacts.items:
		if record.uid == uid:
			return record
	return null


## True when room class [param room_class] can take artefact class [param artefact_class].
static func fits(room_class: StringName, artefact_class: StringName) -> bool:
	return (
		room_class == artefact_class
		or (room_class == &"containment" and artefact_class == &"vault")
	)


## Why artefact [param uid] cannot go into room uid [param room_uid], or &"".
static func house_error(state: GameState, uid: int, room_uid: int) -> StringName:
	var record: ArtefactRecord = find(state, uid)
	if record == null:
		return &"unknown_artefact"
	if record.room_uid != ArtefactRecord.IN_HOLDING:
		return &"not_in_holding"
	var room: RoomState = state.base.find_room(ModifierRules.room_id_of(room_uid))
	var room_def: RoomDef = null if room == null else state.room_defs.get(room.def_id)
	if room_def == null or room_def.artefact_slots <= 0:
		return &"not_storage"
	if not room.is_built() or room.is_demolishing():
		return &"not_built"
	var def: ArtefactDef = state.artefact_defs.get(record.artefact)
	var artefact_class: StringName = &"vault" if def == null else def.storage
	if not fits(room_def.artefact_class, artefact_class):
		return &"wrong_class"
	if slots_used(state, room_uid) >= room_def.artefact_slots:
		return &"room_full"
	return &""


## Why artefact [param uid] cannot go back to holding, or &"".
static func unhouse_error(state: GameState, uid: int) -> StringName:
	var record: ArtefactRecord = find(state, uid)
	if record == null:
		return &"unknown_artefact"
	if record.room_uid < 0:
		return &"not_housed"
	if holding(state).size() >= capacity(state):
		return &"holding_full"
	return &""


## Why artefact [param uid] cannot be retrieved from the gate, or &"".
static func retrieve_error(state: GameState, uid: int) -> StringName:
	var record: ArtefactRecord = find(state, uid)
	if record == null:
		return &"unknown_artefact"
	if record.room_uid != ArtefactRecord.AT_GATE:
		return &"not_at_gate"
	if holding(state).size() >= capacity(state):
		return &"holding_full"
	return &""


## Moves artefact [param uid] to [param room_uid] (a room, IN_HOLDING), sets HOUSED when it
## goes into a room (a STUDIED one stays STUDIED) and posts artefact_moved.
static func move(state: GameState, uid: int, room_uid: int) -> void:
	var record: ArtefactRecord = find(state, uid)
	record.room_uid = room_uid
	if room_uid >= 0 and record.state != ArtefactRecord.ArtefactState.STUDIED:
		record.state = ArtefactRecord.ArtefactState.HOUSED
	state.events.post(&"artefact_moved", [uid])


## Intruders take artefact [param uid] (M4c-07): it is carried until they leave or fall.
static func carry(state: GameState, uid: int) -> bool:
	var record: ArtefactRecord = find(state, uid)
	if record == null:
		return false
	record.room_uid = ArtefactRecord.CARRIED
	state.events.post(&"artefact_moved", [uid])
	return true


## A carried artefact [param uid] left through the Ring: it is gone.
static func lose(state: GameState, uid: int) -> bool:
	var record: ArtefactRecord = find(state, uid)
	if record == null:
		return false
	state.artefacts.items.erase(record)
	state.events.post(&"artefact_moved", [uid])
	return true


## The intruders carrying artefact [param uid] fell: it goes back to Gate Room holding.
static func recover(state: GameState, uid: int) -> bool:
	var record: ArtefactRecord = find(state, uid)
	if record == null:
		return false
	record.room_uid = ArtefactRecord.IN_HOLDING
	state.events.post(&"artefact_moved", [uid])
	return true


static func _uids_at(state: GameState, room_uid: int) -> Array[int]:
	var found: Array[int] = []
	for record: ArtefactRecord in state.artefacts.items:
		if record.room_uid == room_uid:
			found.append(record.uid)
	return found
