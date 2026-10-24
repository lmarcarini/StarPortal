class_name WorldsState
extends RefCounted
## Saved progress over the galaxy: the seed and generator version the galaxy is regenerated
## from, and the status of every world the player has learned something about.
## Saved shape: {"galaxy_seed": decimal string, "generator_version", "statuses":
## {world id: status name}, "consoles_read": {world id: true}}. The seed is a string because it
## can exceed 2^53.
## Bible: technical-architecture.md#data-model, technical-architecture.md#save-system,
## gate-and-address-spec.md#where-addresses-come-from (Ring consoles)

## What the base knows about a world. UNKNOWN is never stored; more statuses arrive with
## probing (M3).
enum WorldStatus { UNKNOWN, LOCKED }

## Saved names of the statuses, indexed by WorldStatus value.
const _STATUS_NAMES: Array[String] = ["unknown", "locked"]

## Seed of the galaxy: RandomState.derive_seed(base seed, &"galaxy").
var galaxy_seed: int = 0
## WorldGenerator.GENERATOR_VERSION the galaxy was generated with.
var generator_version: int = 0
## Status of every world that is not UNKNOWN, by world id.
var statuses: Dictionary[StringName, WorldStatus] = {}
## Worlds whose far Ring's console the player has read, by world id; always true.
var consoles_read: Dictionary[StringName, bool] = {}


## Returns the status of [param world_id]; UNKNOWN when none is stored.
func status_of(world_id: StringName) -> WorldStatus:
	return statuses.get(world_id, WorldStatus.UNKNOWN)


## True when the console of [param world_id] has been read.
func is_console_read(world_id: StringName) -> bool:
	return consoles_read.has(world_id)


## Returns JSON-safe data for saving: the seed as a decimal string, statuses as lowercase
## names keyed by world id strings.
func to_dict() -> Dictionary:
	var status_data: Dictionary = {}
	for world_id: StringName in statuses:
		status_data[String(world_id)] = _STATUS_NAMES[statuses[world_id]]
	var console_data: Dictionary = {}
	for world_id: StringName in consoles_read:
		console_data[String(world_id)] = true
	return {
		"galaxy_seed": str(galaxy_seed),
		"generator_version": generator_version,
		"statuses": status_data,
		"consoles_read": console_data,
	}


## Builds a WorldsState from saved [param data]. The seed string is parsed exactly; a plain
## number is still accepted. Statuses that are unknown or unreadable are dropped. Call
## validate_dict() first for untrusted data.
static func from_dict(data: Dictionary) -> WorldsState:
	var worlds := WorldsState.new()
	worlds.galaxy_seed = _to_int64(data.get("galaxy_seed", 0))
	worlds.generator_version = type_convert(data.get("generator_version", 0), TYPE_INT)
	var console_data: Variant = data.get("consoles_read", {})
	if console_data is Dictionary:
		var console_dict: Dictionary = console_data
		for world_id: Variant in console_dict:
			if _is_true(console_dict[world_id]):
				worlds.consoles_read[StringName(str(world_id))] = true
	var status_data: Variant = data.get("statuses", {})
	if not status_data is Dictionary:
		return worlds
	var status_dict: Dictionary = status_data
	for world_id: Variant in status_dict:
		var status := _STATUS_NAMES.find(str(status_dict[world_id]))
		if status > WorldStatus.UNKNOWN:
			worlds.statuses[StringName(str(world_id))] = status as WorldStatus
	return worlds


## Returns human-readable errors for saved [param data], empty when it is valid:
## "galaxy_seed" a 64-bit integer written as a canonical decimal string; "generator_version"
## a whole number from 0 to 2^53; "statuses" an object mapping non-empty world ids to a
## status name other than "unknown"; "consoles_read" an object mapping non-empty world ids to
## true.
static func validate_dict(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not data.has("galaxy_seed"):
		errors.append("missing 'galaxy_seed'")
	elif not _is_int64_string(data["galaxy_seed"]):
		errors.append("'galaxy_seed' is not a 64-bit integer string")
	if not data.has("generator_version"):
		errors.append("missing 'generator_version'")
	elif not _is_count(data["generator_version"]):
		errors.append("'generator_version' is not a whole number from 0 to 2^53")
	if not data.has("statuses"):
		errors.append("missing 'statuses'")
	elif not data["statuses"] is Dictionary:
		errors.append("'statuses' is not an object")
	else:
		var status_dict: Dictionary = data["statuses"]
		errors.append_array(_validate_statuses(status_dict))
	errors.append_array(_validate_consoles(data))
	return errors


## Errors for "consoles_read" of [param data].
static func _validate_consoles(data: Dictionary) -> Array[String]:
	if not data.has("consoles_read"):
		return ["missing 'consoles_read'"]
	if not data["consoles_read"] is Dictionary:
		return ["'consoles_read' is not an object"]
	var errors: Array[String] = []
	var console_dict: Dictionary = data["consoles_read"]
	for world_id: Variant in console_dict:
		if str(world_id).is_empty():
			errors.append("a read console has an empty world id")
		elif not _is_true(console_dict[world_id]):
			errors.append("consoles_read of '%s' is not true" % world_id)
	return errors


## Errors for each entry of [param status_dict].
static func _validate_statuses(status_dict: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for world_id: Variant in status_dict:
		var status: Variant = status_dict[world_id]
		if str(world_id).is_empty():
			errors.append("a status has an empty world id")
		elif not status is String or _STATUS_NAMES.find(status) <= WorldStatus.UNKNOWN:
			errors.append("status of '%s' is not one of %s" % [world_id, _STATUS_NAMES.slice(1)])
	return errors


## True only for the bool true.
static func _is_true(value: Variant) -> bool:
	return value is bool and value


## True when [param value] is a String that round-trips exactly through a 64-bit int, so
## out-of-range numbers, signs like "+1", leading zeros and spaces are rejected. Same rule
## as RandomState's seed strings.
static func _is_int64_string(value: Variant) -> bool:
	if not value is String:
		return false
	var text: String = value
	return text.is_valid_int() and str(text.to_int()) == text


## True for an int, or a whole float, from 0 to 2^53.
static func _is_count(value: Variant) -> bool:
	if not JsonLimits.is_exact_int(value):
		return false
	var number: float = value
	return number >= 0.0


static func _to_int64(value: Variant) -> int:
	if value is String:
		var text: String = value
		return text.to_int()
	return type_convert(value, TYPE_INT)
