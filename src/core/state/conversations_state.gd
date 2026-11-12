class_name ConversationsState
extends RefCounted
## Saved state of conversations: the one running, if any, every transcript, and how many times
## each conversation has run.
## Saved shape: {"active": {} | ActiveConversation, "transcripts": [TranscriptRecord],
## "count": {conversation: int}, "next_uid"}.
## Bible: docs/content/m4-core-systems.md sections 3 and 9

## Saved keys, in to_dict() order.
const KEYS: Array[String] = ["active", "transcripts", "count", "next_uid"]

## The conversation running, or null.
var active: ActiveConversation = null
## Every transcript, oldest first.
var transcripts: Array[TranscriptRecord] = []
## Times each conversation has run.
var count: Dictionary[StringName, int] = {}
## Next transcript uid.
var next_uid: int = 0


## Returns JSON-safe data for saving.
func to_dict() -> Dictionary:
	var transcript_data: Array = []
	for record: TranscriptRecord in transcripts:
		transcript_data.append(record.to_dict())
	return {
		"active": active.to_dict() if active != null else {},
		"transcripts": transcript_data,
		"count": SaveFields.write_int_map(count),
		"next_uid": next_uid,
	}


## Builds the state from valid saved [param data].
static func from_dict(data: Dictionary) -> ConversationsState:
	var state := ConversationsState.new()
	var active_data: Dictionary = SaveFields.dict_or_empty(data.get("active"))
	if not active_data.is_empty():
		state.active = ActiveConversation.from_dict(active_data)
	for entry: Dictionary in SaveFields.dicts_in(data.get("transcripts")):
		state.transcripts.append(TranscriptRecord.from_dict(entry))
	state.count = SaveFields.read_int_map(data.get("count"))
	state.next_uid = SaveFields.read_int(data.get("next_uid"))
	return state


## Errors of saved [param data]: every key, an empty or valid active conversation, valid
## transcripts with distinct uids, counts of at least 0, next_uid above every uid.
static func validate_dict(data: Dictionary) -> Array[String]:
	var errors: Array[String] = SaveFields.missing(data, KEYS)
	if not errors.is_empty():
		return errors
	if not data["active"] is Dictionary:
		errors.append("'active' is not an object")
	else:
		var active_data: Dictionary = data["active"]
		if not active_data.is_empty():
			for error: String in ActiveConversation.validate_dict(active_data):
				errors.append("active: " + error)
	errors.append_array(
		SaveFields.record_list_errors(
			data["transcripts"], "transcripts", TranscriptRecord.validate_dict
		)
	)
	errors.append_array(SaveFields.int_map_errors(data["count"], "count", true))
	if data["transcripts"] is Array:
		var records: Array = data["transcripts"]
		errors.append_array(SaveFields.next_uid_errors(data, records))
	return errors


## Errors for ticks of valid [param data] later than [param now].
static func tick_errors(data: Dictionary, now: int) -> Array[String]:
	var errors: Array[String] = []
	var active_data: Dictionary = data["active"]
	if not active_data.is_empty() and SaveFields.read_int(active_data["node_tick"]) > now:
		errors.append("active 'node_tick' is later than the clock tick")
	var records: Array = data["transcripts"]
	for index: int in records.size():
		var record: Dictionary = records[index]
		if SaveFields.read_int(record["tick"]) > now:
			errors.append("transcripts %d 'tick' is later than the clock tick" % index)
	return errors
