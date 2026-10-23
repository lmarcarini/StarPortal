class_name ArchiveState
extends RefCounted
## The Archive: every document the player holds, in arrival order, the tick each arrived and
## which have been read. Documents are content (DocumentDef); only their ids are saved.
## Saved shape: {"received": [document id], "read": {document id: bool},
## "received_tick": {document id: tick}}.
## Bible: gate-and-address-spec.md#where-addresses-come-from,
## technical-architecture.md#data-model

## Document ids, in arrival order.
var received: Array[StringName] = []
## Whether each received document has been read; a missing id is unread.
var read: Dictionary[StringName, bool] = {}
## Tick each received document arrived.
var received_tick: Dictionary[StringName, int] = {}


## True when document [param document_id] is in the Archive.
func has_document(document_id: StringName) -> bool:
	return received.has(document_id)


## True when document [param document_id] has been read.
func is_read(document_id: StringName) -> bool:
	return read.get(document_id, false)


## Adds [param document_id] at the end, received at [param tick], unread. Callers check
## has_document() first.
func add(document_id: StringName, tick: int) -> void:
	received.append(document_id)
	received_tick[document_id] = tick


## Returns JSON-safe data for saving; ids become Strings.
func to_dict() -> Dictionary:
	var received_data: Array[String] = []
	for document_id: StringName in received:
		received_data.append(String(document_id))
	var read_data: Dictionary = {}
	for document_id: StringName in read:
		read_data[String(document_id)] = read[document_id]
	var tick_data: Dictionary = {}
	for document_id: StringName in received_tick:
		tick_data[String(document_id)] = received_tick[document_id]
	return {"received": received_data, "read": read_data, "received_tick": tick_data}


## Builds an Archive from saved [param data]; JSON floats become ints. Unreadable items are
## skipped. Call validate_dict() first for untrusted data.
static func from_dict(data: Dictionary) -> ArchiveState:
	var archive := ArchiveState.new()
	var received_data: Variant = data.get("received")
	if received_data is Array:
		var list: Array = received_data
		for item: Variant in list:
			archive.received.append(StringName(str(item)))
	var read_data: Dictionary = _dict_or_empty(data.get("read"))
	for document_id: Variant in read_data:
		var value: Variant = read_data[document_id]
		if value is bool:
			archive.read[StringName(str(document_id))] = value
	var tick_data: Dictionary = _dict_or_empty(data.get("received_tick"))
	for document_id: Variant in tick_data:
		var tick: int = type_convert(tick_data[document_id], TYPE_INT)
		archive.received_tick[StringName(str(document_id))] = tick
	return archive


## Returns human-readable errors for saved [param data], empty when it is valid: "received" an
## array of distinct, non-empty strings; "read" an object mapping received ids to bools;
## "received_tick" an object mapping every received id, and nothing else, to a whole number
## from 0 to 2^53.
static func validate_dict(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key: String in ["received", "read", "received_tick"]:
		if not data.has(key):
			errors.append("missing '%s'" % key)
	if not errors.is_empty():
		return errors
	if not data["received"] is Array:
		return ["'received' is not an array"]
	var ids: Array = data["received"]
	for index: int in ids.size():
		if not ids[index] is String or str(ids[index]).is_empty():
			errors.append("received %d is not a non-empty string" % index)
		elif ids.find(ids[index]) != index:
			errors.append("received %d repeats '%s'" % [index, ids[index]])
	errors.append_array(_read_errors(data["read"], ids))
	errors.append_array(_tick_errors(data["received_tick"], ids))
	return errors


## Errors for the "read" value [param read_data] against the [param ids] received.
static func _read_errors(read_data: Variant, ids: Array) -> Array[String]:
	if not read_data is Dictionary:
		return ["'read' is not an object"]
	var errors: Array[String] = []
	var read_dict: Dictionary = read_data
	for document_id: Variant in read_dict:
		if not ids.has(document_id):
			errors.append("read names '%s', which is not received" % document_id)
		elif not read_dict[document_id] is bool:
			errors.append("read of '%s' is not a bool" % document_id)
	return errors


## Errors for the "received_tick" value [param tick_data] against the [param ids] received.
static func _tick_errors(tick_data: Variant, ids: Array) -> Array[String]:
	if not tick_data is Dictionary:
		return ["'received_tick' is not an object"]
	var errors: Array[String] = []
	var tick_dict: Dictionary = tick_data
	for document_id: Variant in tick_dict:
		var tick: Variant = tick_dict[document_id]
		if not ids.has(document_id):
			errors.append("received_tick names '%s', which is not received" % document_id)
		elif not JsonLimits.is_exact_int(tick) or not _is_non_negative(tick):
			errors.append(
				"received_tick of '%s' is not a whole number from 0 to 2^53" % document_id
			)
	for document_id: Variant in ids:
		if document_id is String and not tick_dict.has(document_id):
			errors.append("received_tick is missing '%s'" % document_id)
	return errors


## True for an exact whole number [param tick] of at least 0.
static func _is_non_negative(tick: Variant) -> bool:
	var number: float = tick
	return number >= 0.0


static func _dict_or_empty(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}
