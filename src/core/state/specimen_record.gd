class_name SpecimenRecord
extends RefCounted
## One specimen of alien life the player holds (docs/content/research-and-progression.md
## sections 3 and 10): where it came from, what it is and when it arrived (its age spoils it
## unless a cold store keeps it). Kept in ArtefactsState.specimens, in holding at the gate.
## Saved shape: {"uid", "world_id", "kind", "arrived_tick"}.
## Bible: docs/content/research-and-progression.md sections 3 and 10

## Saved keys, in to_dict() order.
const KEYS: Array[String] = ["uid", "world_id", "kind", "arrived_tick"]
## Kinds of specimen, from the world's life.
const KINDS: Array[StringName] = [&"plants", &"animals"]

## Unique id among specimens.
var uid: int = 0
## The world it came from.
var world_id: StringName = &""
## One of [constant KINDS].
var kind: StringName = &"plants"
## The tick it arrived.
var arrived_tick: int = 0


## Returns JSON-safe data for saving.
func to_dict() -> Dictionary:
	return {
		"uid": uid, "world_id": String(world_id), "kind": String(kind), "arrived_tick": arrived_tick
	}


## Builds a record from valid saved [param data].
static func from_dict(data: Dictionary) -> SpecimenRecord:
	var record := SpecimenRecord.new()
	record.uid = SaveFields.read_int(data.get("uid"))
	record.world_id = SaveFields.read_id(data.get("world_id"))
	record.kind = SaveFields.read_id(data.get("kind"))
	record.arrived_tick = SaveFields.read_int(data.get("arrived_tick"))
	return record


## Errors of saved [param data], empty when valid.
static func validate_dict(data: Dictionary) -> Array[String]:
	var errors: Array[String] = SaveFields.missing(data, KEYS)
	if not errors.is_empty():
		return errors
	if not SaveFields.is_int(data["uid"]) or SaveFields.read_int(data["uid"]) < 0:
		errors.append("'uid' is not a whole number of at least 0")
	if not SaveFields.is_id(data["world_id"]):
		errors.append("'world_id' is not a non-empty string")
	if not (data["kind"] is String and StringName(str(data["kind"])) in KINDS):
		errors.append("'kind' is not a known kind")
	if not SaveFields.is_tick(data["arrived_tick"]):
		errors.append("'arrived_tick' is not a tick")
	return errors
