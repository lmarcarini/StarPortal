class_name ArtefactsState
extends RefCounted
## Saved state of the artefacts the player holds, in arrival order.
## Saved shape: {"items": [ArtefactRecord], "next_uid"}.
## Bible: docs/content/m4-core-systems.md sections 5 and 9

## Saved keys, in to_dict() order.
const KEYS: Array[String] = ["items", "next_uid"]

## Every artefact held, in arrival order.
var items: Array[ArtefactRecord] = []
## Next artefact uid.
var next_uid: int = 0


## Returns JSON-safe data for saving.
func to_dict() -> Dictionary:
	var item_data: Array = []
	for record: ArtefactRecord in items:
		item_data.append(record.to_dict())
	return {"items": item_data, "next_uid": next_uid}


## Builds the state from valid saved [param data].
static func from_dict(data: Dictionary) -> ArtefactsState:
	var state := ArtefactsState.new()
	for entry: Dictionary in SaveFields.dicts_in(data.get("items")):
		state.items.append(ArtefactRecord.from_dict(entry))
	state.next_uid = SaveFields.read_int(data.get("next_uid"))
	return state


## Errors of saved [param data]: both keys, valid records with distinct uids, next_uid above
## every uid.
static func validate_dict(data: Dictionary) -> Array[String]:
	var errors: Array[String] = SaveFields.missing(data, KEYS)
	if not errors.is_empty():
		return errors
	errors.append_array(
		SaveFields.record_list_errors(data["items"], "items", ArtefactRecord.validate_dict)
	)
	if data["items"] is Array:
		var records: Array = data["items"]
		errors.append_array(SaveFields.next_uid_errors(data, records))
	return errors


## Errors for arrival ticks of valid [param data] later than [param now].
static func tick_errors(data: Dictionary, now: int) -> Array[String]:
	var errors: Array[String] = []
	var records: Array = data["items"]
	for index: int in records.size():
		var record: Dictionary = records[index]
		if SaveFields.read_int(record["arrived_tick"]) > now:
			errors.append("items %d 'arrived_tick' is later than the clock tick" % index)
	return errors
