class_name UnitState
extends RefCounted
## One intruder (M4c): its UnitDef, health, position and the artefact it carries.
## Positions are Vector3i(cell x, cell y, level), saved as [x, y, level].
## Saved shape: {"unit", "health", "pos", "carrying"}.
## Bible: docs/content/m4c-incursions.md section 9

## Saved keys, in to_dict() order.
const KEYS: Array[String] = ["unit", "health", "pos", "carrying"]

## UnitDef id.
var unit: StringName = &""
## Health left; down at 0.
var health: int = 0
## Cell and level.
var pos: Vector3i = Vector3i.ZERO
## Uid of the artefact carried, or −1.
var carrying: int = -1


## Returns JSON-safe data for saving.
func to_dict() -> Dictionary:
	return {"unit": String(unit), "health": health, "pos": write_pos(pos), "carrying": carrying}


## Builds one from valid saved [param data].
static func from_dict(data: Dictionary) -> UnitState:
	var state := UnitState.new()
	state.unit = SaveFields.read_id(data.get("unit"))
	state.health = SaveFields.read_int(data.get("health"))
	state.pos = read_pos(data.get("pos"))
	state.carrying = SaveFields.read_int(data.get("carrying"), -1)
	return state


## Errors of saved [param data].
static func validate_dict(data: Dictionary) -> Array[String]:
	var errors: Array[String] = SaveFields.missing(data, KEYS)
	if not errors.is_empty():
		return errors
	if not SaveFields.is_id(data["unit"]):
		errors.append("'unit' is not a non-empty string")
	if not (SaveFields.is_int(data["health"]) and data["health"] >= 0):
		errors.append("'health' is not a whole number of at least 0")
	if not is_pos(data["pos"]):
		errors.append("'pos' is not [x, y, level]")
	if not (SaveFields.is_int(data["carrying"]) and data["carrying"] >= -1):
		errors.append("'carrying' is not an artefact uid or -1")
	return errors


## [param value] as saved: [x, y, level].
static func write_pos(value: Vector3i) -> Array:
	return [value.x, value.y, value.z]


## True for three whole numbers of at least 0.
static func is_pos(value: Variant) -> bool:
	if not value is Array:
		return false
	var parts: Array = value
	if parts.size() != 3:
		return false
	for part: Variant in parts:
		if not (SaveFields.is_int(part) and part >= 0):
			return false
	return true


## The saved position [param value], or Vector3i.ZERO when unreadable.
static func read_pos(value: Variant) -> Vector3i:
	if not is_pos(value):
		return Vector3i.ZERO
	var parts: Array = value
	return Vector3i(
		SaveFields.read_int(parts[0]), SaveFields.read_int(parts[1]), SaveFields.read_int(parts[2])
	)
