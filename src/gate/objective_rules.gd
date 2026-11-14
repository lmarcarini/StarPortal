class_name ObjectiveRules
extends RefCounted
## Where intruders go and how long their objective takes, pure (M4c-07).
## Bible: docs/content/m4c-incursions.md section 5

## Ticks in the room, uncontested, to carry out each objective; assault holds (no end).
const WORK_TICKS: Dictionary[StringName, int] = {&"sabotage": 10, &"theft": 5, &"assault": -1}
## Ticks intruders with nothing to go for hold the Gate Room before leaving.
const HOLD_GATE_TICKS: int = 30
const POWER_PLANT_DEF: StringName = &"room_power_plant"
const CONTROL_ROOM_DEF: StringName = &"room_control"


## The room id [param objective] sends intruders to in [param state], or &"" when there is
## none (they then hold the Gate Room): sabotage the first built Power Plant; theft the
## first room housing an artefact, else the Gate Room when holding has one; assault the
## Control Room.
static func target_room(state: GameState, objective: StringName) -> StringName:
	match objective:
		&"sabotage":
			return _first_of(state, POWER_PLANT_DEF)
		&"assault":
			return _first_of(state, CONTROL_ROOM_DEF)
		&"theft":
			for room: RoomState in state.base.rooms:
				if (
					room.is_built()
					and not _artefacts_in(state, ArtefactRules.room_uid_of(room.id)).is_empty()
				):
					return room.id
			if not _artefacts_in(state, ArtefactRecord.IN_HOLDING).is_empty():
				return _first_of(state, StartingBase.GATE_ROOM_DEF)
	return &""


## The cell intruders walk to for room [param room_id]: its top-left cell; the Gate Room's
## cell when the room is gone or &"".
static func target_cell(state: GameState, room_id: StringName) -> Vector3i:
	var room: RoomState = state.base.find_room(room_id)
	if room == null:
		return IncursionRules.gate_cell(state)
	return Vector3i(room.origin.x, room.origin.y, room.level)


## The artefact uid theft takes from room [param room_id] (its holding when it is the Gate
## Room), or −1.
static func loot(state: GameState, room_id: StringName) -> int:
	var room: RoomState = state.base.find_room(room_id)
	if room == null:
		return -1
	var found: Array[int] = _artefacts_in(state, ArtefactRules.room_uid_of(room.id))
	if found.is_empty() and room.def_id == StartingBase.GATE_ROOM_DEF:
		found = _artefacts_in(state, ArtefactRecord.IN_HOLDING)
	return found[0] if not found.is_empty() else -1


static func _first_of(state: GameState, def_id: StringName) -> StringName:
	for room: RoomState in state.base.rooms:
		if room.def_id == def_id and room.is_built():
			return room.id
	return &""


static func _artefacts_in(state: GameState, room_uid: int) -> Array[int]:
	var found: Array[int] = []
	for record: ArtefactRecord in state.artefacts.items:
		if record.room_uid == room_uid:
			found.append(record.uid)
	return found
