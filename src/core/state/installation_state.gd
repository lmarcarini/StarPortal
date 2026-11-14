class_name InstallationState
extends RefCounted
## One installation fitted to a room or a door (M4c-18): its def, building left, what was
## paid and its health. Saved shape: {"def", "build_ticks_left", "paid_k", "health"}.
## Bible: docs/content/m4c-incursions.md sections 6 and 9

## Saved keys, in to_dict() order.
const KEYS: Array[String] = ["def", "build_ticks_left", "paid_k", "health"]

## Bumped whenever an installation is built or removed, for caches (the modifier totals).
static var revision: int = 0

## InstallationDef id.
var def: StringName = &""
## Ticks of building left; 0 once built.
var build_ticks_left: int = 0:
	set(value):
		if (value > 0) != (build_ticks_left > 0):
			revision += 1
		build_ticks_left = value
## What was paid, $k.
var paid_k: int = 0
## Health left for one that can be destroyed; 0 otherwise.
var health: int = 0


## True once built.
func is_built() -> bool:
	return build_ticks_left == 0


## Returns JSON-safe data for saving.
func to_dict() -> Dictionary:
	return {
		"def": String(def),
		"build_ticks_left": build_ticks_left,
		"paid_k": paid_k,
		"health": health,
	}


## Builds one from valid saved [param data].
static func from_dict(data: Dictionary) -> InstallationState:
	var item := InstallationState.new()
	item.def = SaveFields.read_id(data.get("def"))
	item.build_ticks_left = SaveFields.read_int(data.get("build_ticks_left"))
	item.paid_k = SaveFields.read_int(data.get("paid_k"))
	item.health = SaveFields.read_int(data.get("health"))
	return item


## Errors of saved [param data].
static func validate_dict(data: Dictionary) -> Array[String]:
	var errors: Array[String] = SaveFields.missing(data, KEYS)
	if not errors.is_empty():
		return errors
	if not SaveFields.is_id(data["def"]):
		errors.append("'def' is not a non-empty string")
	for key: String in ["build_ticks_left", "paid_k", "health"]:
		if not (SaveFields.is_int(data[key]) and data[key] >= 0):
			errors.append("'%s' is not a whole number of at least 0" % key)
	return errors


## Saved [param items] as an array.
static func write_all(items: Array[InstallationState]) -> Array:
	var out: Array = []
	for item: InstallationState in items:
		out.append(item.to_dict())
	return out


## The installations saved in [param value] (an array of objects).
static func read_all(value: Variant) -> Array[InstallationState]:
	var out: Array[InstallationState] = []
	for item: Dictionary in SaveFields.dicts_in(value):
		out.append(from_dict(item))
	return out
