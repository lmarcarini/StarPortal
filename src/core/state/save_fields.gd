class_name SaveFields
extends RefCounted
## Small pure helpers shared by the M4 state sections to read and check saved fields: ids,
## id lists, ticks, whole numbers and enum values. Ticks are whole numbers from 0 to
## JsonLimits.MAX_EXACT_INT; ids are non-empty strings.
## Bible: technical-architecture.md#data-model, docs/content/m4-core-systems.md section 9


## Returns "missing '<key>'" for each of [param keys] that [param data] lacks.
static func missing(data: Dictionary, keys: Array[String]) -> Array[String]:
	var errors: Array[String] = []
	for key: String in keys:
		if not data.has(key):
			errors.append("missing '%s'" % key)
	return errors


## True for a non-empty String.
static func is_id(value: Variant) -> bool:
	return value is String and not str(value).is_empty()


## True for a whole number from 0 to JsonLimits.MAX_EXACT_INT.
static func is_tick(value: Variant) -> bool:
	if not JsonLimits.is_exact_int(value):
		return false
	var number: float = value
	return number >= 0.0


## True for a whole number in JSON range (any sign).
static func is_int(value: Variant) -> bool:
	return JsonLimits.is_exact_int(value)


## True for a whole number from 0 to [param count] − 1.
static func is_enum(value: Variant, count: int) -> bool:
	if not JsonLimits.is_exact_int(value):
		return false
	var number: float = value
	return number >= 0.0 and number < float(count)


## Returns [param value] as an int (whole floats become ints), or [param fallback] when it
## is not a whole number in JSON range.
static func read_int(value: Variant, fallback: int = 0) -> int:
	if not JsonLimits.is_exact_int(value):
		return fallback
	var number: int = value
	return number


## Returns [param value] as a StringName, or &"" when it is not a String.
static func read_id(value: Variant) -> StringName:
	if value is String:
		return StringName(str(value))
	return &""


## Returns the distinct non-empty Strings of [param value] as StringNames, in order.
static func read_ids(value: Variant) -> Array[StringName]:
	var found: Array[StringName] = []
	if not value is Array:
		return found
	var entries: Array = value
	for entry: Variant in entries:
		var id: StringName = read_id(entry)
		if not id.is_empty() and not found.has(id):
			found.append(id)
	return found


## Returns [param ids] as an Array of Strings for saving.
static func write_ids(ids: Array[StringName]) -> Array:
	var data: Array = []
	for id: StringName in ids:
		data.append(String(id))
	return data


## Errors for [param value] under [param label]: not an array, or an entry that is not a
## non-empty string, or a repeated entry.
static func id_list_errors(value: Variant, label: String) -> Array[String]:
	var errors: Array[String] = []
	if not value is Array:
		errors.append("'%s' is not an array" % label)
		return errors
	var entries: Array = value
	var seen: Dictionary[String, bool] = {}
	for index: int in entries.size():
		var entry: Variant = entries[index]
		if not is_id(entry):
			errors.append("%s %d is not a non-empty string" % [label, index])
		elif seen.has(entry):
			errors.append("%s %d: duplicate '%s'" % [label, index, entry])
		else:
			seen[entry] = true
	return errors


## Errors for [param value] under [param label]: not an object, or a key that is empty or a
## value that is not a whole number (ticks when [param as_ticks]).
static func int_map_errors(value: Variant, label: String, as_ticks: bool) -> Array[String]:
	var errors: Array[String] = []
	if not value is Dictionary:
		errors.append("'%s' is not an object" % label)
		return errors
	var entries: Dictionary = value
	for key: Variant in entries:
		var ok: bool = is_tick(entries[key]) if as_ticks else is_int(entries[key])
		if not is_id(key) or not ok:
			errors.append("%s '%s' is not a whole number" % [label, str(key)])
	return errors


## Returns the entries of a saved {id: whole number} map as StringName -> int.
static func read_int_map(value: Variant) -> Dictionary[StringName, int]:
	var found: Dictionary[StringName, int] = {}
	if not value is Dictionary:
		return found
	var entries: Dictionary = value
	for key: Variant in entries:
		if is_id(key) and is_int(entries[key]):
			found[StringName(str(key))] = read_int(entries[key])
	return found


## Returns a StringName -> int map as JSON-safe data, keys sorted for a stable save.
static func write_int_map(map: Dictionary[StringName, int]) -> Dictionary:
	var keys: Array = map.keys()
	keys.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	var data: Dictionary = {}
	for key: StringName in keys:
		data[String(key)] = map[key]
	return data


## Errors for the records of [param value] under [param label]: not an array, a record that
## is not an object, the errors [param check] returns for it, or a repeated "uid".
static func record_list_errors(value: Variant, label: String, check: Callable) -> Array[String]:
	var errors: Array[String] = []
	if not value is Array:
		errors.append("'%s' is not an array" % label)
		return errors
	var entries: Array = value
	var uids: Dictionary[int, bool] = {}
	for index: int in entries.size():
		if not entries[index] is Dictionary:
			errors.append("%s %d is not an object" % [label, index])
			continue
		var entry: Dictionary = entries[index]
		var found: Array[String] = check.call(entry)
		for error: String in found:
			errors.append("%s %d: %s" % [label, index, error])
		if found.is_empty() and entry.has("uid"):
			var uid: int = read_int(entry["uid"])
			if uids.has(uid):
				errors.append("%s %d: duplicate uid %d" % [label, index, uid])
			uids[uid] = true
	return errors


## Errors when "next_uid" of [param data] is not a whole number above every uid in
## [param records] (saved record dictionaries with a valid "uid").
static func next_uid_errors(data: Dictionary, records: Array) -> Array[String]:
	var errors: Array[String] = []
	if not is_tick(data["next_uid"]):
		errors.append("'next_uid' is not a whole number of at least 0")
		return errors
	var next_uid: int = read_int(data["next_uid"])
	for entry: Variant in records:
		if not entry is Dictionary:
			continue
		var record: Dictionary = entry
		if read_int(record.get("uid"), -1) >= next_uid:
			errors.append("'next_uid' is not above every uid")
			break
	return errors


## True for a tick or −1 (not set).
static func is_tick_or_unset(value: Variant) -> bool:
	return is_tick(value) or (is_int(value) and read_int(value) == -1)


## Returns the Dictionary entries of [param value] when it is an Array; others are skipped.
static func dicts_in(value: Variant) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if not value is Array:
		return found
	var entries: Array = value
	for entry: Variant in entries:
		if entry is Dictionary:
			found.append(entry)
	return found


## Returns [param value] when it is a Dictionary, else an empty one.
static func dict_or_empty(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}
