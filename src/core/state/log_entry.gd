class_name LogEntry
extends RefCounted
## One line of the operations log: when it happened, what kind of thing happened, the world it
## concerns (empty when none) and a few saveable details. LogRules builds entries from domain
## events; views decide how to word them.
## Saved shape: {"tick", "kind", "world_id", "args": {name: String | bool | int | [int]}}.
## Bible: game-design.md#core-loop (Archive: the operations log),
## technical-architecture.md#data-model

## Every kind an entry can have.
const KINDS: Array[StringName] = [
	&"dial", &"lock", &"close", &"document", &"console", &"horizon", &"power"
]

## Tick the event happened.
var tick: int = 0
## One of [constant KINDS].
var kind: StringName = &""
## The world the entry concerns; may be empty.
var world_id: StringName = &""
## Small, saveable values only: Strings, bools, ints and arrays of ints.
var args: Dictionary = {}


## Returns an entry of [param entry_kind] at [param at_tick] about [param world] with
## [param details].
static func create(
	at_tick: int, entry_kind: StringName, world: StringName, details: Dictionary = {}
) -> LogEntry:
	var entry := LogEntry.new()
	entry.tick = at_tick
	entry.kind = entry_kind
	entry.world_id = world
	entry.args = details.duplicate(true)
	return entry


## Returns JSON-safe data for saving.
func to_dict() -> Dictionary:
	return {
		"tick": tick,
		"kind": String(kind),
		"world_id": String(world_id),
		"args": args.duplicate(true)
	}


## Builds an entry from saved [param data]; whole JSON floats become ints, and unsupported
## argument values are dropped. Call validate_dict() first for untrusted data.
static func from_dict(data: Dictionary) -> LogEntry:
	var entry := LogEntry.new()
	entry.tick = type_convert(data.get("tick", 0), TYPE_INT)
	entry.kind = StringName(str(data.get("kind", "")))
	entry.world_id = StringName(str(data.get("world_id", "")))
	var arg_data: Variant = data.get("args")
	if arg_data is Dictionary:
		var arg_dict: Dictionary = arg_data
		for key: Variant in arg_dict:
			var value: Variant = _read_value(arg_dict[key])
			if value != null:
				entry.args[str(key)] = value
	return entry


## Returns human-readable errors for saved [param data], empty when it is valid: "tick" a whole
## number from 0 to 2^53, "kind" one of [constant KINDS], "world_id" a string and "args" an
## object whose values are strings, bools, whole numbers or arrays of whole numbers.
static func validate_dict(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not _is_tick(data.get("tick")):
		errors.append("'tick' is not a whole number from 0 to 2^53")
	var kind_value: Variant = data.get("kind")
	if not kind_value is String or not KINDS.has(StringName(str(kind_value))):
		errors.append("'kind' is not a log entry kind")
	if not data.get("world_id") is String:
		errors.append("'world_id' is not a string")
	var arg_data: Variant = data.get("args")
	if not arg_data is Dictionary:
		errors.append("'args' is not an object")
		return errors
	var arg_dict: Dictionary = arg_data
	for key: Variant in arg_dict:
		if _read_value(arg_dict[key]) == null:
			errors.append("args '%s' is not a string, bool, whole number or list of them" % key)
	return errors


## True for a whole number from 0 to 2^53.
static func _is_tick(value: Variant) -> bool:
	if not JsonLimits.is_exact_int(value):
		return false
	var number: float = value
	return number >= 0.0


## Returns saved [param value] as entry data (whole floats as ints), or null when unsupported.
static func _read_value(value: Variant) -> Variant:
	if value is String or value is bool:
		return value
	if JsonLimits.is_exact_int(value):
		return type_convert(value, TYPE_INT)
	if not value is Array:
		return null
	var numbers: Array[int] = []
	var list: Array = value
	for item: Variant in list:
		if not JsonLimits.is_exact_int(item):
			return null
		numbers.append(type_convert(item, TYPE_INT))
	return numbers
