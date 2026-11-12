class_name ArtefactRecord
extends RefCounted
## One artefact the player holds: which ArtefactDef, its state, where it is and when it came.
## room_uid is a room's uid when housed, −1 in Gate Room holding, −2 waiting at the gate.
## Saved shape: {"uid", "artefact", "state", "room_uid", "arrived_tick"}.
## Bible: docs/content/m4-core-systems.md sections 5 and 9

## Recovered (just arrived) → Housed → Studied.
enum ArtefactState { RECOVERED = 0, HOUSED = 1, STUDIED = 2 }

## room_uid of an artefact in Gate Room holding.
const IN_HOLDING: int = -1
## room_uid of an artefact waiting at the gate because holding was full.
const AT_GATE: int = -2
## Saved keys, in to_dict() order.
const KEYS: Array[String] = ["uid", "artefact", "state", "room_uid", "arrived_tick"]

## Unique id among artefacts.
var uid: int = 0
## Id of the ArtefactDef.
var artefact: StringName = &""
## Its state.
var state: ArtefactState = ArtefactState.RECOVERED
## Room uid when housed; IN_HOLDING or AT_GATE otherwise.
var room_uid: int = IN_HOLDING
## Tick it arrived.
var arrived_tick: int = 0


## Returns JSON-safe data for saving.
func to_dict() -> Dictionary:
	return {
		"uid": uid,
		"artefact": String(artefact),
		"state": state,
		"room_uid": room_uid,
		"arrived_tick": arrived_tick,
	}


## Builds a record from valid saved [param data].
static func from_dict(data: Dictionary) -> ArtefactRecord:
	var record := ArtefactRecord.new()
	record.uid = SaveFields.read_int(data.get("uid"))
	record.artefact = SaveFields.read_id(data.get("artefact"))
	record.state = SaveFields.read_int(data.get("state")) as ArtefactState
	record.room_uid = SaveFields.read_int(data.get("room_uid"), IN_HOLDING)
	record.arrived_tick = SaveFields.read_int(data.get("arrived_tick"))
	return record


## Errors of saved [param data]: keys, a uid of at least 0, an artefact id, a known state, a
## room uid of at least −2, and an arrival tick.
static func validate_dict(data: Dictionary) -> Array[String]:
	var errors: Array[String] = SaveFields.missing(data, KEYS)
	if not errors.is_empty():
		return errors
	if not SaveFields.is_tick(data["uid"]):
		errors.append("'uid' is not a whole number of at least 0")
	if not SaveFields.is_id(data["artefact"]):
		errors.append("'artefact' is not a non-empty string")
	if not SaveFields.is_enum(data["state"], ArtefactState.size()):
		errors.append("'state' is not an artefact state")
	if not SaveFields.is_int(data["room_uid"]) or SaveFields.read_int(data["room_uid"]) < AT_GATE:
		errors.append("'room_uid' is not a room uid, -1 or -2")
	if not SaveFields.is_tick(data["arrived_tick"]):
		errors.append("'arrived_tick' is not a tick")
	return errors
