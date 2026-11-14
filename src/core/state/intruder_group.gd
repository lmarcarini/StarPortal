class_name IntruderGroup
extends RefCounted
## One group of intruders (M4c): its units, the room it is heading for (&"" until chosen),
## and where it was last seen (Vector3i, or −1s when never seen).
## Saved shape: {"units": [UnitState], "target_room", "last_seen", "work_ticks"}.
## Bible: docs/content/m4c-incursions.md sections 3, 7 and 9

## Saved keys, in to_dict() order.
const KEYS: Array[String] = ["units", "target_room", "last_seen"]
## Optional saved keys (absent in the first v19 saves).
const OPTIONAL: Array[String] = ["work_ticks"]
## last_seen when the group has not been seen.
const UNSEEN: Vector3i = Vector3i(-1, -1, -1)

## The units, front first.
var units: Array[UnitState] = []
## Room id of the objective, or &"".
var target_room: StringName = &""
## Where it was last seen, or UNSEEN.
var last_seen: Vector3i = UNSEEN
## Ticks spent on the objective so far (reset while a squad contests the room).
var work_ticks: int = 0


## The units still standing.
func standing() -> Array[UnitState]:
	var found: Array[UnitState] = []
	for unit: UnitState in units:
		if unit.health > 0:
			found.append(unit)
	return found


## Where the group is: its first standing unit's cell, or its first unit's.
func pos() -> Vector3i:
	var up: Array[UnitState] = standing()
	if not up.is_empty():
		return up[0].pos
	return units[0].pos if not units.is_empty() else UNSEEN


## Moves every unit to [param cell].
func move_to(cell: Vector3i) -> void:
	for unit: UnitState in units:
		unit.pos = cell


## Returns JSON-safe data for saving.
func to_dict() -> Dictionary:
	var unit_data: Array = []
	for unit: UnitState in units:
		unit_data.append(unit.to_dict())
	var seen: Variant = null if last_seen == UNSEEN else UnitState.write_pos(last_seen)
	return {
		"units": unit_data,
		"target_room": String(target_room),
		"last_seen": seen,
		"work_ticks": work_ticks,
	}


## Builds one from valid saved [param data].
static func from_dict(data: Dictionary) -> IntruderGroup:
	var group := IntruderGroup.new()
	for item: Dictionary in SaveFields.dicts_in(data.get("units")):
		group.units.append(UnitState.from_dict(item))
	group.target_room = StringName(str(data.get("target_room", "")))
	var seen: Variant = data.get("last_seen")
	group.last_seen = UnitState.read_pos(seen) if UnitState.is_pos(seen) else UNSEEN
	group.work_ticks = SaveFields.read_int(data.get("work_ticks"))
	return group


## Errors of saved [param data].
static func validate_dict(data: Dictionary) -> Array[String]:
	var errors: Array[String] = SaveFields.missing(data, KEYS)
	if not errors.is_empty():
		return errors
	errors.append_array(
		SaveFields.record_list_errors(data["units"], "units", UnitState.validate_dict)
	)
	if not data["target_room"] is String:
		errors.append("'target_room' is not a String")
	if data["last_seen"] != null and not UnitState.is_pos(data["last_seen"]):
		errors.append("'last_seen' is not null or [x, y, level]")
	if (
		data.has("work_ticks")
		and not (SaveFields.is_int(data["work_ticks"]) and data["work_ticks"] >= 0)
	):
		errors.append("'work_ticks' is not a whole number of at least 0")
	return errors
