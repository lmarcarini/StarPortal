class_name RequestsState
extends RefCounted
## Saved state of requests: every instance offered, open or closed, oldest first.
## Saved shape: {"items": [RequestRecord], "next_uid"}.
## Bible: docs/content/m4-core-systems.md sections 4 and 9

## Saved keys, in to_dict() order.
const KEYS: Array[String] = ["items", "next_uid"]

## Every request instance, oldest first.
var items: Array[RequestRecord] = []
## Next request uid.
var next_uid: int = 0


## Returns JSON-safe data for saving.
func to_dict() -> Dictionary:
	var item_data: Array = []
	for record: RequestRecord in items:
		item_data.append(record.to_dict())
	return {"items": item_data, "next_uid": next_uid}


## Builds the state from valid saved [param data].
static func from_dict(data: Dictionary) -> RequestsState:
	var state := RequestsState.new()
	for entry: Dictionary in SaveFields.dicts_in(data.get("items")):
		state.items.append(RequestRecord.from_dict(entry))
	state.next_uid = SaveFields.read_int(data.get("next_uid"))
	return state


## Errors of saved [param data]: both keys, valid records with distinct uids, next_uid above
## every uid.
static func validate_dict(data: Dictionary) -> Array[String]:
	var errors: Array[String] = SaveFields.missing(data, KEYS)
	if not errors.is_empty():
		return errors
	errors.append_array(
		SaveFields.record_list_errors(data["items"], "items", RequestRecord.validate_dict)
	)
	if data["items"] is Array:
		var records: Array = data["items"]
		errors.append_array(SaveFields.next_uid_errors(data, records))
	return errors


## Errors for offered, accepted or closed ticks of valid [param data] later than [param now].
static func tick_errors(data: Dictionary, now: int) -> Array[String]:
	var errors: Array[String] = []
	var records: Array = data["items"]
	for index: int in records.size():
		var record: Dictionary = records[index]
		for key: String in RequestRecord.PAST_TICKS:
			if SaveFields.read_int(record[key]) > now:
				errors.append("items %d '%s' is later than the clock tick" % [index, key])
	return errors
