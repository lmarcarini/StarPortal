class_name FactionsState
extends RefCounted
## Saved state of the factions: standings (not the Committee's, which is Confidence), which
## are met, the last standing causes, pending contacts, when each last made contact, and the
## once-only conversations used.
## Saved shape: {"standing": {faction: int}, "met": [faction], "causes": {faction: [{"tick",
## "delta", "key"}]}, "pending": [PendingContact], "last_contact_tick": {faction: int},
## "used": [conversation]}.
## Bible: docs/content/m4-core-systems.md sections 2 and 9

## Saved keys, in to_dict() order.
const KEYS: Array[String] = ["standing", "met", "causes", "pending", "last_contact_tick", "used"]
## Keys of a standing cause.
const CAUSE_KEYS: Array[String] = ["tick", "delta", "key"]

## Standing per faction, −100..100 (the Committee has none here).
var standing: Dictionary[StringName, int] = {}
## Factions met, in the order they were met.
var met: Array[StringName] = []
## Per faction, the last standing changes, oldest first: {"tick": int, "delta": int,
## "key": StringName}.
var causes: Dictionary[StringName, Array] = {}
## Contacts waiting to be made, oldest first.
var pending: Array[PendingContact] = []
## Tick each faction last started a contact.
var last_contact_tick: Dictionary[StringName, int] = {}
## Once-only conversations already used.
var used: Array[StringName] = []


## Returns the state of a new game over [param factions]: each non-Committee faction at its
## starting standing, Earth factions met.
static func starting(factions: Array[FactionDef]) -> FactionsState:
	var state := FactionsState.new()
	for faction: FactionDef in factions:
		if not faction.uses_confidence:
			state.standing[faction.id] = faction.start_standing
		if faction.kind == &"earth":
			state.met.append(faction.id)
	return state


## Returns JSON-safe data for saving.
func to_dict() -> Dictionary:
	var cause_data: Dictionary = {}
	var cause_keys: Array = causes.keys()
	cause_keys.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for faction: StringName in cause_keys:
		var list: Array = []
		for cause: Dictionary in causes[faction]:
			var key: StringName = cause["key"]
			list.append({"tick": cause["tick"], "delta": cause["delta"], "key": String(key)})
		cause_data[String(faction)] = list
	var pending_data: Array = []
	for contact: PendingContact in pending:
		pending_data.append(contact.to_dict())
	return {
		"standing": SaveFields.write_int_map(standing),
		"met": SaveFields.write_ids(met),
		"causes": cause_data,
		"pending": pending_data,
		"last_contact_tick": SaveFields.write_int_map(last_contact_tick),
		"used": SaveFields.write_ids(used),
	}


## Builds the state from valid saved [param data].
static func from_dict(data: Dictionary) -> FactionsState:
	var state := FactionsState.new()
	state.standing = SaveFields.read_int_map(data.get("standing"))
	state.met = SaveFields.read_ids(data.get("met"))
	state.last_contact_tick = SaveFields.read_int_map(data.get("last_contact_tick"))
	state.used = SaveFields.read_ids(data.get("used"))
	var cause_data: Variant = data.get("causes")
	if cause_data is Dictionary:
		var by_faction: Dictionary = cause_data
		for faction: Variant in by_faction:
			state.causes[StringName(str(faction))] = _read_causes(by_faction[faction])
	for entry: Dictionary in SaveFields.dicts_in(data.get("pending")):
		state.pending.append(PendingContact.from_dict(entry))
	return state


## Errors of saved [param data]: every key, standings within −100..100, distinct met and used
## ids, well-formed causes and pending contacts, whole-number contact ticks.
static func validate_dict(data: Dictionary) -> Array[String]:
	var errors: Array[String] = SaveFields.missing(data, KEYS)
	if not errors.is_empty():
		return errors
	errors.append_array(SaveFields.int_map_errors(data["standing"], "standing", false))
	if errors.is_empty():
		var standing_data: Dictionary = data["standing"]
		for faction: Variant in standing_data:
			if absi(SaveFields.read_int(standing_data[faction])) > 100:
				errors.append("standing '%s' is outside -100..100" % str(faction))
	errors.append_array(SaveFields.id_list_errors(data["met"], "met"))
	errors.append_array(SaveFields.id_list_errors(data["used"], "used"))
	errors.append_array(
		SaveFields.int_map_errors(data["last_contact_tick"], "last_contact_tick", true)
	)
	errors.append_array(_causes_errors(data["causes"]))
	errors.append_array(_pending_errors(data["pending"]))
	return errors


## Errors for ticks of valid [param data] later than [param now].
static func tick_errors(data: Dictionary, now: int) -> Array[String]:
	var errors: Array[String] = []
	var last: Dictionary = data["last_contact_tick"]
	for faction: Variant in last:
		if SaveFields.read_int(last[faction]) > now:
			errors.append("last_contact_tick '%s' is later than the clock tick" % str(faction))
	var causes_data: Dictionary = data["causes"]
	for faction: Variant in causes_data:
		for cause: Dictionary in causes_data[faction]:
			if SaveFields.read_int(cause["tick"]) > now:
				errors.append("a cause of '%s' is later than the clock tick" % str(faction))
	var pending_data: Array = data["pending"]
	for index: int in pending_data.size():
		var contact: Dictionary = pending_data[index]
		if SaveFields.read_int(contact["since_tick"]) > now:
			errors.append("pending %d 'since_tick' is later than the clock tick" % index)
	return errors


static func _causes_errors(value: Variant) -> Array[String]:
	var errors: Array[String] = []
	if not value is Dictionary:
		errors.append("'causes' is not an object")
		return errors
	var by_faction: Dictionary = value
	for faction: Variant in by_faction:
		if not SaveFields.is_id(faction) or not by_faction[faction] is Array:
			errors.append("causes '%s' is not a list" % str(faction))
			continue
		for cause: Variant in by_faction[faction]:
			if not _is_cause(cause):
				errors.append("a cause of '%s' is not {tick, delta, key}" % str(faction))
	return errors


static func _is_cause(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var cause: Dictionary = value
	if not SaveFields.missing(cause, CAUSE_KEYS).is_empty():
		return false
	return (
		SaveFields.is_tick(cause["tick"])
		and SaveFields.is_int(cause["delta"])
		and SaveFields.is_id(cause["key"])
	)


static func _read_causes(value: Variant) -> Array:
	var list: Array = []
	if not value is Array:
		return list
	for entry: Variant in value:
		if _is_cause(entry):
			var cause: Dictionary = entry
			(
				list
				. append(
					{
						"tick": SaveFields.read_int(cause["tick"]),
						"delta": SaveFields.read_int(cause["delta"]),
						"key": StringName(str(cause["key"])),
					}
				)
			)
	return list


static func _pending_errors(value: Variant) -> Array[String]:
	var errors: Array[String] = []
	if not value is Array:
		errors.append("'pending' is not an array")
		return errors
	var entries: Array = value
	for index: int in entries.size():
		if not entries[index] is Dictionary:
			errors.append("pending %d is not an object" % index)
			continue
		var entry: Dictionary = entries[index]
		for error: String in PendingContact.validate_dict(entry):
			errors.append("pending %d: %s" % [index, error])
	return errors
